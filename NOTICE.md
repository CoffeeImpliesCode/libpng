# Notice

Two separate things are recorded here: which grant covers each file of the
vendored upstream tree, and what this fork wrote on top of it.
[`FORK-LICENSE.md`](FORK-LICENSE.md) carries the grant for the second group.

**libpng is not MIT.** The compiled core is under the *PNG Reference Library
License version 2*, which is not the MIT text and does not reduce to it. Saying
"MIT" for this package would be wrong twice over: wrong about the core, and
wrong about the CI files, which are MIT and MIT-0 respectively. The inventory
below is per file, and the one-label answer is the one this table exists to
prevent.

## The upstream term: the compiled core

`src/LICENSE` is the authoritative copy, and its own heading at `src/LICENSE:4`
is the name of the term:

```
PNG Reference Library License version 2
---------------------------------------
```

`src/LICENSE:6-11` carries the copyright lines: the PNG Reference Library
Authors, Cosmin Truta, Glenn Randers-Pehrson, Andreas Dilger and others, each
with its own years. `src/LICENSE` then states the disclaimer and the conditions
of distribution and use for that grant.

`src/LICENSE:39-42` carries a **second, older** grant in the same file:

```
PNG Reference Library License version 1 (for libpng 0.5 through 1.6.35)
```

and `src/LICENSE:43-45` explains that libpng 1.0.7 (2000-07-01) through 1.6.35
(2018-07-15) are Copyright (c) 2000-2002, 2004, 2006-2018 Glenn
Randers-Pehrson, derived from libpng-1.0.6, and distributed under the same
disclaimer and license as libpng-1.0.6. Both texts are preserved because the
current release's file ships them; the version 2 grant is the one that covers
libpng 1.6.59's code, and the version 1 text is the historical grant for the
versions named in its own heading.

`src/png.h` carries the notice the generated `pnglibconf.h` points at: the
generated header's own comment (`src/scripts/pnglibconf.h.prebuilt:9-11`) reads
*"This code is released under the libpng license. For conditions of distribution
and use, see the disclaimer and license in png.h"*. So the licence text is not
only in `src/LICENSE`; the headers that the compiler sees also name it.

## Inventory of the vendored files

**614 files**, all digests in [`UPSTREAM.sha256`](UPSTREAM.sha256). Grouped by
the term that actually covers them:

| Path | Count | Term | Notice in the file |
|---|---:|---|---|
| `src/*.c`, `src/*.h` — the compiled core and its public and private headers | 16 C units plus `png.h`, `pngconf.h`, `pngdebug.h`, `pnginfo.h`, `pngpriv.h`, `pngstruct.h` | **PNG Reference Library License version 2** | `src/LICENSE:4` carries the text; the sources themselves carry copyright lines naming the same grant |
| `src/pngusr.dfa` | 1 | part of the libpng tree | **none — the file carries no copyright line and no licence header at all** (`src/pngusr.dfa:2-14` is its whole comment block: the filename, "Build time configuration of libpng", and usage prose). Covered by the grant in `src/LICENSE`; recorded here because "no notice in the file" is a fact an auditor needs, not an omission to gloss over |
| `src/LICENSE` | 1 | the grant itself | contains both the version 2 and the version 1 texts, `src/LICENSE:4` and `src/LICENSE:39-42` |
| `src/example.c` | 1 | **public domain, by upstream's own dedication** | `src/example.c:18-19`: "This is not officially part of libpng, is hereby placed in the public domain, and therefore does not require a copyright notice." Not part of the compiled core |
| `src/ci/**` | 49 | **MIT** | the mapping is `src/REUSE.toml:3-5`; the text is `src/LICENSES/MIT.txt:1` |
| `src/.github/workflows/**` | 4 | **MIT-0** | the mapping is `src/REUSE.toml:7-9`; the text is `src/LICENSES/MIT-0.txt:1` ("MIT No Attribution") |
| `src/LICENSES/MIT.txt`, `src/LICENSES/MIT-0.txt` | 2 | MIT, MIT-0 respectively | the texts themselves |
| `src/arm/*.c` | — | **libpng licence** (PNG Reference Library License version 2), by the file's own statement | `src/arm/filter_neon_intrinsics.c:3-4` the two copyright lines (Cosmin Truta; Glenn Randers-Pehrson), `:5` "Written by James Yu", `:6` "Based on filter_neon.S, written by Mans Rullgard", `:8` "This code is released under the libpng license" |
| `src/intel/*.c` | — | **libpng licence**, by the file's own statement | `src/intel/filter_sse2_intrinsics.c:3-4` the two copyright lines, `:5` "Written by Mike Klein and Matt Sarett", `:6` "Derived from arm/filter_neon_intrinsics.c", `:8` "This code is released under the libpng license" |
| `src/mips/*.c` | — | **libpng licence**, by the file's own statement | `src/mips/filter_msa_intrinsics.c:3-4` the two copyright lines (Truta 2018-2024; Randers-Pehrson 2016), `:5` "Written by Mandar Sahastrabuddhe", `:7` "This code is released under the libpng license" |
| `src/powerpc/*.c` | 2 files | **libpng licence**, by the file's own statement | `src/powerpc/filter_vsx_intrinsics.c:3-4` the two copyright lines, `:5` "Written by Vadim Barkov, 2017", `:7` "This code is released under the libpng license". The second file is `src/powerpc/powerpc_init.c` |
| `src/loongarch/*.c` | 2 files | **libpng licence**, by the file's own statement | `src/loongarch/filter_lsx_intrinsics.c:3-7`: the Loongson (with "All rights reserved."), Truta and Randers-Pehrson copyright lines and the "Contributed by Jin Bo" line; `:9` "This code is released under the libpng license". The second file is `src/loongarch/loongarch_lsx_init.c` |
| `src/riscv/*.c` | — | **libpng licence**, by the file's own statement | `src/riscv/filter_rvv_intrinsics.c:3-9`: the Google LLC copyright line, the author line and the four named "Revised by" contributors; `:11` "This code is released under the libpng license" |
| `src/CMakeLists.txt`, `src/scripts/cmake/**` | 10 files (`CMakeLists.txt` plus the 9 under `scripts/cmake/`) | **PNG Reference Library License version 2**, and upstream says so in SPDX form | these are the files that carry `SPDX-License-Identifier: libpng-2.0` — the upstream identifier for this grant. Upstream's own build files, not compiled |
| everything else under `src/` | the remainder | **PNG Reference Library License version 2** | `src/LICENSE` carries the text for the tree; the per-architecture directories are named individually above because each of them restates the grant in a contributor block |

`src/REUSE.toml:3-9` is upstream's own machine-readable mapping of the two
exception groups, and it is the authority for the `ci/**` → MIT and
`.github/workflows/**` → MIT-0 rows above. Both licence texts ship in the
tarball, at `src/LICENSES/MIT.txt` and `src/LICENSES/MIT-0.txt`, and both are
preserved verbatim.

### The compiled closure, named

The files that are actually compiled into `libpng16` are the 16 units of
`src/Makefile.am:127-129` and the headers named in the same list — all of them
under the PNG Reference Library License version 2, with no per-file exception
among them. `src/pngusr.dfa` is in that source list but is not a C unit; it is
upstream's build-configuration input, and it is the one file in the list with no
notice of its own.

**None** of the six architecture-specific directories is in this package's
build graph, for the reasons in [`README.md`](README.md) ("No SIMD is
compiled"). They are carried, digested and licence-recorded anyway: the grant
covers them, they are not deleted, and a later wave that enables one needs the
record above to be right.

## What this fork changed in upstream files

**Nothing.** No file under `src/` has been edited, reformatted, re-entered or
regenerated, and `README.upstream.md` is byte-identical to `src/README`.
`UPSTREAM.sha256` plus the exact-file-set comparison in
`tools/check-provenance.sh` are what make that checkable rather than asserted,
and any future native edit has to move those digests in the same change, with a
numbered entry in [`CHANGELOG.md`](CHANGELOG.md).

Upstream's `.gitignore` is preserved untouched at `src/.gitignore`. No upstream
ignore entry was removed, narrowed or reordered by this fork.

## Fork-specific notice

Every file below was written for this fork. **This fork adds no upstream code to
its own files**: no upstream source line, header, table or macro was copied into
any of them, so no upstream copyright notice travels in a fork-authored file and
none of the grants below is derived from an upstream permission. Every upstream
notice is preserved verbatim in the file that carries it, inside `src/`.

* `build.zig`, `build.zig.zon`, `.gitignore`, `cross-test.profile.sh`,
  `.github/workflows/verify.yml`
* `zig/root.zig`, the typed facade, and `zig/translate.h`, the aggregate
  translation header this build runs `translate-c` over
* `tests.zig`, `smoke.zig`, `consumer/build.zig`, `consumer/build.zig.zon`,
  `consumer/src/main.zig`
* `runtime/` — the load-at-runtime route: `loader.zig`, `library.zig`,
  `graph.zig`, `generate.zig`, `sync.h`, `sync.c`. All six are fork work; none
  is upstream material.
* `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml`, `.envrc`
* `tools/pnglibconf.zig`, `tools/make-fixtures.py`, `tools/check-provenance.sh`,
  `tools/check-fixtures.py`
* this file, `README.md`, `README.zig.md`, `README.upstream.md` (a byte copy of
  `src/README`, so it is *upstream* bytes under a fork-side name and is
  deliberately not counted among the fork-authored prose below),
  `UPSTREAM.md`, `UPSTREAM.sha256`, `FORK-LICENSE.md`, `CHANGELOG.md`,
  `FORK-NOTES.md`

`flake.lock` and `devenv.lock` are **absent from this tree**; both are
driver-owned. `build.zig.zon`'s `.paths` is the package's file filter, and the
rule that governs it is that every path it names must exist — naming a lock that
is not there would make the fetch hash a missing entry.

### Which of those files carry the SPDX tag

Those files read out of the tree rather than assumed: `build.zig`,
`build.zig.zon`, `zig/root.zig`, `tests.zig`, `smoke.zig`, `consumer/build.zig`,
`consumer/src/main.zig`, `tools/pnglibconf.zig`, `tools/make-fixtures.py`,
`tools/check-provenance.sh`, `package.nix`, `flake.nix`, `devenv.nix`,
`devenv.yaml` and `.envrc` carry `SPDX-License-Identifier: MIT` plus a pointer
to this fork's `FORK-LICENSE.md`.

The rest carry the same grant in prose without a tag, and are named here rather
than left for a scanner to read as unlicensed: `zig/translate.h`,
`runtime/loader.zig`, `runtime/library.zig`, `runtime/graph.zig`,
`runtime/generate.zig`, `runtime/sync.h`, `runtime/sync.c`,
`tools/check-fixtures.py`, `cross-test.profile.sh`,
`.github/workflows/verify.yml`, `.gitignore`, `consumer/build.zig.zon`, and the
documentation and digest records — this file, `README.md`, `README.zig.md`,
`UPSTREAM.md`, `UPSTREAM.sha256`, `FORK-LICENSE.md`, `CHANGELOG.md` and
`FORK-NOTES.md`.

Upstream's obligations are unaffected by any of this. A consumer who receives a
libpng 1.6.59 binary, static or shared library, or a copy of the installed
headers, still owes the PNG Reference Library License version 2 terms recorded in
`src/LICENSE`, and the installed tree carries that file. The MIT and MIT-0 terms
on `src/ci/**` and `src/.github/workflows/**` are upstream's own for those two
subtrees; they are preserved and neither is dropped nor widened by this fork.