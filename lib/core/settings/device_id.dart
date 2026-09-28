import 'dart:math';

import 'preferences_repository.dart';

/// The preferences key holding this device's stable id.
const kDeviceIdKey = 'deviceId';

/// A stable per-device id (ADR-0019), generated once and stored in the **device-local**
/// preferences table — never the vault, because it identifies *this* device, not the
/// study content. It names the device's own state snapshot (`_onyx/state/<id>.json`) so
/// two devices sharing a synced folder never write the same file, closing the
/// same-file multi-device write race (the ADR-0001 follow-up).
///
/// Get-or-generate: returns the stored id, or mints one (16 random bytes as lowercase
/// hex via [Random.secure] — collision-negligible, filename-safe) and persists it.
/// A fresh install / lost DB simply mints a new id and writes a new state file; the
/// old device's file is still merged in on restore, so no progress is lost — just an
/// extra (convergent) file.
Future<String> resolveDeviceId(PreferencesRepository prefs) async {
  final existing = await prefs.get(kDeviceIdKey);
  if (existing != null && existing.isNotEmpty) return existing;
  final id = _mintDeviceId();
  await prefs.set(kDeviceIdKey, id);
  return id;
}

String _mintDeviceId() {
  final rand = Random.secure();
  final bytes = [for (var i = 0; i < 16; i++) rand.nextInt(256)];
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
