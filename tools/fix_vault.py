"""Replaces the PDF-vault block in lib/core/store.dart with a clean version."""
from pathlib import Path

p = Path('lib/core/store.dart')
s = p.read_text(encoding='utf-8')

# Remove everything from the vault section up to (but not including) the
# settings/export section, then re-insert a clean implementation.
start = s.find("  // ------------------------- PDF vault")
if start == -1:
    start = s.find("  /// Delete the vault entry only.")
end = s.find("  /// Delete the vault entry only.")
if end == -1 or end < start:
    end = s.find("  Future<void> importData(")
if end == -1 or end < start:
    end = s.find("  Future<void> importData(")
    # last resort: cut to the export section
    idx = s.find("  Future<void> importData(")
    end = idx if idx != -1 else len(s)
assert start != -1, 'vault start not found'
assert end != -1 and end > start, 'vault end not found'

NEW = r'''
  // ------------------------- PDF vault -------------------------

  /// All indexed PDF documents, newest first.
  List<PdfDocument> allDocuments() =>
      isar.pdfDocuments.where().sortByGeneratedAtDesc().findAllSync();

  /// Reactive list over the vault, for the Documents screen.
  Stream<List<PdfDocument>> watchDocuments() {
    return _docStream.stream.map((e) => List.unmodifiable(e));
  }

  /// Look up a single document by its vault key.
  PdfDocument? documentById(String id) =>
      isar.pdfDocuments.filter().docIdEqualTo(id).findFirstSync();

  /// Share through the Android share sheet.
  Future<void> shareDocument(PdfDocument doc) async {
    await Share.shareXFiles([XFile(doc.storagePath)], text: doc.fileName);
  }

  /// Save a copy through the Android system file picker.
  Future<void> saveDocumentToDevice(BuildContext context, PdfDocument doc) async {
    final picked = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF',
      fileName: doc.fileName,
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
    );
    if (picked == null) return;
    await File(doc.storagePath).copy(picked);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${p.basename(picked)}')),
      );
    }
  }

  /// Hand the document to the Android print framework.
  Future<void> printDocument(PdfDocument doc) async {
    await Printing.layoutPdf(onLayout: (_) => File(doc.storagePath).readAsBytes());
  }

  /// Record a freshly generated PDF in the vault.
  Future<PdfDocument> indexGeneratedPdf({
    required String storagePath,
    required String invoiceId,
    required String template,
  }) async {
    final file = File(storagePath);
    final base = p.basename(storagePath);
    final doc = PdfDocument(
      docId: storagePath,
      invoiceId: invoiceId,
      number: '',
      type: 'invoice',
      template: template,
      clientName: '',
      fileName: base,
      storagePath: storagePath,
      bytes: await file.length(),
      accent: '#1A2744',
      generatedAt: DateTime.now(),
    );
    await isar.writeTxn(() async {
      await isar.pdfDocuments.put(doc);
    });
    _docStream.add(allDocuments());
    notifyListeners();
    return doc;
  }

  /// Re-scan the vault directory and reconcile the index with disk.
  Future<void> reindexVault() async {
    final dir = await _vaultDir();
    final entries = <PdfDocument>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.pdf')) continue;
      final stat = await entity.stat();
      final base = p.basename(entity.path);
      entries.add(PdfDocument(
        docId: entity.path,
        invoiceId: '',
        number: '',
        type: 'invoice',
        template: _templateFromName(base),
        clientName: '',
        fileName: base,
        storagePath: entity.path,
        bytes: stat.size,
        accent: '#1A2744',
        generatedAt: stat.modified,
      ));
    }
    await isar.writeTxn(() async {
      await isar.pdfDocuments.clear();
      await isar.pdfDocuments.putAll(entries);
    });
    _docStream.add(allDocuments());
    notifyListeners();
  }

  /// Delete a vault entry and its on-disk copy. The invoice is untouched.
  Future<void> deleteDocument(String docId) async {
    final doc = documentById(docId);
    if (doc == null) return;
    final f = File(doc.storagePath);
    if (await f.exists()) await f.delete();
    await isar.writeTxn(() async {
      await isar.pdfDocuments.delete(doc.id!);
    });
    _docStream.add(allDocuments());
    notifyListeners();
  }

  /// Generate a PDF for [invoice], store it in the vault, and index it.
  Future<PdfDocument> generatePdfFor(Invoice invoice) async {
    final bytes = await buildInvoicePdf(invoice);
    final dir = await _vaultDir();
    final name =
        '${invoice.template}_${invoice.number}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}${p.separator}$name');
    await file.writeAsBytes(bytes);
    return indexGeneratedPdf(
      storagePath: file.path,
      invoiceId: invoice.id,
      template: invoice.template,
    );
  }

  Future<Directory> _vaultDir() async {
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}${p.separator}pdfs');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  String _templateFromName(String name) {
    final parts = name.replaceAll('.pdf', '').split('_');
    return parts.length > 1 ? parts[0] : '';
  }

'''

s = s[:start] + NEW + s[end:]
p.write_text(s, encoding='utf-8')
print('vault block replaced cleanly')
