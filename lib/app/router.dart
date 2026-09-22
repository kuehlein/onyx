import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/algorithms/algo_screen.dart';
import '../features/behavioral/behavioral_entry_screen.dart';
import '../features/behavioral/story_bank_screen.dart';
import '../features/behavioral/story_capture_screen.dart';
import '../features/browse/browse_screen.dart';
import '../features/browse/card_detail_screen.dart';
import '../features/browse/unresolved_links_screen.dart';
import '../features/drafts/draft_review_screen.dart';
import '../features/home/home_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/interview/interview_debrief_screen.dart';
import '../features/interview/interview_prep_screen.dart';
import '../features/interview/upcoming_interviews_screen.dart';
import '../features/learn/learn_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/practice/flow_runner_screen.dart';
import '../features/practice/practice_screen.dart';
import '../features/quiz/quiz_screen.dart';
import '../features/reader/reader_screen.dart';
import '../features/report/readiness_report_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/system_design/sd_entry_screen.dart';
import '../shared/providers/vault.dart';

/// Builds the app router: a persistent bottom-nav shell (indexed stack, so each
/// tab keeps its state and scroll position) over four top-level destinations.
///
/// A function rather than a singleton so each [OnyxApp] instance owns fresh
/// navigation state — production has one app, but widget tests pump many, and a
/// shared router would leak one test's location into the next.
///
/// [ref] reads the vault-configured state for the first-run gate (redirect
/// below); [refresh] re-evaluates that redirect when the source (or its startup
/// load) settles — see [OnyxApp], which bumps it via `listenManual`.
GoRouter createRouter(WidgetRef ref, Listenable refresh) => GoRouter(
      initialLocation: '/',
      refreshListenable: refresh,
      // First-run gate (docs/settings-ux.md §3): with no study folder configured,
      // land on /welcome; once configured, keep it out of reach. Deciding is
      // *deferred* while the persisted ref is still loading, so a returning user
      // never flashes /welcome before their saved folder resolves.
      redirect: (context, state) {
        if (ref.read(loadVaultRefProvider).isLoading) return null;
        final configured = ref.read(vaultSourceProvider) != null;
        final atWelcome = state.matchedLocation == '/welcome';
        if (!configured && !atWelcome) return '/welcome';
        if (configured && atWelcome) return '/';
        return null;
      },
      routes: [
        // The first-run folder-source gate — a pre-shell full page (item 5),
        // outside the tab shell.
        GoRoute(path: '/welcome', builder: (_, __) => const WelcomeScreen()),
        // Full-screen, focused flow launched from Home (outside the tab shell).
        GoRoute(path: '/learn', builder: (_, __) => const LearnScreen()),
        // The daily Algorithms session (separate paced track).
        GoRoute(path: '/algorithms', builder: (_, __) => const AlgoScreen()),
        // The system-design practice track: pick a problem, run a mock.
        GoRoute(
            path: '/system-design', builder: (_, __) => const SdEntryScreen()),
        // A config-driven practice flow for one card (a vault-authored flow, e.g.
        // a Korean `conversation`). Full-screen, pushed from Home like the SD/algo
        // sessions; `:type` is the card type / practice-track id, `:id` the card.
        GoRoute(
          path: '/flow/:type/:id',
          builder: (_, state) => FlowRunnerScreen(
            flowType: state.pathParameters['type']!,
            cardId: state.pathParameters['id']!,
          ),
        ),
        // The interview-prep hub: target + scheduled interviews + behavioral.
        GoRoute(
            path: '/interview-prep',
            builder: (_, __) => const InterviewPrepScreen()),
        // The behavioral practice track: pick a competency, run a mock.
        GoRoute(
            path: '/behavioral',
            builder: (_, __) => const BehavioralEntryScreen()),
        // The career brain-dump: build your STAR story bank with the coach.
        GoRoute(
            path: '/behavioral/stories',
            builder: (_, __) => const StoryCaptureScreen()),
        // The story bank: coverage matrix + your saved stories.
        GoRoute(
            path: '/behavioral/story-bank',
            builder: (_, __) => const StoryBankScreen()),
        // The concept-card review session. A full-screen flow launched from
        // Home (like Learn / Algorithms), not a bottom-nav tab — the tabs are
        // app SECTIONS, the study sessions are actions.
        GoRoute(path: '/quiz', builder: (_, __) => const QuizScreen()),
        // The draft-review gate: self-test-then-promote over draft cards. A
        // bounded full-screen session (like /quiz, /learn), outside the shell.
        GoRoute(
            path: '/draft-review',
            builder: (_, __) => const DraftReviewScreen()),
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
        // A card's full detail, pushable from Learn/Review ("View full card") to
        // read reference sections (e.g. the implementation) that aren't quizzed.
        GoRoute(
          path: '/card/:id',
          builder: (_, state) =>
              CardDetailScreen(cardId: state.pathParameters['id']!),
        ),
        // The AI interview-readiness report, launched from Home.
        GoRoute(
            path: '/report', builder: (_, __) => const ReadinessReportScreen()),
        // The upcoming-interviews list — toggle/remove/practice for prep goals.
        GoRoute(
            path: '/interviews',
            builder: (_, __) => const UpcomingInterviewsScreen()),
        // Post-interview debrief for one goal (`/debrief/goal-123`).
        GoRoute(
          path: '/debrief/:deckId',
          builder: (_, state) =>
              InterviewDebriefScreen(deckId: state.pathParameters['deckId']!),
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
                  GoRoute(
                    path: 'unresolved-links',
                    builder: (_, __) => const UnresolvedLinksScreen(),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/insights',
                // `?focus=readiness|memory|applied|habits` deep-links a Home
                // metric to its explanation, revealing that group on open.
                builder: (_, state) =>
                    InsightsScreen(focus: state.uri.queryParameters['focus']),
              ),
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
