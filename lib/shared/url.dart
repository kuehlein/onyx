import 'package:url_launcher/url_launcher.dart';

/// Open a URL in the external browser/app (e.g. a card's `practice_url` on
/// NeetCode/LeetCode). No-ops on an unparseable URL.
Future<void> openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
