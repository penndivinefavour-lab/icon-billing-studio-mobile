/// ICON Billing Studio - product constants.
///
/// Ported from the web prototype's js/constants.js. Ids are unchanged so the
/// two implementations stay interoperable.

/// ids, labels and colours of the five document statuses.
library;
class StatusDef {
  final String id;
  final String label;
  final int color;
  const StatusDef({required this.id, required this.label, required this.color});
}

const kStatuses = <StatusDef>[
  StatusDef(id: 'draft', label: 'Draft', color: 0xFF8A8F98),
  StatusDef(id: 'sent', label: 'Sent', color: 0xFF3B82F6),
  StatusDef(id: 'partial', label: 'Partial', color: 0xFFF5C518),
  StatusDef(id: 'paid', label: 'Paid', color: 0xFF22C55E),
  StatusDef(id: 'overdue', label: 'Overdue', color: 0xFFEF4444),
];

const kStatusIds = <String>['draft', 'sent', 'partial', 'paid', 'overdue'];

StatusDef statusById(String id) {
  for (final s in kStatuses) {
    if (s.id == id) return s;
  }
  return kStatuses.first;
}

String statusLabel(String id) => statusById(id).label;

/// Short hint shown under each status in the change-status sheet.
String statusHint(String id) => const <String, String>{
      'draft': 'Not sent yet',
      'sent': 'Delivered, awaiting payment',
      'partial': 'Partially paid',
      'paid': 'Fully settled',
      'overdue': 'Past the due date',
    }[id] ??
    '';

const kDocumentTypes = <Map<String, String>>[
  {'id': 'invoice', 'label': 'Invoice'},
  {'id': 'quotation', 'label': 'Quotation'},
];

/* ---------------------------------------------------------------- accents */

/// One selectable brand accent. The app and every invoice template re-skin
/// from this single colour.
class AccentDef {
  final String id;
  final String name;
  final int a;
  final int aSoft;
  const AccentDef({required this.id, required this.name, required this.a, required this.aSoft});
}

const kAccents = <AccentDef>[
  AccentDef(id: 'icon', name: 'ICON Purple', a: 0xFF6B21A8, aSoft: 0xFF8B3FC9),
  AccentDef(id: 'navy', name: 'Deep Navy', a: 0xFF1A2744, aSoft: 0xFF3A4A6E),
  AccentDef(id: 'gold', name: 'Golden', a: 0xFFB8860B, aSoft: 0xFFD4A517),
  AccentDef(id: 'emerald', name: 'Emerald', a: 0xFF059669, aSoft: 0xFF10B981),
  AccentDef(id: 'crimson', name: 'Crimson', a: 0xFFDC2626, aSoft: 0xFFF05252),
  AccentDef(id: 'azure', name: 'Azure', a: 0xFF2563EB, aSoft: 0xFF3B82F6),
  AccentDef(id: 'teal', name: 'Teal', a: 0xFF0D9488, aSoft: 0xFF14B8A6),
  AccentDef(id: 'rose', name: 'Rose', a: 0xFFE11D48, aSoft: 0xFFF43F5E),
  AccentDef(id: 'slate', name: 'Slate', a: 0xFF475569, aSoft: 0xFF64748B),
  AccentDef(id: 'sunset', name: 'Sunset', a: 0xFFEA580C, aSoft: 0xFFFB923C),
];

AccentDef accentById(String id) {
  for (final a in kAccents) {
    if (a.id == id) return a;
  }
  return kAccents.first;
}

/* ---------------------------------------------------------------- templates */

/// One of the ten built-in invoice layouts.
class TemplateDef {
  final String id;
  final String name;
  final String category;
  final String blurb;
  const TemplateDef({required this.id, required this.name, required this.category, required this.blurb});
}

/// The ten template ids, in gallery order. These never change.
const kTemplateIds = <String>[
  'minimal',
  'executive',
  'modern',
  'classic',
  'creative',
  'corporate',
  'elegant',
  'compact',
  'bold',
  'professional',
];

const kTemplates = <TemplateDef>[
  TemplateDef(id: 'minimal', name: 'Minimal', category: 'Clean', blurb: 'Quiet type, generous air, zero ornament.'),
  TemplateDef(id: 'executive', name: 'Executive', category: 'Formal', blurb: 'Two-tone masthead, ledger-style itemisation.'),
  TemplateDef(id: 'modern', name: 'Modern', category: 'Tech', blurb: 'Accent spine, banded rows, panelled totals.'),
  TemplateDef(id: 'classic', name: 'Classic', category: 'Formal', blurb: 'Centered letterhead, double-rule tables.'),
  TemplateDef(id: 'creative', name: 'Creative', category: 'Bold', blurb: 'Inverted hero block, big invoice wordmark.'),
  TemplateDef(id: 'corporate', name: 'Corporate', category: 'Business', blurb: 'Header strip with totals sidebar column.'),
  TemplateDef(id: 'elegant', name: 'Elegant', category: 'Premium', blurb: 'Serif masthead, hairlines, generous margins.'),
  TemplateDef(id: 'compact', name: 'Compact', category: 'Utility', blurb: 'Dense single-column docket for quick prints.'),
  TemplateDef(id: 'bold', name: 'Bold', category: 'Bold', blurb: 'Chunky type, solid bands, high contrast.'),
  TemplateDef(id: 'professional', name: 'Professional', category: 'Business', blurb: 'Structured rows, payment panel, receipt stub.'),
];

TemplateDef templateById(String id) {
  for (final t in kTemplates) {
    if (t.id == id) return t;
  }
  return kTemplates[1]; // executive
}

String templateName(String id) => templateById(id).name;

/* ---------------------------------------------------------------- misc */

const kCurrencies = <String>[
  'USD', 'EUR', 'GBP', 'NGN', 'XAF', 'GHS', 'ZAR', 'CAD', 'KES', 'INR', 'JPY', 'CHF', 'AUS'
];

/// Rates offered in the line-item tax picker.
const kDefaultTaxRates = <double>[0, 5, 10, 15, 18, 20, 25];

/// Statuses a document may move to from [from].
const kStatusFlow = <String, List<String>>{
  'draft': ['sent', 'paid', 'overdue'],
  'sent': ['partial', 'paid', 'overdue', 'draft'],
  'partial': ['paid', 'overdue'],
  'paid': ['draft'],
  'overdue': ['partial', 'paid', 'draft'],
};

class AppMeta {
  static const name = 'ICON Billing Studio';
  static const dataVersion = 1;
}
