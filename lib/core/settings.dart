/// ICON Billing Studio - persisted settings.
///
/// Theme, accent, active template, currency and number prefixes survive
/// restarts. Kept as a single Isar row keyed by [id].
library;

import 'package:isar/isar.dart';

part 'settings.g.dart';

@collection
@Name('AppSettings')
class AppSettings {
  Id id = 0; // single row

  String theme; // 'dark' | 'light'
  String accentId; // preset id or 'custom'
  int? customAccent; // 0xFF...... when accentId == 'custom'
  String activeTemplate;
  String currency;
  String prefixInvoice;
  String prefixQuotation;
  int numberInvoice;
  int numberQuotation;
  bool taxInclusive;
  bool showLogo;

  AppSettings({
    this.theme = 'dark',
    this.accentId = 'icon',
    this.customAccent,
    this.activeTemplate = 'executive',
    this.currency = 'USD',
    this.prefixInvoice = 'INV',
    this.prefixQuotation = 'QUO',
    this.numberInvoice = 2043,
    this.numberQuotation = 2043,
    this.taxInclusive = false,
    this.showLogo = true,
  });

  /// Load the single row, creating the default when absent.
  static Future<AppSettings> load(Isar isar) async {
    final existing = isar.appSettings.where().findFirstSync();
    if (existing != null) return existing;
    final fresh = AppSettings();
    await isar.writeTxn(() async {
      await isar.appSettings.put(fresh);
    });
    return fresh;
  }

  Future<void> persist() async {
    final isar = Isar.getInstance();
    if (isar == null) return;
    await isar.writeTxn(() async {
      await isar.appSettings.put(this);
    });
  }
}
