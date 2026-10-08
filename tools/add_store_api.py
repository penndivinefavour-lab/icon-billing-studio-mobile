"""Adds the collection/CRUD/stats API to lib/core/store.dart."""
from pathlib import Path

ANCHOR = "  /// Delete the vault entry only."
assert ANCHOR in Path('lib/core/store.dart').read_text(encoding='utf-8')

BLOCK = r'''
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
      await isar.clients.delete(client.id!);
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
      await isar.services.delete(service.id!);
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
      await isar.invoices.delete(invoice.id!);
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
        list.sort((a, b) => a.issueDate.compareTo(b.issueDate));
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
        list.sort((a, b) => b.issueDate.compareTo(a.issueDate));
    }
    return list;
  }

  // ---------------------- Derived stats ----------------------

  /// Dashboard totals, mirroring getStats() in js/store.js.
  Stats getStats() {
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

    return Stats(
      outstanding: outstanding,
      paid: paid,
      overdue: overdue,
      draftCount: draft,
      clientCount: clients.length,
      invoiceCount: all.where((i) => !i.isQuote).length,
      quotationCount: all.where((i) => i.isQuote).length,
    );
  }

  /// Last six calendar months of billed revenue, oldest first.
  List<MonthlyPoint> getMonthlySeries() {
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
      final key = DateTime(inv.issueDate.year, inv.issueDate.month);
      if (buckets.containsKey(key)) {
        buckets[key] = buckets[key]! + computeTotals(inv).grandTotal;
      }
    }

    const names = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return order
        .map((k) => MonthlyPoint(label: names[k.month - 1], value: buckets[k]!))
        .toList();
  }

'''

p = Path('lib/core/store.dart')
s = p.read_text(encoding='utf-8')
s = s.replace(ANCHOR, BLOCK + ANCHOR, 1)
p.write_text(s, encoding='utf-8')
print('collection + stats API added')
