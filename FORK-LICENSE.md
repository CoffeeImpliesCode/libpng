# FORK-LICENSE.md — the grant for this fork's own files

[`NOTICE.md`](NOTICE.md) is the per-file inventory. This grant covers fork-authored files only; it does not cover upstream material.

## Upstream files not covered

The 614 files under `src/` are unmodified files from the libpng 1.6.59 release archive. Their upstream terms remain in force; this file does not re-grant, narrow or change them.

| Upstream paths | Term and scope |
|---|---|
| The 16 compiled C units listed in `src/Makefile.am` and public/private headers (`png.h`, `pngconf.h`, `pngdebug.h`, `pnginfo.h`, `pngpriv.h`, `pngstruct.h`) | PNG Reference Library License version 2 in `src/LICENSE`. |
| Remaining upstream files under `src/`, including autotools files, manuals and architecture intrinsics | Upstream terms are recorded per path in `NOTICE.md`; each architecture intrinsic file states the PNG Reference Library License version 2. `src/pngusr.dfa` has no notice of its own. |
| `src/LICENSE` | Also preserves the historical PNG Reference Library License version 1 for libpng 0.5 through 1.6.35; version 2 covers libpng 1.6.59. |
| `src/example.c` | Upstream dedicates it to the public domain. It is not officially part of libpng and is not compiled here. |
| `src/CMakeLists.txt`, `src/scripts/cmake/**` | PNG Reference Library License version 2, stated with upstream's `SPDX-License-Identifier: libpng-2.0`. These upstream build files are not compiled here. |
| `src/REUSE.toml`, `src/LICENSES/MIT.txt`, `src/LICENSES/MIT-0.txt` | Upstream's exception mapping and license texts; `NOTICE.md` records the mapped paths and terms. |

The compiled core is not MIT. The version 2 license in `src/LICENSE` covers libpng 1.6.59; the historical version 1 text applies only to the older releases named in that file. Upstream terms vary by path, as `NOTICE.md` records.

`README.upstream.md` is the byte-for-byte copy of upstream's `src/README`, under upstream terms and not this grant.

## Fork-authored files covered

| Fork-authored paths | Included files |
|---|---|
| Build and configuration | `build.zig`, `build.zig.zon`, `.gitignore`, `.envrc`, `cross-test.profile.sh`, `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml` |
| Zig, tests and consumers | `zig/root.zig`, `zig/translate.h`, `tests.zig`, `smoke.zig`, `consumer/build.zig`, `consumer/build.zig.zon`, `consumer/src/main.zig` |
| Runtime and tools | `runtime/loader.zig`, `runtime/library.zig`, `runtime/graph.zig`, `runtime/generate.zig`, `runtime/sync.h`, `runtime/sync.c`, `tools/pnglibconf.zig`, `tools/make-fixtures.py`, `tools/check-provenance.sh`, `tools/check-fixtures.py` |
| Documentation and records | `README.md`, `README.zig.md`, `UPSTREAM.md`, `UPSTREAM.sha256`, `NOTICE.md`, `FORK-LICENSE.md`, `CHANGELOG.md`, `FORK-NOTES.md` |

These fork-authored paths carry the grant below; `NOTICE.md` records which files have an SPDX tag. `README.upstream.md` is excluded: it is upstream material under its upstream term.

No upstream source was copied into a fork-authored file. This grant does not assert that the PNG Reference Library Authors, Cosmin Truta, Glenn Randers-Pehrson, Andreas Dilger or any other upstream contributor wrote, reviewed or endorsed fork-authored work. No upstream permission is claimed for these additions.

The owner authorized per-project licensing for fork-authored additions. This is the owner's grant, not an upstream grant; it applies to no upstream file. The copyright line is collective and asserts no individual copyright holder.

### Grant

Those fork-authored files are released under the MIT License:

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

### SPDX identifier

```
MIT
```

`MIT` is the registered SPDX identifier for fork-authored files only. Upstream's `libpng-2.0` is a LicenseRef-shaped identifier for the PNG Reference Library License version 2, not a grant in this file. `NOTICE.md` preserves the per-file distinction.

## Upstream obligations

Nothing here changes upstream's terms. A consumer redistributing libpng 1.6.59 source, binaries or installed headers must meet the PNG Reference Library License version 2 terms in `src/LICENSE`; `NOTICE.md` records terms for the other upstream paths.