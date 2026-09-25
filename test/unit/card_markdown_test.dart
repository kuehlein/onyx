import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/vault/card_markdown.dart';

/// The shared card-serialization primitives (ADR-0013 §Addendum, G4) — the one
/// home for the YAML escaping / flow-list / slug rules the three write paths
/// (card_edit, generated_cards, import_deck) used to each copy. A quoting bug here
/// would corrupt every write path, so pin the rules directly.

void main() {
  group('yamlScalar', () {
    test('double-quotes a plain value', () {
      expect(yamlScalar('tcp'), '"tcp"');
    });

    test('escapes embedded quotes and backslashes (backslash first)', () {
      expect(yamlScalar('a"b'), r'"a\"b"');
      expect(yamlScalar(r'a\b'), r'"a\\b"');
      // A literal backslash-quote must not collapse into an escaped quote.
      expect(yamlScalar(r'a\"b'), r'"a\\\"b"');
    });

    test('leaves YAML-special characters inert inside the quotes', () {
      expect(yamlScalar('# not a comment'), '"# not a comment"');
      expect(yamlScalar('- leading dash'), '"- leading dash"');
      expect(yamlScalar('key: value'), '"key: value"');
    });
  });

  group('yamlFlowList', () {
    test('empty → [] regardless of spacing', () {
      expect(yamlFlowList(const []), '[]');
      expect(yamlFlowList(const [], spaced: true), '[]');
    });

    test('compact by default, padded when spaced', () {
      expect(yamlFlowList(['a', 'b']), '["a", "b"]');
      expect(yamlFlowList(['a', 'b'], spaced: true), '[ "a", "b" ]');
    });

    test('quotes each value via yamlScalar', () {
      expect(yamlFlowList(['a"b']), r'["a\"b"]');
    });
  });

  group('oneLine', () {
    test('collapses internal line breaks + surrounding whitespace to a space',
        () {
      expect(oneLine('a\nb'), 'a b');
      expect(oneLine('a  \n  b'), 'a b');
      expect(oneLine('a\r\n\r\nb'), 'a b');
    });

    test('trims the ends', () {
      expect(oneLine('  hi  '), 'hi');
      expect(oneLine('\n hi \n'), 'hi');
    });
  });

  group('slugify', () {
    test('lowercases and hyphenates runs of non-alphanumerics', () {
      expect(slugify('Two Pointers'), 'two-pointers');
      expect(slugify('A/B  test!!'), 'a-b-test');
    });

    test('trims leading/trailing hyphens; all-punct → empty', () {
      expect(slugify('  -Hello-  '), 'hello');
      expect(slugify('!!!'), '');
    });
  });
}
