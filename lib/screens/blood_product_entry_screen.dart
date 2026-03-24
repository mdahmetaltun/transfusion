import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/blood_product_unit.dart';
import '../providers/blood_product_provider.dart';

class BloodProductEntrySheet extends StatefulWidget {
  final String caseId;
  final BloodGroup patientBloodGroup;

  const BloodProductEntrySheet({
    super.key,
    required this.caseId,
    required this.patientBloodGroup,
  });

  @override
  State<BloodProductEntrySheet> createState() => _BloodProductEntrySheetState();
}

class _BloodProductEntrySheetState extends State<BloodProductEntrySheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Form fields
  BloodProductType _productType = BloodProductType.ES;
  final _barcodeController = TextEditingController();
  final _lotController = TextEditingController();
  final _dispatchedByController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _expiryDate;
  BloodGroup _bloodGroup = BloodGroup.unknown;
  RhFactor _rhFactor = RhFactor.unknown;

  // Scanner state
  bool _scannerActive = true;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 0) {
        _scannerController?.start();
      } else {
        _scannerController?.stop();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _barcodeController.dispose();
    _lotController.dispose();
    _dispatchedByController.dispose();
    _notesController.dispose();
    _scannerController?.dispose();
    super.dispose();
  }

  bool _isCompatible(BloodGroup productGroup) {
    if (widget.patientBloodGroup == BloodGroup.unknown) return true;
    if (productGroup == BloodGroup.unknown) return true;
    if (productGroup == BloodGroup.O) return true; // Emergency universal
    if (widget.patientBloodGroup == BloodGroup.AB) return true; // Universal recipient
    return productGroup == widget.patientBloodGroup;
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;
    if (_expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Son kullanma tarihi seçiniz.')),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    final unit = BloodProductUnit(
      id: const Uuid().v4(),
      caseId: widget.caseId,
      productType: _productType,
      barcode: _barcodeController.text.trim(),
      lotNumber: _lotController.text.trim(),
      expiryDate: _expiryDate!,
      bloodGroup: _bloodGroup,
      rhFactor: _rhFactor,
      dispatchedBy: _dispatchedByController.text.trim(),
      registeredAt: DateTime.now(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final bp = Provider.of<BloodProductProvider>(context, listen: false);
    bp.registerUnit(unit);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '${unit.productTypeShortLabel} (${unit.barcode}) kayıt edildi.'),
        backgroundColor: AppTheme.okGreen,
      ),
    );

    Navigator.pop(context);
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) {
      final withTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 23, minute: 59),
      );
      if (mounted) {
        setState(() {
          if (withTime != null) {
            _expiryDate = DateTime(
                picked.year, picked.month, picked.day,
                withTime.hour, withTime.minute);
          } else {
            _expiryDate = DateTime(picked.year, picked.month, picked.day, 23, 59);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Text(
                    'Kan Ürünü Kayıt',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.qr_code_scanner), text: 'Barkod Tara'),
                Tab(icon: Icon(Icons.edit_note), text: 'Manuel Giriş'),
              ],
              labelColor: AppTheme.primaryColor,
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildScannerTab(),
                  _buildManualTab(scrollController),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScannerTab() {
    return Column(
      children: [
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Kan ürününün barkodunu kameraya gösterin.',
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _scannerActive
                  ? MobileScanner(
                      controller: _scannerController ??= MobileScannerController(),
                      onDetect: (capture) {
                        final barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final value = barcodes.first.rawValue ?? '';
                          if (value.isNotEmpty) {
                            setState(() {
                              _scannerActive = false;
                              _barcodeController.text = value;
                            });
                            _scannerController?.stop();
                            _tabController.animateTo(1);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Barkod okundu: $value'),
                                backgroundColor: AppTheme.okGreen,
                              ),
                            );
                          }
                        }
                      },
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppTheme.okGreen, size: 48),
                          const SizedBox(height: 12),
                          Text('Barkod: ${_barcodeController.text}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _scannerActive = true;
                                _barcodeController.clear();
                              });
                              _scannerController?.start();
                            },
                            child: const Text('Tekrar Tara'),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ElevatedButton.icon(
            onPressed: () => _tabController.animateTo(1),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Manuel Girişe Geç'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildManualTab(ScrollController scrollController) {
    final theme = Theme.of(context);

    final incompatible = _bloodGroup != BloodGroup.unknown &&
        widget.patientBloodGroup != BloodGroup.unknown &&
        !_isCompatible(_bloodGroup);

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Product type
            DropdownButtonFormField<BloodProductType>(
              value: _productType,
              decoration: const InputDecoration(
                labelText: 'Ürün Tipi',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.bloodtype),
              ),
              items: BloodProductType.values.map((t) {
                return DropdownMenuItem(
                  value: t,
                  child: Text(_productLabel(t)),
                );
              }).toList(),
              onChanged: (v) => setState(() => _productType = v!),
            ),
            const SizedBox(height: 12),

            // Barcode
            TextFormField(
              controller: _barcodeController,
              decoration: const InputDecoration(
                labelText: 'Barkod No',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.qr_code),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Barkod zorunludur' : null,
            ),
            const SizedBox(height: 12),

            // Lot number
            TextFormField(
              controller: _lotController,
              decoration: const InputDecoration(
                labelText: 'Lot Numarası',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Lot numarası zorunludur' : null,
            ),
            const SizedBox(height: 12),

            // Expiry date
            InkWell(
              onTap: _pickExpiryDate,
              borderRadius: BorderRadius.circular(12),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Son Kullanma Tarihi',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.event),
                  errorText: _expiryDate == null ? null : null,
                ),
                child: Text(
                  _expiryDate != null
                      ? DateFormat('dd.MM.yyyy HH:mm').format(_expiryDate!)
                      : 'Tarih seçin...',
                  style: TextStyle(
                    color: _expiryDate != null
                        ? theme.textTheme.bodyLarge?.color
                        : theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Blood group
            const Text('Kan Grubu',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: BloodGroup.values.map((bg) {
                return ChoiceChip(
                  label: Text(_bloodGroupLabel(bg)),
                  selected: _bloodGroup == bg,
                  onSelected: (s) {
                    if (s) setState(() => _bloodGroup = bg);
                  },
                  selectedColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: _bloodGroup == bg ? Colors.white : null,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            // Rh factor
            const Text('Rh Faktörü',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Rh+'),
                  selected: _rhFactor == RhFactor.positive,
                  onSelected: (s) {
                    if (s) setState(() => _rhFactor = RhFactor.positive);
                  },
                  selectedColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: _rhFactor == RhFactor.positive ? Colors.white : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Rh-'),
                  selected: _rhFactor == RhFactor.negative,
                  onSelected: (s) {
                    if (s) setState(() => _rhFactor = RhFactor.negative);
                  },
                  selectedColor: AppTheme.primaryColor,
                  labelStyle: TextStyle(
                    color: _rhFactor == RhFactor.negative ? Colors.white : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Bilinmiyor'),
                  selected: _rhFactor == RhFactor.unknown,
                  onSelected: (s) {
                    if (s) setState(() => _rhFactor = RhFactor.unknown);
                  },
                  selectedColor: Colors.grey,
                  labelStyle: TextStyle(
                    color: _rhFactor == RhFactor.unknown ? Colors.white : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Compatibility warning
            if (incompatible)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warningOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.warningOrange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: AppTheme.warningOrange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'UYUMLULUK UYARISI: Ürünün kan grubu ($_bloodGroup) '
                        'hasta kan grubu (${widget.patientBloodGroup.name}) '
                        'ile uyumsuz olabilir. Klinik kararınızı kullanın.',
                        style: const TextStyle(
                          color: AppTheme.warningOrange,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),

            // Dispatched by / notes
            TextFormField(
              controller: _dispatchedByController,
              decoration: const InputDecoration(
                labelText: 'Gönderen (Kan Bankası Personeli - Opsiyonel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notlar (Opsiyonel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.notes),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _submitForm,
              icon: const Icon(Icons.save),
              label: const Text('KAYDET'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _productLabel(BloodProductType t) {
    switch (t) {
      case BloodProductType.ES:
        return 'ES — Eritrosit Süspansiyonu';
      case BloodProductType.TDP:
        return 'TDP — Taze Donmuş Plazma';
      case BloodProductType.TSP:
        return 'TSP — Trombosit Süspansiyonu';
      case BloodProductType.KRIYO:
        return 'KRIYO — Kriyopresipitat';
    }
  }

  String _bloodGroupLabel(BloodGroup bg) {
    switch (bg) {
      case BloodGroup.A:
        return 'A';
      case BloodGroup.B:
        return 'B';
      case BloodGroup.AB:
        return 'AB';
      case BloodGroup.O:
        return 'O';
      case BloodGroup.unknown:
        return 'Bilinmiyor';
    }
  }
}
