"""Generates lib/views/dashboard_screen.dart - statistics, chart, quick actions."""
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

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = Store.instance;
    final stats = store.getStats();
    final series = store.getMonthlySeries(6);
    final recent = store.filterInvoices(sort: 'date-desc').take(5).toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  PageHeader(
                    title: 'Studio overview',
                    subtitle: 'Everything your billing workspace knows today.',
                    action: FilledButton.icon(
                      onPressed: () => context.go('/editor/new'),
                      icon: const Icon(AppIcons.plus, size: 16),
                      label: const Text('New invoice'),
                    ),
                  ),
                  _StatGrid(stats: stats),
                  const SizedBox(height: 16),
                  _RevenueChart(series: series),
                  const SizedBox(height: 24),
                  Text('Quick actions', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  const _QuickActions(),
                  const SizedBox(height: 24),
                  _RecentDocuments(recent: recent),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------------ stats */

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final cards = <_StatCardData>[
      _StatCardData(
        label: 'Total revenue',
        value: formatMoney(stats.totalRevenue),
        sub: '${stats.invoiceCount} documents',
        bar: 1.0,
        tone: null,
      ),
      _StatCardData(
        label: 'Collected',
        value: formatMoney(stats.paid),
        sub: '${stats.paidCount} paid',
        bar: _pct(stats.paid, stats.totalRevenue),
        tone: successColor,
      ),
      _StatCardData(
        label: 'Outstanding',
        value: formatMoney(stats.outstanding),
        sub: '${stats.outstandingCount} open',
        bar: _pct(stats.outstanding, stats.totalRevenue),
        tone: warningColor,
      ),
      _StatCardData(
        label: 'Overdue',
        value: formatMoney(stats.overdue),
        sub: '${stats.overdueCount} late',
        bar: _pct(stats.overdue, stats.totalRevenue),
        tone: dangerColor,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns on phones, four on tablets - no orphan cards.
        final columns = constraints.maxWidth > 560 ? 4 : 2;
        final rows = (cards.length / columns).ceil();
        return Column(
          children: [
            for (int r = 0; r < rows; r++)
              Padding(
                padding: EdgeInsets.only(bottom: r == rows - 1 ? 0 : 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int i = r * columns; i < r * columns + columns; i++)
                      Expanded(
                        child: i < cards.length
                            ? Padding(
                                padding: EdgeInsets.only(
                                    right: i % columns == columns - 1 ? 0 : 10),
                                child: _StatCard(data: cards[i]),
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  double _pct(double part, double whole) => whole > 0 ? part / whole : 0.0;
}

class _StatCardData {
  final String label;
  final String value;
  final String sub;
  final double bar;
  final Color? tone;

  const _StatCardData({
    required this.label,
    required this.value,
    required this.sub,
    required this.bar,
    required this.tone,
  });
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.data});

  final _StatCardData data;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) {
        return Opacity(opacity: v, child: child);
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border, width: 0.6),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  data.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: c.text3,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                if (data.tone != null)
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: data.tone,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              data.value,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: c.text,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              data.sub,
              style: TextStyle(fontSize: 11.5, color: c.text3),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: data.bar.clamp(0.03, 1.0),
                minHeight: 3,
                backgroundColor: c.surface3,
                valueColor: AlwaysStoppedAnimation(data.tone ?? c.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ----------------------------------------------------------------- chart */

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.series});

  final List<MonthPoint> series;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    final max = series.fold<double>(1, (a, b) => b.revenue > a ? b.revenue : a);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Revenue',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Billed per month, all documents',
                    style: TextStyle(fontSize: 11.5, color: c.text3),
                  ),
                ],
              ),
              const Spacer(),
              TextButton(
                onPressed: () => context.go('/invoices'),
                child: const Text('View all'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < series.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: _ChartBar(point: series[i], max: max)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartBar extends StatelessWidget {
  const _ChartBar({required this.point, required this.max});

  final MonthPoint point;
  final double max;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    final has = point.revenue > 0;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (has)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              formatMoneyPlain(point.revenue),
              style: TextStyle(
                fontSize: 9.5,
                color: c.text3,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: has ? (point.revenue / max).clamp(0.05, 1.0) : 0.03),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) {
            return SizedBox(
              height: 78 * v + 3,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: has ? c.accent : c.surface3,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          point.label,
          style: TextStyle(fontSize: 10.5, color: c.text3),
        ),
      ],
    );
  }
}

/* -------------------------------------------------------- quick actions */

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  static const _actions = <_QuickAction>[
    _QuickAction(icon: AppIcons.document, label: 'New invoice', sub: 'Blank document', route: '/editor/new'),
    _QuickAction(icon: AppIcons.templates, label: 'Templates', sub: '10 layouts', route: '/templates'),
    _QuickAction(icon: AppIcons.clients, label: 'Add client', sub: 'Bill someone new', route: '/clients'),
    _QuickAction(icon: AppIcons.services, label: 'Add service', sub: 'Reusable item', route: '/services'),
    _QuickAction(icon: AppIcons.preview, label: 'Preview', sub: 'Current document', route: '/preview'),
    _QuickAction(icon: AppIcons.settings, label: 'Branding', sub: 'Theme and accent', route: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 560 ? 3 : 2;
        return Column(
          children: [
            for (int r = 0; r < (_actions.length / columns).ceil(); r++)
              Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    for (int i = r * columns; i < r * columns + columns; i++)
                      Expanded(
                        child: i < _actions.length
                            ? Padding(
                                padding: EdgeInsets.only(
                                    right: i % columns == columns - 1 ? 0 : 10),
                                child: _QuickActionTile(action: _actions[i]),
                              )
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String sub;
  final String route;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.sub,
    required this.route,
  });
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.go(action.route),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border, width: 0.6),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(action.icon, size: 17, color: c.accent),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      action.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      action.sub,
                      style: TextStyle(fontSize: 11, color: c.text3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ------------------------------------------------------------- recent */

class _RecentDocuments extends StatelessWidget {
  const _RecentDocuments({required this.recent});

  final List<Invoice> recent;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.6),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              children: [
                Text(
                  'Recent documents',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/invoices'),
                  child: const Text('History'),
                ),
              ],
            ),
          ),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text(
                'No documents yet - create your first invoice.',
                style: TextStyle(fontSize: 13),
              ),
            )
          else
            for (final inv in recent) ...[
              hairline(context),
              _RecentRow(invoice: inv),
            ],
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    final due = relativeDue(invoice.dueDate, invoice.status);
    return ListRow(
      onTap: () => context.go('/editor/${invoice.invoiceId}'),
      leading: Avatar(invoice.toName, size: 36),
      child: Meta(
        title: invoice.number,
        subtitle: '${invoice.toName}${invoice.toCompany.isNotEmpty ? ' · ${invoice.toCompany}' : ''}',
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
                            : colors(context).text3,
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
'''


def main() -> None:
    p = Path('lib/views/dashboard_screen.dart')
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(CONTENT, encoding='utf-8')
    back = p.read_text(encoding='utf-8')
    if back != CONTENT:
        raise SystemExit('read-back mismatch')
    print('OK lib/views/dashboard_screen.dart (%d chars)' % len(CONTENT))


if __name__ == '__main__':
    main()
