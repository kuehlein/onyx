import 'package:flutter_test/flutter_test.dart';
import 'package:onyx/core/vault/desktop_vault_source.dart';
import 'package:onyx/core/vault/vault_ref.dart';

/// Pure properties of [VaultRef] + [resolveVaultSource] (ADR-0002). No plugins.

void main() {
  group('VaultRef', () {
    test('encode/decode round-trips every kind (values may contain colons)',
        () {
      for (final kind in VaultRefKind.values) {
        const value = '/some/value with:a:colon';
        final ref = VaultRef(kind, value);
        final back = VaultRef.decode(ref.encode());
        expect(back, ref);
        expect(back!.kind, kind);
        expect(
            back.value, value); // only the FIRST ':' separates kind from value
      }
    });

    test('decode returns null for null / empty / malformed input', () {
      expect(VaultRef.decode(null), isNull);
      expect(VaultRef.decode(''), isNull);
      expect(VaultRef.decode('nocolon'), isNull);
      expect(VaultRef.decode('path:'), isNull); // empty value
      expect(VaultRef.decode(':/x'), isNull); // empty kind
      expect(VaultRef.decode('bogusKind:/x'), isNull);
    });

    test('resolveVaultSource maps path/appManaged to a DesktopVaultSource', () {
      for (final kind in const [VaultRefKind.path, VaultRefKind.appManaged]) {
        final src = resolveVaultSource(VaultRef(kind, '/tmp/deck'));
        expect(src, isA<DesktopVaultSource>());
        expect((src as DesktopVaultSource).rootPath, '/tmp/deck');
      }
    });

    test('resolveVaultSource throws for the native external kinds (fill-in)',
        () {
      expect(
        () =>
            resolveVaultSource(const VaultRef(VaultRefKind.iosBookmark, 'b64')),
        throwsUnsupportedError,
      );
      expect(
        () => resolveVaultSource(
            const VaultRef(VaultRefKind.androidTree, 'content://x')),
        throwsUnsupportedError,
      );
    });

    test('value equality', () {
      expect(const VaultRef(VaultRefKind.path, '/a'),
          const VaultRef(VaultRefKind.path, '/a'));
      expect(const VaultRef(VaultRefKind.path, '/a'),
          isNot(const VaultRef(VaultRefKind.appManaged, '/a')));
    });
  });
}
