# FORK-LICENSE.md — the grant for this fork's own files

[`NOTICE.md`](NOTICE.md) is the inventory: which files are upstream's, which are
this fork's, and which term covers each. This file is the grant itself, for the
second group only.

## 1. The native source is not covered by anything below

The 614 files under `src/` are libpng's, whole from
`libpng-1.6.59.tar.gz`, and none of them has been edited.

Which upstream term covers which of those files is **not** one answer, and the
table in [`NOTICE.md`](NOTICE.md) is the authority:

| Upstream files | Term, and where it is written |
|---|---|
| the 16 compiled C units of `src/Makefile.am:127-129` and their public and private headers (`png.h`, `pngconf.h`, `pngdebug.h`, `pnginfo.h`, `pngpriv.h`, `pngstruct.h`) | **PNG Reference Library License version 2** — `src/LICENSE:4` |
| the rest of the vendored tree, including `src/pngusr.dfa`, the autotools files, the CMake files, the manual pages and the per-architecture intrinsics sources | the same PNG Reference Library License version 2, each intrinsics file restating it in its own contributor block (`src/arm/filter_neon_intrinsics.c:8` and its five siblings), and `src/pngusr.dfa` carrying no notice of its own at all (`src/pngusr.dfa:2-14`) |
| `src/LICENSE:39-42` | the historical **PNG Reference Library License version 1**, stated in that file for libpng 0.5 through 1.6.35. Preserved because the release ships it; not the grant covering 1.6.59's code |
| `src/example.c:18-19` | **public domain**, by upstream's own dedication. Not officially part of libpng, and not compiled here |
| `src/ci/**` (49 files) | **MIT** — `src/REUSE.toml:3-5`, text at `src/LICENSES/MIT.txt:1` |
| `src/.github/workflows/**` (4 files) | **MIT-0** — `src/REUSE.toml:7-9`, text at `src/LICENSES/MIT-0.txt:1` |
| `src/CMakeLists.txt`, `src/scripts/cmake/**` (9 files) | PNG Reference Library License version 2, stated by those files themselves as `SPDX-License-Identifier: libpng-2.0` |

**libpng is not MIT.** The compiled core is under the PNG Reference Library
License version 2, a different grant with its own conditions, and stating "MIT"
for it would be a misdescription. It is also not a single term across the tree:
`src/ci/**` really is MIT, `src/.github/workflows/**` really is MIT-0, and
`src/example.c` really is public domain.

Nothing in this file re-grants, narrows, widens or conditions any of those
terms, and nothing here asserts that the PNG Reference Library Authors, Cosmin
Truta, Glenn Randers-Pehrson, Andreas Dilger or any other named contributor
wrote, reviewed or endorsed a line of fork code.

## 2. The fork-authored material

Everything else in this repository — the Zig build graph and its manifest, the
typed module and its tests, the example, the consumer package, the
runtime-loading route, the generated-input tool, the fixture generator, the
integrity scripts, the packaging and the documentation — was written for this
fork. `README.upstream.md` is the one named exception in the *other* direction:
it is a byte-for-byte copy of upstream's own `src/README`, kept under this
repository's naming convention, and it is upstream material under its upstream
term rather than fork work.

### No upstream source in a fork-authored file

**No upstream source was copied into any fork-authored file.** No upstream `.c`
line, header, macro, table, generated value, script or comment was pasted into
`build.zig`, `zig/`, `tests.zig`, `smoke.zig`, `consumer/`, `runtime/`,
`tools/`, the Nix files or the documentation. Every fork-authored file cites the
upstream file and line it is derived from by reference; none carries an upstream
copyright notice, because none contains upstream code.

Two consequences worth keeping distinct:

* No upstream permission is claimed over fork-authored work, and no upstream
  grant is extended to it. The grant below is the owner's, on their own
  authority.
* The upstream terms still travel with the upstream bytes. A consumer who takes
  `libpng16.a` still owes the PNG Reference Library License version 2 conditions
  in `src/LICENSE`, exactly as before this fork existed.

### Grant

**Those files are released under the MIT License**, the term the owner
authorized for this project's fork-authored additions:

```
MIT License

Copyright (c) 2026 the contributors to this fork

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

The same obligation MIT imposes applies to this text: keep the notice with
copies of the fork's files.

### Authority for that grant

The owner of this repository authorized per-project licensing for fork-authored
additions as part of the SDK contract-migration wave, with the term chosen per
project. The authorization is recorded here and in [`NOTICE.md`](NOTICE.md); the
term above is the owner's, reached by that authorization and not by any upstream
grant.

The owner is not named and no individual copyright holder is invented: the
copyright line is deliberately the collective one.

**MIT is a choice here, and it is deliberately *not* the upstream term.** For a
project whose primary term is MIT, matching upstream is the obvious call. Here
the primary upstream term is the PNG Reference Library License version 2, which
is not MIT and carries conditions MIT does not, and this fork's own additions are
independently authored work that does not need those conditions — they are not
derived from libpng's code. The authorization covers choosing MIT; it does not
cover re-licensing libpng under it, and nothing here attempts to.

### SPDX identifier

```
MIT
```

The plain registered identifier, with no `LicenseRef-` wrapper — and the reason
is worth being exact about, because in this project the wrapper would be the
*wrong* direction. `libpng-2.0`, upstream's own SPDX identifier for the PNG
Reference Library License version 2 (`src/CMakeLists.txt` and
`src/scripts/cmake/**`), is not an SPDX-listed licence identifier; it is a
LicenseRef-shaped name that upstream uses for a term this file does not grant.
The fork-authored files carry `MIT`, which is the registered plain identifier
for the grant above and for nothing else. The two terms must not be conflated,
which is exactly why [`NOTICE.md`](NOTICE.md) keeps a per-file inventory
instead of a single package label.

`tools/check-provenance.sh` checks that the upstream notices are still in the
files [`NOTICE.md`](NOTICE.md) says they are in — including the two MIT texts and
the version 2 and version 1 headers in `src/LICENSE` — so this inventory stays
tied to the bytes rather than to this document.

### What this does not do

* It does not re-license, sublicense or add a condition to any libpng file.
* It does not assert that the PNG Reference Library Authors, Cosmin Truta,
  Glenn Randers-Pehrson, Andreas Dilger, the Loongson Technology Corporation or
  Google LLC authored, reviewed, endorsed or is affiliated with the fork's
  files.
* It does not discharge libpng's obligations. A consumer who ships a libpng
  1.6.59 binary, static or shared library, or the installed headers, still owes
  the PNG Reference Library License version 2 terms in `src/LICENSE`, and the
  upstream `src/ci/**` and `src/.github/workflows/**` terms for those subtrees;
  see [`NOTICE.md`](NOTICE.md) for where each travels.
* It does not claim MIT is the only term the owner could have chosen for
  independently authored work, nor that it is the right term for the vendored
  library.

## 3. Material carried but not authored here

Two things, and neither is a third-party code import:

1. **The vendored upstream tree.** The 614 files in `src/`, complete and
   unmodified, under the terms in section 1. [`UPSTREAM.md`](UPSTREAM.md) is the
   pin: libpng 1.6.59, released 2026-09-28, 1589315 bytes, sha256
   `86a3e4b501f7f50e392c4e456ea158893e9a595b1c63eb88c7bb9f6cf8772dad`. It was
   imported as a release archive with no upstream history, so no commit identity
   is recorded and none is invented.
2. **The sibling `zlib` package**, referenced by the relative path
   `.dependencies = .{ .zlib = .{ .path = "../zlib" } }`. It is a separate
   package with its own vendored tree and its own records; nothing of it is
   copied here. **That wire is `PENDING-VERIFICATION`** — the zlib tree was not
   on disk when this package was prepared, and no gate has exercised it.

The one file this build generates is `pnglibconf.h`, produced by
`tools/pnglibconf.zig` from upstream's own `src/scripts/pnglibconf.h.prebuilt`.
It is not carried material and not third-party code: it is upstream's bytes,
transformed deterministically, written into the build cache rather than into
this tree. Nothing is fetched to make it.

The three PNG fixtures under `fixtures/` are also fork-authored material,
written by `tools/make-fixtures.py` from ISO/IEC 15948 without an image library.
They are inputs to this fork's tests, not upstream content.

## 4. Why a separate file at all

[`NOTICE.md`](NOTICE.md) names which fork-authored files carry an
`SPDX-License-Identifier` line and which carry the same grant in prose without
one. This file exists so that the authority, the grant text and the limits of
that grant live in one place, next to the inventory rather than scattered
across the files themselves — and so that the point which most needs saying once,
that libpng's core is **not** MIT, cannot be lost inside a table.