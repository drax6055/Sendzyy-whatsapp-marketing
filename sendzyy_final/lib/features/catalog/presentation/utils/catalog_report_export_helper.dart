import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:iFloraBuzz/core/utils/web_helper.dart';
import 'package:iFloraBuzz/features/catalog/data/models/catalog_model.dart';

/// Helper utility for exporting Catalog reports in both Excel (CSV) and PDF formats.
class CatalogReportExportHelper {
  /// Replaces characters outside the PDF font's Latin-1 range to avoid rendering errors.
  static String pdfSafe(String s) {
    return s
        .replaceAll('₹', 'Rs. ')
        .replaceAll('\u20B9', 'Rs. ')
        .replaceAll('\u2014', '-') // em dash
        .replaceAll('\u2013', '-') // en dash
        .replaceAll('\u2018', "'") // left single quote
        .replaceAll('\u2019', "'") // right single quote
        .replaceAll('\u201C', '"') // left double quote
        .replaceAll('\u201D', '"') // right double quote
        .replaceAll('\u2026', '...') // ellipsis
        .replaceAll(RegExp(r'[^\x00-\xFF]'), '?');
  }

  /// Exports catalog orders report as an Excel-compatible CSV file.
  /// Prepends UTF-8 BOM (\uFEFF) to guarantee correct Unicode decoding in Microsoft Excel.
  static Future<String> exportExcel({
    required List<WhatsAppOrder> orders,
  }) async {
    if (orders.isEmpty) {
      throw Exception('No orders available to export.');
    }

    final buffer = StringBuffer();
    // Excel CSV Header
    buffer.writeln(
      'Order ID,Date,Time,Customer Phone,Customer Name,Items Count,Products (SKU x Qty),Currency,Total Amount,Payment Status,Order Status,Payment Link ID,Payment ID,Customer Note',
    );

    final dateFormat = DateFormat('yyyy-MM-dd');
    final timeFormat = DateFormat('HH:mm:ss');

    for (final o in orders) {
      final dateStr = o.createdAt != null ? dateFormat.format(o.createdAt!) : '';
      final timeStr = o.createdAt != null ? timeFormat.format(o.createdAt!) : '';
      final itemsSummary = o.items
          .map((i) => '${i.productRetailerId} (x${i.quantity})')
          .join('; ');

      buffer.writeln(
        '"${o.id}",'
        '"$dateStr",'
        '"$timeStr",'
        '"${o.contactId}",'
        '"${o.contactName.replaceAll('"', '""')}",'
        '${o.items.length},'
        '"${itemsSummary.replaceAll('"', '""')}",'
        '"${o.currency}",'
        '${o.totalAmount.toStringAsFixed(2)},'
        '"${o.paymentStatus}",'
        '"${o.status}",'
        '"${o.paymentLinkId ?? ''}",'
        '"${o.paymentId ?? ''}",'
        '"${o.customerNote.replaceAll('"', '""')}"',
      );
    }

    final bytes = utf8.encode('\uFEFF${buffer.toString()}');
    final fileName =
        'catalog_orders_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

    await webDownloadBytes(bytes, fileName, mimeType: 'text/csv;charset=utf-8');
    return fileName;
  }

  /// Exports catalog performance and orders report as a formatted PDF document.
  static Future<String> exportPdf({
    required List<WhatsAppOrder> orders,
    required List<CatalogProduct> products,
    DateTimeRange? dateRange,
    String datePreset = 'all',
  }) async {
    if (orders.isEmpty) {
      throw Exception('No orders available to export.');
    }

    final pdf = pw.Document();
    const primaryGreen = PdfColor.fromInt(0xFF25D366);
    const darkSlate = PdfColor.fromInt(0xFF1A1D1E);

    // Compute Executive KPIs
    double totalRevenue = 0;
    double paidRevenue = 0;
    double pendingRevenue = 0;
    int receivedCount = 0;
    int acceptedCount = 0;
    int processingCount = 0;
    int completedCount = 0;
    int cancelledCount = 0;

    for (final o in orders) {
      totalRevenue += o.totalAmount;
      if (o.paymentStatus.toLowerCase() == 'paid') {
        paidRevenue += o.totalAmount;
      } else {
        pendingRevenue += o.totalAmount;
      }

      switch (o.status.toLowerCase()) {
        case 'received':
          receivedCount++;
          break;
        case 'accepted':
          acceptedCount++;
          break;
        case 'processing':
          processingCount++;
          break;
        case 'completed':
          completedCount++;
          break;
        case 'cancelled':
          cancelledCount++;
          break;
      }
    }

    final totalOrders = orders.length;
    final aov = totalOrders > 0 ? (totalRevenue / totalOrders) : 0.0;

    // Aggregate Top Products by revenue
    final Map<String, int> productQty = {};
    final Map<String, double> productRev = {};
    final Map<String, String> productName = {};

    for (final p in products) {
      productName[p.retailerId] = p.name;
    }

    for (final o in orders) {
      for (final item in o.items) {
        final sku = item.productRetailerId;
        productQty[sku] = (productQty[sku] ?? 0) + item.quantity;
        productRev[sku] = (productRev[sku] ?? 0) + (item.itemPrice * item.quantity);
      }
    }

    final sortedSkus = productRev.keys.toList()
      ..sort((a, b) => productRev[b]!.compareTo(productRev[a]!));
    final topSkus = sortedSkus.take(5).toList();

    // Human-readable date range description
    String periodText = 'All Time';
    if (datePreset == 'today') {
      periodText = 'Today (${DateFormat('MMM dd, yyyy').format(DateTime.now())})';
    } else if (datePreset == '7d') {
      periodText = 'Last 7 Days';
    } else if (datePreset == '30d') {
      periodText = 'Last 30 Days';
    } else if (dateRange != null) {
      periodText =
          '${DateFormat('MMM dd, yyyy').format(dateRange.start)} - ${DateFormat('MMM dd, yyyy').format(dateRange.end)}';
    }

    final nowStr = DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        header: (context) {
          if (context.pageNumber > 1) {
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding: const pw.EdgeInsets.only(bottom: 6),
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Sendzyy • Catalog Performance & Orders Report',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    nowStr,
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
            );
          }
          return pw.SizedBox.shrink();
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 14),
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.5)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Confidential - Generated via Sendzyy Commerce Analytics',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
                ),
              ],
            ),
          );
        },
        build: (context) => [
          // ── Brand & Document Header ──────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Sendzyy',
                    style: pw.TextStyle(
                      fontSize: 26,
                      fontWeight: pw.FontWeight.bold,
                      color: primaryGreen,
                    ),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    'Catalog Performance & Orders Report',
                    style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: darkSlate,
                    ),
                  ),
                  pw.Text(
                    'WhatsApp Commerce Revenue & Order Fulfillment Insights',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                    ),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('Report Period', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        pw.Text(
                          pdfSafe(periodText),
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: darkSlate),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Generated: $nowStr', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Divider(color: primaryGreen, thickness: 1.5),
          pw.SizedBox(height: 14),

          // ── 1. Executive Metric Summary Cards ─────────────────────────────────
          pw.Text(
            'Executive Summary',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkSlate),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              _buildStatCard('Total Orders', '$totalOrders', const PdfColor.fromInt(0xFF0284C7)),
              _buildStatCard('Gross Revenue', 'Rs. ${NumberFormat('#,##0.00').format(totalRevenue)}', const PdfColor.fromInt(0xFF10B981)),
              _buildStatCard('Collected', 'Rs. ${NumberFormat('#,##0.00').format(paidRevenue)}', const PdfColor.fromInt(0xFF059669)),
              _buildStatCard('Pending', 'Rs. ${NumberFormat('#,##0.00').format(pendingRevenue)}', const PdfColor.fromInt(0xFFD97706)),
              _buildStatCard('Avg Order Value', 'Rs. ${NumberFormat('#,##0.00').format(aov)}', const PdfColor.fromInt(0xFF8B5CF6)),
            ],
          ),
          pw.SizedBox(height: 18),

          // ── 2. Fulfillment Status Funnel ──────────────────────────────────────
          pw.Text(
            'Fulfillment Status Distribution',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkSlate),
          ),
          pw.SizedBox(height: 6),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                _buildFunnelItem('Received', receivedCount, totalOrders, const PdfColor.fromInt(0xFF6B7280)),
                _buildFunnelItem('Accepted', acceptedCount, totalOrders, const PdfColor.fromInt(0xFF2563EB)),
                _buildFunnelItem('Processing', processingCount, totalOrders, const PdfColor.fromInt(0xFFD97706)),
                _buildFunnelItem('Completed', completedCount, totalOrders, const PdfColor.fromInt(0xFF10B981)),
                _buildFunnelItem('Cancelled', cancelledCount, totalOrders, const PdfColor.fromInt(0xFFEF4444)),
              ],
            ),
          ),
          pw.SizedBox(height: 18),

          // ── 3. Top Performing Products ────────────────────────────────────────
          if (topSkus.isNotEmpty) ...[
            pw.Text(
              'Top Performing Catalog Products',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkSlate),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              headers: ['SKU / Retailer ID', 'Product Name', 'Units Sold', 'Total Revenue'],
              data: topSkus.map((sku) {
                final name = productName[sku] ?? 'Product $sku';
                final qty = productQty[sku] ?? 0;
                final rev = productRev[sku] ?? 0.0;
                return [
                  pdfSafe(sku),
                  pdfSafe(name),
                  '$qty',
                  'Rs. ${NumberFormat('#,##0.00').format(rev)}',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E293B)),
              cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
              cellStyle: const pw.TextStyle(fontSize: 8),
              oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 18),
          ],

          // ── 4. Detailed Orders Log ────────────────────────────────────────────
          pw.Text(
            'Detailed Orders & Inquiries Log (${orders.length} Records)',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkSlate),
          ),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: [
              'Order ID',
              'Date & Time',
              'Customer',
              'Items Summary',
              'Amount',
              'Payment',
              'Status',
            ],
            data: orders.map((o) {
              final dateStr = o.createdAt != null
                  ? DateFormat('yy-MM-dd HH:mm').format(o.createdAt!)
                  : '-';
              final customer = o.contactName.isNotEmpty
                  ? '${o.contactName} (${o.contactId})'
                  : o.contactId;
              final itemsSummary = o.items
                  .map((i) => '${i.productRetailerId} (x${i.quantity})')
                  .join('; ');
              final amountStr = 'Rs. ${o.totalAmount.toStringAsFixed(2)}';

              return [
                pdfSafe(o.id.length > 10 ? '#${o.id.substring(o.id.length - 8)}' : o.id),
                dateStr,
                pdfSafe(customer),
                pdfSafe(itemsSummary.isNotEmpty ? itemsSummary : 'None'),
                amountStr,
                pdfSafe(o.paymentStatus.toUpperCase()),
                pdfSafe(o.status.toUpperCase()),
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              color: PdfColors.white,
              fontWeight: pw.FontWeight.bold,
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(color: primaryGreen),
            rowDecoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
            ),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 5),
            cellStyle: const pw.TextStyle(fontSize: 7.5),
            oddRowDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.center,
              6: pw.Alignment.center,
            },
          ),
        ],
      ),
    );

    final pdfBytes = await pdf.save();
    final fileName =
        'catalog_orders_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

    if (kIsWeb) {
      await webDownloadBytes(pdfBytes, fileName, mimeType: 'application/pdf');
    } else {
      await webDownloadBytes(pdfBytes, fileName, mimeType: 'application/pdf');
      try {
        await Printing.layoutPdf(
          onLayout: (_) async => pdfBytes,
          name: fileName,
        );
      } catch (e) {
        debugPrint('[CatalogReportExportHelper] Printing error or test env: $e');
      }
    }

    return fileName;
  }

  static pw.Widget _buildStatCard(String label, String value, PdfColor color) {
    return pw.Container(
      width: 98,
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
            maxLines: 1,
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            pdfSafe(value),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFunnelItem(String label, int count, int total, PdfColor color) {
    final pct = total > 0 ? (count / total * 100).toStringAsFixed(0) : '0';
    return pw.Column(
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          '$count ($pct%)',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
