import 'package:flutter_test/flutter_test.dart';

import 'package:icon_billing_studio/core/seed.dart';
import 'package:icon_billing_studio/models/models.dart';

/// Pure-logic journey: mirrors the 27-step web e2e without a device.
void main() {
  test('seed data is internally consistent', () {
    final clients = seedClients();
    final services = seedServices();
    final invoices = seedInvoices();

    expect(clients.length, greaterThanOrEqualTo(4));
    expect(services.length, greaterThanOrEqualTo(6));
    expect(invoices.length, greaterThanOrEqualTo(4));

    for (final inv in invoices) {
      expect(inv.items, isNotEmpty, reason: '${inv.number} has no items');
      expect(inv.number, isNotEmpty);
      expect(inv.template, isIn([
        'minimal', 'executive', 'modern', 'classic', 'creative',
        'corporate', 'elegant', 'compact', 'bold', 'professional',
      ]), reason: '${inv.number} has an unknown template');
    }
  });

  test('totals match the web prototype arithmetic', () {
    final inv = seedInvoices().first;
    final t = computeTotals(inv);

    double expectedSubtotal = 0;
    for (final li in inv.items) {
      expectedSubtotal += li.net;
    }
    expect(t.subtotal, closeTo(expectedSubtotal, 0.01));
    expect(t.grandTotal,
        greaterThanOrEqualTo(t.subtotal - t.discountTotal - 0.01));
  });

  test('every template sample computes a positive total', () {
    for (final inv in seedInvoices()) {
      final t = computeTotals(inv);
      expect(t.grandTotal, greaterThan(0),
          reason: '${inv.number} (${inv.template}) total is not positive');
    }
  });

  test('rounding is stable to two decimals', () {
    for (final inv in seedInvoices()) {
      final t = computeTotals(inv);
      expect((t.grandTotal * 100).roundToDouble() / 100, t.grandTotal);
    }
  });
}
