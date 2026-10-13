library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/store.dart';
import 'core/theme.dart';
import 'ui/kit.dart';
import 'views/clients_screen.dart';
import 'views/dashboard_screen.dart';
import 'views/document_viewer_screen.dart';
import 'views/documents_screen.dart';
import 'views/editor_screen.dart';
import 'views/invoices_screen.dart';
import 'views/preview_screen.dart';
import 'views/services_screen.dart';
import 'views/settings_screen.dart';
import 'views/templates_screen.dart';

/// Route names shared with the web prototype.
class Routes {
  static const dashboard = 'dashboard';
  static const invoices = 'invoices';
  static const clients = 'clients';
  static const services = 'services';
  static const templates = 'templates';
  static const preview = 'preview';
  static const editor = 'editor';
  static const documents = 'documents';
  static const settings = 'settings';

  static const paths = <String>[
    '/dashboard',
    '/invoices',
    '/clients',
    '/services',
    '/templates',
    '/documents',
    '/preview',
    '/editor',
    '/settings',
  ];
}

class AppRouter {
  static GoRouter config(Store store) {
    return GoRouter(
      navigatorKey: _rootKey,
      initialLocation: '/${Routes.dashboard}',
      refreshListenable: store,
      routes: [
        ShellRoute(
          builder: (context, state, child) => _AppShell(child: child),
          routes: [
            GoRoute(
              name: Routes.dashboard,
              path: '/${Routes.dashboard}',
              builder: (context, state) => const DashboardScreen(),
            ),
            GoRoute(
              name: Routes.invoices,
              path: '/${Routes.invoices}',
              builder: (context, state) => const InvoicesScreen(),
            ),
            GoRoute(
              name: Routes.clients,
              path: '/${Routes.clients}',
              builder: (context, state) => const ClientsScreen(),
            ),
            GoRoute(
              name: Routes.services,
              path: '/${Routes.services}',
              builder: (context, state) => const ServicesScreen(),
            ),
            GoRoute(
              name: Routes.templates,
              path: '/${Routes.templates}',
              builder: (context, state) => const TemplatesScreen(),
            ),
            GoRoute(
              name: Routes.documents,
              path: '/${Routes.documents}',
              builder: (context, state) => const DocumentsScreen(),
            ),
            GoRoute(
              name: Routes.settings,
              path: '/${Routes.settings}',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
        // Full-screen routes outside the bottom-nav shell.
        GoRoute(
          name: Routes.preview,
          path: '/${Routes.preview}',
          parentNavigatorKey: _rootKey,
          builder: (context, state) => const PreviewScreen(),
        ),
        GoRoute(
          name: Routes.editor,
          path: '/${Routes.editor}/:invoiceId',
          parentNavigatorKey: _rootKey,
          builder: (context, state) => EditorScreen(
            invoiceId: state.pathParameters['invoiceId'] ?? 'new',
          ),
        ),
        GoRoute(
          path: '/documents/view/:docId',
          parentNavigatorKey: _rootKey,
          builder: (context, state) => DocumentViewerScreen(
            documentId: state.pathParameters['docId'] ?? '',
          ),
        ),
      ],
    );
  }
}

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

class _NavItem {
  final String name;
  final IconData icon;
  final IconData selectedIcon;
  const _NavItem(this.name, this.icon, this.selectedIcon);
}

const _navItems = <_NavItem>[
  _NavItem(Routes.dashboard, AppIcons.dashboard, Icons.dashboard_rounded),
  _NavItem(Routes.invoices, AppIcons.invoices, Icons.description_rounded),
  _NavItem(Routes.clients, AppIcons.clients, Icons.people_rounded),
  _NavItem(Routes.documents, AppIcons.documents, Icons.folder_open_rounded),
  _NavItem(Routes.settings, AppIcons.settings, Icons.settings_rounded),
];

class _AppShell extends StatelessWidget {
  const _AppShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    final location = GoRouterState.of(context).uri.toString();
    final index = _navItems
        .indexWhere((n) => location.startsWith('/${n.name}'));

    return Scaffold(
      body: SafeArea(
        top: false,
        child: child,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: c.bgElevated,
          border: Border(top: BorderSide(color: c.border, width: 0.6)),
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          height: 66,
          selectedIndex: index < 0 ? 0 : index,
          onDestinationSelected: (i) {
            context.go('/${_navItems[i].name}');
          },
          indicatorColor: c.accent.withValues(alpha: 0.12),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            for (final n in _navItems)
              NavigationDestination(
                icon: Icon(n.icon, size: 21),
                selectedIcon: Icon(n.selectedIcon, size: 21),
                label: _label(n.name),
              ),
          ],
        ),
      ),
    );
  }

  String _label(String name) {
    switch (name) {
      case Routes.dashboard:
        return 'Home';
      case Routes.invoices:
        return 'Invoices';
      case Routes.clients:
        return 'Clients';
      case Routes.documents:
        return 'Documents';
      case Routes.settings:
        return 'Settings';
    }
    return name;
  }
}

