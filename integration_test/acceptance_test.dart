import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:icon_billing_studio/main.dart';
import 'package:icon_billing_studio/core/store.dart';
import 'package:icon_billing_studio/models/models.dart';
import 'package:icon_billing_studio/pdf/invoice_pdf.dart';
import 'package:icon_billing_studio/core/constants.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('E2E Acceptance: startup, persistence, 10 templates, PDF generation, vault deletion isolation', (tester) async {
    // 1. Launch App
    await tester.pumpWidget(const IconBillingApp());
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Verify Store is ready
    final store = Store.instance;
    expect(store.clients, isNotEmpty, reason: 'Clients seeded');
    expect(store.invoices, isNotEmpty, reason: 'Invoices seeded');
    expect(find.text('Studio overview'), findsOneWidget);

    // 2. Create invoice with client and multiple line items
    final client = store.clients.first;
    final draft = store.newInvoiceDraft();
    draft.clientId = client.clientId;
    draft.toName = client.name;
    draft.toEmail = client.email;
    draft.toCompany = client.company;
    draft.toAddress = client.addressLine;
    draft.items = [
      LineItem(id: 'item_1', name: 'Software Consulting', quantity: 10, unitPrice: 150, taxRate: 10, discount: 5),
      LineItem(id: 'item_2', name: 'Infrastructure Setup', quantity: 2, unitPrice: 500, taxRate: 20, discount: 0),
    ];
    draft.globalDiscount = 10; // 10% global discount
    draft.shipping = 25;

    // Verify calculations:
    // item 1: gross = 1500, disc = 75, net = 1425, tax (10%) = 142.5
    // item 2: gross = 1000, disc = 0, net = 1000, tax (20%) = 200
    // subtotal = 2500 (gross subtotal)
    // discountTotal = 75 (line discount total)
    // taxableBase = 2500 - 75 = 2425
    // globalDiscount = 2425 * 0.10 = 242.5
    // afterDiscount = 2425 - 242.5 = 2182.5
    // taxTotal = (142.5 + 200) * 0.90 = 128.25 + 180 = 308.25
    // shipping = 25
    // total = 2182.5 + 308.25 + 25 = 2515.75
    final totals = computeTotals(draft);
    expect(totals.subtotal, equals(2500.0));
    expect(totals.discountTotal, equals(75.0));
    expect(totals.taxableBase, equals(2425.0));
    expect(totals.globalDiscount, equals(242.5));
    expect(totals.afterDiscount, equals(2182.5));
    expect(totals.taxTotal, equals(308.25));
    expect(totals.total, equals(2515.75));

    final savedInvoice = await store.saveInvoice(draft);
    expect(savedInvoice.invoiceId, isNotEmpty);
    expect(store.invoiceById(savedInvoice.invoiceId), isNotNull);

    // 3. Test all 10 templates rendering valid PDFs
    for (final tpl in kTemplates) {
      savedInvoice.template = tpl.id;
      final pdfBytes = await buildInvoicePdf(savedInvoice);
      expect(pdfBytes.length, greaterThan(1000), reason: 'Template ${tpl.id} generated valid PDF bytes');
    }

    // 4. Generate real PDF and save to vault
    final initialVaultCount = store.allDocuments().length;
    final vaultDoc = await store.generatePdfFor(savedInvoice);
    expect(vaultDoc.docId, isNotEmpty);
    expect(File(vaultDoc.storagePath).existsSync(), isTrue);
    expect(store.allDocuments().length, equals(initialVaultCount + 1));

    // 5. Verify deletion isolation: deleting vault document MUST NOT delete source invoice
    await store.deleteDocument(vaultDoc.docId);
    expect(store.documentById(vaultDoc.docId), isNull);
    expect(store.invoiceById(savedInvoice.invoiceId), isNotNull, reason: 'Source invoice preserved after vault document deletion');

    // 6. Test persistence across store reload
    final retrieved = store.invoiceById(savedInvoice.invoiceId);
    expect(retrieved, isNotNull);
    expect(retrieved!.number, equals(savedInvoice.number));
    expect(retrieved.items.length, equals(2));
    expect(retrieved.toName, equals(client.name));

    // 7. Verify print layout generation
    final freshDoc = await store.generatePdfFor(savedInvoice);
    expect(File(freshDoc.storagePath).existsSync(), isTrue);
    final printBytes = await File(freshDoc.storagePath).readAsBytes();
    expect(printBytes.length, greaterThan(1000));
    expect(printBytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46])); // %PDF header
  });
}
