import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'vault_ref.dart';

/// Obtains a content-source [VaultRef] from the user (ADR-0002).
abstract class FolderPicker {
  /// Let the user choose an EXISTING folder, returning a persistable ref (or null
  /// if cancelled / not yet supported on this platform).
  ///
  /// **Platform fill-in (ADR-0002).** A directory picker + a *durable* handle
  /// differs per platform — a plain path (desktop), a security-scoped bookmark
  /// ([VaultRefKind.iosBookmark]), or a persisted SAF `content://` tree URI
  /// ([VaultRefKind.androidTree]). Wiring the picker plugin(s) + persisting the
  /// handle needs device testing, so it lands with the picker-UI unit;
  /// [PlatformFolderPicker] returns null until then. `createManaged` is the
  /// working cross-platform on-ramp in the meantime.
  Future<VaultRef?> pickExisting();

  /// Create an app-managed study folder inside the app's own sandbox and return a
  /// ref to it. Works on **every** platform now — the app owns its sandbox, so no
  /// security-scoped bookmark or SAF permission is needed (just `dart:io`).
  Future<VaultRef> createManaged({String name});
}

/// The default [FolderPicker]. [createManaged] is fully cross-platform via
/// `path_provider`; [pickExisting] is the per-platform fill-in (see the interface).
class PlatformFolderPicker implements FolderPicker {
  const PlatformFolderPicker();

  @override
  Future<VaultRef?> pickExisting() async => null; // platform fill-in (ADR-0002)

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
