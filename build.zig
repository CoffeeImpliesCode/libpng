// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md for what that identifier covers.
//
//! Zig 0.16 build for libpng 1.6.59.
//!
//! **No gate has been run for this package.** Nothing below is a verified
//! result: every statement about what this graph produces is a
//! `SOURCE-CONFIRMED` reading of a file in `src/` or a `CONSTRAINT` this file
//! states on purpose, and the first `zig build`, `zig build test`,
//! `zig build smoke`, `zig build consumer` and `zig build check` runs are what
//! move any of it to `PENDING-VERIFICATION` or to a receipt.
//!
//! The library is upstream's own C, byte for byte: the 16 units of
//! `libpng@PNGLIB_MAJOR@@PNGLIB_MINOR@_la_SOURCES` at `src/Makefile.am:127-129`,
//! and nothing else. No `arm/`, `intel/`, `mips/`, `powerpc/`, `loongarch/`
//! or `riscv/` unit is compiled, no assembly of any kind is compiled, and no
//! test program (`pngtest.c`), example (`example.c`) or `contrib/` tool is
//! built. Nothing is downloaded, no make, no CMake and no autotools script is
//! executed, and the default mode compiles from this repository rather than
//! linking an installed copy.
//!
//! Upstream reference: the official `libpng-1.6.59` release tarball, unpacked
//! into `src/`. The version is read out of `src/png.h:277`
//! (`PNG_LIBPNG_VER_STRING "1.6.59"`), `src/png.h:286-288`
//! (`PNG_LIBPNG_VER_MAJOR 1`, `MINOR 6`, `RELEASE 59`) and `src/png.h:319`
//! (`PNG_LIBPNG_VER 10659 /* 1.6.59 */`). The release digest belongs in
//! `UPSTREAM.md`, which the fork's provenance owner writes; this script does
//! not restate one.
//!
//! Entry points
//! -----------
//!   zig build           install the library, the three public headers, the
//!                        `libpng16.pc`, the three man pages and the licence
//!                        and provenance records; and compile the example
//!   zig build test      run the behavioural tests for the selected target
//!                        (`-Dtarget`; the host when it is absent)
//!   zig build smoke     run the example program
//!   zig build consumer  build the separate `consumer/` package, and run it when
//!                        this host can execute the selected target
//!   zig build check     compile the native library, the facade, the tests and
//!                        the example for the six check targets, running
//!                        nothing
//!
//!   cross-test       the same `test` step, for the published 53-platform
//!                   Zig 0.16.0 Tier 1/2 table rather than the host alone.
//!                   `cross-test` discovers `cross-test.profile.sh` from the
//!                   package root, runs `zig build test -Dtarget=TARGET` for
//!                   each of them, and executes the binary where a runner
//!                   exists and records explicit `build_only` coverage where
//!                   one does not.
//!
//! Options
//! -------
//!   -Dlinkage=static   a static archive, `libpng16.a`. This is the default.
//!   -Dlinkage=dynamic  a real shared object, `libpng16.so.16.59.0` with
//!                      `libpng16.so.16` beside it, PIC on every constituent,
//!                      and an ELF export surface of exactly the `png_*`
//!                      namespace. The version numbers are upstream's own; see
//!                      "Static and shared delivery" below.
//!   -Druntime=true     resolve the native entry points at run time instead of
//!                      linking them. Orthogonal to `-Dlinkage`, which still
//!                      decides which artifact this build delivers and
//!                      installs. Default off; a linked build is unchanged.
//!   -Dsystem=true      refused, not honoured. See "System mode is vacuous here"
//!                      below. It supplies the default of
//!                      `b.systemIntegrationOption("png16", ...)`, and either
//!                      spelling that selects it stops the build before a
//!                      compiler is invoked.
//!   -Dtarget=<triple>  build for one target; `zig build check` then checks
//!                      that target only instead of the whole matrix.
//!   -Doptimize=<mode>  the caller's mode, passed to every graph below.
//!
//! System mode is vacuous here
//! --------------------------
//! AGENTS.md §4 (`WISDOM.md` W14) requires a system mode to link a real
//! installed library *and translate the headers it links*, and it says what a
//! fork without one must write: "A fork with no system mode records the rule as
//! vacuous, not satisfied." So that is what this is, stated here rather than
//! papered over with a flag that does nothing.
//!
//! The rule is vacuous for a substantive reason, not for convenience. This
//! package's declarations are not one header: `src/png.h:328` includes the
//! *generated* `pnglibconf.h` and `src/png.h:333` includes `pngconf.h`, and
//! `pnglibconf.h` is a configure-time product. A system mode would have to
//! translate the installed `pnglibconf.h` next to the installed `png.h`, from
//! the same prefix, and confirm that its `PNG_ZLIB_VERNUM`
//! (`src/pngpriv.h:1026-1028`) matches the zlib that prefix links - a
//! confirmation no `b.dependency` performs. Bundling this tree's own
//! `src/png.h` against an older installed libpng is exactly the silent-ABI
//! failure the rule names. So the honest answer is not implemented, and
//! `-Dsystem=true` (or a runner's `-fsys=png16`) is a refusal: `build` prints
//! the reason through `std.log.err` and stops. It is not a silent no-op and
//! not a fallback to the bundled tree, because both of those would report a
//! system-mode build that never happened.
//!
//! The generated `pnglibconf.h`
//! ---------------------------
//! `pnglibconf.h` is a configure-time input, not a source file: `png.h`
//! includes it at `:328`, `pngpriv.h` includes it at `:81`, and upstream lists
//! it as a `nodist_` source (`src/Makefile.am:176`) and a `nodist_` installed
//! header (`src/Makefile.am:207`) because it is built, not shipped. So it is
//! produced by a build step from this repository, never checked in and never
//! written into `src/`.
//!
//! Upstream has two ways to produce it, and this package takes the second.
//! `src/Makefile.am:345-352` runs `scripts/options.awk` twice over the `.dfa`
//! files (`:347` and `:350`) to produce `pnglibconf.out`; the generic `.c.out`
//! rule at `src/Makefile.am:335-341` runs `scripts/dfn.awk` (`:340`) for the
//! per-symbol `prefix.out` list. The CMake wiring for the same three
//! scripts is `src/CMakeLists.txt:488-518`, and whether it runs at all depends
//! on `src/CMakeLists.txt:439` (`find_program(AWK NAMES gawk nawk awk)`). When
//! that probe finds nothing, upstream copies its own prebuilt file:
//! `src/CMakeLists.txt:457-462` is the `# No AWK program available to generate
//! pnglibconf.h` arm, and it `configure_file`s
//! `scripts/pnglibconf.h.prebuilt` into the binary directory. Autotools says
//! the same in prose at `src/Makefile.am:295-300`, and adds "AND set
//! PNG_ZLIB_VERNUM to 0 (you MUST do this)".
//!
//! That branch is this package's branch, and it is taken for a reason of
//! portability rather than preference: an AWK program is a host toolchain
//! dependency this build graph does not acquire, and the generated header
//! would then depend on whatever AWK implementation the build machine happens
//! to have. `tools/pnglibconf.zig` is the host program that reads
//! `src/scripts/pnglibconf.h.prebuilt`, validates the release banner and the
//! include guard, and writes the bytes out unchanged - so the generated
//! `pnglibconf.h` is byte-identical to the vendored prebuilt file, and the
//! vendored file remains the record of the configuration.
//!
//! What that costs is one thing, and it is a compile-time check rather than
//! behaviour: `src/scripts/pnglibconf.h.prebuilt:226` is
//! `#define PNG_ZLIB_VERNUM 0 /* unknown */`, and `src/pngpriv.h:1026-1028`
//! uses that only to skip
//! `#if PNG_ZLIB_VERNUM != 0 && PNG_ZLIB_VERNUM != ZLIB_VERNUM` / `# error The
//! include path of <zlib.h> is incorrect`. With the value at 0 the check does
//! not run; no `png_*` function changes what it does, and the zlib options
//! around it carry their real values. The build's own zlib include path is
//! still fixed (see below), so the mismatch that check would catch is one this
//! build cannot produce.
//!
//! Generated-header placement, for the *target* and on both lines
//! ---------------------------------------------------------------
//! The generated directory is ahead of `b.path("src")` on every C module *and*
//! on the translate-c step, because an installed-style header included by bare
//! name needs its own directory on the path (AGENTS.md §5). The `Run` step's
//! output file lives in the build cache
//! (`Step.Run.addOutputFileArg`, `lib/std/Build/Step/Run.zig:279`) and the
//! directory that file is in is what goes on the include line
//! (`LazyPath.dirname()`, as `spglib/build.zig:888` does for its generated
//! `version.h`). That also is why `build.zig.zon` can name `src` as a bare
//! directory: nothing is ever written inside it.
//!
//! The generator is a host program and the header it writes is
//! target-independent
//! ---------------------------------------------------------------
//! `tools/pnglibconf.zig` is built for `b.graph.host` and reads the vendored
//! prebuilt file by path. Its output does not depend on the target being
//! built, because upstream's prebuilt file carries no target-derived value -
//! `pnglibconf.h` is the same file for every platform, which is precisely why
//! upstream ships it. So there is no host macro that could be copied onto a
//! cross target here, and one `Run` step serves the whole build: its output is
//! the same bytes for every target, and every target's compile line and
//! translation line name its directory.
//!
//! The zlib wire
//! -------------
//! libpng is a zlib binding: `src/pngstruct.h:27` includes `"zlib.h"`, and the
//! 16 units call `inflateInit2_`, `deflateInit2_`, `inflate` and `deflate`
//! through it. The wire is the whole of it:
//!
//!     const zlib_dep = b.dependency("zlib", .{ .target = target, .optimize = optimize });
//!     c_mod.linkLibrary(zlib_dep.artifact("zlib"));
//!
//! and no guessed include path goes with it.
//! `Module.linkLibraryOrObject` (`lib/std/Build/Module.zig:649-659`) appends
//! `.{ .other_step = other }` to the module's `include_dirs`, and
//! `IncludeDir.appendZigProcessFlags` (`:183-184`) renders that as `-I` the
//! linked artifact's own installed-header include tree. So zlib's `zlib.h` and
//! `zconf.h` reach the compile line from the sibling's own tree, with no path
//! this package would have to guess and keep in step with.
//!
//! Nothing is defined for zlib, and the reason is upstream's own value.
//! `src/pngpriv.h:1026-1028` compares `PNG_ZLIB_VERNUM` against
//! `ZLIB_VERNUM` and `#error`s on a mismatch; the prebuilt configuration sets
//! it to 0 (`src/scripts/pnglibconf.h.prebuilt:226`), which disables that one
//! comparison (see above) and needs no `-D`. Nothing else in `src/` reads a
//! zlib macro at configure time, so there is no `-D` to pass.
//!
//! **No system zlib include path may be added, ahead of the sibling's or
//! anywhere else.** `src/pngpriv.h:1028`'s own comment says why: "the -I options
//! must match". A host's `/usr/include` reaching this compile line would put a
//! second `zlib.h` in the search path, and which one wins would then depend on
//! flag order rather than on this build's design. If the sibling ever needs a
//! system zlib, that is a change to the `zlib` package and to this line, made
//! deliberately.
//!
//! The zlib wire is `PENDING-VERIFICATION` and unproven: `../zlib` has no
//! `build.zig` on disk yet at the time of writing, so `b.dependency("zlib", ...)`
//! has not been observed resolving and no `dep.artifact("zlib")` has been
//! observed to exist. The first `zig build` either resolves it or stops with
//! its message.
//!
//! SIMD configuration: none, and that is a stated decision
//! --------------------------------------------------
//! No `PNG_*_OPT` macro is defined on any compile line, and no architecture
//! unit is compiled. The reason is upstream's own source list: the `arm/`,
//! `mips/`, `intel/`, `powerpc/`, `riscv/` and `loongarch/` units are added by
//! `if PNG_ARM_NEON` / `PNG_MIPS_MSA` / `PNG_MIPS_MMI` / `PNG_INTEL_SSE` /
//! `PNG_POWERPC_VSX` / `PNG_RISCV_RVV` / `PNG_LOONGARCH_LSX` blocks at
//! `src/Makefile.am:132-174`, each of which also adds its own `.la` to
//! `_la_LIBADD` (`:165`, `:173`). Those macros are derived inside
//! `src/pngpriv.h:118-313` from the compiler's own predefines - `__ARM_NEON__`
//! and `__ARM_NEON` at `:139`, `__mips_msa` with `__mips_isa_rev` at `:174`,
//! `__powerpc64__` at `:196`, `__loongarch_sx` at `:204` and the RISC-V
//! `__riscv_v` test at `:305` - *and* from `src/pngusr.dfa`, which carries no
//! options at all: the whole file is a comment block.
//!
//! So on a target whose compiler predefines one of those, `pngpriv.h` alone
//! would turn the corresponding optimization on and the link would then fail
//! on `png_read_filter_row_*_neon` or `png_mips_*`, because this package
//! compiles none of those units. Every `PNG_*_OPT` macro is therefore defined
//! to `0` explicitly on the library module, and that is the one place this file
//! uses `addCMacro` for a libpng macro. Each is a documented upstream knob -
//! `src/pngpriv.h:136` names `-DPNG_ARM_NEON_OPT=0` as the way to "disable ARM
//! NEON optimizations entirely, and skip compiling the associated assembler
//! code", and the other six are the same `#ifndef ... #define` block - and
//! `0` is upstream's own "off" value for each of them, not an invented one.
//!
//! No other `addCMacro` is used. There is no platform macro here in the
//! `LUA_USE_*` sense: `src/pngconf.h:182-183` is the `_WIN32` / `__WIN32__` /
//! `__NT__` / `__CYGWIN__` test that opens the Windows calling-convention
//! block, `:198-200` the `__GNUC__` / `_MSC_VER` default outside it,
//! `:225-227` the `__declspec` spellings, and `:255-263` the `PNG_IMPEXP`
//! defaulting - all derived from the target's own predefined macros inside the
//! header, so a compile line has nothing to add for any of the six check
//! targets. See "Windows and `PNG_BUILD_DLL`" below for the one macro that *is*
//! a build-shape question.
//!
//! `PNG_PREFIX` is not defined. `src/pngpriv.h:84-86` is the whole of its
//! effect: `#if defined(PNG_PREFIX) && !defined(PNGPREFIX_H)` / `#  include
//! "pngprefix.h"`. No `pngprefix.h` is generated by this build (upstream's own
//! rule for it is `src/Makefile.am:291-292`, "pngprefix.h: # is empty"), so
//! defining the macro would put a header on the include path that does not
//! exist.
//!
//! Static and shared delivery
//! --------------------------
//! `-Dlinkage` selects which artifact this package produces. Nothing about the
//! compiled C changes between the two: the same 16 units, the same generated
//! `pnglibconf.h`, the same `PNG_*_OPT 0` line, the same zlib wire.
//!
//! The ABI numbers are upstream's. `src/Makefile.am:178-179` is
//! `libpng16_la_LDFLAGS = -no-undefined -export-dynamic` followed by
//! `-version-number @PNGLIB_MAJOR@@PNGLIB_MINOR@:@PNGLIB_RELEASE@:0`, so the
//! libtool `-version-number 16:59:0` is `current:revision:age`, which libtool
//! turns into the file name `libpng16.so.16.59.0` and the soname
//! `libpng16.so.16`. `src/png.h:281` states the same major independently,
//! `PNG_LIBPNG_VER_SHAREDLIB 16`, with the comment "The versions of shared
//! library builds should stay in sync, going forward". `abi_version` below is
//! therefore `{ .major = 16, .minor = 59, .patch = 0 }` and Zig's own
//! `version` field produces exactly those two names.
//!
//! The export surface is the `png_*` namespace and nothing else. Every public
//! declaration in `src/png.h` goes through `PNG_EXPORT` / `PNG_EXPORTA`
//! (`src/pngconf.h:297-298` and `:286-291`), there are 225 `PNG_EXPORT*`
//! occurrences in the header, and every one of them names a function whose
//! name starts with `png_`; there is no other public symbol. The one data
//! object, `png_libpng_ver`, is a macro rather than a symbol
//! (`src/png.h:372`, `#define png_libpng_ver png_get_header_ver(NULL)`), so it
//! needs no separate catalogue entry. An ELF version script exporting `png_*`
//! globally and `*` locally therefore reproduces upstream's restricted export
//! (`src/Makefile.am:186`, `-Wl,--version-script=libpng.vers`) without a
//! generated symbol list that could omit a declaration - and without needing
//! AWK to generate it, which is the same constraint as the header above.
//!
//! Mach-O has no version script that GNU ld or lld reads the same way, so a
//! Darwin shared object from this build exports libpng's internals as well as
//! its API. That is a real difference from the ELF object, it is printed by
//! `build` rather than hidden, and upstream ships no Darwin shared object to
//! match (`src/Makefile.am:412` lists `dylib` among the extensions it builds,
//! but no rule in `src/Makefile.am` produces one for libpng itself).
//!
//! Windows and `PNG_BUILD_DLL`
//! --------------------------
//! `src/pngpriv.h:323-350` derives `PNG_BUILD_DLL` from four host spellings -
//! `DLL_EXPORT` (libtool), `_WINDLL` (Visual Studio), `__DLL__` (Borland) and a
//! comment inviting more cases - and then `:360-368` makes `PNG_IMPEXP`
//! `PNG_DLL_EXPORT` when `PNG_BUILD_DLL` is set and empty when it is not.
//! `src/pngconf.h:225-227` is where `PNG_DLL_EXPORT` is
//! `__declspec(dllexport)` and `PNG_DLL_IMPORT` is `__declspec(dllimport)`,
//! and `:255-263` makes a *consumer* take the import spelling only when the
//! consumer sets `PNG_USE_DLL` and `PNG_DLL_IMPORT`.
//!
//! So this build defines `PNG_BUILD_DLL` on a Windows shared build, and only
//! there. Upstream's own CMake does exactly that and nothing more:
//! `src/CMakeLists.txt:692-694` sets `png_shared`'s `DEFINE_SYMBOL` to
//! `PNG_BUILD_DLL` on `WIN32` (and clears `png_shared_EXPORTS` on Apple,
//! `:688-690`). A static Windows build defines nothing, which is the correct
//! answer on both sides: the library's `PNG_IMPEXP` stays empty
//! (`src/pngpriv.h:363-368`) and a consumer that wants the import spelling
//! sets `PNG_USE_DLL` itself (`src/pngconf.h:255-263`). No module-definition file
//! is written: on COFF, the `__declspec(dllexport)` decoration upstream applies
//! to each of the 225 exported declarations is the export list, and
//! `src/CMakeLists.txt:1215` ("# pexports libpng.dll > libpng.def") is a comment
//! showing a hand-derived `.def` for a build that has no decoration, which is
//! not this one.
//!
//! Installed closure
//! -----------------
//! `zig build` installs, in bundled mode:
//!
//!   * `lib/libpng16.a`, or `lib/libpng16.so.16.59.0` with
//!     `lib/libpng16.so.16` beside it, per `-Dlinkage`.
//!   * `include/libpng16/png.h`, `include/libpng16/pngconf.h` and
//!     `include/libpng16/pnglibconf.h`. The directory is upstream's own:
//!     `src/Makefile.am:205` is `pkgincludedir= $(includedir)/$(PNGLIB_BASENAME)`
//!     and `:10` is `PNGLIB_BASENAME= libpng@PNGLIB_MAJOR@@PNGLIB_MINOR@`, so
//!     the C consumer's include is `<libpng16/png.h>`. The two source headers
//!     are `src/Makefile.am:206` (`pkginclude_HEADERS= png.h pngconf.h`); the
//!     third is `:207` (`nodist_pkginclude_HEADERS= pnglibconf.h`) because it
//!     is generated, and this build installs the bytes the generator produced.
//!   * `lib/pkgconfig/libpng16.pc`, generated from upstream's own template
//!     `src/scripts/libpng.pc.in` by `@VAR@` substitution; see `add_pkg_config`.
//!     The name is upstream's: `src/Makefile.am:212` is
//!     `pkgconfig_DATA = libpng@PNGLIB_MAJOR@@PNGLIB_MINOR@.pc`.
//!   * `share/man/man3/libpng.3`, `share/man/man3/libpngpf.3` and
//!     `share/man/man5/png.5`, the whole of `src/Makefile.am:117`
//!     (`dist_man_MANS= libpng.3 libpngpf.3 png.5`). `libpng-manual.txt` is
//!     *not* installed: `src/Makefile.am:222` lists it in `EXTRA_DIST`, which is
//!     the distribution tarball, not `make install`, and nothing else names it.
//!   * `share/licenses/libpng/` - upstream's `src/LICENSE` (which is the PNG
//!     Reference Library License version 2, `src/LICENSE:4`, *not* MIT),
//!     `src/example.c` (the one file upstream dedicates to the public domain,
//!     `src/example.c:18-19`), `src/REUSE.toml` (the per-path SPDX map,
//!     `:3-9`), and this fork's own records.
//!
//! Published routes
//! ---------------
//!   * `dep.module("libpng")`: the Zig facade, `zig/root.zig`. This is the one
//!     registered module. It carries `link_libc`, the translated headers as
//!     its `c` import, the compiled archive and the include path.
//!   * `dep.artifact("png16")`: the C artifact, installed as
//!     `libpng16.a` / `libpng16.so.16.59.0`. A C consumer of this package that
//!     wants the archive, rather than the Zig facade, names this.
//!
//! The two names differ on purpose. The module name is the package's identity;
//! the artifact name is upstream's ABI name with the leading `lib` left to
//! Zig's `lib` prefix.

const std = @import("std");

/// The runtime-loading build half, owned by the API role.
///
/// `createModule` builds the generated dispatch that replaces
/// `translate.createModule()` under `-Druntime`; it makes the loader-core
/// module itself and re-exports `LoadSource`/`LoadError` from it.
/// `createCoreModule` builds that same core module for the *linked* branch.
///
/// The two branches must not both call `createCoreModule`: `LoadSource` and
/// `LoadError` are this SDK's public types, so they have to be the *same* types
/// in one build. `addGraph` is the only place that calls either of them.
const graph = @import("runtime/graph.zig");

/// `build.zig.zon` itself. `@import` of the manifest is how a build script
/// reads `.version` without a second copy of it.
const manifest = @import("build.zig.zon");

/// `build.zig.zon .version`, parsed. The parse is the loud part: a manifest
/// whose `.version` is not a semantic version fails to configure here rather
/// than being silently compared as something else.
const manifest_version = std.SemanticVersion.parse(manifest.version) catch
    @panic("build.zig.zon: .version is not a semantic version");

/// The Zig facade. It re-exports the translated module as `c`.
const facade_source = "zig/root.zig";

/// The one header this package translates. It is a fork-authored wrapper whose
/// whole job is to name the three public headers; see the file for why it is a
/// wrapper and not a copy.
const translate_header = "zig/translate.h";

/// Test root, owned by the API role.
const test_source = "tests.zig";

/// The deterministic example program, owned by the API role.
const example_source = "smoke.zig";

/// The host generator for `pnglibconf.zig`. Fork-authored; see the file.
const generator_source = "tools/pnglibconf.zig";

/// The vendored prebuilt configuration header the generator reads. Upstream's
/// own no-AWK input, `src/CMakeLists.txt:457-462`.
const prebuilt_libconf = "src/scripts/pnglibconf.h.prebuilt";

/// Where the native source lives. `src/png.h:333` includes `"pngconf.h"` and
/// `src/pngpriv.h:81` includes `"pnglibconf.h"`, both by quoted bare name, so
/// one include path given to every C compilation and to the translation is
/// what keeps all of it resolvable.
const source_dir = "src";

/// Package id, the name a dependent writes in its dependency map, and the one
/// registered module: `dep.module("libpng")`. All three are `libpng`.
const lib_name = "libpng";

/// The C artifact name: `dep.artifact("png16")`.
///
/// Upstream states the ABI name, not the artifact name: `src/Makefile.am:125`
/// is `lib_LTLIBRARIES=libpng@PNGLIB_MAJOR@@PNGLIB_MINOR@.la`, which for
/// `@PNGLIB_MAJOR@ 16` and `@PNGLIB_MINOR@ 6` is `libpng16.la`.
///
/// Zig prepends the platform's `lib` prefix to an artifact name, so an artifact
/// called `png16` emits `libpng16.a` and `libpng16.so.16.59.0` - the two names
/// a C consumer's `-lpng16` needs and upstream's own `Libs:` field asks for
/// (`src/scripts/libpng.pc.in`, `Libs: -L${libdir} -lpng16`). Naming the
/// artifact `libpng16` instead would emit `liblibpng16.a`, which is why the two
/// constants above are different strings on purpose.
const artifact_name = "png16";

/// The sibling's package name in `build.zig.zon .dependencies` and in
/// `b.dependency`. Fixed for this wave: `dep.module("zlib")`, and its C
/// artifact is also `zlib`.
const zlib_package = "zlib";

/// Upstream's version, read out of `src/png.h:277` and `:286-288`, and
/// cross-checked against `:319`. `build` refuses to configure when it and
/// `build.zig.zon .version` disagree, so the manifest, the pkg-config
/// `Version:` field, the shared object's file name and the generated
/// `pnglibconf.h` banner cannot describe four different releases.
const upstream_version: std.SemanticVersion = .{ .major = 1, .minor = 6, .patch = 59 };

/// The shared object's ABI version. `src/Makefile.am:178-179`:
/// `-version-number @PNGLIB_MAJOR@@PNGLIB_MINOR@:@PNGLIB_RELEASE@:0`, which
/// libtool reads as `current:revision:age` and turns into
/// `libpng16.so.{current}.{age}` plus `libpng16.so.{current}`. `current` is
/// `16` because `src/png.h:281` says `PNG_LIBPNG_VER_SHAREDLIB 16`.
const abi_version: std.SemanticVersion = .{ .major = 16, .minor = 59, .patch = 0 };

/// The 16 translation units of `libpng@PNGLIB_MAJOR@@PNGLIB_MINOR@_la_SOURCES`
/// (`src/Makefile.am:127-129`), in upstream's order.
///
/// The list is copied from upstream's, not derived, and nothing is added to it:
/// no architecture unit from `arm/`, `intel/`, `mips/`, `powerpc/`,
/// `loongarch/` or `riscv/` (each behind its own `if PNG_*_OPT` block at
/// `src/Makefile.am:132-174`), no `pngtest.c` (`src/Makefile.am:42`, the first
/// `check_PROGRAMS` entry's source) and no `example.c`
/// (`src/Makefile.am:222`, an `EXTRA_DIST` entry), and nothing under
/// `contrib/`.
const core_sources = [_][]const u8{
    "src/png.c",
    "src/pngerror.c",
    "src/pngget.c",
    "src/pngmem.c",
    "src/pngpread.c",
    "src/pngread.c",
    "src/pngrio.c",
    "src/pngrtran.c",
    "src/pngrutil.c",
    "src/pngset.c",
    "src/pngtrans.c",
    "src/pngwio.c",
    "src/pngwrite.c",
    "src/pngwtran.c",
    "src/pngwutil.c",
};

/// The `PNG_*_OPT` macros this build defines to `0`, with the `src/pngpriv.h`
/// line that derives each one.
///
/// Each is upstream's own knob and `0` is upstream's own "off" value:
/// `src/pngpriv.h:142` is the `#define PNG_ARM_NEON_OPT 0` arm, and every
/// other block at `:157`, `:176-191`, `:197-199`, `:205-207`, `:220-225` ends
/// in the same `#define ..._OPT 0` fallback. See the module comment under "SIMD
/// configuration" for why they are defined at all.
const simd_opt_macros = [_][]const u8{
    "PNG_ARM_NEON_OPT",
    "PNG_INTEL_SSE_OPT",
    "PNG_MIPS_MSA_OPT",
    "PNG_MIPS_MMI_OPT",
    "PNG_POWERPC_VSX_OPT",
    "PNG_LOONGARCH_LSX_OPT",
    "PNG_RISCV_RVV_OPT",
};

/// The three public headers upstream installs.
///
/// `src/Makefile.am:206` is `pkginclude_HEADERS= png.h pngconf.h` and `:207` is
/// `nodist_pkginclude_HEADERS= pnglibconf.h`; the third is generated, and
/// `public_headers` says so in its own type rather than carrying a path this
/// build cannot hand to `b.path` at configure time.
const PublicHeader = struct {
    /// Where the bytes come from.
    source: []const u8,
    /// The name it is installed under.
    basename: []const u8,
    /// True when the bytes are the generator's output rather than a source
    /// file. Only `pnglibconf.h`: `src/Makefile.am:207` lists it as `nodist_`.
    generated: bool,
};

/// The installed header set, into `include/libpng16/`.
const public_headers = [_]PublicHeader{
    .{ .source = "src/png.h", .basename = "png.h", .generated = false },
    .{ .source = "src/pngconf.h", .basename = "pngconf.h", .generated = false },
    .{ .source = "pnglibconf.h", .basename = "pnglibconf.h", .generated = true },
};

/// One manual page: the source file and the directory automake installs it in.
///
/// `src/Makefile.am:117` is `dist_man_MANS= libpng.3 libpngpf.3 png.5`, and
/// automake's `man_MANS` rule puts a `.3` file in `$(man3dir)` and a `.5` file
/// in `$(man5dir)`. `libpng-manual.txt` is deliberately absent: it is in
/// `EXTRA_DIST` (`src/Makefile.am:222`), which is the distribution tarball and
/// not `make install`.
const ManPage = struct {
    /// The vendored file.
    source: []const u8,
    /// `man3` or `man5`, from the file name's own suffix.
    section: []const u8,
};

/// The three manual pages upstream installs.
const man_pages = [_]ManPage{
    .{ .source = "src/libpng.3", .section = "man3" },
    .{ .source = "src/libpngpf.3", .section = "man3" },
    .{ .source = "src/png.5", .section = "man5" },
};

/// The licence and provenance records `zig build` installs under
/// `share/licenses/libpng/`.
///
/// `src/LICENSE` is upstream's own grant and it is *not* MIT: `src/LICENSE:4`
/// is `PNG Reference Library License version 2`. It installs under its own
/// name so that a package which ships the binary and neither text has removed
/// an obligation a private repository does not remove.
///
/// `src/example.c` installs with them even though no part of it is compiled,
/// because `src/example.c:18-19` dedicates that one file to the public domain
/// and a per-file term has to travel with the tree it covers.
///
/// `src/REUSE.toml` is the per-path SPDX map (`src/REUSE.toml:3-9` maps `ci/**`
/// to MIT and `.github/workflows/**` to MIT-0), so it is the file that says
/// which grant applies to which part of the vendored tree.
const licence_records = [_][]const u8{
    "src/LICENSE",
    "src/example.c",
    "src/REUSE.toml",
    "README.upstream.md",
    "NOTICE.md",
    "FORK-LICENSE.md",
    "UPSTREAM.md",
    "UPSTREAM.sha256",
    "FORK-NOTES.md",
    "CHANGELOG.md",
};

/// Language level for every C translation unit, pinned.
///
/// Upstream names no C standard on its compile line: `src/Makefile.am:238-239`
/// is `PNG_COPTS = @PNG_COPTS@` feeding `AM_CFLAGS = ${PNG_COPTS}`, i.e.
/// whatever the user passes to `configure`. libpng states its own requirement
/// in the source instead: `src/pngconf.h:25` is "From libpng 1.6.0 libpng
/// requires an ANSI X3.159-1989 (\"ISOC90\") compliant C compiler for correct
/// compilation", and `:33-34` repeats it for the library headers it needs.
/// ISOC90 is C89.
///
/// So gnu99 is pinned, not because upstream asks for it - upstream asks for
/// C89 and names no flag at all - but so that the language level is a fact of
/// this build rather than of the host compiler's default. Nothing here
/// *requires* C99; the point is that two builds of this tree do not differ in
/// language level. If the driver observes a unit that needs a later level, or a
/// toolchain that rejects one here, the change is to this one list and to the
/// sentence above, which then has to say why it moved.
const c_flags = [_][]const u8{"-std=gnu99"};

/// The cross-compilation matrix `check` walks when no target is named. The
/// order is this workspace's order and nothing is skipped.
///
/// No row is refused, and one of them is now known not to compile. `wasm32-wasi`
/// was an open risk until 2026-10-05, when the first `zig build check` observed
/// it: `src/pngconf.h:48-50` includes `<setjmp.h>` under
/// `PNG_SETJMP_SUPPORTED`, and the pinned toolchain's wasi-libc refuses to
/// declare `setjmp` unless `__wasm_exception_handling__` is defined -
/// `libc/include/wasm-wasi-musl/setjmp.h:13` raises `#error` saying exactly
/// that. Both halves of the row fail there, and `FORK-NOTES.md` section 5
/// carries the message, the include trace and what would have to change.
///
/// The row stays in this list so that the failure is reported on every
/// `zig build check` instead of the target quietly disappearing from the
/// matrix. No configuration in this build graph can reach it:
/// `src/scripts/pnglibconf.h.prebuilt:113` defines `PNG_SETJMP_SUPPORTED`
/// unconditionally and `tools/pnglibconf.zig` must reproduce that vendored
/// header byte for byte, so a `-DPNG_SETJMP_SUPPORTED=0` on the compile line
/// would be redefined by the header on the next line.
const check_targets = [_]std.Target.Query{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .macos, .abi = .none },
    .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    .{ .cpu_arch = .riscv64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .wasm32, .os_tag = .wasi },
};

/// The rows `check` does not walk because this build refuses them.
///
/// Empty, and that is a checked fact rather than an omission. One platform limit
/// is on record for libpng - `wasm32-wasi`, whose libc has no `setjmp` - and it
/// is recorded as a failing row rather than as a refusal, because a refusal is a
/// cell this build graph never attempts: `addGraph` calls `refusalFor` for every
/// cell, and a refused one prints a reason and stops. A cell that fails keeps
/// failing loudly on every `zig build check` with its cause in `FORK-NOTES.md`
/// section 5, which is a stronger record than a refusal. The list exists so that
/// a future refusal has somewhere to go and so `checkMatrixPartition` fails any
/// build that adds a refusal without saying so in one list.
const refused_check_targets = [_]std.Target.Query{};

/// The name one artifact carries in this build graph.
///
/// The published graph installs `libpng16.a` / `libpng16.so.16.59.0`, which is
/// upstream's name, and a check graph installs nothing, so its artifacts carry
/// the target triple instead: six targets in one build graph would otherwise
/// produce six steps called `png16`, which makes `--summary all` impossible to
/// read.
fn artifactLabel(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    public: bool,
) []const u8 {
    if (public) return artifact_name;
    const triple = target.result.zigTriple(b.allocator) catch @panic("unspellable target");
    return b.fmt("{s}-{s}-{s}", .{ artifact_name, lib_name, triple });
}

/// What one target's build produces.
const Graph = struct {
    /// The C archive. Always present: this graph has no system branch, and
    /// `build` refuses `-fsys=png16` before any graph is configured.
    c_lib: *std.Build.Step.Compile,
    /// The module a dependent imports.
    module: *std.Build.Module,
};

/// The RISC-V float-ABI macro the C compiler predefines and `translate-c` does
/// not, as the `-D` pair `defineCMacro` takes, or null on every other
/// architecture.
///
/// glibc lays out a RISC-V `jmp_buf` for two of the three RISC-V float ABIs and
/// refuses the third. In the pinned toolchain's own headers,
/// `lib/libc/include/riscv-linux-gnu/bits/setjmp.h:32-36` gives the struct
/// twelve callee-saved `double` registers when `__riscv_float_abi_double` is
/// defined, gives it none when `__riscv_float_abi_soft` is, and raises `#error
/// unsupported FLEN` for `__riscv_float_abi_single`, the one ABI left with no
/// layout there. `<setjmp.h>` reaches this package from libpng's own header:
/// `src/png.h:333` includes `pngconf.h`, and `src/pngconf.h:48-50` includes
/// `<setjmp.h>` under `PNG_SETJMP_SUPPORTED`.
///
/// Clang and the translator disagree about that one macro and about nothing
/// else on this path. `zig cc -target riscv64-linux-gnu` predefines
/// `__riscv_float_abi_double`, so libpng's own units compile for that target;
/// `translate-c`, which is Aro, predefines none of the three and stops on the
/// same header at `bits/setjmp.h:35`. Left alone, the facade would be translated
/// against a `jmp_buf` layout the library was never compiled with.
///
/// So the translation is handed the macro the compile was handed, derived from
/// the target being built and never from the host (AGENTS.md section 5). A
/// target with F and no D gets `__riscv_float_abi_single`, which is what clang
/// gives it and what glibc rejects, so that failure stays a failure instead of
/// being translated away.
fn translateCRiscvFloatAbi(target: std.Build.ResolvedTarget) ?[2][]const u8 {
    switch (target.result.cpu.arch) {
        .riscv32, .riscv32be, .riscv64, .riscv64be => {},
        else => return null,
    }
    const abi: []const u8 = if (std.Target.riscv.featureSetHas(target.result.cpu.features, .d))
        "__riscv_float_abi_double"
    else if (std.Target.riscv.featureSetHas(target.result.cpu.features, .f))
        "__riscv_float_abi_single"
    else
        "__riscv_float_abi_soft";
    return .{ abi, "1" };
}

/// Builds one target's library, generated header and facade.
///
/// `public` chooses between the package module set, which is what a dependent
/// reaches through `dep.module("libpng")`, and a private module. A cross-target
/// check needs the private form: modules are registered by name against the
/// whole build, so registering `libpng` once per matrix target would leave only

/// the last of them reachable and silently stop checking the rest.
fn addGraph(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
    public: bool,
    libconf: std.Build.LazyPath,
) Graph {
    // Every route into this file passes through here: `build` for the published
    // graph and for `-Dtarget=`, and `add_target_check` for each matrix cell.
    // `runConsumer` reaches it too, one process later: it shells out to a
    // nested `zig build` in `consumer/` that resolves this package as a
    // dependency, and that nested build runs this `build()`. The refusal is
    // here rather than in `build` so that naming the target by hand and walking
    // the matrix cannot be given two different answers. Nothing has been
    // compiled when this runs - it is a configure-time stop, not a warning hung
    // off a later step. Today it refuses nothing: the one platform limit on
    // record for this package, `wasm32-wasi`'s missing `setjmp`, is recorded as
    // a failing row instead, because a failing row is a cell this build graph
    // actually attempts on every run. See `refusalFor`.
    if (refusalFor(target.result.os.tag) != null) refuseTarget(b, target);

    // The linkage this target can actually carry, resolved here so the
    // translation and the library cannot disagree about it.
    const delivered = deliveredLinkage(target, linkage);

    // `libconf` is threaded in from `build` rather than produced here: `addGraph`
    // runs once per matrix cell, and a generator and a run step created six
    // times over would be six identical host compilations carrying six
    // identical names. One copy is correct rather than a shortcut - the bytes
    // are upstream's prebuilt header, which is the same file for every target.
    const c_lib = add_c_library(b, target, optimize, delivered, artifactLabel(b, target, public), libconf);

    // The same generated header and the same `src` on the translation line as
    // on the compile line, in that order, for the reason the module comment
    // under "Generated-header placement" gives: `src/png.h:328` and `:333`
    // include `pnglibconf.h` and `pngconf.h` by bare name.
    const translate = b.addTranslateC(.{
        .root_source_file = b.path(translate_header),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    translate.addIncludePath(libconf.dirname());
    translate.addIncludePath(b.path(source_dir));
    // `PNG_BUILD_DLL` is the one declaration-visible macro this build can add,
    // and only for a Windows shared build; `add_c_library` gives the *library*
    // that same macro, and a consumer that wants the import spelling sets
    // `PNG_USE_DLL` itself (`src/pngconf.h:255-263`). See "Windows and
    // `PNG_BUILD_DLL`" above.
    //
    // This graph is bundled-only: `build` refuses `-fsys=png16` before any of
    // this is configured, because there is no system branch to configure.
    if (delivered == .dynamic and target.result.ofmt == .coff) {
        translate.defineCMacro("PNG_BUILD_DLL", "1");
    }
    // The one macro the C compiler and the translator disagree about on this
    // path. It goes on the translation only: clang already predefines it for
    // every C compile line, and a `-D` there would be a second copy of a fact
    // the compiler owns. Null off RISC-V, so no other architecture sees a `-D`
    // it did not need.
    if (translateCRiscvFloatAbi(target)) |macro| translate.defineCMacro(macro[0], macro[1]);

    const module = if (public)
        b.addModule(lib_name, .{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        })
    else
        b.createModule(.{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

    // Where the runtime-loading seam is
    // ---------------------------------
    // `runtime/graph.zig`, which the API role owns, exposes
    //
    //     pub fn createModule(
    //         b: *std.Build,
    //         translate: *std.Build.Step.TranslateC,
    //         target: std.Build.ResolvedTarget,
    //         optimize: std.builtin.OptimizeMode,
    //     ) *std.Build.Module
    //
    //     pub fn createCoreModule(
    //         b: *std.Build,
    //         target: std.Build.ResolvedTarget,
    //         optimize: std.builtin.OptimizeMode,
    //     ) *std.Build.Module
    //
    // and `-Druntime` substitutes the first for `translate.createModule()`. It
    // takes the `TranslateC` step this function has already built, so the
    // generated dispatch keeps the exact translated type and constant namespace
    // rather than compiling a second copy of the native extern declarations and
    // casting between two nominally distinct Zig modules.
    //
    // `-Dlinkage` is orthogonal and keeps meaning what it means: it selects
    // which artifact this build *delivers* and installs, never which one the
    // module dispatches through.
    //
    // The `rt` import is for the linked branch only, and the reason is the
    // nominal type rather than the code: `graph.createModule` creates the one
    // core-module instance the generated dispatch uses and re-exports
    // `LoadSource`/`LoadError` from it; a second instance created here for the
    // facade would be a *different* `LoadSource`. One instance per build, no
    // more.
    if (runtime_loaded) {
        // A loaded provider must arrive through the platform loader, so the
        // link line names nothing. Linking the archive as well would make the
        // linker resolve the same symbols statically and the runtime route
        // would quietly be a linked one. The artifact itself is still built and
        // installed, because delivery and dispatch are separate questions.
        module.addImport("c", graph.createModule(b, translate, target, optimize));
    } else {
        // The translated headers are imported, never registered:
        // `addModule("c")` would make `dep.module("c")` resolve and hand a
        // dependent the same declarations without the library that satisfies
        // them.
        module.addImport("c", translate.createModule());
        module.addImport("rt", graph.createCoreModule(b, target, optimize));
        module.linkLibrary(c_lib);
    }

    // The same two include directories as the archive's own module, in the same
    // order, on the module a dependent actually imports, so a dependent that
    // compiles its own C against this package finds the same headers the core
    // was compiled with - the generated directory first, because `png.h:328`
    // includes `pnglibconf.h` by bare name and there must be exactly one copy
    // of it in the search path.
    module.addIncludePath(libconf.dirname());
    module.addIncludePath(b.path(source_dir));

    return .{ .c_lib = c_lib, .module = module };
}

/// Builds `tools/pnglibconf.zig` for the host and runs it, returning the
/// generated `pnglibconf.h`.
///
/// The generator is a host program: it is the machine running `zig build` that
/// executes it, and the file it produces carries no target-derived value (see
/// the module comment under "The generator is a host program"). The `Run` step
/// is added to the graph through the returned `LazyPath`'s own step
/// dependencies, so a build that never includes this header never runs it.
/// Built once per build script process and shared by every target's graph,
/// which is the point: `addGraph` is called once per matrix cell, and a
/// generator and a run step created six times over would be six identical
/// host compilations with six identical names. The bytes are the same file for
/// every target - that is upstream's own prebuilt header - so one copy is
/// correct rather than a shortcut.
///
/// The run step is cacheable, so `has_side_effects` is deliberately *not* set:
/// its only outputs are the declared output file and the generator's stdout,
/// both of which the build system already knows how to hash and cache. Setting
/// the flag would re-run the generator on every invocation for no gain.
fn addLibconf(b: *std.Build) std.Build.LazyPath {
    const generator_mod = b.createModule(.{
        .root_source_file = b.path(generator_source),
        // Host, at a fixed mode: this is a build-time program that never
        // enters the artifact, so its optimize mode is this build's business
        // and not the caller's - the same reasoning `gmp/build.zig:673-676`
        // gives for its seven host generators.
        .target = b.graph.host,
        .optimize = .ReleaseSafe,
    });
    const generator = b.addExecutable(.{
        .name = "pnglibconf-gen",
        .root_module = generator_mod,
    });

    const run = b.addRunArtifact(generator);
    run.setName("generate pnglibconf.h");
    // No `has_side_effects`: see above.
    run.addArg("--input");
    run.addFileArg(b.path(prebuilt_libconf));
    run.addArg("--output");
    const out = run.addOutputFileArg("pnglibconf.h");
    run.addArg("--expect-version");
    run.addArg(b.fmt("{d}.{d}.{d}", .{
        upstream_version.major,
        upstream_version.minor,
        upstream_version.patch,
    }));
    return out;
}

/// Compiles the C library for one target: the 16 units, and nothing else.
///
/// `linkage` is what this target can carry, not what the caller asked for;
/// `deliveredLinkage` is what resolves the difference and `addGraph` and
/// `build` both call it, so the artifact, the declarations paired with it and
/// the installed `libpng16.pc` cannot describe different linkages.
fn add_c_library(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    name: []const u8,
    libconf: std.Build.LazyPath,
) *std.Build.Step.Compile {
    const c_lib = b.addLibrary(.{
        .name = name,
        .linkage = linkage,
        // See "Static and shared delivery" for where `abi_version` comes from.
        // `version` is null for a static archive, which has no soname and no
        // versioned file name.
        .version = if (linkage == .dynamic) abi_version else null,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            // libc, because every unit reaches the C library for its own
            // vocabulary: `<stdlib.h>` for `malloc` (`src/pngmem.c:98`,
            // inside `png_malloc_base` at `:68`) and `free`
            // (`src/pngmem.c:234`, `png_free`), `<stdlib.h>` again for the
            // `abort()` at `src/pngerror.c:795`, `<string.h>` for
            // `memcpy`/`memset` throughout, `<setjmp.h>` for `png_longjmp`,
            // and `<time.h>`/`<ctype.h>` in `png.c`. `src/pngconf.h:30-31`
            // includes `<limits.h>` and `<stddef.h>` on its own and
            // `src/pngconf.h:45` includes `<stdio.h>` under
            // `PNG_STDIO_SUPPORTED`, so the standard vocabulary is upstream's
            // own requirement rather than an addition by this build.
            .link_libc = true,
            // A shared library is position-independent whether or not this says
            // so; naming it makes the requirement explicit.
            .pic = if (linkage == .dynamic) true else null,
        }),
    });
    const c_mod = c_lib.root_module;

    // Two include directories, in this order, and the order is the whole of the
    // argument: `src/pngpriv.h:81` includes `"pnglibconf.h"` and
    // `src/png.h:333` includes `"pngconf.h"` by bare name, so the generated
    // directory has to come first for there to be exactly one `pnglibconf.h`
    // in the search path. Nothing is ever written into `b.path("src")` - which
    // is what makes `build.zig.zon` able to name `"src"` as a bare directory.
    c_mod.addIncludePath(libconf.dirname());
    c_mod.addIncludePath(b.path(source_dir));

    // The SIMD line. See the module comment under "SIMD configuration": these
    // seven are the documented upstream knobs, each pinned to upstream's own
    // "off" value, because `src/pngpriv.h:118-313` would otherwise enable one
    // from the compiler's predefines alone on a target this package compiles
    // none of the corresponding units for.
    for (simd_opt_macros) |macro| {
        c_mod.addCMacro(macro, "0");
    }

    // `PNG_BUILD_DLL`, for a Windows shared build and nothing else. Upstream's
    // own CMake sets exactly this and exactly here: `src/CMakeLists.txt:692-694`
    // gives `png_shared` the `DEFINE_SYMBOL PNG_BUILD_DLL` on `WIN32`, and
    // `src/pngpriv.h:360-368` is what that macro then turns into
    // `PNG_IMPEXP = PNG_DLL_EXPORT` = `__declspec(dllexport)`
    // (`src/pngconf.h:225`). A static build defines nothing, which is correct
    // on both sides.
    if (linkage == .dynamic and target.result.ofmt == .coff) {
        c_mod.addCMacro("PNG_BUILD_DLL", "1");
    }

    for (core_sources) |source| {
        c_mod.addCSourceFile(.{
            .file = b.path(source),
            .flags = &c_flags,
        });
    }

    // The zlib wire, in full. See the module comment under "The zlib wire":
    // `linkLibrary` reaches both the archive's link line and its `-I` for the
    // sibling's installed headers, with no path written here to go stale.
    //
    // PENDING-VERIFICATION: `../zlib` has no build.zig on disk yet, so this
    // call has not been observed to resolve.
    const zlib_dep = b.dependency(zlib_package, .{
        .target = target,
        .optimize = optimize,
    });
    c_mod.linkLibrary(zlib_dep.artifact(zlib_package));

    if (linkage == .dynamic) setVersionScript(b, c_lib, target);

    // The two source headers install from `src/`; the third is the generator's
    // output and installs from the build cache. Installing the headers also puts
    // them on the include path of anything that links this artifact, so a C
    // consumer needs nothing from this tree to call it.
    //
    // The `libpng16/` prefix is upstream's own installed layout, not a choice:
    // `src/Makefile.am:205` is `pkgincludedir= $(includedir)/$(PNGLIB_BASENAME)`
    // and `:10` is `PNGLIB_BASENAME= libpng@PNGLIB_MAJOR@@PNGLIB_MINOR@`, so a C
    // consumer's include is `<libpng16/png.h>`.
    for (public_headers) |header| {
        c_lib.installHeader(
            if (header.generated) libconf else b.path(header.source),
            b.fmt("libpng16/{s}", .{header.basename}),
        );
    }

    return c_lib;
}

/// Gives an ELF shared library upstream's restricted export surface.
///
/// Every public declaration in `src/png.h` goes through `PNG_EXPORT` /
/// `PNG_EXPORTA` (`src/pngconf.h:297-298`, `:286-291`) and every one of them
/// names a `png_*` function, so exporting the namespace globally and
/// everything else locally is upstream's export surface expressed without the
/// symbol list upstream generates with AWK
/// (`src/Makefile.am:186`, `-Wl,--version-script=libpng.vers`, from
/// `scripts/vers.out`). No cataloguing step can omit a header-declared
/// function this way, which is the defect a generated list has.
///
/// Mach-O has no version script that GNU ld or lld reads the same way, so this
/// does nothing for Darwin: a `libpng16.dylib` from this build exports libpng's
/// internals as well as its API. That is a real difference from the ELF object
/// and `build` reports it rather than hiding it.
fn setVersionScript(
    b: *std.Build,
    c_lib: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
) void {
    if (target.result.ofmt != .elf) return;

    const files = b.addWriteFiles();
    c_lib.setVersionScript(files.add("libpng.map",
        \\{
        \\  global:
        \\    png_*;
        \\  local:
        \\    *;
        \\}
    ));
}

/// Compiles the library, the facade, the tests and the example for one matrix
/// target and attaches all of them to `step`.
///
/// Building the test binary and the example is what makes this a check of the
/// facade rather than of an unreferenced archive: Zig analyses a function body
/// only when something calls it, and `tests.zig` and `smoke.zig` call the
/// facade. The full 16-unit C closure is compiled by the same graph. Nothing is
/// run here, so every result this step produces is compile evidence and not a
/// claim that a cross-built binary executed.
fn add_target_check(
    b: *std.Build,
    step: *std.Build.Step,
    query: std.Target.Query,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
    libconf: std.Build.LazyPath,
) void {
    const cross_target = b.resolveTargetQuery(query);
    // The triple names the cross artifacts. Six targets in one build graph
    // otherwise produce six steps called `png16`, which makes `--summary all`
    // useless for telling them apart.
    const triple = cross_target.result.zigTriple(b.allocator) catch @panic("unspellable target");

    // The archive is built here and not merely referenced: the test binary and
    // the example both link it, so a cell where the 16 units do not compile
    // fails at this step rather than at the first install.
    const cross = addGraph(b, cross_target, optimize, linkage, runtime_loaded, false, libconf);

    const test_mod = b.createModule(.{
        .root_source_file = b.path(test_source),
        .target = cross_target,
        .optimize = optimize,
        .link_libc = true,
    });
    test_mod.addImport(lib_name, cross.module);
    step.dependOn(&b.addTest(.{
        .name = b.fmt("libpng-tests-{s}", .{triple}),
        .root_module = test_mod,
    }).step);

    const example_mod = b.createModule(.{
        .root_source_file = b.path(example_source),
        .target = cross_target,
        .optimize = optimize,
        .link_libc = true,
    });
    example_mod.addImport(lib_name, cross.module);
    step.dependOn(&b.addExecutable(.{
        .name = b.fmt("libpng-smoke-{s}", .{triple}),
        .root_module = example_mod,
    }).step);

    // A target where the 16 units do not compile is a target this SDK does not
    // support, and the matrix says so at build time rather than at install.
    step.dependOn(&cross.c_lib.step);
}

/// Runs the consumer package as its own `zig build` in `consumer/`.
///
/// The consumer is a separate package on purpose: a manifest dependency here
/// would close a cycle, because its manifest points back at this package by
/// path. Running it as a separate build is what makes the proof real - that a
/// package which only writes `b.dependency("libpng", ...)` and
/// `dep.module("libpng")` gets a working, correctly linked library, with the
/// archive, libc and zlib arriving through the module and nothing else.
///
/// Everything this build resolved travels with it: the target and CPU, the
/// optimize mode, the linkage and dispatch shapes, the system-integration
/// decision, the executor switches, both cache directories, the install
/// prefix, the job width and the summary. An argument left behind would be a
/// proof of a configuration nobody asked for.
///
/// Run when this host can execute the selected target, and install otherwise:
/// `hostCanExecute` asks exactly what `std.Build.Step.Run` asks of a foreign
/// binary, so the decision here and the nested run cannot disagree. An executor
/// counts only when its `-f` switch was given; a target with none installs,
/// which is compile evidence and never a semantic pass.
fn runConsumer(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    linkage: std.builtin.LinkMode,
    runtime_loaded: bool,
) *std.Build.Step.Run {
    const triple = target.query.zigTriple(b.allocator) catch @panic("OOM");
    defer b.allocator.free(triple);
    // The same query's other half. The triple above names the architecture, the
    // OS and the ABI; it carries no CPU model and no feature set
    // (`lib/std/Target/Query.zig:421-423`), and `cpu` is a separate option of
    // its own. `serializeCpu` (`lib/std/Target/Query.zig:530`) writes `native`
    // for a query that named no CPU and `baseline` for a cross query that named
    // none, and `Target.Query.parseCpu` recognises both spellings, so the nested
    // `standardTargetOptions` resolves this build's selection rather than one
    // of its own. `addArg` copies each argument, so these temporaries can go
    // right after.
    const cpu = target.query.serializeCpuAlloc(b.allocator) catch @panic("OOM");
    defer b.allocator.free(cpu);

    // `b.graph.zig_exe` is the compiler running this build script, so the
    // nested build is the same toolchain rather than whatever is on PATH.
    const run = b.addSystemCommand(&.{ b.graph.zig_exe, "build" });
    run.setName("consumer package");
    run.setCwd(b.path("consumer"));
    run.addArg(if (hostCanExecute(b, target)) "run" else "install");
    run.addArg(b.fmt("-Dtarget={s}", .{triple}));
    // The model and its feature set, for the reason the serialization above
    // gives. Without it the nested build would compile the consumer at a
    // baseline CPU on a host that built the library for something else, and the
    // step would prove a configuration nobody asked for.
    run.addArg(b.fmt("-Dcpu={s}", .{cpu}));
    run.addArg(b.fmt("-Doptimize={s}", .{@tagName(optimize)}));
    // The delivery and dispatch options have to reach the nested build or the
    // consumer would silently check the default graph and say nothing about the
    // configuration that was asked for.
    run.addArg(b.fmt("-Dlinkage={s}", .{@tagName(linkage)}));
    // Both spellings go, not only the true one, so a cell's configuration is
    // stated rather than inferred from a default and the flag cannot be dropped
    // on the way down.
    run.addArg(b.fmt("-Druntime={s}", .{if (runtime_loaded) "true" else "false"}));
    // The mode *this* build resolved, which is a different question from which
    // option asked for it. `b.systemIntegrationOption` is fed by the build
    // runner's `-fsys=`/`-fno-sys=` flags (`lib/compiler/build_runner.zig:169-174`)
    // and is never an entry in the `-D` map, so forwarding `-Dsystem` would set
    // the nested graph's *default* and leave the answer to that graph's own
    // runner instead of this build's. The flag itself goes instead, so the
    // dependency's own `systemIntegrationOption(artifact_name, ...)` resolves
    // the answer this build already reached: a dependency shares its parent's
    // `Graph` (`lib/std/Build.zig:352`) and `system_library_options` is a field
    // of it (`:116`, read at `:2731`).
    //
    // The key is the *artifact* name, not the module name, because that is what
    // the run flag names and what `systemIntegrationOption` above is registered
    // under.
    //
    // Only the negative spelling is possible: this graph has no system branch
    // (see "System mode is vacuous here"), so a nested build told
    // `-fsys=png16` would stop with its own message while the outer build that
    // launched it was compiling the bundled tree - two different answers to one
    // cell.
    run.addArg(b.fmt("-fno-sys={s}", .{artifact_name}));
    // Forward the selected executor and its dynamic-linker support.
    if (b.enable_darling) run.addArg("-fdarling");
    if (b.enable_qemu) run.addArg("-fqemu");
    if (b.enable_rosetta) run.addArg("-frosetta");
    if (b.enable_wasmtime) run.addArg("-fwasmtime");
    if (b.enable_wine) run.addArg("-fwine");
    if (b.libc_runtimes_dir) |runtimes| run.addArgs(&.{ "--libc-runtimes", runtimes });
    // The nested build carries this workspace's job count and summary in its own
    // command line. Nothing can append a `-j` to a `Run` step's command, so a
    // nested build left to derive its own width takes `cpu_count - 1` instead,
    // and the consumer this step proves then compiles at a different width from
    // the build that asked for it.
    run.addArg("-j8");
    run.addArg("--summary");
    run.addArg("all");
    // A null `path` means "the current directory", and the working directory is
    // already the consumer package, so the default is right.
    if (b.cache_root.path) |cache| {
        run.addArg("--cache-dir");
        run.addArg(b.fmt("{s}/consumer", .{cache}));
    }
    // The global cache is inherited whole rather than subdirectoryed: it is one
    // shared store of packages and hashes, so a nested build left to resolve its
    // own would fetch again what this one already holds, and would write outside
    // the root this workspace approved. Two tokens, as documented at
    // `lib/compiler/build_runner.zig:1675`.
    if (b.graph.global_cache_root.path) |global_cache| {
        run.addArg("--global-cache-dir");
        run.addArg(global_cache);
    }
    // The install prefix this invocation resolved, handed on when the caller
    // named one. A nested `zig build` left to resolve its own installs into
    // `consumer/zig-out` - a build artefact inside a source package - rather
    // than into the directory the caller asked for. A relative `--prefix` would
    // resolve against the working directory set above, `consumer/`, and not
    // against this build's root, so it is made absolute before it is handed on.
    // `DESTDIR` needs no forwarding, because the nested build inherits the
    // environment this one ran with.
    const default_prefix = b.build_root.join(b.allocator, &.{"zig-out"}) catch @panic("OOM");
    if (!std.mem.eql(u8, b.install_prefix, default_prefix)) {
        const prefix = if (std.fs.path.isAbsolute(b.install_prefix))
            b.install_prefix
        else
            b.pathJoin(&.{ b.graph.cache.cwd, b.install_prefix });
        run.addArg("--prefix");
        run.addArg(prefix);
    }
    // The caller's own arguments, last and behind `--`: `--` is where the build
    // runner stops parsing options and keeps the rest as `b.args`
    // (`lib/compiler/build_runner.zig:428-430`), so this `--` has to follow
    // every argument above - those are this package's own bookkeeping with the
    // nested build, and only what the caller typed after `--` belongs to the
    // program. `consumer/src/main.zig` may document a command-line input, and
    // this is the only place those words can enter the nested graph at all.
    if (b.args) |args| {
        run.addArg("--");
        run.addArgs(args);
    }
    // The nested build is the step's only observable effect.
    run.has_side_effects = true;
    return run;
}

/// True when this build can execute `target`'s binaries.
///
/// `std.zig.system.getExternalExecutor` (`lib/std/zig/system.zig:42`) is the
/// predicate `std.Build.Step.Run` applies to the artifact it is about to spawn
/// (`lib/std/Build/Step/Run.zig:1268`), and `allow_*` carries this build's own
/// executor switches, so the two cannot disagree. `link_libc` holds in every
/// mode this package builds; the `.qemu` arm carries `Run`'s own second gate.
fn hostCanExecute(b: *std.Build, target: std.Build.ResolvedTarget) bool {
    const host = &b.graph.host.result;
    const candidate = &target.result;
    const options: std.zig.system.GetExternalExecutorOptions = .{
        .allow_darling = b.enable_darling,
        .allow_qemu = b.enable_qemu,
        .allow_wasmtime = b.enable_wasmtime,
        .allow_wine = b.enable_wine,
        // `consumer/` builds its executable with `b.addExecutable` and no
        // linkage, so `Run`'s musl half of `need_cross_libc` never holds here.
        .qemu_fixes_dl = candidate.isGnuLibC() and b.libc_runtimes_dir != null,
        .link_libc = true,
    };
    return switch (std.zig.system.getExternalExecutor(b.graph.io, host, candidate, options)) {
        .native, .rosetta => true,
        // Reachable only for an executor the switches above enabled, each of
        // which `Run` gates on the same switch and nothing else.
        .wine, .wasmtime, .darling => true,
        // Not a yes on its own: `Run` fails a cross GNU libc target given no
        // `--libc-runtimes`, so this step installs it instead.
        .qemu => !(candidate.isGnuLibC() and b.libc_runtimes_dir == null),
        // Same OS and CPU with no dynamic linker to load, or an architecture and
        // system this build has no enabled executor for.
        .bad_dl, .bad_os_or_cpu => false,
    };
}

/// Writes `lib/pkgconfig/libpng16.pc` and installs it.
///
/// Upstream ships the template, `src/scripts/libpng.pc.in`, and `configure`
/// substitutes its four `@VAR@`s. Every one is named here with the line it
/// comes from, and every one is written relative to `${pcfiledir}` rather than
/// as an absolute path:
///
///   * `@prefix@` - the configure-time installation prefix. Substituted as
///     `${pcfiledir}/../..`, which is correct wherever the file is installed,
///     including a Nix store path that is only known at build time.
///   * `@exec_prefix@` - `src/scripts/libpng.pc.in:2` sets it to `@prefix@`, so
///     it is `${prefix}` and nothing else.
///   * `@libdir@` - `src/scripts/libpng.pc.in:3`. `${prefix}/lib`, matching the
///     `lib/` this build installs into.
///   * `@includedir@` - `src/scripts/libpng.pc.in:4` is `@includedir@/libpng16`,
///     i.e. upstream's `pkgincludedir` (`src/Makefile.am:205`) already has the
///     `libpng16` suffix, and `Cflags: -I${includedir}` (`src/scripts/
///     libpng.pc.in:7`) therefore yields the whole `-I${prefix}/include/
///     libpng16` with no second substitution.
///
/// The three static fields are upstream's own text, unchanged: `Name: libpng`,
/// `Description: Loads and saves PNG files` and `Libs: -L${libdir} -lpng16`
/// (`src/scripts/libpng.pc.in:5-7`). `Version:` is `src/scripts/libpng.pc.in:6`
/// and carries the release this graph compiles.
///
/// One field is added, about the zlib wire, and it is stated rather than
/// smuggled in:
///
///   * `Libs.private: -lz`. Upstream's template has no such line, because
///     upstream's `configure` finds zlib with a compile probe and links it
///     through `LIBS` rather than through the `.pc`. This build reaches zlib as
///     a sibling package instead, and a static consumer of `libpng16.a` has to
///     name zlib itself or the link fails on `inflateInit2_`.
///     `src/CMakeLists.txt:141-142` is upstream's own statement of the
///     dependency (`find_package(ZLIB REQUIRED)`,
///     `set(PNG_LINK_LIBRARIES ZLIB::ZLIB)`), so this is the same fact in the
///     place a `.pc` can carry it.
///
/// `Requires.private: zlib` is deliberately *absent*, although it would be the
/// more idiomatic spelling. Whether the sibling zlib package installs a
/// `zlib.pc` at all has not been observed - `../zlib` has no `build.zig` on disk
/// yet - and a `Requires.private` naming a `.pc` that does not exist makes
/// `pkg-config` fail on every consumer, not only on a static one. `-lz` needs
/// no such file. When the sibling's install layout is observed, this is the
/// line to revisit.
///
/// The installed name is upstream's: `src/Makefile.am:212` is
/// `pkgconfig_DATA = libpng@PNGLIB_MAJOR@@PNGLIB_MINOR@.pc`.
fn add_pkg_config(b: *std.Build) void {
    const files = b.addWriteFiles();
    // The returned step is bound to the install step. `addInstallFileWithDir`
    // *creates* a `Step.InstallFile` and nothing more - dropping the return
    // value builds nothing and installs nothing, and the omission is silent:
    // the step exists, it is simply never in the graph, so an install that was
    // missing its `.pc` file would still report success.
    const install_pc = b.addInstallFileWithDir(
        files.add("libpng16.pc", b.fmt(
            \\# libpng16.pc for the libpng 1.6.59 SDK.
            \\#
            \\# Generated from upstream's own template, src/scripts/libpng.pc.in, by
            \\# substituting the four @VAR@s configure would. `prefix` is pcfiledir-relative
            \\# so the installed file is correct wherever --prefix put it. build.zig's
            \\# add_pkg_config names the upstream line each field comes from.
            \\prefix=${{pcfiledir}}/../..
            \\exec_prefix=${{prefix}}
            \\libdir=${{prefix}}/lib
            \\includedir=${{prefix}}/include/libpng16
            \\
            \\Name: libpng
            \\Description: Loads and saves PNG files
            \\Version: {f}
            \\
            \\Libs: -L"${{libdir}}" -lpng16
            \\Libs.private: -lz
            \\Cflags: -I"${{includedir}}"
            \\
        , .{upstream_version})),
        .prefix,
        "lib/pkgconfig/libpng16.pc",
    );
    b.getInstallStep().dependOn(&install_pc.step);
}

/// Installs the carried licence texts and provenance records under
/// `share/licenses/libpng/`.
///
/// A private repository removes no upstream obligation, and libpng's grant is
/// not MIT: `src/LICENSE:4` is the PNG Reference Library License version 2.
/// What installs is upstream's own file under its own name, plus
/// `src/example.c` (`src/example.c:18-19`, the one file upstream dedicates to
/// the public domain) and `src/REUSE.toml` (the per-path SPDX map). The rest
/// are this fork's records.
fn install_licence_records(b: *std.Build) void {
    for (licence_records) |record| {
        // Bound, for the reason `add_pkg_config` says.
        const install_record = b.addInstallFileWithDir(
            b.path(record),
            .prefix,
            b.fmt("share/licenses/libpng/{s}", .{std.fs.path.basename(record)}),
        );
        b.getInstallStep().dependOn(&install_record.step);
    }
}

/// Installs the three manual pages, each under its own automake section.
///
/// `src/Makefile.am:117` is `dist_man_MANS= libpng.3 libpngpf.3 png.5`, and
/// automake's `man_MANS` rule installs a `.3` file into `$(man3dir)` and a `.5`
/// file into `$(man5dir)`. `libpng-manual.txt` is in `EXTRA_DIST`
/// (`src/Makefile.am:222`), which is the distribution tarball and not
/// `make install`, so it is not installed here either.
fn install_man_pages(b: *std.Build) void {
    for (man_pages) |page| {
        // Bound, for the reason `add_pkg_config` says.
        const install_page = b.addInstallFileWithDir(
            b.path(page.source),
            .prefix,
            b.fmt("share/{s}/{s}", .{ page.section, std.fs.path.basename(page.source) }),
        );
        b.getInstallStep().dependOn(&install_page.step);
    }
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const system_default = b.option(
        bool,
        "system",
        "Refused in this package: no system mode is implemented, and the module " ++
            "comment says why (a system mode would have to translate the installed " ++
            "pnglibconf.h alongside the installed png.h and check its " ++
            "PNG_ZLIB_VERNUM against the zlib that prefix links, which is the " ++
            "silent-ABI failure AGENTS.md rule 4 forbids). This option supplies the " ++
            "default of systemIntegrationOption(\"png16\"); a build runner that " ++
            "decides the mode itself (-fsys=png16) overrides it. Either spelling " ++
            "that selects the system stops the build before a compiler is invoked.",
    ) orelse false;

    // The key is the artifact name, not the module name: it is what the build
    // runner's `-fsys=`/`-fno-sys=` flag names and what a dependent's own
    // `systemIntegrationOption` call has to match.
    if (b.systemIntegrationOption(artifact_name, .{ .default = system_default })) {
        // A refusal, not a silent no-op and not a fallback to the bundled tree.
        // The flag was asked for and cannot be honoured, so the build stops
        // before a compiler is invoked and names the reason. See the module
        // comment under "System mode is vacuous here": a system mode would have
        // to translate the *installed* `pnglibconf.h` next to the installed
        // `png.h` (`src/png.h:328`, `:333`) and confirm its `PNG_ZLIB_VERNUM`
        // against the zlib that prefix links (`src/pngpriv.h:1026-1028`), which
        // no `b.dependency` performs.
        std.log.err(
            \\libpng: -fsys=png16 selects a system mode this package does not
            \\implement, and the rule is recorded as vacuous rather than
            \\satisfied.
            \\
            \\src/png.h:328 includes the *generated* pnglibconf.h and
            \\src/png.h:333 includes pngconf.h, so a system mode must translate
            \\the installed pnglibconf.h alongside the installed png.h from the
            \\same prefix and check its PNG_ZLIB_VERNUM against the zlib that
            \\prefix links (src/pngpriv.h:1026-1028). Bundling this tree's own
            \\src/png.h against an older installed libpng is the silent ABI
            \\mismatch AGENTS.md rule 4 forbids.
            \\
            \\Build the bundled graph instead: drop -Dsystem and do not pass
            \\-fsys=png16.
            \\
        , .{});
        @panic("libpng: refusing a system mode this package does not implement");
    }

    const linkage_option = b.option(
        std.builtin.LinkMode,
        "linkage",
        "Deliver the native library as a static archive (the default) or as a real " ++
            "shared object with upstream's libpng16 ABI name " ++
            "(libpng16.so.16.59.0, soname libpng16.so.16). This selects the delivery " ++
            "and never the dispatch: the same 16 C units are compiled either way.",
    );

    // The default is upstream's: libtool produces `libpng16.a` for a static
    // link (`src/Makefile.am:125`, `lib_LTLIBRARIES=libpng16.la`), and the
    // pre-option graph compiled an archive. `-Dlinkage=dynamic` selects the
    // shared object instead.
    const linkage: std.builtin.LinkMode = linkage_option orelse .static;

    // `-Druntime` selects the *dispatch*, and it is orthogonal to `-Dlinkage`:
    // the option says which artifact this build delivers and installs, this one
    // says whether the Zig facade calls it through a link line or through a
    // table an explicit `load` fills. Under `-Druntime` nothing is linked into
    // the facade module at all, so a caller may name a provider this tree did
    // not build - and the artifact is still built and installed, so a caller may
    // equally name the one it did.
    const runtime_loaded = b.option(
        bool,
        "runtime",
        "Resolve the native entry points at run time instead of linking them. " ++
            "The facade keeps the same translated headers and the same public " ++
            "types; each selected native function becomes a dispatch through " ++
            "one process-lifetime table that an explicit load(source) fills, " ++
            "and the module links no archive. Independent of -Dlinkage, which " ++
            "still decides which artifact this build delivers and installs. " ++
            "Default off, and a linked build is unchanged in every respect.",
    ) orelse false;

    // `build.zig.zon .version` and the version read out of `src/png.h` are one
    // fact. `std.SemanticVersion.parse` fails loudly rather than wrapping a
    // non-version, and the comparison catches a manifest edited without the
    // source it describes - including an upstream re-sync that moved
    // `PNG_LIBPNG_VER_STRING` without moving this manifest.
    if (manifest_version.order(upstream_version) != .eq) {
        @panic("build.zig.zon .version no longer matches the version read out " ++
            "of src/png.h:277; see UPSTREAM.md");
    }

    // Two lists, one decision function, checked before any graph is configured:
    // a row cannot be quietly wrong in either direction.
    checkMatrixPartition(b);

    // One generator, one run step, one output file for the whole build script
    // process - see `addLibconf`.
    const libconf = addLibconf(b);

    const published = addGraph(b, target, optimize, linkage, runtime_loaded, true, libconf);

    const c_lib = published.c_lib;

    b.installArtifact(c_lib);
    add_pkg_config(b);
    install_licence_records(b);
    install_man_pages(b);

    // `zig build` also compiles the example. The example is the cheapest thing
    // that proves the facade, the translated headers and the C archive agree on
    // types, symbols and link-time dependencies. It is compiled, not installed:
    // it is a proof, not a deliverable.
    const example_mod = b.createModule(.{
        .root_source_file = b.path(example_source),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    example_mod.addImport(lib_name, published.module);
    const example = b.addExecutable(.{
        .name = "libpng-smoke",
        .root_module = example_mod,
    });
    b.getInstallStep().dependOn(&example.step);

    // A run artifact already depends on building the executable, which depends
    // on compiling the C and linking the facade. `zig build smoke` deliberately
    // does not depend on the install step: installing is `zig build`'s job and
    // conflating the two would make a smoke run depend on the install layout.
    const run_example = b.addRunArtifact(example);
    run_example.has_side_effects = true;
    if (b.args) |args| run_example.addArgs(args);
    b.step("smoke", "Run the deterministic example program").dependOn(&run_example.step);

    // The test root is `tests.zig`, which names the test blocks; a root that
    // only re-exported them would discover no tests and still exit zero.
    // `addRunArtifact` is used rather than a plain compile so that this is a
    // real runnable test step for whatever `-Dtarget` names: a foreign target is
    // left to whichever executor the cross-test harness detects, and this build
    // does not decide that.
    const test_mod = b.createModule(.{
        .root_source_file = b.path(test_source),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    test_mod.addImport(lib_name, published.module);
    const unit_tests = b.addTest(.{
        .name = "libpng-tests",
        .root_module = test_mod,
    });
    const run_tests = b.addRunArtifact(unit_tests);
    run_tests.has_side_effects = true;
    b.step("test", "Run the behavioural tests").dependOn(&run_tests.step);

    // The separate consumer package, built as its own `zig build`. It runs when
    // this host can execute the selected target and installs when it cannot,
    // which is `hostCanExecute` rather than a query predicate: a cross-compiled
    // consumer binary cannot run here, and a native one can run under an enabled
    // executor. An install is compile evidence and nothing more.
    //
    // The linkage forwarded is the one this build resolved with
    // `deliveredLinkage`, not the one a caller typed, so a cell where the
    // requested delivery is impossible is asked for the delivery that exists.
    b.step("consumer", "Build or run the consumer/ package for the selected target")
        .dependOn(&runConsumer(b, target, optimize, deliveredLinkage(target, linkage), runtime_loaded).step);

    // The cross target gate. Compiling the library, the facade, the tests and
    // the example for each target is what makes this a check of the facade
    // rather than of an unreferenced archive. Nothing runs here.
    const check_step = b.step(
        "check",
        "Compile the native library, the facade, the tests and the example for " ++
            "the six check targets without running any of them",
    );
    if (!target.query.isNative()) {
        add_target_check(b, check_step, target.query, optimize, linkage, runtime_loaded, libconf);
    } else {
        // One matrix, whatever the delivery. `-Dlinkage` selects the artifact,
        // not the set of targets: a target whose OS cannot carry a shared
        // object is a delivery refusal at `deliveredLinkage`, not a missing
        // matrix row. `[0..]`, not `.*`: `.*` is for dereferencing a single
        // optional or error-union payload, so the pointer-to-array has to
        // become a slice before it can be iterated.
        for (check_targets[0..]) |query| {
            add_target_check(b, check_step, query, optimize, linkage, runtime_loaded, libconf);
        }
    }

    // What this configuration is, read out of the build rather than inferred
    // from a cache directory. These are configure-time lines, not gate results:
    // nothing has been compiled when they print.
    std.debug.print("libpng: {d} C units from src/Makefile.am:127-129, C99 (gnu99), no SIMD unit compiled\n", .{
        core_sources.len,
    });
    std.debug.print("libpng: {s}\n", .{switch (deliveredLinkage(target, linkage)) {
        .static => "static archive libpng16.a (default)",
        .dynamic => b.fmt("shared object libpng16.so.{d}.{d}.{d}, soname libpng16.so.{d} " ++
            "(src/png.h:281 PNG_LIBPNG_VER_SHAREDLIB {d}, src/Makefile.am:178-179 -version-number {d}:{d}:0)", .{
            abi_version.major,
            abi_version.minor,
            abi_version.patch,
            abi_version.major,
            abi_version.major,
            abi_version.major,
            abi_version.minor,
        }),
    }});
    // SIMD, stated at configure time because "which configuration" is the
    // question a reader of a support matrix has, and silence reads as
    // "upstream's default" rather than as a decision.
    std.debug.print(
        "libpng: SIMD configuration is none; all seven PNG_*_OPT macros are 0 and no " ++
            "arm/ intel/ mips/ powerpc/ loongarch/ riscv/ unit is compiled " ++
            "(src/pngusr.dfa carries no options, and src/Makefile.am:132-174 adds those " ++
            "units only under its own if PNG_*_OPT blocks)\n",
        .{},
    );
    std.debug.print(
        "libpng: pnglibconf.h is generated by tools/pnglibconf.zig from " ++
            "{s} into the build cache, on the include line ahead of src/; PNG_ZLIB_VERNUM " ++
            "is 0 (src/scripts/pnglibconf.h.prebuilt:226), so src/pngpriv.h:1026-1028 " ++
            "skips its include-path check\n",
        .{prebuilt_libconf},
    );
    // The zlib wire is stated as pending rather than described as working: it
    // has not been observed to resolve, because `../zlib` has no build.zig on
    // disk at the time of writing.
    std.debug.print(
        "libpng: zlib comes from the sibling package `../zlib` through " ++
            "c_mod.linkLibrary(zlib_dep.artifact(\"zlib\")), with no hand-written include " ++
            "path and no system zlib path; that wire is PENDING-VERIFICATION\n",
        .{},
    );
    if (runtime_loaded) {
        // Dispatch is a separate fact from delivery, and a runtime-loaded build
        // links nothing into the facade module: the caller names a provider
        // with an explicit `load(source)` and the symbols arrive through the
        // platform loader. Printing it here is what keeps "the library is still
        // built and installed" from reading as "the module links it".
        std.debug.print(
            "libpng: runtime-loaded dispatch (-Druntime=true, sync prefix libpng_rt); " ++
                "the facade module links no archive and a provider is named by an " ++
                "explicit load(source)\n",
            .{},
        );
    }
    if (deliveredLinkage(target, linkage) == .dynamic and target.result.ofmt != .elf) {
        // See `setVersionScript`. A Mach-O or COFF shared object gets
        // upstream's `__declspec` decoration on Windows and nothing on Darwin,
        // so a Darwin shared object from this build exports libpng's internal
        // symbols as well as its API. Said here rather than left to be
        // discovered by `nm -D`.
        std.debug.print(
            "libpng: {s} has no version-script mechanism here, so the shared " ++
                "object exports libpng's internal symbols as well as its API\n",
            .{@tagName(target.result.ofmt)},
        );
    }
}

/// Whether this target's OS has a dynamic linker at all, and therefore whether
/// it can carry a shared object.
///
/// Windows uses its PE/COFF loader without an interpreter path. Other shared
/// targets need a dynamic linker. WASI has neither.
fn targetHasDynamicLinker(target: std.Build.ResolvedTarget) bool {
    return target.result.os.tag == .windows or std.Target.DynamicLinker.kind(target.result.os.tag) != .none;
}

/// The linkage this build delivers, or a refusal when the target cannot carry
/// what was asked for.
///
/// There is no substitution here, deliberately. Upstream's `src/Makefile.am`
/// builds `libpng16.la` through libtool, which produces both a `.a` and a
/// `.so.16.59.0` from one build, so "deliver a shared object" is this fork's
/// selection between two of upstream's own products; handing back an archive
/// under the shared name would be a result the caller did not request and cannot
/// tell from support. So a shared request on a target whose OS has no dynamic
/// linker stops here, with a message that names the target, the reason and the
/// way out.
///
/// `add_c_library`, `addGraph` and `build` all resolve through this one
/// function, so the artifact, the declarations it is paired with and the
/// installed `libpng16.pc` cannot describe different linkages.
fn deliveredLinkage(
    target: std.Build.ResolvedTarget,
    requested: std.builtin.LinkMode,
) std.builtin.LinkMode {
    if (requested == .dynamic and !targetHasDynamicLinker(target)) {
        // `std.debug.panic` with a format string, not `@panic` on a
        // concatenated string: `@tagName` of a run-time tag is not comptime
        // known, and `++` on a slice being concatenated has to be.
        std.debug.panic(
            "libpng: -Dlinkage=dynamic was asked for {s}, which has no dynamic " ++
                "linker: std.Target.DynamicLinker.kind is .none for it, so it cannot " ++
                "carry a shared object at all. This build does not substitute a static " ++
                "archive for a requested shared object. Build that target with the " ++
                "default -Dlinkage=static, or leave -Dlinkage unset.",
            .{@tagName(target.result.os.tag)},
        );
    }
    return requested;
}

/// Why a target has no buildable libpng here, or null when it has one.
///
/// Null for every operating system, and that is deliberate rather than a gap.
/// One platform limit has been observed for this package since it was written -
/// `wasm32-wasi`, whose libc has no `setjmp` while
/// `src/scripts/pnglibconf.h.prebuilt:113` defines `PNG_SETJMP_SUPPORTED`
/// unconditionally - and it is deliberately *not* routed here. A refusal is a
/// cell this build graph never attempts; a failing row is a cell it attempts on
/// every run, which is why `wasm32-wasi` stays in `check_targets` and keeps
/// reporting the toolchain's own message. This function is where a refusal goes
/// when refusing is the only honest answer, so that `refuseTarget` has
/// something to print and `checkMatrixPartition` has one list to check.
const Refusal = struct {
    /// One line, printed with the target triple in front of it.
    summary: []const u8,
    /// The long form printed before the build fails.
    detail: []const u8,
};

fn refusalFor(os_tag: std.Target.Os.Tag) ?Refusal {
    _ = os_tag;
    return null;
}

/// Prints why `target` cannot be built, and fails the build.
///
/// A real refusal, not a warning and not a stub: `zig build`, `zig build check`
/// and `zig build check -Dtarget=<this target>` all stop here, before a compiler
/// is invoked. Unreachable today, because `refusalFor` refuses nothing; it
/// stays because deleting it would delete the only place a future refusal has to
/// be written down.
fn refuseTarget(b: *std.Build, target: std.Build.ResolvedTarget) noreturn {
    const refusal = refusalFor(target.result.os.tag) orelse
        @panic("build.zig internal error: refusalFor returned null for a target addGraph refused");
    const triple = target.result.zigTriple(b.allocator) catch @panic("unspellable target");
    std.log.err("libpng: {s}: {s}\n{s}", .{ triple, refusal.summary, refusal.detail });
    @panic("libpng: refusing a target this package has no buildable configuration for");
}

/// Keeps the two halves of the matrix honest against each other.
///
/// The point of naming `refused_check_targets` is that a refused row is not
/// quietly absent, and the point of naming `check_targets` is that every row in
/// it is real. Both are re-derived here through the same `refusalFor` that
/// `refuseTarget` stops with, so a change that makes a refused target buildable
/// fails any build of this package rather than quietly shrinking what `check`
/// proves.
fn checkMatrixPartition(b: *std.Build) void {
    for (check_targets) |query| {
        const resolved = b.resolveTargetQuery(query);
        if (refusalFor(resolved.result.os.tag) != null) {
            @panic(b.fmt(
                "build.zig: {s} is in check_targets but this build refuses its operating system",
                .{resolved.result.zigTriple(b.allocator) catch @panic("unspellable check target")},
            ));
        }
    }
    for (refused_check_targets) |query| {
        const resolved = b.resolveTargetQuery(query);
        if (refusalFor(resolved.result.os.tag) == null) {
            @panic(b.fmt(
                "build.zig: {s} is in refused_check_targets but refusalFor no longer refuses it; move it to check_targets and prove it builds",
                .{resolved.result.zigTriple(b.allocator) catch @panic("unspellable check target")},
            ));
        }
    }
}