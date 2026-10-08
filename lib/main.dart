library;

import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'router.dart';
import 'ui/kit.dart';

/// Boot screen shown while Isar opens and the seed data is written.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, v, child) {
                return Opacity(
                  opacity: v,
                  child: child,
                );
              },
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  'IB',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: c.onAccent,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              AppMeta.name,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 120,
              child: LinearProgressIndicator(
                backgroundColor: c.surface3,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IconBillingApp extends StatefulWidget {
  const IconBillingApp({super.key});

  @override
  State<IconBillingApp> createState() => _IconBillingAppState();
}

class _IconBillingAppState extends State<IconBillingApp> {
  Store? _store;
  String _theme = 'dark';
  AccentDef _accent = accentById('icon');
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final store = await Store.create();
    if (!mounted) return;
    setState(() {
      _store = store;
      _theme = store.settings.theme;
      _accent = store.accent;
      _ready = true;
    });
    store.addListener(_onStoreChanged);
  }

  void _onStoreChanged() {
    if (!mounted) return;
    final s = _store;
    if (s == null) return;
    final nextTheme = s.settings.theme;
    final nextAccent = s.accent;
    if (nextTheme != _theme || nextAccent.a != _accent.a) {
      setState(() {
        _theme = nextTheme;
        _accent = nextAccent;
      });
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_onStoreChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.of(context, 'dark', accentById('icon')),
        home: const _Splash(),
      );
    }

    final store = _store!;
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: AppMeta.name,
          theme: AppTheme.of(context, store.settings.theme, store.accent),
          routerConfig: AppRouter.config(store),
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: EdgeInsets.zero,
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IconBillingApp());
}
