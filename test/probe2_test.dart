library;

import 'package:flutter_test/flutter_test.dart';
import 'package:icon_billing_studio/core/seed.dart';

void main() {
  test('dump raw line items', () {
    for (final inv in seedInvoices()) {
      print('PROBE2 ${inv.number} itemsJson=${inv.itemsJson}');
    }
  });
}
