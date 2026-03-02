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
      appBar: AppBar(title: const Text('MTP Risk Değerlendirmesi')),
      body: Consumer<MtpStateProvider>(
        builder: (context, provider, child) {
          final patient = provider.currentPatient;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSectionHeader('Hayati Bulgular (ABC Skoru İçin)'),
              _buildSliderRow(
                context,
                "Nabız (Kalp Hızı)",
                patient.heartRate.toDouble(),
                40,
                200,
                "dk",
                (val) => provider.updateVitals(hr: val.toInt()),
              ),
              _buildSliderRow(
                context,
                "Sistolik Kan Basıncı (SKB)",
                patient.systolicBp.toDouble(),
                40,
                220,
                "mmHg",
                (val) => provider.updateVitals(sbp: val.toInt()),
              ),

              const SizedBox(height: 8),
              _buildFastRow(context, provider),

              const SizedBox(height: 16),

              _buildSectionHeader('Travma Tipi'),
              _buildMechanismSelector(context, provider),

              const SizedBox(height: 24),
              const Divider(color: Colors.white24),

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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.textGrey,
        ),
      ),
    );
  }

  Widget _buildSliderRow(
    BuildContext context,
    String title,
    double value,
    double min,
    double max,
    String unit,
    Function(double) onChanged,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(context).textTheme.bodyLarge),
                Text(
                  '${value.toStringAsFixed(0)} $unit',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.warningOrange,
                  ),
                ),
              ],
            ),
            Slider(value: value, min: min, max: max, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Widget _buildFastRow(BuildContext context, MtpStateProvider provider) {
    final patient = provider.currentPatient;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "FAST USG Pozitif (Sıvı var)",
              style: Theme.of(context).textTheme.bodyLarge,
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: InjuryMechanism.values.map((mech) {
        final isSelected = patient.mechanism == mech;
        return ChoiceChip(
          label: Text(getLabel(mech)),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) provider.updateVitals(mechanism: mech);
          },
          selectedColor: AppTheme.primaryColor,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textGrey,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPreDecisionCard(
    BuildContext context,
    MtpStateProvider provider,
  ) {
    return Card(
      color: Colors.blueGrey[900],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text(
              "KLİNİK KARAR (GESTALT)",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Klinik önsezinize göre MTP'yi aktive etmeyi düşünüyor musunuz?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.okGreen,
                    ),
                    onPressed: () => provider.savePreDecision(true),
                    child: const Text("EVET"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[700],
                    ),
                    onPressed: () => provider.savePreDecision(false),
                    child: const Text("HAYIR"),
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

    switch (risk) {
      case RiskLevel.low:
        riskColor = Colors.green;
        riskLabel = "DÜŞÜK ($score Puan)";
        break;
      case RiskLevel.high:
        riskColor = Colors.red;
        riskLabel = "YÜKSEK ($score Puan)";
        break;
    }

    return Column(
      children: [
        Card(
          color: riskColor.withOpacity(0.2),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: riskColor, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("ABC Skoru:", style: TextStyle(fontSize: 18)),
                Text(
                  riskLabel,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          "NİHAİ KARAR",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed),
          onPressed: () => _handleFinalDecision(context, provider, true),
          child: const Text("MTP'Yİ AKTİVE ET"),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[800]),
          onPressed: () => _handleFinalDecision(context, provider, false),
          child: const Text("MTP'Yİ İPTAL ET / AKTİVE ETME"),
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
