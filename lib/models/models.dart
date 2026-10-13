/// ICON Billing Studio - data models.
///
/// Mirrors the web prototype's JSON document shape exactly so a backup
/// exported from the prototype imports here and vice versa.
library;

import 'dart:convert';

import 'package:isar/isar.dart';

part 'models.g.dart';


const _kInvoice = 'invoice';
const _kQuotation = 'quotation';

/* ---------------------------------------------------------------------- *
 * Client
 * ---------------------------------------------------------------------- */

@collection
@Name('Client')
class Client {
  Id id = Isar.autoIncrement;

  /// Stable logical id. Seed fixtures use readable ids ('cl_adiba').
  String clientId;

  String name;
  String company;
  String email;
  String phone;
  String addressLine;
  String city;
  String region;
  String country;
  String notes;

  DateTime? createdAt;
  DateTime? updatedAt;

  /// Defaulted constructor used when dates are not supplied.
  Client.dated({
    required this.name,
    this.clientId = '',
    this.company = '',
    this.email = '',
    this.phone = '',
    this.addressLine = '',
    this.city = '',
    this.region = '',
    this.country = '',
    this.notes = '',
  })  : createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  Client({
    this.clientId = '',
    required this.name,
    this.company = '',
    this.email = '',
    this.phone = '',
    this.addressLine = '',
    this.city = '',
    this.region = '',
    this.country = '',
    this.notes = '',
    this.createdAt,
    this.updatedAt,
  });

  factory Client.fromJson(Map<String, dynamic> j) => Client(
        clientId: (j['id'] ?? j['clientId'] ?? '').toString(),
        name: j['name'] ?? '',
        company: j['company'] ?? '',
        email: j['email'] ?? '',
        phone: j['phone'] ?? '',
        addressLine: j['addressLine'] ?? '',
        city: j['city'] ?? '',
        region: j['region'] ?? '',
        country: j['country'] ?? '',
        notes: j['notes'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': clientId,
        'name': name,
        'company': company,
        'email': email,
        'phone': phone,
        'addressLine': addressLine,
        'city': city,
        'region': region,
        'country': country,
        'notes': notes,
      };

  String get addressLineOne =>
      [addressLine, city, country].where((s) => s.trim().isNotEmpty).join(', ');
  DateTime get createdOn => createdAt ?? DateTime.now();

  Client copy() => Client(
        clientId: clientId,
        name: name,
        company: company,
        email: email,
        phone: phone,
        addressLine: addressLine,
        city: city,
        region: region,
        country: country,
        notes: notes,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
}

/* ---------------------------------------------------------------------- *
 * Service (reusable line item)
 * ---------------------------------------------------------------------- */

@collection
@Name('Service')
class Service {
  Id id = Isar.autoIncrement;

  String serviceId;
  String name;
  String description;
  String unit;
  double price;
  double taxRate;
  String category;

  DateTime? createdAt;

  Service.dated({
    required this.name,
    this.serviceId = '',
    this.description = '',
    this.unit = 'item',
    this.price = 0,
    this.taxRate = 0,
    this.category = '',
  }) : createdAt = DateTime.now();

  Service({
    this.serviceId = '',
    required this.name,
    this.description = '',
    this.unit = 'item',
    this.price = 0,
    this.taxRate = 0,
    this.category = '',
    this.createdAt,
  });

  factory Service.fromJson(Map<String, dynamic> j) => Service(
        serviceId: (j['id'] ?? j['serviceId'] ?? '').toString(),
        name: j['name'] ?? '',
        description: j['description'] ?? '',
        unit: j['unit'] ?? 'item',
        price: (j['price'] ?? 0).toDouble(),
        taxRate: (j['taxRate'] ?? 0).toDouble(),
        category: j['category'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': serviceId,
        'name': name,
        'description': description,
        'unit': unit,
        'price': price,
        'taxRate': taxRate,
        'category': category,
      };
}

/* ---------------------------------------------------------------------- *
 * Line item
 * ---------------------------------------------------------------------- */

/// One line on an invoice. Stored embedded as JSON inside [Invoice.itemsJson].
class LineItem {
  String id;
  String name;
  String description;
  double quantity;
  String unit;
  double unitPrice;
  double discount; // percent 0..100
  double taxRate; // percent 0..100

  LineItem({
    required this.id,
    this.name = '',
    this.description = '',
    this.quantity = 1,
    this.unit = 'item',
    this.unitPrice = 0,
    this.discount = 0,
    this.taxRate = 0,
  });

  /// Service this line was built from, if any (used by delete guards).
  String get linkedServiceId => '';

  /// Net for this line: qty x price minus the line discount.
  double get net =>
      round2(quantity * unitPrice * (1 - discount.clamp(0, 100) / 100));

  factory LineItem.fromJson(Map<String, dynamic> j) => LineItem(
        id: (j['id'] ?? '').toString(),
        name: j['name'] ?? '',
        description: j['description'] ?? '',
        quantity: (j['quantity'] ?? 1).toDouble(),
        unit: j['unit'] ?? 'item',
        unitPrice: (j['unitPrice'] ?? 0).toDouble(),
        discount: (j['discount'] ?? 0).toDouble(),
        taxRate: (j['taxRate'] ?? 0).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'discount': discount,
        'taxRate': taxRate,
      };

  LineItem copy() => LineItem(
        id: id,
        name: name,
        description: description,
        quantity: quantity,
        unit: unit,
        unitPrice: unitPrice,
        discount: discount,
        taxRate: taxRate,
      );
}

/* ---------------------------------------------------------------------- *
 * Derived money
 * ---------------------------------------------------------------------- */

/// Dashboard headline numbers.
class Stats {
  final double outstanding;
  final double paid;
  final double overdue;
  final int draftCount;
  final int clientCount;
  final int invoiceCount;
  final int quotationCount;

  const Stats({
    this.outstanding = 0,
    this.paid = 0,
    this.overdue = 0,
    this.draftCount = 0,
    this.clientCount = 0,
    this.invoiceCount = 0,
    this.quotationCount = 0,
  });
}

/// One bar of the revenue chart.
class MonthlyPoint {
  final String label;
  final double value;
  const MonthlyPoint({required this.label, this.value = 0});
}

/// One tax bucket shown in the totals block ("Tax 18%  ...").
class TaxBucket {
  final double rate;
  final double amount;
  const TaxBucket({required this.rate, required this.amount});

  Map<String, dynamic> toJson() => {'rate': rate, 'amount': amount};
}

/// Result of [computeTotals]. Money is always derived, never stored, so a
/// saved invoice and its preview can never disagree.
class Totals {
  final double subtotal;
  final double discountTotal;
  final double globalDiscount;
  final double taxableBase;
  final double afterDiscount;
  final double taxTotal;
  final List<TaxBucket> taxes;
  final double shipping;
  final double total;
  final int itemCount;
  final double units;

  /// The headline number. Mirrors the web prototype's naming.
  double get grandTotal => total;

  const Totals({
    required this.subtotal,
    required this.discountTotal,
    required this.globalDiscount,
    required this.taxableBase,
    required this.afterDiscount,
    required this.taxTotal,
    required this.taxes,
    required this.shipping,
    required this.total,
    required this.itemCount,
    required this.units,
  });

  static const empty = Totals(
    subtotal: 0,
    discountTotal: 0,
    globalDiscount: 0,
    taxableBase: 0,
    afterDiscount: 0,
    taxTotal: 0,
    taxes: [],
    shipping: 0,
    total: 0,
    itemCount: 0,
    units: 0,
  );
}

/* ---------------------------------------------------------------------- *
 * Invoice / quotation
 * ---------------------------------------------------------------------- */

@collection
@Name('Invoice')
class Invoice {
  Id id = Isar.autoIncrement;

  /// Stable logical id ('inv_seed1').
  String invoiceId;

  String number;
  String type; // 'invoice' | 'quotation'
  String status; // draft | sent | partial | paid | overdue
  String template; // one of the ten template ids
  String clientId;

  String fromName;
  String fromEmail;
  String fromPhone;
  String toName;
  String toEmail;
  String toCompany;
  String toAddress;
  String poNumber;

  /// Line items serialised to JSON (Isar has no embedded object list).
  String itemsJson;

  double globalDiscount;
  double shipping;
  String currency;
  String notes;
  String paymentInfo;

  String accent;
  String accentName;

  DateTime? issueDate;
  DateTime? dueDate;
  DateTime? createdAt;
  DateTime? updatedAt;

  Invoice.dated({
    this.invoiceId = '',
    this.number = '',
    this.type = _kInvoice,
    this.status = 'draft',
    this.template = 'executive',
    this.clientId = '',
    this.fromName = '',
    this.fromEmail = '',
    this.fromPhone = '',
    this.toName = '',
    this.toEmail = '',
    this.toCompany = '',
    this.toAddress = '',
    this.poNumber = '',
    this.itemsJson = '[]',
    this.globalDiscount = 0,
    this.shipping = 0,
    this.currency = 'USD',
    this.notes = '',
    this.paymentInfo = '',
    this.accent = '#1A2744',
    this.accentName = 'Deep Navy',
  })  : issueDate = DateTime.now(),
        dueDate = DateTime.now().add(const Duration(days: 14)),
        createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  Invoice({
    this.invoiceId = '',
    this.number = '',
    this.type = _kInvoice,
    this.status = 'draft',
    this.template = 'executive',
    this.clientId = '',
    this.fromName = '',
    this.fromEmail = '',
    this.fromPhone = '',
    this.toName = '',
    this.toEmail = '',
    this.toCompany = '',
    this.toAddress = '',
    this.poNumber = '',
    this.itemsJson = '[]',
    this.globalDiscount = 0,
    this.shipping = 0,
    this.currency = 'USD',
    this.notes = '',
    this.paymentInfo = '',
    this.accent = '#1A2744',
    this.accentName = 'Deep Navy',
    this.issueDate,
    this.dueDate,
    this.createdAt,
    this.updatedAt,
  });

  // ---------------------------------------------------------------- items

  /// Alias the views use when they want the raw list without the setter.
  @ignore
  List<LineItem> get itemsList => items;

  bool get isQuote => type == 'quotation';

  @ignore
  List<LineItem>? _itemsCache;

  /// Line items, decoded from [itemsJson]. @ignore keeps Isar's generator
  /// from treating the derived list as a persisted property.
  @ignore
  List<LineItem> get items {
    if (_itemsCache == null) {
      try {
        final list = jsonDecode(itemsJson);
        if (list is List) {
          _itemsCache = list
              .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
              .toList();
        } else {
          _itemsCache = <LineItem>[];
        }
      } catch (_) {
        _itemsCache = <LineItem>[];
      }
    }
    return _itemsCache!;
  }

  set items(List<LineItem> value) {
    _itemsCache = value;
    itemsJson = jsonEncode(value.map((e) => e.toJson()).toList());
  }

  void syncItemsJson() {
    if (_itemsCache != null) {
      itemsJson = jsonEncode(_itemsCache!.map((e) => e.toJson()).toList());
    }
  }

  /// Derived money breakdown.
  @ignore
  Totals get totals => computedTotals();

  /// Kept separate from the getter so Isar's generator ignores it cleanly.
  Totals computedTotals() => computeTotals(this);

  bool get isQuotation => type == _kQuotation;
  String get docLabel => isQuotation ? 'Quotation' : 'Invoice';

  /// Non-null views over the optional dates.
  DateTime get issuedOn => issueDate ?? createdAt ?? DateTime.now();
  DateTime get dueOn => dueDate ?? issuedOn.add(const Duration(days: 14));
  DateTime get createdOn => createdAt ?? DateTime.now();
  DateTime get updatedOn => updatedAt ?? createdOn;

  Invoice copy() {
    syncItemsJson();
    return Invoice(
        invoiceId: invoiceId,
        number: number,
        type: type,
        status: status,
        template: template,
        clientId: clientId,
        fromName: fromName,
        fromEmail: fromEmail,
        fromPhone: fromPhone,
        toName: toName,
        toEmail: toEmail,
        toCompany: toCompany,
        toAddress: toAddress,
        poNumber: poNumber,
        itemsJson: itemsJson,
        globalDiscount: globalDiscount,
        shipping: shipping,
        currency: currency,
        notes: notes,
        paymentInfo: paymentInfo,
        accent: accent,
        accentName: accentName,
        issueDate: issueDate,
        dueDate: dueDate,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
  }

  factory Invoice.fromJson(Map<String, dynamic> j) {
    final items = (j['items'] as List?) ?? [];
    return Invoice(
      invoiceId: (j['id'] ?? '').toString(),
      number: j['number'] ?? '',
      type: j['type'] ?? 'invoice',
      status: j['status'] ?? 'draft',
      template: j['template'] ?? 'executive',
      clientId: j['clientId'] ?? '',
      fromName: j['fromName'] ?? '',
      fromEmail: j['fromEmail'] ?? '',
      fromPhone: j['fromPhone'] ?? '',
      toName: j['toName'] ?? '',
      toEmail: j['toEmail'] ?? '',
      toCompany: j['toCompany'] ?? '',
      toAddress: j['toAddress'] ?? '',
      poNumber: j['poNumber'] ?? '',
      itemsJson: jsonEncode(items),
      globalDiscount: (j['globalDiscount'] ?? 0).toDouble(),
      shipping: (j['shipping'] ?? 0).toDouble(),
      currency: j['currency'] ?? 'USD',
      notes: j['notes'] ?? '',
      paymentInfo: j['paymentInfo'] ?? '',
      accent: j['accent'] ?? '#1A2744',
      accentName: j['accentName'] ?? 'Deep Navy',
      issueDate: parseIsoDate(j['issueDate']) ?? DateTime.now(),
      dueDate: parseIsoDate(j['dueDate']) ?? DateTime.now(),
      createdAt: parseIsoDate(j['createdAt']) ?? DateTime.now(),
      updatedAt: parseIsoDate(j['updatedAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': invoiceId,
        'number': number,
        'type': type,
        'status': status,
        'template': template,
        'clientId': clientId,
        'fromName': fromName,
        'fromEmail': fromEmail,
        'fromPhone': fromPhone,
        'toName': toName,
        'toEmail': toEmail,
        'toCompany': toCompany,
        'toAddress': toAddress,
        'poNumber': poNumber,
        'items': items.map((e) => e.toJson()).toList(),
        'globalDiscount': globalDiscount,
        'shipping': shipping,
        'currency': currency,
        'notes': notes,
        'paymentInfo': paymentInfo,
        'accent': accent,
        'accentName': accentName,
        'issueDate': isoDateString(issuedOn),
        'dueDate': isoDateString(dueOn),
        'createdAt': isoDateString(createdOn),
        'updatedAt': isoDateString(updatedOn),
      };
}

/* ---------------------------------------------------------------------- *
 * Generated PDF document (the in-app PDF Vault entry)
 * ---------------------------------------------------------------------- */

@collection
@Name('PdfDocument')
class PdfDocument {
  Id id = Isar.autoIncrement;

  String docId; // stable logical id
  String invoiceId; // owning invoice (never null after generation)
  String number; // INV-0001
  String type; // invoice | quotation
  String template; // template used at generation time
  String clientName;
  String fileName; // INV-0001-Adiba-Njoh.pdf
  String storagePath; // app-private copy (kept after export)
  int bytes;
  String accent;

  DateTime? generatedAt;

  // --- read-only aliases used by the vault UI (kept narrow on purpose) ---
  String get uuid => docId;
  String get path => storagePath;
  int get sizeBytes => bytes;
  DateTime get created => generatedAt ?? DateTime.now();
  String get sourceInvoiceId => invoiceId;
  int get pageCount => _pageCount;

  static const int _pageCount = 0;

  PdfDocument.dated({
    this.docId = '',
    this.invoiceId = '',
    this.number = '',
    this.type = 'invoice',
    this.template = 'executive',
    this.clientName = '',
    this.fileName = '',
    this.storagePath = '',
    this.bytes = 0,
    this.accent = '#1A2744',
  }) : generatedAt = DateTime.now();

  PdfDocument({
    this.docId = '',
    this.invoiceId = '',
    this.number = '',
    this.type = 'invoice',
    this.template = 'executive',
    this.clientName = '',
    this.fileName = '',
    this.storagePath = '',
    this.bytes = 0,
    this.accent = '#1A2744',
    this.generatedAt,
  });

  String get docLabel => type == 'quotation' ? 'Quotation' : 'Invoice';
  DateTime get generatedOn => generatedAt ?? DateTime.now();
}

/* ---------------------------------------------------------------------- *
 * Business profile
 * ---------------------------------------------------------------------- */

@collection
@Name('Business')
class Business {
  Id id = Isar.autoIncrement;

  String businessId;
  String name;
  String email;
  String phone;
  String website;
  String addressLine;
  String city;
  String region;
  String postal;
  String country;
  String taxId;
  String logoText;
  String logoShape;
  String bankName;
  String bankAccount;
  String bankRouting;
  String swift;
  String upi;

  Business({
    this.businessId = 'primary',
    this.name = 'Your Business',
    this.email = '',
    this.phone = '',
    this.website = '',
    this.addressLine = '',
    this.city = '',
    this.region = '',
    this.postal = '',
    this.country = '',
    this.taxId = '',
    this.logoText = '',
    this.logoShape = 'square',
    this.bankName = '',
    this.bankAccount = '',
    this.bankRouting = '',
    this.swift = '',
    this.upi = '',
  });

  factory Business.fromJson(Map<String, dynamic> j) => Business(
        businessId: 'primary',
        name: j['name'] ?? 'Your Business',
        email: j['email'] ?? '',
        phone: j['phone'] ?? '',
        website: j['website'] ?? '',
        addressLine: j['addressLine'] ?? '',
        city: j['city'] ?? '',
        region: j['region'] ?? '',
        postal: j['postal'] ?? '',
        country: j['country'] ?? '',
        taxId: j['taxId'] ?? '',
        logoText: j['logoText'] ?? '',
        logoShape: j['logoShape'] ?? 'square',
        bankName: j['bankName'] ?? '',
        bankAccount: j['bankAccount'] ?? '',
        bankRouting: j['bankRouting'] ?? '',
        swift: j['swift'] ?? '',
        upi: j['upi'] ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'website': website,
        'addressLine': addressLine,
        'city': city,
        'region': region,
        'postal': postal,
        'country': country,
        'taxId': taxId,
        'logoText': logoText,
        'logoShape': logoShape,
        'bankName': bankName,
        'bankAccount': bankAccount,
        'bankRouting': bankRouting,
        'swift': swift,
        'upi': upi,
      };

  /// One-line payment string used to prefill new invoices.
  String get paymentLine =>
      [bankName, bankAccount, swift].where((s) => s.trim().isNotEmpty).join(' - ');

  Business copy() => Business(
        businessId: businessId,
        name: name,
        email: email,
        phone: phone,
        website: website,
        addressLine: addressLine,
        city: city,
        region: region,
        postal: postal,
        country: country,
        taxId: taxId,
        logoText: logoText,
        logoShape: logoShape,
        bankName: bankName,
        bankAccount: bankAccount,
        bankRouting: bankRouting,
        swift: swift,
        upi: upi,
      );
}

/* ---------------------------------------------------------------------- *
 * Pure helpers shared by model + tests
 * ---------------------------------------------------------------------- */

/// Round to two decimals without floating-point noise.
double round2(double v) => ((v + 1e-9) * 100).roundToDouble() / 100;

/// Parse 'yyyy-mm-dd' or an ISO datetime into a local [DateTime].
DateTime? parseIsoDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  final s = value.toString().trim();
  if (s.isEmpty) return null;
  if (s.contains('T')) {
    return DateTime.tryParse(s)?.toLocal();
  }
  final p = s.split('-');
  if (p.length == 3) {
    return DateTime.tryParse(
        '${p[0]}-${p[1].padLeft(2, '0')}-${p[2].padLeft(2, '0')}');
  }
  return DateTime.tryParse(s);
}

/// 'yyyy-MM-dd' string for storage and display keys.
String isoDateString(DateTime d) {
  final local = d.toLocal();
  return '${local.year.toString().padLeft(4, '0')}'
      '-${local.month.toString().padLeft(2, '0')}'
      '-${local.day.toString().padLeft(2, '0')}';
}

/// Line-level discount first, then per-line tax on the discounted amount.
/// Rates are pooled per rate so the totals block can show "Tax 18%" rows
/// instead of one opaque number. Byte-for-byte equivalent to the web
/// prototype's computeTotals().
Totals computeTotals(Invoice invoice) {
  invoice.syncItemsJson();
  final items = invoice.items;
  double subtotal = 0;
  double discountTotal = 0;
  final buckets = <double, double>{};
  var itemCount = 0;
  var units = 0.0;

  for (final it in items) {
    final gross = it.quantity * it.unitPrice;
    final disc = round2(gross * (it.discount.clamp(0, 100) / 100));
    final net = round2(gross - disc);
    final taxed = round2(net * (it.taxRate.clamp(0, 100) / 100));

    subtotal = round2(subtotal + gross);
    discountTotal = round2(discountTotal + disc);
    buckets[it.taxRate.clamp(0, 100)] =
        round2((buckets[it.taxRate.clamp(0, 100)] ?? 0) + taxed);
    itemCount += 1;
    units += it.quantity;
  }

  final taxableBase = round2(subtotal - discountTotal);
  final globalRate = invoice.globalDiscount.clamp(0, 100);
  final globalDiscount = round2(taxableBase * (globalRate / 100));
  final afterDiscount = round2(taxableBase - globalDiscount);

  var taxTotal = 0.0;
  final taxes = <TaxBucket>[];
  for (final entry in buckets.entries) {
    if (entry.value > 0) {
      final scaled = round2(entry.value * (1 - globalRate / 100));
      taxTotal = round2(taxTotal + scaled);
      taxes.add(TaxBucket(rate: entry.key, amount: scaled));
    }
  }
  taxes.sort((a, b) => b.rate.compareTo(a.rate));

  final shipping = invoice.shipping < 0 ? 0.0 : invoice.shipping;
  final total = round2(afterDiscount + taxTotal + shipping);

  return Totals(
    subtotal: subtotal,
    discountTotal: discountTotal,
    globalDiscount: globalDiscount,
    taxableBase: taxableBase,
    afterDiscount: afterDiscount,
    taxTotal: taxTotal,
    taxes: taxes,
    shipping: shipping,
    total: total,
    itemCount: itemCount,
    units: units,
  );
}

/// Lightweight total used for dashboard aggregation and list rows.
/// Matches the web prototype's store money() helper.
double invoiceAggregate(Invoice invoice) {
  var sum = 0.0;
  for (final it in invoice.items) {
    final gross = it.quantity * it.unitPrice;
    final disc = gross * (it.discount.clamp(0, 100) / 100);
    sum += (gross - disc) * (1 + it.taxRate.clamp(0, 100) / 100);
  }
  return round2(sum);
}