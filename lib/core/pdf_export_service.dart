import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'models.dart';

class PdfExportService {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );

  static final NumberFormat _numFormat = NumberFormat('#,##0.##', 'tr_TR');
  static final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm', 'tr_TR');

  /// Generates and opens/downloads a comprehensive Stock & Valuation PDF Report.
  static Future<void> exportStockReportPdf(
    List<Product> products, {
    String? title,
    String? warehouseName,
  }) async {
    final doc = pw.Document();
    final now = DateTime.now();

    final totalQuantity = products.fold<num>(0, (sum, p) => sum + p.stock);
    final totalInventoryValue = products.fold<double>(0, (sum, p) {
      final unitPrice = p.averageCost ?? p.purchasePrice ?? 0;
      return sum + (p.stock * unitPrice).toDouble();
    });
    final totalSalesValue = products.fold<double>(0, (sum, p) {
      final unitPrice = p.salePrice ?? 0;
      return sum + (p.stock * unitPrice).toDouble();
    });
    final criticalCount = products.where((p) => p.isCritical || p.isLow).length;
    final outOfStockCount = products.where((p) => p.isOutOfStock).length;

    // Use built-in bold and regular TTF fonts from printing package for Turkish UTF-8 characters
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BITRONIX STOK & ENVANTER DEĞER RAPORU',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.orange900,
                      ),
                    ),
                    if (warehouseName != null)
                      pw.Text(
                        'Depo: $warehouseName',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Rapor Tarihi: ${_dateFormat.format(now)}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.Text(
                      'Sayfa ${context.pageNumber} / ${context.pagesCount}',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(color: PdfColors.grey400, thickness: 1),
            pw.SizedBox(height: 6),
          ],
        ),
        build: (context) => [
          // KPI Summary Cards
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildKpiPdf(
                  'Toplam Çeşit',
                  '${products.length} Kalem',
                  fontBold,
                ),
                _buildKpiPdf(
                  'Toplam Stok',
                  '${_numFormat.format(totalQuantity)} Adet/Birim',
                  fontBold,
                ),
                _buildKpiPdf(
                  'Toplam Alış Değeri',
                  _currencyFormat.format(totalInventoryValue),
                  fontBold,
                  color: PdfColors.blue800,
                ),
                _buildKpiPdf(
                  'Toplam Satış Değeri',
                  _currencyFormat.format(totalSalesValue),
                  fontBold,
                  color: PdfColors.green800,
                ),
                _buildKpiPdf(
                  'Kritik / Biten',
                  '$criticalCount / $outOfStockCount',
                  fontBold,
                  color: criticalCount > 0
                      ? PdfColors.red800
                      : PdfColors.grey800,
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Main Table
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 9,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF1E293B),
            ),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              ),
            ),
            cellAlignment: pw.Alignment.centerLeft,
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(24), // #
              1: const pw.FlexColumnWidth(3.0), // Ürün Adı
              2: const pw.FlexColumnWidth(1.6), // SKU
              3: const pw.FlexColumnWidth(1.6), // Barkod
              4: const pw.FlexColumnWidth(1.2), // Stok
              5: const pw.FlexColumnWidth(1.4), // Alış Birim Fiyatı
              6: const pw.FlexColumnWidth(1.6), // Toplam Alış Değeri
              7: const pw.FlexColumnWidth(1.4), // Satış Birim Fiyatı
              8: const pw.FlexColumnWidth(1.6), // Toplam Satış Değeri
            },
            headers: [
              '#',
              'Ürün Adı',
              'SKU',
              'Barkod',
              'Miktar',
              'Birim Alış (₺)',
              'Toplam Alış (₺)',
              'Birim Satış (₺)',
              'Toplam Satış (₺)',
            ],
            data: List<List<dynamic>>.generate(products.length, (index) {
              final p = products[index];
              final cost = p.averageCost ?? p.purchasePrice ?? 0;
              final sale = p.salePrice ?? 0;
              final totalCost = p.stock * cost;
              final totalSale = p.stock * sale;

              return [
                (index + 1).toString(),
                p.name,
                p.sku.isNotEmpty ? p.sku : '—',
                p.barcode ?? '—',
                '${_numFormat.format(p.stock)} ${p.unit}',
                cost > 0 ? _currencyFormat.format(cost) : '—',
                totalCost > 0 ? _currencyFormat.format(totalCost) : '—',
                sale > 0 ? _currencyFormat.format(sale) : '—',
                totalSale > 0 ? _currencyFormat.format(totalSale) : '—',
              ];
            }),
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Bitronix Stok Yönetim Sistemi tarafından üretilmiştir.',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name:
          'Bitronix_Stok_Raporu_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf',
    );
  }

  /// Generates printable Barcode & QR code label sheets in PDF format.
  ///
  /// Seçilen tüm ürünler tek bir PDF'e A4 sayfalarına sığacak şekilde
  /// soldan sağa, satır satır dizilir; taştıkça otomatik yeni sayfaya geçer.
  /// [labelSize] "GENxYUK" (mm) biçiminde olup etiket kutu boyutunu belirler.
  static Future<void> exportBarcodeLabelsPdf(
    List<Product> products, {
    String labelSize = '50x30',
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();

    // Etiket boyutunu ayrıştır (mm). Hatalıysa 50x30'a düş.
    final parts = labelSize.toLowerCase().split('x');
    final labelWmm = double.tryParse(parts.elementAtOrNull(0) ?? '') ?? 50;
    final labelHmm = double.tryParse(parts.elementAtOrNull(1) ?? '') ?? 30;
    final labelW = labelWmm * PdfPageFormat.mm;
    final labelH = labelHmm * PdfPageFormat.mm;
    final qrSize = (labelH - 10 * PdfPageFormat.mm)
        .clamp(12 * PdfPageFormat.mm, labelW * 0.5)
        .toDouble();

    final now = DateTime.now();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        margin: const pw.EdgeInsets.all(14),
        header: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'BITRONIX QR / BARKOD ETİKETLERİ',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange900,
                ),
              ),
              pw.Text(
                '${products.length} etiket • ${labelWmm.toStringAsFixed(0)}x${labelHmm.toStringAsFixed(0)} mm • ${_dateFormat.format(now)}',
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
        build: (context) => [
          pw.Wrap(
            spacing: 6,
            runSpacing: 6,
            children: products.map((p) {
              final code = p.sku.isNotEmpty ? p.sku : p.id;
              final price = p.salePrice ?? p.purchasePrice;

              return pw.Container(
                width: labelW,
                height: labelH,
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                padding: const pw.EdgeInsets.all(4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: code,
                      width: qrSize,
                      height: qrSize,
                    ),
                    pw.SizedBox(width: 4),
                    pw.Expanded(
                      child: pw.Column(
                        mainAxisAlignment: pw.MainAxisAlignment.center,
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'BITRONIX',
                            style: pw.TextStyle(
                              fontSize: 6,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.orange900,
                              letterSpacing: 1,
                            ),
                          ),
                          pw.Text(
                            p.name,
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                            maxLines: 2,
                            overflow: pw.TextOverflow.clip,
                          ),
                          pw.SizedBox(height: 1),
                          pw.Text(
                            'SKU: $code',
                            style: const pw.TextStyle(
                              fontSize: 6.5,
                              color: PdfColors.grey800,
                            ),
                            maxLines: 1,
                          ),
                          if (p.barcode != null && p.barcode!.isNotEmpty)
                            pw.Text(
                              p.barcode!,
                              style: const pw.TextStyle(
                                fontSize: 6,
                                color: PdfColors.grey700,
                              ),
                              maxLines: 1,
                            ),
                          if (price != null && price > 0)
                            pw.Text(
                              _currencyFormat.format(price),
                              style: pw.TextStyle(
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Sayfa ${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => doc.save(),
      name:
          'Bitronix_QR_Etiketleri_${DateFormat('yyyyMMdd_HHmm').format(now)}.pdf',
    );
  }

  /// Exports a single product QR / Barcode as PDF or Printable high-res label
  static Future<void> exportSingleBarcodePdf(Product product) async {
    await exportBarcodeLabelsPdf([product]);
  }

  static pw.Widget _buildKpiPdf(
    String label,
    String value,
    pw.Font fontBold, {
    PdfColor? color,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10.5,
            fontWeight: pw.FontWeight.bold,
            font: fontBold,
            color: color ?? PdfColors.black,
          ),
        ),
      ],
    );
  }
}
