import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/lethal_triad_data.dart';
import '../providers/mtp_state_provider.dart';

class LethalTriadScreen extends StatefulWidget {
  const LethalTriadScreen({super.key});

  @override
  State<LethalTriadScreen> createState() => _LethalTriadScreenState();
}

class _LethalTriadScreenState extends State<LethalTriadScreen> {
  double _ph = 7.40;
  double _temperature = 36.5;
  double _inr = 1.2;
  double _lactate = 1.5;

  final _phController = TextEditingController();
  final _tempController = TextEditingController();
  final _inrController = TextEditingController();
  final _lactateController = TextEditingController();

  bool _hasAcidosis = false;
  bool _hasHypothermia = false;
  bool _hasCoagulopathy = false;
  int _triadCount = 0;

  @override
  void initState() {
    super.initState();
    _syncControllers();
    _recalculate();
  }

  @override
  void dispose() {
    _phController.dispose();
    _tempController.dispose();
    _inrController.dispose();
    _lactateController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _phController.text = _ph.toStringAsFixed(2);
    _tempController.text = _temperature.toStringAsFixed(1);
    _inrController.text = _inr.toStringAsFixed(1);
    _lactateController.text = _lactate.toStringAsFixed(1);
  }

  void _recalculate() {
    setState(() {
      _hasAcidosis = _ph < 7.35;
      _hasHypothermia = _temperature < 35.0;
      _hasCoagulopathy = _inr > 1.5;
      _triadCount =
          [_hasAcidosis, _hasHypothermia, _hasCoagulopathy].where((v) => v).length;
    });
  }

  void _save() {
    HapticFeedback.mediumImpact();
    final provider = Provider.of<MtpStateProvider>(context, listen: false);
    final data = LethalTriadData(
      ph: _ph,
      temperature: _temperature,
      inr: _inr,
      lactate: _lactate,
    );
    provider.updateLethalTriad(data);

    if (_triadCount >= 2) {
      HapticFeedback.vibrate();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_triadCount >= 2
            ? 'ÖLÜMCÜL ÜÇGEN KAYDEDİLDİ!'
            : 'Ölümcül üçgen verileri kaydedildi.'),
        backgroundColor:
            _triadCount >= 2 ? AppTheme.alertRed : AppTheme.okGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (_triadCount >= 2) {
      statusColor = AppTheme.alertRed;
      statusText = 'ÖLÜMCÜL ÜÇGEN TESPİT EDİLDİ';
      statusIcon = Icons.dangerous;
    } else if (_triadCount == 1) {
      statusColor = AppTheme.warningOrange;
      statusText = 'TEK KRİTER TESPİT EDİLDİ — İZLEME DEVAM ET';
      statusIcon = Icons.warning_amber_rounded;
    } else {
      statusColor = AppTheme.okGreen;
      statusText = 'TÜM KRİTERLER NORMAL';
      statusIcon = Icons.check_circle;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ölümcül Üçgen Monitörü'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Triad visual indicator
          _buildTriadIndicator(),
          const SizedBox(height: 16),

          // Status card
          Card(
            color: statusColor.withValues(alpha: 0.12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: statusColor.withValues(alpha: 0.5), width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusColor, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Inputs
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

          _buildParameterCard(
            label: 'pH',
            icon: Icons.science,
            value: _ph,
            min: 6.8,
            max: 7.8,
            divisions: 100,
            controller: _phController,
            normalRange: '7.35 – 7.45',
            abnormalLabel: 'ASİDOZ < 7.35',
            isAbnormal: _hasAcidosis,
            onChanged: (v) {
              setState(() {
                _ph = v;
                _phController.text = v.toStringAsFixed(2);
              });
              _recalculate();
            },
            onTextChanged: (text) {
              final parsed = double.tryParse(text);
              if (parsed != null && parsed >= 6.8 && parsed <= 7.8) {
                setState(() => _ph = parsed);
                _recalculate();
              }
            },
          ),

          _buildParameterCard(
            label: 'Sıcaklık (°C)',
            icon: Icons.thermostat,
            value: _temperature,
            min: 30.0,
            max: 42.0,
            divisions: 120,
            controller: _tempController,
            normalRange: '36.5 – 37.5°C',
            abnormalLabel: 'HİPOTERMİ < 35°C',
            isAbnormal: _hasHypothermia,
            onChanged: (v) {
              setState(() {
                _temperature = v;
                _tempController.text = v.toStringAsFixed(1);
              });
              _recalculate();
            },
            onTextChanged: (text) {
              final parsed = double.tryParse(text);
              if (parsed != null && parsed >= 30 && parsed <= 42) {
                setState(() => _temperature = parsed);
                _recalculate();
              }
            },
          ),

          _buildParameterCard(
            label: 'INR',
            icon: Icons.bloodtype,
            value: _inr,
            min: 0.5,
            max: 10.0,
            divisions: 95,
            controller: _inrController,
            normalRange: '< 1.5',
            abnormalLabel: 'KOAGÜLOPATİ > 1.5',
            isAbnormal: _hasCoagulopathy,
            onChanged: (v) {
              setState(() {
                _inr = v;
                _inrController.text = v.toStringAsFixed(1);
              });
              _recalculate();
            },
            onTextChanged: (text) {
              final parsed = double.tryParse(text);
              if (parsed != null && parsed >= 0.5 && parsed <= 10) {
                setState(() => _inr = parsed);
                _recalculate();
              }
            },
          ),

          _buildParameterCard(
            label: 'Laktat (mmol/L)',
            icon: Icons.monitor_heart_outlined,
            value: _lactate,
            min: 0.0,
            max: 20.0,
            divisions: 200,
            controller: _lactateController,
            normalRange: '< 2.0 mmol/L',
            abnormalLabel: 'YÜKSEK > 4.0',
            isAbnormal: _lactate > 4.0,
            onChanged: (v) {
              setState(() {
                _lactate = v;
                _lactateController.text = v.toStringAsFixed(1);
              });
              _recalculate();
            },
            onTextChanged: (text) {
              final parsed = double.tryParse(text);
              if (parsed != null && parsed >= 0 && parsed <= 20) {
                setState(() => _lactate = parsed);
                _recalculate();
              }
            },
          ),

          const SizedBox(height: 16),

          // Management tips
          if (_triadCount > 0) ...[
            Text(
              'YÖNETİM ÖNERİLERİ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: theme.textTheme.bodyMedium?.color,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            if (_hasAcidosis)
              _buildTipCard(
                'Asidoz Yönetimi',
                'Na-bikarbonat düşünün. pH hedef > 7.35. Laktat klerensi takip edin. Kanama kontrolü için cerrahi hemostaza odaklanın.',
                AppTheme.alertRed,
                Icons.science,
              ),
            if (_hasHypothermia)
              _buildTipCard(
                'Hipotermi Yönetimi',
                'Isıtılmış sıvı kullanın. Isıtma battaniyesi uygulayın. Oda sıcaklığını artırın. Islak kıyafetleri çıkarın. Hedef ≥ 36.5°C.',
                Colors.blue,
                Icons.thermostat,
              ),
            if (_hasCoagulopathy)
              _buildTipCard(
                'Koagülopati Yönetimi',
                'Taze donmuş plazma (TDP) verin. Kriyopresipitat düşünün. INR hedef < 1.5. TEG/ROTEM rehberli tedavi uygulayın.',
                AppTheme.warningOrange,
                Icons.bloodtype,
              ),
            const SizedBox(height: 16),
          ],

          ElevatedButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('KAYDET'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _triadCount >= 2 ? AppTheme.alertRed : AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 16),

          // History
          _buildHistory(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTriadIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _triadCircle('ASİDOZ', _hasAcidosis, AppTheme.alertRed),
        _triadCircle('HİPOTERMİ', _hasHypothermia, Colors.blue),
        _triadCircle('KOAGÜLOPATİ', _hasCoagulopathy, AppTheme.warningOrange),
      ],
    );
  }

  Widget _triadCircle(String label, bool isMet, Color color) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isMet ? color : Colors.grey.withValues(alpha: 0.2),
            border: Border.all(
              color: isMet ? color : Colors.grey,
              width: 2,
            ),
            boxShadow: isMet
                ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2)]
                : [],
          ),
          child: Icon(
            isMet ? Icons.close : Icons.check,
            color: isMet ? Colors.white : Colors.grey,
            size: 32,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isMet ? color : Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildParameterCard({
    required String label,
    required IconData icon,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required TextEditingController controller,
    required String normalRange,
    required String abnormalLabel,
    required bool isAbnormal,
    required ValueChanged<double> onChanged,
    required ValueChanged<String> onTextChanged,
  }) {
    final color = isAbnormal ? AppTheme.alertRed : AppTheme.okGreen;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon,
                    color: isAbnormal ? AppTheme.alertRed : Colors.blue,
                    size: 20),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                const Spacer(),
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true, signed: false),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: color,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                    ),
                    onChanged: onTextChanged,
                  ),
                ),
              ],
            ),
            Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
            Row(
              children: [
                Icon(Icons.circle, size: 10,
                    color: isAbnormal ? AppTheme.alertRed : AppTheme.okGreen),
                const SizedBox(width: 6),
                Text(
                  isAbnormal ? abnormalLabel : 'Normal: $normalRange',
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard(String title, String tip, Color color, IconData icon) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: color,
                          fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(tip, style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    final provider = Provider.of<MtpStateProvider>(context, listen: false);
    final history = provider.lethalTriadHistory;

    if (history.isEmpty) {
      return const Text(
        'Henüz kayıt yok.',
        style: TextStyle(fontStyle: FontStyle.italic),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GEÇMİŞ KAYITLAR',
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
        ),
        const SizedBox(height: 8),
        ...history.take(5).map((record) {
          final triadColor = record.isLethalTriad
              ? AppTheme.alertRed
              : (record.lethalTriadCount == 1
                  ? AppTheme.warningOrange
                  : AppTheme.okGreen);
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              dense: true,
              leading: Icon(Icons.circle, color: triadColor, size: 12),
              title: Text(
                'pH ${record.ph.toStringAsFixed(2)} | '
                '${record.temperature.toStringAsFixed(1)}°C | '
                'INR ${record.inr.toStringAsFixed(1)} | '
                'Lak ${record.lactate.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 12),
              ),
              subtitle: Text(
                DateFormat('dd.MM.yyyy HH:mm').format(record.recordedAt),
                style: const TextStyle(fontSize: 11),
              ),
              trailing: Text(
                '${record.lethalTriadCount}/3',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: triadColor,
                    fontSize: 14),
              ),
            ),
          );
        }),
      ],
    );
  }
}
