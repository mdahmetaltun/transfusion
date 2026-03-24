import 'package:url_launcher/url_launcher.dart';

/// Centralized WhatsApp messaging service.
/// Phone numbers must be in international format without + or spaces (e.g. 905413817331).
class WhatsAppService {
  /// Opens WhatsApp with [phone] and a pre-filled [message].
  /// Returns true if WhatsApp could be launched.
  static Future<bool> sendMessage({
    required String phone,
    required String message,
  }) async {
    final clean = _cleanPhone(phone);
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('https://wa.me/$clean?text=$encoded');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  /// Opens a WhatsApp chat with [phone] (no pre-filled message).
  static Future<bool> openChat({required String phone}) async {
    final clean = _cleanPhone(phone);
    final uri = Uri.parse('https://wa.me/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return true;
    }
    return false;
  }

  /// Strips all non-digit characters and leading + from the phone number.
  static String _cleanPhone(String phone) =>
      phone.replaceAll(RegExp(r'[^\d]'), '');

  // ── Pre-built MTP message templates ─────────────────────────────────────

  /// Sent immediately when MTP is activated.
  static String mtpActivationMessage({
    required String caseId,
    required String location,
    required String targetRatio,
  }) =>
      '🚨 *MTP AKTİVE EDİLDİ*\n'
      'Vaka: $caseId\n'
      'Lokasyon: $location\n'
      'Hedef oran: $targetRatio\n\n'
      'İlk kan seti (ES + TDP + TSP) için acilen hazırlık yapınız.';

  /// Sent when the "Kan Bankasını Ara" button is tapped during active MTP.
  static String bloodBankRequestMessage({
    required String caseId,
    required int esGiven,
    required int tdpGiven,
    required int tspGiven,
    required String targetRatio,
  }) =>
      '🩸 *MTP DEVAM EDİYOR — KAN İSTEMİ*\n'
      'Vaka: $caseId\n'
      'Verilen ürünler: ES $esGiven · TDP $tdpGiven · TSP $tspGiven\n'
      'Hedef oran: $targetRatio\n\n'
      'Bir sonraki set için hazırlık ricası.';

  /// Sent as the shift handover summary.
  static String handoverMessage({required String summaryText}) =>
      '📋 *MTP NÖBET DEVİR BİLGİSİ*\n\n$summaryText';
}
