import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/patient_assessment.dart';
import '../providers/mtp_state_provider.dart';

class PatientAssessmentScreen extends StatefulWidget {
  const PatientAssessmentScreen({super.key});

  @override
  _PatientAssessmentScreenState createState() =>
      _PatientAssessmentScreenState();
}

class _PatientAssessmentScreenState extends State<PatientAssessmentScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showCaseStartDialog();
    });
  }

  Future<void> _showCaseStartDialog() async {
    final provider = Provider.of<MtpStateProvider>(context, listen: false);
    if (provider.currentCaseId != null) return; // Already started

    String selectedLocation = "ACİL SERVİS";

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Yeni Vaka Başlat"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Kişisel veri girmeyin. Sistem otomatik dosya numarası atayacaktır.",
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedLocation,
                    decoration: const InputDecoration(
                      labelText: 'Hasta Lokasyonu',
                      border: OutlineInputBorder(),
                    ),
                    items: ["ACİL SERVİS", "AMELİYATHANE", "YOĞUN BAKIM"].map((
                      loc,
                    ) {
                      return DropdownMenuItem(value: loc, child: Text(loc));
                    }).toList(),
                    onChanged: (val) {
                      setState(() => selectedLocation = val!);
                    },
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    provider.startNewCase(selectedLocation);
                  },
                  child: const Text("VAKAYI BAŞLAT"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('MTP Risk Değerlendirmesi'),
      ),
      body: Consumer<MtpStateProvider>(
        builder: (context, provider, child) {
          final patient = provider.currentPatient;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader(
                context,
                'Hayati Bulgular (ABC Skoru İçin)',
                Icons.favorite,
              ),
              _buildSliderRow(
                context,
                "Nabız (Kalp Hızı)",
                Icons.monitor_heart,
                patient.heartRate.toDouble(),
                40,
                200,
                "dk",
                (val) => provider.updateVitals(hr: val.toInt()),
              ),
              _buildSliderRow(
                context,
                "Sistolik Kan Basıncı (SKB)",
                Icons.bloodtype,
                patient.systolicBp.toDouble(),
                40,
                220,
                "mmHg",
                (val) => provider.updateVitals(sbp: val.toInt()),
              ),

              const SizedBox(height: 8),
              _buildFastRow(context, provider),

              const SizedBox(height: 16),

              _buildSectionHeader(
                context,
                'Travma Tipi',
                Icons.personal_injury,
              ),
              _buildMechanismSelector(context, provider),

              const SizedBox(height: 24),
              Divider(color: Theme.of(context).dividerTheme.color),

              // Module 2: Pre-Decision
              if (patient.preDecision == null)
                _buildPreDecisionCard(context, provider)
              else
                _buildAIDiscussionArea(context, provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0, left: 4.0),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primaryColor, size: 22),
          const SizedBox(width: 8),
          Text(
            title,
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

  Widget _buildSliderRow(
    BuildContext context,
    String title,
    IconData icon,
    double value,
    double min,
    double max,
    String unit,
    Function(double) onChanged,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      icon,
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${value.toStringAsFixed(0)} $unit',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppTheme.warningOrange
                          : Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(value: value, min: min, max: max, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Widget _buildFastRow(BuildContext context, MtpStateProvider provider) {
    final patient = provider.currentPatient;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.monitor_heart_outlined,
                  color: isDark ? Colors.purple[300] : Colors.purple[700],
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  "FAST USG Pozitif (Sıvı var)",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
            Switch(
              value: patient.isFastPositive,
              activeColor: AppTheme.primaryColor,
              onChanged: (val) => provider.updateVitals(fastPositive: val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMechanismSelector(
    BuildContext context,
    MtpStateProvider provider,
  ) {
    final patient = provider.currentPatient;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String getLabel(InjuryMechanism mechanism) {
      switch (mechanism) {
        case InjuryMechanism.blunt:
          return "KÜNT";
        case InjuryMechanism.penetrating:
          return "PENETRAN";
        case InjuryMechanism.nonTrauma:
          return "TRAVMA DIŞI";
      }
    }

    IconData getIcon(InjuryMechanism mechanism) {
      switch (mechanism) {
        case InjuryMechanism.blunt:
          return Icons.car_crash;
        case InjuryMechanism.penetrating:
          return Icons.colorize;
        case InjuryMechanism.nonTrauma:
          return Icons.medical_services_outlined;
      }
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 12.0,
      alignment: WrapAlignment.center,
      children: InjuryMechanism.values.map((mech) {
        final isSelected = patient.mechanism == mech;
        return ChoiceChip(
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  getIcon(mech),
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.grey[400] : Colors.grey[700]),
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(getLabel(mech), style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) provider.updateVitals(mechanism: mech);
          },
          selectedColor: AppTheme.primaryColor,
          backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          labelStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.grey[300] : Colors.black87),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPreDecisionCard(
    BuildContext context,
    MtpStateProvider provider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDark ? const Color(0xFF263238) : Colors.blue[50],
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.psychology,
                  color: isDark ? Colors.blueAccent : Colors.blue[800],
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  "KLİNİK KARAR (GESTALT)",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDark ? Colors.blueAccent : Colors.blue[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "Klinik önsezinize göre MTP'yi aktive etmeyi düşünüyor musunuz?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.okGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => provider.savePreDecision(true),
                    icon: const Icon(Icons.check_circle_outline, size: 20),
                    label: const FittedBox(
                      child: Text(
                        "EVET",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.grey[700]
                          : Colors.grey[400],
                      foregroundColor: isDark ? Colors.white : Colors.black87,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => provider.savePreDecision(false),
                    icon: const Icon(Icons.cancel_outlined, size: 20),
                    label: const FittedBox(
                      child: Text(
                        "HAYIR",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAIDiscussionArea(
    BuildContext context,
    MtpStateProvider provider,
  ) {
    final risk = provider.currentPatient.calculateRisk();
    final score = provider.currentPatient.calculateABCScore();
    Color riskColor;
    String riskLabel;
    IconData riskIcon;

    switch (risk) {
      case RiskLevel.low:
        riskColor = AppTheme.okGreen;
        riskLabel = "DÜŞÜK ($score Puan)";
        riskIcon = Icons.shield_outlined;
        break;
      case RiskLevel.high:
        riskColor = AppTheme.alertRed;
        riskLabel = "YÜKSEK ($score Puan)";
        riskIcon = Icons.warning_amber_rounded;
        break;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Card(
          color: riskColor.withOpacity(isDark ? 0.2 : 0.1),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: riskColor.withOpacity(0.5), width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(riskIcon, color: riskColor, size: 28),
                    const SizedBox(width: 8),
                    Text(
                      "ABC Skoru:",
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Text(
                  riskLabel,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.gavel,
              color: Theme.of(context).textTheme.bodyLarge?.color,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              "NİHAİ KARAR",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.alertRed,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _handleFinalDecision(context, provider, true),
          icon: const Icon(Icons.play_circle_fill, size: 28),
          label: const FittedBox(
            child: Text(
              "MTP'Yİ AKTİVE ET",
              style: TextStyle(fontSize: 18, letterSpacing: 1.2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
            foregroundColor: isDark ? Colors.white : Colors.black87,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: () => _handleFinalDecision(context, provider, false),
          icon: const Icon(Icons.stop_circle_outlined, size: 24),
          label: const FittedBox(
            child: Text(
              "MTP'Yİ İPTAL ET / AKTİVE ETME",
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ],
    );
  }

  void _handleFinalDecision(
    BuildContext context,
    MtpStateProvider provider,
    bool activate,
  ) {
    provider.saveFinalDecision(activate);
    if (activate) {
      Navigator.pushReplacementNamed(context, '/dashboard');
    } else {
      // Show summary and reset
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("MTP İptal Edildi"),
          content: const Text(
            "Değerlendirme güvenli bir şekilde kaydedildi. Başlangıca dönülüyor.",
          ),
          actions: [
            TextButton(
              onPressed: () {
                provider.startNewAssessment();
                Navigator.pop(context); // Close dialog
              },
              child: const Text("TAMAM"),
            ),
          ],
        ),
      );
    }
  }
}
