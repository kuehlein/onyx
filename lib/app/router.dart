import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/browse/browse_screen.dart';
import '../features/home/home_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/settings/settings_screen.dart';

/// Builds the app router: a persistent bottom-nav shell (indexed stack, so each
/// tab keeps its state and scroll position) over four top-level destinations.
///
/// A function rather than a singleton so each [OnyxApp] instance owns fresh
/// navigation state — production has one app, but widget tests pump many, and a
/// shared router would leak one test's location into the next.
GoRouter createRouter() => GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _ShellScaffold(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/browse', builder: (_, __) => const BrowseScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/quiz', builder: (_, __) => const QuizScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/settings',
                  builder: (_, __) => const SettingsScreen()),
            ]),
          ],
        ),
      ],
    );

class _ShellScaffold extends StatelessWidget {
  const _ShellScaffold({required this.shell});

  final StatefulNavigationShell shell;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view),
      label: 'Browse',
    ),
    NavigationDestination(
      icon: Icon(Icons.school_outlined),
      selectedIcon: Icon(Icons.school),
      label: 'Study',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        // goBranch(initialLocation:) re-taps the current tab back to its root.
        onDestinationSelected: (i) => shell.goBranch(
          i,
          initialLocation: i == shell.currentIndex,
        ),
        destinations: _destinations,
      ),
    );
  }
}
