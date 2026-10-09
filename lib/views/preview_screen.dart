library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

import '../core/constants.dart';
import '../core/format.dart' as fmt;
import '../core/store.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../pdf/invoice_pdf.dart';
import '../ui/kit.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  Invoice? _inv;
  bool _loading = true;
  bool _rendering = false;
  Uint8List? _bytes;
  pdfx.PdfController? _pdfController;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
  }

  void _loadInvoice() {
    final args = ModalRoute.of(context)?.settings.arguments;
    Invoice? inv;
    if (args is Invoice) {
      inv = args;
    } else {
      inv = Store.instance.invoices.isEmpty ? null : Store.instance.invoices.first;
    }
    setState(() {
      _inv = inv;
      _loading = false;
    });
    if (inv != null) {
      _renderPdf(inv);
    }
  }

  Future<void> _renderPdf(Invoice inv) async {
    setState(() { _rendering = true; });
    try {
      final bytes = await buildInvoicePdf(inv);
      if (!mounted) return;
      _pdfController?.dispose();
      _pdfController = pdfx.PdfController(
        document: pdfx.PdfDocument.openData(Uint8List.fromList(bytes)),
      );
      setState(() {
        _bytes = Uint8List.fromList(bytes);
        _rendering = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _rendering = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not render PDF: $e')),
        );
      }
    }
  }

  void _edit() {
    if (_inv == null) return;
    context.push('/editor/${_inv!.invoiceId.isEmpty ? 'new' : _inv!.invoiceId}');
  }

  Future<void> _printPdf() async {
    if (_inv == null) return;
    try {
      final doc = await Store.instance.generatePdfFor(_inv!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to vault: ${doc.fileName}')),
      );
      context.go('/documents');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate PDF: $e')),
      );
    }
  }

  Future<void> _switchTemplate(String templateId) async {
    if (_inv == null || _inv!.template == templateId) return;
    final store = Store.instance;
    _inv!.template = templateId;
    final saved = _inv!.invoiceId.isNotEmpty && store.invoiceById(_inv!.invoiceId) != null;
    if (saved) await store.upsertInvoice(_inv!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Template: ${templateName(templateId)}')),
    );
    await _renderPdf(_inv!);
  }

  void _showTemplateSheet() {
    if (_inv == null) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: Text('Select Template', style: Theme.of(ctx).textTheme.titleLarge),
              ),
              for (final t in kTemplates)
                ListTile(
                  leading: Radio<String>(
                    value: t.id,
                    groupValue: _inv!.template,
                    onChanged: (v) { if (v != null) { Navigator.pop(ctx); _switchTemplate(v); } },
                  ),
                  title: Text(t.name),
                  subtitle: Text(t.blurb),
                  trailing: _inv!.template == t.id
                      ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                      : null,
                  onTap: () => _switchTemplate(t.id),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    final inv = _inv;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(AppIcons.back),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Preview',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        if (inv != null)
                          Text(
                            '${inv.number} · ${templateName(inv.template)} · A4',
                            style: TextStyle(fontSize: 12, color: c.text3),
                          ),
                      ],
                    ),
                  ),
                  if (inv != null) ...[
                    IconButton(
                      icon: const Icon(AppIcons.edit, size: 20),
                      onPressed: _edit,
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(AppIcons.print, size: 20),
                      onPressed: _printPdf,
                    ),
                  ],
                ],
              ),
            ),
            if (inv != null)
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 12),
                child: Row(
                  children: [
                    Text('TEMPLATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: c.text3, letterSpacing: 0.8)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showTemplateSheet,
                        icon: const Icon(Icons.unfold_more, size: 15),
                        label: Text(templateName(inv.template)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Total ${fmt.formatMoney(inv.totals.total, inv.currency)}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (inv == null)
              Expanded(
                child: Center(
                  child: EmptyState(
                    title: 'No document to preview',
                    message: 'Create or select an invoice to preview it.',
                    actionLabel: 'New invoice',
                    onAction: () => context.go('/editor/new'),
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 595),
                    child: _rendering
                        ? const Center(child: CircularProgressIndicator())
                        : _bytes != null && _pdfController != null
                            ? AspectRatio(
                                aspectRatio: 595.28 / 841.89,
                                child: Container(
                                  color: Colors.white,
                                  child: pdfx.PdfView(
                                    controller: _pdfController!,
                                  ),
                                ),
                              )
                            : Container(
                                constraints: const BoxConstraints(maxWidth: 595),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: c.border),
                                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 4))],
                                ),
                                child: const Center(
                                  child: Text('Render failed', style: TextStyle(color: Colors.grey)),
                                ),
                              ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
