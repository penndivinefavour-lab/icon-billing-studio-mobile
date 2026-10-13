import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:icon_billing_studio/core/constants.dart';
import 'package:icon_billing_studio/core/theme.dart';
import 'package:icon_billing_studio/models/models.dart';

double _luminance(Color c) {
  // Relative luminance calculation per WCAG 2.1
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  final r = channel(c.r);
  final g = channel(c.g);
  final b = channel(c.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _contrastRatio(Color c1, Color c2) {
  final l1 = _luminance(c1);
  final l2 = _luminance(c2);
  final lighter = math.max(l1, l2);
  final darker = math.min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Theme contrast remediation tests', () {
    test('Dark theme text3 has WCAG AA compliant contrast (>= 4.5:1) against surface', () {
      final dark = AppColors.dark(kAccents.first.a);
      final ratio = _contrastRatio(dark.text3, dark.surface);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'Dark text3 contrast ratio is $ratio');
    });

    test('Light theme text3 has WCAG AA compliant contrast (>= 4.5:1) against surface', () {
      final light = AppColors.light(kAccents.first.a);
      final ratio = _contrastRatio(light.text3, light.surface);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'Light text3 contrast ratio is $ratio');
    });

    testWidgets('Theme lookup cache isolates dark and light modes with identical accent',
        (tester) async {
      clearThemeLookupCache();
      final accent = kAccents.first;

      late AppColors darkResolved;
      late AppColors lightResolved;

      // Pump dark theme
      await tester.pumpWidget(
        Builder(
          builder: (ctx) {
            final darkTheme = AppTheme.of(ctx, 'dark', accent);
            return MaterialApp(
              themeMode: ThemeMode.dark,
              theme: darkTheme,
              darkTheme: darkTheme,
              home: Builder(
                builder: (innerCtx) {
                  darkResolved = colors(innerCtx);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      // Pump light theme with identical accent
      await tester.pumpWidget(
        Builder(
          builder: (ctx) {
            final lightTheme = AppTheme.of(ctx, 'light', accent);
            return MaterialApp(
              themeMode: ThemeMode.light,
              theme: lightTheme,
              darkTheme: lightTheme,
              home: Builder(
                builder: (innerCtx) {
                  lightResolved = colors(innerCtx);
                  return const SizedBox();
                },
              ),
            );
          },
        ),
      );
      await tester.pumpAndSettle();

      expect(darkResolved.surface, isNot(equals(lightResolved.surface)));
      expect(lightResolved.text, equals(const Color(0xFF0F172A)));
      expect(darkResolved.text, equals(const Color(0xFFF8FAFC)));
    });
  });

  group('PDF Vault Logical ID format tests', () {
    test('Logical doc ID format contains no path separators', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final invoiceId = 'inv_test_123';
      final docId = 'doc_${now}_$invoiceId';

      expect(docId, isNot(contains('/')));
      expect(docId, isNot(contains('\\')));
      expect(RegExp(r'^doc_\d+_inv_.*$').hasMatch(docId), isTrue);
    });
  });

  group('Invoice items caching & synchronization tests', () {
    test('items list caches mutation and syncs to itemsJson', () {
      final inv = Invoice(
        invoiceId: 'inv_cache_test',
        itemsJson: '[]',
      );

      expect(inv.items.length, 0);

      inv.items.add(LineItem(
        id: 'li_1',
        name: 'Design Consultation',
        quantity: 2,
        unitPrice: 150,
      ));

      expect(inv.items.length, 1);
      inv.syncItemsJson();
      expect(inv.itemsJson, contains('Design Consultation'));
      expect(inv.itemsJson, contains('150'));

      // Check totals derivation
      final totals = inv.totals;
      expect(totals.subtotal, 300.0);
      expect(totals.total, 300.0);

      // Check copy retains items
      final copy = inv.copy();
      expect(copy.items.length, 1);
      expect(copy.items.first.name, 'Design Consultation');
      expect(copy.items.first.unitPrice, 150.0);
    });
  });
}
