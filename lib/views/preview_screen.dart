library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../core/constants.dart';
import '../core/format.dart' as fmt;
import '../core/store.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../pdf/invoice_pdf.dart';
import '../ui/kit.dart';

class PreviewScreen extends StatefulWidget {
  final String? invoiceId;
  final Invoice? invoice;

  const PreviewScreen({super.key, this.invoiceId, this.invoice});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  Invoice? _inv;
  bool _loading = true;
  bool _rendering = false;
  Uint8List? _bytes;
  final _pdfViewerController = PdfViewerController();

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  void _loadInvoice() {
    Invoice? inv = widget.invoice;
    if (inv == null && widget.invoiceId != null && widget.invoiceId!.isNotEmpty) {
      inv = Store.instance.invoiceById(widget.invoiceId!);
    }
    if (inv == null && Store.instance.invoices.isNotEmpty) {
      inv = Store.instance.invoices.first;
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
    setState(() {
      _rendering = true;
    });
    try {
      final bytes = await buildInvoicePdf(inv);
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(bytes);
        _rendering = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rendering = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not render PDF: $e')),
      );
    }
  }

  void _edit() {
    if (_inv == null) return;
    context.push('/editor/${_inv!.invoiceId.isEmpty ? 'new' : _inv!.invoiceId}');
  }

  Future<void> _sharePdf() async {
    if (_inv == null) return;
    try {
      HapticFeedback.lightImpact();
      final doc = await Store.instance.generatePdfFor(_inv!);
      await Store.instance.shareDocument(doc);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Share failed: $e')),
      );
    }
  }

  Future<void> _saveToVault() async {
    if (_inv == null) return;
    try {
      HapticFeedback.lightImpact();
      final doc = await Store.instance.generatePdfFor(_inv!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to Vault: ${doc.fileName}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }

  Future<void> _printPdf() async {
    if (_bytes == null) return;
    try {
      HapticFeedback.lightImpact();
      await Printing.layoutPdf(onLayout: (_) => _bytes!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Print failed: $e')),
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
              RadioGroup<String>(
                groupValue: _inv!.template,
                onChanged: (v) {
                  if (v != null) {
                    Navigator.pop(ctx);
                    _switchTemplate(v);
                  }
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final t in kTemplates)
                      ListTile(
                        leading: Radio<String>(
                          value: t.id,
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
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/invoices');
                      }
                    },
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
                      icon: const Icon(AppIcons.share, size: 20),
                      tooltip: 'Share',
                      onPressed: _sharePdf,
                    ),
                    IconButton(
                      icon: const Icon(AppIcons.save, size: 20),
                      tooltip: 'Save to Vault',
                      onPressed: _saveToVault,
                    ),
                    IconButton(
                      icon: const Icon(AppIcons.print, size: 20),
                      tooltip: 'Print',
                      onPressed: _printPdf,
                    ),
                    IconButton(
                      icon: const Icon(AppIcons.edit, size: 20),
                      tooltip: 'Edit',
                      onPressed: _edit,
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
                    Text(
                      'TEMPLATE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: c.text3,
                        letterSpacing: 0.8,
                      ),
                    ),
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
                child: _rendering
                    ? const Center(child: CircularProgressIndicator())
                    : _bytes != null
                        ? SfPdfViewer.memory(
                            _bytes!,
                            controller: _pdfViewerController,
                          )
                        : const Center(
                            child: Text(
                              'Could not render preview',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
              ),
          ],
        ),
      ),
    );
  }
}
