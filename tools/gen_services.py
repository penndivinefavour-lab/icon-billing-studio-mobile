"""Generates lib/views/services_screen.dart - product/service management."""
from pathlib import Path

CONTENT = r'''library;

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../ui/kit.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  late final Store _store;

  @override
  void initState() {
    super.initState();
    _store = Store.instance;
    _store.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _store.removeListener(_onChanged);
    super.dispose();
  }

  Future<void> _openForm([Service? existing]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ServiceForm(store: _store, editing: existing),
    );
  }

  Future<void> _confirmDelete(Service service) async {
    final ok = await showConfirmDialog(
      context,
      title: 'Delete ${service.name}?',
      message: 'Existing invoices keep their own line-item copies, so nothing changes on them.',
    );
    if (!ok || !mounted) return;
    await _store.deleteService(service.serviceId);
    if (mounted) showAppToast(context, '${service.name} deleted');
  }

  @override
  Widget build(BuildContext context) {
    final services = _store.services;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  PageHeader(
                    title: 'Products & services',
                    subtitle: '${services.length} saved · reusable line items for any invoice',
                    action: FilledButton.icon(
                      onPressed: () => _openForm(),
                      icon: const Icon(AppIcons.plus, size: 16),
                      label: const Text('Add service'),
                    ),
                  ),
                  if (services.isEmpty)
                    Container(
                      decoration: _cardDecoration(context),
                      child: EmptyState(
                        title: 'No services yet',
                        message:
                            'Create a service once and insert it into any invoice straight from the editor.',
                        actionLabel: 'Add service',
                        onAction: () => _openForm(),
                        icon: AppIcons.services,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: _cardDecoration(context),
                      child: Column(
                        children: [
                          for (final s in services) ...[
                            hairline(context),
                            _ServiceRow(
                              service: s,
                              onEdit: () => _openForm(s),
                              onDelete: () => _confirmDelete(s),
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

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.onEdit,
    required this.onDelete,
  });

  final Service service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return ListRow(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Icon(AppIcons.services, size: 17, color: c.accent),
      ),
      child: Meta(
        title: service.name,
        subtitle: service.description.isNotEmpty
            ? service.description
            : '${service.unit} · ${formatMoney(service.price)}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (service.category.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tag(service.category),
            ),
          MoneyText(service.price),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(AppIcons.edit, size: 17),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(AppIcons.trash, size: 17),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------------ form */

class _ServiceForm extends StatefulWidget {
  const _ServiceForm({required this.store, this.editing});

  final Store store;
  final Service? editing;

  @override
  State<_ServiceForm> createState() => _ServiceFormState();
}

class _ServiceFormState extends State<_ServiceForm> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _unit;
  late final TextEditingController _price;
  late final TextEditingController _tax;
  late final TextEditingController _category;
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.editing;
    _name = TextEditingController(text: s?.name ?? '');
    _description = TextEditingController(text: s?.description ?? '');
    _unit = TextEditingController(text: s?.unit ?? 'item');
    _price = TextEditingController(
        text: s != null && s.price != 0 ? s.price.toStringAsFixed(2) : '');
    _tax = TextEditingController(
        text: s != null && s.taxRate != 0 ? s.taxRate.toStringAsFixed(0) : '0');
    _category = TextEditingController(text: s?.category ?? '');
  }

  @override
  void dispose() {
    for (final ctrl in [_name, _description, _unit, _price, _tax, _category]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'A service needs a name.');
      return;
    }
    final price = double.tryParse(_price.text.trim()) ?? 0;
    if (price < 0) {
      setState(() => _error = 'Price cannot be negative.');
      return;
    }
    final existing = widget.editing;
    final service = (existing ?? Service(name: name))
      ..name = name
      ..description = _description.text.trim()
      ..unit = _unit.text.trim().isEmpty ? 'item' : _unit.text.trim()
      ..price = price
      ..taxRate = (double.tryParse(_tax.text.trim()) ?? 0).clamp(0, 100)
      ..category = _category.text.trim();

    await widget.store.upsertService(service);
    if (!mounted) return;
    Navigator.pop(context);
    showAppToast(
      context,
      existing == null ? 'Service ${service.name} created' : 'Service updated',
      success: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.editing == null ? 'New service' : 'Edit service',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors(context).text,
                ),
              ),
              const SizedBox(height: 16),
              _Field(label: 'Name', controller: _name, autoFocus: true),
              const SizedBox(height: 12),
              _Field(label: 'Description', controller: _description, maxLines: 2),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Field(label: 'Unit', controller: _unit)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      label: 'Unit price',
                      controller: _price,
                      keyboard: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      label: 'Tax rate %',
                      controller: _tax,
                      keyboard: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _Field(label: 'Category', controller: _category)),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: const TextStyle(fontSize: 12.5, color: dangerColor),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: Text(widget.editing == null ? 'Add service' : 'Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.keyboard,
    this.maxLines = 1,
    this.autoFocus = false,
  });

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;
  final int maxLines;
  final bool autoFocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      autofocus: autoFocus,
      decoration: InputDecoration(
        labelText: label,
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}
'''


def main() -> None:
    p = Path('lib/views/services_screen.dart')
    p.write_text(CONTENT, encoding='utf-8')
    back = p.read_text(encoding='utf-8')
    if back != CONTENT:
        raise SystemExit('read-back mismatch')
    print('OK lib/views/services_screen.dart (%d chars)' % len(CONTENT))


if __name__ == '__main__':
    main()
