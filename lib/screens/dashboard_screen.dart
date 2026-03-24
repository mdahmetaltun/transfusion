import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';
import '../core/app_routes.dart';
import '../core/whatsapp_service.dart';
import '../providers/mtp_state_provider.dart';
import '../providers/admin_settings_provider.dart';
import '../providers/blood_product_provider.dart';

class ActiveMTPScreen extends StatefulWidget {
  const ActiveMTPScreen({super.key});

  @override
  State<ActiveMTPScreen> createState() => _ActiveMTPScreenState();
}

class _ActiveMTPScreenState extends State<ActiveMTPScreen> {
  Timer? _txaTimer;
  bool _isCalciumDialogOpen = false;
  int _lastCalciumAlertMultiple = 0;
  bool _isChecklistDialogOpen = false;

  // POC text field controllers (initialized empty; synced with provider in postFrameCallback)
  final TextEditingController _extemController = TextEditingController();
  final TextEditingController _inrController = TextEditingController();

  // Provider reference for listener management
  MtpStateProvider? _provider;

  static final Map<String, _ProductChecklistDefinition> _productChecklists = {
    'ES': const _ProductChecklistDefinition(
      productCode: 'ES',
      displayName: 'ES (Eritrosit)',
      steps: [
        'Hekim istemi ve doğru hasta/ürün eşleşmesi çift kontrol edildi.',
        'ABO-Rh ve uygunluk (cross-match) doğrulandı.',
        'Uygun transfüzyon seti ve damar yolu hazırlandı.',
        'Uygulama öncesi vital bulgular kaydedildi.',
        'İlk 15 dakika reaksiyon izlemi tamamlandı.',
        'Uygulama zamanı ve ünite kaydı sisteme işlendi.',
      ],
    ),
    'TDP': const _ProductChecklistDefinition(
      productCode: 'TDP',
      displayName: 'TDP (Plazma)',
      steps: [
        'Hekim istemi ve doğru hasta/ürün eşleşmesi doğrulandı.',
        'ABO uygunluğu kontrol edildi.',
        'Ürün hazırlığı/çözündürme süreci tamamlandı.',
        'Uygulama seti ve damar yolu hazırlandı.',
        'Transfüzyon reaksiyonu açısından izlem yapıldı.',
        'Uygulama zamanı ve ünite kaydı sisteme işlendi.',
      ],
    ),
    'TSP': const _ProductChecklistDefinition(
      productCode: 'TSP',
      displayName: 'TSP (Trombosit)',
      steps: [
        'Hekim istemi ve doğru hasta/ürün eşleşmesi doğrulandı.',
        'Ürün uygunluğu ve son kullanma tarihi kontrol edildi.',
        'Uygun set ve uygulama hattı hazırlandı.',
        'Uygulama öncesi vital bulgular kaydedildi.',
        'Uygulama sırasında reaksiyon izlemi yapıldı.',
        'Uygulama zamanı ve ünite kaydı sisteme işlendi.',
      ],
    ),
    'KRİYO': const _ProductChecklistDefinition(
      productCode: 'KRİYO',
      displayName: 'KRİYO/FİBRİNOJEN',
      steps: [
        'Hekim istemi ve endikasyon doğrulandı.',
        'Ürün hazırlığı/çözündürme süreci tamamlandı.',
        'Doğru hasta/ürün eşleşmesi kontrol edildi.',
        'Uygulama öncesi vital bulgular kaydedildi.',
        'Uygulama sırasında reaksiyon izlemi yapıldı.',
        'Uygulama zamanı ve ünite kaydı sisteme işlendi.',
      ],
    ),
  };

  @override
  void initState() {
    super.initState();

    // Timer only drives setState; actual elapsed time is computed from
    // provider.mtpActivationTime, so it survives navigation.
    _txaTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Blood bank prompt on first entry
      _promptCallBloodBank();

      // Sync POC controllers with any existing provider state
      final prov = Provider.of<MtpStateProvider>(context, listen: false);
      _extemController.text = prov.pocExtemCa5Text;
      _inrController.text = prov.pocPtInrText;

      // Listen for product count changes to trigger calcium alert
      _provider = prov;
      _provider!.addListener(_onProviderChanged);

      // Set firestore + caseId on blood product provider
      if (prov.currentCaseId != null) {
        final bp = Provider.of<BloodProductProvider>(context, listen: false);
        bp.setCaseId(prov.currentCaseId!);
      }
    });
  }

  void _onProviderChanged() {
    if (!mounted) return;
    final settings =
        Provider.of<AdminSettingsProvider>(context, listen: false).settings;
    _checkCalciumAlert(_provider!, settings.calciumUnitThreshold);
  }

  @override
  void dispose() {
    _txaTimer?.cancel();
    _provider?.removeListener(_onProviderChanged);
    _extemController.dispose();
    _inrController.dispose();
    super.dispose();
  }

  Future<void> _promptCallBloodBank() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        final settings = Provider.of<AdminSettingsProvider>(
          context,
          listen: false,
        ).settings;
        final mtpProv = Provider.of<MtpStateProvider>(context, listen: false);

        return AlertDialog(
          backgroundColor: AppTheme.alertRed,
          title: const Text(
            'MTP AKTİFLEŞTİRİLDİ',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'İlk kan setlerini istemek için Kan Bankasını hemen arayın.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child:
                  const Text('ATLA', style: TextStyle(color: Colors.white70)),
            ),
            // WhatsApp — primary CTA
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(context);
                final msg = WhatsAppService.mtpActivationMessage(
                  caseId: mtpProv.currentCaseId ?? '—',
                  location: mtpProv.caseLocation ?? '—',
                  targetRatio: settings.use211Ratio ? '2:1:1' : '1:1:1',
                );
                final sent = await WhatsAppService.sendMessage(
                  phone: settings.bloodBankPhone,
                  message: msg,
                );
                if (!sent && mounted) {
                  // Fallback: tel
                  final uri =
                      Uri(scheme: 'tel', path: settings.bloodBankPhone);
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                }
              },
              icon: const Icon(Icons.message),
              label: const Text('WHATSAPP İLE YAZI'),
            ),
            // Classic phone call — secondary
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: Colors.white70),
              onPressed: () async {
                Navigator.pop(context);
                final uri =
                    Uri(scheme: 'tel', path: settings.bloodBankPhone);
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              icon: const Icon(Icons.phone, size: 18),
              label: const Text('Ara'),
            ),
          ],
        );
      },
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
    stateProvider.logAlertFired('Kalsiyum Uyarisi ($totalProducts urun)');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(
          'KALSİYUM UYARISI',
          style: TextStyle(color: AppTheme.warningOrange),
        ),
        content: Text(
          '$totalProducts ünite kan ürünü verildi.\nHipokalsemiyi önlemek için 1 gram Kalsiyum Klorür/Glukonat uygulayın.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('ANLADIM / UYGULADIM'),
          ),
        ],
      ),
    ).then((_) {
      _isCalciumDialogOpen = false;
    });
  }

  Future<void> _confirmProductChecklistAndAdd({
    required MtpStateProvider provider,
    required String productCode,
  }) async {
    final checklist = _productChecklists[productCode];
    if (checklist == null) {
      provider.addProduct(productCode);
      return;
    }

    if (_isChecklistDialogOpen) return;
    _isChecklistDialogOpen = true;

    try {
      final completed = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => _ProductChecklistSheet(checklist: checklist),
      );

      if (!mounted || completed != true) return;

      provider.logChecklistCompletion(
        productType: checklist.productCode,
        completedSteps: checklist.steps.length,
        totalSteps: checklist.steps.length,
      );
      provider.addProduct(productCode);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${checklist.displayName} için tüm adımlar tamamlandı ve ürün kaydedildi.',
          ),
        ),
      );
    } finally {
      _isChecklistDialogOpen = false;
    }
  }

  Future<void> _callBloodBank() async {
    final settings =
        Provider.of<AdminSettingsProvider>(context, listen: false).settings;
    final mtpProv =
        Provider.of<MtpStateProvider>(context, listen: false);

    // Show choice: WhatsApp message or phone call
    if (!mounted) return;
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
                'Kan Bankası ile İletişim',
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
                  final msg = WhatsAppService.bloodBankRequestMessage(
                    caseId: mtpProv.currentCaseId ?? '—',
                    esGiven: mtpProv.prbcCount,
                    tdpGiven: mtpProv.ffpCount,
                    tspGiven: mtpProv.pltCount,
                    targetRatio: settings.use211Ratio ? '2:1:1' : '1:1:1',
                  );
                  final sent = await WhatsAppService.sendMessage(
                    phone: settings.bloodBankPhone,
                    message: msg,
                  );
                  if (!sent && mounted) {
                    final uri =
                        Uri(scheme: 'tel', path: settings.bloodBankPhone);
                    if (await canLaunchUrl(uri)) await launchUrl(uri);
                  }
                },
                icon: const Icon(Icons.message),
                label: const Text('WhatsApp ile Yaz',
                    style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.alertRed,
                  side: const BorderSide(color: AppTheme.alertRed),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  final uri =
                      Uri(scheme: 'tel', path: settings.bloodBankPhone);
                  if (await canLaunchUrl(uri)) await launchUrl(uri);
                },
                icon: const Icon(Icons.phone),
                label: const Text('Ara', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQuickProductSheet(MtpStateProvider provider) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Hızlı Ürün Ekle',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _quickProductButton(
                    'ES +1',
                    AppTheme.prbcColor,
                    () {
                      Navigator.pop(context);
                      _confirmProductChecklistAndAdd(
                          provider: provider, productCode: 'ES');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickProductButton(
                    'TDP +1',
                    AppTheme.ffpColor,
                    () {
                      Navigator.pop(context);
                      _confirmProductChecklistAndAdd(
                          provider: provider, productCode: 'TDP');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _quickProductButton(
                    'TSP +1',
                    AppTheme.pltColor,
                    () {
                      Navigator.pop(context);
                      _confirmProductChecklistAndAdd(
                          provider: provider, productCode: 'TSP');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quickProductButton(
                    'KRİYO +1',
                    Colors.purple[300]!,
                    () {
                      Navigator.pop(context);
                      _confirmProductChecklistAndAdd(
                          provider: provider, productCode: 'KRİYO');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _quickProductButton(
      String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AKTİF MTP TAKİBİ'),
        backgroundColor: AppTheme.alertRed,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
      ),
      floatingActionButton: Consumer<MtpStateProvider>(
        builder: (context, provider, child) => FloatingActionButton(
          onPressed: () => _showQuickProductSheet(provider),
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add, size: 28),
        ),
      ),
      body: Consumer<MtpStateProvider>(
        builder: (context, provider, child) {
          final settings = Provider.of<AdminSettingsProvider>(
            context,
            listen: false,
          ).settings;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Case Header Card
              _buildCaseHeaderCard(context, provider),
              const SizedBox(height: 12),
              _buildWarningsArea(context, provider),
              const SizedBox(height: 16),
              _buildTimersArea(context, provider, settings),
              const SizedBox(height: 16),
              Text(
                'RESÜSİTASYON TAKİBİ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              Text(
                "Hedef Oran: ${settings.use211Ratio ? '2:1:1' : '1:1:1'}",
                style: TextStyle(color: theme.textTheme.bodyMedium?.color),
              ),
              const SizedBox(height: 8),
              _buildProductCounter(
                title: 'ES (Eritrosit)',
                count: provider.prbcCount,
                color: AppTheme.prbcColor,
                onAdd: () => _confirmProductChecklistAndAdd(
                  provider: provider,
                  productCode: 'ES',
                ),
                onRemove: () => provider.removeProduct('ES'),
              ),
              _buildProductCounter(
                title: 'TDP (Plazma)',
                count: provider.ffpCount,
                color: AppTheme.ffpColor,
                onAdd: () => _confirmProductChecklistAndAdd(
                  provider: provider,
                  productCode: 'TDP',
                ),
                onRemove: () => provider.removeProduct('TDP'),
              ),
              _buildProductCounter(
                title: 'TSP (Trombosit)',
                count: provider.pltCount,
                color: AppTheme.pltColor,
                onAdd: () => _confirmProductChecklistAndAdd(
                  provider: provider,
                  productCode: 'TSP',
                ),
                onRemove: () => provider.removeProduct('TSP'),
              ),
              _buildProductCounter(
                title: 'KRİYO/FİBRİNOJEN',
                count: provider.cryoCount,
                color: Colors.purple[300]!,
                onAdd: () => _confirmProductChecklistAndAdd(
                  provider: provider,
                  productCode: 'KRİYO',
                ),
                onRemove: () => provider.removeProduct('KRİYO'),
              ),
              const SizedBox(height: 12),
              // Ratio compliance card
              _buildRatioComplianceCard(context, provider, settings.use211Ratio),
              const SizedBox(height: 24),

              // Clinical tools section
              _buildClinicalToolsSection(context, provider),
              const SizedBox(height: 24),

              Text(
                'Ek Yatak Başı Test (POC) Değerleri',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              _buildPOCArea(provider),
              const SizedBox(height: 32),

              // Nöbet Devri button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  side: const BorderSide(color: Colors.blue, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.shiftHandover),
                icon: const Icon(Icons.handshake_outlined),
                label: const Text(
                  'NÖBET DEVRİ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),

              // Permanent blood bank button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.alertRed,
                  side: const BorderSide(color: AppTheme.alertRed, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _callBloodBank,
                icon: const Icon(Icons.phone),
                label: const Text(
                  'KAN BANKASINI ARA',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.grey[800]
                      : const Color(0xFF44566C),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => _handleStopMTP(context, provider),
                child: const Text("MTP'Yİ DURDUR / SONLANDIR"),
              ),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildClinicalToolsSection(
      BuildContext context, MtpStateProvider provider) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'KLİNİK ARAÇLAR',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: theme.textTheme.bodyMedium?.color,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _clinicalToolButton(
                label: 'Kan Ürünü\nTakibi',
                icon: Icons.bloodtype,
                color: AppTheme.prbcColor,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.bloodProducts),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _clinicalToolButton(
                label: 'Ölümcül\nÜçgen',
                icon: Icons.warning_amber_rounded,
                color: AppTheme.alertRed,
                badge: provider.hasLethalTriad ? '!' : null,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.lethalTriad),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _clinicalToolButton(
                label: 'TEG/\nROTEM',
                icon: Icons.biotech,
                color: Colors.blue,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.tegRotem),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _clinicalToolButton(
                label: 'Doz\nHesaplama',
                icon: Icons.calculate,
                color: AppTheme.okGreen,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.dosingCalc),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _clinicalToolButton(
                label: 'Antikoagülan\nReversal',
                icon: Icons.medication,
                color: Colors.purple,
                onTap: () =>
                    Navigator.pushNamed(context, AppRoutes.reversalGuide),
              ),
            ),
            const SizedBox(width: 8),
            // Blood product expiry badge
            Expanded(
              child: Consumer<BloodProductProvider>(
                builder: (context, bp, child) {
                  final expiringCount = bp.expiringSoon.length;
                  return _clinicalToolButton(
                    label: 'Ürün\nUyarısı',
                    icon: Icons.schedule_outlined,
                    color: expiringCount > 0
                        ? AppTheme.warningOrange
                        : Colors.grey,
                    badge: expiringCount > 0 ? '$expiringCount' : null,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.bloodProducts),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _clinicalToolButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? badge,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppTheme.alertRed,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseHeaderCard(
    BuildContext context,
    MtpStateProvider provider,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Card(
      color: isDark ? Colors.blueGrey[900] : const Color(0xFFEAF2FB),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    provider.currentCaseId ?? '—',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : AppTheme.lightSubTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Toplam Ürün: ${provider.totalProductsGiven}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.lightTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Süre',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : AppTheme.lightSubTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  provider.mtpDurationFormatted,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.lightTextColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWarningsArea(BuildContext context, MtpStateProvider provider) {
    final warning = provider.checkWarnings();
    final lethalTriadWarning = provider.lethalTriadWarning;

    final widgets = <Widget>[];

    if (warning != null) {
      final isLethalTriad = provider.hasLethalTriad;
      widgets.add(
        Card(
          color: isLethalTriad
              ? AppTheme.alertRed.withValues(alpha: 0.9)
              : AppTheme.warningOrange.withValues(alpha: 0.85),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(
                  isLethalTriad
                      ? Icons.dangerous
                      : Icons.warning_amber_rounded,
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
        ),
      );
    } else if (lethalTriadWarning != null) {
      widgets.add(
        Card(
          color: AppTheme.warningOrange.withValues(alpha: 0.85),
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
                    lethalTriadWarning,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Blood product expiry warnings
    final bp = Provider.of<BloodProductProvider>(context, listen: false);
    final expiring = bp.expiringSoon;
    final expired = bp.expiredNotAdministered;

    if (expired.isNotEmpty) {
      widgets.add(
        Card(
          color: AppTheme.alertRed.withValues(alpha: 0.85),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Icon(Icons.timer_off, size: 28, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${expired.length} kan ürününün son kullanma tarihi geçmiş!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (expiring.isNotEmpty) {
      widgets.add(
        Card(
          color: AppTheme.warningOrange.withValues(alpha: 0.85),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                const Icon(Icons.schedule, size: 28, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${expiring.length} kan ürününün son kullanma tarihi 24 saat içinde dolacak!',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (widgets.isEmpty) return const SizedBox.shrink();

    return Column(
      children: widgets
          .map((w) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: w,
              ))
          .toList(),
    );
  }

  Widget _buildTimersArea(
    BuildContext context,
    MtpStateProvider provider,
    SettingsModel settings,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Compute TXA remaining from provider's activation time (survives navigation)
    final txaWindowSeconds = settings.txaWindowHours * 3600;
    int txaElapsed = 0;
    if (provider.mtpActivationTime != null) {
      txaElapsed =
          DateTime.now().difference(provider.mtpActivationTime!).inSeconds;
    }
    int txaRemaining = txaWindowSeconds - txaElapsed;
    if (txaRemaining < 0) txaRemaining = 0;

    final progress = txaWindowSeconds > 0
        ? txaRemaining / txaWindowSeconds
        : 0.0;
    final isLow = progress < 0.25;

    String formatTime(int seconds) {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      final s = seconds % 60;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }

    final panelColor = isDark ? Colors.blueGrey[900]! : const Color(0xFFEAF2FB);
    final primaryText = isDark ? Colors.white : AppTheme.lightTextColor;
    final secondaryText = isDark ? Colors.white70 : AppTheme.lightSubTextColor;
    final timerColor = txaRemaining == 0
        ? Colors.red
        : (isLow ? Colors.red : AppTheme.okGreen);

    return Card(
      color: panelColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                // Circular TXA timer
                SizedBox(
                  width: 64,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: Colors.grey.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(timerColor),
                      ),
                      Text(
                        txaRemaining == 0 ? 'BİTTİ' : formatTime(txaRemaining),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: txaRemaining == 0 ? 8 : 9,
                          fontWeight: FontWeight.bold,
                          color: timerColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TXA Penceresi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryText,
                        ),
                      ),
                      Text(
                        'İlk ${settings.txaWindowHours} saat içinde verin',
                        style: TextStyle(fontSize: 13, color: secondaryText),
                      ),
                      if (txaRemaining == 0)
                        const Text(
                          'TXA PENCERESİ KAPANDI',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Hipotermi Kontrolü:',
                    style: TextStyle(fontSize: 16, color: primaryText),
                  ),
                ),
                const SizedBox(width: 12),
                const Flexible(
                  child: Text(
                    'VÜCUT ISISI > 37°C TUTUN',
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
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '(Hedef normotermi)',
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 12, color: secondaryText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatioComplianceCard(
    BuildContext context,
    MtpStateProvider provider,
    bool use211,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCompliant = provider.isRatioCompliant(use211);
    final targetLabel = use211 ? '2:1:1' : '1:1:1';
    final currentLabel = provider.currentRatioDisplay;

    final cardColor = isCompliant
        ? AppTheme.okGreen.withValues(alpha: isDark ? 0.2 : 0.08)
        : AppTheme.alertRed.withValues(alpha: isDark ? 0.25 : 0.08);
    final borderColor = isCompliant
        ? AppTheme.okGreen.withValues(alpha: 0.5)
        : AppTheme.alertRed.withValues(alpha: 0.5);
    final labelColor = isCompliant ? AppTheme.okGreen : AppTheme.alertRed;

    return Card(
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(
              isCompliant ? Icons.check_circle : Icons.warning_amber_rounded,
              color: labelColor,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ES:TDP:TSP = $currentLabel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
                    ),
                  ),
                  Text(
                    'Hedef oran: $targetLabel',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            if (!isCompliant)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.alertRed,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'ORAN\nUYARISI',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCounter({
    required String title,
    required int count,
    required Color color,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Container(width: 8, height: 40, color: color),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.titleLarge?.color,
                ),
              ),
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: onRemove,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  iconSize: 32,
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    count.toString(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.titleLarge?.color,
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
            controller: _extemController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'EXTEM CA5 (Hedef >35)',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              provider.updatePOCText(extemCa5: val);
              final parsed = double.tryParse(val);
              if (parsed != null) {
                provider.updatePOC(parsed, provider.ptInr);
              }
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: _inrController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'PT/INR',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              provider.updatePOCText(ptInr: val);
              final parsed = double.tryParse(val);
              if (parsed != null) {
                provider.updatePOC(provider.rotumExTemCa5, parsed);
              }
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
        title: const Text('MTP Durdurulsun mu?'),
        content: const Text(
          'Vakayı sonlandırıp özet ekranına gitmek istediğinize emin misiniz? (Loglar bu vaka için kapatılacaktır.)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İPTAL'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacementNamed(context, '/summary');
            },
            child: const Text('SONLANDIR VE ÖZETİ GÖR'),
          ),
        ],
      ),
    );
  }
}

class _ProductChecklistDefinition {
  final String productCode;
  final String displayName;
  final List<String> steps;

  const _ProductChecklistDefinition({
    required this.productCode,
    required this.displayName,
    required this.steps,
  });
}

class _ProductChecklistSheet extends StatefulWidget {
  final _ProductChecklistDefinition checklist;

  const _ProductChecklistSheet({required this.checklist});

  @override
  State<_ProductChecklistSheet> createState() => _ProductChecklistSheetState();
}

class _ProductChecklistSheetState extends State<_ProductChecklistSheet> {
  late final List<bool> _done;

  @override
  void initState() {
    super.initState();
    _done = List<bool>.filled(widget.checklist.steps.length, false);
  }

  int get _completedCount => _done.where((isDone) => isDone).length;
  bool get _allCompleted => _completedCount == _done.length;

  @override
  Widget build(BuildContext context) {
    final progress = _done.isEmpty ? 0.0 : _completedCount / _done.length;

    return Container(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${widget.checklist.displayName} Uygulama Kontrolü',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context, false),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Ürün kaydı yapılmadan önce tüm adımları tamamlayın.',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Tamamlanan: $_completedCount/${_done.length}'),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.checklist.steps.length,
                itemBuilder: (context, index) {
                  return CheckboxListTile(
                    value: _done[index],
                    onChanged: (checked) {
                      setState(() {
                        _done[index] = checked ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(widget.checklist.steps[index]),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('İptal'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _allCompleted
                        ? () => Navigator.pop(context, true)
                        : null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('TÜM ADIMLAR TAMAM'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
