// Single source of truth for all invoice spacing and typography.
//
// invoice_preview.dart uses these values directly (Flutter design pixels,
// 820px-wide canvas). invoice_pdf.dart multiplies each value by [pdfScale]
// (A4 width in points ÷ design width) so the two outputs share one set of
// numbers to tune. Edit here; both renderers update on hot reload / next PDF
// export.

abstract class InvoiceLayout {
  // ── Coordinate spaces ──────────────────────────────────────────────
  static const double designWidth = 820.0;
  static const double pdfPageWidth = 595.0; // A4 width in points
  static const double pdfScale = pdfPageWidth / designWidth; // ≈ 0.726

  // ── Spacing ────────────────────────────────────────────────────────
  static const double pageMargin = 50.0;
  static const double sectionGap = 33.0;
  static const double headlineGap = 11.0;
  static const double partyBlockGap = 22.0;
  static const double detailsBlockGap = 28.0;
  static const double detailsHeadingGap = 8.0;
  static const double tableHeaderGap = 6.0;
  static const double totalsGap = 8.0;
  static const double amountDueGap = 6.0;
  static const double paymentsHeadingGap = 8.0;
  static const double paymentsFieldGap = 11.0;
  static const double gridGutter = 11.0;
  static const double fieldValueGap = 3.0;
  static const double fieldPaddingH = 14.0;
  static const double fieldPaddingV = 10.0;
  static const double rowPaddingH = 17.0;
  static const double rowPaddingV = 10.0;
  static const double rowMarginBottom = 4.0;
  static const double fieldRadius = 6.0;

  // ── Typography ─────────────────────────────────────────────────────
  static const double fontLabel = 11.0;
  static const double fontCell = 12.0;
  static const double fontValue = 15.0;
  static const double fontInvoiceNumber = 18.0;
  static const double fontDetailsHeading = 19.0;
  static const double fontPaymentsHeading = 17.0;
  static const double fontAmountDue = 22.0;
  static const double fontHeadline = 30.0;
}
