from pathlib import Path

P = []
P.append(r"""library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../core/format.dart';
import '../core/store.dart';
""")

P.append(r"""
/// In-app PDF viewer with Share / Save-to-device / Print actions.
class DocumentViewerScreen extends StatefulWidget {
  final String documentId;

  const DocumentViewerScreen({super.key, required this.documentId});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  Store? _store;
  PdfDocument? _doc;
  bool _missing = false;
  final _controller = PdfViewerController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store ??= Store.of(context);
    _load();
  }

  Future<void> _load() async {
    final doc = await _store!.documentById(widget.documentId);
    if (doc == null || !await File(doc.path).exists()) {
      if (mounted) setState(() => _missing = true);
      return;
    }
    if (mounted) setState(() => _doc = doc);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_missing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Document')),
        body: EmptyState(
          icon: Icons.broken_image_outlined,
          title: 'Document unavailable',
          body: 'This file was removed from the device.',
          action: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Back to vault'),
          ),
        ),
      );
    }

    if (_doc == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final file = File(_doc!.path);

    return Scaffold(
      appBar: AppBar(
        title: Text(_doc!.fileName, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: () => _store!.shareDocument(_doc!),
          ),
          IconButton(
            tooltip: 'Save to device',
            icon: const Icon(Icons.save_alt_rounded),
            onPressed: () => _store!.saveDocumentToDevice(context, _doc!),
          ),
          IconButton(
            tooltip: 'Print',
            icon: const Icon(Icons.print_rounded),
            onPressed: () => _store!.printDocument(_doc!),
          ),
        ],
      ),
      body: Stack(
        children: [
          SfPdfViewer.file(
            file,
            controller: _controller,
            backgroundColor: scheme.surface,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 18,
            child: SafeArea(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        '${_doc!.template.isEmpty ? "Invoice" : _doc!.template} '
                        'layout - ${formatDate(_doc!.created)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _doc!.pageCount > 0 ? '${_doc!.pageCount} page(s)' : '',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
""")

OUT = Path('lib/views/document_viewer_screen.dart')
OUT.write_text(''.join(P), encoding='utf-8')
n = len(OUT.read_bytes())
assert n > 4000, n
print(f'OK {OUT} ({n} bytes)')
