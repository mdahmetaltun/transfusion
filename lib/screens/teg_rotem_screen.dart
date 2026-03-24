import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/mtp_state_provider.dart';

class TegRotemScreen extends StatefulWidget {
  const TegRotemScreen({super.key});

  @override
  State<TegRotemScreen> createState() => _TegRotemScreenState();
}

class _TegRotemScreenState extends State<TegRotemScreen> {
  double? _extemCa5;
  double? _extemMcf;
  double? _fibtemMcf;
  double? _aptemVsExtemDiff;
  double? _ptInr;

  final _extemCa5Controller = TextEditingController();
  final _extemMcfController = TextEditingController();
  final _fibtemMcfController = TextEditingController();
  final _aptemDiffController = TextEditingController();
  final _inrController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<MtpStateProvider>(context, listen: false);
      if (provider.rotumExTemCa5 != null) {
        _extemCa5 = provider.rotumExTemCa5;
        _extemCa5Controller.text = _extemCa5!.toStringAsFixed(1);
      }
      if (provider.ptInr != null) {
        _ptInr = provider.ptInr;
        _inrController.text = _ptInr!.toStringAsFixed(2);
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _extemCa5Controller.dispose();
    _extemMcfController.dispose();
    _fibtemMcfController.dispose();
    _aptemDiffController.dispose();
    _inrController.dispose();
    super.dispose();
  }

  void _saveToProvider() {
    HapticFeedback.mediumImpact();
    final provider = Provider.of<MtpStateProvider>(context, listen: false);
    provider.updatePOC(_extemCa5, _ptInr);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('TEG/ROTEM verileri kaydedildi.'),
        backgroundColor: AppTheme.okGreen,
      ),
    );
  }

  _Recommendation _computeRecommendation() {
    final ca5 = _extemCa5;
    final fibtem = _fibtemMcf;
    final inr = _ptInr;
    final aptem = _aptemVsExtemDiff;

    // Fibrinolysis
    if (aptem != null && aptem > 15) {
      return _Recommendation(
        text: 'FİBRİNOLİZ: TXA (Traneksamik Asit) düşünün. APTEM/EXTEM farkı >%15.',
        color: AppTheme.alertRed,
        rationale:
            'APTEM test, EXTEM ile karşılaştırıldığında fibrinolitik aktiviteyi gösterir. >%15 fark fibrinolizi işaret eder.',
        dosing: 'TXA: 1g IV bolus, ardından 1g/8h infüzyon',
      );
    }

    if (fibtem != null && fibtem < 7) {
      if (ca5 != null && ca5 < 35) {
        return _Recommendation(
          text: 'Hem FİBRİNOJEN hem TDP (FFP) gerekli.',
          color: AppTheme.alertRed,
          rationale:
              'FIBTEM MCF < 7mm fibrinojen eksikliğini, EXTEM CA5 < 35mm ise pıhtılaşma faktörü eksikliğini gösterir.',
          dosing:
              'Fibrinojen konsantratı: 3-4g IV\nTDP: 10-15 mL/kg',
        );
      }
      return _Recommendation(
        text: 'KRİYOPRESİPİTAT / FİBRİNOJEN KONSANTRATI VER',
        color: AppTheme.alertRed,
        rationale:
            'FIBTEM MCF < 7mm, yetersiz fibrinojen polimerleşmesini gösterir. Fibrinojen replasmanı gereklidir.',
        dosing:
            'Fibrinojen konsantratı: 3-4g IV\nKriyopresipitat: 1 havuz (10 ünite)',
      );
    }

    if (ca5 != null && ca5 < 35) {
      if (fibtem != null && fibtem > 7) {
        return _Recommendation(
          text: 'TDP (FFP) VER — pıhtılaşma faktörü eksikliği',
          color: AppTheme.warningOrange,
          rationale:
              'EXTEM CA5 < 35mm pıhtılaşma faktörü eksikliğini gösterir. FIBTEM MCF normal olduğundan fibrinojen yeterli.',
          dosing: 'TDP: 10-15 mL/kg',
        );
      }
      return _Recommendation(
        text: 'TDP (FFP) VER — pıhtılaşma faktörü eksikliği değerlendirin',
        color: AppTheme.warningOrange,
        rationale: 'EXTEM CA5 < 35mm anormal pıhtılaşmayı işaret eder.',
        dosing: 'TDP: 10-15 mL/kg. FIBTEM sonucunu bekleyin.',
      );
    }

    if (inr != null && inr > 1.5) {
      return _Recommendation(
        text: "TDP'yi artırın, hedef INR < 1.5",
        color: AppTheme.warningOrange,
        rationale:
            'INR > 1.5 pıhtılaşma bozukluğunu gösterir. TEG mevcut değilken INR rehberli tedavi uygulanır.',
        dosing: 'TDP: 10-15 mL/kg IV',
      );
    }

    if (ca5 != null && ca5 >= 35 && (fibtem == null || fibtem >= 7)) {
      return _Recommendation(
        text: 'TEG parametreleri normal — mevcut protokole devam',
        color: AppTheme.okGreen,
        rationale:
            'EXTEM CA5 ≥ 35mm ve FIBTEM MCF ≥ 7mm. Koagülasyon görece normal.',
        dosing: 'Mevcut MTP protokolüne devam edin. Periyodik TEG tekrarlayın.',
      );
    }

    return _Recommendation(
      text: 'Veri giriniz — Öneri için parametre gerekli',
      color: Colors.grey,
      rationale: 'TEG/ROTEM parametrelerini girerek algoritmik öneri alabilirsiniz.',
      dosing: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recommendation = _computeRecommendation();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TEG/ROTEM Rehberli Tedavi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Educational header
          Card(
            color: Colors.blue.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.blue.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'TEG/ROTEM Parametreleri',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _infoRow('EXTEM CA5', 'Pıhtı amplitüdü 5. dakikada (Normal >35mm)'),
                  _infoRow('EXTEM MCF', 'Maksimum pıhtı sertliği (Normal 50-72mm)'),
                  _infoRow('FIBTEM MCF', 'Fibrin katkısı (Normal 9-25mm, Kritik <7mm)'),
                  _infoRow('APTEM/EXTEM', 'Fibrinoliz göstergesi (>%15 anormal)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            'PARAMETRE GİRİŞİ',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: theme.textTheme.bodyMedium?.color,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),

          _buildInputField(
            controller: _extemCa5Controller,
            label: 'EXTEM CA5 (mm) — Normal >35',
            icon: Icons.show_chart,
            isAbnormal: _extemCa5 != null && _extemCa5! < 35,
            onChanged: (v) {
              final parsed = double.tryParse(v);
              setState(() => _extemCa5 = parsed);
            },
          ),
          _buildInputField(
            controller: _extemMcfController,
            label: 'EXTEM MCF (mm) — Normal 50-72',
            icon: Icons.show_chart,
            isAbnormal: _extemMcf != null &&
                (_extemMcf! < 50 || _extemMcf! > 72),
            onChanged: (v) {
              final parsed = double.tryParse(v);
              setState(() => _extemMcf = parsed);
            },
          ),
          _buildInputField(
            controller: _fibtemMcfController,
            label: 'FIBTEM MCF (mm) — Normal 9-25, Kritik <7',
            icon: Icons.biotech,
            isAbnormal: _fibtemMcf != null && _fibtemMcf! < 7,
            onChanged: (v) {
              final parsed = double.tryParse(v);
              setState(() => _fibtemMcf = parsed);
            },
          ),
          _buildInputField(
            controller: _aptemDiffController,
            label: 'APTEM vs EXTEM Farkı (%) — Normal <15%',
            icon: Icons.compare_arrows,
            isAbnormal: _aptemVsExtemDiff != null && _aptemVsExtemDiff! > 15,
            onChanged: (v) {
              final parsed = double.tryParse(v);
              setState(() => _aptemVsExtemDiff = parsed);
            },
          ),
          _buildInputField(
            controller: _inrController,
            label: 'PT/INR — Normal <1.5',
            icon: Icons.bloodtype,
            isAbnormal: _ptInr != null && _ptInr! > 1.5,
            onChanged: (v) {
              final parsed = double.tryParse(v);
              setState(() => _ptInr = parsed);
            },
          ),
          const SizedBox(height: 16),

          // Recommendation card
          Card(
            color: recommendation.color.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                  color: recommendation.color.withValues(alpha: 0.5),
                  width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        recommendation.color == AppTheme.okGreen
                            ? Icons.check_circle
                            : Icons.medication,
                        color: recommendation.color,
                        size: 28,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'ÖNERİ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: recommendation.color,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    recommendation.text,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: recommendation.color,
                    ),
                  ),
                  if (recommendation.rationale.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Divider(),
                    const SizedBox(height: 6),
                    Text(
                      'Gerekçe:',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyMedium?.color,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(recommendation.rationale,
                        style: const TextStyle(fontSize: 13)),
                    if (recommendation.dosing.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: recommendation.color.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Doz:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              recommendation.dosing,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: _saveToProvider,
            icon: const Icon(Icons.save),
            label: const Text('VERİYİ KAYDET (Sağlık Kaydı)'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _infoRow(String param, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$param: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          Expanded(
            child: Text(desc, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isAbnormal,
    required ValueChanged<String> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon,
              color: isAbnormal ? AppTheme.alertRed : null),
          suffixIcon: isAbnormal
              ? const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.alertRed)
              : null,
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(
              color: isAbnormal ? AppTheme.alertRed : AppTheme.primaryColor,
              width: 1.6,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _Recommendation {
  final String text;
  final Color color;
  final String rationale;
  final String dosing;

  _Recommendation({
    required this.text,
    required this.color,
    required this.rationale,
    required this.dosing,
  });
}
