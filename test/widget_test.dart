/// Pure unit tests for format helpers and kit widgets.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:icon_billing_studio/core/constants.dart';
import 'package:icon_billing_studio/core/format.dart' as fmt;
import 'package:icon_billing_studio/core/theme.dart';
import 'package:icon_billing_studio/ui/kit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('format helpers', () {
    test('formatMoney matches the en-US currency style', () {
      expect(fmt.formatMoney(1234.5, 'USD'), r'$1,234.50');
      expect(fmt.formatMoney(0, 'EUR'), 'â‚¬0.00');
      expect(fmt.formatMoney(9, ''), r'$9.00');
    });

    test('formatNumber groups digits', () {
      expect(fmt.formatNumber(1234567, 0), '1,234,567');
      expect(fmt.formatNumber(42.5, 1), '42.5');
    });

    test('formatDate renders medium and long styles', () {
      final d = DateTime(2026, 10, 5);
      expect(fmt.formatDate(d), '5 Oct 2026');
      expect(fmt.formatDate(d, long: true), 'Mon, 5 October 2026');
      expect(fmt.formatDate(null), 'â€”');
    });

    test('safeFileName sanitises number + client', () {
      expect(fmt.pdfFileName('INV-1042', 'Acme Corp', false), 'INV-1042-Acme-Corp.pdf');
      expect(fmt.pdfFileName('Q-7', 'ONeil & Sons', true), 'QUO-7-ONeil-Sons.pdf');
      expect(fmt.pdfFileName('', '', false), 'INV---Document.pdf');
    });

    test('initials takes the first two words', () {
      expect(fmt.initials('Jane Marie Doe'), 'JM');
      expect(fmt.initials('  acme  '), 'A');
      expect(fmt.initials(''), '?');
    });

    test('relativeDue badges', () {
      expect(fmt.relativeDue(DateTime.now(), 'paid'), isNull);
      expect(fmt.relativeDue(DateTime.now(), 'draft'), isNull);
      expect(
          fmt.relativeDue(DateTime.now().add(const Duration(days: 3)), 'sent')!.label,
          'Due in 3d');
      expect(
          fmt.relativeDue(
                  DateTime.now().subtract(const Duration(days: 2)), 'sent')!
              .label,
          '2d overdue');
    });
  });

  group('template registry', () {
    test('has exactly the ten prototype templates', () {
      expect(kTemplates.length, 10);
      expect(
          kTemplates.map((t) => t.id).toList(),
          [
            'minimal',
            'executive',
            'modern',
            'classic',
            'creative',
            'corporate',
            'elegant',
            'compact',
            'bold',
            'professional',
          ]);
      for (final t in kTemplates) {
        expect(templateName(t.id), t.name);
      }
      expect(templateName('does-not-exist'), 'Executive');
    });
  });

  group('kit widgets', () {
    testWidgets('EmptyState renders title, message and fires action',
        (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: EmptyState(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Nothing here yet',
              message: 'Some supporting copy for the empty state.',
              actionLabel: 'New invoice',
              onAction: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(
          find.text('Some supporting copy for the empty state.'), findsOneWidget);
      await tester.tap(find.text('New invoice'));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('ListRow shows child content and handles taps', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ListRow(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('INV-1042 Â· Acme Corp',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.1)),
                  const Text(r'$6,120.00 Â· due Oct 15',
                      style: TextStyle(color: Color(0xFF4A5260), fontSize: 11.4)),
                ],
              ),
              onTap: () => taps++,
            ),
          ),
        ),
      );

      expect(find.text('INV-1042 Â· Acme Corp'), findsOneWidget);
      await tester.tap(find.text('INV-1042 Â· Acme Corp'));
      await tester.pump();
      expect(taps, 1);
    });
  });
}

