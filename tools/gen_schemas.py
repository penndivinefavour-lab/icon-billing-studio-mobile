"""Generates lib/models/isar_schemas.dart for isar4 (no build_runner needed).

isar4 removed the codegen'd CollectionSchema/PropertySchema classes in favour
of runtime IsarSchema objects plus a serialize/deserialize converter. This
file defines both for the six collections, using the same field lists the
v3 generator produced.
"""
from pathlib import Path

CONTENT = r'''library;

import 'package:isar/isar.dart';

import 'models.dart';

// --------------------------------------------------------------- Client

final clientSchema = IsarGeneratedSchema(
  schema: const IsarSchema(
    name: 'Client',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'clientId', type: IsarType.string),
      IsarPropertySchema(name: 'name', type: IsarType.string),
      IsarPropertySchema(name: 'company', type: IsarType.string),
      IsarPropertySchema(name: 'email', type: IsarType.string),
      IsarPropertySchema(name: 'phone', type: IsarType.string),
      IsarPropertySchema(name: 'addressLine', type: IsarType.string),
      IsarPropertySchema(name: 'city', type: IsarType.string),
      IsarPropertySchema(name: 'region', type: IsarType.string),
      IsarPropertySchema(name: 'country', type: IsarType.string),
      IsarPropertySchema(name: 'notes', type: IsarType.string),
      IsarPropertySchema(name: 'createdAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'updatedAt', type: IsarType.dateTime),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<Client>(
    serialize: (client) => {
      'id': client.id,
      'clientId': client.clientId,
      'name': client.name,
      'company': client.company,
      'email': client.email,
      'phone': client.phone,
      'addressLine': client.addressLine,
      'city': client.city,
      'region': client.region,
      'country': client.country,
      'notes': client.notes,
      'createdAt': client.createdAt,
      'updatedAt': client.updatedAt,
    },
    deserialize: (json) => Client(
      clientId: json['clientId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      company: json['company'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      addressLine: json['addressLine'] as String? ?? '',
      city: json['city'] as String? ?? '',
      region: json['region'] as String? ?? '',
      country: json['country'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdAt: json['createdAt'] as DateTime?,
      updatedAt: json['updatedAt'] as DateTime?,
    )..id = json['id'] as int? ?? Isar.autoIncrement,
  ),
);

// --------------------------------------------------------------- Service

final serviceSchema = IsarGeneratedSchema(
  schema: const IsarSchema(
    name: 'Service',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'serviceId', type: IsarType.string),
      IsarPropertySchema(name: 'name', type: IsarType.string),
      IsarPropertySchema(name: 'description', type: IsarType.string),
      IsarPropertySchema(name: 'unit', type: IsarType.string),
      IsarPropertySchema(name: 'price', type: IsarType.double),
      IsarPropertySchema(name: 'taxRate', type: IsarType.double),
      IsarPropertySchema(name: 'category', type: IsarType.string),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<Service>(
    serialize: (service) => {
      'id': service.id,
      'serviceId': service.serviceId,
      'name': service.name,
      'description': service.description,
      'unit': service.unit,
      'price': service.price,
      'taxRate': service.taxRate,
      'category': service.category,
    },
    deserialize: (json) => Service(
      serviceId: json['serviceId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      unit: json['unit'] as String? ?? 'item',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      taxRate: (json['taxRate'] as num?)?.toDouble() ?? 0,
      category: json['category'] as String? ?? '',
    )..id = json['id'] as int? ?? Isar.autoIncrement,
  ),
);

// --------------------------------------------------------------- Invoice

final invoiceSchema = IsarGeneratedSchema(
  schema: const IsarSchema(
    name: 'Invoice',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'invoiceId', type: IsarType.string),
      IsarPropertySchema(name: 'number', type: IsarType.string),
      IsarPropertySchema(name: 'type', type: IsarType.string),
      IsarPropertySchema(name: 'status', type: IsarType.string),
      IsarPropertySchema(name: 'template', type: IsarType.string),
      IsarPropertySchema(name: 'clientId', type: IsarType.string),
      IsarPropertySchema(name: 'fromName', type: IsarType.string),
      IsarPropertySchema(name: 'fromEmail', type: IsarType.string),
      IsarPropertySchema(name: 'fromPhone', type: IsarType.string),
      IsarPropertySchema(name: 'toName', type: IsarType.string),
      IsarPropertySchema(name: 'toEmail', type: IsarType.string),
      IsarPropertySchema(name: 'toCompany', type: IsarType.string),
      IsarPropertySchema(name: 'toAddress', type: IsarType.string),
      IsarPropertySchema(name: 'poNumber', type: IsarType.string),
      IsarPropertySchema(name: 'itemsJson', type: IsarType.string),
      IsarPropertySchema(name: 'globalDiscount', type: IsarType.double),
      IsarPropertySchema(name: 'shipping', type: IsarType.double),
      IsarPropertySchema(name: 'currency', type: IsarType.string),
      IsarPropertySchema(name: 'notes', type: IsarType.string),
      IsarPropertySchema(name: 'paymentInfo', type: IsarType.string),
      IsarPropertySchema(name: 'accent', type: IsarType.string),
      IsarPropertySchema(name: 'accentName', type: IsarType.string),
      IsarPropertySchema(name: 'issueDate', type: IsarType.dateTime),
      IsarPropertySchema(name: 'dueDate', type: IsarType.dateTime),
      IsarPropertySchema(name: 'createdAt', type: IsarType.dateTime),
      IsarPropertySchema(name: 'updatedAt', type: IsarType.dateTime),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<Invoice>(
    serialize: (invoice) => {
      'id': invoice.id,
      'invoiceId': invoice.invoiceId,
      'number': invoice.number,
      'type': invoice.type,
      'status': invoice.status,
      'template': invoice.template,
      'clientId': invoice.clientId,
      'fromName': invoice.fromName,
      'fromEmail': invoice.fromEmail,
      'fromPhone': invoice.fromPhone,
      'toName': invoice.toName,
      'toEmail': invoice.toEmail,
      'toCompany': invoice.toCompany,
      'toAddress': invoice.toAddress,
      'poNumber': invoice.poNumber,
      'itemsJson': invoice.itemsJson,
      'globalDiscount': invoice.globalDiscount,
      'shipping': invoice.shipping,
      'currency': invoice.currency,
      'notes': invoice.notes,
      'paymentInfo': invoice.paymentInfo,
      'accent': invoice.accent,
      'accentName': invoice.accentName,
      'issueDate': invoice.issueDate,
      'dueDate': invoice.dueDate,
      'createdAt': invoice.createdAt,
      'updatedAt': invoice.updatedAt,
    },
    deserialize: (json) => Invoice(
      invoiceId: json['invoiceId'] as String? ?? '',
      number: json['number'] as String? ?? '',
      type: json['type'] as String? ?? 'invoice',
      status: json['status'] as String? ?? 'draft',
      template: json['template'] as String? ?? 'executive',
      clientId: json['clientId'] as String? ?? '',
      fromName: json['fromName'] as String? ?? '',
      fromEmail: json['fromEmail'] as String? ?? '',
      fromPhone: json['fromPhone'] as String? ?? '',
      toName: json['toName'] as String? ?? '',
      toEmail: json['toEmail'] as String? ?? '',
      toCompany: json['toCompany'] as String? ?? '',
      toAddress: json['toAddress'] as String? ?? '',
      poNumber: json['poNumber'] as String? ?? '',
      itemsJson: json['itemsJson'] as String? ?? '[]',
      globalDiscount: (json['globalDiscount'] as num?)?.toDouble() ?? 0,
      shipping: (json['shipping'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      notes: json['notes'] as String? ?? '',
      paymentInfo: json['paymentInfo'] as String? ?? '',
      accent: json['accent'] as String? ?? '#1A2744',
      accentName: json['accentName'] as String? ?? 'Deep Navy',
      issueDate: json['issueDate'] as DateTime?,
      dueDate: json['dueDate'] as DateTime?,
      createdAt: json['createdAt'] as DateTime?,
      updatedAt: json['updatedAt'] as DateTime?,
    )..id = json['id'] as int? ?? Isar.autoIncrement,
  ),
);

// ------------------------------------------------------------- PdfDocument

final pdfDocumentSchema = IsarGeneratedSchema(
  schema: const IsarSchema(
    name: 'PdfDocument',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'docId', type: IsarType.string),
      IsarPropertySchema(name: 'invoiceId', type: IsarType.string),
      IsarPropertySchema(name: 'number', type: IsarType.string),
      IsarPropertySchema(name: 'type', type: IsarType.string),
      IsarPropertySchema(name: 'template', type: IsarType.string),
      IsarPropertySchema(name: 'clientName', type: IsarType.string),
      IsarPropertySchema(name: 'fileName', type: IsarType.string),
      IsarPropertySchema(name: 'storagePath', type: IsarType.string),
      IsarPropertySchema(name: 'bytes', type: IsarType.long),
      IsarPropertySchema(name: 'accent', type: IsarType.string),
      IsarPropertySchema(name: 'generatedAt', type: IsarType.dateTime),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<PdfDocument>(
    serialize: (doc) => {
      'id': doc.id,
      'docId': doc.docId,
      'invoiceId': doc.invoiceId,
      'number': doc.number,
      'type': doc.type,
      'template': doc.template,
      'clientName': doc.clientName,
      'fileName': doc.fileName,
      'storagePath': doc.storagePath,
      'bytes': doc.bytes,
      'accent': doc.accent,
      'generatedAt': doc.generatedAt,
    },
    deserialize: (json) => PdfDocument(
      docId: json['docId'] as String? ?? '',
      invoiceId: json['invoiceId'] as String? ?? '',
      number: json['number'] as String? ?? '',
      type: json['type'] as String? ?? 'invoice',
      template: json['template'] as String? ?? 'executive',
      clientName: json['clientName'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
      storagePath: json['storagePath'] as String? ?? '',
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      accent: json['accent'] as String? ?? '#1A2744',
      generatedAt: json['generatedAt'] as DateTime?,
    )..id = json['id'] as int? ?? Isar.autoIncrement,
  ),
);

// --------------------------------------------------------------- Business

final businessSchema = IsarGeneratedSchema(
  schema: const IsarSchema(
    name: 'Business',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'businessId', type: IsarType.string),
      IsarPropertySchema(name: 'name', type: IsarType.string),
      IsarPropertySchema(name: 'email', type: IsarType.string),
      IsarPropertySchema(name: 'phone', type: IsarType.string),
      IsarPropertySchema(name: 'website', type: IsarType.string),
      IsarPropertySchema(name: 'addressLine', type: IsarType.string),
      IsarPropertySchema(name: 'city', type: IsarType.string),
      IsarPropertySchema(name: 'region', type: IsarType.string),
      IsarPropertySchema(name: 'postal', type: IsarType.string),
      IsarPropertySchema(name: 'country', type: IsarType.string),
      IsarPropertySchema(name: 'taxId', type: IsarType.string),
      IsarPropertySchema(name: 'logoText', type: IsarType.string),
      IsarPropertySchema(name: 'logoShape', type: IsarType.string),
      IsarPropertySchema(name: 'bankName', type: IsarType.string),
      IsarPropertySchema(name: 'bankAccount', type: IsarType.string),
      IsarPropertySchema(name: 'bankRouting', type: IsarType.string),
      IsarPropertySchema(name: 'swift', type: IsarType.string),
      IsarPropertySchema(name: 'upi', type: IsarType.string),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<Business>(
    serialize: (business) => {
      'id': business.id,
      'businessId': business.businessId,
      'name': business.name,
      'email': business.email,
      'phone': business.phone,
      'website': business.website,
      'addressLine': business.addressLine,
      'city': business.city,
      'region': business.region,
      'postal': business.postal,
      'country': business.country,
      'taxId': business.taxId,
      'logoText': business.logoText,
      'logoShape': business.logoShape,
      'bankName': business.bankName,
      'bankAccount': business.bankAccount,
      'bankRouting': business.bankRouting,
      'swift': business.swift,
      'upi': business.upi,
    },
    deserialize: (json) => Business(
      businessId: json['businessId'] as String? ?? 'primary',
      name: json['name'] as String? ?? 'Your Business',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      website: json['website'] as String? ?? '',
      addressLine: json['addressLine'] as String? ?? '',
      city: json['city'] as String? ?? '',
      region: json['region'] as String? ?? '',
      postal: json['postal'] as String? ?? '',
      country: json['country'] as String? ?? '',
      taxId: json['taxId'] as String? ?? '',
      logoText: json['logoText'] as String? ?? '',
      logoShape: json['logoShape'] as String? ?? 'square',
      bankName: json['bankName'] as String? ?? '',
      bankAccount: json['bankAccount'] as String? ?? '',
      bankRouting: json['bankRouting'] as String? ?? '',
      swift: json['swift'] as String? ?? '',
      upi: json['upi'] as String? ?? '',
    )..id = json['id'] as int? ?? Isar.autoIncrement,
  ),
);

// -------------------------------------------------------------- AppSettings

final appSettingsSchema = IsarGeneratedSchema(
  schema: const IsarSchema(
    name: 'AppSettings',
    idName: 'id',
    embedded: false,
    properties: [
      IsarPropertySchema(name: 'theme', type: IsarType.string),
      IsarPropertySchema(name: 'accentId', type: IsarType.string),
      IsarPropertySchema(name: 'customAccent', type: IsarType.long),
      IsarPropertySchema(name: 'activeTemplate', type: IsarType.string),
      IsarPropertySchema(name: 'currency', type: IsarType.string),
      IsarPropertySchema(name: 'prefixInvoice', type: IsarType.string),
      IsarPropertySchema(name: 'prefixQuotation', type: IsarType.string),
      IsarPropertySchema(name: 'numberInvoice', type: IsarType.long),
      IsarPropertySchema(name: 'numberQuotation', type: IsarType.long),
      IsarPropertySchema(name: 'taxInclusive', type: IsarType.bool),
      IsarPropertySchema(name: 'showLogo', type: IsarType.bool),
    ],
    indexes: [],
  ),
  converter: IsarObjectConverter<AppSettings>(
    serialize: (settings) => {
      'id': settings.id,
      'theme': settings.theme,
      'accentId': settings.accentId,
      'customAccent': settings.customAccent,
      'activeTemplate': settings.activeTemplate,
      'currency': settings.currency,
      'prefixInvoice': settings.prefixInvoice,
      'prefixQuotation': settings.prefixQuotation,
      'numberInvoice': settings.numberInvoice,
      'numberQuotation': settings.numberQuotation,
      'taxInclusive': settings.taxInclusive,
      'showLogo': settings.showLogo,
    },
    deserialize: (json) => AppSettings(
      theme: json['theme'] as String? ?? 'dark',
      accentId: json['accentId'] as String? ?? 'icon',
      customAccent: json['customAccent'] as int?,
      activeTemplate: json['activeTemplate'] as String? ?? 'executive',
      currency: json['currency'] as String? ?? 'USD',
      prefixInvoice: json['prefixInvoice'] as String? ?? 'INV',
      prefixQuotation: json['prefixQuotation'] as String? ?? 'QUO',
      numberInvoice: (json['numberInvoice'] as num?)?.toInt() ?? 2041,
      numberQuotation: (json['numberQuotation'] as num?)?.toInt() ?? 2043,
      taxInclusive: json['taxInclusive'] as bool? ?? false,
      showLogo: json['showLogo'] as bool? ?? true,
    )..id = json['id'] as int? ?? 0,
  ),
);

// ------------------------------------------------------------- all schemas

final allSchemas = <IsarGeneratedSchema>[
  clientSchema,
  serviceSchema,
  invoiceSchema,
  pdfDocumentSchema,
  businessSchema,
  appSettingsSchema,
];
'''

OUT = Path('lib/models/isar_schemas.dart')
OUT.write_text(CONTENT, encoding='utf-8')
n = len(OUT.read_bytes())
assert n > 15000, n
print(f'OK {OUT} ({n} bytes)')
