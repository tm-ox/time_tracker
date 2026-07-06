import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:time_tracker/constants/format.dart';
import 'package:time_tracker/constants/tokens.dart';
import 'package:time_tracker/data/database.dart';
import 'package:time_tracker/features/invoices/invoice_document.dart';

// Renders an [InvoiceDocument] into a branded PDF using an [InvoiceTemplate]
// (colours + optional logo). Presentational: it reads resolved values from the
// document and applies the template — no arithmetic here. Dark, brand-coloured,
// modelled on the reference invoice (PRD #79).

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

// Print-space layout scale (points, at A4 width 595pt) — the PDF equivalent of
// invoice_preview.dart's AppTokens usage (design-space pixels, at 820px width).
// The two scales aren't 1:1 convertible (different coordinate spaces), so sizes
// here are independently tuned to *look* like the preview, not numerically
// matched to it. Kept in visual parity by hand — see invoice_preview.dart.
abstract class _Layout {
  static const pageMargin = 36.0;
  static const sectionGap = 24.0;
  static const headlineGap = 8.0;
  static const partyBlockGap = 16.0;
  static const detailsBlockGap = 20.0;
  static const detailsHeadingGap = 6.0;
  static const tableHeaderGap = 4.0;
  static const totalsGap = 6.0;
  static const amountDueGap = 4.0;
  static const paymentsHeadingGap = 6.0;
  static const paymentsFieldGap = 8.0;
  static const gridGutter = 8.0;
  static const fieldValueGap = 2.0;
  static const fieldPaddingH = 10.0;
  static const fieldPaddingV = 7.0;
  static const rowPaddingH = 12.0;
  static const rowPaddingV = 7.0;
  static const rowMarginBottom = 3.0;

  static const fontLabel = 8.0;
  static const fontCell = 9.0;
  static const fontValue = 11.0;
  static const fontInvoiceNumber = 13.0;
  static const fontDetailsHeading = 14.0;
  static const fontAmountDue = 16.0;
  static const fontPaymentsHeading = 12.0;
  static const fontHeadline = 22.0;
}

Future<Uint8List> buildBrandedInvoicePdf({
  required InvoiceDocument doc,
  required InvoiceTemplate template,
}) async {
  final fontData = await rootBundle.load(
    'assets/fonts/Urbanist-VariableFont_wght.ttf',
  );
  // Urbanist is a variable font; the pdf package embeds a single instance, so
  // `bold` reuses it (weight won't be heavier — a static bold ttf could be
  // bundled later if needed). Hierarchy leans on size/colour instead.
  final font = pw.Font.ttf(fontData);

  // User logo (template.logo) wins; fall back to the bundled timedart mark so
  // the default template shows branding before a logo is uploaded.
  final logoBytes =
      template.logo ??
      (await rootBundle.load('assets/logo/timedart_logo_horizontal.png'))
          .buffer
          .asUint8List();

  final bg = PdfColor.fromInt(template.colorBackground);
  final surface = PdfColor.fromInt(template.colorSurface);
  final primary = PdfColor.fromInt(template.colorPrimary);
  final text = PdfColor.fromInt(template.colorText);
  final muted = PdfColor.fromInt(template.colorText).flatten(background: bg);

  final labelStyle = pw.TextStyle(color: primary, fontSize: _Layout.fontLabel);
  final valueStyle = pw.TextStyle(
    color: primary,
    fontSize: _Layout.fontValue,
    fontWeight: pw.FontWeight.bold,
  );

  String money(double a) => formatCurrency(a, doc.currency);

  // A "label above a filled value box" cell, mirroring the reference.
  pw.Widget field(String label, String? value) => pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('$label:', style: labelStyle),
      pw.SizedBox(height: _Layout.fieldValueGap),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(
          horizontal: _Layout.fieldPaddingH,
          vertical: _Layout.fieldPaddingV,
        ),
        decoration: pw.BoxDecoration(
          color: surface,
          borderRadius: pw.BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: pw.Text(
          value == null || value.isEmpty ? '—' : value,
          style: valueStyle,
        ),
      ),
    ],
  );

  // One column of the details grid. The same flex weights (3/2/2/2/2) are used
  // by the header, the line rows, and the totals so TIME and TOTAL line up top
  // to bottom.
  pw.Widget cell(String s, int flex, {bool right = false, pw.TextStyle? style}) =>
      pw.Expanded(
        flex: flex,
        child: pw.Text(
          s,
          maxLines: 1,
          textAlign: right ? pw.TextAlign.right : pw.TextAlign.left,
          style:
              style ??
              pw.TextStyle(
                color: primary,
                fontSize: _Layout.fontCell,
                fontWeight: pw.FontWeight.bold,
              ),
        ),
      );

  final doc0 = pw.Document();
  doc0.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.zero,
      theme: pw.ThemeData.withFont(base: font, bold: font),
      build: (context) => pw.Container(
        color: bg,
        padding: const pw.EdgeInsets.all(_Layout.pageMargin),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Masthead: logo/business right, contact under it ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.SizedBox(),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Image(pw.MemoryImage(logoBytes), height: 28),
                    pw.SizedBox(height: _Layout.fieldValueGap * 2),
                    pw.Text(
                      [
                        if (doc.senderEmail != null) 'e. ${doc.senderEmail}',
                        if (doc.senderPhone != null) 't. ${doc.senderPhone}',
                      ].join('    '),
                      style: pw.TextStyle(color: muted, fontSize: _Layout.fontLabel),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: _Layout.sectionGap),

            // ── ATT / RE / date / invoice # ──
            pw.Text('ATT:', style: labelStyle),
            pw.Text(
              doc.attention ?? doc.organisation,
              style: pw.TextStyle(
                color: primary,
                fontSize: _Layout.fontHeadline,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: _Layout.headlineGap),
            pw.Text('RE:', style: labelStyle),
            pw.Text(
              doc.reference,
              style: pw.TextStyle(
                color: primary,
                fontSize: _Layout.fontHeadline,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: _Layout.headlineGap),
            pw.Text(_isoDate(doc.issueDate), style: pw.TextStyle(color: muted, fontSize: _Layout.fontLabel)),
            if (doc.invoiceNumber != null)
              pw.Text(
                'Invoice #${doc.invoiceNumber}',
                style: pw.TextStyle(
                  color: text,
                  fontSize: _Layout.fontInvoiceNumber,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            pw.SizedBox(height: _Layout.partyBlockGap),

            // ── Recipient grid ──
            pw.Row(
              children: [
                pw.Expanded(child: field('TO', doc.recipientContact)),
                pw.SizedBox(width: _Layout.gridGutter),
                pw.Expanded(child: field('EMAIL', doc.recipientEmail)),
              ],
            ),
            pw.SizedBox(height: _Layout.totalsGap),
            pw.Row(
              children: [
                pw.Expanded(child: field('ORGANISATION', doc.organisation)),
                pw.SizedBox(width: _Layout.gridGutter),
                pw.Expanded(child: field('PHONE', doc.recipientPhone)),
              ],
            ),
            pw.SizedBox(height: _Layout.detailsBlockGap),

            // ── Details ──
            pw.Text(
              'Details',
              style: pw.TextStyle(
                color: primary,
                fontSize: _Layout.fontDetailsHeading,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: _Layout.detailsHeadingGap),
            // Header — same horizontal inset as the line rows so columns align.
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: _Layout.rowPaddingH),
              child: pw.Row(
                children: [
                  cell('ITEM', 3, style: labelStyle),
                  cell('DATE', 2, style: labelStyle),
                  cell('RATE (${doc.currency})', 2, right: true, style: labelStyle),
                  cell('TIME (HRS)', 2, right: true, style: labelStyle),
                  cell('TOTAL', 2, right: true, style: labelStyle),
                ],
              ),
            ),
            pw.SizedBox(height: _Layout.tableHeaderGap),
            // Line rows — borderless rounded surfaces, padded for the corners.
            for (final l in doc.lines)
              pw.Container(
                margin: const pw.EdgeInsets.only(bottom: _Layout.rowMarginBottom),
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: _Layout.rowPaddingH,
                  vertical: _Layout.rowPaddingV,
                ),
                decoration: pw.BoxDecoration(
                  color: surface,
                  borderRadius: pw.BorderRadius.circular(AppTokens.radiusSm),
                ),
                child: pw.Row(
                  children: [
                    cell(l.item, 3),
                    cell(_isoDate(l.date), 2),
                    cell(money(l.rate), 2, right: true),
                    cell(Duration(seconds: l.seconds).hms, 2, right: true),
                    cell(money(l.amount), 2, right: true),
                  ],
                ),
              ),
            pw.SizedBox(height: _Layout.totalsGap),

            // ── Totals — TIME under TIME, amount under TOTAL (same columns) ──
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: _Layout.rowPaddingH, vertical: _Layout.fieldValueGap),
              child: pw.Row(
                children: [
                  cell('TOTAL:', 7, right: true, style: labelStyle),
                  cell(doc.totalTime.hms, 2, right: true, style: valueStyle),
                  cell(money(doc.subtotal), 2, right: true, style: valueStyle),
                ],
              ),
            ),
            if (doc.tax != null)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  horizontal: _Layout.rowPaddingH,
                  vertical: _Layout.fieldValueGap,
                ),
                child: pw.Row(
                  children: [
                    cell(
                      '${doc.tax!.label} (${doc.tax!.rate}%):',
                      9,
                      right: true,
                      style: labelStyle,
                    ),
                    cell(money(doc.tax!.amount), 2, right: true, style: valueStyle),
                  ],
                ),
              ),
            pw.SizedBox(height: _Layout.amountDueGap),
            // AMOUNT DUE — emphasised, right edge aligned with the TOTAL column.
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: _Layout.rowPaddingH, vertical: _Layout.fieldValueGap),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.end,
                children: [
                  pw.Text('AMOUNT DUE:  ', style: labelStyle),
                  pw.Text(
                    '${money(doc.amountDue)} ${doc.currency}',
                    style: pw.TextStyle(
                      color: primary,
                      fontSize: _Layout.fontAmountDue,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            pw.Spacer(),

            // ── Payments ──
            pw.Text(
              'Please make payments to:',
              style: pw.TextStyle(
                color: primary,
                fontSize: _Layout.fontPaymentsHeading,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: _Layout.paymentsHeadingGap),
            if (doc.paymentLink != null)
              field('Link', doc.paymentLink)
            else
              pw.SizedBox(),
            pw.SizedBox(height: _Layout.paymentsFieldGap),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: field('NAME', doc.payeeName)),
                pw.SizedBox(width: _Layout.gridGutter),
                pw.Expanded(child: field('ACN/ABN', doc.senderAbn)),
                pw.SizedBox(width: _Layout.gridGutter),
                pw.Expanded(child: field('SWIFT/BIC', doc.swift)),
                pw.SizedBox(width: _Layout.gridGutter),
                pw.Expanded(child: field('BANK', doc.bankName)),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return doc0.save();
}
