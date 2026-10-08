"""Fixes the last interface mismatches in store.dart, dashboard and viewer."""
from pathlib import Path
import re

# ---------------------------------------------------------------- store.dart
p = Path('lib/core/store.dart')
s = p.read_text(encoding='utf-8')

# file_picker 13 exposes saveFile() directly on the platform class
s = s.replace("""    final picked = await FilePicker.platform.saveFile(""",
              """    final picked = await FilePicker.platform.saveFile(""")

# Id vs String on delete calls
s = s.replace("""    final doc = isar.pdfDocuments
        .filter()        .docIdEqualTo(docId)
        .findFirstSync();""",
"""    final doc = isar.pdfDocuments.filter().docIdEqualTo(docId).findFirstSync();""")

s = s.replace("""  Future<void> deleteDocument(String docId) async {""",
              """  Future<void> deleteDocument(String docId) async {
    final match = isar.pdfDocuments.filter().docIdEqualTo(docId).findFirstSync();
    if (match == null) return;
    final f = File(match.storagePath);
    if (await f.exists()) await f.delete();
    await isar.writeTxn(() async {
      await isar.pdfDocuments.delete(match.id!);
    });
    _docStream.add(allDocuments());
    notifyListeners();
    return;
  }

  Future<void> _deleteDocumentLegacy(Id docId) async {""", 1)

p.write_text(s, encoding='utf-8')
print('store patched')

# ------------------------------------------------------------- dashboard
p = Path('lib/views/dashboard_screen.dart')
s = p.read_text(encoding='utf-8')
# The view expects DashboardStats / MonthPoint but the store returns
# Stats / MonthlyPoint. Bridge by mapping at the call site.
s = s.replace("final stats = store.getStats();",
              "final stats = _asDashboardStats(store);", 1)
s = s.replace("final series = store.getMonthlySeries();",
              "final series = _asMonthPoints(store);", 1)
s = s.replace("final stats = store.getStats;",
              "final stats = _asDashboardStats(store);", 1)
p.write_text(s, encoding='utf-8')
print('dashboard patched')

# --------------------------------------------------------------- viewer
p = Path('lib/views/document_viewer_screen.dart')
s = p.read_text(encoding='utf-8')
s = s.replace("""import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';""",
              """import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../models/models.dart';
import '../ui/kit.dart';""", 1)
p.write_text(s, encoding='utf-8')
print('viewer patched')
