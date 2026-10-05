# Flake interface for the libpng SDK.
#
# Portable counterpart to devenv.nix. Both call ./package.nix, so the package a
# flake builds and the package devenv builds are the same derivation; this file
# only decides which systems are exposed and which variants of that derivation
# they get.
#
# Canonical development is `devenv shell` (see devenv.nix and .envrc). This
# flake exists so the SDK can be built and consumed off this host. `nix develop`
# here is parity, not the canonical entry point, and it deliberately does not
# build the SDK: entering a shell must not require building a library.
#
# flake.lock is not written here: the driver owns locks, and the nixpkgs revision
# below is the pin that lock would record.
#
# SPDX-License-Identifier: MIT

{
  description = "libpng 1.6.59, the PNG Reference Library, packaged for Zig 0.16";

  inputs = {
    # Copied verbatim from the sibling Lua SDK's flake input. The revision is not
    # invented and not re-derived here; it is a pin this package shares with the
    # rest of the workspace so one `nix build` resolves one nixpkgs.
    nixpkgs.url = "github:NixOS/nixpkgs/c7def046b9a883d46974757852106483d741586f";
  };

  outputs = { self, nixpkgs }:
    let
      # Both linkages are real for libpng: src/Makefile.am:125 installs
      # libpng16.la and src/Makefile.am:178-180 gives it -version-number
      # 16:59:0, so upstream's own build produces a shared object as well as an
      # archive. Static is still this fork's default and `.default` stays that
      # way, because an archive is what a linked consumer usually wants.
      #
      # These are Unix systems only, which is the same boundary package.nix
      # asserts: it builds for the compiler's native target rather than
      # hand-building a cross triple. Documented in README.md, not worked
      # around here.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
        "x86_64-freebsd"
      ];

      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs:
        let
          mk = linkage: pkgs.callPackage ./package.nix {
            inherit linkage;
            zig = pkgs.zig_0_16;
          };
        in
        {
          static = mk "static";

          # A separate variant of the same derivation, not a second SDK.
          # "shared" names the artefact; the flag it passes is Zig's own
          # `-Dlinkage=dynamic`, which emits libpng16.so.16.59.0 with soname
          # libpng16.so.16 (src/png.h:281 is where the 16 comes from).
          shared = mk "dynamic";

          default = mk "static";
        });

      # Parity only. The canonical development environment is devenv.nix.
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.zig_0_16 pkgs.gnumake pkgs.pkg-config ];
        };
      });
    };
}