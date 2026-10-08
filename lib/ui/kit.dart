library;

/// ICON Billing Studio - shared presentational widgets.
///
/// Ported from the web prototype's js/ui/kit.js and js/ui/overlays.js: status
/// pills, avatars, empty states, section cards, list rows, money display.

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../core/format.dart';
import '../core/theme.dart';

/* ------------------------------------------------------------------ icons */

/// Line icons matching the prototype's stroke set.
class AppIcons {
  static const dashboard = Icons.dashboard_outlined;
  static const invoices = Icons.description_outlined;
  static const clients = Icons.people_outline;
  static const services = Icons.inventory_2_outlined;
  static const templates = Icons.dashboard_customize_outlined;
  static const preview = Icons.visibility_outlined;
  static const settings = Icons.settings_outlined;
  static const documents = Icons.folder_open_outlined;
  static const plus = Icons.add_rounded;
  static const search = Icons.search_rounded;
  static const trash = Icons.delete_outline_rounded;
  static const copy = Icons.copy_outlined;
  static const edit = Icons.edit_outlined;
  static const send = Icons.send_outlined;
  static const check = Icons.check_rounded;
  static const back = Icons.arrow_back_rounded;
  static const print = Icons.print_outlined;
  static const download = Icons.download_rounded;
  static const share = Icons.ios_share_rounded;
  static const chevron = Icons.chevron_right_rounded;
  static const more = Icons.more_horiz_rounded;
  static const document = Icons.insert_drive_file_outlined;
  static const wallet = Icons.account_balance_wallet_outlined;
  static const clock = Icons.access_time_rounded;
  static const close = Icons.close_rounded;
  static const palette = Icons.palette_outlined;
  static const sparkles = Icons.auto_awesome_outlined;
  static const pdf = Icons.picture_as_pdf_outlined;
  static const save = Icons.save_alt_rounded;
  static const open = Icons.open_in_new_rounded;
}

/* ----------------------------------------------------------------- pills */

/// Coloured status chip with a dot, mirroring statusPill().
class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final def = statusById(status);
    final c = colors(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: Color(def.color).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Color(def.color),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            def.label,
            style: TextStyle(
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w600,
              color: Color(def.color),
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small neutral chip used for document kinds and counts.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.tone, this.compact = true});

  final String label;
  final Color? tone;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    final fill = tone ?? c.surface3;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 9,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: tone != null ? tone!.withValues(alpha: 0.12) : fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: compact ? 10.5 : 11.5,
          fontWeight: FontWeight.w600,
          color: tone != null ? tone : c.text2,
        ),
      ),
    );
  }
}

/* --------------------------------------------------------------- avatar */

/// Round initials avatar, mirroring avatar().
class Avatar extends StatelessWidget {
  const Avatar(
    this.name, {
    super.key,
    this.size = 38,
    this.radius,
    this.accent,
  });

  final String name;
  final double size;
  final double? radius;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    final base = accent ?? c.accent;
    final text = initials(name);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: base.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(radius ?? size / 2),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          color: base,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------------- card */

/// Section container used across every screen.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.trailing,
    required this.child,
    this.padding,
  });

  final String title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.6),
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.text3,
                    letterSpacing: 0.6,
                  ),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------ empty state */

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.body,
    this.action,
    this.backgroundColor,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;

  /// Alias for [message], used by screens written against the web prototype.
  final String? body;
  final Widget? action;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: c.surface2,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon ?? AppIcons.document,
              size: 26,
              color: c.text3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: c.text3,
              height: 1.5,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: Icon(AppIcons.plus, size: 16),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------ list row */

/// Tappable row used by every list in the app.
class ListRow extends StatelessWidget {
  const ListRow({
    super.key,
    required this.child,
    this.onTap,
    this.leading,
    this.trailing,
    this.showDivider = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Widget? leading;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(child: child),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Meta block used inside list rows: a bold title and a muted subtitle.
class Meta extends StatelessWidget {
  const Meta({super.key, required this.title, this.subtitle, this.crossAxisAlignment});

  final String title;
  final String? subtitle;
  final CrossAxisAlignment? crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return Column(
      crossAxisAlignment: crossAxisAlignment ?? CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: c.text,
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: c.text3, height: 1.35),
          ),
        ],
      ],
    );
  }
}

/* --------------------------------------------------------------- money */

/// Right-aligned amount with the currency symbol muted.
class MoneyText extends StatelessWidget {
  const MoneyText(
    this.value, {
    super.key,
    this.currency = 'USD',
    this.style,
    this.align = TextAlign.right,
  });

  final double value;
  final String currency;
  final TextStyle? style;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return Text(
      formatMoney(value, currency),
      textAlign: align,
      style: (style ?? TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text))
          .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}

/* ------------------------------------------------------------ page header */

/// Screen title + optional action, mirroring .page-header.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null) ...[
            IconButton(
              onPressed: onBack,
              icon: Icon(AppIcons.back, size: 20),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                    height: 1.15,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 12.5, color: c.text3, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/* ------------------------------------------------------------ segmented */

/// Segmented control used for the invoice/quotation filter.
class Segmented extends StatefulWidget {
  const Segmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final List<String> segments;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  State<Segmented> createState() => _SegmentedState();
}

class _SegmentedState extends State<Segmented> {
  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return Container(
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in widget.segments)
            GestureDetector(
              onTap: () => widget.onChanged(s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: widget.selected == s
                      ? c.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: widget.selected == s
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  s,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: widget.selected == s ? FontWeight.w600 : FontWeight.w500,
                    color: widget.selected == s ? c.text : c.text3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/* --------------------------------------------------------- confirm dialog */

/// Danger confirmation for destructive actions.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
  bool danger = true,
}) async {
  final c = colors(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: danger ? dangerColor : c.accent,
            foregroundColor: danger ? Colors.white : c.onAccent,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Success feedback, mirroring toast().
void showAppToast(BuildContext context, String message, {bool success = false, bool error = false}) {
  final c = colors(context);
  final color = success ? successColor : error ? dangerColor : c.text2;
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          Icon(
            success ? AppIcons.check : error ? AppIcons.close : AppIcons.sparkles,
            size: 17,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
        ],
      ),
      duration: const Duration(milliseconds: 3200),
    ),
  );
}

/// Thin full-width divider used inside cards.
Widget hairline(BuildContext context) => Divider(
      height: 1,
      thickness: 0.6,
      color: colors(context).border,
    );
