import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart' show SharePlus, ShareParams;
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../core/whatsapp_service.dart';
import '../providers/mtp_state_provider.dart';
import '../providers/admin_settings_provider.dart';
import '../models/event_model.dart';
import '../services/firestore_service.dart';

class ShiftHandoverScreen extends StatefulWidget {
  const ShiftHandoverScreen({super.key});

  @override
  State<ShiftHandoverScreen> createState() => _ShiftHandoverScreenState();
}

class _ShiftHandoverScreenState extends State<ShiftHandoverScreen> {
  final _noteController = TextEditingController();
  bool _handoverDone = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _completeHandover() {
    HapticFeedback.mediumImpact();
    final provider = Provider.of<MtpStateProvider>(context, listen: false);
    if (provider.currentCaseId != null) {
      final fs = FirestoreService();
      final event = MtpEvent(
        caseId: provider.currentCaseId!,
        type: EventType.caseUpdated,
        payload: {
          'action': 'handover',
          'note': _noteController.text,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      fs.logEvent(provider.currentCaseId!, event);
    }

    setState(() => _handoverDone = true);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Devir Tamamlandı'),
        content: const Text(
          'Nöbet devri başarıyla kaydedildi ve loglandı.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('TAMAM'),
          ),
        ],
      ),
    );
  }

  void _shareHandover(MtpStateProvider provider) {
    final settings =
        Provider.of<AdminSettingsProvider>(context, listen: false).settings;
    final summary = _buildHandoverText(provider, settings);
    final waMsg = WhatsAppService.handoverMessage(summaryText: summary);

    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Devir Notunu Paylaş',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  final sent = await WhatsAppService.sendMessage(
                    phone: settings.bloodBankPhone,
                    message: waMsg,
                  );
                  if (!sent && mounted) {
                    // Fallback to system share sheet
                    SharePlus.instance.share(ShareParams(
                      text: summary,
                      subject: 'MTP Nöbet Devir — ${provider.currentCaseId}',
                    ));
                  }
                },
                icon: const Icon(Icons.message),
                label: const Text('Kan Bankasına WhatsApp Gönder',
                    style: TextStyle(fontSize: 15)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  SharePlus.instance.share(ShareParams(
                    text: summary,
                    subject: 'MTP Nöbet Devir — ${provider.currentCaseId}',
                  ));
                },
                icon: const Icon(Icons.ios_share),
                label: const Text('Diğer Uygulamalarla Paylaş',
                    style: TextStyle(fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildHandoverText(
      MtpStateProvider provider, SettingsModel settings) {
    final now = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());
    final activationStr = provider.mtpActivationTime != null
        ? DateFormat('dd.MM.yyyy HH:mm').format(provider.mtpActivationTime!)
        : '—';

    final score = provider.currentPatient.calculateABCScore();
    final hr = provider.currentPatient.heartRate;
    final sbp = provider.currentPatient.systolicBp;
    final isFast = provider.currentPatient.isFastPositive ? 'Pozitif' : 'Negatif';
    final mech = provider.currentPatient.mechanism.name;

    final txaWindowSec = settings.txaWindowHours * 3600;
    final txaElapsed = provider.mtpActivationTime != null
        ? DateTime.now().difference(provider.mtpActivationTime!).inSeconds
        : 0;
    final txaOpen = txaElapsed < txaWindowSec;

    final triagStr = provider.hasLethalTriad
        ? 'ÖLÜMCÜL ÜÇGEN TESPİT EDİLDİ'
        : (provider.latestLethalTriad != null
            ? 'Üçgen yok (${provider.latestLethalTriad!.lethalTriadCount}/3)'
            : 'Veri yok');

    return '''
=== MTP NÖBET DEVİR ÖZETI ===
Tarih/Saat: $now

VAKA BİLGİSİ
Vaka ID: ${provider.currentCaseId ?? '—'}
Lokasyon: ${provider.caseLocation ?? '—'}
MTP Aktivasyon: $activationStr
Süre: ${provider.mtpDurationFormatted}

ABC SKORU: $score/4
- Nabız ≥120: ${hr >= 120 ? 'EVET ($hr)' : 'HAYIR ($hr)'}
- SKB ≤90: ${sbp <= 90 ? 'EVET ($sbp)' : 'HAYIR ($sbp)'}
- FAST: $isFast
- Mekanizma: $mech

ÜRÜN TAKİBİ (UYGULANDILAR)
ES: ${provider.prbcCount} ünite
TDP: ${provider.ffpCount} ünite
TSP: ${provider.pltCount} ünite
KRİYO: ${provider.cryoCount} ünite
TOPLAM: ${provider.totalProductsGiven} ünite
Oran: ${provider.currentRatioDisplay} (Hedef: ${settings.use211Ratio ? '2:1:1' : '1:1:1'})

KLİNİK DURUM
TXA Penceresi: ${txaOpen ? 'AÇIK' : 'KAPALI'}
Ölümcül Üçgen: $triagStr
Fibrinojen: ${provider.fibrinogenLevel != null ? '${provider.fibrinogenLevel!.toStringAsFixed(1)} g/L' : 'Ölçülmedi'}

DEVİR NOTU
${_noteController.text.isEmpty ? '—' : _noteController.text}

=== DEVİR SONU ===
''';
  }

  Future<void> _callBloodBank() async {
    final settings =
        Provider.of<AdminSettingsProvider>(context, listen: false).settings;
    // Try WhatsApp first, fall back to phone call
    final sent =
        await WhatsAppService.openChat(phone: settings.bloodBankPhone);
    if (!sent && mounted) {
      final uri = Uri(scheme: 'tel', path: settings.bloodBankPhone);
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Consumer2<MtpStateProvider, AdminSettingsProvider>(
      builder: (context, provider, admin, child) {
        final settings = admin.settings;
        final score = provider.currentPatient.calculateABCScore();
        final activationStr = provider.mtpActivationTime != null
            ? DateFormat('dd.MM.yyyy HH:mm')
                .format(provider.mtpActivationTime!)
            : '—';

        final txaWindowSec = settings.txaWindowHours * 3600;
        final txaElapsed = provider.mtpActivationTime != null
            ? DateTime.now()
                .difference(provider.mtpActivationTime!)
                .inSeconds
            : 0;
        final txaOpen = txaElapsed < txaWindowSec;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Nöbet Devir Özeti'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _shareHandover(provider),
                tooltip: 'Paylaş',
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary card
              Card(
                color: isDark
                    ? Colors.blueGrey[900]
                    : const Color(0xFFEAF2FB),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _summaryRow('Vaka ID', provider.currentCaseId ?? '—'),
                      _summaryRow('Lokasyon', provider.caseLocation ?? '—'),
                      _summaryRow('MTP Aktivasyon', activationStr),
                      _summaryRow('Süre', provider.mtpDurationFormatted),
                      const Divider(),
                      _summaryRow(
                          'ABC Skoru', '$score / 4',
                          valueColor: score >= 2
                              ? AppTheme.alertRed
                              : AppTheme.okGreen),
                      _summaryRow('Nabız',
                          '${provider.currentPatient.heartRate} dk',
                          valueColor:
                              provider.currentPatient.heartRate >= 120
                                  ? AppTheme.alertRed
                                  : null),
                      _summaryRow('SKB',
                          '${provider.currentPatient.systolicBp} mmHg',
                          valueColor:
                              provider.currentPatient.systolicBp <= 90
                                  ? AppTheme.alertRed
                                  : null),
                      _summaryRow('FAST',
                          provider.currentPatient.isFastPositive
                              ? 'Pozitif'
                              : 'Negatif',
                          valueColor:
                              provider.currentPatient.isFastPositive
                                  ? AppTheme.alertRed
                                  : null),
                      const Divider(),
                      _summaryRow(
                          'ES', '${provider.prbcCount} ünite',
                          color: AppTheme.prbcColor),
                      _summaryRow(
                          'TDP', '${provider.ffpCount} ünite',
                          color: AppTheme.ffpColor),
                      _summaryRow(
                          'TSP', '${provider.pltCount} ünite',
                          color: AppTheme.pltColor),
                      _summaryRow(
                          'KRİYO', '${provider.cryoCount} ünite',
                          color: Colors.purple[300]!),
                      _summaryRow('TOPLAM',
                          '${provider.totalProductsGiven} ünite',
                          bold: true),
                      _summaryRow('Oran',
                          '${provider.currentRatioDisplay} (Hedef: ${settings.use211Ratio ? '2:1:1' : '1:1:1'})'),
                      const Divider(),
                      _summaryRow('TXA Penceresi',
                          txaOpen ? 'AÇIK' : 'KAPALI',
                          valueColor:
                              txaOpen ? AppTheme.okGreen : AppTheme.alertRed),
                      if (provider.latestLethalTriad != null)
                        _summaryRow(
                          'Ölümcül Üçgen',
                          provider.hasLethalTriad
                              ? 'TESPİT EDİLDİ'
                              : '${provider.latestLethalTriad!.lethalTriadCount}/3',
                          valueColor: provider.hasLethalTriad
                              ? AppTheme.alertRed
                              : AppTheme.okGreen,
                        ),
                      if (provider.fibrinogenLevel != null)
                        _summaryRow(
                          'Fibrinojen',
                          '${provider.fibrinogenLevel!.toStringAsFixed(1)} g/L',
                          valueColor: provider.needsFibrinogen
                              ? AppTheme.alertRed
                              : AppTheme.okGreen,
                        ),
                      if (provider.checkWarnings() != null)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.warningOrange
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.warningOrange),
                          ),
                          child: Text(
                            provider.checkWarnings()!,
                            style: const TextStyle(
                                color: AppTheme.warningOrange,
                                fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Handover note
              const Text(
                'DEVİR NOTU',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText:
                      'Klinik durum, bekleyen işlemler, özel notlar...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.alertRed,
                  side: const BorderSide(color: AppTheme.alertRed, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _callBloodBank,
                icon: const Icon(Icons.phone),
                label: const Text('KAN BANKASINI ARA'),
              ),
              const SizedBox(height: 10),

              ElevatedButton.icon(
                onPressed: _handoverDone ? null : _completeHandover,
                icon: Icon(_handoverDone ? Icons.check_circle : Icons.handshake),
                label: Text(_handoverDone
                    ? 'DEVİR TAMAMLANDI'
                    : 'DEVİR TAMAMLANDI OLARAK İŞARETLE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _handoverDone ? AppTheme.okGreen : AppTheme.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 10),

              OutlinedButton.icon(
                onPressed: () => _shareHandover(provider),
                icon: const Icon(Icons.ios_share),
                label: const Text('PAYLAŞ (WhatsApp / Mesaj)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    Color? color,
    Color? valueColor,
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (color != null)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
