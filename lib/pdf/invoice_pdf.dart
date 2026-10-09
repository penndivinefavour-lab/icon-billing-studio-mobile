library;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/format.dart';
import '../models/models.dart';

/// A4 page with safe margins.
const _pageFormat = PdfPageFormat.a4;
const _margin = 42.0;

/// [PdfColor] is immutable, so tinting rebuilds the colour with a new alpha.
PdfColor tint(PdfColor c, double alpha) =>
    PdfColor(c.red, c.green, c.blue, alpha);

/// Context handed to every template painter.
class PdfContext {
  final Invoice invoice;
  final Totals totals;
  final PdfColor accent;
  final PdfColor accentSoft;
  final PdfColor accentDark;
  final PdfColor onAccent;
  final String currency;
  final String docLabel;
  final String kindLabel;
  final String Function(double) money;
  final String Function(DateTime?) fmt;

  PdfContext({
    required this.invoice,
    required this.totals,
    required this.accent,
    required this.accentSoft,
    required this.accentDark,
    required this.onAccent,
    required this.currency,
    required this.docLabel,
    required this.kindLabel,
    required this.money,
    required this.fmt,
  });
}

/* ---------------------------------------------------------------- helpers */

PdfColor _hex(String hex) {
  final c = hex.replaceFirst('#', '');
  final value = c.length == 6
      ? int.parse('FF$c', radix: 16)
      : int.parse(c, radix: 16);
  return PdfColor.fromInt(value);
}

PdfColor _shade(PdfColor c, double f) {
  double apply(double v) {
    if (f >= 0) return (v + (1 - v) * f).clamp(0, 1);
    return (v * (1 + f)).clamp(0, 1);
  }
  return PdfColor(apply(c.red), apply(c.green), apply(c.blue), c.alpha);
}

PdfColor _onColor(PdfColor c) {
  final l = 0.299 * c.red + 0.587 * c.green + 0.114 * c.blue;
  return l > 0.62 ? const PdfColor.fromInt(0xFF14161B) : PdfColors.white;
}

/// Build the render context from an invoice.
PdfContext ctxFor(Invoice invoice) {
  final accent = _hex(invoice.accent);
  return PdfContext(
    invoice: invoice,
    totals: invoice.computedTotals(),
    accent: accent,
    accentSoft: _shade(accent, 0.14),
    accentDark: _shade(accent, -0.18),
    onAccent: _onColor(accent),
    currency: invoice.currency,
    docLabel: invoice.docLabel,
    kindLabel: invoice.isQuotation ? 'QUOTATION' : 'INVOICE',
    money: (v) => formatMoneyPdf(v, invoice.currency),
    fmt: (d) => formatDatePdf(d),
  );
}

String formatMoneyPdf(double value, String currency) => formatMoney(value, currency);

String formatDatePdf(DateTime? d) {
  if (d == null) return '-';
  return formatDate(d);
}

/// Table column widths shared by the templates.
final _colWidths = {
  'name': 1.9,
  'qty': 0.55,
  'unit': 0.5,
  'price': 0.8,
  'disc': 0.5,
  'tax': 0.5,
  'amount': 0.85,
};

String formatQuantityPdf(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(2);
}

/// Rows per page-sized chunk. [pw.MultiPage] can only break between top-level
/// children, so a single giant Table is unbreakable; emit one chunk per page.
const int _rowsPerPage = 18;

/// Hard cap so a hostile document still renders.
const int _maxItemRows = 200;

/// The shared item table. Multi-page safe: the header repeats on every page
/// and rows never clip.
pw.Widget itemsTable(PdfContext ctx, {bool banded = true, PdfColor? zebra}) {
  final inv = ctx.invoice;
  final band = zebra ?? PdfColors.grey100;
  return pw.Table(
    border: pw.TableBorder(
      horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
      top: pw.BorderSide(color: PdfColors.grey400, width: 0.7),
      bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.7),
    ),
    defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
    columnWidths: {
      0: const pw.FlexColumnWidth(1.9),
      1: const pw.FlexColumnWidth(0.55),
      2: const pw.FlexColumnWidth(0.5),
      3: const pw.FlexColumnWidth(0.8),
      4: const pw.FlexColumnWidth(0.5),
      5: const pw.FlexColumnWidth(0.5),
      6: const pw.FlexColumnWidth(0.85),
    },
    children: [
      _headerRow(ctx),
      for (int i = 0; i < inv.items.length && i < _maxItemRows; i++)
        _itemRow(ctx, inv.items[i], i, banded: banded, band: band),
    ],
  );
}

/// [pw.MultiPage] paginates between top-level children, not inside a Table.
/// Splitting the rows into page-sized chunks lets long invoices flow across
/// pages instead of overflowing.
List<pw.Widget> itemsTableChunked(PdfContext ctx,
    {bool banded = true, PdfColor? zebra}) {
  final inv = ctx.invoice;
  final band = zebra ?? PdfColors.grey100;
  final rows = inv.items.take(_maxItemRows).toList();
  if (rows.length <= _rowsPerPage) return [itemsTable(ctx, banded: banded)];

  final chunks = <pw.Widget>[];
  for (var start = 0; start < rows.length; start += _rowsPerPage) {
    final slice = rows.skip(start).take(_rowsPerPage).toList();
    chunks.add(pw.Table(
      border: pw.TableBorder(
        horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
        top: pw.BorderSide(color: PdfColors.grey400, width: 0.7),
        bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.7),
      ),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: {
        0: const pw.FlexColumnWidth(1.9),
        1: const pw.FlexColumnWidth(0.55),
        2: const pw.FlexColumnWidth(0.5),
        3: const pw.FlexColumnWidth(0.8),
        4: const pw.FlexColumnWidth(0.5),
        5: const pw.FlexColumnWidth(0.5),
        6: const pw.FlexColumnWidth(0.85),
      },
      children: [
        if (start == 0) _headerRow(ctx),
        for (int i = 0; i < slice.length; i++)
          _itemRow(ctx, slice[i], start + i, banded: banded, band: band),
      ],
    ));
    if (start + _rowsPerPage < rows.length) {
      chunks.add(pw.SizedBox(height: 8));
    }
  }
  return chunks;
}

pw.TableRow _headerRow(PdfContext ctx) {
  final style = pw.TextStyle(
    fontSize: 7.5,
    fontWeight: pw.FontWeight.bold,
    color: PdfColors.grey700,
    
  );
  return pw.TableRow(
    decoration: const pw.BoxDecoration(color: PdfColors.grey100),
    children: [
      _cell('Item', style, align: pw.TextAlign.left),
      _cell('Qty', style),
      _cell('Unit', style),
      _cell('Unit price', style),
      _cell('Disc', style),
      _cell('Tax', style),
      _cell('Amount', style),
    ],
  );
}

pw.TableRow _itemRow(PdfContext ctx, LineItem it, int index,
    {required bool banded, required PdfColor band}) {
  final base = pw.TextStyle(fontSize: 8.5, color: PdfColors.black);
  final num = pw.TextStyle(
      fontSize: 8.5, color: PdfColors.black, );
  return pw.TableRow(
    decoration: banded && index.isOdd ? pw.BoxDecoration(color: band) : null,
    children: [
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(it.name, style: base.copyWith(fontWeight: pw.FontWeight.bold)),
            if (it.description.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 1.5),
                child: pw.Text(
                  it.description,
                  style: base.copyWith(color: PdfColors.grey600, fontSize: 7.5),
                ),
              ),
          ],
        ),
      ),
      _cell(formatQuantityPdf(it.quantity), num),
      _cell(it.unit, base),
      _cell(ctx.money(it.unitPrice), num),
      _cell('${it.discount.toStringAsFixed(0)}%', num),
      _cell('${it.taxRate.toStringAsFixed(0)}%', num),
      _cell(ctx.money(it.net), num.copyWith(fontWeight: pw.FontWeight.bold)),
    ],
  );
}

pw.Widget _cell(String text, pw.TextStyle style, {pw.TextAlign align = pw.TextAlign.right}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
    child: pw.Text(text, style: style, textAlign: align),
  );
}

/// The shared totals block. Left label column, right amount column.
pw.Widget totalsBlock(PdfContext ctx, {bool panel = false}) {
  final t = ctx.totals;
  final rows = <_TotalRow>[
    _TotalRow('Subtotal', ctx.money(t.subtotal)),
  ];
  if (t.discountTotal > 0) {
    rows.add(_TotalRow('Line discounts', '-${ctx.money(t.discountTotal)}'));
  }
  if (t.globalDiscount > 0) {
    rows.add(_TotalRow(
        'Global discount (${ctx.invoice.globalDiscount.toStringAsFixed(0)}%)',
        '-${ctx.money(t.globalDiscount)}'));
  }
  for (final tax in t.taxes) {
    rows.add(_TotalRow('Tax ${tax.rate.toStringAsFixed(0)}%', ctx.money(tax.amount)));
  }
  if (t.shipping > 0) {
    rows.add(_TotalRow('Shipping', ctx.money(t.shipping)));
  }

  final labelStyle = pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700);
  final valueStyle = pw.TextStyle(
      fontSize: 8.5,
      color: PdfColors.black,
      fontWeight: pw.FontWeight.bold,
      );

  return pw.Container(
    decoration: panel
        ? pw.BoxDecoration(
            color: PdfColors.grey50,
            border: pw.Border.all(color: PdfColors.grey200, width: 0.6),
          )
        : null,
    padding: panel ? const pw.EdgeInsets.all(12) : pw.EdgeInsets.zero,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final r in rows)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Row(
              children: [
                pw.Expanded(child: pw.Text(r.label, style: labelStyle)),
                pw.SizedBox(
                  width: 80,
                  child: pw.Text(r.amount,
                      style: valueStyle, textAlign: pw.TextAlign.right),
                ),
              ],
            ),
          ),
        pw.Container(
          margin: const pw.EdgeInsets.only(top: 6),
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: pw.BoxDecoration(color: ctx.accent),
          child: pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Total ${ctx.docLabel.toLowerCase()}',
                  style: pw.TextStyle(
                      fontSize: 10,
                      fontWeight: pw.FontWeight.bold,
                      color: ctx.onAccent),
                ),
              ),
              pw.Text(
                ctx.money(t.total),
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: ctx.onAccent,
                    ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}


class _TotalRow {
  final String label;
  final String amount;
  _TotalRow(this.label, this.amount);
}

/// Date rows used by most templates.
List<_Meta> metaRows(PdfContext ctx) {
  final inv = ctx.invoice;
  return [
    _Meta('Issue date', ctx.fmt(inv.issuedOn)),
    _Meta(inv.isQuotation ? 'Valid until' : 'Due date', ctx.fmt(inv.dueOn)),
    if (inv.poNumber.isNotEmpty) _Meta('PO number', inv.poNumber),
  ];
}

class _Meta {
  final String k;
  final String v;
  _Meta(this.k, this.v);
}

pw.Widget metaBlock(PdfContext ctx) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      for (final m in metaRows(ctx))
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 3),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 68,
                child: pw.Text(m.k,
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ),
              pw.Text(m.v,
                  style: pw.TextStyle(
                      fontSize: 8.5,
                      color: PdfColors.black,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
    ],
  );
}

pw.Widget partyBlock(String title, Invoice inv, {required bool from}) {
  final name = from ? inv.fromName : inv.toName;
  final email = from ? inv.fromEmail : inv.toEmail;
  final company = from ? '' : inv.toCompany;
  final address = from ? '' : inv.toAddress;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(title.toUpperCase(),
          style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey500,
              letterSpacing: 0.8)),
      pw.SizedBox(height: 3),
      pw.Text(name,
          style: pw.TextStyle(
              fontSize: 10.5,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black)),
      if (company.isNotEmpty)
        pw.Text(company,
            style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
      if (email.isNotEmpty)
        pw.Text(email, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      if (address.isNotEmpty)
        pw.Text(address, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ],
  );
}

pw.Widget notesBlock(Invoice inv) {
  final hasNotes = inv.notes.isNotEmpty;
  final hasPay = inv.paymentInfo.isNotEmpty;
  if (!hasNotes && !hasPay) return pw.SizedBox();
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (hasNotes) ...[
        pw.Text('NOTES',
            style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey500,
                letterSpacing: 0.8)),
        pw.SizedBox(height: 3),
        pw.Text(inv.notes,
            style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700, height: 1.4)),
      ],
      if (hasNotes && hasPay) pw.SizedBox(height: 10),
      if (hasPay) ...[
        pw.Text('PAYMENT',
            style: pw.TextStyle(
                fontSize: 7,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey500,
                letterSpacing: 0.8)),
        pw.SizedBox(height: 3),
        pw.Text(inv.paymentInfo,
            style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700, height: 1.4)),
      ],
    ],
  );
}

/* ---------------------------------------------------------------- engine */

typedef TemplatePainter = pw.Widget Function(PdfContext ctx);

/// Registry of the ten template painters.
final Map<String, TemplatePainter> _painters = {
  'minimal': _minimal,
  'executive': _executive,
  'modern': _modern,
  'classic': _classic,
  'creative': _creative,
  'corporate': _corporate,
  'elegant': _elegant,
  'compact': _compact,
  'bold': _bold,
  'professional': _professional,
};

List<String> templateNames() => _painters.keys.toList();

/// Render an invoice to PDF bytes.
Future<List<int>> buildInvoicePdf(Invoice invoice) async {
  final ctx = ctxFor(invoice);
  final doc = pw.Document();
  final painter = _painters[invoice.template] ?? _executive;
  doc.addPage(
    pw.MultiPage(
      pageFormat: _pageFormat,
      margin: const pw.EdgeInsets.all(_margin),
      maxPages: 400,
      build: (context) => [painter(ctx)],
    ),
  );
  return doc.save();
}

/// Synchronous variant used by tests and the sharing pipeline.
Future<List<int>> buildInvoicePdfSync(Invoice invoice) => buildInvoicePdf(invoice);

/* =============================================================== 1 minimal */

pw.Widget _minimal(PdfContext ctx) {
  final inv = ctx.invoice;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(ctx.docLabel.toUpperCase(),
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: ctx.accent,
                      letterSpacing: 1.2)),
              pw.SizedBox(height: 4),
              pw.Text(inv.number,
                  style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                      )),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text(inv.fromName,
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
        ],
      ),
      pw.Container(margin: const pw.EdgeInsets.only(top: 12), height: 2, color: ctx.accent),
      pw.SizedBox(height: 18),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: partyBlock('From', inv, from: true)),
          pw.Expanded(child: partyBlock('To', inv, from: false)),
        ],
      ),
      pw.SizedBox(height: 18),
      metaBlock(ctx),
      pw.SizedBox(height: 18),
      ...itemsTableChunked(ctx),
      pw.SizedBox(height: 20),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
          pw.Expanded(flex: 3, child: notesBlock(inv)),
          pw.Expanded(flex: 2, child: totalsBlock(ctx)),
        ],
      ),
      pw.SizedBox(height: 24),
      pw.Container(
        margin: const pw.EdgeInsets.only(top: 18),
        padding: const pw.EdgeInsets.only(top: 10),
        decoration: pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: 0.6)),
        ),
        child: pw.Row(
          children: [
            if (inv.paymentInfo.isNotEmpty)
              pw.Expanded(
                  child: pw.Text(inv.paymentInfo,
                      style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600))),
            pw.Text('Thank you for your business.',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ),
    ],
  );
}

/* ============================================================= 2 executive */

pw.Widget _executive(PdfContext ctx) {
  final inv = ctx.invoice;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        color: ctx.accent,
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: pw.Row(
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(inv.fromName,
                    style: pw.TextStyle(
                        fontSize: 15, fontWeight: pw.FontWeight.bold, color: ctx.onAccent)),
                pw.SizedBox(height: 2),
                pw.Text(inv.fromEmail,
                    style: pw.TextStyle(fontSize: 8.5, color: ctx.onAccent)),
              ],
            ),
            pw.Spacer(),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(ctx.docLabel.toUpperCase(),
                    style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                        color: ctx.onAccent,
                        letterSpacing: 1.4)),
                pw.SizedBox(height: 4),
                pw.Text(inv.number,
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: ctx.onAccent,
                        )),
              ],
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 20),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: partyBlock('Billed to', inv, from: false)),
          pw.SizedBox(width: 20),
          metaBlock(ctx),
        ],
      ),
      pw.SizedBox(height: 20),
      ...itemsTableChunked(ctx),
      pw.SizedBox(height: 20),
      pw.Align(alignment: pw.Alignment.centerRight, child: totalsBlock(ctx, panel: true)),
      pw.SizedBox(height: 20),
      notesBlock(inv),
    ],
  );
}

/* =============================================================== 3 modern */

pw.Widget _modern(PdfContext ctx) {
  final inv = ctx.invoice;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(width: 6, color: ctx.accent),
      pw.Expanded(
        child: pw.Padding(
          padding: const pw.EdgeInsets.only(left: 16),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                children: [
                  pw.Text(inv.fromName,
                      style: pw.TextStyle(
                          fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                  pw.Spacer(),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    color: ctx.accent,
                    child: pw.Text(ctx.docLabel,
                        style: pw.TextStyle(
                            fontSize: 9, fontWeight: pw.FontWeight.bold, color: ctx.onAccent)),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(inv.number,
                  style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: ctx.accent,
                      )),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(child: partyBlock('From', inv, from: true)),
                  pw.Expanded(child: partyBlock('To', inv, from: false)),
                  pw.Expanded(child: metaBlock(ctx)),
                ],
              ),
              pw.SizedBox(height: 20),
              itemsTable(ctx, banded: true, zebra: tint(ctx.accent, 0.06)),
              pw.SizedBox(height: 20),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(flex: 3, child: notesBlock(inv)),
                  pw.Expanded(flex: 2, child: totalsBlock(ctx, panel: true)),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/* =============================================================== 4 classic */

pw.Widget _classic(PdfContext ctx) {
  final inv = ctx.invoice;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Center(
        child: pw.Column(
          children: [
            pw.Text(inv.fromName,
                style: pw.TextStyle(
                    fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
            pw.Container(
                margin: const pw.EdgeInsets.only(top: 8, bottom: 4),
                width: 120,
                height: 1.5,
                color: ctx.accent),
            pw.Text(ctx.docLabel,
                style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                    letterSpacing: 1.6,
                    fontWeight: pw.FontWeight.bold)),
            pw.Text('No. ${inv.number}',
                style: pw.TextStyle(
                    fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
          ],
        ),
      ),
      pw.SizedBox(height: 22),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: partyBlock('From', inv, from: true)),
          pw.Expanded(child: partyBlock('To', inv, from: false)),
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Container(height: 1, color: ctx.accent),
      pw.SizedBox(height: 2),
      pw.Container(height: 0.6, color: ctx.accent),
      pw.SizedBox(height: 12),
      metaBlock(ctx),
      pw.SizedBox(height: 14),
      ...itemsTableChunked(ctx),
      pw.SizedBox(height: 18),
      totalsBlock(ctx),
      pw.SizedBox(height: 18),
      notesBlock(inv),
    ],
  );
}

/* ============================================================= 5 creative */

pw.Widget _creative(PdfContext ctx) {
  final inv = ctx.invoice;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        color: ctx.accent,
        padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 22),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(inv.fromName,
                style: pw.TextStyle(
                    fontSize: 12, fontWeight: pw.FontWeight.bold, color: ctx.onAccent)),
            pw.SizedBox(height: 6),
            pw.Text(ctx.kindLabel,
                style: pw.TextStyle(
                    fontSize: 30,
                    fontWeight: pw.FontWeight.bold,
                    color: ctx.onAccent,
                    letterSpacing: 1.2)),
            pw.SizedBox(height: 4),
            pw.Text(inv.number,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: ctx.onAccent,
                    )),
            pw.SizedBox(height: 10),
            pw.Text('${ctx.fmt(inv.issuedOn)}  ->  ${ctx.fmt(inv.dueOn)}',
                style: pw.TextStyle(fontSize: 9, color: ctx.onAccent)),
          ],
        ),
      ),
      pw.SizedBox(height: 20),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: partyBlock('To', inv, from: false)),
          pw.Expanded(child: partyBlock('From', inv, from: true)),
        ],
      ),
      pw.SizedBox(height: 20),
      itemsTable(ctx, banded: true, zebra: tint(ctx.accent, 0.07)),
      pw.SizedBox(height: 20),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(flex: 3, child: notesBlock(inv)),
          pw.Expanded(flex: 2, child: totalsBlock(ctx)),
        ],
      ),
    ],
  );
}

/* ============================================================ 6 corporate */

pw.Widget _corporate(PdfContext ctx) {
  final inv = ctx.invoice;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: ctx.accent, width: 1.2),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: pw.Row(
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(inv.fromName,
                    style: pw.TextStyle(
                        fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                pw.Text(inv.fromEmail,
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ],
            ),
            pw.Spacer(),
            pw.Container(
              color: ctx.accent,
              padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: pw.Text(ctx.docLabel,
                  style: pw.TextStyle(
                      fontSize: 9, fontWeight: pw.FontWeight.bold, color: ctx.onAccent)),
            ),
          ],
        ),
      ),
      pw.SizedBox(height: 18),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                partyBlock('Client', inv, from: false),
                pw.SizedBox(height: 16),
                ...itemsTableChunked(ctx),
                pw.SizedBox(height: 14),
                notesBlock(inv),
              ],
            ),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(
            flex: 2,
            child: pw.Container(
              decoration: pw.BoxDecoration(
                color: tint(ctx.accent, 0.06),
                border: pw.Border.all(color: tint(ctx.accent, 0.25), width: 0.6),
              ),
              padding: const pw.EdgeInsets.all(12),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('SUMMARY',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: ctx.accent,
                          letterSpacing: 1)),
                  pw.SizedBox(height: 8),
                  totalsBlock(ctx),
                  pw.SizedBox(height: 12),
                  metaBlock(ctx),
                ],
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

/* ============================================================= 7 elegant */

pw.Widget _elegant(PdfContext ctx) {
  final inv = ctx.invoice;
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 24),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Column(
            children: [
              pw.Text(inv.fromName,
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
              pw.SizedBox(height: 6),
              pw.Text('- ${ctx.docLabel} -',
                  style: pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey600,
                      
                      fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 2),
              pw.Text(inv.number,
                  style: pw.TextStyle(
                      fontSize: 11, fontWeight: pw.FontWeight.bold, color: ctx.accent)),
            ],
          ),
        ),
        pw.SizedBox(height: 24),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: partyBlock('From', inv, from: true)),
            pw.Expanded(child: partyBlock('To', inv, from: false)),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Center(child: pw.Container(width: 60, height: 0.8, color: ctx.accent)),
        pw.SizedBox(height: 16),
        metaBlock(ctx),
        pw.SizedBox(height: 18),
        ...itemsTableChunked(ctx),
        pw.SizedBox(height: 20),
        totalsBlock(ctx),
        pw.SizedBox(height: 20),
        notesBlock(inv),
      ],
    ),
  );
}

/* ============================================================= 8 compact */

pw.Widget _compact(PdfContext ctx) {
  final inv = ctx.invoice;
  final line = pw.TextStyle(fontSize: 8.5, color: PdfColors.black);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        children: [
          pw.Text(inv.fromName,
              style: pw.TextStyle(
                  fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
          pw.Spacer(),
          pw.Text('${ctx.docLabel} ${inv.number}',
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: ctx.accent,
                  )),
        ],
      ),
      pw.Container(
          margin: const pw.EdgeInsets.only(top: 4, bottom: 6),
          height: 1.2,
          color: ctx.accent),
      pw.Text('${inv.fromEmail}${inv.fromPhone.isNotEmpty ? ' - ${inv.fromPhone}' : ''}',
          style: line.copyWith(color: PdfColors.grey600, fontSize: 7.5)),
      pw.SizedBox(height: 4),
      pw.Text(
          'To: ${inv.toName}${inv.toCompany.isNotEmpty ? ' - ${inv.toCompany}' : ''} - ${inv.toEmail}',
          style: line.copyWith(color: PdfColors.grey700, fontSize: 7.5)),
      pw.SizedBox(height: 4),
      pw.Text(
          'Date: ${ctx.fmt(inv.issuedOn)}  Due: ${ctx.fmt(inv.dueOn)}${inv.poNumber.isNotEmpty ? '  PO: ${inv.poNumber}' : ''}',
          style: line.copyWith(color: PdfColors.grey700, fontSize: 7.5)),
      pw.SizedBox(height: 12),
      ...itemsTableChunked(ctx),
      pw.SizedBox(height: 14),
      totalsBlock(ctx),
      pw.SizedBox(height: 12),
      if (inv.paymentInfo.isNotEmpty)
        pw.Text('Payment: ${inv.paymentInfo}',
            style: line.copyWith(color: PdfColors.grey700, fontSize: 7.5)),
      if (inv.notes.isNotEmpty) ...[
        pw.SizedBox(height: 4),
        pw.Text('Notes: ${inv.notes}',
            style: line.copyWith(color: PdfColors.grey700, fontSize: 7.5)),
      ],
    ],
  );
}

/* ================================================================ 9 bold */

pw.Widget _bold(PdfContext ctx) {
  final inv = ctx.invoice;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        color: ctx.accent,
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(ctx.docLabel.toUpperCase(),
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: ctx.onAccent,
                    letterSpacing: 1.6)),
            pw.SizedBox(height: 4),
            pw.Text(inv.number,
                style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: ctx.onAccent,
                    )),
            pw.SizedBox(height: 8),
            pw.Text(inv.fromName,
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold, color: ctx.onAccent)),
          ],
        ),
      ),
      pw.SizedBox(height: 20),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: partyBlock('To', inv, from: false)),
          pw.Expanded(child: partyBlock('From', inv, from: true)),
        ],
      ),
      pw.SizedBox(height: 16),
      pw.Container(
        color: tint(ctx.accent, 0.08),
        padding: const pw.EdgeInsets.all(10),
        child: metaBlock(ctx),
      ),
      pw.SizedBox(height: 18),
      ...itemsTableChunked(ctx),
      pw.SizedBox(height: 18),
      totalsBlock(ctx),
      pw.SizedBox(height: 18),
      notesBlock(inv),
    ],
  );
}

/* ====================================================== 10 professional */

pw.Widget _professional(PdfContext ctx) {
  final inv = ctx.invoice;
  final mark = inv.fromName.trim().split(RegExp(r'\s+')).first;
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Row(
        children: [
          pw.Container(
            width: 40,
            height: 40,
            color: ctx.accent,
            alignment: pw.Alignment.center,
            child: pw.Text(mark.substring(0, mark.length > 2 ? 2 : mark.length).toUpperCase(),
                style: pw.TextStyle(
                    fontSize: 13, fontWeight: pw.FontWeight.bold, color: ctx.onAccent)),
          ),
          pw.SizedBox(width: 12),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(inv.fromName,
                  style: pw.TextStyle(
                      fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
              pw.Text(inv.fromEmail,
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
          pw.Spacer(),
          pw.Text(ctx.docLabel,
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: ctx.accent,
                  letterSpacing: 1.2)),
        ],
      ),
      pw.Container(margin: const pw.EdgeInsets.only(top: 12), height: 2, color: ctx.accent),
      pw.SizedBox(height: 18),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: partyBlock('Bill to', inv, from: false)),
          pw.SizedBox(width: 16),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(inv.number,
                  style: pw.TextStyle(
                      fontSize: 14,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.black,
                      )),
              pw.SizedBox(height: 6),
              metaBlock(ctx),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 18),
      itemsTable(ctx, banded: true, zebra: tint(ctx.accent, 0.05)),
      pw.SizedBox(height: 18),
      pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('PAYMENT INFORMATION',
                    style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: ctx.accent,
                        letterSpacing: 1)),
                pw.SizedBox(height: 4),
                pw.Text(inv.paymentInfo.isEmpty ? 'Not specified' : inv.paymentInfo,
                    style: pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700, height: 1.4)),
                pw.SizedBox(height: 12),
                notesBlock(inv),
              ],
            ),
          ),
          pw.Expanded(flex: 2, child: totalsBlock(ctx, panel: true)),
        ],
      ),
      pw.SizedBox(height: 20),
      pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border(
            top: pw.BorderSide(color: ctx.accent, width: 1.2),
            bottom: pw.BorderSide(color: ctx.accent, width: 1.2),
          ),
        ),
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: pw.Row(
          children: [
            pw.Expanded(child: pw.Text(inv.number, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700))),
            pw.Expanded(
                child: pw.Text(ctx.money(ctx.totals.total),
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.black,
                        ))),
            pw.Expanded(
                child: pw.Text(ctx.fmt(inv.dueOn),
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700))),
          ],
        ),
      ),
    ],
  );
}
