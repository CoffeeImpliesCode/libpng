# Source-only package derivation for the libpng SDK.
#
# One file, consumed by both flake.nix and devenv.nix, so the two entry points
# cannot describe different packages. It builds nothing but this repository: the
# native source is upstream's `src/`, which is the complete libpng 1.6.59 release
# tarball imported whole, and build.zig owns every compile flag, the generated
# pnglibconf.h and the whole installed layout. Nothing here restates a C flag,
# fetches a tarball, reaches into a sibling checkout by hand, or installs an
# artifact of its own. The one edit it makes is the rpath of the ELF files the
# build installed: Zig records its own build cache there, and that directory
# does not exist once a binary is installed.
#
# The one sibling dependency is declared by build.zig.zon, not here: `.zlib`
# resolves through the relative path `../zlib`, and package.nix must not restate
# it or the two places could disagree about which zlib is used.
#
# No lock file is written here. `flake.lock` and `devenv.lock` belong to the
# driver.
#
# SPDX-License-Identifier: MIT
# See FORK-LICENSE.md for what that identifier covers, and NOTICE.md for the
# per-file inventory of the upstream material this package ships. Note that
# libpng is NOT MIT: the compiled core is under the PNG Reference Library
# License version 2 (src/LICENSE:4), and `meta.license` below says so rather
# than picking the term that would have been convenient.

{ lib
, stdenv
, zig
, patchelf
    # Zig's own `std.builtin.LinkMode` spelling, passed straight through as
    # `-Dlinkage`. "static" and "dynamic" are two variants of one derivation, and
    # `""` passes nothing at all so the SDK's own default policy runs unchanged.
    # Both linkages are real for libpng: src/Makefile.am:125 installs
    # libpng16.la and src/Makefile.am:178-180 gives it `-version-number
    # 16:59:0`, so the shared form is libpng16.so.16.59.0 with soname
    # libpng16.so.16, exactly as upstream's libtool build produces.
  , linkage ? "static"
  , optimize ? "ReleaseSafe"
  }:

  let
    requestedLinkage =
      if builtins.elem linkage [ "" "static" "dynamic" ] then linkage
      else throw "package.nix: linkage must be \"\", \"static\" or \"dynamic\", not ${toString linkage}";

  # Everything except build outputs, version control and developer-tool state.
  # Filtering by directory name rather than by an allow list means a file added
  # here later is packaged without editing this file, while `.zig-cache/`,
  # `zig-out/`, `.devenv/`, `.direnv/` and `result` stay out of a published
  # output at any depth, including under consumer/. The vendored upstream tree
  # is deliberately kept whole: all 614 files, including upstream's own test
  # programs, CI definitions and per-architecture intrinsics sources, which are
  # digested in UPSTREAM.sha256 and are the audit surface.
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

  # patchelf rewrites ELF rpaths and does not read Mach-O, so the rpath
  # normalisation in the install phase exists for ELF targets only, and the tool
  # is a build input exactly where that code runs.
  isElfTarget = !stdenv.hostPlatform.isDarwin;
  in

  # These packages build for the compiler's own native target. A cross build here
  # would mean hand-building a libc-suffixed triple that has to track nixpkgs, so
  # this derivation refuses one instead of silently producing a host-architecture
  # library under a foreign name. The comparison is against stdenv's own
  # platforms, which are pure values; `builtins.currentSystem` is not evaluable
  # in a sandbox and is not used. A remote builder is unaffected: this compares
  # build against host, not against any particular machine.
  assert stdenv.buildPlatform.system == stdenv.hostPlatform.system;

  stdenv.mkDerivation {
    pname = "libpng";
    version = "1.6.59";

    inherit src;

    strictDeps = true;
    dontPatch = true;

    # The real work is one `zig build install` in installPhase below. Disabling
    # configure and build phases keeps the Zig setup hook from running a first,
    # differently-flagged build of its own; `dontInstall` is deliberately NOT set,
    # because that is what would disable the real install phase.
    dontConfigure = true;
    dontBuild = true;

    nativeBuildInputs = [ zig ] ++ lib.optional isElfTarget patchelf;

    # libpng is a zlib binding: src/pngpriv.h and src/png.c include <zlib.h> and
    # call inflateInit2_/deflateInit2_ and friends, so the 16 C units do not
    # compile without a zlib on the include line and the archive does not link
    # without one to resolve those names. zlib itself is NOT listed here: it is
    # a package dependency resolved by build.zig.zon's relative path, and adding
    # a second declaration would create a second place for it to be wrong.
    propagatedBuildInputs = [ stdenv.cc.libc ];

    # The driver owns every gate for this SDK, and a Nix build is not a
    # verification receipt. No check phase is declared here rather than a check
    # phase that runs something smaller than the real gates; the commands that do
    # verify this package are in README.md and CHANGELOG.md.
    doCheck = false;
    dontUseZigCheck = true;

    installPhase = ''
      runHook preInstall

      # Both caches go under the Nix-provided TMPDIR, outside the unpacked source
      # tree, so a build cannot write into $src and so two parallel derivations
      # cannot share state. Any caller-supplied cache variables are left alone:
      # they are the caller's scratch, not this file's to clear.
      export ZIG_LOCAL_CACHE_DIR="$TMPDIR/zig-local-cache"
      export ZIG_GLOBAL_CACHE_DIR="$TMPDIR/zig-global-cache"

      # build.zig owns the source list (the 16 units of src/Makefile.am:127-129),
      # the generated pnglibconf.h, the C flags, the libpng16.pc file, the
      # pkg-config contents and every installed path. Declaring any of them here
      # as well would create a second place where they can disagree with the
      # build graph.
      zig build install \
        --prefix "$out" \
        -j"''${NIX_BUILD_CORES:-1}" \
        -Doptimize=${optimize} \
        -Dcpu=baseline \
        ${lib.optionalString (requestedLinkage != "") "-Dlinkage=${requestedLinkage}"}

      # Zig records the build cache in the rpath of anything that links a dynamic
      # artifact it has just built (lib/std/Build/Step/Compile.zig:1192-1199), so
      # an installed binary names a directory that is gone, and Nix rejects an
      # installed file that names its build directory at all. Both Zig caches above
      # are under $TMPDIR, so dropping those entries and no other removes it: the
      # $ORIGIN/../lib build.zig adds, and every store path a real dependency
      # needs, stay. Symlinks are resolved first so a soname link is rewritten
      # through to the object and never replaced by a copy of it.
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

    # The layout this derivation produces is the build graph's, not this file's:
    # $out/include/libpng16/{png.h,pngconf.h,pnglibconf.h} (src/Makefile.am:206-207
    # installs into $(includedir)/$(PNGLIB_BASENAME), which is libpng16),
    # $out/lib/libpng16.a (or libpng16.so.16.59.0 with the libpng16.so.16 soname
    # link and the libpng16.so linker name), $out/lib/pkgconfig/libpng16.pc
    # (src/Makefile.am:212), $out/share/man with libpng.3, libpngpf.3 and png.5
    # (src/Makefile.am:117), and $out/share/licenses with upstream's LICENSE and
    # this fork's records. Both variants keep it; only the artifact kind differs.
    # Nothing is copied or generated by hand here, so `zig build install --prefix
    # $out` and `nix build` produce one layout by construction rather than two
    # that have to be kept in agreement.

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
      # NOT mit. The compiled core is under the PNG Reference Library License
      # version 2 (src/LICENSE:4), a permissive grant with its own conditions,
      # and this attribute must not name a different one. Two subtrees of the
      # vendored tree carry other terms -- ci/** is MIT and
      # .github/workflows/** is MIT-0 (src/REUSE.toml:3-9) -- and
      # src/example.c is public domain by upstream's own dedication, so no
      # single label can describe the tree.
      #
      # `lib.licenses.mit` would be wrong for the core and
      # `lib.licenses.unfree` would be wrong too: this is not copyleft, not
      # source-disclosable and not restricted. `other` is used because nixpkgs'
      # own set has no identifier for the PNG Reference Library License, and a
      # generic placeholder plus this comment is more honest than a precise
      # wrong answer. The authoritative term is in NOTICE.md, per file.
      license = lib.licenses.other;
      platforms = lib.platforms.unix;
    };
  }