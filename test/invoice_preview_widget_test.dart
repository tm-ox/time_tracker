import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timedart/data/database.dart';
import 'package:timedart/features/invoices/invoice_document.dart';
import 'package:timedart/features/invoices/invoice_preview.dart';
import 'package:timedart/features/invoices/invoice_region.dart';

// Widget-level smoke coverage for invoicePreviewPage's layout — especially the
// narrow (phone) zoom paths, which neither the author nor tm can eyeball until
// a mobile release is cut. Asserts the tree lays out without throwing at a
// phone width in every embedding: the self-contained invoice view (scrollable,
// bounded by an Expanded) and the editor previews (scrollable: false, inside an
// unbounded scroll → capped zoom window).

final _t = DateTime(2026, 4, 25, 9);
final _issue = DateTime(2026, 6, 15);

InvoiceDocument _doc() => buildInvoiceDocument(
  profile: InvoiceProfile(
    id: 'pf1',
    name: 'Default',
    businessName: 'tmox.net',
    currency: 'AUD',
    isDefault: true,
    region: InvoiceRegion.au.name,
    showBank: true,
    showPaymentLink: true,
    showTax: true,
    showRateColumn: true,
    showTimeColumn: true,
    reverseCharge: false,
    createdAt: _t,
    updatedAt: _t,
  ),
  project: Project(
    id: 'p1',
    clientId: 'c1',
    code: 'CD002',
    title: 'Care Direct work',
    status: 'active',
    createdAt: _t,
    updatedAt: _t,
  ),
  client: Client(
    id: 'c1',
    name: 'Client A',
    defaultRate: 46,
    createdAt: _t,
    updatedAt: _t,
  ),
  tasks: [
    Task(
      id: 't1',
      projectId: 'p1',
      title: 'Mobile',
      status: 'active',
      createdAt: _t,
      updatedAt: _t,
    ),
  ],
  entries: [
    TimeEntry(
      id: 'e1',
      projectId: 'p1',
      taskId: 't1',
      startedAt: _t,
      endedAt: _t.add(const Duration(hours: 1)),
      seconds: 3600,
      createdAt: _t,
      updatedAt: _t,
    ),
  ],
  from: DateTime(2026, 4, 1),
  to: DateTime(2026, 4, 30),
  issueDate: _issue,
);

const _template = InvoiceTemplate(
  id: 'tpl1',
  name: 'Default',
  colorBackground: 0xFF0D0D0D,
  colorSurface: 0xFF1A1A1A,
  colorPrimary: 0xFF4ADE80,
  colorText: 0xFFE5E5E5,
  colorAccent: 0xFF4ADE80,
  fontFamily: 'Mona Sans',
  isDefault: true,
);

// Pump [child] at a fixed logical size so context.isNarrow reflects the width
// under test rather than the host's default surface.
Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget child,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: child)),
  );
  await tester.pumpAndSettle();
}

void main() {
  const narrow = Size(360, 720);
  const wide = Size(1200, 900);

  testWidgets('invoice-view preview lays out at phone width (zoomable)', (
    tester,
  ) async {
    // Mirrors the invoice view: a bounded slot the zoom viewer fills.
    await _pumpAt(
      tester,
      narrow,
      Column(
        children: [
          Expanded(
            child: invoicePreviewPage(doc: _doc(), template: _template),
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(InteractiveViewer), findsOneWidget);
  });

  testWidgets('editor preview lays out at phone width (A4-proportioned window)', (
    tester,
  ) async {
    // Mirrors the editors: scrollable: false inside an unbounded scroll.
    await _pumpAt(
      tester,
      narrow,
      SingleChildScrollView(
        child: Column(
          children: [
            invoicePreviewPage(
              doc: _doc(),
              template: _template,
              scrollable: false,
            ),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    // The resting zoom window is an A4-proportioned box (height/width ≈ 297/210)
    // — a whole proportional page, not a crunched fixed-height slice.
    final box = tester.getSize(find.byType(InteractiveViewer));
    expect(box.height / box.width, closeTo(297 / 210, 0.01));
  });

  testWidgets('desktop preview stays a plain fitted page (no zoom)', (
    tester,
  ) async {
    await _pumpAt(
      tester,
      wide,
      Column(
        children: [
          Expanded(
            child: invoicePreviewPage(doc: _doc(), template: _template),
          ),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(InteractiveViewer), findsNothing);
  });
}
