import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';
import 'theme.dart';

/// Root widget: wires the router and theme into a MaterialApp. Follows the
/// system light/dark setting, defaulting dark.
///
/// Owns its [GoRouter] (created once in [initState]) so navigation state is
/// scoped to this app instance. Tests may inject a router; otherwise one is
/// built via [createRouter].
class OnyxApp extends StatefulWidget {
  const OnyxApp({super.key, this.router});

  final GoRouter? router;

  @override
  State<OnyxApp> createState() => _OnyxAppState();
}

class _OnyxAppState extends State<OnyxApp> {
  late final GoRouter _router = widget.router ?? createRouter();

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
