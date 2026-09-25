import 'package:flutter/material.dart';

/// Maps a flow's `FlowSpec.iconKey` to its icon (fallback: a generic card). The
/// one home for flow iconography — shared by Browse, Home, and the card view.
/// Config-driven: resolved from the flow, never a `card.type ==` branch
/// (architecture invariant #2).
IconData flowIcon(String? key) => switch (key) {
      'flashcard' => Icons.style_outlined,
      'interview' => Icons.forum_outlined,
      'algorithm' => Icons.terminal_outlined,
      'systemDesign' => Icons.architecture_outlined,
      'behavioral' => Icons.record_voice_over_outlined,
      _ => Icons.style_outlined,
    };
