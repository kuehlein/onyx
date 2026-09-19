import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/design/context_x.dart';
import 'folder_source_sheet.dart';

/// The first-run gate (docs/settings-ux.md §3, docs/product-direction.md §5): a
/// pre-shell full page — no bottom-nav, no sheet chrome — shown until a study
/// folder is configured. Deliberately not folder-first and not SWE-specific:
/// the framing is "how do you want to start?", and the "Create a study folder
/// for me" path seeds a subject-neutral sample deck so cards exist immediately
/// (the "two taps to first review, zero deck-building" non-negotiable).
///
/// It renders the same [FolderSourceBody] the Settings folder picker uses, so
/// the two actions + expander stay in one place. Once a source is chosen, the
/// router gate redirects to Home automatically.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                EdgeInsets.symmetric(horizontal: t.space5, vertical: t.space6),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.hexagon_outlined,
                    size: 44,
                    color: context.colors.primary,
                  ),
                  SizedBox(height: t.space4),
                  Text(
                    "Let's get you set up",
                    textAlign: TextAlign.center,
                    style: context.text.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: t.space2),
                  Text(
                    'How do you want to start?',
                    textAlign: TextAlign.center,
                    style: context.text.bodyLarge
                        ?.copyWith(color: context.colors.onSurfaceVariant),
                  ),
                  SizedBox(height: t.space6),
                  const FolderSourceBody(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
