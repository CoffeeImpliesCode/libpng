# Upstream

Which upstream this package is built from, what was taken from it byte for byte,
what this package generates from it, and what was not taken at all.

## Canonical source

| | |
|---|---|
| Project | libpng, the PNG Reference Library |
| Authoritative site | <http://www.libpng.org/pub/png/libpng.html> |
| Artifact | `libpng-1.6.59.tar.gz` |
| URL | <https://downloads.sourceforge.net/project/libpng/libpng16/1.6.59/libpng-1.6.59.tar.gz> |
| Released | 2026-09-28 |
| Size | 1589315 bytes |
| sha256 | `86a3e4b501f7f50e392c4e456ea158893e9a595b1c63eb88c7bb9f6cf8772dad` |

The tarball itself is served from **SourceForge**, at the `downloads.sourceforge.net`
path above; libpng.org is where the project announces releases and hosts its
documentation and public-key-signed release directory listing. Both facts are
recorded because they are two different roles and a pin that names only one of
them misstates where the bytes came from.

`SOURCE-CONFIRMED`: the release date, byte count and digest are the values
recorded in this repository's own provenance records — the header comment of
[`UPSTREAM.sha256`](UPSTREAM.sha256) and, identically, the table above. They were
observed at import time and have not been re-derived since. `tools/check-provenance.sh`
fails if the two records ever name different digests.

There is **no VCS import and therefore no commit SHA**. A release archive is
what this package is built from; see "Import mechanism" below. No commit, tag
or revision is invented to fill the gap, because none was observed.

## Import mechanism

A release tarball, imported whole. The tarball carries no upstream Git history
in this import, so this tree has no history to keep, no patch series to
re-apply, and no commit identity to record. The tree either matches the tarball
or a deviation is recorded.

Re-syncing to another release means, in one change: download the new tarball,
verify its published sha256, replace the imported files, regenerate
`UPSTREAM.sha256`, update this file, [`NOTICE.md`](NOTICE.md) and
[`README.md`](README.md), and add a numbered [`CHANGELOG.md`](CHANGELOG.md)
entry.

The imported bytes were checked two ways at import time and both are repeatable
by anyone:

```sh
sha256sum -c UPSTREAM.sha256          # each file's digest, one by one
tools/check-provenance.sh             # digests, the exact file set, the notices
diff -rq src <extracted tarball>      # the whole tree, byte for byte
```

`diff -rq` reported no difference: `src/` is byte-identical to the extracted
release tarball. That is a reading of two directories, not a build gate.

## The preserved upstream README

The release tarball ships a file called `README`, which is upstream's own
release note and **not** a fork README. It is preserved here twice, unaltered:

* `src/README` — the imported original, exactly as the tarball carries it.
* `README.upstream.md` — the same bytes under the name the rest of this
  repository uses for a preserved upstream README.

Both are **9485 bytes with sha256
`b74a298f460282116bc83d8e13afc38b50105d89016f4f7f64fca54c221c2606`**, and
`cmp src/README README.upstream.md` reports no difference — that comparison was
run and it printed nothing, which is the confirmation recorded here. It is not a
digest, because `UPSTREAM.sha256` already records `src/README` by digest;
`README.upstream.md` is deliberately not a 615th digested file, and
`tools/check-provenance.sh` is what proves the copy has not drifted from the
original. The canonical fork document is [`README.md`](README.md).

## What is in the tarball

**614 files**, the complete file list of the release tarball. The whole project
is imported: nothing is dropped for size, and nothing is dropped for being
uncompiled by this package. That includes upstream's own test programs
(`src/tests/`) and its contribution material (`src/contrib/`, which is where the
test PNG corpus lives in 1.6.59), plus the autotools files (`configure`,
`aclocal.m4`, `Makefile.in`), the CMake files, the CI definitions, the per-
architecture intrinsics sources and the manual pages. `UPSTREAM.sha256` is that
set in full, not a selection.

Carried but not compiled, and why that is a decision rather than an omission:

| Carried, uncompiled | Why |
|---|---|
| `src/tests/`, `src/contrib/`, the sample images | upstream's own test programs (`src/tests/`) and its contribution material (`src/contrib/` — `pngsuite/`, `libtests/`, `testpngs/`, `oss-fuzz/` and the rest, 339 files, of which 201 are PNGs). Plus the three root-level sample images `src/pngtest.png`, `src/pngbar.png` and `src/pngnow.png`. They are never deleted and never substituted for by this package's fixtures; they are also not built, because upstream drives them from `Makefile.am` test targets this package does not run. Recorded here as **carried-but-not-run**. There is no `src/testimages/` directory in libpng 1.6.59. |
| `src/arm/`, `src/intel/`, `src/mips/`, `src/powerpc/`, `src/loongarch/`, `src/riscv/` | the architecture-specific filter implementations. This package compiles none of them; see "No SIMD is compiled" in [`README.md`](README.md). |
| `src/pngtest.c`, `src/example.c` | upstream's example/test programs. `src/example.c:18-19` states it "is not officially part of libpng, is hereby placed in the public domain, and therefore does not require a copyright notice", so it is carried with its own dedication and not as part of the compiled core. |
| `configure`, `aclocal.m4`, `Makefile.in`, `CMakeLists.txt` | upstream's two build systems. Neither is used; `build.zig` owns every compile flag. |
| `src/ci/`, `src/.github/workflows/`, `src/.appveyor.yml` | upstream's own CI, targeting upstream's maintainers' infrastructure. Preserved verbatim and never run by this fork. |

## What was modified in `src/`

**Nothing.** No file under `src/` has been edited, reformatted, re-entered or
regenerated. `UPSTREAM.sha256` plus the exact-file-set comparison in
`tools/check-provenance.sh` are what make that checkable rather than asserted:
the digests cover every one of the 614 files, and the script rejects a file that
appears under `src/` without a recorded digest, which a plain checksum run alone
cannot see.

Any future native edit has to move those digests, add a per-file record to
[`NOTICE.md`](NOTICE.md) and a numbered entry to [`CHANGELOG.md`](CHANGELOG.md)
in the same change, and needs an observed failure to justify it.

## The one generated input, and where it comes from

`pnglibconf.h` is the only file this package generates, and it is generated for
the target being built by `tools/pnglibconf.zig` from
`src/scripts/pnglibconf.h.prebuilt` — **upstream's own prebuilt configuration
file**, which ships inside the release tarball.

This is upstream's own fallback path, not an invention. `src/CMakeLists.txt:458-462`
is the `elseif(NOT AWK)` branch:

```cmake
elseif(NOT AWK)
  # No AWK program available to generate pnglibconf.h.
  # Configure libpng with pnglibconf.h.prebuilt.
  png_check_libconf(HEADER "${PNG_LIBCONF_HEADER_PREBUILT}")
  configure_file("${PNG_LIBCONF_HEADER_PREBUILT}"
                 "${CMAKE_CURRENT_BINARY_DIR}/pnglibconf.h"
                 @ONLY)
```

So when upstream's CMake cannot run AWK it configures the build from exactly
this prebuilt header. This package always takes that branch — it has no AWK
dependency and therefore no second source of truth for the configuration.

One consequence is worth stating precisely, because it is the only thing the
prebuilt header changes about the compiled library.
`src/scripts/pnglibconf.h.prebuilt:226` defines

```c
#define PNG_ZLIB_VERNUM 0 /* unknown */
```

and the **only** place that macro is read in the entire vendored tree is
`src/pngpriv.h:1026`, where it guards a compile-time include-path consistency
check:

```c
#if PNG_ZLIB_VERNUM != 0 && PNG_ZLIB_VERNUM != ZLIB_VERNUM
#  error The include path of <zlib.h> is incorrect
```

With `PNG_ZLIB_VERNUM` 0 the first conjunct is false, so the check does not
fire. Nothing else reads the macro: no runtime behaviour, no ABI, and no public
header is affected. What the package loses is upstream's ability to *notice* at
compile time that a build is looking at a different `zlib.h` than the one the
configuration was generated from. The declared dependency on the sibling `zlib`
package is what replaces that check — see `README.md`.

The generated directory is placed **before** `src/` on every include line, so
the generated header is the one every translation unit sees, and the vendored
prebuilt copy under `src/scripts/` is never on an include path.

Nothing is generated *into* `src/`. The generator is a `Run` step whose output
is a build-cache file, so the vendored tree stays byte-identical.

## The C closure, as upstream lists it

`src/Makefile.am:127-129` names the sources that make `libpng16`:

```
libpng@PNGLIB_MAJOR@@PNGLIB_MINOR@_la_SOURCES = png.c pngerror.c\
   pngget.c pngmem.c pngpread.c pngread.c pngrio.c pngrtran.c pngrutil.c\
   pngset.c pngtrans.c pngwio.c pngwrite.c pngwtran.c pngwutil.c\
   png.h pngconf.h pngdebug.h pnginfo.h pngpriv.h pngstruct.h pngusr.dfa
```

That is **16 C units** — `png.c`, `pngerror.c`, `pngget.c`, `pngmem.c`,
`pngpread.c`, `pngread.c`, `pngrio.c`, `pngrtran.c`, `pngrutil.c`, `pngset.c`,
`pngtrans.c`, `pngwio.c`, `pngwrite.c`, `pngwtran.c`, `pngwutil.c` — plus the
headers and `pngusr.dfa`. This package compiles the same 16 units and reads
nothing else as C.

Names and versions, all read out of the vendored source rather than assumed:

* `src/Makefile.am:125` — `lib_LTLIBRARIES=libpng@PNGLIB_MAJOR@@PNGLIB_MINOR@.la`,
  i.e. `libpng16`.
* `src/Makefile.am:178-180` — `-version-number
  @PNGLIB_MAJOR@@PNGLIB_MINOR@:@PNGLIB_RELEASE@:0`, i.e. `16:59:0`, which is what
  produces `libpng16.so.16.59.0` with soname `libpng16.so.16`.
* `src/png.h:281` — `#define PNG_LIBPNG_VER_SHAREDLIB 16`, the same 16.
* `src/png.h:277` — `#define PNG_LIBPNG_VER_STRING "1.6.59"`.
* `src/png.h:286-288` — `PNG_LIBPNG_VER_MAJOR 1`, `MINOR 6`, `RELEASE 59`.
* `src/png.h:319` — `#define PNG_LIBPNG_VER 10659 /* 1.6.59 */`.

Public headers, per `src/Makefile.am:204` and `:207`: `png.h` and `pngconf.h`
(`pkginclude_HEADERS`), plus the generated `pnglibconf.h`
(`nodist_pkginclude_HEADERS`), installed into `include/libpng16/`.

## The one sibling dependency: zlib

libpng is a zlib binding: `src/pngpriv.h` and `src/png.c` include `<zlib.h>`
and call `inflateInit2_`, `deflateInit2_` and their siblings, so the 16 units do
not compile without a zlib on the include line and the archive does not link
without one to resolve those names. This package therefore declares exactly one
dependency, `.zlib = .{ .path = "../zlib" }`, and links
`dep.artifact("zlib")`.

**`PENDING-VERIFICATION`.** The zlib tree was not on disk when this package was
prepared, so no gate has exercised this wire. The surface agreed for it is
recorded here so a later wave can check the wire rather than infer it:

| | |
|---|---|
| Package directory | `zlib/` (a sibling of this one) |
| `.name` | `.zlib` |
| `.version` | `1.3.2` |
| Zig module | `dep.module("zlib")` |
| C artifact | `dep.artifact("zlib")`, emitting `libz.a` / `libz.so` |
| Public headers | `zlib.h`, `zconf.h` |
| Mandatory macros for a dependent | none on POSIX |

No zlib digest, commit or URL is recorded here, because none was observed. The
link call is what puts zlib's headers on the include line, so no separate include
path appears anywhere in this package.

## The fixtures, and where their expected answers come from

The three PNG images under `fixtures/` are **not** upstream files. They are
inputs this package's own tests read, and they were written for it.

`tools/make-fixtures.py` writes them. It uses **no image library**: not libpng,
not Pillow, not ImageMagick. The container is assembled by hand from
ISO/IEC 15948 — the eight-byte signature, an `IHDR`, one `IDAT` holding a zlib
stream over the filtered scanlines, and an `IEND`. The only facility borrowed is
`zlib.compress`, because `IDAT` is *defined* as a zlib stream (ISO/IEC 15948
§11.2.4) and the CRC-32 and ADLER-32 the format specifies are the ones zlib
computes.

That is what makes them independent known answers rather than a round trip: the
bytes come from an encoder written from the specification, and the pixels each
test expects are written out in arithmetic in `tools/make-fixtures.py` rather
than read back out of a file this package produced.

| Fixture | sha256 | Bytes |
|---|---|---:|
| `fixtures/grey8x8-200.png` | `4cd467a6c469e7890696808a829808d1137a991a8f6a55c9113339853272a283` | 71 |
| `fixtures/rgb4x3.png` | `a37878d39ff5765cfa4cee3cd7d9723b3cb761e65ae0d9f3f0873ff96adf44ff` | 97 |
| `fixtures/rgba2x2.png` | `3c5f2d8cdf5195958619e1ff666f9a2fb439863996996e2de09f54b15f512ba9` | 80 |

The expected decoded pixels, hand-computed and independent of the library under
test:

**`fixtures/rgb4x3.png`** — 4×3, colour type 2 (RGB), bit depth 8, row filters
none / Sub / none.

| | column 0 | column 1 | column 2 | column 3 |
|---|---|---|---|---|
| row 0 | (0,0,0) | (255,0,0) | (0,255,0) | (0,0,255) |
| row 1 | (255,255,255) | (128,128,128) | (255,255,0) | (0,255,255) |
| row 2 | (1,2,3) | (10,20,30) | (200,100,50) | (7,255,0) |

Row 0's filter byte is 0 (None), so its bytes are the pixels verbatim. Row 1's
filter byte is 1 (Sub): each byte is the difference from the byte three positions
earlier in the same row, so (255,255,255) after (0,0,0) reconstructs to
(255,255,255), and (128,128,128) after (255,255,255) reconstructs to
(128,128,128), and so on down the row. Row 2's filter byte is 0 again. The
asymmetric values 1/2/3, 10/20/30, 200/100/50 and 7/255/0 are chosen so that a
decoder that transposes channels, drops the alpha step or reorders rows produces
a different picture rather than the same one.

**`fixtures/rgba2x2.png`** — 2×2, colour type 6 (RGBA), filter Sub on both rows.

| | column 0 | column 1 |
|---|---|---|
| row 0 | (0,0,0,0) | (255,0,0,64) |
| row 1 | (0,255,0,128) | (0,0,255,255) |

Row 0's first pixel is the unfiltered origin (0,0,0,0); its second pixel is the
byte-wise difference from it, which is why the alpha channel carries a distinct
ramp 0 → 64 → 128 → 255 that a decoder dropping or clamping alpha cannot
reproduce.

**`fixtures/grey8x8-200.png`** — 8×8, colour type 0 (greyscale), bit depth 8,
every sample exactly 200. A flat image: any decoder that loses a row, shifts the
image by one or applies a wrong reconstruction filter produces a different
picture.

`tools/check-fixtures.py` compares the three digests above against the files on
disk. It is a provenance check, not a behavioural gate: no image is decoded and
no assertion about libpng is made.

## Third-party material in this repository

Only the zlib sibling described above, which is a separate package with its own
vendored tree and its own records, referenced by a relative path. There is no
other vendored dependency, no downloaded header, no external data file, and
nothing is fetched at build time. Every file in this repository other than the
614 under `src/` was written for this fork.