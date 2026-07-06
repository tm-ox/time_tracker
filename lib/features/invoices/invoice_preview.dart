import 'package:flutter/material.dart';
import 'package:time_tracker/constants/format.dart';
import 'package:time_tracker/constants/tokens.dart';
import 'package:time_tracker/data/database.dart';
import 'package:time_tracker/features/invoices/invoice_document.dart';

/// A bordered frame that hugs an invoice preview tightly — the border traces
/// the sheet's true edges, so it reads as the actual page boundary rather than
/// an arbitrary panel outline (a loose frame around a dark-background template
/// was easy to mistake for extra page margin). Wrapped in [Center] so a
/// stretching ancestor (e.g. a `Column(crossAxisAlignment: stretch)`) can't
/// force it wider than its child — it sizes to the sheet, not its slot. The
/// child is clipped to a radius inset by the border width so the corners meet
/// cleanly (a bordered Container with a rounded child otherwise leaves a
/// square notch).
Widget brandingPreviewFrame({required Widget child}) => Center(
  child: Container(
    // Container (unlike DecoratedBox) insets its child by the border width, so
    // the opaque preview can't paint over the border. ClipRRect rounds the
    // inner corners to match.
    decoration: BoxDecoration(
      border: Border.all(color: AppTokens.colorBorder),
      borderRadius: BorderRadius.circular(AppTokens.radiusSm),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(AppTokens.radiusSm - 1),
      child: child,
    ),
  ),
);

/// Standard print page proportions (height ÷ width). A4 is the default; Letter
/// is offered for US output. A page-size picker is a later setting — for now the
/// preview assumes A4.
enum InvoicePageSize {
  a4(297 / 210),
  letter(279 / 216);

  const InvoicePageSize(this.ratio);
  final double ratio; // height / width
}

/// The invoice preview laid out as a page — a sheet with the chosen print
/// proportions and a minimum height, so it reads like the printed output
/// (with the content's own safe margin) rather than a raw content block.
/// Fills [brandingPreviewFrame] edge to edge — no gutter between the sheet and
/// its border, so the border traces the sheet's true boundary instead of an
/// ambiguous margin that a dark template background could get lost in.
/// Scrolls vertically inside its parent when the invoice runs longer than one
/// page. When [scrollable] (the default) the page scrolls vertically within
/// its own slot — right for a fixed-size preview panel. Pass `false` when
/// embedding the preview inside an outer scroll view (e.g. an editor whose
/// whole content pane scrolls): the page then renders at its natural height
/// and the outer view owns scrolling, avoiding nested scrollables.
Widget invoicePreviewPage({
  required InvoiceDocument doc,
  required InvoiceTemplate template,
  InvoicePageSize size = InvoicePageSize.a4,
  bool scrollable = true,
}) {
  return LayoutBuilder(
    builder: (context, c) {
      // The page is always laid out at a fixed A4 design width, then scaled
      // down to fit narrower panes — so the preview reads like the printed
      // sheet (content proportionate to the page) rather than reflowing its
      // contents. It is never scaled up past the design width.
      const designWidth = 820.0;
      final sheet = Container(
        width: designWidth,
        constraints: BoxConstraints(minHeight: designWidth * size.ratio),
        color: Color(template.colorBackground),
        child: InvoicePreview(doc: doc, template: template),
      );
      final page = c.maxWidth >= designWidth
          ? sheet
          // Uniform down-scale: width matches the pane, height follows in
          // proportion, so the whole page shrinks like a thumbnail.
          : FittedBox(
              fit: BoxFit.fitWidth,
              alignment: Alignment.topCenter,
              child: sheet,
            );
      return scrollable ? SingleChildScrollView(child: page) : page;
    },
  );
}

/// On-screen, WYSIWYG preview of an [InvoiceDocument] rendered with an
/// [InvoiceTemplate]. Presentational — reads resolved values from the document
/// and applies the template, mirroring the PDF renderer (invoice_pdf.dart) so
/// what you see matches the export. Both read the same view-model; the two
/// renderers are kept in visual parity by hand (printing's PdfPreview is
/// unusable on Linux — see PRD #79).
class InvoicePreview extends StatelessWidget {
  final InvoiceDocument doc;
  final InvoiceTemplate template;
  const InvoicePreview({super.key, required this.doc, required this.template});

  // Design-space (820px width) sizes with no AppTokens equivalent — the PDF's
  // matching values are invoice_pdf.dart's _Layout.fontHeadline/fontAmountDue,
  // independently tuned (different coordinate space; see that file's note).
  static const _fontHeadline = 22.0;
  static const _fontAmountDue = 18.0;

  Color get _bg => Color(template.colorBackground);
  Color get _surface => Color(template.colorSurface);
  Color get _primary => Color(template.colorPrimary);
  Color get _muted => Color(template.colorText).withValues(alpha: 0.55);

  String _money(double a) => formatCurrency(a, doc.currency);
  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  TextStyle get _label =>
      TextStyle(color: _primary, fontSize: AppTokens.fontSizeXs);
  TextStyle get _value => TextStyle(
    color: _primary,
    fontSize: AppTokens.fontSizeSm,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    // A4-ish aspect on a dark card, scrolls within its parent.
    return Container(
      color: _bg,
      padding: const EdgeInsets.all(AppTokens.spaceXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _masthead(),
          const SizedBox(height: AppTokens.spaceLg),
          _party(),
          const SizedBox(height: AppTokens.spaceMd),
          _recipientGrid(),
          const SizedBox(height: AppTokens.spaceLg),
          Text(
            'Details',
            style: TextStyle(
              color: _primary,
              fontSize: AppTokens.fontSizeMd,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTokens.spaceSm),
          _table(),
          const SizedBox(height: AppTokens.spaceMd),
          _totals(),
          const SizedBox(height: AppTokens.spaceXl),
          _payments(),
        ],
      ),
    );
  }

  Widget _masthead() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Spacer(),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // template.logo (user upload) wins; else the bundled timedart mark.
          template.logo != null
              ? Image.memory(template.logo!, height: 28)
              : Image.asset(
                  'assets/logo/timedart_logo_horizontal.png',
                  height: 28,
                ),
          const SizedBox(height: AppTokens.space3xs),
          Text(
            [
              if (doc.senderEmail != null) 'e. ${doc.senderEmail}',
              if (doc.senderPhone != null) 't. ${doc.senderPhone}',
            ].join('    '),
            style: TextStyle(color: _muted, fontSize: AppTokens.fontSizeXs),
          ),
        ],
      ),
    ],
  );

  Widget _party() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('ATT:', style: _label),
      Text(
        doc.attention ?? doc.organisation,
        style: TextStyle(
          color: _primary,
          fontSize: _fontHeadline,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: AppTokens.spaceXs),
      Text('RE:', style: _label),
      Text(
        doc.reference,
        style: TextStyle(
          color: _primary,
          fontSize: _fontHeadline,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: AppTokens.spaceXs),
      Text(
        _iso(doc.issueDate),
        style: TextStyle(color: _muted, fontSize: AppTokens.fontSizeXs),
      ),
      if (doc.invoiceNumber != null)
        Text(
          'Invoice #${doc.invoiceNumber}',
          style: TextStyle(
            color: _primary,
            fontSize: AppTokens.fontSizeMd,
            fontWeight: FontWeight.w700,
          ),
        ),
    ],
  );

  Widget _recipientGrid() => Column(
    children: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _field('TO', doc.recipientContact)),
          const SizedBox(width: AppTokens.spaceXs),
          Expanded(child: _field('EMAIL', doc.recipientEmail)),
        ],
      ),
      const SizedBox(height: AppTokens.space2xs),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _field('ORGANISATION', doc.organisation)),
          const SizedBox(width: AppTokens.spaceXs),
          Expanded(child: _field('PHONE', doc.recipientPhone)),
        ],
      ),
    ],
  );

  Widget _field(String label, String? value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('$label:', style: _label),
      const SizedBox(height: AppTokens.space3xs),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.spaceSm,
          vertical: AppTokens.spaceXs,
        ),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(AppTokens.radiusSm),
        ),
        child: Text(
          value == null || value.isEmpty ? '—' : value,
          style: _value,
        ),
      ),
    ],
  );

  // Shared column layout (flex 3/2/2/2/2) for header, lines, and totals.
  Widget _cell(String s, int flex, {bool right = false, TextStyle? style}) =>
      Expanded(
        flex: flex,
        child: Text(
          s,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: right ? TextAlign.right : TextAlign.left,
          style: style ?? _value,
        ),
      );

  Widget _table() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceSm),
        child: Row(
          children: [
            _cell('ITEM', 3, style: _label),
            _cell('DATE', 2, style: _label),
            _cell('RATE (${doc.currency})', 2, right: true, style: _label),
            _cell('TIME (HRS)', 2, right: true, style: _label),
            _cell('TOTAL', 2, right: true, style: _label),
          ],
        ),
      ),
      const SizedBox(height: AppTokens.space3xs),
      for (final l in doc.lines)
        Container(
          margin: const EdgeInsets.only(bottom: AppTokens.space3xs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceSm,
            vertical: AppTokens.spaceXs,
          ),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
          ),
          child: Row(
            children: [
              _cell(l.item, 3),
              _cell(_iso(l.date), 2),
              _cell(_money(l.rate), 2, right: true),
              _cell(Duration(seconds: l.seconds).hms, 2, right: true),
              _cell(_money(l.amount), 2, right: true),
            ],
          ),
        ),
    ],
  );

  Widget _totals() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceSm),
        child: Row(
          children: [
            _cell('TOTAL:', 7, right: true, style: _label),
            _cell(doc.totalTime.hms, 2, right: true, style: _value),
            _cell(_money(doc.subtotal), 2, right: true, style: _value),
          ],
        ),
      ),
      if (doc.tax != null)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.spaceSm,
            vertical: AppTokens.space4xs,
          ),
          child: Row(
            children: [
              _cell(
                '${doc.tax!.label} (${doc.tax!.rate}%):',
                9,
                right: true,
                style: _label,
              ),
              _cell(_money(doc.tax!.amount), 2, right: true, style: _value),
            ],
          ),
        ),
      const SizedBox(height: AppTokens.space3xs),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppTokens.spaceSm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('AMOUNT DUE:  ', style: _label),
            Text(
              '${_money(doc.amountDue)} ${doc.currency}',
              style: TextStyle(
                color: _primary,
                fontSize: _fontAmountDue,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _payments() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Please make payments to:',
        style: TextStyle(
          color: _primary,
          fontSize: AppTokens.fontSizeSm,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: AppTokens.space2xs),
      if (doc.paymentLink != null) _field('Link', doc.paymentLink),
      const SizedBox(height: AppTokens.spaceXs),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _field('NAME', doc.payeeName)),
          const SizedBox(width: AppTokens.spaceXs),
          Expanded(child: _field('ACN/ABN', doc.senderAbn)),
          const SizedBox(width: AppTokens.spaceXs),
          Expanded(child: _field('SWIFT/BIC', doc.swift)),
          const SizedBox(width: AppTokens.spaceXs),
          Expanded(child: _field('BANK', doc.bankName)),
        ],
      ),
    ],
  );
}
