"""Generates lib/views/settings_screen.dart - business profile, appearance, data."""
from pathlib import Path

CONTENT = r'''library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../core/constants.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../ui/kit.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final Store _store;
  bool _resetting = false;

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

  Future<void> _export() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/icon-billing-backup.json');
      final payload = const JsonEncoder.withIndent('  ').convert(_store.exportData());
      await file.writeAsString(payload);
      if (!mounted) return;
      showAppToast(context, 'Backup written: ${file.path}', success: true);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Export failed: $e', error: true);
    }
  }

  Future<void> _confirmReset() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Reset demo data?',
      message:
          'This replaces all clients, services, invoices and generated PDFs with the original demo content.',
      confirmLabel: 'Reset',
    );
    if (!ok || !mounted) return;
    setState(() => _resetting = true);
    await _store.seed();
    setState(() => _resetting = false);
    if (!mounted) return;
    showAppToast(context, 'Demo data restored', success: true);
  }

  @override
  Widget build(BuildContext context) {
    final settings = _store.settings;
    final business = _store.business;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const PageHeader(
                    title: 'Settings',
                    subtitle: 'Business profile, appearance and data.',
                  ),
                  _AppearanceSection(store: _store, settings: settings),
                  const SizedBox(height: 14),
                  _BusinessSection(store: _store, business: business),
                  const SizedBox(height: 14),
                  _NumberingSection(store: _store, settings: settings),
                  const SizedBox(height: 14),
                  _DataSection(
                    onExport: _export,
                    onReset: _confirmReset,
                    resetting: _resetting,
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Text(
                      '${AppMeta.name} · offline-first',
                      style: TextStyle(fontSize: 11.5, color: colors(context).text3),
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

/* ------------------------------------------------------------- appearance */

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.store, required this.settings});

  final Store store;
  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Appearance',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors(context).text2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final t in const [('dark', 'Dark'), ('light', 'Light')])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _ThemeChip(
                    label: t.$2,
                    selected: settings.theme == t.$1,
                    onTap: () => store.setTheme(t.$1),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Accent colour',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors(context).text2,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final a in kAccents)
                _AccentSwatch(
                  name: a.name,
                  color: Color(a.a),
                  selected: settings.accentId == a.id,
                  onTap: () => store.setAccent(a.id),
                ),
              _AccentSwatch(
                name: 'Custom',
                color: settings.customAccent != null
                    ? Color(settings.customAccent!)
                    : colors(context).text3,
                selected: settings.accentId == 'custom',
                onTap: () async {
                  final picked = await _pickCustomColor(context);
                  if (picked == null) return;
                  await store.setAccent('custom', picked);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<int?> _pickCustomColor(BuildContext context) async {
    Color chosen = Color(store.accent.a);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Custom accent'),
          content: SingleChildScrollView(
            child: ColorPicker(changed: (c) => chosen = c),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    return ok == true ? chosen.toARGB32() : null;
  }
}

class _ThemeChip extends StatelessWidget {
  const _ThemeChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return Material(
      color: selected ? c.accent : c.surface2,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? c.onAccent : c.text2,
            ),
          ),
        ),
      ),
    );
  }
}

class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.name,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? c.text : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: selected
              ? Icon(
                  AppIcons.check,
                  size: 18,
                  color: onAccentOf(color),
                )
              : null,
        ),
      ),
    );
  }
}

/// Compact hue+saturation picker built from primitives (no extra dependency).
class ColorPicker extends StatefulWidget {
  const ColorPicker({super.key, required this.changed});

  final ValueChanged<Color> changed;

  @override
  State<ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<ColorPicker> {
  double _hue = 270;
  double _sat = 0.65;
  double _val = 0.65;

  Color get _color => HSLColor.fromAHSL(1, _hue, _sat, _val).toColor();

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: _color,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            '#${_color.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors._onColor(_color),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Slider(
          label: 'Hue',
          min: 0,
          max: 360,
          value: _hue,
          color: HSLColor.fromAHSL(1, _hue, 1, 0.5).toColor(),
          onChanged: (v) => setState(() {
            _hue = v;
            widget.changed(_color);
          }),
        ),
        _Slider(
          label: 'Saturation',
          min: 0,
          max: 1,
          value: _sat,
          color: _color,
          onChanged: (v) => setState(() {
            _sat = v;
            widget.changed(_color);
          }),
        ),
        _Slider(
          label: 'Lightness',
          min: 0.1,
          max: 0.9,
          value: _val,
          color: _color,
          onChanged: (v) => setState(() {
            _val = v;
            widget.changed(_color);
          }),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in const [
              0xFF6B21A8, 0xFF1A2744, 0xFFB8860B, 0xFF059669, 0xFFDC2626,
              0xFF2563EB, 0xFF0D9488, 0xFFE11D48, 0xFF475569, 0xFFEA580C,
            ])
              GestureDetector(
                onTap: () {
                  final hsl = HSLColor.fromColor(Color(preset));
                  setState(() {
                    _hue = hsl.hue;
                    _sat = hsl.saturation;
                    _val = hsl.lightness;
                  });
                  widget.changed(Color(preset));
                },
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: Color(preset),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.min,
    required this.max,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final double min;
  final double max;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(label, style: TextStyle(fontSize: 12, color: colors(context).text3)),
        ),
        Expanded(
          child: Slider(
            min: min,
            max: max,
            value: value,
            activeColor: color,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/* ------------------------------------------------------------- business */

class _BusinessSection extends StatefulWidget {
  const _BusinessSection({required this.store, required this.business});

  final Store store;
  final Business business;

  @override
  State<_BusinessSection> createState() => _BusinessSectionState();
}

class _BusinessSectionState extends State<_BusinessSection> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _taxId;
  late final TextEditingController _bankName;
  late final TextEditingController _bankAccount;
  late final TextEditingController _swift;

  @override
  void initState() {
    super.initState();
    final b = widget.business;
    _name = TextEditingController(text: b.name);
    _email = TextEditingController(text: b.email);
    _phone = TextEditingController(text: b.phone);
    _address = TextEditingController(text: b.addressLine);
    _city = TextEditingController(text: b.city);
    _country = TextEditingController(text: b.country);
    _taxId = TextEditingController(text: b.taxId);
    _bankName = TextEditingController(text: b.bankName);
    _bankAccount = TextEditingController(text: b.bankAccount);
    _swift = TextEditingController(text: b.swift);
  }

  @override
  void dispose() {
    for (final c in [
      _name, _email, _phone, _address, _city, _country, _taxId, _bankName,
      _bankAccount, _swift
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final next = widget.business.copy()
      ..name = _name.text.trim()
      ..email = _email.text.trim()
      ..phone = _phone.text.trim()
      ..addressLine = _address.text.trim()
      ..city = _city.text.trim()
      ..country = _country.text.trim()
      ..taxId = _taxId.text.trim()
      ..bankName = _bankName.text.trim()
      ..bankAccount = _bankAccount.text.trim()
      ..swift = _swift.text.trim();
    await widget.store.updateBusiness(next);
    if (!mounted) return;
    showAppToast(context, 'Business profile saved', success: true);
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Business profile',
      child: Column(
        children: [
          _Row(label: 'Business name', controller: _name),
          const SizedBox(height: 12),
          _Row(
            label: 'Email',
            controller: _email,
            keyboard: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          _Row(label: 'Phone', controller: _phone, keyboard: TextInputType.phone),
          const SizedBox(height: 12),
          _Row(label: 'Address line', controller: _address),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Row(label: 'City', controller: _city)),
              const SizedBox(width: 12),
              Expanded(child: _Row(label: 'Country', controller: _country)),
            ],
          ),
          const SizedBox(height: 12),
          _Row(label: 'Tax ID', controller: _taxId),
          const SizedBox(height: 16),
          Text(
            'Bank details (prefill payment information)',
            style: TextStyle(fontSize: 12, color: colors(context).text3),
          ),
          const SizedBox(height: 10),
          _Row(label: 'Bank name', controller: _bankName),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Row(label: 'Account', controller: _bankAccount)),
              const SizedBox(width: 12),
              Expanded(child: _Row(label: 'SWIFT', controller: _swift)),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _save,
              child: const Text('Save business profile'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.controller, this.keyboard});

  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
    );
  }
}

/* ------------------------------------------------------------- numbering */

class _NumberingSection extends StatefulWidget {
  const _NumberingSection({required this.store, required this.settings});

  final Store store;
  final AppSettings settings;

  @override
  State<_NumberingSection> createState() => _NumberingSectionState();
}

class _NumberingSectionState extends State<_NumberingSection> {
  late final TextEditingController _invoicePrefix;
  late final TextEditingController _quotePrefix;

  @override
  void initState() {
    super.initState();
    _invoicePrefix = TextEditingController(text: widget.settings.prefixInvoice);
    _quotePrefix = TextEditingController(text: widget.settings.prefixQuotation);
  }

  @override
  void dispose() {
    _invoicePrefix.dispose();
    _quotePrefix.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return SectionCard(
      title: 'Numbering & currency',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _invoicePrefix,
                  decoration: InputDecoration(
                    labelText: 'Invoice prefix',
                    counterText: '',
                  ),
                  maxLength: 6,
                  onChanged: (v) => settings.prefixInvoice = v.toUpperCase(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _quotePrefix,
                  decoration: InputDecoration(
                    labelText: 'Quotation prefix',
                    counterText: '',
                  ),
                  maxLength: 6,
                  onChanged: (v) => settings.prefixQuotation = v.toUpperCase(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: settings.currency,
                  decoration: const InputDecoration(labelText: 'Default currency'),
                  items: kCurrencies
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    settings.currency = v;
                    await settings.persist();
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: settings.activeTemplate,
                  decoration: const InputDecoration(labelText: 'Default template'),
                  items: kTemplates
                      .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
                      .toList(),
                  onChanged: (v) async {
                    if (v == null) return;
                    await widget.store.setActiveTemplate(v);
                    setState(() {});
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

/* ------------------------------------------------------------------- data */

class _DataSection extends StatelessWidget {
  const _DataSection({
    required this.onExport,
    required this.onReset,
    required this.resetting,
  });

  final VoidCallback onExport;
  final VoidCallback onReset;
  final bool resetting;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Data management',
      child: Column(
        children: [
          Text(
            'Everything is stored on this device. Export a JSON backup before clearing app data.',
            style: TextStyle(fontSize: 12.5, color: colors(context).text3, height: 1.45),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onExport,
              icon: const Icon(AppIcons.download, size: 16),
              label: const Text('Export JSON backup'),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: resetting ? null : onReset,
              icon: resetting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.sparkles, size: 16),
              style: OutlinedButton.styleFrom(foregroundColor: warningColor),
              label: Text(resetting ? 'Resetting…' : 'Reset demo data'),
            ),
          ),
        ],
      ),
    );
  }
}
'''


def main() -> None:
    p = Path('lib/views/settings_screen.dart')
    p.write_text(CONTENT, encoding='utf-8')
    back = p.read_text(encoding='utf-8')
    if back != CONTENT:
        raise SystemExit('read-back mismatch')
    print('OK lib/views/settings_screen.dart (%d chars)' % len(CONTENT))


if __name__ == '__main__':
    main()
