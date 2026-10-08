library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../core/format.dart' as fmt;
import '../core/store.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../ui/kit.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({super.key});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  Invoice? _inv;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoice();
  }

  void _loadInvoice() {
    final args = ModalRoute.of(context)?.settings.arguments;
    Invoice? inv;
    if (args is Invoice) {
      inv = args;
    } else {
      inv = Store.instance.latestInvoice();
    }
    setState(() {
      _inv = inv;
      _loading = false;
    });
  }

  void _edit() {
    if (_inv == null) return;
    Navigator.of(context).pushNamed(
      '/editor',
      arguments: _inv!.invoiceId.isEmpty ? 'new' : _inv!.invoiceId,
    );
  }

  void _printPdf() {
    if (_inv == null) return;
    // PDF generation would go here
    showAppToast(context, 'PDF generation coming soon');
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
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (inv == null)
              const Expanded(
                child: Center(
                  child: EmptyState(
                    title: 'No document to preview',
                    message: 'Create or select an invoice to preview it.',
                  ),
                ),
              )
            else
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 595),
                    child: _buildViewer(c, inv),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewer(AppColors c, Invoice inv) {
    // Placeholder for PDF preview - would use pdfx in full implementation
    return Container(
      constraints: const BoxConstraints(maxWidth: 595, maxHeight: 842),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 4))],
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'PDF preview for ${inv.number}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Template: ${templateName(inv.template)}',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Total: ${fmt.formatMoney(inv.totals.total, inv.currency)}',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
