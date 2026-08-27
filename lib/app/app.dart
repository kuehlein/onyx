import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../shared/providers/backup.dart';
import 'router.dart';
import 'theme.dart';

/// Root widget: wires the router and theme into a MaterialApp. Follows the
/// system light/dark setting, defaulting dark.
///
/// Owns its [GoRouter] (created once in [initState]) so navigation state is
/// scoped to this app instance. Tests may inject a router; otherwise one is
/// built via [createRouter]. Flushes the progress backup when the app is
/// backgrounded, so nothing since the last debounced write is lost.
class OnyxApp extends ConsumerStatefulWidget {
  const OnyxApp({super.key, this.router});

  final GoRouter? router;

  @override
  ConsumerState<OnyxApp> createState() => _OnyxAppState();
}

class _OnyxAppState extends ConsumerState<OnyxApp> with WidgetsBindingObserver {
  late final GoRouter _router = widget.router ?? createRouter();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      ref.read(backupProvider.notifier).flush();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Onyx',
      theme: OnyxTheme.light(),
      darkTheme: OnyxTheme.dark(),
      themeMode: ThemeMode.dark,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
