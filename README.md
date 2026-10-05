# libpng

libpng 1.6.59 — the PNG Reference Library — as a complete standalone Zig SDK:
the whole 16-unit C core compiled from the official release sources with no
CMake, no autotools and no build-time download, plus the public headers, a typed
Zig surface, the raw translated C route and an optional runtime-loading route.

* Upstream: the `libpng-1.6.59.tar.gz` release, 2026-09-28, sha256
  `86a3e4b501f7f50e392c4e456ea158893e9a595b1c63eb88c7bb9f6cf8772dad`,
  served from SourceForge — see [`UPSTREAM.md`](UPSTREAM.md).
* Native source: unmodified. All **614** upstream files are recorded by digest in
  [`UPSTREAM.sha256`](UPSTREAM.sha256), and `src/` was compared byte-for-byte
  with the extracted tarball (`diff -rq`, no difference).
* Licence: **PNG Reference Library License version 2** for the compiled core
  (`src/LICENSE:4`) — **not MIT** — with per-file exceptions recorded in
  [`NOTICE.md`](NOTICE.md); MIT for this fork's own files, per
  [`FORK-LICENSE.md`](FORK-LICENSE.md).
* Upstream's own README is preserved verbatim in
  [`README.upstream.md`](README.upstream.md), byte-identical to `src/README`.
* **Three gates have been run: `zig build` (exit 0), `zig build check` (exit
  1), and `cross-test` over the published 53-platform matrix (exit 1).** All on
  2026-10-05, with the pinned Zig 0.16.0. `check` compiled five of its six
  targets; the `wasm32-wasi` row does not compile, for a reason written down in
  [`FORK-NOTES.md`](FORK-NOTES.md) §5 and in [`CHANGELOG.md`](CHANGELOG.md)
  entry 2. `cross-test` is the first run here that executed a test binary: 18 of
  its 53 cells ran 9/9 tests and passed, 18 compiled without executing
  (`build_only`, never a pass), 2 crashed at runtime and 15 did not compile. The
  full per-cell table is in [`FORK-NOTES.md`](FORK-NOTES.md) §11 and
  [`CHANGELOG.md`](CHANGELOG.md) entry 3. Every other gate — tests in either
  optimize mode outside this matrix, smoke, both linkages, the runtime-loaded
  route, the consumer, Nix and CI — is still `PENDING-VERIFICATION`, and **no
  cell in the support matrix may be called passing** beyond the 18 the matrix
  run actually executed.

## Native-source deviations

**None.** Every one of the 614 files under `src/` is byte-identical to the
release tarball. No portability patch, no reformat, no `#if` added around a
platform workaround, and upstream's own `.gitignore` is preserved untouched at
`src/.gitignore`.

That is a checkable claim rather than an assertion:

```sh
sha256sum -c UPSTREAM.sha256          # the bytes
tools/check-provenance.sh             # the bytes, the exact file set, the notices
tools/check-fixtures.py               # the three fixture digests
```

`tools/check-provenance.sh` also rejects a file that appears under `src/`
without a recorded digest, which a checksum run alone cannot see. Any future
native edit has to move those digests, add a per-file record to
[`NOTICE.md`](NOTICE.md) and a numbered entry to [`CHANGELOG.md`](CHANGELOG.md)
in the same change, and needs an observed failure to justify it.

### What this package compiles, read out of upstream

`src/Makefile.am:127-129` names the sources that make `libpng16`. This package
compiles the same **16 C units** — `png.c`, `pngerror.c`, `pngget.c`, `pngmem.c`,
`pngpread.c`, `pngread.c`, `pngrio.c`, `pngrtran.c`, `pngrutil.c`, `pngset.c`,
`pngtrans.c`, `pngwio.c`, `pngwrite.c`, `pngwtran.c`, `pngwutil.c` — and
nothing else is read as C.

Names and versions, all `SOURCE-CONFIRMED` from the vendored source:

| | | |
|---|---|---|
| library base name | `libpng16` | `src/Makefile.am:125` |
| shared object | `libpng16.so.16.59.0`, soname `libpng16.so.16` | `src/Makefile.am:178-180` (`-version-number 16:59:0`) |
| the ABI number 16 | `PNG_LIBPNG_VER_SHAREDLIB 16` | `src/png.h:281` |
| version string | `PNG_LIBPNG_VER_STRING "1.6.59"` | `src/png.h:277` |
| version components | `MAJOR 1`, `MINOR 6`, `RELEASE 59` | `src/png.h:286-288` |
| numeric version | `PNG_LIBPNG_VER 10659` | `src/png.h:319` |
| public headers | `png.h`, `pngconf.h`, plus generated `pnglibconf.h`, installed to `include/libpng16/` | `src/Makefile.am:204`, `:207` |

Two load-time facts a consumer can check without a test harness, both declared
by the translated header: `png_access_version_number()` must answer `10659`
(`src/png.h:319`, declared at `src/png.h:920`) and `png_get_libpng_ver()` must
begin `"1.6.59"` (`src/png.h:277`, declared at `src/png.h:2574`).

### The one generated input

`pnglibconf.h` is generated for the target being built by
`tools/pnglibconf.zig` from `src/scripts/pnglibconf.h.prebuilt` — **upstream's
own prebuilt configuration**, which ships inside the release tarball. This is
upstream's own fallback: `src/CMakeLists.txt:458-462` is the `elseif(NOT AWK)`
branch whose comment reads *"No AWK program available to generate pnglibconf.h.
Configure libpng with pnglibconf.h.prebuilt."* This package has no AWK
dependency, so it always takes that branch.

The generated directory precedes `src/` on every include line, and nothing is
generated into `src/` — the generator is a `Run` step whose output is a
build-cache file.

One consequence, stated precisely because it is the only thing the prebuilt
header changes: `src/scripts/pnglibconf.h.prebuilt:226` defines
`PNG_ZLIB_VERNUM 0 /* unknown */`, and `src/pngpriv.h:1026` is the one and only
place in the vendored tree that reads it, where it guards

```c
#if PNG_ZLIB_VERNUM != 0 && PNG_ZLIB_VERNUM != ZLIB_VERNUM
#  error The include path of <zlib.h> is incorrect
```

So `0` disables **only** that compile-time include-path consistency check. No
runtime behaviour, no ABI, no public header is affected. What is lost is the
ability to notice at compile time that a different `zlib.h` is on the include
line than the configuration was generated from; the declared dependency on the
sibling zlib package is what replaces it, more weakly.

### The one sibling dependency, and it is not optional

libpng is a zlib binding: `src/pngpriv.h` and `src/png.c` include `<zlib.h>` and
call `inflateInit2_`, `deflateInit2_` and siblings, so the 16 units do not
compile without a zlib on the include line and the archive does not link without
one to resolve those names. This package declares exactly one dependency:

```zig
.dependencies = .{ .zlib = .{ .path = "../zlib" } },
```

linked with `c_mod.linkLibrary(zlib_dep.artifact("zlib"))`. That link call is
the whole of the include-path story — `lib/std/Build/Module.zig:649-659` appends
the linked artifact to `include_dirs`, and `IncludeDir.appendZigProcessFlags`
(`lib/std/Build/Module.zig:183-184`) renders it as `-I` on the linked artifact's
installed-header include tree — so no separate include path appears anywhere
else, where a second one could disagree with the first.

**`PENDING-VERIFICATION`.** The `zlib/` tree was not on disk when this package
was prepared, so **no gate has exercised this wire**. The agreed surface is
recorded in [`UPSTREAM.md`](UPSTREAM.md): package directory `zlib/`,
`.name = .zlib`, `.version = "1.3.2"`, module `dep.module("zlib")`, artifact
`dep.artifact("zlib")` emitting `libz.a`/`libz.so`, public headers `zlib.h` and
`zconf.h`, and no mandatory macros for a POSIX dependent. No zlib digest, commit
or URL is recorded anywhere in this package, because none was observed.

### No SIMD is compiled

Every `PNG_*_OPT` macro is undefined and **no file** under `src/arm/`,
`src/intel/`, `src/mips/`, `src/powerpc/`, `src/loongarch/` or `src/riscv/` is
in this package's build graph. This is a **deliberate configuration**, not an
omission, and the cost of enabling each family is written out in
[`FORK-NOTES.md`](FORK-NOTES.md) §3:

* **Intel SSE** is the cheapest and the most requested. Enabling it means
  defining `PNG_INTEL_SSE_SUPPORTED` in the generated `pnglibconf.h` and
  compiling what upstream's own `src/Makefile.am:150-152` adds under
  `if PNG_INTEL_SSE`: `intel/intel_init.c` and `intel/filter_sse2_intrinsics.c`.
  Both are C with intrinsics; they need a target-conditional branch in the build
  graph because the option is architecture-specific.
* **ARM NEON** — the same shape. The gate is `PNG_ARM_NEON_API_SUPPORTED`,
  which the prebuilt configuration leaves `/*#undef ...*/`
  (`src/scripts/pnglibconf.h.prebuilt:20`); enabling it compiles
  `src/arm/arm_init.c`, `src/arm/filter_neon_intrinsics.c` and
  `src/arm/palette_neon_intrinsics.c`.
* **MIPS MSA, PowerPC VSX, LoongArch LSX, RISC-V RVV** — the same per-family
  pattern, one `*_init.c` beside each filter implementation, one option macro
  each.
* **No assembler is involved anywhere.** libpng 1.6.59 contains exactly one
  `.S` file in the whole tree, `src/arm/filter_neon.S`, and it is a *placeholder*
  by its own header (`src/arm/filter_neon.S:1-12`). Every SIMD family in this
  release is C with intrinsics, so there is no NASM, MASM or other assembler to
  work around. (Zig 0.16.0 has no NASM and its bundled clang does not accept
  NASM syntax — worth knowing for a *future* release that reintroduces assembler
  filters, not for this one.)

**What this package therefore is:** the portable C configuration of libpng,
which upstream also produces and supports — **not** libpng's full-speed x86
configuration, and no parity with it is claimed. Filtered images will be
slower on any machine whose SIMD family is switched off here. That is a stated
boundary, not a defect and not a silent substitution.

Upstream's SIMD directories are still carried, digested and licence-recorded in
the vendored tree; see [`NOTICE.md`](NOTICE.md), which names each one's own
"released under the libpng license" line individually.

### Upstream's test material is carried but not run

`src/tests/` and `src/contrib/` — including the PNG corpus (`pngsuite/`,
`libtests/`, `testpngs/`, `oss-fuzz/`) — ship untouched inside the vendored tree
and are recorded as **carried-but-not-run**. They are never deleted, they are not
built (upstream drives them from `Makefile.am` test targets this package does not
run), and no step fetches anything to stand in for them. This package's own
fixtures do **not** replace them; they are a separate, fork-authored set with
their own provenance.

There is no `src/testimages/` directory in libpng 1.6.59 — that name belongs to
other projects, and recording it here would be a small lie about the tarball.

### This package's own fixtures

Three PNG files under `fixtures/`, written by `tools/make-fixtures.py` with **no
image library**: the container is assembled by hand from ISO/IEC 15948 and the
only borrowed facility is `zlib.compress`, because `IDAT` is *defined* as a zlib
stream. They are independent known answers, not round trips.

| Fixture | sha256 | Bytes | What a decoder must produce |
|---|---|---:|---|
| `fixtures/grey8x8-200.png` | `4cd467a6c469e7890696808a829808d1137a991a8f6a55c9113339853272a283` | 71 | 8×8, colour type 0 (greyscale), every sample exactly `200` |
| `fixtures/rgb4x3.png` | `a37878d39ff5765cfa4cee3cd7d9723b3cb761e65ae0d9f3f0873ff96adf44ff` | 97 | 4×3, colour type 2, row filters none/Sub/none — see below |
| `fixtures/rgba2x2.png` | `3c5f2d8cdf5195958619e1ff666f9a2fb439863996996e2de09f54b15f512ba9` | 80 | 2×2, colour type 6, filter Sub on both rows — see below |

`rgb4x3.png`, exactly:

| | col 0 | col 1 | col 2 | col 3 |
|---|---|---|---|---|
| row 0 | (0,0,0) | (255,0,0) | (0,255,0) | (0,0,255) |
| row 1 | (255,255,255) | (128,128,128) | (255,255,0) | (0,255,255) |
| row 2 | (1,2,3) | (10,20,30) | (200,100,50) | (7,255,0) |

`rgba2x2.png`, exactly:

| | col 0 | col 1 |
|---|---|---|
| row 0 | (0,0,0,0) | (255,0,0,64) |
| row 1 | (0,255,0,128) | (0,0,255,255) |

The full specification, with the arithmetic and why each image is chosen to make
a wrong decoder produce a different picture, is in [`UPSTREAM.md`](UPSTREAM.md).

## Native-build deviations

What the compiled package does that upstream's build systems do not. Each is a
fork decision with a stated reason; none changes an algorithm.

* **Zig builds it; upstream's two build systems are unused.** `build.zig`
  compiles the closure `src/Makefile.am:127-129` names. No CMake, no autotools,
  no `configure`, and no download at build time.
* **Two delivery linkages.** `-Dlinkage=static` (default) produces
  `libpng16.a`; `-Dlinkage=dynamic` produces `libpng16.so.16.59.0` with soname
  `libpng16.so.16`. The 16 is the ABI number upstream states in
  `src/png.h:281`, and `16:59:0` is upstream's own `-version-number`
  (`src/Makefile.am:178-180`). Upstream's `Makefile.am` builds a libtool
  library and installs both forms, so neither linkage is an invention; static is
  the default because an archive is what a linked consumer usually wants.
* **One version, read out of the header.** `build.zig` compares
  `build.zig.zon`'s `.version` against the `PNG_LIBPNG_VER_*` constants read out
  of `src/png.h` and refuses to configure if they disagree, so the manifest, the
  `libpng16.pc` `Version:` field, the shared object's file name and the
  generated `pnglibconf.h` banner cannot describe different releases.
* **The full installed closure.** `include/libpng16/` with `png.h`, `pngconf.h`
  and the generated `pnglibconf.h` (`src/Makefile.am:206`, `:207` — upstream
  installs into `$(includedir)/$(PNGLIB_BASENAME)`, which is `libpng16`);
  `lib/libpng16.a` or the three shared names; `lib/pkgconfig/libpng16.pc`
  (`src/Makefile.am:212` `pkgconfig_DATA`, from `src/libpng.pc.in`); `share/man`
  with `libpng.3`, `libpngpf.3` and `png.5` (`src/Makefile.am:117`
  `dist_man_MANS`); and `share/licenses/` carrying upstream's
  `LICENSE` together with this fork's records.
* **A typed Zig surface beside the raw one.** `zig/root.zig` publishes a
  documented facade over the same library, with the translated headers reached
  as `c` on that module. Documented in [`README.zig.md`](README.zig.md).
* **Optional runtime loading.** `-Druntime=true` selects a load-at-runtime
  route with explicit `.path` or `.system` selection, one process-lifetime
  table, no fallback, no automatic retry, atomic publication and an ordinary
  pre-initialization panic — not `std.debug.assert` — in every optimize mode.
  The linked route stays direct.
* **The facade translation needs `<stdio.h>` and `<setjmp.h>` before
  `<png.h>`.** This is upstream's own header shape, not a wrapping problem:
  `src/png.h`'s entire include closure is `pnglibconf.h` (`src/png.h:328`) and
  `pngconf.h` (`src/png.h:333`), and `src/pngconf.h:30-31` includes only
  `<limits.h>` and `<stddef.h>`. Yet `src/png.h:1629` declares `png_init_io(
  ..., FILE *fp)` under `PNG_STDIO_SUPPORTED` and `src/png.h:971` declares
  `png_set_longjmp_fn(..., jmp_buf *, ...)` under `PNG_SETJMP_SUPPORTED`. So
  `zig/translate.h` includes `<stdio.h>` and `<setjmp.h>` ahead of the library
  header. **An installed C consumer is expected to supply `<stdio.h>` before
  `png.h>` for the same reason**, and that expectation is written into
  `zig/translate.h`'s own comment.
* **No system mode.** There is no `-Dsystem` option: this package builds the
  vendored source and nothing else. A record with no system mode is vacuous, not
  satisfied.

### History of these deviations

The deviations above are the current state, and all of them landed in the same
change as the import itself. [`CHANGELOG.md`](CHANGELOG.md) numbers them — entry
1 is the whole initial import — and [`FORK-NOTES.md`](FORK-NOTES.md) records the
condition, symptom, fix and boundary of each decision.

## Support matrix

### What has been run

Three gates were run here on 2026-10-05, with the pinned Zig 0.16.0 at
`/home/tmp2/gertullj/zig-global-cache/p/N-V-__8AAFFSVRWqblwBIcA-Yqv-u7sbjsJoww8K0mWaHbmJ/zig`,
`-j8 --summary all`, default optimize mode. Everything else — `smoke`, the
shared linkage, the runtime-loaded route, the installed C surface, the consumer
run, Nix, devenv and CI — is still `PENDING-VERIFICATION` and nothing below may
be read as a receipt for it.

`cross-test` is the only one of the three that executed a test binary. Its
per-cell result is in [`FORK-NOTES.md`](FORK-NOTES.md) §11 and
[`CHANGELOG.md`](CHANGELOG.md) entry 3; the classified table with every cause is
at `/home/tmp2/gertullj/libpng-cross-test-53-cell-summary.md`.

### The six compile targets

| Target | What a gate would establish | Status |
|---|---|---|
| `x86_64-linux-gnu` | compile the 16-unit closure, run the tests and smoke against the linked route | compiles (`zig build check`) |
| `aarch64-linux-gnu` | the same, compiled for the target | compiles (`zig build check`) |
| `aarch64-macos-none` | the same, compiled for the target | compiles (`zig build check`) |
| `x86_64-windows-gnu` | the same, compiled for the target | compiles (`zig build check`) |
| `riscv64-linux-gnu` | the same, compiled for the target | compiles (`zig build check`, exit 0 after the `-D` in `CHANGELOG.md` entry 2) |
| `wasm32-wasi` | **a recorded platform boundary.** Not refused and not a pass: both halves of the row fail inside the pinned toolchain's wasi-libc, `libc/include/wasm-wasi-musl/setjmp.h:13`, reached from `src/pngconf.h:50`. See [`FORK-NOTES.md`](FORK-NOTES.md) §5 | fails; `zig build check` exits 1 |

Those are compile results and nothing more. A compiling cell is not a test pass:
no target binary was executed by `check`, so every row above is `build_only` at
best, and the behavioural proof is still decoding the three fixtures to the exact
expected pixels above. `wasm32-wasi` is not `build_only` at all; it is a cell that
does not compile.

### The 53 published platforms

One `cross-test` invocation, 2026-10-05, from the library root, harness **exit
1** over 53 targets, reporting `pass=18 fail=17 build_only=0 partial=18`.
Classified, with every cause and log path, in [`FORK-NOTES.md`](FORK-NOTES.md)
§11 and [`CHANGELOG.md`](CHANGELOG.md) entry 3.

| Class | Cells | What it means here |
|---|---|---|
| `pass` | 18 | `Build Summary: 12/12 steps succeeded; 9/9 tests passed`, run natively or under `qemu-user`. These are the only cells in this repository that may be called passing. |
| `build_only` | 18 | Compiled; `run test libpng-tests skipped`; nothing executed, no test count. Per `AGENTS.md` never a pass. macOS, maccatalyst, FreeBSD, OpenBSD and Windows have no runner on this host. |
| refused | 0 | `build.zig` refuses nothing; `refused_check_targets` is empty. |
| runtime failure | 2 | `powerpc64-linux`, `powerpc64le-linux`: 9/9 tests crash on a misaligned `png_struct`, because ppc64-musl's `jmp_buf` needs 16-byte alignment and that target's `malloc` supplies 8. |
| build failure | 15 | 14 netbsd/openbsd rows plus `wasm32-wasi`, every one inside the pinned toolchain's own libc headers. |

The 18 passing cells are `x86_64-linux`, `aarch64-linux`, `aarch64_be-linux`,
`arm-linux`, `armeb-linux`, `hexagon-linux`, `loongarch64-linux`, `mips-linux`,
`mipsel-linux`, `mips64-linux`, `mips64el-linux`, `powerpc-linux`,
`riscv32-linux`, `riscv64-linux`, `s390x-linux`, `thumb-linux`, `thumbeb-linux`
and `x86-linux`.

### The two linkages, and the two routes

| Configuration | What a gate would establish | Status |
|---|---|---|
| linked, static delivery | `zig build`, `test`, `smoke` against `libpng16.a` | `zig build` **exit 0** on 2026-10-05; `test` ran 9/9 on 18 of the 53 `cross-test` cells; `smoke` not run |
| linked, shared delivery | the same against `libpng16.so.16.59.0` and its soname | not run |
| runtime-loaded | the whole suite through the resolved table, against an explicitly named provider this graph built | `PENDING-VERIFICATION` |
| installed C surface | a plain C program compiled against the installed headers and `libpng16.pc`, in both linkages | `PENDING-VERIFICATION` |
| consumer package | `dep.module("libpng")` resolving from a package that did not write it, in both linkages | `PENDING-VERIFICATION` |

A successfully compiled `libpng16.a` is **not** a facade result, and a `zig fmt`
exit 0 is not a gate. The behavioural proof is decoding the three fixtures to
the exact expected pixels above.

### The recorded gates the driver must run

| Gate | Command | Status |
|---|---|---|
| build | `zig build` | **exit 0** on 2026-10-05 |
| compile matrix | `zig build check` (the six targets above) | **exit 1** on 2026-10-05: five rows compile, `wasm32-wasi` fails |
| tests, Debug | `zig build test` | Debug `test` step was run on all 53 cells by `cross-test` (which runs exactly `zig build test -Dtarget=TARGET`, default optimize mode): 18 executed 9/9 and passed, 18 compiled without running, 2 crashed, 15 did not compile. See §11 |
| tests, ReleaseSafe | `zig build test -Doptimize=ReleaseSafe` | `PENDING-VERIFICATION` |
| smoke | `zig build smoke` | `PENDING-VERIFICATION` |
| consumer, nested | `zig build consumer` | `PENDING-VERIFICATION` |
| consumer, entered directly | `cd consumer && zig build run` | `PENDING-VERIFICATION` |
| published platform matrix | `cross-test` (53 platforms) | **exit 1** on 2026-10-05: 18 cells pass 9/9, 18 `build_only`, 0 refused, 2 runtime failures (`powerpc64-linux`, `powerpc64le-linux`), 15 build failures (14 netbsd/openbsd rows, `wasm32-wasi`). See [`FORK-NOTES.md`](FORK-NOTES.md) §11 |
| provenance | `tools/check-provenance.sh` | **exit 0** on 2026-10-05: 918-file upstream digests and the fork records |
| fixtures | `tools/check-fixtures.py` | `PENDING-VERIFICATION` |
| Nix, static | `nix build .#static` | `PENDING-VERIFICATION` |
| Nix, shared | `nix build .#shared` | `PENDING-VERIFICATION` |
| devenv outputs | `devenv build outputs.static`, `devenv build outputs.shared` | `PENDING-VERIFICATION` |

Add `-j8`, `--cache-dir "$CACHE/libpng/<target>"` and `--summary all` per the
workspace's verification interface.

### The load-time ABI self-check a gate should run

There is **no version symbol to check**: libpng exports no `libpng_version()`
function, and the version macros are compile-time constants in the generated
`pnglibconf.h`. Inventing a version check would mean checking something that is
not there. The honest self-check, through the resolved table, is behavioural:

1. `png_access_version_number()` answers `10659`, and `png_get_libpng_ver()`
   begins `"1.6.59"` — both declared by the translated header
   (`src/png.h:920`, `src/png.h:2574`).
2. `png_create_read_struct` + `png_create_info_struct` succeed;
   `png_init_io` on a `FILE *`; `png_read_png`; `png_get_image_width`,
   `png_get_image_height`, `png_get_color_type` and `png_get_channels` answer
   the fixture's own numbers; `png_destroy_read_struct` frees it.
3. The decoded pixels equal the tables above exactly.

## Consumption

Four routes, one of them two-faced. Full detail, with a worked example, in
[`README.zig.md`](README.zig.md).

* **Typed Zig:** add the dependency, `dep.module("libpng")`, `@import("libpng")`.
* **Raw C from Zig:** `pub const c` on that same module.
* **C:** `dep.artifact("png16")`, which is what makes `libpng16.a` and
  `libpng16.so.16.59.0` the names upstream's own build produces.
* **Installed tree:** `include/libpng16/*.h`, `lib/libpng16.*`,
  `lib/pkgconfig/libpng16.pc`, `share/man`.

```zig
// build.zig.zon of a dependent
.dependencies = .{ .libpng = .{ .path = "../libpng/libpng" } },

// build.zig of a dependent
const dep = b.dependency("libpng", .{ .target = target, .optimize = optimize });
exe_mod.linkLibrary(dep.artifact("png16"));
const png = dep.module("libpng");   // the typed facade
const c = png.c;                    // the raw translated C headers
```

## Records

| File | What it is |
|---|---|
| [`UPSTREAM.md`](UPSTREAM.md) | the pin, the import mechanism, what was and was not modified, the generated-input decision, the fixture provenance |
| [`UPSTREAM.sha256`](UPSTREAM.sha256) | all 614 upstream file digests — the complete set, not a selection |
| [`NOTICE.md`](NOTICE.md) | the per-file licence inventory. **libpng is not MIT** |
| [`FORK-LICENSE.md`](FORK-LICENSE.md) | the owner-authorised MIT grant for this fork's own files |
| [`FORK-NOTES.md`](FORK-NOTES.md) | every decision as condition / symptom / fix / targets bound |
| [`CHANGELOG.md`](CHANGELOG.md) | numbered changes |
| [`README.upstream.md`](README.upstream.md) | upstream's `README`, byte-identical to `src/README` |
| [`README.zig.md`](README.zig.md) | the consumption routes in detail |

No entry in any of them reports a passing test, because none has been run. Two
compile gates are recorded where they belong: [`FORK-NOTES.md`](FORK-NOTES.md)
§5 and §6, with their receipts named there.