import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/patient_assessment.dart';
import '../providers/mtp_state_provider.dart';
import '../providers/admin_settings_provider.dart';

class EndCaseScreen extends StatefulWidget {
  const EndCaseScreen({super.key});

  @override
  State<EndCaseScreen> createState() => _EndCaseScreenState();
}

class _EndCaseScreenState extends State<EndCaseScreen> {
  final _notesController = TextEditingController();

  // Snapshot of provider state captured before closeCase clears it
  String _caseId = '…';
  String _location = '…';
  int _abcScore = 0;
  bool _hrMet = false;
  bool _sbpMet = false;
  bool _fastMet = false;
  bool _penetratingMet = false;
  int _prbcCount = 0;
  int _ffpCount = 0;
  int _pltCount = 0;
  int _cryoCount = 0;
  int _totalProducts = 0;
  String _mtpDuration = '00:00:00';
  String _ratioDisplay = '—';
  bool _use211 = false;

  @override
  void initState() {
    super.initState();
    // Snapshot all summary data before closeCase clears provider state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<MtpStateProvider>(context, listen: false);
      final settings =
          Provider.of<AdminSettingsProvider>(context, listen: false).settings;
      final patient = provider.currentPatient;

      setState(() {
        _caseId = provider.currentCaseId ?? 'TRM-XX';
        _location = provider.caseLocation ?? '—';
        _abcScore = patient.calculateABCScore();
        _hrMet = patient.heartRate >= 120;
        _sbpMet = patient.systolicBp <= 90;
        _fastMet = patient.isFastPositive;
        _penetratingMet = patient.mechanism == InjuryMechanism.penetrating;
        _prbcCount = provider.prbcCount;
        _ffpCount = provider.ffpCount;
        _pltCount = provider.pltCount;
        _cryoCount = provider.cryoCount;
        _totalProducts = provider.totalProductsGiven;
        _mtpDuration = provider.mtpDurationFormatted;
        _ratioDisplay = provider.currentRatioDisplay;
        _use211 = settings.use211Ratio;
      });
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _saveAndFinish(MtpStateProvider provider) {
    provider.closeCase(_notesController.text);
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/splash', (Route<dynamic> route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MtpStateProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaka Özeti'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 72,
              color: AppTheme.okGreen,
            ),
            const SizedBox(height: 12),
            Text(
              'MTP VAKASI SONLANDIRILDI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.headlineMedium?.color,
              ),
            ),
            const SizedBox(height: 20),
            // Summary card
            Card(
              color: isDark ? Colors.black26 : AppTheme.lightSurfaceAltColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark
                      ? Colors.transparent
                      : theme.colorScheme.outline,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Case ID + location
                    Row(
                      children: [
                        const Icon(Icons.folder_open, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '$_caseId · $_location',
                            style: TextStyle(
                              fontSize: 15,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    // ABC Score breakdown
                    Text(
                      'ABC Skoru: $_abcScore / 4',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _abcScore >= 2
                            ? AppTheme.alertRed
                            : AppTheme.okGreen,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _criterionPill(context, 'KH≥120', _hrMet),
                        _criterionPill(context, 'SKB≤90', _sbpMet),
                        _criterionPill(context, 'FAST(+)', _fastMet),
                        _criterionPill(context, 'PENETRAN', _penetratingMet),
                      ],
                    ),
                    const Divider(height: 20),
                    // Product counts
                    Text(
                      'Toplam Ürün: $_totalProducts',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _productBadge(context, 'ES', _prbcCount, AppTheme.prbcColor),
                        const SizedBox(width: 8),
                        _productBadge(context, 'TDP', _ffpCount, AppTheme.ffpColor),
                        const SizedBox(width: 8),
                        _productBadge(context, 'TSP', _pltCount, AppTheme.pltColor),
                        const SizedBox(width: 8),
                        _productBadge(
                          context,
                          'KRIYO',
                          _cryoCount,
                          Colors.purple[300]!,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ES:TDP:TSP = $_ratioDisplay  (Hedef: ${_use211 ? '2:1:1' : '1:1:1'})',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    const Divider(height: 20),
                    // MTP duration
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'MTP Süresi: $_mtpDuration',
                          style: TextStyle(
                            fontSize: 15,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText:
                    'Klinik Not / Süreç Hakkında Serbest Metin (Opsiyonel)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => _saveAndFinish(provider),
              icon: const Icon(Icons.save_outlined),
              label: const Text(
                'KAYDET VE BAŞA DÖN',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _criterionPill(BuildContext context, String label, bool met) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: met
            ? AppTheme.alertRed
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: met
              ? Colors.white
              : Theme.of(context).textTheme.bodySmall?.color,
        ),
      ),
    );
  }

  Widget _productBadge(
    BuildContext context,
    String label,
    int count,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
        ],
      ),
    );
  }
}
