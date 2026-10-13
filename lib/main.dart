library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/constants.dart';
import 'core/store.dart';
import 'core/theme.dart';
import 'router.dart';

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

/// Fallback screen when database initialization or startup fails.
class _BootError extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _BootError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = colors(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                'Initialization Failed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.text),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: c.text2),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry Startup'),
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  foregroundColor: c.onAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
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
  GoRouter? _router;
  String _theme = 'dark';
  AccentDef _accent = accentById('icon');
  bool _ready = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    setState(() {
      _initError = null;
      _ready = false;
    });

    try {
      final store = await Store.create().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Startup timed out after 30 seconds.'),
      );
      if (!mounted) return;
      final router = AppRouter.config(store);
      setState(() {
        _store = store;
        _router = router;
        _theme = store.settings.theme;
        _accent = store.accent;
        _ready = true;
      });
      store.addListener(_onStoreChanged);
    } catch (e, st) {
      debugPrint('[BOOT ERROR] $e\n$st');
      if (!mounted) return;
      setState(() {
        _initError = e is TimeoutException
            ? 'Startup timed out. Please retry.'
            : 'Failed to initialize database: ${e.toString().split('\n').first}';
      });
    }
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
    _router?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.of(context, 'dark', accentById('icon')),
        home: _BootError(
          error: _initError!,
          onRetry: _boot,
        ),
      );
    }

    if (!_ready || _router == null) {
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
        final currentTheme =
            AppTheme.of(context, store.settings.theme, store.accent);
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: AppMeta.name,
          themeMode: store.settings.theme == 'light'
              ? ThemeMode.light
              : ThemeMode.dark,
          theme: currentTheme,
          darkTheme: currentTheme,
          routerConfig: _router,
        );
      },
    );
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const IconBillingApp());
}
