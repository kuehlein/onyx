import 'package:flutter/foundation.dart';

/// True for development builds (any non-release run — `flutter run`, a
/// `--debug` desktop preview, tests). Dev builds isolate their study data: a
/// separate on-disk database (`onyx-dev.sqlite`) and a separate vault snapshot
/// file (`onyx-state.dev.json`), so experimenting on desktop never overwrites
/// the real, synced progress. The shipped release app always uses the real
/// files. This is intentionally driven by `kDebugMode` alone — no env flag to
/// set or forget.
bool get isDevDataMode => kDebugMode;
