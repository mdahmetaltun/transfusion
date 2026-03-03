import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/theme.dart';
import '../providers/mtp_state_provider.dart';

class EndCaseScreen extends StatefulWidget {
  const EndCaseScreen({super.key});

  @override
  State<EndCaseScreen> createState() => _EndCaseScreenState();
}

class _EndCaseScreenState extends State<EndCaseScreen> {
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _exportAndFinish(MtpStateProvider provider) {
    // Generate text dump of the case
    final buffer = StringBuffer();
    buffer.writeln('=== MTP VAKA ÖZETİ ===');
    buffer.writeln('Vaka ID: ${provider.currentCaseId ?? 'Bilinmiyor'}');
    buffer.writeln('Lokasyon: ${provider.caseLocation ?? 'Bilinmiyor'}');
    buffer.writeln('Tarih: ${DateTime.now().toString()}');
    buffer.writeln('Klinik Not: ${_notesController.text}');
    buffer.writeln('-----------------------');
    buffer.writeln('TOPLAM VERİLEN ÜRÜNLER:');
    buffer.writeln('Eritrosit (ES): ${provider.prbcCount}');
    buffer.writeln('Plazma (TDP): ${provider.ffpCount}');
    buffer.writeln('Trombosit (TSP): ${provider.pltCount}');
    buffer.writeln('Kriyo/Fibrinojen: ${provider.cryoCount}');
    buffer.writeln('-----------------------');
    buffer.writeln('OLAY LOGLARI (EVENT SOURCING):');
    for (var event in provider.events) {
      buffer.writeln(event.toString());
    }

    // Attempt local share via system
    Share.share(
      buffer.toString(),
      subject: 'MTP Vaka Raporu: ${provider.currentCaseId}',
    );

    // Close in provider and navigate to start
    provider.closeCase(_notesController.text);
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil('/splash', (Route<dynamic> route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MtpStateProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vaka Özeti ve Dışa Aktar'),
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 80,
              color: AppTheme.okGreen,
            ),
            const SizedBox(height: 16),
            Text(
              'MTP VAKASI SONLANDIRILDI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.textTheme.headlineMedium?.color,
              ),
            ),
            const SizedBox(height: 24),
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
                  children: [
                    Text(
                      "Harekete Geçilen Vaka: ${provider.currentCaseId ?? 'TRM-XX'}",
                      style: TextStyle(
                        fontSize: 18,
                        color: theme.textTheme.bodyMedium?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toplam Verilen Ürün: ${provider.totalProductsGiven}',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ES: ${provider.prbcCount} | TDP: ${provider.ffpCount} | TSP: ${provider.pltCount} | KRIYO: ${provider.cryoCount}',
                      style: TextStyle(
                        fontSize: 16,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
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
            const Spacer(),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => _exportAndFinish(provider),
              icon: const Icon(Icons.share),
              label: const Text(
                'LOGLARI DIŞA AKTAR VE BAŞA DÖN',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
