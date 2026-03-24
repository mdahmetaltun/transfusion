import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class MtpHistoryScreen extends StatefulWidget {
  const MtpHistoryScreen({super.key});

  @override
  State<MtpHistoryScreen> createState() => _MtpHistoryScreenState();
}

class _MtpHistoryScreenState extends State<MtpHistoryScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUid = authService.currentFirebaseUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('MTP Kayıtları')),
      body: currentUid == null
          ? const Center(
              child: Text('Kayıtları görmek için geçerli bir oturum gerekli.'),
            )
          : Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 10, 16, 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bu cihazda sadece sizin oluşturduğunuz vakalar listelenir.',
                    ),
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestoreService.watchCasesByCreator(currentUid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Text('Kayıtlar alınamadı: ${snapshot.error}'),
                        );
                      }

                      final docs = snapshot.data?.docs ?? [];

                      docs.sort((a, b) {
                        final bDate = _parseDate(b.data()['createdAt']);
                        final aDate = _parseDate(a.data()['createdAt']);
                        return bDate.compareTo(aDate);
                      });

                      if (docs.isEmpty) {
                        return const Center(
                          child: Text('Size ait MTP kaydı bulunamadı.'),
                        );
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data();
                          final caseId = (data['caseId'] ?? docs[index].id)
                              .toString();
                          final location = (data['location'] ?? 'Bilinmiyor')
                              .toString();
                          final status = (data['status'] ?? 'Bilinmiyor')
                              .toString();
                          final caseFacility =
                              (data['facilityId'] ?? 'Bilinmiyor').toString();
                          final totalProducts = data['totalProducts'];

                          final createdAt = _formatDate(data['createdAt']);
                          final closedAt = _formatDate(data['closedAt']);

                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              title: Text(
                                caseId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Lokasyon: $location'),
                                    Text('Durum: $status'),
                                    Text('Kurum: $caseFacility'),
                                    Text('Başlangıç: $createdAt'),
                                    Text('Bitiş: $closedAt'),
                                    Text(
                                      'Toplam Ürün: ${totalProducts ?? 'Henüz kapanmadı'}',
                                    ),
                                  ],
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MtpCaseDetailScreen(
                                      caseId: caseId,
                                      caseData: data,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _formatDate(dynamic raw) {
    final date = _parseDate(raw);
    if (date.millisecondsSinceEpoch == 0) return 'Bilinmiyor';
    return DateFormat('dd.MM.yyyy HH:mm').format(date.toLocal());
  }
}

class MtpCaseDetailScreen extends StatelessWidget {
  final String caseId;
  final Map<String, dynamic> caseData;

  const MtpCaseDetailScreen({
    super.key,
    required this.caseId,
    required this.caseData,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final theme = Theme.of(context);
    final status = (caseData['status'] ?? 'Bilinmiyor').toString();
    final location = (caseData['location'] ?? 'Bilinmiyor').toString();
    final facility = (caseData['facilityId'] ?? 'Bilinmiyor').toString();
    final totalProducts = '${caseData['totalProducts'] ?? '-'}';
    final notes = (caseData['notes'] ?? '').toString().trim();
    final abcSummary = caseData['abcSummary'];
    final createdAt = _formatCaseTime(caseData['createdAt']);
    final closedAt = _formatCaseTime(caseData['closedAt']);
    final statusColor = _statusColor(status);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Vaka Detayı')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestoreService.watchCaseEvents(caseId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Event logları alınamadı: ${snapshot.error}'),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isDark
                                ? const [Color(0xFF2A2F36), Color(0xFF1E232A)]
                                : const [Color(0xFFF8FBFF), Color(0xFFEFF5FB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              caseId,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildTag(
                                  context,
                                  label: status,
                                  color: statusColor,
                                  icon: status.toUpperCase() == 'CLOSED'
                                      ? Icons.check_circle_outline
                                      : Icons.timelapse,
                                ),
                                _buildTag(
                                  context,
                                  label: 'Kurum: $facility',
                                  color: theme.colorScheme.primary,
                                  icon: Icons.local_hospital_outlined,
                                ),
                                _buildTag(
                                  context,
                                  label: 'Lokasyon: $location',
                                  color: const Color(0xFF607D8B),
                                  icon: Icons.place_outlined,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text('Başlangıç: $createdAt'),
                            Text('Kapanış: $closedAt'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              title: 'Toplam Ürün',
                              value: totalProducts,
                              icon: Icons.bloodtype_outlined,
                              color: const Color(0xFFB71C1C),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildMetricCard(
                              context,
                              title: 'Event Sayısı',
                              value: docs.length.toString(),
                              icon: Icons.timeline,
                              color: const Color(0xFF1565C0),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (abcSummary is Map<String, dynamic>)
                        _buildAbcSummaryCard(context, abcSummary)
                      else if (abcSummary is Map)
                        _buildAbcSummaryCard(
                          context,
                          Map<String, dynamic>.from(abcSummary),
                        ),
                      const SizedBox(height: 10),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Klinik Not',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(notes.isEmpty ? 'Not girilmemiş.' : notes),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Olay Akışı',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
              if (docs.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Bu vaka için event kaydı yok.')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final data = docs[index].data();
                      final type = (data['type'] ?? 'unknown').toString();
                      final time = _formatEventTime(data['timestamp']);
                      final payload = data['payload'];
                      final eventColor = _eventColor(type);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: eventColor.withValues(
                                          alpha: 0.14,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        _eventIcon(type),
                                        color: eventColor,
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _eventLabel(type),
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            time,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                if (payload is Map && payload.isNotEmpty) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.black12
                                          : const Color(0xFFF4F7FB),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: payload.entries.map((entry) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 4,
                                          ),
                                          child: Text(
                                            '${_prettifyKey(entry.key.toString())}: ${entry.value}',
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    }, childCount: docs.length),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  static Widget _buildTag(
    BuildContext context, {
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildMetricCard(
    BuildContext context, {
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildAbcSummaryCard(
    BuildContext context,
    Map<String, dynamic> abcSummary,
  ) {
    final theme = Theme.of(context);
    final score = abcSummary['score'];
    final risk = (abcSummary['riskLevel'] ?? '-').toString().toUpperCase();
    final hr = abcSummary['heartRate'];
    final sbp = abcSummary['systolicBp'];
    final pointsRaw = abcSummary['criteriaPoints'];
    final points = pointsRaw is Map
        ? Map<String, dynamic>.from(pointsRaw)
        : <String, dynamic>{};

    String pointLabel(String key) => (points[key] ?? 0).toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.query_stats, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'ABC Skoru Detayı',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text('Toplam Skor: $score'),
            Text('Risk Seviyesi: $risk'),
            Text('Nabız: $hr'),
            Text('Sistolik Tansiyon: $sbp'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.dividerColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('HR >= 120 puanı: ${pointLabel('heartRateGte120')}'),
                  Text('SKB <= 90 puanı: ${pointLabel('systolicBpLte90')}'),
                  Text(
                    'Penetran mekanizma puanı: ${pointLabel('penetratingMechanism')}',
                  ),
                  Text('FAST pozitif puanı: ${pointLabel('fastPositive')}'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'CLOSED':
        return const Color(0xFF2E7D32);
      case 'ACTIVE':
        return const Color(0xFFEF6C00);
      default:
        return const Color(0xFF546E7A);
    }
  }

  static Color _eventColor(String type) {
    switch (type) {
      case 'mtpActivated':
        return const Color(0xFFB71C1C);
      case 'productAdded':
        return const Color(0xFF2E7D32);
      case 'productRemoved':
        return const Color(0xFFE65100);
      case 'alertFired':
        return const Color(0xFFED6C02);
      case 'caseClosed':
        return const Color(0xFF1565C0);
      default:
        return const Color(0xFF455A64);
    }
  }

  static IconData _eventIcon(String type) {
    switch (type) {
      case 'caseCreated':
        return Icons.playlist_add_check_circle_outlined;
      case 'mtpActivated':
        return Icons.emergency_outlined;
      case 'productAdded':
        return Icons.add_circle_outline;
      case 'productRemoved':
        return Icons.remove_circle_outline;
      case 'alertFired':
        return Icons.warning_amber_rounded;
      case 'pocResultRecorded':
        return Icons.science_outlined;
      case 'caseClosed':
        return Icons.task_alt;
      default:
        return Icons.event_note;
    }
  }

  static String _eventLabel(String type) {
    switch (type) {
      case 'caseCreated':
        return 'Vaka Oluşturuldu';
      case 'triageUpdated':
        return 'Triyaj Güncellendi';
      case 'gestaltRecorded':
        return 'Ön Karar Kaydedildi';
      case 'mtpActivated':
        return 'MTP Aktifleştirildi';
      case 'mtpNotActivated':
        return 'MTP Aktifleştirilmedi';
      case 'productAdded':
        return 'Kan Ürünü Eklendi';
      case 'productRemoved':
        return 'Kan Ürünü Geri Alındı';
      case 'alertFired':
        return 'Uyarı Oluştu';
      case 'pocResultRecorded':
        return 'POC Sonucu Kaydedildi';
      case 'checklistItemToggled':
        return 'Checklist Tamamlandı';
      case 'caseClosed':
        return 'Vaka Kapatıldı';
      default:
        return _prettifyKey(type);
    }
  }

  static String _formatCaseTime(dynamic raw) {
    final date = _parseDate(raw);
    if (date.millisecondsSinceEpoch == 0) return 'Bilinmiyor';
    return DateFormat('dd.MM.yyyy HH:mm').format(date.toLocal());
  }

  static DateTime _parseDate(dynamic raw) {
    if (raw is Timestamp) return raw.toDate();
    if (raw is String) {
      return DateTime.tryParse(raw) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  static String _formatEventTime(dynamic raw) {
    if (raw is Timestamp) {
      return DateFormat('dd.MM.yyyy HH:mm:ss').format(raw.toDate().toLocal());
    }
    if (raw is String) {
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) {
        return DateFormat('dd.MM.yyyy HH:mm:ss').format(parsed.toLocal());
      }
      return raw;
    }
    return 'Zaman bilinmiyor';
  }

  static String _prettifyKey(String key) {
    final withSpaces = key
        .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .replaceAll('_', ' ')
        .trim();

    if (withSpaces.isEmpty) return key;
    return withSpaces[0].toUpperCase() + withSpaces.substring(1);
  }
}
