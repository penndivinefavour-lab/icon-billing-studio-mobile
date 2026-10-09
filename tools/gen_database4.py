"""Regenerates lib/core/database.dart against the isar4 API."""
from pathlib import Path

CONTENT = r'''library;

/// ICON Billing Studio - Isar database.
///
/// Offline-first local persistence. Isar was chosen over Hive and SQLite:
/// the data is relational (invoices reference clients and generated PDFs),
/// it needs query support for history search/filter/sort, and it survives
/// restarts with no network access.

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'settings.dart';

/// Collections held by the store. Isar 4 takes schemas as a named argument.
final _schemas = [
  ClientSchema,
  ServiceSchema,
  InvoiceSchema,
  PdfDocumentSchema,
  BusinessSchema,
  AppSettingsSchema,
];

class Database {
  Database._();

  static Isar? _instance;

  /// Open (or create) the store. Safe to call repeatedly.
  static Future<Isar> instance() async {
    if (_instance != null) return _instance!;
    final dir = await getApplicationDocumentsDirectory();
    _instance = await Isar.open(
      schemas: _schemas,
      directory: dir.path,
      inspector: false,
    );
    return _instance!;
  }

  /// Test hook: use an isolated sandbox under a temp dir.
  @visibleForTesting
  static Future<Isar> testInstance(String sandboxDir) async {
    _instance = await Isar.open(
      schemas: _schemas,
      directory: sandboxDir,
      inspector: false,
    );
    return _instance!;
  }

  /// Wipe every collection. Used by the "reset demo data" action.
  static Future<void> clearAll() async {
    final isar = await instance();
    await isar.writeAsync((isar) async {
      isar.clients.clear();
      await isar.services.clear();
      await isar.invoices.clear();
      await isar.pdfDocuments.clear();
      await isar.business.clear();
    });
  }
}
'''

OUT = Path('lib/core/database.dart')
OUT.write_text(CONTENT, encoding='utf-8')
n = len(OUT.read_bytes())
assert n > 1500, n
print(f'OK {OUT} ({n} bytes)')
