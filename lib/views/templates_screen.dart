library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../core/store.dart';
import '../core/seed.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../ui/kit.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    final store = Store.instance;
    final samples = seedTemplateSamples();
    final activeId = store.settings.activeTemplate;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  PageHeader(
                    title: 'Templates',
                    subtitle: 'Choose a layout for your invoices',
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: _cardDecoration(c),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Active template',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: c.text3,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: c.accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                templateName(activeId)[0],
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: c.accent,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    templateName(activeId),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    templateById(activeId).blurb,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: c.text3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(AppIcons.check, size: 18, color: Colors.green),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'All templates',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.text3,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final t = kTemplates[index];
                    final sample = samples[t.id];
                    final isActive = t.id == activeId;
                    return _TemplateTile(
                      def: t,
                      isActive: isActive,
                      onTap: () {
                        store.setActiveTemplate(t.id);
                        showAppToast(
                          context,
                          '${t.name} set as default',
                          success: true,
                        );
                      },
                      onUse: sample != null
                          ? () {
                              final draft = sample.copy()
                                ..invoiceId = ''
                                ..number = store.nextNumber('invoice')
                                ..status = 'draft'
                                ..template = t.id
                                ..issueDate = DateTime.now()
                                ..dueDate = DateTime.now().add(const Duration(days: 14));
                              context.push('/editor/new', extra: draft);
                            }
                          : null,
                    );
                  },
                  childCount: kTemplates.length,
                ),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.75,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration(AppColors c) => BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border, width: 0.6),
      );
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({
    required this.def,
    required this.isActive,
    required this.onTap,
    this.onUse,
  });

  final TemplateDef def;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback? onUse;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return Material(
      color: isActive ? c.accent.withValues(alpha: 0.10) : c.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: c.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.border, width: 0.6),
                ),
                child: Center(
                  child: Text(
                    def.name,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: c.text3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                def.name,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                def.category,
                style: TextStyle(fontSize: 10.5, color: c.text3),
              ),
              const Spacer(),
              Row(
                children: [
                  if (onUse != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onUse,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Use', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  if (onUse != null) const SizedBox(width: 6),
                  if (isActive)
                    const Icon(AppIcons.check, size: 16, color: Colors.green)
                  else
                    Container(
                      width: 16,
                      height: 16,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

