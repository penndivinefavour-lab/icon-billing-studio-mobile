library;

import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../ui/kit.dart';

class ClientsScreen extends StatefulWidget {
  const ClientsScreen({super.key});

  @override
  State<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends State<ClientsScreen> {
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

  Future<void> _openForm([Client? existing]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ClientForm(store: _store, editing: existing),
    );
  }

  Future<void> _confirmDelete(Client client) async {
    final used = _store
        .filterInvoices(clientId: client.clientId)
        .length;
    if (used > 0) {
      showAppToast(
        context,
        'Client is used by $used document${used == 1 ? '' : 's'} - remove those first',
        error: true,
      );
      return;
    }
    final ok = await showConfirmDialog(
      context,
      title: 'Delete ${client.name}?',
      message: 'This permanently removes the client.',
    );
    if (!ok || !mounted) return;
    await _store.deleteClient(client.clientId);
    if (mounted) showAppToast(context, '${client.name} deleted');
  }

  @override
  Widget build(BuildContext context) {
    final clients = _store.clients;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  PageHeader(
                    title: 'Clients',
                    subtitle: '${clients.length} saved · selectable from the invoice editor',
                    action: FilledButton.icon(
                      onPressed: () => _openForm(),
                      icon: const Icon(AppIcons.plus, size: 16),
                      label: const Text('Add client'),
                    ),
                  ),
                  if (clients.isEmpty)
                    Container(
                      decoration: _cardDecoration(context),
                      child: EmptyState(
                        title: 'No clients yet',
                        message:
                            'Clients you bill repeatedly. Add one and it becomes selectable in the invoice editor.',
                        actionLabel: 'Add client',
                        onAction: () => _openForm(),
                        icon: AppIcons.clients,
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: _cardDecoration(context),
                      child: Column(
                        children: [
                          for (final c in clients) ...[
                            hairline(context),
                            _ClientRow(
                              client: c,
                              used: _store
                                  .filterInvoices(clientId: c.clientId)
                                  .length,
                              onEdit: () => _openForm(c),
                              onDelete: () => _confirmDelete(c),
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

class _ClientRow extends StatelessWidget {
  const _ClientRow({
    required this.client,
    required this.used,
    required this.onEdit,
    required this.onDelete,
  });

  final Client client;
  final int used;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final location = [
      client.city,
      client.country,
    ].where((s) => s.isNotEmpty).join(', ');
    return ListRow(
      leading: Avatar(client.name, size: 38),
      child: Meta(
        title: client.name,
        subtitle: [client.company, client.email].where((s) => s.isNotEmpty).join(' · '),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (location.isNotEmpty || used > 0)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Text(
                location.isNotEmpty
                    ? '$location · $used doc${used == 1 ? '' : 's'}'
                    : '$used doc${used == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 11, color: colors(context).text3),
              ),
            ),
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

class _ClientForm extends StatefulWidget {
  const _ClientForm({required this.store, this.editing});

  final Store store;
  final Client? editing;

  @override
  State<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<_ClientForm> {
  late final TextEditingController _name;
  late final TextEditingController _company;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _notes;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.editing;
    _name = TextEditingController(text: c?.name ?? '');
    _company = TextEditingController(text: c?.company ?? '');
    _email = TextEditingController(text: c?.email ?? '');
    _phone = TextEditingController(text: c?.phone ?? '');
    _address = TextEditingController(text: c?.addressLine ?? '');
    _city = TextEditingController(text: c?.city ?? '');
    _country = TextEditingController(text: c?.country ?? '');
    _notes = TextEditingController(text: c?.notes ?? '');
  }

  @override
  void dispose() {
    for (final ctrl in [
      _name,
      _company,
      _email,
      _phone,
      _address,
      _city,
      _country,
      _notes,
    ]) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'A client needs a name.');
      return;
    }
    final existing = widget.editing;
    final client = (existing ?? Client(name: name)).copy()
      ..name = name
      ..company = _company.text.trim()
      ..email = _email.text.trim()
      ..phone = _phone.text.trim()
      ..addressLine = _address.text.trim()
      ..city = _city.text.trim()
      ..country = _country.text.trim()
      ..notes = _notes.text.trim();

    await widget.store.upsertClient(client);
    if (!mounted) return;
    Navigator.pop(context);
    showAppToast(
      context,
      existing == null ? 'Client ${client.name} created' : 'Client updated',
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
                widget.editing == null ? 'New client' : 'Edit client',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: colors(context).text,
                ),
              ),
              const SizedBox(height: 16),
              _Field(label: 'Name', controller: _name, autoFocus: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Field(label: 'Company', controller: _company)),
                  const SizedBox(width: 12),
                  Expanded(child: _Field(label: 'Email', controller: _email, keyboard: TextInputType.emailAddress)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Field(label: 'Phone', controller: _phone, keyboard: TextInputType.phone)),
                  const SizedBox(width: 12),
                  Expanded(child: _Field(label: 'City', controller: _city)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _Field(label: 'Address', controller: _address)),
                  const SizedBox(width: 12),
                  Expanded(child: _Field(label: 'Country', controller: _country)),
                ],
              ),
              const SizedBox(height: 12),
              _Field(label: 'Notes', controller: _notes, maxLines: 2),
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
                  child: Text(widget.editing == null ? 'Add client' : 'Save changes'),
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
