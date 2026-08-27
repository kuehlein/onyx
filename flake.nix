{
  description = "Onyx — knowledge graph flashcard app";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            flutter   # dart is bundled
            lefthook  # git hooks runner
            sqlite    # host libsqlite3 for drift tests (device uses sqlite3_flutter_libs)

            # Linux desktop build toolchain — a dev-only convenience so the app
            # can be previewed in a native window here without a Mac round-trip.
            # None of this ships in the iOS bundle; iOS is the real target.
            clang
            cmake
            ninja
            pkg-config
            gtk3
            gsettings-desktop-schemas  # GSettings schemas GTK reads at runtime
            libsecret                  # flutter_secure_storage_linux links libsecret-1
            libsysprof-capture         # provides sysprof-capture-4.pc (glib's private dep)
            pcre2                      # provides libpcre2-8.pc (glib's private dep)
          ];

          shellHook = ''
            echo "Onyx dev shell"
            flutter --version 2>/dev/null | head -1 || true
            # drift's NativeDatabase dlopen's libsqlite3.so by name during `flutter test`;
            # Nix has no /usr/lib, so put it on the loader path explicitly.
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.sqlite ]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            # GTK finds its GSettings schemas / icons via XDG_DATA_DIRS at runtime;
            # without this the desktop preview aborts on a missing-schema error.
            export XDG_DATA_DIRS="${pkgs.gtk3}/share:${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}''${XDG_DATA_DIRS:+:$XDG_DATA_DIRS}"
            # Dev convenience: point the app at the staged cards so the desktop
            # preview shows the full set without setting this each run. A manual
            # ONYX_VAULT_PATH wins; on device the path comes from Settings.
            export ONYX_VAULT_PATH="''${ONYX_VAULT_PATH:-$PWD/staging/flashcards}"
            if [ -d .git ]; then
              lefthook install --force 2>/dev/null || true
            fi
          '';
        };
      }
    );
}
