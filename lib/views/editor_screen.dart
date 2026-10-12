library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../ui/kit.dart';

/// Invoice editor: parties, dates, line items, totals, notes, status.
///
/// The draft is held in the widget state and totals recompute on every
/// keystroke. Nothing is persisted until the user taps Save.
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.invoiceId});

  /// 'new', 'template' or an existing invoice id.
  final String invoiceId;

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final Store _store;
  late Invoice _draft;
  bool _loading = true;
  bool _found = false;
  String? _templatePending;

  @override
  void initState() {
    super.initState();
    _store = Store.instance;
    _load();
  }

  Future<void> _load() async {
    final id = widget.invoiceId;
    if (id == 'template') {
      final tpl = _templatePending;
      final pending = tpl == null || tpl.isEmpty
          ? null
          : _store.consumeTemplateSample(tpl);
      if (pending != null) {
        setState(() {
          _draft = pending;
          _found = false;
          _loading = false;
        });
        return;
      }
    }
    if (id.isEmpty || id == 'new' || id == 'template') {
      setState(() {
        _draft = _store.newInvoiceDraft();
        _found = false;
        _loading = false;
      });
      return;
    }
    final saved = _store.invoiceById(id);
    if (saved == null) {
      setState(() {
        _draft = _store.newInvoiceDraft();
        _found = false;
        _loading = false;
      });
      return;
    }
    setState(() {
      _draft = saved.copy();
      _found = true;
      _loading = false;
    });
  }

  /* ---------------------------------------------------------------- save */

  List<String> _validate() {
    final problems = <String>[];
    if (_draft.fromName.trim().isEmpty) problems.add('Add your business name.');
    if (_draft.toName.trim().isEmpty) problems.add('Add a client name.');
    if (_draft.items.isEmpty ||
        !_draft.items.any((i) => i.name.trim().isNotEmpty)) {
      problems.add('Add at least one line item with a name.');
    }
    return problems;
  }

  Future<void> _save() async {
    final problems = _validate();
    if (problems.isNotEmpty) {
      showAppToast(context, problems.first, error: true);
      return;
    }
    setState(() => _saving = true);
    final saved = await _store.saveInvoice(_draft);
    setState(() => _saving = false);
    if (!mounted) return;
    showAppToast(
      context,
      '${saved.docLabel} ${saved.number} saved',
      success: true,
    );
    context.go('/invoices');
  }

  bool _saving = false;

  Future<void> _duplicate() async {
    final copy = _store.duplicateInvoice(_draft);
    if (!mounted) return;
    showAppToast(context, 'Duplicated as ${copy.number}', success: true);
    context.go('/editor/${copy.invoiceId}');
  }

  Future<void> _delete() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this document?',
      message: 'This permanently removes ${_draft.number}. This cannot be undone.',
    );
    if (!ok || !mounted) return;
    await _store.deleteInvoice(_draft.invoiceId);
    if (!mounted) return;
    showAppToast(context, '${_draft.number} deleted');
    context.go('/invoices');
  }

  Future<void> _generatePdf() async {
    final problems = _validate();
    if (problems.isNotEmpty) {
      showAppToast(context, problems.first, error: true);
      return;
    }
    final saved = _draft.invoiceId.isEmpty
        ? await _store.saveInvoice(_draft)
        : _draft;
    setState(() => _draft = saved);
    if (!mounted) return;
    context.go('/documents/generate/${saved.invoiceId}');
  }

  /* ---------------------------------------------------------------- items */

  void _addItem([LineItem? preset]) {
    setState(() {
      _draft.items.add(preset ?? LineItem(id: 'li_${DateTime.now().microsecondsSinceEpoch}'));
    });
  }

  void _removeItem(int index) {
    if (_draft.items.length <= 1) return;
    setState(() => _draft.items.removeAt(index));
  }

  void _recalc() {
    // Totals are derived from the model, so a rebuild is enough. This hook
    // exists so animated totals can be triggered deliberately.
    setState(() {});
  }

  Future<void> _addFromService() async {
    final services = _store.services;
    if (services.isEmpty) {
      showAppToast(context, 'Create a service first');
      return;
    }
    final picked = await showModalBottomSheet<Service>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add from service library',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors(context).text,
                ),
              ),
              const SizedBox(height: 12),
              for (final sv in services) ...[
                hairline(context),
                ListRow(
                  onTap: () => Navigator.pop(context, sv),
                  leading: Avatar(sv.name, size: 36),
                  trailing: Icon(AppIcons.plus, size: 18, color: colors(context).accent),
                  child: Meta(
                    title: sv.name,
                    subtitle: '${sv.unit} · ${formatMoney(sv.price, _draft.currency)}',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _draft.items.add(LineItem(
        id: 'li_${DateTime.now().microsecondsSinceEpoch}',
        name: picked.name,
        description: picked.description,
        unit: picked.unit,
        unitPrice: picked.price,
        taxRate: picked.taxRate,
      ));
    });
    showAppToast(context, 'Added “${picked.name}”', success: true);
  }

  /* ---------------------------------------------------------------- build */

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: colors(context).accent,
          ),
        ),
      );
    }

    final totals = _draft.totals;
    final docLabel = _draft.docLabel;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/invoices'),
          icon: const Icon(AppIcons.back, size: 20),
        ),
        title: Text(_found
            ? 'Edit ${docLabel.toLowerCase()} ${_draft.number}'
            : 'New ${docLabel.toLowerCase()}'),
        actions: [
          IconButton(
            onPressed: () => context.go('/preview'),
            icon: const Icon(AppIcons.preview, size: 20),
            tooltip: 'Preview',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _PartiesCard(draft: _draft, store: _store, onChanged: _recalc),
                  const SizedBox(height: 14),
                  _ItemsCard(
                    draft: _draft,
                    onAdd: _addItem,
                    onAddFromService: _addFromService,
                    onRemove: _removeItem,
                    onChanged: _recalc,
                  ),
                  const SizedBox(height: 14),
                  _TotalsCard(draft: _draft, totals: totals, onChanged: _recalc),
                  const SizedBox(height: 14),
                  _StatusCard(draft: _draft, onChanged: _recalc),
                  const SizedBox(height: 14),
                  _ActionsCard(
                    found: _found,
                    saving: _saving,
                    onSave: _save,
                    onDuplicate: _duplicate,
                    onDelete: _delete,
                    onPdf: _generatePdf,
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------- parties */

class _PartiesCard extends StatelessWidget {
  const _PartiesCard({
    required this.draft,
    required this.store,
    required this.onChanged,
  });

  final Invoice draft;
  final Store store;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final clients = store.clients;
    return SectionCard(
      title: 'Business & customer',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Text(
                  label: 'Your business',
                  value: draft.fromName,
                  onChanged: (v) {
                    draft.fromName = v;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Text(
                  label: 'Your email',
                  value: draft.fromEmail,
                  onChanged: (v) {
                    draft.fromEmail = v;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: draft.clientId.isEmpty ? null : draft.clientId,
            decoration: const InputDecoration(labelText: 'Load saved client'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Choose a saved client…')),
              ...clients.map((c) => DropdownMenuItem(
                    value: c.clientId,
                    child: Text(c.company.isEmpty ? c.name : '${c.name} · ${c.company}'),
                  )),
            ],
            onChanged: (id) {
              final c = store.clientById(id ?? '');
              if (c == null) return;
              draft.clientId = c.clientId;
              draft.toName = c.name;
              draft.toEmail = c.email;
              draft.toCompany = c.company;
              draft.toAddress = c.addressLineOne;
              onChanged();
              showAppToast(context, 'Filled customer details from ${c.name}',
                  success: true);
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Text(
                  label: 'Client name',
                  value: draft.toName,
                  onChanged: (v) {
                    draft.toName = v;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Text(
                  label: 'Client email',
                  value: draft.toEmail,
                  onChanged: (v) {
                    draft.toEmail = v;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Text(
                  label: 'Company',
                  value: draft.toCompany,
                  onChanged: (v) {
                    draft.toCompany = v;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Text(
                  label: 'Address',
                  value: draft.toAddress,
                  onChanged: (v) {
                    draft.toAddress = v;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => context.go('/clients'),
                icon: const Icon(AppIcons.plus, size: 15),
                label: const Text('New client'),
              ),
              const SizedBox(width: 10),
              Text(
                clients.isEmpty ? 'no clients yet' : '${clients.length} saved',
                style: TextStyle(fontSize: 11.5, color: colors(context).text3),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ items */

class _ItemsCard extends StatelessWidget {
  const _ItemsCard({
    required this.draft,
    required this.onAdd,
    required this.onAddFromService,
    required this.onRemove,
    required this.onChanged,
  });

  final Invoice draft;
  final VoidCallback onAdd;
  final VoidCallback onAddFromService;
  final void Function(int index) onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final totals = draft.totals;
    return SectionCard(
      title: 'Line items',
      trailing: Text(
        '${totals.itemCount} items',
        style: TextStyle(
          fontSize: 11.5,
          color: colors(context).text3,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      child: Column(
        children: [
          for (int i = 0; i < draft.items.length; i++)
            _LineItemRow(
              key: ValueKey(draft.items[i].id),
              index: i,
              item: draft.items[i],
              currency: draft.currency,
              canRemove: draft.items.length > 1,
              onRemove: () => onRemove(i),
              onChanged: onChanged,
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(AppIcons.plus, size: 15),
                label: const Text('Add item'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: onAddFromService,
                icon: const Icon(AppIcons.services, size: 15),
                label: const Text('From service'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  const _LineItemRow({
    super.key,
    required this.index,
    required this.item,
    required this.currency,
    required this.canRemove,
    required this.onRemove,
    required this.onChanged,
  });

  final int index;
  final LineItem item;
  final String currency;
  final bool canRemove;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.surface2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Text(
                    label: 'Item ${index + 1}',
                    value: item.name,
                    hint: 'Item or service name',
                    onChanged: (v) {
                      item.name = v;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: canRemove ? onRemove : null,
                  icon: const Icon(AppIcons.trash, size: 17),
                  color: dangerColor,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Num(
                    label: 'Quantity',
                    value: item.quantity,
                    onChanged: (v) {
                      item.quantity = v;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Text(
                    label: 'Unit',
                    value: item.unit,
                    onChanged: (v) {
                      item.unit = v;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Num(
                    label: 'Unit price',
                    value: item.unitPrice,
                    onChanged: (v) {
                      item.unitPrice = v;
                      onChanged();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _Num(
                    label: 'Discount %',
                    value: item.discount,
                    clamp: 100,
                    onChanged: (v) {
                      item.discount = v;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Num(
                    label: 'Tax %',
                    value: item.taxRate,
                    clamp: 100,
                    onChanged: (v) {
                      item.taxRate = v;
                      onChanged();
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Line total',
                        style: TextStyle(fontSize: 11, color: c.text3),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formatMoney(item.net, currency),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: c.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------- totals */

class _TotalsCard extends StatelessWidget {
  const _TotalsCard({
    required this.draft,
    required this.totals,
    required this.onChanged,
  });

  final Invoice draft;
  final Totals totals;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    final rows = <_TotalRow>[
      _TotalRow('Subtotal', formatMoney(totals.subtotal, draft.currency)),
      if (totals.discountTotal > 0)
        _TotalRow(
            'Line discounts', '−${formatMoney(totals.discountTotal, draft.currency)}',
            muted: true),
      if (totals.globalDiscount > 0)
        _TotalRow(
            'Global discount (${draft.globalDiscount.toStringAsFixed(0)}%)',
            '−${formatMoney(totals.globalDiscount, draft.currency)}',
            muted: true),
      for (final t in totals.taxes)
        _TotalRow('Tax ${t.rate.toStringAsFixed(0)}%', formatMoney(t.amount, draft.currency)),
      if (totals.shipping > 0)
        _TotalRow('Shipping', formatMoney(totals.shipping, draft.currency)),
    ];

    return SectionCard(
      title: 'Totals',
      child: Column(
        children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Text(
                    r.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: r.muted ? c.text3 : c.text2,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    r.value,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: r.muted ? c.text3 : c.text,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  'Total ${draft.docLabel.toLowerCase()}',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    formatMoney(totals.total, draft.currency),
                    key: ValueKey(totals.total),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: c.accent,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Num(
                  label: 'Global discount %',
                  value: draft.globalDiscount,
                  clamp: 100,
                  onChanged: (v) {
                    draft.globalDiscount = v;
                    onChanged();
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Num(
                  label: 'Shipping',
                  value: draft.shipping,
                  onChanged: (v) {
                    draft.shipping = v;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: draft.template,
                  decoration: const InputDecoration(labelText: 'Template'),
                  items: kTemplates
                      .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    draft.template = v;
                    onChanged();
                    showAppToast(context, 'Template updated - open Preview to see it');
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: draft.currency,
                  decoration: const InputDecoration(labelText: 'Currency'),
                  items: kCurrencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    draft.currency = v;
                    onChanged();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TotalRow {
  final String label;
  final String value;
  final bool muted;
  const _TotalRow(this.label, this.value, {this.muted = false});
}

/* ---------------------------------------------------------------- status */

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.draft, required this.onChanged});

  final Invoice draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Status',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in kStatuses)
            _FilterChip(
              label: s.label,
              selected: draft.status == s.id,
              onTap: () {
                draft.status = s.id;
                onChanged();
                showAppToast(context, 'Status set to ${s.label}');
              },
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return Material(
      color: selected ? c.accent : c.surface2,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? c.onAccent : c.text2,
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------------------------------------------------------------- actions */

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.found,
    required this.saving,
    required this.onSave,
    required this.onDuplicate,
    required this.onDelete,
    required this.onPdf,
  });

  final bool found;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback onPdf;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Actions',
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: saving ? null : onSave,
              icon: saving
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.check, size: 16),
              label: Text(saving ? 'Saving…' : 'Save document'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPdf,
              icon: const Icon(AppIcons.pdf, size: 16),
              label: const Text('Generate PDF'),
            ),
          ),
          if (found) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDuplicate,
                icon: const Icon(AppIcons.copy, size: 16),
                label: const Text('Duplicate'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onDelete,
                icon: const Icon(AppIcons.trash, size: 16),
                style: OutlinedButton.styleFrom(foregroundColor: dangerColor),
                label: const Text('Delete'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------- fields */

class _Text extends StatelessWidget {
  const _Text({
    required this.label,
    required this.value,
    this.hint,
    required this.onChanged,
  });

  final String label;
  final String value;
  final String? hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: value),
      decoration: InputDecoration(labelText: label, hintText: hint),
      onChanged: onChanged,
    );
  }
}

class _Num extends StatelessWidget {
  const _Num({
    required this.label,
    required this.value,
    this.clamp,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double? clamp;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(
        text: value == value.roundToDouble()
            ? value.toInt().toString()
            : value.toStringAsFixed(2),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      onChanged: (raw) {
        final parsed = double.tryParse(raw) ?? 0;
        final v = parsed < 0 ? 0.0 : parsed;
        onChanged(clamp == null ? v : v.clamp(0, clamp!));
      },
    );
  }
}
