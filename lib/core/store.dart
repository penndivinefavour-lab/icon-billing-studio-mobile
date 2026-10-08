/// ICON Billing Studio - the store.
///
/// Single source of truth, ported from the web prototype's js/store.js.
/// Every mutation runs inside an Isar write transaction and then notifies
/// listeners, so the widget tree never holds stale state. Derived helpers
/// (stats, monthly series, history filters, counters) live here and views
/// stay declarative.
library;

import 'dart:convert';

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';

import '../models/models.dart';
import 'constants.dart';
import 'database.dart';
import 'seed.dart';
import 'settings.dart';

/// Reason a client cannot be deleted, when applicable.
class DeleteBlock {
  final bool blocked;
  final String message;
  const DeleteBlock({required this.blocked, required this.message});
}

class Store extends ChangeNotifier {
  Store._(this.isar, this.settings) {
    _bootstrap();
  }

  final Isar isar;
  final AppSettings settings;

  static Store? _instance;

  /// Open the database, seed on first launch, and build the store.
  static Future<Store> create() async {
    if (_instance != null) return _instance!;
    final isar = await Database.instance();
    final settings = await AppSettings.load(isar);
    _instance = Store._(isar, settings);
    return _instance!;
  }

  /// Test entry point: sandboxed Isar instance, no seeding side effects on the
  /// real app data.
  @visibleForTesting
  static Future<Store> forTest(Isar isar) async {
    final settings = await AppSettings.load(isar);
    final store = Store._(isar, settings);
    return store;
  }

  static Store get instance {
    final s = _instance;
    if (s == null) {
      throw StateError('Store not ready - await Store.create() first');
    }
    return s;
  }

  @override
  void dispose() {
    for (final watcher in _watchers) {
      watcher.cancel();
    }
    _watchers.clear();
    _subscription.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------- bootstrap

  late final StreamSubscription _subscription;
  final List<StreamSubscription> _watchers = [];

  void _bootstrap() {
    if (isar.clients.where().isEmptySync()) {
      seed();
    }
    // Reactive: any collection write from anywhere triggers a refresh.
    final changes = StreamController<void>.broadcast();
    void watch(Stream<void> stream) {
      _watchers.add(stream.listen((_) => changes.add(null)));
    }

    watch(isar.clients.watchLazy());
    watch(isar.invoices.watchLazy());
    watch(isar.services.watchLazy());
    watch(isar.pdfDocuments.watchLazy());
    _subscription = changes.stream.listen((_) => notifyListeners());
  }

  /// Restore the demo content. Wipes everything first.
  Future<void> seed() async {
    await isar.writeTxn(() async {
      await isar.business.clear();
      await isar.clients.clear();
      await isar.services.clear();
      await isar.invoices.clear();
      await isar.pdfDocuments.clear();

      await isar.business.put(seedBusiness());
      await isar.clients.putAll(seedClients());
      await isar.services.putAll(seedServices());
      await isar.invoices.putAll(seedInvoices());
    });
    settings.numberInvoice = 2044;
    settings.numberQuotation = 2044;
    settings.activeTemplate = 'executive';
    await settings.persist();
    notifyListeners();
  }

  // ---------------------------------------------------- template gallery

  /// A gallery sample waiting to be opened in the editor. Set by the template
  /// gallery screen, consumed once by the editor on boot.
  Invoice? _templateSample;

  void offerTemplateSample(Invoice sample) => _templateSample = sample;

  Invoice? consumeTemplateSample() {
    final s = _templateSample;
    _templateSample = null;
    return s;
  }

  // ---------------------------------------------------------------- business

  Business get business {
    final b = isar.business.where().findFirstSync();
    return b ?? seedBusiness();
  }

  Future<void> updateBusiness(Business next) async {
    await isar.writeTxn(() async {
      await isar.business.put(next);
    });
    notifyListeners();
  }

  // ---------------------------------------------------------------- clients

  List<Client> get clients =>
      isar.clients.where().sortByClientId().findAllSync();

  Client? clientById(String id) {
    if (id.isEmpty) return null;
    return isar.clients
        .filter()        .clientIdEqualTo(id)
        .findFirstSync();
  }

  Future<Client> upsertClient(Client client) async {
    final now = DateTime.now();
    final next = client..updatedAt = now;
    if (next.clientId.isEmpty) {
      next.clientId = 'cl_${now.millisecondsSinceEpoch}';
    }
    await isar.writeTxn(() async {
      await isar.clients.put(next);
    });
    notifyListeners();
    return next;
  }

  /// Refuse while invoices still reference the client, matching the prototype.
  Future<DeleteBlock> deleteClient(String clientId) async {
    final used = isar.invoices
        .filter()
        .clientIdEqualTo(clientId)
        .countSync();
    if (used > 0) {
      return DeleteBlock(
          blocked: true,
          message: 'Client is used by $used document${used == 1 ? '' : 's'} - remove those first');
    }
    await isar.writeTxn(() async {
      await isar.clients
          .filter()
          .clientIdEqualTo(clientId)
          .deleteAll();
    });
    notifyListeners();
    return const DeleteBlock(blocked: false, message: '');
  }

  // ---------------------------------------------------------------- services

  List<Service> get services =>
      isar.services.where().sortByName().findAllSync();

  Service? serviceById(String id) {
    if (id.isEmpty) return null;
    return isar.services.filter().serviceIdEqualTo(id).findFirstSync();
  }

  Future<Service> upsertService(Service service) async {
    if (service.serviceId.isEmpty) {
      service.serviceId = 'sv_${DateTime.now().millisecondsSinceEpoch}';
    }
    await isar.writeTxn(() async {
      await isar.services.put(service);
    });
    notifyListeners();
    return service;
  }

  Future<void> deleteService(String serviceId) async {
    await isar.writeTxn(() async {
      await isar.services
          .filter()
          .serviceIdEqualTo(serviceId)
          .deleteAll();
    });
    notifyListeners();
  }

  // ---------------------------------------------------------------- invoices

  List<Invoice> get invoices =>
      isar.invoices.where().findAllSync();

  Invoice? invoiceById(String id) {
    if (id.isEmpty) return null;
    return isar.invoices.filter().invoiceIdEqualTo(id).findFirstSync();
  }

  /// Next document number for [type], advancing the counter as a side effect.
  String nextNumber(String type) {
    final isQuote = type == 'quotation';
    final n = isQuote
        ? settings.numberQuotation + 1
        : settings.numberInvoice + 1;
    if (isQuote) {
      settings.numberQuotation = n;
    } else {
      settings.numberInvoice = n;
    }
    settings.persist();
    final prefix = isQuote
        ? settings.prefixQuotation
        : settings.prefixInvoice;
    return '$prefix-${n.toString().padLeft(4, '0')}';
  }

  /// A brand-new unsaved invoice draft - mirrors the prototype's
  /// blankInvoice(): number burned immediately, business details prefilled,
  /// one empty line, accent from settings. Not persisted until saved.
  Invoice newInvoiceDraft({String? template, String type = 'invoice'}) {
    final biz = business;
    final a = accent;
    return Invoice(
      invoiceId: '',
      number: nextNumber(type),
      type: type,
      status: 'draft',
      template: template ?? settings.activeTemplate,
      clientId: '',
      fromName: biz.name,
      fromEmail: biz.email,
      itemsJson: jsonEncode([LineItem(id: _newItemId()).toJson()]),
      currency: settings.currency,
      notes: '',
      paymentInfo: [
        biz.bankName,
        biz.bankAccount,
        biz.swift,
      ].where((s) => s.trim().isNotEmpty).join(' — '),
      accent: _hexFromColor(a.a),
      accentName: a.name,
      issueDate: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 14)),
    );
  }

  /// Write an invoice. Returns the saved invoice.
  Future<Invoice> saveInvoice(Invoice invoice) async {
    final now = DateTime.now();
    final existing = invoiceById(invoice.invoiceId);
    if (existing != null) {
      invoice.id = existing.id;
      invoice.updatedAt = now;
    } else {
      if (invoice.invoiceId.isEmpty) {
        invoice.invoiceId = 'inv_${now.millisecondsSinceEpoch}';
      }
      invoice.createdAt = now;
      invoice.updatedAt = now;
    }
    await isar.writeTxn(() async {
      await isar.invoices.put(invoice);
    });
    notifyListeners();
    return invoice;
  }

  Future<Invoice?> updateInvoiceStatus(String id, String status) async {
    final inv = invoiceById(id);
    if (inv == null) return null;
    inv.status = status;
    inv.updatedAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.invoices.put(inv);
    });
    notifyListeners();
    return inv;
  }

  /// Clone a document under a fresh number and id.
  Future<Invoice?> duplicateInvoice(String id) async {
    final inv = invoiceById(id);
    if (inv == null) return null;
    final copy = inv.copy()
      ..invoiceId = 'inv_${DateTime.now().millisecondsSinceEpoch}'
      ..number = nextNumber(inv.type)
      ..status = 'draft'
      ..items = inv.items.map((it) => it.copy()..id = 'li_${DateTime.now().millisecondsSinceEpoch}_${it.id}').toList()
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.invoices.put(copy);
    });
    notifyListeners();
    return copy;
  }

  Future<void> deleteInvoice(String id) async {
    await isar.writeTxn(() async {
      await isar.invoices
          .filter()
          .invoiceIdEqualTo(id)
          .deleteAll();
    });
    notifyListeners();
  }

  /// Most recent document by issue date then number - not storage order.
  /// (Web prototype bug #7: the old code read getInvoices()[0].)
  Invoice? latestInvoice() {
    final all = invoices;
    if (all.isEmpty) return null;
    all.sort((a, b) {
      final c = b.issuedOn.compareTo(a.issuedOn);
      return c != 0 ? c : b.number.compareTo(a.number);
    });
    return all.first;
  }

  // ---------------------------------------------------------------- history

  /// Search by number, client, company, item or notes; filter by status and
  /// type; sort by date, amount or number. Matches filterInvoices() exactly.
  List<Invoice> filterInvoices({
    String q = '',
    String status = 'all',
    String type = 'all',
    String clientId = '',
    String sort = 'date-desc',
  }) {
    final needle = q.trim().toLowerCase();
    var list = invoices.where((inv) {
      if (status != 'all' && inv.status != status) return false;
      if (type != 'all' && inv.type != type) return false;
      if (clientId.isNotEmpty && inv.clientId != clientId) return false;
      if (needle.isEmpty) return true;
      final client = clientById(inv.clientId);
      final haystack = [
        inv.number,
        inv.toName,
        inv.toCompany,
        client?.name ?? '',
        inv.notes,
        ...inv.items.map((i) => i.name),
      ].join(' ').toLowerCase();
      return haystack.contains(needle);
    }).toList();

    int cmpDate(Invoice a, Invoice b, bool desc) {
      final c = desc
          ? b.issuedOn.compareTo(a.issuedOn)
          : a.issuedOn.compareTo(b.issuedOn);
      return c != 0 ? c : b.number.compareTo(a.number);
    }

    switch (sort) {
      case 'date-desc':
        list.sort((a, b) => cmpDate(a, b, true));
        break;
      case 'date-asc':
        list.sort((a, b) => cmpDate(a, b, false));
        break;
      case 'amount-desc':
        list.sort((a, b) => invoiceAggregate(b).compareTo(invoiceAggregate(a)));
        break;
      case 'amount-asc':
        list.sort((a, b) => invoiceAggregate(a).compareTo(invoiceAggregate(b)));
        break;
      case 'number-asc':
        list.sort((a, b) => a.number.compareTo(b.number));
        break;
    }
    return list;
  }

  // ---------------------------------------------------------------- stats

  /// Dashboard statistics. Aggregation mirrors the prototype's getStats().
  DashboardStats getStats() {
    final all = invoices;
    var total = 0.0, paidSum = 0.0, outSum = 0.0, overSum = 0.0;
    var paidCount = 0, outCount = 0, overCount = 0, draftCount = 0, quoteCount = 0;
    for (final inv in all) {
      final amount = invoiceAggregate(inv);
      total += amount;
      switch (inv.status) {
        case 'paid':
          paidSum += amount;
          paidCount++;
          break;
        case 'sent':
        case 'partial':
        case 'overdue':
          outSum += amount;
          outCount++;
          break;
      }
      if (inv.status == 'overdue') {
        overSum += amount;
        overCount++;
      }
      if (inv.status == 'draft') draftCount++;
      if (inv.isQuotation) quoteCount++;
    }
    return DashboardStats(
      totalRevenue: round2(total),
      paid: round2(paidSum),
      outstanding: round2(outSum),
      overdue: round2(overSum),
      invoiceCount: all.length,
      paidCount: paidCount,
      outstandingCount: outCount,
      overdueCount: overCount,
      draftCount: draftCount,
      quotationCount: quoteCount,
      clientCount: clients.length,
      serviceCount: services.length,
      avgInvoice: all.isEmpty ? 0 : total / all.length,
      collectionRate: total == 0 ? 0 : (paidSum / total) * 100,
    );
  }

  /// Six-month revenue series for the dashboard chart.
  List<MonthPoint> getMonthlySeries([int months = 6]) {
    final now = DateTime.now();
    final buckets = <MonthPoint>[];
    for (var i = months - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      buckets.add(MonthPoint(
        key: '${d.year}-${d.month.toString().padLeft(2, '0')}',
        label: _monthLabel(d.month),
        revenue: 0,
        count: 0,
      ));
    }
    final index = {for (var i = 0; i < buckets.length; i++) buckets[i].key: i};
    for (final inv in invoices) {
      final key = isoDateString(inv.issuedOn).substring(0, 7);
      final i = index[key];
      if (i != null) {
        buckets[i] = MonthPoint(
          key: buckets[i].key,
          label: buckets[i].label,
          revenue: round2(buckets[i].revenue + invoiceAggregate(inv)),
          count: buckets[i].count + 1,
        );
      }
    }
    return buckets;
  }

  String _monthLabel(int month) => const [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][month - 1];

  // ---------------------------------------------------------------- PDF vault

  List<PdfDocument> get documents =>
      isar.pdfDocuments.where().sortByGeneratedAtDesc().findAllSync();

  PdfDocument? documentByInvoice(String invoiceId) {
    if (invoiceId.isEmpty) return null;
    return isar.pdfDocuments
        .filter()        .invoiceIdEqualTo(invoiceId)
        .findFirstSync();
  }

  Future<PdfDocument> registerDocument(PdfDocument doc) async {
    if (doc.docId.isEmpty) {
      doc.docId = 'pdf_${DateTime.now().millisecondsSinceEpoch}';
    }
    await isar.writeTxn(() async {
      await isar.pdfDocuments.put(doc);
    });
    notifyListeners();
    return doc;
  }

  /// Delete the vault entry only. The invoice stays unless the user asks for
  /// that separately - the prompt is explicit about the distinction.
  Future<void> deleteDocument(String docId) async {
    final doc = isar.pdfDocuments
        .filter()        .docIdEqualTo(docId)
        .findFirstSync();
    if (doc == null) return;
    // Remove the app-private copy too, but never the invoice.
    final f = File(doc.storagePath);
    if (await f.exists()) {
      await f.delete();
    }
    await isar.writeTxn(() async {
      await isar.pdfDocuments
          .filter()
          .docIdEqualTo(docId)
          .deleteAll();
    });
    notifyListeners();
  }

  // ---------------------------------------------------------------- backup

  /// JSON backup, identical in shape to the web prototype's export.
  Map<String, dynamic> exportData() {
    return {
      'app': 'icon-billing-studio',
      'version': AppMeta.dataVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'data': {
        'business': business.toJson(),
        'clients': clients.map((c) => c.toJson()).toList(),
        'services': services.map((s) => s.toJson()).toList(),
        'invoices': invoices.map((i) => i.toJson()).toList(),
        'counters': {
          'invoice': settings.numberInvoice,
          'quotation': settings.numberQuotation,
        },
        'settings': {
          'theme': settings.theme,
          'accentId': settings.accentId,
          'customAccent': settings.customAccent,
          'activeTemplate': settings.activeTemplate,
          'currency': settings.currency,
          'numberPrefix': {
            'invoice': settings.prefixInvoice,
            'quotation': settings.prefixQuotation,
          },
        },
      },
    };
  }

  /// Import a backup. Rejects anything that is not one of ours.
  Future<void> importData(Map<String, dynamic> parsed) async {
    final data = (parsed['data'] as Map<String, dynamic>?) ?? parsed;
    final list = data['invoices'];
    final clientsList = data['clients'];
    if (list is! List || clientsList is! List) {
      throw const FormatException('File is not a valid Billing Studio backup.');
    }
    await isar.writeTxn(() async {
      await isar.business.clear();
      await isar.clients.clear();
      await isar.services.clear();
      await isar.invoices.clear();
      await isar.pdfDocuments.clear();

      final biz = data['business'] as Map<String, dynamic>?;
      if (biz != null) {
        await isar.business.put(Business.fromJson(biz));
      }
      await isar.clients.putAll(clientsList
          .map((c) => Client.fromJson(c as Map<String, dynamic>))
          .toList());
      final services = data['services'] as List?;
      if (services != null) {
        await isar.services.putAll(services
            .map((s) => Service.fromJson(s as Map<String, dynamic>))
            .toList());
      }
      await isar.invoices.putAll(list
          .map((i) => Invoice.fromJson(i as Map<String, dynamic>))
          .toList());
    });

    final counters = data['counters'] as Map<String, dynamic>?;
    if (counters != null) {
      settings.numberInvoice = (counters['invoice'] ?? 2043).toInt();
      settings.numberQuotation = (counters['quotation'] ?? 2043).toInt();
    }
    final s = data['settings'] as Map<String, dynamic>?;
    if (s != null) {
      settings.theme = (s['theme'] ?? 'dark') as String;
      settings.accentId = (s['accentId'] ?? 'icon') as String;
      settings.activeTemplate = (s['activeTemplate'] ?? 'executive') as String;
      settings.currency = (s['currency'] ?? 'USD') as String;
      final prefixes = s['numberPrefix'] as Map<String, dynamic>?;
      if (prefixes != null) {
        settings.prefixInvoice = (prefixes['invoice'] ?? 'INV') as String;
        settings.prefixQuotation = (prefixes['quotation'] ?? 'QUO') as String;
      }
    }
    await settings.persist();
    notifyListeners();
  }

  // ---------------------------------------------------------------- settings

  /// Resolved accent: a preset, or the user's custom colour.
  AccentDef get accent {
    if (settings.accentId == 'custom' && settings.customAccent != null) {
      return AccentDef(
        id: 'custom',
        name: 'Custom',
        a: settings.customAccent!,
        aSoft: settings.customAccent!,
      );
    }
    return accentById(settings.accentId);
  }

  String get activeTemplateName => templateName(settings.activeTemplate);

  /// Fresh line-item id.
  static String _newItemId() => 'li_${DateTime.now().microsecondsSinceEpoch}';

  /// 0xFF6B21A8 -> '#6B21A8'
  static String _hexFromColor(int value) {
    final hex = value.toRadixString(16).padLeft(8, '0');
    return '#${hex.substring(2)}'.toUpperCase();
  }

  Future<void> setTheme(String theme) async {
    settings.theme = theme;
    await settings.persist();
    notifyListeners();
  }

  Future<void> setAccent(String accentId, [int? custom]) async {
    settings.accentId = accentId;
    settings.customAccent = custom;
    await settings.persist();
    notifyListeners();
  }

  Future<void> setActiveTemplate(String templateId) async {
    settings.activeTemplate = templateId;
    await settings.persist();
    notifyListeners();
  }

  /// Persist settings edited in place (currency, prefixes, counters...).
  Future<void> persistSettings() async {
    await settings.persist();
    notifyListeners();
  }
}

/* ---------------------------------------------------------------- derived */

class DashboardStats {
  final double totalRevenue;
  final double paid;
  final double outstanding;
  final double overdue;
  final int invoiceCount;
  final int paidCount;
  final int outstandingCount;
  final int overdueCount;
  final int draftCount;
  final int quotationCount;
  final int clientCount;
  final int serviceCount;
  final double avgInvoice;
  final double collectionRate;

  const DashboardStats({
    required this.totalRevenue,
    required this.paid,
    required this.outstanding,
    required this.overdue,
    required this.invoiceCount,
    required this.paidCount,
    required this.outstandingCount,
    required this.overdueCount,
    required this.draftCount,
    required this.quotationCount,
    required this.clientCount,
    required this.serviceCount,
    required this.avgInvoice,
    required this.collectionRate,
  });
}

class MonthPoint {
  final String key;
  final String label;
  final double revenue;
  final int count;
  const MonthPoint({
    required this.key,
    required this.label,
    required this.revenue,
    required this.count,
  });
}
