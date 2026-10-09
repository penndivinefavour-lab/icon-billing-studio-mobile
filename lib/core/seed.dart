/// ICON Billing Studio - first-launch seed data.

///

/// Ported from the web prototype's js/seed.js: one business, five clients,

/// eight services, four documents in different states, plus one fully

/// populated sample invoice per template for the gallery.

library;



import 'dart:convert';



import 'package:isar/isar.dart';

import '../models/models.dart';



DateTime _daysFromNow(int days) =>

    DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)

        .add(Duration(days: days));



LineItem _li(String id, String name, String description, double qty, String unit,

        double price, double disc, double tax) =>

    LineItem(

        id: id,

        name: name,

        description: description,

        quantity: qty,

        unit: unit,

        unitPrice: price,

        discount: disc,

        taxRate: tax);



/* ---------------------------------------------------------------- business */



/// Seed every collection on first launch.

Future<void> seedAll(Isar isar) async {

  if (isar.clients.countSync() > 0) return;

  await isar.writeTxn(() async {

    isar.business.put(seedBusiness());

    isar.clients.putAll(seedClients());

    isar.services.putAll(seedServices());

    isar.invoices.putAll(seedInvoices());

  });

}



Business seedBusiness() => Business(

      businessId: 'primary',

      name: 'Lumen Workshop',

      email: 'studio@lumenworkshop.co',

      phone: '+237 680 14 22 90',

      website: 'lumenworkshop.co',

      addressLine: 'Rue 2.454, Bonanjo',

      city: 'Douala',

      region: 'Littoral',

      postal: '00237',

      country: 'Cameroon',

      taxId: 'M1093 8842 5571',

      logoText: 'LW',

      logoShape: 'rounded',

      bankName: 'Ecobank Cameroon',

      bankAccount: '02201 02834 8891',

      bankRouting: 'ECMCCMCX',

      swift: 'ECMCCMCX',

    );



/* ---------------------------------------------------------------- clients */



List<Client> seedClients() => [

      Client(

          clientId: 'cl_adiba',

          name: 'Adiba Njoh',

          company: 'Sable & Pine Interiors',

          email: 'adiba@sableandpine.com',

          phone: '+237 699 11 45 02',

          addressLine: '35 Bamboo Street',

          city: 'Buea',

          region: 'South West',

          country: 'Cameroon',

          notes: 'Prefers PDF attachments over print.'),

      Client(

          clientId: 'cl_marcus',

          name: 'Marcus Banda',

          company: 'Northline Logistics',

          email: 'marcus@northline.io',

          phone: '+27 21 555 0142',

          addressLine: '9 Harbour Road',

          city: 'Cape Town',

          region: 'Western Cape',

          country: 'South Africa'),

      Client(

          clientId: 'cl_ivy',

          name: 'Ivy Okonkwo',

          company: 'Fernwood Studio',

          email: 'ivy@fernwood.studio',

          phone: '+234 803 221 8890',

          addressLine: '12 Amaroo Close',

          city: 'Lagos',

          region: 'Lagos',

          country: 'Nigeria',

          notes: 'Retainer client - 30% deposit upfront.'),

      Client(

          clientId: 'cl_sofia',

          name: 'Sofia Marchetti',

          company: 'Casa Bella Catering',

          email: 'sofia@casabella.it',

          phone: '+39 340 555 1187',

          addressLine: 'Via Po 18',

          city: 'Turin',

          region: 'Piemonte',

          country: 'Italy'),

      Client(

          clientId: 'cl_theo',

          name: 'Theo Ndlovu',

          company: 'Veld Microfarms',

          email: 'theo@veldmicro.co.za',

          phone: '+27 11 555 7741',

          addressLine: 'Plot 7, Glen Anil',

          city: 'Johannesburg',

          region: 'Gauteng',

          country: 'South Africa'),

    ];



/* ---------------------------------------------------------------- services */



List<Service> seedServices() => [

      Service(

          serviceId: 'sv_brand',

          name: 'Brand identity package',

          description: 'Logo suite, marks, palette and type system.',

          unit: 'project',

          price: 2400,

          taxRate: 0,

          category: 'Design'),

      Service(

          serviceId: 'sv_web',

          name: 'Landing page design',

          description: 'Single-page responsive design in Webflow.',

          unit: 'page',

          price: 850,

          taxRate: 0,

          category: 'Design'),

      Service(

          serviceId: 'sv_retainer',

          name: 'Art direction retainer',

          description: 'Monthly creative direction and review.',

          unit: 'month',

          price: 1200,

          taxRate: 0,

          category: 'Consulting'),

      Service(

          serviceId: 'sv_photo',

          name: 'Product photography',

          description: 'Studio shoot, 12 edited images.',

          unit: 'session',

          price: 640,

          taxRate: 0,

          category: 'Production'),

      Service(

          serviceId: 'sv_motion',

          name: 'Motion graphics (15s)',

          description: 'Short animation for social or web.',

          unit: 'clip',

          price: 480,

          taxRate: 0,

          category: 'Production'),

      Service(

          serviceId: 'sv_print',

          name: 'Print production markup',

          description: 'Press supervision and proofing.',

          unit: 'hour',

          price: 95,

          taxRate: 0,

          category: 'Print'),

      Service(

          serviceId: 'sv_strategy',

          name: 'Strategy workshop',

          description: 'Half-day positioning and messaging.',

          unit: 'session',

          price: 1500,

          taxRate: 0,

          category: 'Consulting'),

      Service(

          serviceId: 'sv_support',

          name: 'Priority support',

          description: 'Same-day revisions, 30 days.',

          unit: 'pack',

          price: 350,

          taxRate: 0,

          category: 'Support'),

    ];



/* ---------------------------------------------------------------- invoices */



Invoice _seed(

  String id,

  String number,

  String type,

  String status,

  String template,

  String clientId,

  String toName,

  String toEmail,

  String toCompany,

  String toAddress,

  String poNumber,

  List<LineItem> items, {

  double globalDiscount = 0,

  double shipping = 0,

  String notes = '',

  String paymentInfo = '',

  String accent = '#1A2744',

  String accentName = 'Deep Navy',

  int issuedAgo = 0,

  int dueIn = 0,

}) =>

    Invoice(

      invoiceId: id,

      number: number,

      type: type,

      status: status,

      template: template,

      clientId: clientId,

      fromName: 'Lumen Workshop',

      fromEmail: 'studio@lumenworkshop.co',

      fromPhone: '+237 680 14 22 90',

      toName: toName,

      toEmail: toEmail,

      toCompany: toCompany,

      toAddress: toAddress,

      poNumber: poNumber,

      itemsJson: jsonEncode(items.map((e) => e.toJson()).toList()),

      globalDiscount: globalDiscount,

      shipping: shipping,

      currency: 'USD',

      notes: notes,

      paymentInfo: paymentInfo,

      accent: accent,

      accentName: accentName,

      issueDate: _daysFromNow(issuedAgo),

      dueDate: _daysFromNow(dueIn),

      createdAt: _daysFromNow(issuedAgo),

      updatedAt: _daysFromNow(dueIn),

    );



List<Invoice> seedInvoices() {

  return [

    _seed(

        'inv_seed1',

        'INV-2041',

        'invoice',

        'paid',

        'executive',

        'cl_adiba',

        'Adiba Njoh',

        'adiba@sableandpine.com',

        'Sable & Pine Interiors',

        '35 Bamboo Street, Buea',

        '',

        [

          _li('li_s11', 'Brand identity package', 'Logo suite, palette and type system', 1, 'project', 2400, 0, 0),

          _li('li_s12', 'Print production markup', 'Press supervision, 4 hours', 4, 'hour', 95, 0, 0),

        ],

        notes: 'Final files delivered via cloud. Print proofs retained for one year.',

        paymentInfo: 'Ecobank Cameroon - 02201 02834 8891 - SWIFT ECMCCMCX',

        issuedAgo: -28,

        dueIn: -13),

    _seed(

        'inv_seed2',

        'INV-2042',

        'invoice',

        'sent',

        'modern',

        'cl_ivy',

        'Ivy Okonkwo',

        'ivy@fernwood.studio',

        'Fernwood Studio',

        '12 Amaroo Close, Lagos',

        'PO-8821',

        [

          _li('li_s21', 'Art direction retainer', 'Monthly creative direction', 1, 'month', 1200, 0, 0),

          _li('li_s22', 'Landing page design', 'Two pages, responsive', 2, 'page', 850, 5, 0),

          _li('li_s23', 'Motion graphics (15s)', 'One 15-second clip', 1, 'clip', 480, 0, 0),

        ],

        notes: 'Retainer covers 2 revision rounds per deliverable.',

        paymentInfo: 'Ecobank Cameroon - 02201 02834 8891',

        accent: '#6B21A8',

        accentName: 'ICON Purple',

        issuedAgo: -6,

        dueIn: 8),

    _seed(

        'inv_seed3',

        'QUO-2043',

        'quotation',

        'draft',

        'creative',

        'cl_theo',

        'Theo Ndlovu',

        'theo@veldmicro.co.za',

        'Veld Microfarms',

        'Plot 7, Glen Anil, Johannesburg',

        '',

        [

          _li('li_s31', 'Strategy workshop', 'Half-day positioning session', 1, 'session', 1500, 0, 15),

          _li('li_s32', 'Brand identity package', 'Full identity system', 1, 'project', 2400, 10, 15),

          _li('li_s33', 'Product photography', 'Studio shoot, 12 images', 2, 'session', 640, 0, 15),

        ],

        globalDiscount: 5,

        notes: 'Quotation valid for 30 days. Travel billed separately beyond 50km.',

        paymentInfo: '50% deposit to Ecobank - 02201 02834 8891',

        accent: '#F5C518',

        accentName: 'Golden',

        issuedAgo: -1,

        dueIn: 29),

    _seed(

        'inv_seed4',

        'INV-2040',

        'invoice',

        'overdue',

        'minimal',

        'cl_marcus',

        'Marcus Banda',

        'marcus@northline.io',

        'Northline Logistics',

        '9 Harbour Road, Cape Town',

        'PO-8702',

        [

          _li('li_s41', 'Landing page design', 'Single page, responsive', 1, 'page', 850, 0, 0),

          _li('li_s42', 'Priority support', 'Same-day revisions, 30 days', 1, 'pack', 350, 0, 0),

        ],

        notes: 'Overdue - a reminder was sent on the 1st.',

        paymentInfo: 'Ecobank Cameroon - 02201 02834 8891 - SWIFT ECMCCMCX',

        accent: '#059669',

        accentName: 'Emerald',

        issuedAgo: -46,

        dueIn: -16),

  ];

}



/* ------------------------------------------------------- template samples */



/// One rich, fully-populated invoice per template, used by the gallery.

/// Opening a sample puts it in the editor as a fresh draft; nothing is

/// persisted until the user hits Save.

Map<String, Invoice> seedTemplateSamples() {

  final base = _seed(

    'tpl_sample',

    'INV-2044',

    'invoice',

    'draft',

    'executive',

    '',

    'Sofia Marchetti',

    'sofia@casabella.it',

    'Casa Bella Catering',

    'Via Po 18, Turin',

    'PO-3391',

    const [],

    notes: 'Thank you for your business. Quote valid 30 days from issue date.',

    paymentInfo: 'Ecobank Cameroon - 02201 02834 8891 - SWIFT ECMCCMCX',

  );



  Invoice tuned(

    String template,

    String accent,

    String accentName,

    List<LineItem> items,

  ) =>

      base.copy()

        ..invoiceId = 'tpl_sample'

        ..template = template

        ..accent = accent

        ..accentName = accentName

        ..items = items;



  return {

    'minimal': tuned('minimal', '#1A2744', 'Deep Navy', [

      _li('a1', 'Brand identity package', 'Logo suite, palette, type system', 1, 'project', 2400, 0, 0),

      _li('a2', 'Landing page design', 'Responsive single page', 1, 'page', 850, 0, 0),

    ]),

    'executive': tuned('executive', '#1A2744', 'Deep Navy', [

      _li('b1', 'Strategy workshop', 'Half-day positioning session', 1, 'session', 1500, 0, 0),

      _li('b2', 'Brand identity package', 'Full identity system', 1, 'project', 2400, 5, 0),

      _li('b3', 'Priority support', 'Same-day revisions, 30 days', 1, 'pack', 350, 0, 0),

    ]),

    'modern': tuned('modern', '#6B21A8', 'ICON Purple', [

      _li('c1', 'Art direction retainer', 'Monthly creative direction', 3, 'month',  1200, 0, 0),

      _li('c2', 'Motion graphics (15s)', 'Short animation for social', 2, 'clip', 480, 10, 0),

    ]),

    'classic': tuned('classic', '#1A2744', 'Deep Navy', [

      _li('d1', 'Product photography', 'Studio shoot, 12 edited images', 2, 'session', 640, 0, 0),

      _li('d2', 'Print production markup', 'Press supervision, 6 hours', 6, 'hour', 95, 0, 0),

    ]),

    'creative': tuned('creative', '#F5C518', 'Golden', [

      _li('e1', 'Motion graphics (15s)', 'Two 15-second clips, animated', 2, 'clip', 480, 0, 0),

      _li('e2', 'Brand identity package', 'Logo suite with motion lockup', 1, 'project', 2400, 15, 0),

    ]),

    'corporate': tuned('corporate', '#2563EB', 'Azure', [

      _li('f1', 'Strategy workshop', 'Positioning and messaging', 1, 'session', 1500, 0, 10),

      _li('f2', 'Art direction retainer', 'Quarterly direction', 3, 'month', 1200, 0, 10),

      _li('f3', 'Landing page design', 'Three pages, responsive', 3, 'page', 850, 7, 10),

    ]),

    'elegant': tuned('elegant', '#B8860B', 'Gold', [

      _li('g1', 'Brand identity package', 'Premium identity, foil-ready', 1, 'project', 2400, 0, 5),

      _li('g2', 'Product photography', 'Editorial shoot, 20 images', 1, 'session', 640, 0, 5),

    ]),

    'compact': tuned('compact', '#0D9488', 'Teal', [

      _li('h1', 'Landing page design', 'Responsive single page', 1, 'page', 850, 0, 0),

      _li('h2', 'Priority support', '30-day revision pack', 2, 'pack', 350, 0, 0),

      _li('h3', 'Motion graphics (15s)', 'One clip', 1, 'clip', 480, 0, 0),

    ]),

    'bold': tuned('bold', '#DC2626', 'Crimson', [

      _li('i1', 'Strategy workshop', 'Full-day intensive', 1, 'session', 1500, 0, 0),

      _li('i2', 'Brand identity package', 'Identity + guidelines book', 1, 'project', 2400, 0, 18),

    ]),

    'professional': tuned('professional', '#059669', 'Emerald', [

      _li('j1', 'Art direction retainer', 'Monthly direction', 1, 'month', 1200, 0, 12),

      _li('j2', 'Landing page design', 'Two pages', 2, 'page', 850, 0, 12),

      _li('j3', 'Print production markup', 'Press supervision, 3 hours', 3, 'hour', 95, 5, 12),

    ]),

  };

}



