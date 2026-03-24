import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/patient_assessment.dart';
import '../models/blood_product_unit.dart';
import '../providers/mtp_state_provider.dart';
import '../services/auth_service.dart';

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
                    final authService = Provider.of<AuthService>(
                      context,
                      listen: false,
                    );
                    provider.startNewCase(
                      selectedLocation,
                      uid:
                          authService.currentFirebaseUser?.uid ??
                          authService.currentUserProfile?.uid ??
                          'UNKNOWN',
                      facilityId:
                          authService.currentUserProfile?.facilityId ??
                          'UNKNOWN',
                    );
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

          return Column(
            children: [
              // Always-visible ABC score strip
              _buildAbcScoreStrip(context, provider),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSectionHeader(
                      context,
                      'Hayati Bulgular (ABC Skoru İçin)',
                      Icons.favorite,
                    ),
                    _buildSliderRow(
                      context,
                      provider,
                      "Nabız (Kalp Hızı)",
                      Icons.monitor_heart,
                      patient.heartRate.toDouble(),
                      40,
                      200,
                      160,
                      "dk",
                      (val) => provider.updateVitals(hr: val.toInt()),
                    ),
                    _buildSliderRow(
                      context,
                      provider,
                      "Sistolik Kan Basıncı (SKB)",
                      Icons.bloodtype,
                      patient.systolicBp.toDouble(),
                      40,
                      220,
                      180,
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

                    const SizedBox(height: 16),
                    _buildPatientInfoSection(context, provider),

                    const SizedBox(height: 24),
                    Divider(color: Theme.of(context).dividerTheme.color),

                    // Module 2: Pre-Decision
                    if (patient.preDecision == null)
                      _buildPreDecisionCard(context, provider)
                    else
                      _buildAIDiscussionArea(context, provider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAbcScoreStrip(BuildContext context, MtpStateProvider provider) {
    final patient = provider.currentPatient;
    final score = patient.calculateABCScore();
    final isHighRisk = score >= 2;

    final stripBg = isHighRisk
        ? AppTheme.alertRed.withValues(alpha: 0.12)
        : AppTheme.okGreen.withValues(alpha: 0.10);
    final stripBorder = isHighRisk
        ? AppTheme.alertRed.withValues(alpha: 0.4)
        : AppTheme.okGreen.withValues(alpha: 0.4);
    final scoreColor = isHighRisk ? AppTheme.alertRed : AppTheme.okGreen;

    final criteria = [
      _CriterionPill(
        label: 'KH≥120',
        met: patient.heartRate >= 120,
      ),
      _CriterionPill(
        label: 'SKB≤90',
        met: patient.systolicBp <= 90,
      ),
      _CriterionPill(
        label: 'FAST(+)',
        met: patient.isFastPositive,
      ),
      _CriterionPill(
        label: 'PENETRAN',
        met: patient.mechanism == InjuryMechanism.penetrating,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: stripBg,
        border: Border(
          bottom: BorderSide(color: stripBorder, width: 1.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // Score badge
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scoreColor,
            ),
            child: Center(
              child: Text(
                '$score/4',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Criterion pills
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: criteria.map((c) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: c.met
                        ? AppTheme.alertRed
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    c.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: c.met
                          ? Colors.white
                          : Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 8),
          // Risk label
          Text(
            isHighRisk ? 'YÜKSEK' : 'DÜŞÜK',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: scoreColor,
            ),
          ),
        ],
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
    MtpStateProvider provider,
    String title,
    IconData icon,
    double value,
    double min,
    double max,
    int divisions,
    String unit,
    Function(double) onChanged, {
    Function(double)? onChangeEnd,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valueLabel = '${value.toStringAsFixed(0)} $unit';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 380;
                final titleColor = Theme.of(context).textTheme.bodyLarge?.color;
                final valueColor = isDark
                    ? AppTheme.warningOrange
                    : Colors.orange[800];

                final labelRow = Row(
                  children: [
                    Icon(
                      icon,
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                );

                // Value badge with edit icon
                final valueBadge = GestureDetector(
                  onTap: () => _showDirectEntryDialog(
                    context,
                    title,
                    value,
                    min,
                    max,
                    unit,
                    onChanged,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          valueLabel,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: valueColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.edit,
                          size: 14,
                          color: valueColor?.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ),
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      labelRow,
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: valueBadge,
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: labelRow),
                    const SizedBox(width: 12),
                    valueBadge,
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              label: '${value.toStringAsFixed(0)} $unit',
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDirectEntryDialog(
    BuildContext context,
    String title,
    double currentValue,
    double min,
    double max,
    String unit,
    Function(double) onChanged,
  ) async {
    final controller = TextEditingController(
      text: currentValue.toStringAsFixed(0),
    );

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            suffixText: unit,
            labelText: '${min.toInt()} – ${max.toInt()}',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('İPTAL'),
          ),
          ElevatedButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text);
              if (parsed != null && parsed >= min && parsed <= max) {
                onChanged(parsed);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('TAMAM'),
          ),
        ],
      ),
    );
    controller.dispose();
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

  Widget _buildPatientInfoSection(
    BuildContext context,
    MtpStateProvider provider,
  ) {
    return _PatientInfoExpansionCard(provider: provider);
  }

  Widget _buildPreDecisionCard(
    BuildContext context,
    MtpStateProvider provider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final score = provider.currentPatient.calculateABCScore();

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
              'ABC Skoru: $score/4\nKlinik önsezinize göre MTP\'yi aktive etmeyi düşünüyor musunuz?',
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
          color: riskColor.withValues(alpha: isDark ? 0.2 : 0.1),
          elevation: 0,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: riskColor.withValues(alpha: 0.5), width: 2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 430;
                final scoreText = Text(
                  riskLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                );

                final titleRow = Row(
                  children: [
                    Icon(riskIcon, color: riskColor, size: 28),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "ABC Skoru:",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );

                if (isCompact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      titleRow,
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: scoreText,
                        ),
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: titleRow),
                    const SizedBox(width: 12),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: scoreText,
                      ),
                    ),
                  ],
                );
              },
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

class _PatientInfoExpansionCard extends StatefulWidget {
  final MtpStateProvider provider;

  const _PatientInfoExpansionCard({required this.provider});

  @override
  State<_PatientInfoExpansionCard> createState() =>
      _PatientInfoExpansionCardState();
}

class _PatientInfoExpansionCardState extends State<_PatientInfoExpansionCard> {
  bool _expanded = false;
  double _weight = 70.0;
  BloodGroup _bloodGroup = BloodGroup.unknown;
  RhFactor _rhFactor = RhFactor.unknown;

  @override
  void initState() {
    super.initState();
    _weight = widget.provider.patientWeightKg ?? 70.0;
    _bloodGroup = widget.provider.patientBloodGroup;
    _rhFactor = widget.provider.patientRhFactor;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline, color: AppTheme.primaryColor),
            title: const Text(
              'Hasta Bilgileri (Opsiyonel)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: widget.provider.patientWeightKg != null
                ? Text(
                    '${widget.provider.patientWeightKg!.toStringAsFixed(0)} kg · '
                    '${_bloodGroupLabel(widget.provider.patientBloodGroup)}'
                    '${widget.provider.patientRhFactor == RhFactor.positive ? ' Rh+' : widget.provider.patientRhFactor == RhFactor.negative ? ' Rh-' : ''}',
                    style: TextStyle(
                        color: theme.textTheme.bodyMedium?.color, fontSize: 12),
                  )
                : null,
            trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  // Weight
                  Row(
                    children: [
                      const Icon(Icons.monitor_weight, size: 18,
                          color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Kilo: ${_weight.toStringAsFixed(0)} kg',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Slider(
                    value: _weight.clamp(20, 200),
                    min: 20,
                    max: 200,
                    divisions: 180,
                    label: '${_weight.toStringAsFixed(0)} kg',
                    onChanged: (v) {
                      setState(() => _weight = v);
                      widget.provider.updatePatientInfo(weight: v);
                    },
                  ),
                  const SizedBox(height: 8),

                  // Blood group
                  const Text('Kan Grubu',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: BloodGroup.values.map((bg) {
                      return ChoiceChip(
                        label: Text(_bloodGroupLabel(bg)),
                        selected: _bloodGroup == bg,
                        onSelected: (s) {
                          if (s) {
                            setState(() => _bloodGroup = bg);
                            widget.provider.updatePatientInfo(bloodGroup: bg);
                          }
                        },
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: _bloodGroup == bg ? Colors.white : null,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),

                  // Rh factor
                  const Text('Rh Faktörü',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Rh+'),
                        selected: _rhFactor == RhFactor.positive,
                        onSelected: (s) {
                          if (s) {
                            setState(() => _rhFactor = RhFactor.positive);
                            widget.provider
                                .updatePatientInfo(rhFactor: RhFactor.positive);
                          }
                        },
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: _rhFactor == RhFactor.positive
                              ? Colors.white
                              : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Rh-'),
                        selected: _rhFactor == RhFactor.negative,
                        onSelected: (s) {
                          if (s) {
                            setState(() => _rhFactor = RhFactor.negative);
                            widget.provider
                                .updatePatientInfo(rhFactor: RhFactor.negative);
                          }
                        },
                        selectedColor: AppTheme.primaryColor,
                        labelStyle: TextStyle(
                          color: _rhFactor == RhFactor.negative
                              ? Colors.white
                              : null,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CriterionPill {
  final String label;
  final bool met;

  const _CriterionPill({required this.label, required this.met});
}
