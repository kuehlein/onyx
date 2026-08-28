import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/reader/reader.dart';

void main() {
  group('extractArticle', () {
    test('pulls the title + block content and drops chrome/scripts', () {
      const html = '''
<html>
<head><title>Fallback Title</title>
<meta property="og:title" content="Real Title"></head>
<body>
<nav>Home About</nav>
<article>
  <h1>Heading One</h1>
  <p>First paragraph.</p>
  <h2>Sub</h2>
  <ul><li>Item A</li><li>Item B</li></ul>
  <pre><code>x = 1;</code></pre>
  <blockquote>A quote.</blockquote>
  <script>evil()</script>
</article>
<footer>site footer</footer>
</body></html>
''';
      final a = extractArticle(html, url: 'https://ex.com/p');

      expect(a.title, 'Real Title'); // og:title wins over <title>
      expect(a.url, 'https://ex.com/p');
      expect(a.markdown, contains('# Heading One'));
      expect(a.markdown, contains('First paragraph.'));
      expect(a.markdown, contains('## Sub'));
      expect(a.markdown, contains('- Item A'));
      expect(a.markdown, contains('- Item B'));
      expect(a.markdown, contains('```'));
      expect(a.markdown, contains('x = 1;'));
      expect(a.markdown, contains('> A quote.'));
      // Content outside <article> and scripts are excluded.
      expect(a.markdown, isNot(contains('Home About')));
      expect(a.markdown, isNot(contains('site footer')));
      expect(a.markdown, isNot(contains('evil')));
      expect(a.isEmpty, isFalse);
    });

    test('falls back to <title>; empty body → isEmpty', () {
      const html =
          '<html><head><title>Only Title</title></head><body></body></html>';
      final a = extractArticle(html, url: 'u');
      expect(a.title, 'Only Title');
      expect(a.isEmpty, isTrue);
    });
  });
}
