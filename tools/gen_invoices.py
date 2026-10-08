"""Generates lib/views/invoices_screen.dart - history with search/filter/sort."""
from pathlib import Path

CONTENT = r'''library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../ui/kit.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late final Store _store;
  String _query = '';
  String _status = 'all';
  String _type = 'all';
  String _sort = 'date-desc';
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _store = Store.instance;
    _store.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() => _dirty = !_dirty);
  }

  @override
  void dispose() {
    _store.removeListener(_onChanged);
    super.dispose();
  }

  List<Invoice> get _filtered => _store.filterInvoices(
        search: _query,
        status: _status,
        clientId: 'all',
        sort: _sort,
      );

  Future<void> _changeStatus(Invoice inv) async {
    final next = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => _StatusSheet(status: inv.status),
    );
    if (next == null || next == inv.status || !mounted) return;
    await _store.updateInvoiceStatus(inv.invoiceId, next);
    if (mounted) {
      showAppToast(context, 'Status changed to ${statusLabel(next)}', success: true);
    }
  }

  Future<void> _duplicate(Invoice inv) async {
    final copy = await _store.duplicateInvoice(inv.invoiceId);
    if (copy == null || !mounted) return;
    showAppToast(context, 'Duplicated as ${copy.number}', success: true);
    if (mounted) context.go('/editor/${copy.invoiceId}');
  }

  Future<void> _delete(Invoice inv) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete this document?',
      message:
          'This permanently removes ${inv.number}. Generated PDFs in the Documents vault are kept.',
    );
    if (!ok || !mounted) return;
    await _store.deleteInvoice(inv.invoiceId);
    if (mounted) showAppToast(context, '${inv.number} deleted');
  }

  @override
  Widget build(BuildContext context) {
    final stats = _store.getStats();
    final items = _filtered;
    final filtering = _query.isNotEmpty || _status != 'all' || _type != 'all';

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  PageHeader(
                    title: 'Invoice history',
                    subtitle:
                        '${stats.invoiceCount} documents · ${formatMoney(stats.outstanding)} outstanding',
                    action: FilledButton.icon(
                      onPressed: () => context.go('/editor/new'),
                      icon: const Icon(AppIcons.plus, size: 16),
                      label: const Text('New'),
                    ),
                  ),
                  // search
                  SearchField(
                    value: _query,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 12),
                  // type segmented + sort
                  Row(
                    children: [
                      Segmented(
                        segments: const ['All', 'invoice', 'quotation'],
                        selected: _type == 'all' ? 'All' : _type,
                        onChanged: (v) => setState(() {
                          _type = v == 'All' ? 'all' : v;
                        }),
                      ),
                      const Spacer(),
                      SortMenu(value: _sort, onChanged: (v) => setState(() => _sort = v)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // status chips
                  SizedBox(
                    height: 34,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final s in [
                          const _Chip('all', 'All'),
                          ...kStatuses.map((s) => _Chip(s.id, s.label)),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _FilterChip(
                              label: s.label,
                              selected: _status == s.id,
                              onTap: () => setState(() => _status = s.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (items.isEmpty)
                    Container(
                      decoration: _cardDecoration(context),
                      child: EmptyState(
                        title: filtering ? 'No matches' : 'No invoices yet',
                        message: filtering
                            ? 'Try a different search term or clear the filters.'
                            : 'Create your first invoice and it will appear here.',
                        actionLabel: filtering ? 'Clear filters' : 'New invoice',
                        onAction: filtering
                            ? () => setState(() {
                                  _query = '';
                                  _status = 'all';
                                  _type = 'all';
                                })
                            : () => context.go('/editor/new'),
                        icon: AppIcons.invoices,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: _cardDecoration(context),
                      child: Column(
                        children: [
                          for (final inv in items) ...[
                            hairline(context),
                            _InvoiceRow(
                              invoice: inv,
                              onOpen: () =>
                                  context.go('/editor/${inv.invoiceId}'),
                              onStatus: () => _changeStatus(inv),
                              onDuplicate: () => _duplicate(inv),
                              onDelete: () => _delete(inv),
                            ),
                          ],
                        ],
                      ),
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

BoxDecoration _cardDecoration(BuildContext context) {
  final c = colors(context);
  return BoxDecoration(
    color: c.surface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: c.border, width: 0.6),
  );
}

class _Chip {
  final String id;
  final String label;
  const _Chip(this.id, this.label);
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

/* ------------------------------------------------------------------ rows */

class _InvoiceRow extends StatelessWidget {
  const _InvoiceRow({
    required this.invoice,
    required this.onOpen,
    required this.onStatus,
    required this.onDuplicate,
    required this.onDelete,
  });

  final Invoice invoice;
  final VoidCallback onOpen;
  final VoidCallback onStatus;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    final due = relativeDue(invoice.dueDate, invoice.status);
    return ListRow(
      onTap: onOpen,
      leading: Avatar(invoice.toName, size: 38),
      child: Meta(
        title: invoice.number,
        subtitle:
            '${invoice.toName}${invoice.toCompany.isNotEmpty ? ' · ${invoice.toCompany}' : ''}',
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyText(invoiceAggregate(invoice), currency: invoice.currency),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (invoice.isQuotation) ...[
                const Tag('Quote'),
                const SizedBox(width: 6),
              ],
              StatusPill(invoice.status, compact: true),
              if (due != null) ...[
                const SizedBox(width: 6),
                Text(
                  due.label,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: due.tone == DueTone.danger
                        ? dangerColor
                        : due.tone == DueTone.warning
                            ? warningColor
                            : c.text3,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/* ---------------------------------------------------------------- search */

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return TextField(
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search number, client, item…',
        prefixIcon: Icon(AppIcons.search, size: 18, color: c.text3),
        suffixIcon: value.isNotEmpty
            ? IconButton(
                onPressed: () => onChanged(''),
                icon: Icon(AppIcons.close, size: 17, color: c.text3),
                visualDensity: VisualDensity.compact,
              )
            : null,
      ),
    );
  }
}

/* ------------------------------------------------------------------ sort */

class SortMenu extends StatelessWidget {
  const SortMenu({super.key, required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  static const _options = <DropdownMenuItem<String>>[
    DropdownMenuItem(value: 'date-desc', child: Text('Newest first')),
    DropdownMenuItem(value: 'date-asc', child: Text('Oldest first')),
    DropdownMenuItem(value: 'amount-desc', child: Text('Amount: high→low')),
    DropdownMenuItem(value: 'amount-asc', child: Text('Amount: low→high')),
    DropdownMenuItem(value: 'number-asc', child: Text('Number A→Z')),
  ];

  @override
  Widget build(BuildContext context) {
    return DropdownButton<String>(
      value: value,
      items: _options,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      underline: const SizedBox.shrink(),
      isDense: true,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w500,
        color: colors(context).text2,
      ),
    );
  }
}

/* ---------------------------------------------------------- status sheet */

class _StatusSheet extends StatelessWidget {
  const _StatusSheet({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Change status',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors(context).text,
              ),
            ),
            const SizedBox(height: 12),
            for (final s in kStatuses) ...[
              hairline(context),
              ListRow(
                onTap: () => Navigator.pop(context, s.id),
                leading: StatusPill(s.id),
                child: Meta(title: statusHint(s.id)),
                trailing: s.id == status
                    ? Icon(AppIcons.check, size: 18, color: colors(context).accent)
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
'''


def main() -> None:
    p = Path('lib/views/invoices_screen.dart')
    p.write_text(CONTENT, encoding='utf-8')
    back = p.read_text(encoding='utf-8')
    if back != CONTENT:
        raise SystemExit('read-back mismatch')
    print('OK lib/views/invoices_screen.dart (%d chars)' % len(CONTENT))


if __name__ == '__main__':
    main()
