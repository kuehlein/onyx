import 'vault_source.dart';

/// Matches a whole `status:` frontmatter line whose value is `draft` — quoted or
/// not, with optional surrounding whitespace — including its trailing newline, so
/// removing it leaves no blank line behind. Anchored per-line (multiLine) and
/// case-insensitive on the value (`Draft` reads the same to the parser).
final _draftStatusLine = RegExp(
  '''^status:[ \\t]*["']?draft["']?[ \\t]*\\r?\\n''',
  multiLine: true,
  caseSensitive: false,
);

/// Promotes the card at [filePath] from `draft` to `active` by removing its
/// `status: draft` frontmatter line — absent `status:` defaults to `active`
/// (see [CardStatus]), so deletion is the promotion. Everything else in the file
/// is preserved byte-for-byte.
///
/// Pure-ish: takes a [VaultSource] and no provider/Riverpod deps, so it's
/// unit-testable against a temp desktop source.
Future<void> promoteCard(VaultSource source, String filePath) async {
  final raw = await source.readCard(filePath);
  final promoted = raw.replaceFirst(_draftStatusLine, '');
  // Only rewrite when the line was actually present — avoids a needless write
  // (and a spurious file-mtime bump) for an already-active card.
  if (promoted != raw) await source.writeFile(filePath, promoted);
}

/// Discards the draft at [filePath] entirely — deletes the file. Nothing enters
/// FSRS. No-ops if the file is already gone.
Future<void> discardCard(VaultSource source, String filePath) =>
    source.deleteFile(filePath);
