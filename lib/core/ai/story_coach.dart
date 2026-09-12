import 'dart:convert';

import '../story/competency.dart';
import '../story/story.dart';
import 'coach.dart' show CoachMessage;
import 'coach_update_chat.dart' show coachChatTurns;

export 'coach.dart' show CoachMessage, CoachRole;

/// The **story-bank capture coach** (flow-4 Ph2): a warm interviewer that draws
/// the user's career out and helps them DRAFT STAR+L stories, which are saved to
/// the vault. It is NOT the graded mock — it never scores; it builds material.
///
/// Grounded in the behavioral research: (1) an AI-drafted brain-dump is the
/// highest-leverage feature; (2) it must be COMPETENCY-GAP-TARGETED (drive toward
/// the missing competencies — a missing Conflict/Backbone or Failure story is the
/// #1 loop-killer); (3) it produces a SKELETON, not a script (over-rehearsal reads
/// robotic and is itself a scored failure); (4) it captures the highest-signal
/// pieces — personal ownership ("I", not "we"), a quantified result, and a
/// reflection/learning.
String buildStoryCoachSystem({
  required List<String> have,
  required List<String> gaps,
  String? level,
}) {
  String names(List<String> keys) =>
      keys.isEmpty ? '(none yet)' : keys.map(competencyLabel).join(', ');

  final b = StringBuffer()
    ..writeln('You are a warm, curious interview-prep coach helping a '
        '${level ?? 'software-engineering'} candidate build their behavioral '
        'STORY BANK. You interview them about their career and turn raw memories '
        'into structured STAR+L stories. This is preparation, NOT a graded mock — '
        'be encouraging and never score them.')
    ..writeln()
    ..writeln('# The 8 competencies a strong bank covers')
    ..writeln(kBehavioralCompetencies.map((c) => c.label).join('; '))
    ..writeln()
    ..writeln('# This candidate\'s coverage')
    ..writeln('- Already has a story for: ${names(have)}')
    ..writeln('- STILL NEEDS a story for: ${names(gaps)}')
    ..writeln(
        'Prioritise drawing out a story for a MISSING competency. A missing '
        'Conflict & Backbone or Failure story is the most common thing that sinks '
        'a loop, so steer toward those if they are open.')
    ..writeln()
    ..writeln('# How to run it')
    ..writeln(
        '- Ask ONE question at a time; keep your turns short (the candidate '
        'may be speaking via speech-to-text). Start broad ("tell me about a '
        'project you\'re proud of / a time a project went sideways / a '
        'disagreement you had"), then zoom into ONE concrete incident.')
    ..writeln('- Probe for the STAR+L pieces, especially the ones people miss: '
        'the SITUATION/stakes; what THEY personally did (push for "I", not "we"); '
        'a QUANTIFIED result (a metric, %, \$, time — ask "what changed, and by '
        'how much?"); and the LEARNING ("what would you do differently?").')
    ..writeln(
        '- Capture their OWN words as concise bullets — a SKELETON they can '
        'deliver fresh, NOT a polished script to memorise. Do not put words in '
        'their mouth or invent details; if something is missing, ask.')
    ..writeln(
        '- One story can cover 2-3 competencies — note that when it applies.')
    ..writeln(
        '- Be concise: 2-4 sentences per turn, plain Markdown, no headings.')
    ..writeln()
    ..writeln('# Emitting a draft')
    ..writeln(
        'As soon as you have at least a Situation, the candidate\'s Action, '
        'and a Result, emit the story as ONE tag on its OWN FINAL LINE (after your '
        'normal reply), and re-emit an updated tag whenever it changes materially:')
    ..writeln('<story>{"title":"short title","competencies":["conflict"],'
        '"situation":"…","task":"…","action":"…","result":"…","learning":"…"}'
        '</story>')
    ..writeln(
        'Use only these competency keys: ${kCompetencyKeys.join(', ')}. Keep '
        'each field concise (bullet-worthy, the candidate\'s words). Omit the tag '
        'entirely until you genuinely have S + A + R; never fabricate fields to '
        'complete it.');
  return b.toString();
}

/// A drafted story parsed from a `<story>` tag — the candidate saves it (or keeps
/// refining) rather than it being written automatically.
class StoryDraft {
  const StoryDraft({
    required this.title,
    this.competencies = const [],
    this.situation = '',
    this.task = '',
    this.action = '',
    this.result = '',
    this.learning = '',
  });

  final String title;
  final List<String> competencies;
  final String situation, task, action, result, learning;

  /// Usable once it has the load-bearing STAR pieces.
  bool get isUsable =>
      situation.trim().isNotEmpty &&
      action.trim().isNotEmpty &&
      result.trim().isNotEmpty;

  /// Whether the Result has a number in it (the highest-signal, most-missed part).
  bool get hasQuantifiedResult => RegExp(r'\d').hasMatch(result);

  Story toStory({required String id, DateTime? created}) => Story(
        id: id,
        title: title,
        competencies: competencies,
        situation: situation,
        task: task,
        action: action,
        result: result,
        learning: learning,
        created: created,
      );
}

final _storyTag =
    RegExp(r'<story>\s*(.*?)\s*</story>', dotAll: true, caseSensitive: false);

/// Splits a coach reply into the display text and an optional [StoryDraft] parsed
/// from a `<story>{…}</story>` tag (stripped from the text so it never shows).
({String text, StoryDraft? draft}) parseStoryReply(String raw) {
  final m = _storyTag.firstMatch(raw);
  StoryDraft? draft;
  if (m != null) {
    try {
      final j = jsonDecode(m.group(1)!) as Map<String, dynamic>;
      final title = (j['title'] as String?)?.trim() ?? '';
      if (title.isNotEmpty) {
        final comps = <String>[
          if (j['competencies'] is List)
            for (final c in j['competencies'] as List)
              if (kCompetencyKeys.contains(c)) c as String,
        ];
        String f(String k) => (j[k] as String?)?.trim() ?? '';
        draft = StoryDraft(
          title: title,
          competencies: comps,
          situation: f('situation'),
          task: f('task'),
          action: f('action'),
          result: f('result'),
          learning: f('learning'),
        );
      }
    } catch (_) {
      draft = null;
    }
  }
  return (text: raw.replaceAll(_storyTag, '').trim(), draft: draft);
}

/// Formats the running chat into Anthropic message turns (alternating, starting
/// with the candidate's first turn).
List<({String role, String content})> storyChatTurns(List<CoachMessage> msgs) =>
    coachChatTurns(msgs);
