library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../core/format.dart' as fmt;
import '../core/store.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../ui/kit.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  late final Store _store;

  @override
  void initState() {
    super.initState();
    _store = Store.instance;
    _store.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _deleteDocument(PdfDocument doc) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete ${doc.fileName}?',
      message: 'This removes the PDF from your vault. The invoice stays.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!ok || !mounted) return;
    await _store.deleteDocument(doc.docId);
    if (mounted) showAppToast(context, 'Removed from vault');
  }

  Future<void> _viewDocument(PdfDocument doc) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ViewerScreen(doc: doc),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final docs = _store.documents;
    final c = colors(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  PageHeader(
                    title: 'PDF Vault',
                    subtitle: docs.isEmpty ? 'No documents yet' : '${docs.length} documents',
                  ),
                  if (docs.isEmpty)
                    Container(
                      decoration: _cardDecoration(c),
                      child: EmptyState(
                        title: 'No PDFs yet',
                        message: 'Open Preview and tap Print / PDF — every PDF you generate is kept here.',
                        actionLabel: 'Open preview',
                        onAction: () => Navigator.of(context).pushNamed('/preview'),
                        icon: AppIcons.pdf,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: _cardDecoration(c),
                      child: Column(
                        children: [
                          for (final doc in docs) ...[
                            hairline(context),
                            _DocumentRow(
                              doc: doc,
                              onView: () => _viewDocument(doc),
                              onDelete: () => _deleteDocument(doc),
                            ),
                          ],
                        ],
                      ),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(AppColors c) => BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.6),
      );
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.doc,
    required this.onView,
    required this.onDelete,
  });

  final PdfDocument doc;
  final VoidCallback onView;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return ListRow(
      onTap: onView,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: const Icon(AppIcons.pdf, size: 22, color: Colors.orange),
      ),
      child: Meta(
        title: doc.fileName,
        subtitle: '${doc.docLabel} ${doc.number} · ${fmt.formatDate(doc.generatedAt)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(fmt.fileSize(doc.bytes), style: TextStyle(fontSize: 11, color: c.text3)),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(AppIcons.trash, size: 17),
            onPressed: onDelete,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------- viewer */

class _ViewerScreen extends StatefulWidget {
  const _ViewerScreen({required this.doc});

  final PdfDocument doc;

  @override
  State<_ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<_ViewerScreen> {
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    final path = widget.doc.storagePath;
    if (path.isEmpty || !File(path).existsSync()) {
      _missing = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    final doc = widget.doc;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(AppIcons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doc.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${doc.docLabel} ${doc.number}',
                          style: TextStyle(fontSize: 12, color: c.text3),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(AppIcons.share, size: 20),
                    onPressed: () => showAppToast(context, 'Share coming soon'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(AppIcons.download, size: 20),
                    onPressed: () => showAppToast(context, 'Export coming soon'),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(AppIcons.trash, size: 20, color: Colors.red),
                    onPressed: () async {
                      final ok = await showConfirmDialog(
                        context,
                        title: 'Delete from vault?',
                        message: '${doc.fileName} will be removed.',
                        confirmLabel: 'Delete',
                        danger: true,
                      );
                      if (ok) {
                        await Store.instance.deleteDocument(doc.docId);
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: _missing
                  ? Center(
                      child: EmptyState(
                        title: 'File missing',
                        message: 'This PDF no longer exists on this device.',
                        actionLabel: 'Remove',
                        onAction: () async {
                          await Store.instance.deleteDocument(doc.docId);
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: Icons.error_outline,
                      ),
                    )
                  : Container(
                      color: c.surface2,
                      child: const Center(
                        child: Text(
                          'PDF viewer requires pdfx package\nImplementation pending',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
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
