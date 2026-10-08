library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/format.dart' as fmt;
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
      message: 'This permanently removes the service.',
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
                    title: 'Services',
                    subtitle: 'Reusable line items for quick invoicing',
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
                            'Services are reusable line items. Add one and it becomes selectable in the invoice editor.',
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

  BoxDecoration _cardDecoration(BuildContext context) {
    final c = colors(context);
    return BoxDecoration(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.border, width: 0.6),
    );
  }
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
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Text(
          fmt.initials(service.name)[0],
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.accent),
        ),
      ),
      child: Meta(
        title: service.name,
        subtitle: [service.category, fmt.formatMoney(service.price, 'USD')].where((s) => s.isNotEmpty).join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
  late final TextEditingController _price;
  late final TextEditingController _taxRate;
  late final TextEditingController _category;
  String _unit = 'item';
  String? _error;

  @override
  void initState() {
    super.initState();
    final s = widget.editing;
    _name = TextEditingController(text: s?.name ?? '');
    _description = TextEditingController(text: s?.description ?? '');
    _price = TextEditingController(text: s?.price.toString() ?? '0');
    _taxRate = TextEditingController(text: s?.taxRate.toString() ?? '0');
    _category = TextEditingController(text: s?.category ?? '');
    _unit = s?.unit ?? 'item';
  }

  @override
  void dispose() {
    for (final ctrl in [_name, _description, _price, _taxRate, _category]) {
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
    final price = double.tryParse(_price.text) ?? 0;
    final taxRate = double.tryParse(_taxRate.text) ?? 0;
    final existing = widget.editing;
    final service = existing != null ? existing : Service(name: name);
      service.name = name;
      service.description = _description.text.trim();
      service.price = price;
      service.taxRate = taxRate.clamp(0, 100);
      service.unit = _unit;
      service.category = _category.text.trim();

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
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              _Field(label: 'Name', controller: _name, autoFocus: true),
              const SizedBox(height: 12),
              _Field(label: 'Description', controller: _description, maxLines: 2),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Field(label: 'Price', controller: _price, keyboard: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 12),
                  Expanded(child: _Field(label: 'Tax %', controller: _taxRate, keyboard: const TextInputType.numberWithOptions(decimal: true))),
                ],
              ),
              const SizedBox(height: 12),
              _Field(label: 'Category', controller: _category),
              const SizedBox(height: 12),
              Text('Unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors(context).text3)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ['item', 'hour', 'day', 'project', 'month', 'session', 'page', 'clip', 'pack'].map((u) {
                  final selected = u == _unit;
                  return FilterChip(
                    label: Text(u),
                    selected: selected,
                    onSelected: (_) => setState(() => _unit = u),
                    backgroundColor: colors(context).surface2,
                    selectedColor: colors(context).accent.withValues(alpha: 0.15),
                    checkmarkColor: colors(context).accent,
                  );
                }).toList(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: const TextStyle(fontSize: 12.5, color: dangerColor)),
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
