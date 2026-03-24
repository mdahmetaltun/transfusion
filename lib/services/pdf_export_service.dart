import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/blood_product_unit.dart';

class PdfExportService {
  Future<void> exportCaseSummary({
    required String caseId,
    required String location,
    required int abcScore,
    required bool hrMet,
    required bool sbpMet,
    required bool fastMet,
    required bool penetratingMet,
    required int prbcCount,
    required int ffpCount,
    required int pltCount,
    required int cryoCount,
    required String mtpDuration,
    required List<BloodProductUnit> bloodProducts,
    required String notes,
    required DateTime? activationTime,
  }) async {
    try {
      final pdf = pw.Document();

      final now = DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now());
      final activationStr = activationTime != null
          ? DateFormat('dd.MM.yyyy HH:mm').format(activationTime)
          : '—';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => _buildHeader(caseId, now),
          footer: (context) => _buildFooter(context),
          build: (context) => [
            pw.SizedBox(height: 16),
            _buildInfoSection(
              caseId: caseId,
              location: location,
              activationStr: activationStr,
              duration: mtpDuration,
            ),
            pw.SizedBox(height: 16),
            _buildAbcSection(
              score: abcScore,
              hrMet: hrMet,
              sbpMet: sbpMet,
              fastMet: fastMet,
              penetratingMet: penetratingMet,
            ),
            pw.SizedBox(height: 16),
            _buildProductsSection(
              prbcCount: prbcCount,
              ffpCount: ffpCount,
              pltCount: pltCount,
              cryoCount: cryoCount,
            ),
            pw.SizedBox(height: 16),
            if (bloodProducts.isNotEmpty) ...[
              _buildBloodProductTable(bloodProducts),
              pw.SizedBox(height: 16),
            ],
            if (notes.isNotEmpty) ...[
              _buildNotesSection(notes),
              pw.SizedBox(height: 16),
            ],
            _buildDisclaimer(),
          ],
        ),
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'MTP_Rapor_$caseId.pdf',
      );
    } catch (e) {
      if (kDebugMode) print('PDF Export error: $e');
      rethrow;
    }
  }

  pw.Widget _buildHeader(String caseId, String date) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.red700, width: 2)),
      ),
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'MTP VAKA RAPORU',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 18,
                  color: PdfColors.red700,
                ),
              ),
              pw.Text(
                'Masif Transfüzyon Protokolü — Klinik Özet',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                'Vaka: $caseId',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              pw.Text(
                'Rapor: $date',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400)),
      ),
      padding: const pw.EdgeInsets.only(top: 6),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Bu rapor MTP Transfusion uygulaması tarafından oluşturulmuştur.',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            'Sayfa ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildInfoSection({
    required String caseId,
    required String location,
    required String activationStr,
    required String duration,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('VAKA BİLGİLERİ'),
          pw.SizedBox(height: 6),
          _infoRow('Vaka ID', caseId),
          _infoRow('Lokasyon', location),
          _infoRow('MTP Aktivasyon', activationStr),
          _infoRow('Toplam Süre', duration),
        ],
      ),
    );
  }

  pw.Widget _buildAbcSection({
    required int score,
    required bool hrMet,
    required bool sbpMet,
    required bool fastMet,
    required bool penetratingMet,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
            color: score >= 2 ? PdfColors.red400 : PdfColors.green400),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('ABC SKORU'),
          pw.SizedBox(height: 6),
          pw.Text(
            'Toplam Skor: $score / 4 — ${score >= 2 ? 'YÜKSEK RİSK' : 'DÜŞÜK RİSK'}',
            style: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: score >= 2 ? PdfColors.red700 : PdfColors.green700,
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(3),
              1: const pw.FlexColumnWidth(1),
            },
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              _tableHeader(['Kriter', 'Durum']),
              _tableRow(['Nabız ≥ 120 dk', hrMet ? 'EVET (+1)' : 'HAYIR']),
              _tableRow(['SKB ≤ 90 mmHg', sbpMet ? 'EVET (+1)' : 'HAYIR']),
              _tableRow(['FAST Pozitif', fastMet ? 'EVET (+1)' : 'HAYIR']),
              _tableRow(['Penetran Mekanizma', penetratingMet ? 'EVET (+1)' : 'HAYIR']),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildProductsSection({
    required int prbcCount,
    required int ffpCount,
    required int pltCount,
    required int cryoCount,
  }) {
    final total = prbcCount + ffpCount + pltCount + cryoCount;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('ÜRÜN UYGULAMASI'),
          pw.SizedBox(height: 6),
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(1),
            },
            border: pw.TableBorder.all(color: PdfColors.grey300),
            children: [
              _tableHeader(['Ürün', 'Ünite']),
              _tableRow(['ES (Eritrosit)', '$prbcCount']),
              _tableRow(['TDP (Taze Donmuş Plazma)', '$ffpCount']),
              _tableRow(['TSP (Trombosit)', '$pltCount']),
              _tableRow(['KRİYO/Fibrinojen', '$cryoCount']),
              _tableRow(['TOPLAM', '$total']),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildBloodProductTable(List<BloodProductUnit> products) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionTitle('KAN ÜRÜNÜ TAKİP TABLOSU'),
        pw.SizedBox(height: 6),
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(2),
            2: const pw.FlexColumnWidth(2),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(1.5),
          },
          border: pw.TableBorder.all(color: PdfColors.grey300),
          children: [
            _tableHeader(['Tip', 'Barkod', 'Lot', 'SKT', 'Durum']),
            ...products.map((p) => _tableRow([
                  p.productTypeShortLabel,
                  p.barcode,
                  p.lotNumber,
                  DateFormat('dd.MM.yy').format(p.expiryDate),
                  p.statusLabel,
                ])),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildNotesSection(String notes) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionTitle('KLİNİK NOTLAR'),
          pw.SizedBox(height: 6),
          pw.Text(notes, style: const pw.TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  pw.Widget _buildDisclaimer() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.orange50,
        border: pw.Border.all(color: PdfColors.orange300),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Text(
        'YASAL UYARI: Bu rapor klinik destek amaçlıdır. '
        'Tıbbi kararlar yetkili klinisyen tarafından verilmelidir. '
        'Rapor imzasız olup resmi tıbbi belge yerine geçmez.',
        style: pw.TextStyle(fontSize: 9, color: PdfColors.orange900),
      ),
    );
  }

  pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        fontSize: 12,
        color: PdfColors.grey800,
      ),
    );
  }

  pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 10,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  pw.TableRow _tableHeader(List<String> headers) {
    return pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: headers
          .map((h) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(
                  h,
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ))
          .toList(),
    );
  }

  pw.TableRow _tableRow(List<String> cells) {
    return pw.TableRow(
      children: cells
          .map((c) => pw.Padding(
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(c, style: const pw.TextStyle(fontSize: 10)),
              ))
          .toList(),
    );
  }
}
