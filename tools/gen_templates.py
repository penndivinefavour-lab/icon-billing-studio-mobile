"""Generates lib/views/templates_screen.dart - the ten-template gallery."""
from pathlib import Path

CONTENT = r'''library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../core/seed.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../ui/kit.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final samples = seedTemplateSamples();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const PageHeader(
                    title: 'Template gallery',
                    subtitle: 'Ten distinct layouts. Open one, edit everything, save it as a real invoice.',
                  ),
                  for (final entry in samples.entries) ...[
                    _TemplateCard(
                      id: entry.key,
                      sample: entry.value,
                      onOpen: () {
                        Store.instance.offerTemplateSample(entry.value.copy());
                        context.go('/editor/template');
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.id, required this.sample, required this.onOpen});

  final String id;
  final Invoice sample;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    final def = templateById(id);
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border, width: 0.6),
          ),
          child: Row(
            children: [
              // Miniature preview: a scaled-down rendering of the template's
              // signature header block, drawn from the sample accent.
              _TemplateThumb(templateId: id, accent: sample.accent),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          def.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tag(def.category, tone: c.accent),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      def.blurb,
                      style: TextStyle(fontSize: 12.5, color: c.text3, height: 1.4),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '${sample.items.length} sample items · ${sample.totals.total.toStringAsFixed(0)} ${sample.currency}',
                          style: TextStyle(fontSize: 11.5, color: c.text3),
                        ),
                        const Spacer(),
                        const Icon(AppIcons.chevron, size: 17),
                      ],
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

/// A small abstract representation of each template's header structure.
/// Deliberately schematic - it signals the layout family rather than
/// reproducing the full invoice, which lives in the PDF painter.
class _TemplateThumb extends StatelessWidget {
  const _TemplateThumb({required this.templateId, required this.accent});

  final String templateId;
  final String accent;

  @override
  Widget build(BuildContext context) {
    final a = _parseColor(accent) ?? colors(context).accent;
    final c = colors(context);
    return Container(
      width: 66,
      height: 84,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: c.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.border, width: 0.6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _bars(a, c.surface, w),
          );
        },
      ),
    );
  }

  List<Widget> _bars(Color a, Color bg, double w) {
    const gap = SizedBox(height: 3);
    switch (templateId) {
      case 'minimal':
        return [
          Container(height: 3, color: a),
          gap,
          Container(height: 2, color: bg),
          gap,
          Container(height: 2, color: bg),
          const Spacer(),
          Container(height: 2, color: bg),
        ];
      case 'executive':
        return [
          Container(height: 14, decoration: BoxDecoration(color: a, borderRadius: BorderRadius.circular(2))),
          gap,
          Container(height: 2, color: bg),
          gap,
          Container(height: 2, color: bg),
          const Spacer(),
          Container(height: 6, color: bg),
        ];
      case 'modern':
        return [
          Row(
            children: [
              Container(width: 4, height: 80, color: a),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(height: 3, color: bg),
                    gap,
                    Container(height: 2, color: bg),
                    const Spacer(),
                    Container(height: 6, color: bg),
                  ],
                ),
              ),
            ],
          ),
        ];
      case 'classic':
        return [
          Center(child: Container(height: 4, width: w * 0.7, color: bg)),
          gap,
          Center(child: Container(height: 2, width: w * 0.5, color: a)),
          const Spacer(),
          Center(child: Container(height: 6, width: w * 0.6, color: bg)),
        ];
      case 'creative':
        return [
          Container(height: 22, decoration: BoxDecoration(color: a, borderRadius: BorderRadius.circular(2))),
          const Spacer(),
          Container(height: 2, color: bg),
          gap,
          Container(height: 2, color: bg),
        ];
      case 'corporate':
        return [
          Row(
            children: [
              Expanded(child: Container(height: 10, color: bg)),
              const SizedBox(width: 3),
              Container(width: w * 0.28, height: 34, color: a),
            ],
          ),
          gap,
          Container(height: 2, color: bg),
          gap,
          Container(height: 2, color: bg),
        ];
      case 'elegant':
        return [
          Center(child: Container(height: 2, width: w * 0.8, color: a)),
          const Spacer(),
          Center(child: Container(height: 2, width: w * 0.6, color: bg)),
          gap,
          Center(child: Container(height: 2, width: w * 0.6, color: bg)),
        ];
      case 'compact':
        return [
          Container(height: 2, color: bg),
          gap,
          Container(height: 2, color: bg),
          gap,
          Container(height: 2, color: bg),
          gap,
          Container(height: 2, color: bg),
          const Spacer(),
          Container(height: 4, color: a),
        ];
      case 'bold':
        return [
          Container(height: 10, color: a),
          gap,
          Container(height: 3, color: bg),
          gap,
          Container(height: 3, color: bg),
          const Spacer(),
          Container(height: 8, color: a),
        ];
      case 'professional':
      default:
        return [
          Row(
            children: [
              Container(width: 10, height: 10, color: a),
              const SizedBox(width: 3),
              Container(height: 3, color: bg),
            ],
          ),
          gap,
          Container(height: 2, color: bg),
          gap,
          Container(height: 2, color: bg),
          const Spacer(),
          Container(height: 5, color: bg),
        ];
    }
  }

  Color? _parseColor(String hex) {
    final clean = hex.replaceFirst('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    }
    if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
    return null;
  }
}
'''


def main() -> None:
    p = Path('lib/views/templates_screen.dart')
    p.write_text(CONTENT, encoding='utf-8')
    back = p.read_text(encoding='utf-8')
    if back != CONTENT:
        raise SystemExit('read-back mismatch')
    print('OK lib/views/templates_screen.dart (%d chars)' % len(CONTENT))


if __name__ == '__main__':
    main()
