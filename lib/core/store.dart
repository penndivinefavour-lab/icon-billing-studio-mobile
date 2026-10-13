/// ICON Billing Studio - the store.
///
/// Single source of truth, ported from the web prototype's js/store.js.
/// Every mutation runs inside an Isar write transaction and then notifies
/// listeners, so the widget tree never holds stale state. Derived helpers
/// (stats, monthly series, history filters, counters) live here and views
/// stay declarative.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../pdf/invoice_pdf.dart';

import '../models/models.dart';
import 'constants.dart';
import 'database.dart';
import 'seed.dart';
import 'settings.dart';
import 'theme.dart';

/// Reason a client cannot be deleted, when applicable.
class DeleteBlock {
  final bool blocked;
  final String message;
  const DeleteBlock({required this.blocked, required this.message});
}

class Store extends ChangeNotifier {
  Store._(this.isar, this.settings);

  final Isar isar;
  final AppSettings settings;

  final StreamController<List<PdfDocument>> _docStream =
      StreamController<List<PdfDocument>>.broadcast();

  /// All vault documents, newest first.

  static Store? _instance;
  static Future<Store>? _initFuture;

  /// Open the database, seed on first launch, and build the store.
  Future<void> _ensureSeeded() async {
    if (isar.clients.countSync() > 0) return;
    await seedAll(isar);
    notifyListeners();
  }

  static Future<Store> create() async {
    if (_instance != null) return _instance!;
    if (_initFuture != null) return _initFuture!;
    _initFuture = _doCreate();
    try {
      final created = await _initFuture!;
      return created;
    } finally {
      _initFuture = null;
    }
  }

  static Future<Store> _doCreate() async {
    if (_instance != null) return _instance!;
    final isar = await Database.instance();
    final settings = await AppSettings.load(isar);
    final candidate = Store._(isar, settings);
    await candidate._ensureSeeded();
    _instance = candidate;
    return _instance!;
  }

  /// Look up the store created in main.dart.
  static Store of(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<_StoreScope>()
        : context.findAncestorWidgetOfExactType<_StoreScope>();
    assert(scope != null, 'No Store ancestor. Wrap the app in StoreProvider.');
    return scope!.store;
  }

  /// Singleton accessor for code outside the widget tree.
  static Store get instance {
    final s = _instance;
    assert(s != null, 'Store has not been created yet.');
    return s!;
  }


  // ---------------------- Editor drafts ----------------------

  /// A fresh, unsaved invoice the editor starts from.
  Invoice newInvoiceDraft({bool quotation = false}) {
    final kind = quotation ? 'quotation' : 'invoice';
    final prefix = quotation ? 'QUO' : 'INV';
    final year = DateTime.now().year;
    final seq = (isar.invoices
                .filter()
                .numberContains('$prefix-$year')
                .countSync()) +
        1;
    final client = clients.isNotEmpty ? clients.first : null;
    return Invoice.dated(
      invoiceId: 'draft_${DateTime.now().millisecondsSinceEpoch}',
      number: '$prefix-$year-${seq.toString().padLeft(4, '0')}',
      type: kind,
      status: 'draft',
      clientId: client?.clientId ?? '',
      fromName: business?.name ?? '',
      fromEmail: business?.email ?? '',
      fromPhone: business?.phone ?? '',
      toName: client?.name ?? '',
      toEmail: client?.email ?? '',
      toCompany: client?.company ?? '',
      toAddress: client?.addressLineOne ?? '',
      template: settings.activeTemplate,
      itemsJson: '[]',
    );
  }

  /// Persist a draft as a real invoice.
  Future<Invoice> saveInvoice(Invoice draft) async {
    draft.syncItemsJson();
    final isQuote = draft.type == 'quotation';
    final kind = isQuote ? 'quotation' : 'invoice';
    final prefix = isQuote ? 'QUO' : 'INV';
    final year = DateTime.now().year;
    final seq = (isar.invoices
                .filter()
                .numberContains('$prefix-$year')
                .countSync()) +
        1;
    final number = '$prefix-$year-${seq.toString().padLeft(4, '0')}';

    final saved = Invoice(
      invoiceId: draft.invoiceId.startsWith('draft_')
          ? 'inv_${DateTime.now().millisecondsSinceEpoch}'
          : draft.invoiceId,
      number: draft.invoiceId.startsWith('draft_') ? number : draft.number,
      type: kind,
      status: draft.status.isEmpty ? 'sent' : draft.status,
      clientId: draft.clientId,
      template: draft.template,
      fromName: draft.fromName,
      fromEmail: draft.fromEmail,
      fromPhone: draft.fromPhone,
      toName: draft.toName,
      toEmail: draft.toEmail,
      toCompany: draft.toCompany,
      toAddress: draft.toAddress,
      poNumber: draft.poNumber,
      itemsJson: draft.itemsJson,
      globalDiscount: draft.globalDiscount,
      shipping: draft.shipping,
      currency: draft.currency,
      notes: draft.notes,
      paymentInfo: draft.paymentInfo,
      accent: draft.accent,
      accentName: draft.accentName,
      issueDate: draft.issueDate,
      dueDate: draft.dueDate,
      createdAt: draft.createdAt,
      updatedAt: DateTime.now(),
    );

    await isar.writeTxn(() async {
      await isar.invoices.put(saved);
    });
    notifyListeners();
    return saved;
  }

  /// Take a gallery sample, open it in the editor, and drop it from the
  /// gallery so the template can only be used once per invoice.
  Invoice? consumeTemplateSample(String templateId) {
    final sample = isar.invoices
        .filter()
        .templateEqualTo(templateId)
        .statusEqualTo('template')
        .findFirstSync();
    if (sample == null) return null;
    final draft = sample.copy();
    draft
      ..invoiceId = 'draft_${DateTime.now().millisecondsSinceEpoch}'
      ..status = 'draft'
      ..number = ''
      ..type = 'invoice';
    return draft;
  }


  /// Clone an invoice as a new draft, bumping nothing but the ids.
  Invoice duplicateInvoice(Invoice source) {
    final copy = source.copy();
    copy
      ..invoiceId = 'draft_${DateTime.now().millisecondsSinceEpoch}'
      ..number = ''
      ..status = 'draft';
    return copy;
  }

  /// Transition a document between statuses.
  Future<void> updateInvoiceStatus(String invoiceId, String status) async {
    final invoice = invoiceById(invoiceId);
    if (invoice == null) return;
    invoice.status = status;
    invoice.updatedAt = DateTime.now();
    await isar.writeTxn(() async {
      await isar.invoices.put(invoice);
    });
    notifyListeners();
  }


  /// Persist the business profile.
  Future<void> upsertBusiness(Business business) async {
    await isar.writeTxn(() async {
      await isar.business.put(business);
    });
    notifyListeners();
  }

  /// The business profile, never null (a blank one is used until set up).
  Business get businessOrDefault =>
      isar.business.where().findFirstSync() ?? Business();

  /// Next document number for [kind] ('invoice' | 'quotation').
  String nextNumber(String kind) {
    final isQuote = kind == 'quotation';
    final prefix = isQuote ? 'QUO' : 'INV';
    final year = DateTime.now().year;
    final seq = isar.invoices
            .filter()
            .numberContains('$prefix-$year')
            .countSync() +
        1;
    return '$prefix-$year-${seq.toString().padLeft(4, '0')}';
  }

  /// Most recently issued document, for the Preview screen.
  Invoice? latestInvoice() {
    final list = isar.invoices
        .filter()
        .not()
        .statusEqualTo('template')
        .sortByIssueDateDesc()
        .findFirstSync();
    return list;
  }

  // ---------------------- Collections ----------------------

  List<Client> get clients => isar.clients.where().findAllSync();
  List<Service> get services => isar.services.where().findAllSync();
  List<Invoice> get invoices =>
      isar.invoices.where().sortByIssueDateDesc().findAllSync();
  List<Invoice> get quotations => invoices.where((i) => i.isQuote).toList();
  Business? get business => isar.business.where().findFirstSync();

  Client? clientById(String id) =>
      isar.clients.filter().clientIdEqualTo(id).findFirstSync();

  Service? serviceById(String id) =>
      isar.services.filter().serviceIdEqualTo(id).findFirstSync();

  Invoice? invoiceById(String id) =>
      isar.invoices.filter().invoiceIdEqualTo(id).findFirstSync();

  // ---------------------- CRUD ----------------------

  Future<void> upsertClient(Client client) async {
    await isar.writeTxn(() async {
      await isar.clients.put(client);
    });
    notifyListeners();
  }

  Future<DeleteBlock> deleteClient(String clientId) async {
    final used = invoices.where((i) => i.clientId == clientId).isNotEmpty;
    if (used) {
      return const DeleteBlock(
        blocked: true,
        message: 'This client appears on existing documents and cannot be '
            'deleted. Remove or reassign those documents first.',
      );
    }
    final client = clientById(clientId);
    if (client == null) return const DeleteBlock(blocked: false, message: '');
    await isar.writeTxn(() async {
      await isar.clients.delete(client.id);
    });
    notifyListeners();
    return const DeleteBlock(blocked: false, message: '');
  }

  Future<void> upsertService(Service service) async {
    await isar.writeTxn(() async {
      await isar.services.put(service);
    });
    notifyListeners();
  }

  Future<DeleteBlock> deleteService(String serviceId) async {
    final used = invoices
        .expand((i) => i.itemsList)
        .where((li) => li.linkedServiceId == serviceId)
        .isNotEmpty;
    if (used) {
      return const DeleteBlock(
        blocked: true,
        message: 'This service is referenced by existing invoices and cannot '
            'be deleted.',
      );
    }
    final service = serviceById(serviceId);
    if (service == null) return const DeleteBlock(blocked: false, message: '');
    await isar.writeTxn(() async {
      await isar.services.delete(service.id);
    });
    notifyListeners();
    return const DeleteBlock(blocked: false, message: '');
  }

  Future<Invoice> upsertInvoice(Invoice invoice) async {
    await isar.writeTxn(() async {
      await isar.invoices.put(invoice);
    });
    notifyListeners();
    return invoice;
  }

  Future<void> deleteInvoice(String invoiceId) async {
    final invoice = invoiceById(invoiceId);
    if (invoice == null) return;
    await isar.writeTxn(() async {
      await isar.invoices.delete(invoice.id);
    });
    notifyListeners();
  }

  // ---------------------- Queries ----------------------

  /// Filter the document history. Mirrors js/store.js filterInvoices.
  List<Invoice> filterInvoices({
    String search = '',
    String status = 'all',
    String clientId = 'all',
    String sort = 'date-desc',
  }) {
    var list = isar.invoices.where().findAllSync();

    if (search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      list = list.where((i) {
        final client = clientById(i.clientId);
        return i.number.toLowerCase().contains(q) ||
            (client?.name.toLowerCase().contains(q) ?? false) ||
            i.itemsList.any((li) => li.description.toLowerCase().contains(q));
      }).toList();
    }

    if (status != 'all') {
      list = list.where((i) => i.status == status).toList();
    }

    if (clientId != 'all') {
      list = list.where((i) => i.clientId == clientId).toList();
    }

    switch (sort) {
      case 'date-asc':
        list.sort((a, b) => a.issuedOn.compareTo(b.issuedOn));
        break;
      case 'amount-desc':
        list.sort((a, b) =>
            computeTotals(b).grandTotal.compareTo(computeTotals(a).grandTotal));
        break;
      case 'amount-asc':
        list.sort((a, b) =>
            computeTotals(a).grandTotal.compareTo(computeTotals(b).grandTotal));
        break;
      case 'number-desc':
        list.sort((a, b) => b.number.compareTo(a.number));
        break;
      default:
        list.sort((a, b) => b.issuedOn.compareTo(a.issuedOn));
    }
    return list;
  }

  // ---------------------- Derived stats ----------------------

  /// Dashboard totals, mirroring getStats() in js/store.js.
  DashboardStats getStats() {
    final all = invoices;
    var outstanding = 0.0;
    var paid = 0.0;
    var overdue = 0.0;
    var draft = 0;

    for (final inv in all) {
      final t = computeTotals(inv);
      if (inv.isQuote || inv.status == 'draft') {
        draft++;
        continue;
      }
      switch (inv.status) {
        case 'paid':
          paid += t.grandTotal;
          break;
        case 'overdue':
          overdue += t.grandTotal;
          outstanding += t.grandTotal;
          break;
        default:
          outstanding += t.grandTotal;
      }
    }

    final live = all.where((i) => !i.isQuote).toList();
    final paidCount = live.where((i) => i.status == 'paid').length;
    final overdueCount = live.where((i) => i.status == 'overdue').length;
    final outstandingCount = live
        .where((i) => i.status != 'paid' && i.status != 'draft')
        .length;
    final revenue = paid + outstanding;
    return DashboardStats(
      totalRevenue: revenue,
      paid: paid,
      outstanding: outstanding,
      overdue: overdue,
      invoiceCount: live.length,
      paidCount: paidCount,
      outstandingCount: outstandingCount,
      overdueCount: overdueCount,
      draftCount: draft,
      quotationCount: all.where((i) => i.isQuote).length,
      clientCount: clients.length,
      serviceCount: services.length,
      avgInvoice: live.isEmpty ? 0 : revenue / live.length,
      collectionRate: revenue == 0 ? 0 : paid / revenue,
    );
  }

  /// Last six calendar months of billed revenue, oldest first.
  List<MonthPoint> getMonthlySeries() {
    final now = DateTime.now();
    final order = <DateTime>[];
    final buckets = <DateTime, double>{};
    for (var i = 5; i >= 0; i--) {
      final key = DateTime(now.year, now.month - i);
      order.add(key);
      buckets[key] = 0.0;
    }

    for (final inv in invoices) {
      if (inv.isQuote || inv.status == 'draft') continue;
      final key = DateTime(inv.issuedOn.year, inv.issuedOn.month);
      if (buckets.containsKey(key)) {
        buckets[key] = buckets[key]! + computeTotals(inv).grandTotal;
      }
    }

    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final counts = <DateTime, int>{};
    for (final inv in invoices) {
      if (inv.isQuote || inv.status == 'draft') continue;
      final key = DateTime(inv.issuedOn.year, inv.issuedOn.month);
      if (counts.containsKey(key)) counts[key] = counts[key]! + 1;
    }
    return order
        .map((k) => MonthPoint(
              key: '${k.year}-${k.month.toString().padLeft(2, '0')}',
              label: names[k.month - 1],
              revenue: buckets[k]!,
              count: counts[k] ?? 0,
            ))
        .toList();
  }


  // ------------------------- PDF vault -------------------------

  List<PdfDocument> allDocuments() =>
      isar.pdfDocuments.where().sortByGeneratedAtDesc().findAllSync();

  Stream<List<PdfDocument>> watchDocuments() =>
      _docStream.stream.map((e) => List.unmodifiable(e));

  PdfDocument? documentById(String id) {
    if (id.isEmpty) return null;
    final decoded = Uri.decodeComponent(id).trim();

    // 1. Exact match on logical docId
    var found = isar.pdfDocuments.filter().docIdEqualTo(id).findFirstSync();
    if (found != null) return found;
    if (decoded != id) {
      found = isar.pdfDocuments.filter().docIdEqualTo(decoded).findFirstSync();
      if (found != null) return found;
    }

    // 2. Match on storagePath (backward-compatibility for legacy records)
    found = isar.pdfDocuments.filter().storagePathEqualTo(id).findFirstSync();
    if (found != null) return found;
    if (decoded != id) {
      found = isar.pdfDocuments.filter().storagePathEqualTo(decoded).findFirstSync();
      if (found != null) return found;
    }

    // 3. Match on fileName
    found = isar.pdfDocuments.filter().fileNameEqualTo(id).findFirstSync();
    if (found != null) return found;
    if (decoded != id) {
      found = isar.pdfDocuments.filter().fileNameEqualTo(decoded).findFirstSync();
      if (found != null) return found;
    }

    // 4. Try parsing integer id
    final intId = int.tryParse(id) ?? int.tryParse(decoded);
    if (intId != null) {
      return isar.pdfDocuments.getSync(intId);
    }
    return null;
  }

  Future<void> shareDocument(PdfDocument doc) async {
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(doc.storagePath)],
        text: doc.fileName,
      ),
    );
  }

  Future<void> saveDocumentToDevice(BuildContext context, PdfDocument doc) async {
    final bytes = await File(doc.storagePath).readAsBytes();
    final picked = await FilePicker.saveFile(
      dialogTitle: 'Save PDF',
      fileName: doc.fileName,
      mimeType: 'application/pdf',
      bytes: bytes,
    );
    if (picked == null) return;
    final dest = picked.toFilePath();
    await File(doc.storagePath).copy(dest);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to ${p.basename(dest)}')),
      );
    }
  }

  Future<void> printDocument(PdfDocument doc) async {
    await Printing.layoutPdf(onLayout: (_) => File(doc.storagePath).readAsBytes());
  }

  Future<PdfDocument> indexGeneratedPdf({
    required String storagePath,
    required String invoiceId,
    required String template,
  }) async {
    final file = File(storagePath);
    final base = p.basename(storagePath);
    final cleanInv = invoiceId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    final logicalId =
        'doc_${DateTime.now().millisecondsSinceEpoch}_${cleanInv.isNotEmpty ? cleanInv : "pdf"}';
    final doc = PdfDocument(
      docId: logicalId,
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

  Future<void> reindexVault() async {
    final dir = await _vaultDir();
    final existingDocs = isar.pdfDocuments.where().findAllSync();
    final existingByPath = {for (final d in existingDocs) d.storagePath: d};
    final seenPaths = <String>{};
    final toSave = <PdfDocument>[];

    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        if (entity is! File || !entity.path.endsWith('.pdf')) continue;
        seenPaths.add(entity.path);
        final stat = await entity.stat();
        final base = p.basename(entity.path);

        var doc = existingByPath[entity.path];
        if (doc != null) {
          if (doc.docId.contains('/') || doc.docId.contains(r'\') || doc.docId.isEmpty) {
            final cleanName = p.basenameWithoutExtension(base).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
            doc.docId = 'doc_${stat.modified.millisecondsSinceEpoch}_$cleanName';
          }
          doc.bytes = stat.size;
          doc.generatedAt ??= stat.modified;
          toSave.add(doc);
        } else {
          final cleanName = p.basenameWithoutExtension(base).replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
          toSave.add(PdfDocument(
            docId: 'doc_${stat.modified.millisecondsSinceEpoch}_$cleanName',
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
      }
    }

    final toDeleteIds = existingDocs
        .where((d) => !seenPaths.contains(d.storagePath))
        .map((d) => d.id)
        .toList();

    await isar.writeTxn(() async {
      if (toDeleteIds.isNotEmpty) {
        await isar.pdfDocuments.deleteAll(toDeleteIds);
      }
      if (toSave.isNotEmpty) {
        await isar.pdfDocuments.putAll(toSave);
      }
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
      await isar.pdfDocuments.delete(doc.id);
    });
    _docStream.add(allDocuments());
    notifyListeners();
  }

  Future<PdfDocument> generatePdfFor(Invoice invoice) async {
    final bytes = await buildInvoicePdf(invoice);
    final dir = await _vaultDir();
    final name =
        '${invoice.template}_${invoice.number}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File('${dir.path}${p.separator}$name');
    await file.writeAsBytes(bytes);
    return indexGeneratedPdf(
      storagePath: file.path,
      invoiceId: invoice.invoiceId.isNotEmpty ? invoice.invoiceId : invoice.id.toString(),
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



  // ---------------------------------------------------------------- backup

  /// JSON backup, identical in shape to the web prototype's export.
  Map<String, dynamic> exportData() {
    return {
      'app': 'icon-billing-studio',
      'version': AppMeta.dataVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'data': {
        'business': (isar.business.where().findFirstSync() ?? Business()).toJson(),
        'clients': isar.clients.where().findAllSync().map((c) => c.toJson()).toList(),
        'services': isar.services.where().findAllSync().map((s) => s.toJson()).toList(),
        'invoices': isar.invoices.where().findAllSync().map((i) => i.toJson()).toList(),
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

  Future<void> setTheme(String theme) async {
    clearThemeLookupCache();
    settings.theme = theme;
    await settings.persist();
    notifyListeners();
  }

  Future<void> setAccent(String accentId, [int? custom]) async {
    clearThemeLookupCache();
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

/// Provides [Store] to the widget tree.
class StoreProvider extends InheritedNotifier<ChangeNotifier> {
  final Store store;

  const StoreProvider({
    super.key,
    required this.store,
    required super.child,
  }) : super(notifier: store);

  @override
  bool updateShouldNotify(StoreProvider oldWidget) => store != oldWidget.store;
}

class _StoreScope extends InheritedNotifier<ChangeNotifier> {
  final Store store;

  const _StoreScope({required this.store, required super.child})
      : super(notifier: store);
}

/// Lightweight wrapper that builds a [StoreProvider] once the store is open.
class StoreBinder extends StatefulWidget {
  final Widget child;
  const StoreBinder({super.key, required this.child});

  @override
  State<StoreBinder> createState() => _StoreBinderState();
}

class _StoreBinderState extends State<StoreBinder> {
  Store? _store;

  @override
  void initState() {
    super.initState();
    Store.create().then((s) {
      if (mounted) setState(() => _store = s);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_store == null) {
      return const Material(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    return StoreProvider(store: _store!, child: widget.child);
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
