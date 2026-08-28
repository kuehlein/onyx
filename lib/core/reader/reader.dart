import 'dart:async';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

/// A fetched web page reduced to a clean, readable article.
class Article {
  const Article(
      {required this.title, required this.markdown, required this.url});

  final String title;

  /// The main content extracted to plain Markdown (headings, paragraphs, lists,
  /// code, quotes) — rendered by the reader and fed to the AI Q&A.
  final String markdown;

  final String url;

  bool get isEmpty => markdown.trim().isEmpty;
}

/// A user-presentable failure loading a page.
class ReaderException implements Exception {
  ReaderException(this.message);
  final String message;
  @override
  String toString() => 'ReaderException: $message';
}

/// Reduces raw HTML to a readable [Article] — a small "reader mode". Pure and
/// network-free so it's directly testable; [ReaderService] pairs it with a fetch.
Article extractArticle(String html, {required String url}) {
  final doc = html_parser.parse(html);

  String pick(String? s) => (s ?? '').trim();
  var title = pick(
      doc.querySelector('meta[property="og:title"]')?.attributes['content']);
  if (title.isEmpty) title = pick(doc.querySelector('title')?.text);
  if (title.isEmpty) title = pick(doc.querySelector('h1')?.text);
  if (title.isEmpty) title = 'Untitled';

  final root = doc.querySelector('article') ??
      doc.querySelector('main') ??
      doc.querySelector('[role="main"]') ??
      doc.body;

  final out = StringBuffer();
  if (root != null) {
    // Strip chrome/noise so it doesn't pollute the reading text.
    for (final sel in const [
      'script', 'style', 'noscript', 'template', 'nav', 'header', 'footer',
      'aside', 'form', 'svg', 'iframe', 'button', 'figure', //
    ]) {
      root.querySelectorAll(sel).forEach((e) => e.remove());
    }
    _walk(root, out);
  }

  return Article(title: title, markdown: out.toString().trim(), url: url);
}

/// Depth-first walk emitting Markdown for block elements once each (recursing
/// only into generic containers, so nested blocks aren't duplicated).
void _walk(Element el, StringBuffer out) {
  void block(String s) => out
    ..writeln(s)
    ..writeln();

  for (final node in el.nodes) {
    if (node is! Element) continue;
    final text = node.text.trim();
    switch (node.localName) {
      case 'h1':
        if (text.isNotEmpty) block('# $text');
      case 'h2':
        if (text.isNotEmpty) block('## $text');
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        if (text.isNotEmpty) block('### $text');
      case 'p':
        if (text.isNotEmpty) block(text);
      case 'ul':
      case 'ol':
        for (final li in node.children) {
          if (li.localName != 'li') continue;
          final t = li.text.trim();
          if (t.isNotEmpty) out.writeln('- $t');
        }
        out.writeln();
      case 'pre':
        if (text.isNotEmpty) block('```\n${node.text.trimRight()}\n```');
      case 'blockquote':
        if (text.isNotEmpty) block('> ${text.replaceAll('\n', '\n> ')}');
      case 'br':
        break;
      default:
        // Generic containers (div, section, article, span, a, …) — descend.
        _walk(node, out);
    }
  }
}

/// Fetches a URL and reduces it to a readable [Article].
class ReaderService {
  ReaderService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Article> fetch(String url) async {
    final http.Response response;
    try {
      response = await _client.get(
        Uri.parse(url),
        // Some sites serve a stripped page to unknown agents.
        headers: const {
          'User-Agent': 'Mozilla/5.0 (compatible; OnyxReader/1.0)'
        },
      ).timeout(const Duration(seconds: 20));
    } on TimeoutException {
      throw ReaderException('The page took too long to respond.');
    } catch (_) {
      throw ReaderException("Couldn't reach the page — check your connection.");
    }
    if (response.statusCode != 200) {
      throw ReaderException('The page returned HTTP ${response.statusCode}.');
    }
    final contentType = response.headers['content-type'] ?? '';
    if (!contentType.contains('html')) {
      throw ReaderException(
          "That link isn't a readable page (${contentType.split(';').first}).");
    }
    final article = extractArticle(response.body, url: url);
    if (article.isEmpty) {
      throw ReaderException("Couldn't pull readable text from this page.");
    }
    return article;
  }

  void dispose() => _client.close();
}
