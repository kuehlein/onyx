import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'vault_ref.dart';

/// Obtains a content-source [VaultRef] from the user (ADR-0002).
abstract class FolderPicker {
  /// Whether [pickExisting] can present a native folder chooser here. True on
  /// desktop, where a plain path is durably re-openable via `dart:io`; false on
  /// iOS/Android, where re-opening an external folder across launches needs a
  /// security-scoped bookmark ([VaultRefKind.iosBookmark]) / SAF `content://`
  /// tree URI ([VaultRefKind.androidTree]) — a native fill-in not wired yet
  /// (ADR-0002). The UI hides "Choose a folder" when this is false, leaving the
  /// always-available `createManaged` on-ramp.
  bool get canPickExisting;

  /// Let the user choose an EXISTING folder, returning a persistable ref, or null
  /// if cancelled (or [canPickExisting] is false on this platform).
  Future<VaultRef?> pickExisting();

  /// Create an app-managed study folder inside the app's own sandbox and return a
  /// ref to it. Works on **every** platform now — the app owns its sandbox, so no
  /// security-scoped bookmark or SAF permission is needed (just `dart:io`).
  Future<VaultRef> createManaged({String name});
}

/// The default [FolderPicker]. [createManaged] is fully cross-platform via
/// `path_provider`; [pickExisting] uses the native directory chooser on desktop
/// (the iOS/Android durable-handle path is the ADR-0002 fill-in — see
/// [canPickExisting]).
class PlatformFolderPicker implements FolderPicker {
  const PlatformFolderPicker();

  @override
  bool get canPickExisting =>
      Platform.isMacOS || Platform.isLinux || Platform.isWindows;

  @override
  Future<VaultRef?> pickExisting() async {
    if (!canPickExisting)
      return null; // iOS/Android need a bookmark/SAF (ADR-0002)
    final dir = await FilePicker.getDirectoryPath(dialogTitle: 'Study folder');
    if (dir == null || dir.isEmpty) return null; // cancelled
    return VaultRef(VaultRefKind.path, dir);
  }

  @override
  Future<VaultRef> createManaged({String name = 'Onyx'}) async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, name));
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return VaultRef(VaultRefKind.appManaged, dir.path);
  }
}
