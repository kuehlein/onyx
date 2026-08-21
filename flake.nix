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
          ];

          shellHook = ''
            echo "Onyx dev shell"
            flutter --version 2>/dev/null | head -1 || true
            # drift's NativeDatabase dlopen's libsqlite3.so by name during `flutter test`;
            # Nix has no /usr/lib, so put it on the loader path explicitly.
            export LD_LIBRARY_PATH="${pkgs.lib.makeLibraryPath [ pkgs.sqlite ]}''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
            if [ -d .git ]; then
              lefthook install --force 2>/dev/null || true
            fi
          '';
        };
      }
    );
}
