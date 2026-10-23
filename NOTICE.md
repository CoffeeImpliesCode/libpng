# Notice

## Upstream files

The upstream copyright holders named in `src/LICENSE` include the PNG Reference Library Authors, Cosmin Truta, Glenn Randers-Pehrson, Andreas Dilger, and others. `src/LICENSE` carries PNG Reference Library License version 2 for libpng 1.6.59 and the historical version 1 text for libpng 0.5 through 1.6.35.

| Paths | Term and attribution |
|---|---|
| `src/**`, except paths listed below | PNG Reference Library License version 2, from `src/LICENSE`. This includes the compiled core, architecture sources, and other upstream files. |
| `src/arm/*.c`, `src/intel/*.c`, `src/mips/*.c`, `src/powerpc/*.c`, `src/loongarch/*.c`, `src/riscv/*.c` | PNG Reference Library License version 2; each group states the libpng license. |
| `src/CMakeLists.txt`, `src/scripts/cmake/**` | PNG Reference Library License version 2, identified upstream as `libpng-2.0`. |
| `src/pngusr.dfa` | Covered by `src/LICENSE`; the file has no copyright or license notice. |
| `src/ci/**` | MIT; path mapping in `src/REUSE.toml`, text in `src/LICENSES/MIT.txt`. |
| `src/.github/**` | MIT-0; path mapping in `src/REUSE.toml`, text in `src/LICENSES/MIT-0.txt`. |
| `src/example.c` | Public domain by upstream dedication; not part of the compiled core. |
| `src/LICENSE`, `src/LICENSES/MIT.txt`, `src/LICENSES/MIT-0.txt` | License texts: PNG Reference Library Licenses v2 and v1, MIT, and MIT-0, respectively. |

`README.upstream.md` is a copy of upstream's `src/README`; it is upstream material, not covered by the fork grant.

## Fork-authored files

`FORK-LICENSE.md` grants MIT terms for these fork-authored files only. No upstream source was copied into them, and no upstream contributor is claimed as author, reviewer, or endorser.

| Group | Paths |
|---|---|
| Build and configuration | `build.zig`, `build.zig.zon`, `.gitignore`, `.envrc`, `cross-test.profile.sh`, `package.nix`, `flake.nix`, `devenv.nix`, `devenv.yaml` |
| Zig, tests, and consumers | `zig/root.zig`, `zig/translate.h`, `tests.zig`, `smoke.zig`, `consumer/build.zig`, `consumer/build.zig.zon`, `consumer/src/main.zig` |
| Runtime and tools | `runtime/loader.zig`, `runtime/library.zig`, `runtime/graph.zig`, `runtime/generate.zig`, `runtime/sync.h`, `runtime/sync.c`, `tools/pnglibconf.zig`, `tools/make-fixtures.py`, `tools/check-provenance.sh`, `tools/check-fixtures.py` |
| Documentation and records | `README.md`, `README.zig.md`, `UPSTREAM.md`, `UPSTREAM.sha256`, `NOTICE.md`, `FORK-LICENSE.md`, `CHANGELOG.md`, `FORK-NOTES.md` |

`README.upstream.md` is excluded from the fork grant because it contains upstream bytes.
