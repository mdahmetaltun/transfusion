import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../providers/mtp_state_provider.dart';
import '../providers/admin_settings_provider.dart';

class ActiveMTPScreen extends StatefulWidget {
  const ActiveMTPScreen({super.key});

  @override
  State<ActiveMTPScreen> createState() => _ActiveMTPScreenState();
}

class _ActiveMTPScreenState extends State<ActiveMTPScreen> {
  Timer? _txaTimer;
  int _txaSecondsElapsed = 0;
  bool _isCalciumDialogOpen = false;
  int _lastCalciumAlertMultiple = 0;

  @override
  void initState() {
    super.initState();
    // Start TXA 3-hour timer (10800 seconds)
    _txaTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _txaSecondsElapsed++;
        });
      }
    });

    // Module 3: Prompt to call blood bank IMMEDIATELY on activation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _promptCallBloodBank();
    });
  }

  @override
  void dispose() {
    _txaTimer?.cancel();
    super.dispose();
  }

  Future<void> _promptCallBloodBank() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.alertRed,
        title: const Text(
          "MTP AKTİFLEŞTİRİLDİ",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          "İlk kan setlerini istemek için Kan Bankasını hemen arayın.",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("ATLA", style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              Navigator.pop(context);
              final phone = Provider.of<AdminSettingsProvider>(
                context,
                listen: false,
              ).settings.bloodBankPhone;
              final Uri phoneUri = Uri(scheme: 'tel', path: phone);
              if (await canLaunchUrl(phoneUri)) {
                await launchUrl(phoneUri);
              }
            },
            icon: const Icon(Icons.phone),
            label: const Text("KAN BANKASINI ARA"),
          ),
        ],
      ),
    );
  }

  void _checkCalciumAlert(MtpStateProvider stateProvider, int threshold) {
    if (threshold <= 0) return;

    final totalProducts = stateProvider.totalProductsGiven;
    final isTriggerPoint = totalProducts > 0 && totalProducts % threshold == 0;
    final currentMultiple = totalProducts ~/ threshold;

    if (!isTriggerPoint) return;
    if (_isCalciumDialogOpen) return;
    if (currentMultiple <= _lastCalciumAlertMultiple) return;

    _isCalciumDialogOpen = true;
    _lastCalciumAlertMultiple = currentMultiple;
    stateProvider.logAlertFired("Kalsiyum Uyarisi ($totalProducts urun)");

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          "KALSİYUM UYARISI",
          style: TextStyle(color: AppTheme.warningOrange),
        ),
        content: Text(
          "$totalProducts ünite kan ürünü verildi.\nHipokalsemiyi önlemek için 1 gram Kalsiyum Klorür/Glukonat uygulayın.",
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text("ANLADIM / UYGULADIM"),
          ),
        ],
      ),
    ).then((_) {
      _isCalciumDialogOpen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AKTİF MTP TAKİBİ'),
        backgroundColor: AppTheme.alertRed,
        automaticallyImplyLeading: false, // Prevent accidental back navigation
      ),
      body: Consumer<MtpStateProvider>(
        builder: (context, provider, child) {
          final settings = Provider.of<AdminSettingsProvider>(
            context,
            listen: false,
          ).settings;

          WidgetsBinding.instance.addPostFrameCallback((_) {
            _checkCalciumAlert(provider, settings.calciumUnitThreshold);
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildWarningsArea(provider),
              const SizedBox(height: 16),

              _buildTimersArea(),
              const SizedBox(height: 16),

              const Text(
                "RESÜSİTASYON TAKİBİ",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                "Hedef Oran: ${settings.use211Ratio ? '2:1:1' : '1:1:1'}",
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 8),
              _buildProductCounter(
                "ES (Eritrosit)",
                provider.prbcCount,
                AppTheme.prbcColor,
                () => provider.addProduct('ES'),
                () => provider.removeProduct('ES'),
              ),
              _buildProductCounter(
                "TDP (Plazma)",
                provider.ffpCount,
                AppTheme.ffpColor,
                () => provider.addProduct('TDP'),
                () => provider.removeProduct('TDP'),
              ),
              _buildProductCounter(
                "TSP (Trombosit)",
                provider.pltCount,
                AppTheme.pltColor,
                () => provider.addProduct('TSP'),
                () => provider.removeProduct('TSP'),
              ),
              _buildProductCounter(
                "KRİYO/FİBRİNOJEN",
                provider.cryoCount,
                Colors.purple[300]!,
                () => provider.addProduct('KRİYO'),
                () => provider.removeProduct('KRİYO'),
              ),

              const SizedBox(height: 24),
              // Module 5: POC Integration
              const Text(
                "Ek Yatak Başı Test (POC) Değerleri",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              _buildPOCArea(provider),

              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                ),
                onPressed: () => _handleStopMTP(context, provider),
                child: const Text("MTP'Yİ DURDUR / SONLANDIR"),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildWarningsArea(MtpStateProvider provider) {
    final warning = provider.checkWarnings();
    if (warning == null) return const SizedBox.shrink();

    return Card(
      color: AppTheme.warningOrange.withOpacity(0.8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              size: 36,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                warning,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimersArea() {
    // 3 hours = 10800 seconds
    int txaRemaining = 10800 - _txaSecondsElapsed;
    if (txaRemaining < 0) txaRemaining = 0;

    String formatTime(int seconds) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      final s = seconds % 60;
      return "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    }

    return Card(
      color: Colors.blueGrey[900],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    "TXA Penceresi (İlk 3 Saat):",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatTime(txaRemaining),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: txaRemaining == 0 ? Colors.red : AppTheme.okGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Expanded(
                  child: Text(
                    "Hipotermi Kontrolü:",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                SizedBox(width: 12),
                Flexible(
                  child: Text(
                    "VÜCUT ISISI > 37°C TUTUN",
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerRight,
              child: Text(
                "(Hedef normotermi)",
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCounter(
    String title,
    int count,
    Color color,
    VoidCallback onAdd,
    VoidCallback onRemove,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(width: 8, height: 40, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: onRemove,
                  color: Colors.white54,
                  iconSize: 32,
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    count.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.add_circle,
                    color: AppTheme.primaryColor,
                  ),
                  onPressed: onAdd,
                  iconSize: 40,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPOCArea(MtpStateProvider provider) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'EXTEM CA5 (Hedef >35)',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              if (double.tryParse(val) != null)
                provider.updatePOC(double.parse(val), provider.ptInr);
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'PT/INR',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              if (double.tryParse(val) != null)
                provider.updatePOC(provider.rotumExTemCa5, double.parse(val));
            },
          ),
        ),
      ],
    );
  }

  void _handleStopMTP(BuildContext context, MtpStateProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("MTP Durdurulsun mu?"),
        content: const Text(
          "Vakayı sonlandırıp özet ekranına gitmek istediğinize emin misiniz? (Loglar bu vaka için kapatılacaktır.)",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("İPTAL"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacementNamed(context, '/summary');
            },
            child: const Text("SONLANDIR VE ÖZETİ GÖR"),
          ),
        ],
      ),
    );
  }
}
