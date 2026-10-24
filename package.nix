# SPDX-License-Identifier: MIT
# The compiled core uses the PNG Reference Library License (`src/LICENSE:4`).

{ lib
, stdenv
, zig
, fetchFromGitHub
, patchelf
, zlibSrc ? fetchFromGitHub {
    owner = "CoffeeImpliesCode";
    repo = "zlib";
    rev = "797ee44eb7ba765c0a8efd81cd482315448b4586";
    hash = "sha256-F97nOXPkAr/r52ndLL5/iF88qLKZ+tHgz0U13lGTJtM=";
  }
  , linkage ? "static"
  , optimize ? "ReleaseSafe"
  }:

  let
    requestedLinkage =
      if builtins.elem linkage [ "" "static" "dynamic" ] then linkage
      else throw "package.nix: linkage must be \"\", \"static\" or \"dynamic\", not ${toString linkage}";

  src = lib.cleanSourceWith {
    src = ./.;
    filter = path: _type:
      let name = builtins.baseNameOf (toString path); in
      !(lib.elem name [
        ".git"
        ".direnv"
        ".devenv"
        ".zig-cache"
        "zig-cache"
        "zig-pkg"
        "zig-out"
        "result"
      ]);
  };

  # patchelf handles ELF rpaths, not Mach-O.
  isElfTarget = !stdenv.hostPlatform.isDarwin;
  in

  # Build only for the native compiler target.
  assert stdenv.buildPlatform.system == stdenv.hostPlatform.system;

  stdenv.mkDerivation {
    pname = "libpng";
    version = "1.6.59";

    inherit src;

    strictDeps = true;
    dontPatch = true;

    # Run the package install step; keep Nix's install phase enabled.
    dontConfigure = true;
    dontBuild = true;

    nativeBuildInputs = [ zig ] ++ lib.optional isElfTarget patchelf;

    propagatedBuildInputs = [ stdenv.cc.libc ];

    doCheck = false;
    dontUseZigCheck = true;

    installPhase = ''
      runHook preInstall

      # Keep Zig caches outside the source tree.
      export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
      export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"
      mkdir -p "$ZIG_GLOBAL_CACHE_DIR/p"
      cp -r --no-preserve=mode ${zlibSrc} "$ZIG_GLOBAL_CACHE_DIR/p/zlib-1.3.2-cRllmzjYOwBhITM-YZxiVxQp2TMHncrQGwj3tCUHG37h"

      # build.zig owns the compile flags and install layout.
      zig build install \
        --prefix "$out" \
        -j"''${NIX_BUILD_CORES:-1}" \
        -Doptimize=${optimize} \
        -Dcpu=baseline \
        ${lib.optionalString (requestedLinkage != "") "-Dlinkage=${requestedLinkage}"}

      # Remove Zig cache rpaths from installed ELF files.
      # Keep `$ORIGIN` and dependency store paths.
      ${lib.optionalString isElfTarget ''
        for elf in "$out"/bin/* "$out"/lib/*.so*; do
          [ -f "$elf" ] || continue
          elf=$(readlink -f "$elf")
          rpath=$(patchelf --print-rpath "$elf") || rpath=""
          kept=""
          rest=$rpath
          while [ -n "$rest" ]; do
            entry="''${rest%%:*}"
            case "$entry" in
              "$TMPDIR"/*) ;;
              *) if [ -z "$kept" ]; then kept=$entry; else kept=$kept:$entry; fi ;;
            esac
            if [ "$entry" = "$rest" ]; then rest=""; else rest="''${rest#*:}"; fi
          done
          [ "$kept" = "$rpath" ] || patchelf --set-rpath "$kept" "$elf"
        done
      ''}

      runHook postInstall
    '';


    enableParallelBuilding = true;

    meta = {
      description = "libpng 1.6.59, the PNG Reference Library, built from the official release sources";
      longDescription = ''
        The complete libpng 1.6.59 release source -- the 16-unit portable C
        core, the public headers, the generated pnglibconf.h, the per-architecture
        intrinsics sources and upstream's manuals -- compiled from the tarball's
        own src/ directory with Zig, with no CMake, no autotools and no
        build-time download. Ships libpng16.a or libpng16.so.16.59.0 with
        soname libpng16.so.16, the headers under include/libpng16/, a
        libpng16.pc and the three man pages.

        No SIMD is compiled: every PNG_*_OPT macro is undefined and no file under
        arm/, intel/, mips/, powerpc/, loongarch/ or riscv/ is in the build
        graph. That is a deliberate configuration, documented in README.md, and
        it means this is the portable C configuration rather than libpng's
        full-speed x86 configuration. No parity with the latter is claimed.
      '';
      license = lib.licenses.libpng2;
      platforms = lib.platforms.unix;
    };
  }