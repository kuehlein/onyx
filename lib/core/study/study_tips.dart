/// Evidence-based study tips shown in Learn mode (first exposure to material),
/// not while testing. Each is grounded in the learning-science research synthesis
/// (see docs/learning-science.md): retrieval practice, spacing, interleaving,
/// desirable difficulty, rule-based encoding, conditional knowledge, and the
/// flashcard→transfer gap. Kept short and few so they're easy to keep in mind.
class StudyTip {
  const StudyTip(this.title, this.body);
  final String title;
  final String body;
}

const studyTips = <StudyTip>[
  StudyTip(
    'Try before you reveal',
    'Take a real guess first — even a wrong one. Struggling to retrieve an '
        'answer cements it far more than reading it straight away.',
  ),
  StudyTip(
    'Say it in your own words',
    'After revealing, explain the idea aloud or jot a quick note as if teaching '
        'it. Producing it yourself beats re-reading.',
  ),
  StudyTip(
    'Learn the rule, not the answer',
    'Aim to reconstruct the specifics from the underlying principle. If you can '
        'derive the answer from the idea, it will last.',
  ),
  StudyTip(
    'Ask “when would I use this?”',
    'Recognising which pattern a problem calls for is the real interview skill. '
        'Study the trigger — the signals that point to this approach — not just '
        'the fact.',
  ),
  StudyTip(
    'Let the mixing happen',
    'Onyx interleaves topics on purpose. The effort of switching between them '
        'feels harder but makes the learning stick — don’t batch one topic.',
  ),
  StudyTip(
    'Trust the schedule — don’t cram',
    'Spacing reviews out beats massing them. Coming back tomorrow, when it’s a '
        'little harder to recall, is exactly the point.',
  ),
  StudyTip(
    'A little struggle is good',
    'If recall feels effortful, it’s working. Don’t mark something easy just '
        'because it looks familiar — recognising isn’t the same as recalling.',
  ),
  StudyTip(
    'Connect it to what you know',
    'Tie a new idea to something familiar or a concrete example. Elaborating on '
        'a fact deepens the memory more than repeating it.',
  ),
  StudyTip(
    'Cards build the library; problems build transfer',
    'Flashcards make patterns fast to recall. To learn to apply them to novel '
        'problems, pair Onyx with real practice (LeetCode, mock interviews).',
  ),
];
