import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/mtp_state_provider.dart';

class DosingCalculatorScreen extends StatefulWidget {
  const DosingCalculatorScreen({super.key});

  @override
  State<DosingCalculatorScreen> createState() => _DosingCalculatorScreenState();
}

class _DosingCalculatorScreenState extends State<DosingCalculatorScreen> {
  double _weight = 70.0;
  final _weightController = TextEditingController(text: '70');
  double? _fibrinogenCurrent;
  final _fibController = TextEditingController();
  bool _isPediatric = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<MtpStateProvider>(context, listen: false);
      if (provider.patientWeightKg != null) {
        setState(() {
          _weight = provider.patientWeightKg!;
          _weightController.text = _weight.toStringAsFixed(0);
          _isPediatric = _weight < 15;
        });
      }
      if (provider.fibrinogenLevel != null) {
        setState(() {
          _fibrinogenCurrent = provider.fibrinogenLevel;
          _fibController.text = _fibrinogenCurrent!.toStringAsFixed(1);
        });
      }
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _fibController.dispose();
    super.dispose();
  }

  double get _bloodVolumeMl =>
      _isPediatric ? _weight * 80 : _weight * 70;

  double get _esMl => _weight * 10;
  double get _esUnits => (_esMl / 300).ceil().toDouble();

  double get _tdpMlLow => _weight * 10;
  double get _tdpMlHigh => _weight * 15;
  double get _tdpUnitsLow => (_tdpMlLow / 225).ceil().toDouble();
  double get _tdpUnitsHigh => (_tdpMlHigh / 225).ceil().toDouble();

  double get _tspUnits => (_weight / 10).ceil().toDouble();
  double get _kryoUnits => (_weight / 5).ceil().toDouble();

  double? get _fibDose {
    if (_fibrinogenCurrent == null) return null;
    const target = 1.5;
    final current = _fibrinogenCurrent!;
    if (current >= target) return 0;
    const fibPerUnit = 0.4; // ~0.4 g fibrinojen per kriyopresipitat ünitesi
    final plasmaVolume = _bloodVolumeMl * 0.5; // roughly
    final dose = (target - current) * plasmaVolume * 1.5 / (fibPerUnit * 1000);
    return dose;
  }

  void _saveWeight() {
    HapticFeedback.mediumImpact();
    final provider = Provider.of<MtpStateProvider>(context, listen: false);
    provider.updatePatientInfo(weight: _weight);
    if (_fibrinogenCurrent != null) {
      provider.updateFibrinogen(_fibrinogenCurrent!);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Kilo ve veriler kaydedildi.'),
        backgroundColor: AppTheme.okGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kilo Bazlı Doz Hesaplama'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Weight input
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.monitor_weight, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        'Hasta Kilosu',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          const Text('Pediatrik (<15kg)', style: TextStyle(fontSize: 12)),
                          Switch(
                            value: _isPediatric,
                            onChanged: (v) => setState(() => _isPediatric = v),
                            activeColor: AppTheme.primaryColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Slider(
                          value: _weight.clamp(1, 200),
                          min: 1,
                          max: 200,
                          divisions: 199,
                          label: '${_weight.toStringAsFixed(0)} kg',
                          onChanged: (v) {
                            setState(() {
                              _weight = v;
                              _weightController.text =
                                  v.toStringAsFixed(0);
                              _isPediatric = v < 15;
                            });
                          },
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: TextField(
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          textAlign: TextAlign.center,
                          decoration: const InputDecoration(
                            suffixText: 'kg',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) {
                            final parsed = double.tryParse(v);
                            if (parsed != null && parsed >= 1 && parsed <= 200) {
                              setState(() {
                                _weight = parsed;
                                _isPediatric = parsed < 15;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Tahmini Kan Hacmi: ${_bloodVolumeMl.toStringAsFixed(0)} mL '
                    '(${_isPediatric ? '80 mL/kg pediatrik' : '70 mL/kg yetişkin'})',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _saveWeight,
                    icon: const Icon(Icons.save, size: 18),
                    label: const Text('Kaydet'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(120, 44),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'HESAPLANAN DOZLAR',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: theme.textTheme.bodyMedium?.color,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),

          _buildDoseCard(
            title: 'ES (Eritrosit Süspansiyonu)',
            color: AppTheme.prbcColor,
            icon: Icons.bloodtype,
            rows: [
              'Hedef: 10 mL/kg',
              'Toplam: ${_esMl.toStringAsFixed(0)} mL',
              'Yaklaşık Ünite: ${_esUnits.toStringAsFixed(0)} ünite (1 ünite ≈ 250-350 mL)',
            ],
          ),

          _buildDoseCard(
            title: 'TDP (Taze Donmuş Plazma)',
            color: AppTheme.ffpColor,
            icon: Icons.opacity,
            rows: [
              'Hedef: 10-15 mL/kg',
              'Düşük: ${_tdpMlLow.toStringAsFixed(0)} mL → ${_tdpUnitsLow.toStringAsFixed(0)} ünite',
              'Yüksek: ${_tdpMlHigh.toStringAsFixed(0)} mL → ${_tdpUnitsHigh.toStringAsFixed(0)} ünite',
              '(1 ünite TDP ≈ 200-250 mL)',
            ],
          ),

          _buildDoseCard(
            title: 'TSP (Trombosit Süspansiyonu)',
            color: AppTheme.pltColor,
            icon: Icons.grain,
            rows: [
              'Hedef: 1 ünite / 10 kg',
              'Toplam: ${_tspUnits.toStringAsFixed(0)} ünite',
            ],
          ),

          _buildDoseCard(
            title: 'KRİYOPRESİPİTAT',
            color: Colors.purple[300]!,
            icon: Icons.science,
            rows: [
              'Hedef: 1 ünite / 5 kg',
              'Toplam: ${_kryoUnits.toStringAsFixed(0)} ünite',
            ],
          ),

          const SizedBox(height: 16),

          // Fibrinogen section
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.biotech, color: Colors.purple),
                      SizedBox(width: 8),
                      Text(
                        'Fibrinojen Hedef Doz Hesabı',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _fibController,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Mevcut Fibrinojen (g/L)',
                      border: OutlineInputBorder(),
                      hintText: 'örn: 1.0',
                    ),
                    onChanged: (v) {
                      setState(() {
                        _fibrinogenCurrent = double.tryParse(v);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  if (_fibrinogenCurrent != null) ...[
                    Text(
                      'Hedef fibrinojen: 1.5 g/L',
                      style: TextStyle(
                          color: theme.textTheme.bodyMedium?.color,
                          fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    if (_fibDose != null && _fibDose! > 0)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Tahmini Kriyopresipitat: '
                              '${_fibDose!.ceil()} ünite',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.purple,
                              ),
                            ),
                            const Text(
                              '(Her ünite ≈ 0.4g fibrinojen içerir)',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    else if (_fibrinogenCurrent! >= 1.5)
                      const Text(
                        'Fibrinojen hedef düzeyde — ek doz gerekmiyor.',
                        style: TextStyle(color: AppTheme.okGreen),
                      ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warningOrange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppTheme.warningOrange.withValues(alpha: 0.4)),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: AppTheme.warningOrange, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hesaplanan dozlar kılavuz niteliğindedir. Klinisyen kararı esastır.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDoseCard({
    required String title,
    required Color color,
    required IconData icon,
    required List<String> rows,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: color, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...rows.map(
                      (r) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text(r, style: const TextStyle(fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
