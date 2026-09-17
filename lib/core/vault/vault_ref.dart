import 'desktop_vault_source.dart';
import 'vault_source.dart';

/// How a chosen content root is referenced durably. Platforms differ in what can
/// be persisted and later reopened (ADR-0002):
///
///  * [path] — a plain filesystem path (desktop / `ONYX_VAULT_PATH`).
///  * [appManaged] — an absolute path to a folder the app created inside its own
///    sandbox (`path_provider` documents dir). Readable via `dart:io` on **every**
///    platform with no special permission — it is the app's own directory.
///  * [iosBookmark] — a base64 iOS security-scoped bookmark for an external folder.
///  * [androidTree] — an Android Storage Access Framework `content://` tree URI
///    (with persisted permission) for an external folder.
///
/// [iosBookmark] and [androidTree] are the native external-folder handles; their
/// [VaultSource] resolution is a documented fill-in (see [resolveVaultSource]).
enum VaultRefKind { path, appManaged, iosBookmark, androidTree }

/// A persistable reference to the user's content root. Encodes to a compact
/// `"<kind>:<value>"` string stored in the preferences table (ADR-0002).
class VaultRef {
  const VaultRef(this.kind, this.value);

  final VaultRefKind kind;

  /// The path (for [VaultRefKind.path] / [VaultRefKind.appManaged]), the base64
  /// bookmark ([VaultRefKind.iosBookmark]), or the `content://` tree URI
  /// ([VaultRefKind.androidTree]).
  final String value;

  /// Compact form for the key/value preferences table.
  String encode() => '${kind.name}:$value';

  /// Inverse of [encode]; returns null for null/empty/malformed input (so a
  /// missing or cleared preference decodes to "no ref").
  static VaultRef? decode(String? raw) {
    if (raw == null) return null;
    final sep = raw.indexOf(':');
    if (sep <= 0) return null;
    final kindName = raw.substring(0, sep);
    final value = raw.substring(sep + 1);
    if (value.isEmpty) return null;
    for (final kind in VaultRefKind.values) {
      if (kind.name == kindName) return VaultRef(kind, value);
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is VaultRef && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => 'VaultRef(${kind.name}, $value)';
}

/// Resolves a [VaultRef] to a live [VaultSource].
///
/// [VaultRefKind.path] and [VaultRefKind.appManaged] resolve to a
/// [DesktopVaultSource] over the stored path — this covers desktop *and* the
/// cross-platform "create a study folder" case (an app-sandbox folder is readable
/// by `dart:io` everywhere). The external-folder kinds require native handle
/// resolution and are **not implemented in this unit** (ADR-0002): they throw
/// [UnsupportedError] so a caller fails loudly rather than silently reading the
/// wrong folder. Implementing them is a platform fill-in.
VaultSource resolveVaultSource(VaultRef ref) {
  switch (ref.kind) {
    case VaultRefKind.path:
    case VaultRefKind.appManaged:
      return DesktopVaultSource(ref.value);
    case VaultRefKind.iosBookmark:
      throw UnsupportedError(
        'iOS security-scoped bookmark resolution is not implemented yet '
        '(ADR-0002). Resolve the bookmark to a path + startAccessing… in a '
        'platform channel, then return a bookmark-backed VaultSource.',
      );
    case VaultRefKind.androidTree:
      throw UnsupportedError(
        'Android SAF tree-URI source is not implemented yet (ADR-0002). Back a '
        'VaultSource with DocumentFile over the persisted content:// permission.',
      );
  }
}
