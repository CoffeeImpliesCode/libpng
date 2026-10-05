# Changelog

Numbered changes to this repository. Every entry is `PENDING-VERIFICATION`
unless an observed gate run says otherwise. Three gates have now been run here,
on 2026-10-05 — `zig build` (exit 0), `zig build check` (exit 1) and the
53-platform `cross-test` matrix (exit 1; 18 of 53 cells executed 9/9 tests) —
and only the `cross-test` run has executed a test binary.

Version pinning lives in one place, [`UPSTREAM.md`](UPSTREAM.md), and every
entry that changes the vendored source has to move it in the same change.

## 1. Initial import: libpng 1.6.59 as a Zig package

**Status: `PENDING-VERIFICATION`. No gate has been run for this package.**

* **Upstream pin.** libpng 1.6.59, released 2026-09-28, tarball
  `libpng-1.6.59.tar.gz`, 1589315 bytes, sha256
  `86a3e4b501f7f50e392c4e456ea158893e9a595b1c63eb88c7bb9f6cf8772dad`, served
  from
  <https://downloads.sourceforge.net/project/libpng/libpng16/1.6.59/libpng-1.6.59.tar.gz>.
  `SOURCE-CONFIRMED` as a record of bytes: the pin is the digest the import was
  made against, and `src/` was compared byte-for-byte with the extracted
  tarball (`diff -rq`, no difference). Re-checkable with
  `sha256sum -c UPSTREAM.sha256`.
* **Import mechanism.** A release **archive**: no upstream Git history in this
  import, therefore no commit SHA, no patch series and no invented revision.
  Re-syncing means re-downloading, verifying the published digest, replacing the
  files and moving the digests in one change.
* **Vendored scope.** All **614 files** of the release tarball, recorded by
  digest in [`UPSTREAM.sha256`](UPSTREAM.sha256) and checked against
  `find src -type f` by `tools/check-provenance.sh`. Nothing dropped for size,
  nothing dropped for being uncompiled. Nothing under `src/` was modified: no
  patch, no reformat, no portability edit.
* **Build graph.** `build.zig` compiles the 16 C units upstream names at
  `src/Makefile.am:127-129`, with no CMake, no autotools and no build-time
  download. C artifact `png16`, emitting `libpng16.a` or
  `libpng16.so.16.59.0` with soname `libpng16.so.16` (`src/Makefile.am:125`,
  `src/Makefile.am:178-180`, `src/png.h:281`). Zig module `libpng`. Public
  headers `png.h`, `pngconf.h` and the generated `pnglibconf.h`
  (`src/Makefile.am:206`, `:207`), installed into `include/libpng16/`.
* **Generated input.** `pnglibconf.h`, produced deterministically by
  `tools/pnglibconf.zig` from upstream's own `src/scripts/pnglibconf.h.prebuilt`
  — the same path upstream's own CMake takes when no AWK is available
  (`src/CMakeLists.txt:458-462`). The generated directory precedes `src/` on
  every include line; nothing is generated into `src/`. Consequence recorded
  precisely: `PNG_ZLIB_VERNUM 0`
  (`src/scripts/pnglibconf.h.prebuilt:226`) disables **only** the compile-time
  include-path consistency check at `src/pngpriv.h:1026-1028`, which is the one
  and only place that macro is read in the tree. No runtime behaviour and no ABI
  is affected.
* **Sibling dependency.** One, and it is not optional: libpng is a zlib binding.
  `.dependencies = .{ .zlib = .{ .path = "../zlib" } }`, linked with
  `dep.artifact("zlib")`. **`PENDING-VERIFICATION`**: the zlib tree was not on
  disk when this package was prepared, so no gate has exercised the wire. The
  agreed surface is recorded in [`UPSTREAM.md`](UPSTREAM.md) — package dir
  `zlib/`, `.name = .zlib`, `.version = "1.3.2"`, module `dep.module("zlib")`,
  artifact `dep.artifact("zlib")` emitting `libz.a`/`libz.so`, headers
  `zlib.h` + `zconf.h`, no mandatory macros for a POSIX dependent. **No zlib
  digest, commit or URL is recorded, because none was observed.**
* **SIMD: deliberately off.** Every `PNG_*_OPT` macro is undefined and no file
  under `src/arm/`, `src/intel/`, `src/mips/`, `src/powerpc/`,
  `src/loongarch/` or `src/riscv/` is in the build graph. This is a
  configuration, not an omission; the cost of enabling each family is written out
  in [`README.md`](README.md).
* **Typed surface and routes.** `zig/root.zig` publishes the typed facade with
  the raw translated C reachable as `c`; `-Druntime=true` selects the
  load-at-runtime route with explicit selection, one process-lifetime table, no
  fallback, atomic publication, explicit retry and an ordinary pre-initialization
  panic in every optimize mode. The linked route stays direct.
* **Fixtures.** Three PNG files under `fixtures/`, written by
  `tools/make-fixtures.py` with **no image library**: the container is assembled
  by hand from ISO/IEC 15948 and the only borrowed facility is
  `zlib.compress`, because `IDAT` is defined as a zlib stream. They are
  independent known answers for the behavioural tests, not round trips. Digests
  and expected pixels are in [`UPSTREAM.md`](UPSTREAM.md);
  `tools/check-fixtures.py` compares the digests.
* **Documentation and provenance.** `README.md`,
  [`README.zig.md`](README.zig.md), [`UPSTREAM.md`](UPSTREAM.md),
  [`NOTICE.md`](NOTICE.md), [`FORK-LICENSE.md`](FORK-LICENSE.md),
  [`FORK-NOTES.md`](FORK-NOTES.md), `UPSTREAM.sha256`,
  `tools/check-provenance.sh` and `tools/check-fixtures.py`.
  `README.upstream.md` is a byte-for-byte copy of `src/README`, compared with
  `cmp` at the time it was written; the comparison printed no difference.
* **Licence.** Recorded **per file, not as one label**: the compiled core is
  under the **PNG Reference Library License version 2** (`src/LICENSE:4`), *not*
  MIT; `src/LICENSE:39-42` also carries the version 1 text for libpng 0.5
  through 1.6.35; `src/ci/**` is MIT (`src/REUSE.toml:3-5`,
  `src/LICENSES/MIT.txt:1`); `src/.github/workflows/**` is MIT-0
  (`src/REUSE.toml:7-9`, `src/LICENSES/MIT-0.txt:1`); `src/example.c:18-19` is
  dedicated to the public domain by upstream; and `src/pngusr.dfa` carries no
  copyright or licence header at all (`src/pngusr.dfa:2-14`). Fork-authored
  additions are MIT by owner authorization, recorded in
  [`FORK-LICENSE.md`](FORK-LICENSE.md), and **no upstream source was copied into
  any fork-authored file**.
* **Upstream test suites are preserved.** `src/tests/` and `src/contrib/`, with
  upstream's PNG corpus, ship untouched inside the vendored tree and are recorded
  as **carried-but-not-run**. They are never deleted, and this package's fixtures
  never replace them.
* **Manifest fingerprint.** `.fingerprint` is **deliberately absent** from
  `build.zig.zon`. Deriving one requires running the compiler, and no gate has
  run here, so any value written now would be an invented identifier. The first
  observed `zig build` reports the toolchain-derived value; the driver records it
  and adds it in the same change. Nothing in this package's source, build graph
  or tests reads it.
* **`wasm32-wasi` was an unknown in this import, and the unknown has since been
  resolved — against the target.** Nothing in the import established whether
  libpng's C closure compiles for it, so it stayed in the six-target compile
  matrix with a cell that claimed only what had been observed. On 2026-10-05 the
  first `zig build check` observed it: the row fails inside the pinned
  toolchain's wasi-libc, `libc/include/wasm-wasi-musl/setjmp.h:13`, reached from
  `src/pngconf.h:50`. It is **not** refused and it is **not** a pass. This
  bullet is kept as the record it was and is superseded by entry 2, which
  carries the diagnosis.
* **`.github/workflows/verify.yml`** defines four jobs — provenance, native
  build+tests+smoke+installed C surface in both linkages, the six-target cross
  compile matrix, and the consumer package in both linkages — with no
  `continue-on-error`, no tolerated matrix row, and no upstream CI copied or
  retargeted. **No run of that workflow has produced a receipt for this
  package**, so its existence is not evidence about anything.
* **`UPSTREAM.sha256`, `tools/pnglibconf.zig` and `tools/make-fixtures.py`** land
  as part of this same import; see `UPSTREAM.md` and `README.md` for what each
  does.

### What this entry does not say

It does not say the package builds, links, decodes a PNG or passes anything. It
records what was imported, what was decided, and what still has to be run. The
commands the driver owes a receipt for are listed in [`README.md`](README.md)
and every one of them is `PENDING-VERIFICATION`.

## 2. One `-D` on the translation, and one platform boundary recorded

`zig build check` walks six targets. On 2026-10-05 two rows were red inside a
`setjmp.h`. One was fixable in this package and is; the other is not and is now
written down where a reader will meet it.

### Fixed — `riscv64-linux-gnu`

libpng's own 15 units compiled for that target and the facade's `translate-c`
step did not, with
`libc/include/riscv-linux-gnu/bits/setjmp.h:35:3: error: unsupported FLEN` on
the way in from `src/pngconf.h:50`. glibc lays out a RISC-V `jmp_buf` only for
`__riscv_float_abi_double` and `__riscv_float_abi_soft`; clang predefines the
first for `riscv64-linux-gnu` and Aro, which runs `translate-c`, predefines none
of the three. `build.zig` now derives the macro clang would use from the target
being built and hands it to `translate.defineCMacro`, so the facade is
translated against the ABI the library was compiled with. It goes on the
translation only, and only on RISC-V. Observed: `zig build check
-Dtarget=riscv64-linux-gnu` went from exit 1 to exit 0.

### Recorded — `wasm32-wasi`

Both halves of the row fail with the pinned toolchain's own message,
`libc/include/wasm-wasi-musl/setjmp.h:13: error: Setjmp/longjmp support
requires Exception handling support`, which that header raises unless
`__wasm_exception_handling__` is defined. libpng does have the upstream switch,
`PNG_SETJMP_SUPPORTED`, but it is not reachable from a compile line here:
`tools/pnglibconf.zig` generates `pnglibconf.h` from
`src/scripts/pnglibconf.h.prebuilt`, whose line 113 defines the macro
unconditionally, and the generator must reproduce that vendored header byte for
byte. So the row stays in `check_targets`, `refused_check_targets` stays empty,
and `zig build check` exits 1: a failing cell that stays visible, not a dropped
one and not a pass. The two things that would have to change — the toolchain's
wasi-libc, or a documented upstream deviation in the prebuilt header with its
integrity records — are in [`FORK-NOTES.md`](FORK-NOTES.md) §5. No vendored
header was edited and no replacement `setjmp.h` was vendored.

## 3. The 53-platform `cross-test` matrix, run and classified

`cross-test` over the published 53-platform Zig 0.16 Tier 1/2 matrix was run in
this tree on 2026-10-05 with the pinned Zig 0.16.0, from the library root,
`--jobs 8 --build-jobs 8`, using this tree's own `cross-test.profile.sh`
unchanged. **The harness exited 1 over 53 targets** and reported
`pass=18 fail=17 build_only=0 partial=18`. Classified per cell, and recorded
verbatim in [`FORK-NOTES.md`](FORK-NOTES.md) §11 with the full table at
`/home/tmp2/gertullj/libpng-cross-test-53-cell-summary.md`:

* **18 pass** — build exit 0 and `run test libpng-tests 9 pass (9 total)`,
  `Build Summary: 12/12 steps succeeded; 9/9 tests passed`. Every one is a real
  executed run, native or under `qemu-user`: `x86_64-linux`, `aarch64-linux`,
  `aarch64_be-linux`, `arm-linux`, `armeb-linux`, `hexagon-linux`,
  `loongarch64-linux`, `mips-linux`, `mipsel-linux`, `mips64-linux`,
  `mips64el-linux`, `powerpc-linux`, `riscv32-linux`, `riscv64-linux`,
  `s390x-linux`, `thumb-linux`, `thumbeb-linux`, `x86-linux`.
* **18 build-only** — build exit 0, `run test libpng-tests skipped`, nothing
  executed, no test count. Per `AGENTS.md` these are build-only coverage and
  never a pass. macOS, maccatalyst, FreeBSD, OpenBSD and Windows rows have no
  runner on this host (`cross-test --list` reports `no_local_runner_*`,
  `unsupported_windows_arch`, `missing_wine`, `missing_wine64`).
* **0 refused.** `build.zig`'s `refusalFor` refuses nothing and
  `refused_check_targets` stays empty, so no cell was taken out of the matrix.
* **2 runtime failures** — `powerpc64-linux` and `powerpc64le-linux`. Both
  compile, then all 9 tests crash on a misaligned `png_struct`. Diagnosed from
  the pinned toolchain's own sources: `src/pngstruct.h:125` puts a `jmp_buf`
  first in `struct png_struct_def`; ppc64-musl's `jmp_buf` is
  `unsigned __int128[32]` and so 16-byte aligned; ppc64-musl's `max_align_t` is
  8-byte aligned because `long double` is 64-bit there
  (`lib/std/Target.zig:3105-3119`); `lib/c/malloc.zig:20-21` sizes `malloc` from
  `max_align_t`. Measured: `_Alignof(jmp_buf)=16`, `_Alignof(max_align_t)=8`,
  and `malloc mod 16 == 8` under `qemu-ppc64`/`qemu-ppc64le`. libc therefore
  returns 8-aligned memory for a type whose ABI alignment is 16, which is a live
  memory-model defect on ppc64 and not only a Zig safety check.
* **15 build failures** — 14 netbsd/openbsd rows and `wasm32-wasi`. All are the
  pinned toolchain's own headers refusing, reproduced with a probe header that
  includes only `<stddef.h>`, `<sys/types.h>` and `<stdio.h>` and no libpng
  header at all: netbsd `stdio.h:151` `_Pragma("GCC visibility pop")` through
  `sys/cdefs.h:432`/`:413`; `mips-netbsd-eabi/machine/endian_machdep.h:8` and
  `generic-openbsd/mips64/endian.h:40` needing `__MIPSEB__`/`__MIPSEL__`; and
  Aro's `stddef.h:8` `typedef __SIZE_TYPE__ size_t` colliding with
  `generic-openbsd/sys/types.h:173`. `wasm32-wasi` is entry 2's boundary again,
  now observed on the `test` step.

No vendored file was touched to get here: `src/` is byte-identical to the
release tarball. Nothing was weakened, skipped, or relabelled to look green.

> **Superseded in part by entry 4.** The claim that the fix for *every* red cell
> lies in the toolchain or in an upstream deviation was true for the 15 build
> failures and **false for the 2 runtime failures**. Those two ppc64 rows had a
> caller-side remedy inside this package and now pass 9/9.

## 4. The ppc64 misalignment is fixed in fork code, and it was never a boundary

**Status: `SOURCE-CONFIRMED` by observed run.** The 53-platform matrix was re-run
after the fix and reports **`pass=20 fail=15 build_only=0 partial=18`** (run id
`20261005-205643-73372-27975`, harness exit 1, `bookkeeping_failure: false`),
against entry 3's `pass=18 fail=17 build_only=0 partial=18`. The two cells that
moved are `powerpc64-linux` and `powerpc64le-linux`, both now `status: pass`,
`build.exit 0`, `run.exit 0`, `tests 9`, `reason: tests_complete`, with harness
logs reading `Build Summary: 12/12 steps succeeded; 9/9 tests passed`. The 15
build failures and the 18 build-only cells are unchanged, for the same reasons
as before. Per-cell tables, receipts and the source-stability gate the run was
made under are in [`FORK-NOTES.md`](FORK-NOTES.md) §11 and §12.

Entry 3 recorded these two rows as runtime failures and §11 recorded them as a
boundary this package could not close. **Both records were wrong**, and the
error was the same one in each: assuming the only remedies lived inside `src/`.

* **What the fix is.** `PNG_USER_MEM_SUPPORTED` is defined
  (`src/scripts/pnglibconf.h.prebuilt:131`), so libpng publishes the seam itself:
  `png_create_read_struct_2` and `png_create_write_struct_2`
  (`src/png.h:997-1006`) take a caller-supplied `malloc_fn`/`free_fn`, and
  `src/png.c:298-300` installs them through `png_set_mem_fn` **before**
  `src/png.c:331-332` allocates the `png_struct`. Allocation consults that hook
  ahead of the system `malloc` (`src/pngmem.c:88-99`) and release routes back
  through it (`src/pngmem.c:234-244`, including the `png_struct` itself at
  `src/pngmem.c:24-37`), so one caller-supplied allocator governs every block
  libpng takes — starting with the one that panicked.
* **Where it lives.** Fork-authored code only. `zig/root.zig:508-517` (the
  alignment and why it is 16), `:521-523` (the header), `:535-549`
  (`libpngMallocThunk`), `:557-564` (`libpngFreeThunk`), installed at
  `:600-607` for `Reader.open` and `:814-821` for `Writer.open`. Each block is
  over-allocated by one whole alignment step plus the header, so a 16-byte
  aligned address always exists inside it and `free` recovers the original
  pointer from the header rather than guessing.
* **Why 16, measured.** `src/pngstruct.h:125` puts `jmp_buf jmp_buf_local`
  first in `struct png_struct_def`, so `png_struct` inherits `jmp_buf`'s
  alignment. musl's `arch/powerpc64/bits/setjmp.h` is
  `typedef unsigned __int128 __jmp_buf[32]`, and `__int128` is 16-byte aligned
  on ppc64; `lib/c/malloc.zig:20-21` sizes `malloc` from `max_align_t`, which
  `arch/powerpc64/bits/alltypes.h` puts at 8. Measured with a standalone
  `zig cc` probe under `qemu-ppc64`/`qemu-ppc64le`/`aarch64`: `_Alignof(jmp_buf)`
  is 16 on both ppc64 rows and 8 on `aarch64-linux-musl`;
  `_Alignof(max_align_t)` is 8 on the ppc64 rows and 16 on aarch64.
* **Verified, not asserted.** Before the fix, a probe linked against this tree's
  own `libpng16.a` aborted at `src/pngread.c:52` under `qemu-ppc64` with the
  default allocator and printed `align16=1` with the supplied one. After it, a
  stress probe ran 20 000 rounds over ten sizes straddling the header and
  alignment boundary, then 5 000 full read and write struct lifecycles, on both
  ppc64 rows: `alloc=220000 free=220000 live=0`, every pointer 16-byte aligned,
  exit 0. The allocator balances and leaks nothing.
* **What did not change.** No test was weakened, no cell dropped or relabelled,
  no `|| true` added. The same nine tests now execute on both rows. `src/` is
  byte-identical to the release tarball and `tools/check-provenance.sh` passes.
  The upstream gap itself is untouched and still real: upstream musl's own
  allocator hands out 16 bytes regardless (`#define ALIGN 16` in
  `src/malloc/lite_malloc.c`), Zig's does not, and that stays where it is — in
  the toolchain.
* **Also corrected.** Entry 3's closing claim, that the fix for every red cell
  lies in the toolchain or in an upstream deviation, was true for the other 15
  build failures and was false for these two runtime failures.