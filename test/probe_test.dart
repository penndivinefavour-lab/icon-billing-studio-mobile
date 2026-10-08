library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icon_billing_studio/core/seed.dart';
import 'package:icon_billing_studio/models/models.dart';

void main() {
  test('dump seed invoice totals', () {
    for (final inv in seedInvoices()) {
      final t = computeTotals(inv);
      print('PROBE ${inv.number} ${inv.template} status=${inv.status} '
          'items=${inv.items.length} subtotal=${t.subtotal} '
          'disc=${t.discountTotal} tax=${t.taxTotal} ship=${t.shipping} '
          'total=${t.total}');
      for (final li in inv.items) {
        print('   li qty=${li.quantity} price=${li.unitPrice} '
            'disc%=${li.discount} tax%=${li.taxRate} net=${li.net}');
      }
    }
  });
}
