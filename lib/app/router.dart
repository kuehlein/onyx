import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/browse/browse_screen.dart';
import '../features/browse/card_detail_screen.dart';
import '../features/home/home_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/interview/interview_debrief_screen.dart';
import '../features/interview/interview_planner_screen.dart';
import '../features/interview/upcoming_interviews_screen.dart';
import '../features/learn/learn_screen.dart';
import '../features/practice/practice_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/report/readiness_report_screen.dart';
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
        // Full-screen, focused flow launched from Home (outside the tab shell).
        GoRoute(path: '/learn', builder: (_, __) => const LearnScreen()),
        // In-app reader for a recommended-reading link (`/read?url=…`).
        GoRoute(
          path: '/read',
          builder: (_, state) =>
              ReaderScreen(url: state.uri.queryParameters['url'] ?? ''),
        ),
        // A short, non-grading practice run on a domain (`/practice/ds-a`).
        GoRoute(
          path: '/practice/:domain',
          builder: (_, state) => PracticeScreen(
            domain: state.pathParameters['domain']!,
            // `?for=Google · Senior · Backend` themes the mock to a prep goal.
            interviewContext: state.uri.queryParameters['for'],
          ),
        ),
        // The AI interview-readiness report, launched from Home.
        GoRoute(
            path: '/report', builder: (_, __) => const ReadinessReportScreen()),
        // The AI interview planner — describe an interview → active prep goal.
        GoRoute(
            path: '/plan-interview',
            builder: (_, __) => const InterviewPlannerScreen()),
        // The upcoming-interviews list — toggle/remove/practice for prep goals.
        GoRoute(
            path: '/interviews',
            builder: (_, __) => const UpcomingInterviewsScreen()),
        // Post-interview debrief for one goal (`/debrief/goal-123`).
        GoRoute(
          path: '/debrief/:goalId',
          builder: (_, state) =>
              InterviewDebriefScreen(goalId: state.pathParameters['goalId']!),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _ShellScaffold(shell: shell),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/browse',
                builder: (_, __) => const BrowseScreen(),
                routes: [
                  GoRoute(
                    path: 'card/:id',
                    builder: (_, state) =>
                        CardDetailScreen(cardId: state.pathParameters['id']!),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/quiz', builder: (_, __) => const QuizScreen()),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                  path: '/insights',
                  builder: (_, __) => const InsightsScreen()),
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
      icon: Icon(Icons.query_stats_outlined),
      selectedIcon: Icon(Icons.query_stats),
      label: 'Insights',
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
