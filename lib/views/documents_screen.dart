library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart';
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
  late final Store _store = Store.instance;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _store.reindexVault();
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _open(PdfDocument doc) async {
    HapticFeedback.selectionClick();
    final file = File(doc.path);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File no longer exists on disk.')),
        );
      }
      await _store.deleteDocument(doc.docId);
      await _refresh();
      return;
    }
    if (!mounted) return;
    context.push('/documents/view/${doc.docId}');
  }

  Future<void> _confirmDelete(PdfDocument doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('${doc.fileName} will be removed from this device. '
            'The invoice itself is not affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _store.deleteDocument(doc.docId);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.medium(
            title: const Text('Documents'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _refresh,
                tooltip: 'Re-scan vault',
              ),
            ],
          ),
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text('Vault scan failed: $_error',
                    style: TextStyle(color: scheme.error)),
              ),
            ),
          StreamBuilder<List<PdfDocument>>(
            stream: _store.watchDocuments(),
            initialData: _store.allDocuments(),
            builder: (context, snap) {
              final docs = snap.data ?? const [];
              if (_loading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (docs.isEmpty) {
                return SliverFillRemaining(
                  child: EmptyState(
                    icon: Icons.folder_open_rounded,
                    title: 'No documents yet',
                    message: 'Generate a PDF from any invoice and it will be '
                        'saved here automatically.',
                    actionLabel: 'Browse invoices',
                    onAction: () => context.go('/invoices'),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                sliver: SliverList.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return _DocumentCard(
                      doc: doc,
                      onTap: () => _open(doc),
                      onDelete: () => _confirmDelete(doc),
                      onShare: () => _store.shareDocument(doc),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }


}

class _DocumentCard extends StatelessWidget {
  final PdfDocument doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  const _DocumentCard({
    required this.doc,
    required this.onTap,
    required this.onDelete,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    final size = doc.sizeBytes;
    final sizeLabel = size < 1024
        ? '$size B'
        : size < 1024 * 1024
            ? '${(size / 1024).toStringAsFixed(1)} KB'
            : '${(size / 1024 / 1024).toStringAsFixed(1)} MB';

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.8),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 52,
                  decoration: BoxDecoration(
                    color: c.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.picture_as_pdf_rounded,
                      color: c.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(doc.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          )),
                      const SizedBox(height: 3),
                      Text(
                        '${doc.template.isEmpty ? "Invoice" : doc.template} '
                        'template · $sizeLabel · ${formatDate(doc.created)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: c.text3,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.ios_share_rounded),
                  tooltip: 'Share',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onShare();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onDelete();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
