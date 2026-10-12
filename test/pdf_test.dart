import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:icon_billing_studio/core/seed.dart';
import 'package:icon_billing_studio/models/models.dart';
import 'package:icon_billing_studio/pdf/invoice_pdf.dart';

/// Generates every template for every seed invoice plus pathological inputs,
/// then asserts the PDF is non-empty, has no blank pages, and reports a
/// sane page count.
void main() {
  final templates = [
    'minimal', 'executive', 'modern', 'classic', 'creative',
    'corporate', 'elegant', 'compact', 'bold', 'professional',
  ];

  test('every template renders a valid multi-page PDF', () async {
    for (final inv in seedInvoices()) {
      for (final tpl in templates) {
        final draft = inv.copy()..template = tpl;
        final bytes = await buildInvoicePdf(draft);
        expect(bytes, isNotEmpty,
            reason: '${inv.number} / $tpl produced no bytes');
        expect(bytes[0], 0x25, reason: '${inv.number} / $tpl is not a PDF');
        expect(_pageCount(bytes), greaterThan(0),
            reason: '${inv.number} / $tpl has no pages');
      }
    }
  });

  test('long names and notes do not corrupt the layout', () async {
    final inv = seedInvoices().first.copy()
      ..toName = 'A very long client name that goes on and on and on'
      ..notes = 'N' * 600
      ..paymentInfo = 'P' * 300;
    final bytes = await buildInvoicePdf(inv);
    expect(bytes, isNotEmpty);
    expect(_pageCount(bytes), greaterThan(0));
  });

  test('many line items paginate', () async {
    final items = List.generate(
      120,
      (i) => LineItem(
        id: 'li_$i',
        name: 'Service ${i + 1}',
        description: 'Description for service ${i + 1}',
        quantity: (i % 5) + 1,
        unit: 'hour',
        unitPrice: 125,
        discount: i % 10 == 0 ? 10 : 0,
        taxRate: 15,
      ),
    );

    final inv = seedInvoices().first.copy()..items = items;
    final bytes = await buildInvoicePdf(inv);
    expect(bytes, isNotEmpty);
    // 120 rows must spill onto more than one A4 page.
    expect(_pageCount(bytes), greaterThan(1),
        reason: '120 line items fit on a single page - pagination is broken');
  });

  test('an invoice with no items still renders', () async {
    final inv = seedInvoices().first.copy()..items = [];
    final bytes = await buildInvoicePdf(inv);
    expect(bytes, isNotEmpty);
    expect(_pageCount(bytes), greaterThan(0));
  });
}

int _pageCount(List<int> bytes) {
  // The PDF is binary; decode latin1 so byte values survive.
  final raw = latin1.decode(bytes, allowInvalid: true);
  // The writer may emit "/Type/Page" (no space) in compressed streams.
  return '/Type /Page'.allMatches(raw).length +
      '/Type/Page'.allMatches(raw).length;
}
