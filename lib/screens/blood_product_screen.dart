import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/theme.dart';
import '../models/blood_product_unit.dart';
import '../providers/blood_product_provider.dart';
import '../providers/mtp_state_provider.dart';
import '../services/firestore_service.dart';
import 'blood_product_entry_screen.dart';

class BloodProductScreen extends StatelessWidget {
  const BloodProductScreen({super.key});

  Color _productColor(BloodProductType type) {
    switch (type) {
      case BloodProductType.ES:
        return AppTheme.prbcColor;
      case BloodProductType.TDP:
        return AppTheme.ffpColor;
      case BloodProductType.TSP:
        return AppTheme.pltColor;
      case BloodProductType.KRIYO:
        return Colors.purple[300]!;
    }
  }

  Color _statusColor(ProductStatus status) {
    switch (status) {
      case ProductStatus.registered:
        return Colors.blue;
      case ProductStatus.received:
        return AppTheme.warningOrange;
      case ProductStatus.administered:
        return AppTheme.okGreen;
      case ProductStatus.returned:
        return Colors.grey;
      case ProductStatus.wasted:
        return AppTheme.alertRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<BloodProductProvider, MtpStateProvider>(
      builder: (context, bp, mtp, child) {
        final units = bp.units;
        final expiring = bp.expiringSoon;
        final expired = bp.expiredNotAdministered;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Kan Ürünü Takibi'),
                const SizedBox(width: 8),
                if (units.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${units.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openEntrySheet(context, mtp),
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Ürün Ekle'),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              if (mtp.currentCaseId != null) {
                await bp.loadForCase(
                    mtp.currentCaseId!, FirestoreService());
              }
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSummaryBar(context, bp),
                const SizedBox(height: 12),
                if (expired.isNotEmpty) ...[
                  _buildExpiryAlerts(context, expired, true),
                  const SizedBox(height: 8),
                ],
                if (expiring.isNotEmpty) ...[
                  _buildExpiryAlerts(context, expiring, false),
                  const SizedBox(height: 8),
                ],
                if (units.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'Henüz kayıtlı ürün yok.\nSağ alttaki "+" ile ekleyin.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else ...[
                  _buildGroupedList(
                      context, bp, mtp, ProductStatus.registered, 'KAYITLI'),
                  _buildGroupedList(
                      context, bp, mtp, ProductStatus.received, 'ALINDI'),
                  _buildGroupedList(context, bp, mtp,
                      ProductStatus.administered, 'UYGULANDILAR'),
                  _buildGroupedList(
                      context, bp, mtp, ProductStatus.wasted, 'İMHA'),
                  _buildGroupedList(
                      context, bp, mtp, ProductStatus.returned, 'İADE'),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openEntrySheet(BuildContext context, MtpStateProvider mtp) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => BloodProductEntrySheet(
        caseId: mtp.currentCaseId ?? 'UNKNOWN',
        patientBloodGroup: mtp.patientBloodGroup,
      ),
    );
  }

  Widget _buildSummaryBar(BuildContext context, BloodProductProvider bp) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final counts = {
      'ES': {'registered': 0, 'received': 0, 'administered': 0},
      'TDP': {'registered': 0, 'received': 0, 'administered': 0},
      'TSP': {'registered': 0, 'received': 0, 'administered': 0},
      'KRIYO': {'registered': 0, 'received': 0, 'administered': 0},
    };

    for (final u in bp.units) {
      final key = u.productTypeShortLabel;
      if (!counts.containsKey(key)) continue;
      if (u.status == ProductStatus.registered) {
        counts[key]!['registered'] = (counts[key]!['registered'] ?? 0) + 1;
      } else if (u.status == ProductStatus.received) {
        counts[key]!['received'] = (counts[key]!['received'] ?? 0) + 1;
      } else if (u.status == ProductStatus.administered) {
        counts[key]!['administered'] = (counts[key]!['administered'] ?? 0) + 1;
      }
    }

    return Card(
      color: isDark ? Colors.blueGrey[900] : const Color(0xFFEAF2FB),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ÖZET',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Row(
              children: counts.entries.map((e) {
                final reg = e.value['registered'] ?? 0;
                final rec = e.value['received'] ?? 0;
                final adm = e.value['administered'] ?? 0;
                final color = _productColorByKey(e.key);
                return Expanded(
                  child: Column(
                    children: [
                      Text(e.key,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 13)),
                      const SizedBox(height: 4),
                      Text('$adm uyg.',
                          style: const TextStyle(fontSize: 11)),
                      Text('$rec alındı',
                          style: const TextStyle(fontSize: 11)),
                      Text('$reg kayıtlı',
                          style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Color _productColorByKey(String key) {
    switch (key) {
      case 'ES':
        return AppTheme.prbcColor;
      case 'TDP':
        return AppTheme.ffpColor;
      case 'TSP':
        return AppTheme.pltColor;
      default:
        return Colors.purple[300]!;
    }
  }

  Widget _buildExpiryAlerts(
      BuildContext context, List<BloodProductUnit> units, bool isExpired) {
    final color = isExpired ? AppTheme.alertRed : AppTheme.warningOrange;
    final label = isExpired ? 'SON KULLANMA TARİHİ GEÇMİŞ' : 'SON KULLANMA YAKINLAŞIYOR';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 18),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 13),
            ),
          ],
        ),
        ...units.map((u) => Card(
              color: color.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: color.withValues(alpha: 0.4)),
              ),
              child: ListTile(
                dense: true,
                leading: Icon(Icons.bloodtype, color: _productColor(u.productType)),
                title: Text('${u.productTypeShortLabel} — ${u.barcode}'),
                subtitle: Text(
                    'SKT: ${DateFormat('dd.MM.yyyy HH:mm').format(u.expiryDate)}'),
                trailing: Text(
                  u.bloodGroupLabel +
                      (u.rhFactor != RhFactor.unknown ? u.rhFactorLabel : ''),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildGroupedList(
    BuildContext context,
    BloodProductProvider bp,
    MtpStateProvider mtp,
    ProductStatus status,
    String label,
  ) {
    final filtered = bp.units.where((u) => u.status == status).toList();
    if (filtered.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '$label (${filtered.length})',
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
          ),
        ),
        ...filtered.map((u) => _buildUnitCard(context, u, bp)),
        const SizedBox(height: 4),
      ],
    );
  }

  Widget _buildUnitCard(
    BuildContext context,
    BloodProductUnit unit,
    BloodProductProvider bp,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final productColor = _productColor(unit.productType);
    final statusColor = _statusColor(unit.status);
    final isExpiredOrExpiring = unit.isExpired || unit.isExpiringSoon;
    final expiryColor = unit.isExpired
        ? AppTheme.alertRed
        : (unit.isExpiringSoon ? AppTheme.warningOrange : theme.textTheme.bodyMedium?.color);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 6,
              decoration: BoxDecoration(
                color: productColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          unit.productTypeShortLabel,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: productColor,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          unit.barcode,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.5)),
                          ),
                          child: Text(
                            unit.statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Lot: ${unit.lotNumber}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          isExpiredOrExpiring
                              ? Icons.warning_amber_rounded
                              : Icons.schedule,
                          size: 13,
                          color: expiryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'SKT: ${DateFormat('dd.MM.yy HH:mm').format(unit.expiryDate)}',
                          style: TextStyle(fontSize: 12, color: expiryColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (unit.bloodGroup != BloodGroup.unknown)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.blueGrey[800]
                                  : Colors.blue[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              unit.bloodGroupLabel +
                                  (unit.rhFactor != RhFactor.unknown
                                      ? ' ${unit.rhFactorLabel}'
                                      : ''),
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        const Spacer(),
                        if (unit.status == ProductStatus.registered) ...[
                          _actionButton(
                            'Alındı',
                            AppTheme.warningOrange,
                            () => bp.markReceived(unit.id),
                          ),
                          const SizedBox(width: 6),
                          _actionButton(
                            'Uygulandı',
                            AppTheme.okGreen,
                            () => bp.markAdministered(unit.id),
                          ),
                          const SizedBox(width: 6),
                          _actionButton(
                            'İptal',
                            Colors.grey,
                            () => _confirmWaste(context, unit, bp),
                          ),
                        ] else if (unit.status == ProductStatus.received) ...[
                          _actionButton(
                            'Uygulandı',
                            AppTheme.okGreen,
                            () => bp.markAdministered(unit.id),
                          ),
                          const SizedBox(width: 6),
                          _actionButton(
                            'İptal',
                            Colors.grey,
                            () => _confirmWaste(context, unit, bp),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  void _confirmWaste(
      BuildContext context, BloodProductUnit unit, BloodProductProvider bp) {
    showDialog(
      context: context,
      builder: (_) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('İmha / İptal'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'İmha nedeni (opsiyonel)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İPTAL'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.alertRed),
              onPressed: () {
                bp.markWasted(unit.id, controller.text);
                Navigator.pop(context);
              },
              child: const Text('İMHA ET'),
            ),
          ],
        );
      },
    );
  }
}
