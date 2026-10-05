# Fork notes

Working notes for this package. Each entry is in the shape the horizon learning
mandate requires — **condition / symptom / fix / targets bound** — so a later
wave in another directory, library or toolchain version can apply it without
re-deriving it. An entry without a named boundary is not promotable.

**Three gates have been run for this package, on 2026-10-05:** `zig build`
(exit 0), `zig build check` (exit 1, five of six targets compiling and
`wasm32-wasi` failing) and `cross-test` over the published 53-platform matrix
(exit 1; 18 cells executed 9/9 tests and passed, 18 compiled without executing,
2 crashed at runtime, 15 did not compile — section 11). Everything else here is
`SOURCE-CONFIRMED` (read out of a file), `CONSTRAINT` (a binding rule with no
observation), or `PENDING-VERIFICATION` (landed, unobserved). No entry below may
be read as a receipt for a gate that did not run, and a compiling cell is not a
passing test; the driver owns the rest of the gates and [`README.md`](README.md)
lists the commands one is owed.

## 1. `pnglibconf.h` is generated from upstream's own prebuilt file, and the one thing that costs is a compile-time check

* **Condition.** libpng's configuration header is produced by upstream's build
  system from `src/scripts/pnglibconf.dfa` via AWK (`src/CMakeLists.txt:465-478`),
  and the release tarball also ships `scripts/pnglibconf.h.prebuilt` as a
  ready-made configuration for builds that cannot run AWK.
* **Symptom (reasoned, unexecuted).** This package has no AWK dependency and no
  intent to take one, so it must choose between generating the configuration from
  `.dfa` — which needs an AWK-shaped program and would make the configuration a
  second source of truth derived by this fork — or using the prebuilt header
  upstream itself ships.
* **Fix.** `tools/pnglibconf.zig` reads
  `src/scripts/pnglibconf.h.prebuilt` and emits `pnglibconf.h` into the build
  cache; the generated directory is placed **before** `src/` on every include
  line, and nothing is generated into `src/`. This is upstream's own documented
  fallback, not an invention: `src/CMakeLists.txt:458-462` is the
  `elseif(NOT AWK)` branch, whose own comment reads *"No AWK program available to
  generate pnglibconf.h. Configure libpng with pnglibconf.h.prebuilt."*
* **Consequence, named exactly.** `src/scripts/pnglibconf.h.prebuilt:226`
  defines `PNG_ZLIB_VERNUM 0 /* unknown */`. The one and only place that macro is
  read in the whole vendored tree is `src/pngpriv.h:1026`, where it guards the
  include-path consistency check:

  ```c
  #if PNG_ZLIB_VERNUM != 0 && PNG_ZLIB_VERNUM != ZLIB_VERNUM
  #  error The include path of <zlib.h> is incorrect
  ```

  With `0` the check does not fire. So the package loses upstream's ability to
  *detect at compile time* that it is looking at a different `zlib.h` than the
  configuration was generated from. Nothing else changes: no runtime behaviour,
  no ABI, no public header.
* **What replaces the lost check.** The declared dependency on the sibling zlib
  package, resolved by link time rather than by macro comparison. That is a
  *weaker* guarantee, and it is stated as one rather than claimed as equivalent:
  a mismatched zlib on the include line would be caught by a link error or a
  behavioural failure, not by a `#error` at configure time.
* **Targets bound.** Bounded to this package and to libpng 1.6.59's
  `scripts/pnglibconf.h.prebuilt`. Any other libpng version may ship a different
  prebuilt configuration, and the `PNG_ZLIB_VERNUM 0` consequence is specific to
  this file's line 226. A build that has a real AWK available would take the
  `.dfa` branch instead and would *not* have `PNG_ZLIB_VERNUM 0`.

## 2. The zlib wire is declared but unexercised

* **Condition.** libpng is a zlib binding. `src/pngpriv.h` and `src/png.c`
  include `<zlib.h>` and call `inflateInit2_`, `deflateInit2_` and siblings, so
  the 16 C units do not compile without a zlib on the include line and the
  archive does not link without one to resolve those names. There is no
  optional-zlib configuration in this build: it is not a feature to be toggled.
* **Symptom.** The sibling `zlib/` tree was **not on disk when this package was
  prepared**. So the wire `.dependencies = .{ .zlib = .{ .path = "../zlib" } }` +
  `c_mod.linkLibrary(zlib_dep.artifact("zlib"))` has never been exercised, and
  every downstream statement in this repository about zlib's headers being on the
  include line is a reading of the build-graph mechanism, not an observation.
* **Fix.** The dependency is declared in `build.zig.zon` and linked in
  `build.zig`. The link call is the whole of the include-path story:
  `lib/std/Build/Module.zig:649-659` appends `.{ .other_step = other }` to
  `include_dirs`, and `IncludeDir.appendZigProcessFlags` (`lib/std/Build/Module.zig:183-184`)
  renders that as `-I <the linked artifact's installed-header include tree>`. No
  separate include path is written anywhere else, because a second one could
  disagree with the first.
* **Agreed surface, recorded so a later wave can check rather than infer:**
  package directory `zlib/`; `.name = .zlib`; `.version = "1.3.2"`; module
  `dep.module("zlib")`; C artifact `dep.artifact("zlib")` emitting `libz.a` and
  `libz.so`; public headers `zlib.h` and `zconf.h`; **no mandatory compile
  macros** for a dependent on POSIX.
* **Not recorded, deliberately.** No zlib digest, commit, tag or URL appears
  anywhere in this package, because none was observed. Do not let a later wave
  fill that in from memory — it is zlib's package's record to make, not this
  one's.
* **Targets bound.** Bounded to the current sibling arrangement
  (`../zlib`). If the sibling is fetched rather than path-referenced, or is
  renamed, or changes its artifact name, the wire changes with it. **This entry
  is `PENDING-VERIFICATION` and cannot be promoted until a gate has built this
  package with that dependency present.**

## 3. No SIMD is compiled, on purpose, and here is what each family would cost

* **Condition.** libpng 1.6.59 ships six architecture-specific filter
  implementations, and `src/Makefile.am:127-129` — the source list this package
  compiles — names exactly the 16 portable C units and none of them.
* **Symptom (the thing a reader would otherwise mistake for a bug).** A reader
  comparing this package against upstream's build output may find the filtered
  images slower and conclude something is missing. Nothing is missing. Every
  `PNG_*_OPT` macro is undefined and no file under `src/arm/`, `src/intel/`,
  `src/mips/`, `src/powerpc/`, `src/loongarch/` or `src/riscv/` is in the build
  graph.
* **Fix.** This is a deliberate configuration, stated here and in
  [`README.md`](README.md), not an omission. What enabling each family would
  cost:
  * **Intel SSE** — the cost is upstream's own conditional source list:
    `src/Makefile.am:150-152` adds `intel/intel_init.c` and
    `intel/filter_sse2_intrinsics.c` under `if PNG_INTEL_SSE`, so enabling SSE
    means defining `PNG_INTEL_SSE_SUPPORTED` in the generated `pnglibconf.h`
    and compiling those two files. Both are C with intrinsics. They cannot be
    added to a portable closure without a target-conditional branch in the
    build graph, because the option is architecture-specific and the C compiler
    must be one that has the intrinsics.
  * **ARM NEON** — the same shape. The gate macro is
    `PNG_ARM_NEON_API_SUPPORTED`, which the prebuilt configuration leaves
    `/*#undef ...*/` at `src/scripts/pnglibconf.h.prebuilt:20`; enabling it
    compiles `src/arm/arm_init.c` and `src/arm/filter_neon_intrinsics.c`
    (plus `src/arm/palette_neon_intrinsics.c` where palettes are transformed).
  * **MIPS MSA**, **PowerPC VSX**, **LoongArch LSX**, **RISC-V RVV** — the same
    per-family pattern: one `*_init.c` registration function beside the filter
    implementation in each of the six directories, and one option macro per
    family. `src/pngusr.dfa`, which is a *source* file in
    `src/Makefile.am:127-129`, is upstream's per-installation override file for
    the security limits (`PNG_USER_WIDTH_MAX`, `PNG_USER_HEIGHT_MAX`,
    `PNG_USER_CHUNK_CACHE_MAX`, `PNG_USER_CHUNK_MALLOC_MAX`) that are fed into
    `pnglibconf.h` generation; it is **not** the file that selects SIMD, and it
    is not how the SSE dispatch is configured. Saying otherwise would be a
    misreading of the tree.
  * **Assembly.** In 1.6.59 there is exactly **one** `.S` file in the whole
    vendored tree, `src/arm/filter_neon.S` — and it is not a filter
    implementation: `src/arm/filter_neon.S:1-12` calls itself a *placeholder
    file*, and its own note explains that the hand-coded assembler
    implementation has been replaced. So the SIMD families in this release are
    C-with-intrinsics across the board, and there is no NASM, MASM or other
    assembler source to work around. If a future libpng release reintroduces
    assembler filters, Zig 0.16.0 has no NASM and its bundled clang does not
    accept NASM syntax, and that would be a toolchain problem rather than a
    build-graph problem. It is not a problem this release has.
* **Targets bound.** Bounded to this package's configuration, and to libpng
  1.6.59's directory names and option macros. A future wave that enables any
  family must bound the change to the targets where the family exists: NEON to
  AArch32/AArch64, MSA to MIPS, VSX to PowerPC, LSX to LoongArch, RVV to RISC-V,
  SSE to x86/x86-64 — and must not make the portable closure conditional on the
  build host. Enabling a family for the host and shipping the result for a
  foreign target is exactly the mistake `AGENTS.md` §5 forbids.

## 4. `.fingerprint` is deliberately absent, and deriving one needs a compiler

* **Condition.** `build.zig.zon` may carry a `.fingerprint` field.
* **Symptom.** Leaving it absent means a `zig fetch` of this package has no
  fingerprint to compare against, which looks like an omission in the manifest.
  Writing one to silence that would be worse.
* **Fix.** Deriving a fingerprint requires running the Zig toolchain, and **no
  gate has been run for this package**, so any value written now would be an
  invented identifier (`AGENTS.md` rule 3). It is left absent on purpose. The
  first observed `zig build` reports the value the toolchain computes for
  `.libpng`; the driver records that printed value in this file and adds the
  field in the same change. Nothing in this package's source, build graph or
  tests reads it, so its absence cannot affect any build result.
* **Targets bound.** Bounded to `build.zig.zon` of this package. The same rule
  applies to any other package in this workspace prepared without a gate run; the
  value is toolchain-derived and must never be written by hand.

## 5. The two cross-target cells that were red, one fixed and one bound

`zig build check` walks six targets. On 2026-10-05 two of them were red and both
were red inside a `setjmp.h` — for `wasm32-wasi` this package's own, and for
`riscv64-linux-gnu` the same one reached through the translator's smaller
predefine set. Section 5 used to record `wasm32-wasi` as an *unknown*; it is now
an observation, and `riscv64-linux-gnu` joins it. They are recorded separately
because their answers differ.

### `wasm32-wasi` — a platform boundary, and this package cannot move it

* **Condition.** The `wasm32-wasi` row of `zig build check`, alongside
  `x86_64-linux-gnu`, `aarch64-linux-gnu`, `aarch64-macos-none`,
  `x86_64-windows-gnu` and `riscv64-linux-gnu`.
* **Symptom, observed 2026-10-05.** Both halves of the row fail with the pinned
  toolchain's own message:

  ```text
  /home/tmp2/gertullj/zig-global-cache/p/N-V-__8AAFFSVRWqblwBIcA-Yqv-u7sbjsJoww8K0mWaHbmJ/lib/libc/include/wasm-wasi-musl/setjmp.h:13:2: error: Setjmp/longjmp support requires Exception handling support, which is [not yet standardized](https://github.com/WebAssembly/proposals?tab=readme-ov-file#phase-3---implementation-phase-cg--wg). To enable it, compile with `-mllvm -wasm-enable-sjlj` and use an engine that implements the Exception handling proposal.
  #error Setjmp/longjmp support requires Exception handling support, which is [not yet standardized](https://github.com/WebAssembly/proposals?tab=readme-ov-file#phase-3---implementation-phase-cg--wg). To enable it, compile with `-mllvm -wasm-enable-sjlj` and use an engine that implements the Exception handling proposal.
  ```

  `compile lib png16-libpng-wasm32-wasi... 15 errors` and `translate-c 2
  errors`, and the compiler's own include trace names the path:
  `src/pngmem.c:19` → `src/pngpriv.h:427` → `src/png.h:333` →
  `src/pngconf.h:50` → `<setjmp.h>`. `Build Summary: 52/57 steps succeeded
  (2 failed)`, and `zig build check` exits 1. Nothing else in the row fails: the
  sibling zlib's library and its per-target `zconf.h` generator both built for
  `wasm32-wasi`, so the zlib pressure point this entry used to list as unmeasured
  is measured now and is clean.
* **Cause, read out of the pinned toolchain.**
  `libc/include/wasm-wasi-musl/setjmp.h:10-15` opens `/* WASI has no setjmp */`
  and raises that `#error` unless `__wasm_exception_handling__` is defined, so
  the refusal is in wasi-libc's own header and not in a setting this package
  controls.
* **Why upstream's own switch does not reach it.** libpng does have the knob:
  `src/pngconf.h:48-50` includes `<setjmp.h>` only `#ifdef
  PNG_SETJMP_SUPPORTED`. But `PNG_SETJMP_SUPPORTED` is not a command-line
  option here — `tools/pnglibconf.zig` generates `pnglibconf.h` from
  `src/scripts/pnglibconf.h.prebuilt`, whose line 113 is an unconditional
  `#define PNG_SETJMP_SUPPORTED`, and that generator is required to reproduce
  the vendored prebuilt header byte for byte. A `-DPNG_SETJMP_SUPPORTED=0` on
  the compile line would be redefined by the header on the next line and would
  change nothing. Turning the option off therefore needs a source deviation in
  the vendored prebuilt file, which this package does not take.
* **Fix.** None here, and none in this repository. The two real moves are both
  outside it: the pinned toolchain's wasi-libc gaining the exception-handling
  proposal, or a documented upstream deviation in
  `src/scripts/pnglibconf.h.prebuilt` with the matching integrity records.
  Vendoring a replacement `setjmp.h` or editing a vendored header would break
  upstream integrity, so neither was done.
* **Status of the cell.** Not a pass and not a refusal. `wasm32-wasi` stays in
  `check_targets` and `refused_check_targets` stays empty, so the row keeps
  failing loudly rather than disappearing from the matrix. `refusalFor`
  refuses nothing today, and the comment above it that says so is still true.
* **Targets bound.** `wasm32-wasi` on Zig 0.16.0's wasi-libc, for any build of
  this package. It is not libpng-specific: FreeType reaches the same header from
  `include/freetype/config/ftstdlib.h:166` and HarfBuzz from `<hb-ft.h>`.

### `riscv64-linux-gnu` — the translator and the C compiler disagreed about one macro

* **Condition.** The `riscv64-linux-gnu` row of the same matrix.
* **Symptom.** libpng's own 15 units compiled and the facade's `translate-c`
  step did not, with the pinned toolchain's own message on the way in from
  `src/pngconf.h:50`:

  ```text
  /home/tmp2/gertullj/zig-global-cache/p/N-V-__8AAFFSVRWqblwBIcA-Yqv-u7sbjsJoww8K0mWaHbmJ/lib/libc/include/riscv-linux-gnu/bits/setjmp.h:35:3: error: unsupported FLEN
  # error unsupported FLEN
  ```

  `Build Summary: 8/12 steps succeeded (1 failed)` for the single-cell run.
* **Cause, read out of the pinned toolchain.** `bits/setjmp.h:32-36` gives the
  RISC-V `jmp_buf` twelve callee-saved `double` registers when
  `__riscv_float_abi_double` is defined, none when `__riscv_float_abi_soft` is,
  and raises `#error unsupported FLEN` for `__riscv_float_abi_single`, the only
  ABI left with no layout there. Clang and Aro disagree about which one that is:
  `zig cc -target riscv64-linux-gnu` predefines `__riscv_float_abi_double`
  (observed with an `#error` probe that names the macro), so this package's C
  units compile for the target, while `translate-c` predefines none of the three
  and stops on the same line.
* **Fix.** `build.zig` gives the translation the macro the compile was given.
  `translateCRiscvFloatAbi` derives it from the target being built — `d` gives
  `__riscv_float_abi_double`, `f` without `d` gives
  `__riscv_float_abi_single`, neither gives `__riscv_float_abi_soft` — and hands
  it to `translate.defineCMacro`, so the facade is translated against the ABI
  the library was compiled with. It goes on the translation only: clang already
  predefines it on every C compile line. It is null off RISC-V, so no other
  architecture sees a `-D` it did not need, and a `single`-ABI target still
  fails inside glibc rather than having its failure translated away.
* **Result, observed.** `zig build check -Dtarget=riscv64-linux-gnu` exited 0
  after the change, with `translate-c success 330ms`. Before it, the same
  command exited 1.
* **Targets bound.** Zig 0.16.0, and the `riscv32`/`riscv64` rows of any build
  graph that translates a header reaching `<setjmp.h>` under glibc. The entry
  rests on Aro's predefine set for RISC-V, so a toolchain that teaches
  `translate-c` the macro retires it, and until then the `-D` is the only way
  to make the translation agree with the compile.

### Receipts, for both rows

Both were run in this tree on 2026-10-05 with the pinned Zig 0.16.0 at
`/home/tmp2/gertullj/zig-global-cache/p/N-V-__8AAFFSVRWqblwBIcA-Yqv-u7sbjsJoww8K0mWaHbmJ/zig`,
`-j8 --summary all`, default optimize mode, `--cache-dir` under
`/home/tmp2/gertullj/cache/foundation-libs/wave10-fresh/libpng`. `zig build`
exited 0. `zig build check` exited 1 with `Build Summary: 52/57 steps succeeded
(2 failed)`, both failures inside the `wasm32-wasi` row, and
`zig build check -Dtarget=riscv64-linux-gnu` exited 0 — it exited 1 before the
`-D` landed. Logs: `local://libpng-check-six-targets-2026-10-05.log`,
`local://libpng-check-riscv64-linux-gnu-2026-10-05.log`,
`local://libpng-zig-build-2026-10-05.log`. `tools/check-provenance.sh` exited 0,
so no file under `src/`, `scripts/`, `tests/` or `contrib/` was touched.

## 6. Three gates have now been run, and only the 53-platform matrix executed a test binary

* **Condition.** `AGENTS.md` §6 defines the verification interface: per library
  repository `zig build`; `zig build test` in Debug and ReleaseSafe;
  `zig build smoke`; `zig build check`; per consumer package `zig build run`; and
  `cross-test` for the published 53-platform matrix.
* **Symptom.** Three of those are no longer unknown. On 2026-10-05, with the pinned
  Zig 0.16.0 at
  `/home/tmp2/gertullj/zig-global-cache/p/N-V-__8AAFFSVRWqblwBIcA-Yqv-u7sbjsJoww8K0mWaHbmJ/zig`,
  `-j8 --summary all`, default optimize mode: `zig build` exited 0, `zig build
  check` exited 1 with five rows compiling and `wasm32-wasi` failing for the
  reason in section 5, and `cross-test` over the 53-platform matrix exited 1
  with **18 cells executing 9/9 tests and passing** (section 11). Everything else
  is still `PENDING-VERIFICATION`: `test` in ReleaseSafe, `smoke`, `consumer`,
  the consumer's `zig build run`, the shared linkage, `-Druntime=true`, Nix and
  CI. No `check` cell may be called passing — `check` runs nothing, so its five
  compiling rows are `build_only`, which is what they are.
* **Fix.** None in this repository for the rest — the gates belong to the
  driver. What this package still owes: `zig build test` in ReleaseSafe,
  `zig build smoke`, `zig build consumer`, `cd consumer && zig build run`, the
  same in both linkages, and the receipts for the red cells section 11 names.
  The load-time ABI self-check the driver should run through the resolved table
  is written out in [`README.md`](README.md).
* **A note on what a compiled archive is not.** `libpng16.a` compiling is not a
  facade result and `zig fmt` exiting 0 is not a green gate — and on the
  `check` run `libpng16.a` compiling for five of six targets is exactly what was
  observed while `wasm32-wasi` did not compile at all. The behavioural proof is
  decoding the three fixtures to the exact expected pixels recorded in
  [`UPSTREAM.md`](UPSTREAM.md), which is an independent known answer and not a
  round trip. The 18 passing matrix cells do run those fixture decodes; the
  behavioural proof is now **partly** observed, and the rest of the proof —
  `smoke`, the installed C surface, the shared linkage — has not been run.
* **Targets bound.** Bounded to Zig 0.16.0 at the pinned compiler path, and to
  the six baseline targets plus the 53-platform matrix. A different toolchain
  version re-opens every entry in this file.

## 7. The allocator belongs to the C library, so the test framework cannot be a leak oracle

* **Condition.** `png_create_read_struct_2` and `png_set_mem_fn` take a
  user-supplied allocator, and libpng's own default is the C library's
  `malloc`/`free`/`realloc`.
* **Symptom (the trap).** Running the tests under `std.testing.allocator` would
  report the library's internal allocations as leaks, because those allocations
  never pass through the testing allocator. Conversely, the reverse mistake —
  installing the testing allocator and treating its report as covering
  everything — would hide a real leak inside libpng itself.
* **Fix.** Neither claim is made. `tests.zig` and `smoke.zig` say plainly that
  `std.testing.allocator` cannot be a leak oracle for third-party-allocated
  memory, and prove **ownership transitions** instead: a read struct destroyed
  exactly once, a write struct destroyed exactly once, and — where one is
  installed — the custom-allocator path exercised with an ordinary comparison,
  never a `std.debug.assert`.
* **Targets bound.** Bounded to this package's tests. It is a general property of
  every C library in this workspace that takes allocator callbacks, and it is the
  reason `AGENTS.md` §4 forbids treating the test framework as a leak oracle for
  memory that crosses into a third-party allocator.

## 8. Upstream's own test material is carried, never deleted and never replaced

* **Condition.** The release tarball ships `src/tests/` (upstream's test
  programs), `src/contrib/` (contribution material, including the PNG corpus —
  `pngsuite/`, `libtests/`, `testpngs/`, `oss-fuzz/`) and three root-level sample
  images. There is no `src/testimages/` directory in 1.6.59; that name belongs to
  other projects and inventing it here would be a small lie about the tarball.
* **Symptom.** This package has its own fixtures under `fixtures/`, and it would
  be easy to read that as replacing upstream's corpus.
* **Fix.** Both are recorded: upstream's material is **carried-but-not-run**,
  digested in [`UPSTREAM.sha256`](UPSTREAM.sha256) and never deleted; this
  package's three fixtures are fork-authored inputs to fork-authored tests, with
  independent provenance ([`UPSTREAM.md`](UPSTREAM.md)). Upstream's material is
  not built, because upstream drives it from `Makefile.am` test targets this
  package does not run — and no step fetches anything to stand in for them.
* **Targets bound.** Bounded to this import of libpng 1.6.59 and to
  `AGENTS.md` §7's fixture policy. A re-sync to another release may rename or
  relocate these directories, and the record has to move with them.

## 9. This import has no upstream commit identity

* **Condition.** The tarball is served from SourceForge and carries no upstream
  Git history in this import.
* **Symptom.** There is no commit SHA to record, no history to keep and no patch
  series to re-apply. A repository record with no commit in it can look like a
  gap.
* **Fix.** It is recorded as an archive import, in
  [`UPSTREAM.md`](UPSTREAM.md), [`FORK-LICENSE.md`](FORK-LICENSE.md) and
  [`CHANGELOG.md`](CHANGELOG.md) entry 1. **No commit, tag or revision is
  invented to fill the gap**, because none was observed. What stands in place of
  a commit identity is the release digest
  `86a3e4b501f7f50e392c4e456ea158893e9a595b1c63eb88c7bb9f6cf8772dad` plus the
  614 per-file digests in [`UPSTREAM.sha256`](UPSTREAM.sha256), and
  `tools/check-provenance.sh` rejects a missing, extra or renamed file — which a
  checksum run alone cannot see.
* **Targets bound.** Bounded to this import. Any package in this workspace built
  from a tarball rather than a VCS checkout has the same shape and the same
  obligation.

## 10. Upstream's ignore file is preserved untouched, and one entry needed a re-include

* **Condition.** `AGENTS.md` §4 requires preserving every upstream ignore
  convention and re-including fork paths where an upstream ignore is broad
  enough to swallow them.
* **Symptom.** `src/.gitignore` is upstream's own file and is preserved verbatim
  — it is one of the 614 digested files. Its **libpng-configuration** block ends
  with two entries that are broad enough to matter for this package:
  `pnglibconf.[ch]` and `pnglibconf.dfn`. Those match the *generated* header by
  name, anywhere a Git pattern without a slash matches. This package generates
  that header — into the build cache, not into `src/` — so the pattern never
  matches anything this fork produces, but a future change that generated it into
  the tree would be silently untrackable.
* **Fix.** This package's own `.gitignore` does not remove, narrow or reorder a
  single upstream entry, and it does not need to re-include any fork path: the
  fork-owned build, Nix and devenv artefacts it lists (`.zig-cache/`, `zig-out/`,
  `zig-pkg/`, `result`, `result-*`, `.devenv/`, `.devenv.flake.nix`,
  `.devenv.flakes/`, `devenv.local.nix`, `.direnv/`) match nothing in
  `src/.gitignore`, and `src/.gitignore` is itself inside the vendored tree that
  this repository's own ignore does not reach. The `pnglibconf.[ch]` entry is
  left exactly as upstream wrote it and is recorded here as the one upstream
  pattern that would need a `!pnglibconf.h` re-inclusion **if** a future wave
  decided to generate into the tree instead of into the build cache. It does not
  today.
* **Targets bound.** Bounded to libpng 1.6.59's `src/.gitignore` and to this
  package's decision to keep generated files out of the tree. A re-sync may change
  the ignore file, and then the re-inclusion question has to be re-asked.

## 11. The 53-platform `cross-test` run: 20 cells pass, 18 are build-only, 15 are red with named causes

* **Condition.** `AGENTS.md` §6 asks for `cross-test` over the published
  53-platform Zig 0.16 Tier 1/2 matrix, and §6 says a cell with no observed
  runner is `build_only` and never a pass.
* **Symptom, first run, observed 2026-10-05.** Run from the library root with the
  pinned compiler, `cross-test --output <scratch> --jobs 8 --build-jobs 8`, this
  tree's own `cross-test.profile.sh` (read, not edited: `CROSS_BUILD_STEP=test`,
  `CROSS_BUILD_JOBS=4`, `CROSS_BUILD_TIMEOUT=3600`, `CROSS_TIMEOUT=1800`; the
  command line overrode the job counts). The harness **exited 1** over **53
  targets**, reporting `pass=18 fail=17 build_only=0 partial=18`.
  Per cell: **18 pass**, **18 build-only** (`run test libpng-tests skipped`,
  nothing executed — macOS, maccatalyst, FreeBSD, OpenBSD and Windows rows have
  no local runner), **0 refused**, **2 runtime failures** (`powerpc64-linux`,
  `powerpc64le-linux`) and **15 build failures** (14 netbsd/openbsd rows plus
  `wasm32-wasi`). Run id `20261005-191611-72648-28081`.
* **Symptom, after the ppc64 fix, same day, same command.** Re-run once the
  fork-owned sources were hashed, held stable across a 300-second window and
  confirmed to compile on `x86_64-linux-musl`, `powerpc64-linux-musl`,
  `powerpc64le-linux-musl` and `aarch64-linux-musl` first — see section 12 for
  why that gate is part of the run and not an optional extra. The harness
  **exited 1** again over **53 targets**, run id `20261005-205643-73372-27975`,
  `bookkeeping_failure: false`, reporting **`pass=20 fail=15 build_only=0
  partial=18`**. Classified from that one summary file:
  * **20 pass** (build exit 0, `run test libpng-tests 9 pass (9 total)`, 9/9
    tests executed): the 18 above plus **`powerpc64-linux`** and
    **`powerpc64le-linux`**. Both ppc64 logs read `Build Summary: 12/12 steps
    succeeded; 9/9 tests passed`.
  * **18 build-only**, unchanged: `aarch64-freebsd`, `aarch64-maccatalyst`,
    `aarch64-macos`, `aarch64-openbsd`, `aarch64-windows`, `arm-freebsd`,
    `powerpc64-freebsd`, `powerpc64-openbsd`, `powerpc64le-freebsd`,
    `riscv64-freebsd`, `riscv64-openbsd`, `thumb-windows`, `x86-windows`,
    `x86_64-freebsd`, `x86_64-maccatalyst`, `x86_64-macos`, `x86_64-openbsd`,
    `x86_64-windows`.
  * **0 refused**, unchanged.
  * **15 build failures**, unchanged and unaffected by this fix:
    `aarch64-netbsd`, `aarch64_be-netbsd`, `arm-netbsd`, `arm-openbsd`,
    `armeb-netbsd`, `mips-netbsd`, `mips64-openbsd`, `mips64el-openbsd`,
    `mipsel-netbsd`, `powerpc-netbsd`, `powerpc-openbsd`, `x86-netbsd`,
    `x86-openbsd`, `x86_64-netbsd`, and `wasm32-wasi`.
  * **Net change from the first run: +2 pass, -2 runtime failure, nothing else.**
    The 15 build failures and the 18 build-only cells are the same cells, for
    the same reasons, as before.
* **Fix.** Two of the three red groups are the pinned toolchain's own headers
  refusing to translate, which is outside this package. The third was not: the
  two ppc64 rows were a real defect with a caller-side remedy that libpng
  publishes, and that remedy is now installed in fork-authored code (see the
  ppc64 entry below). No test was weakened, no cell was dropped, no `|| true`
  was added and no cell was relabelled to look green; the two rows run their
  real tests and pass.
* **Targets bound.** Zig 0.16.0 at the pinned compiler path, this tree's
  `cross-test.profile.sh`, and the runner availability on this host at run time.
  A host with Wine, a wasmtime and BSD emulators would convert build-only cells
  into pass-or-fail cells without a source change; a different toolchain version
  re-opens every cause below.

### `powerpc64-linux` and `powerpc64le-linux` — musl's `jmp_buf` is 16-byte aligned and musl's `malloc` is not

* **Condition.** The two ppc64 rows of the same matrix. Both compile.
* **Symptom.** `Build Summary: 10/12 steps succeeded (1 failed); 0/9 tests
  passed (9 crashed)`, `run test libpng-tests 0 pass, 9 crash (9 total)`. Every
  one of the nine tests aborts on the same Debug safety panic, and the first
  frame is inside libpng:

  ```text
  thread N panic: member access within misaligned address 0x7ff239cc0008 for type 'png_struct' (aka 'struct png_struct_def'), which requires 16 byte alignment
  src/pngread.c:52:16: in png_create_read_struct_2
      png_ptr->mode = PNG_IS_READ_STRUCT;
  ```

  The `...008` is the tell: the pointer is 8-byte aligned and the type wants 16.
* **Cause, read out of the pinned toolchain, with a measurement.** Four facts,
  in order:
  1. `src/pngstruct.h:125` makes `jmp_buf jmp_buf_local` the **first** member of
     `struct png_struct_def`, so the struct inherits the alignment of `jmp_buf`.
  2. `libc/include/powerpc64-linux-musl/bits/setjmp.h:1` is
     `typedef unsigned __int128 __jmp_buf[32];`, and `__int128` is 16-byte
     aligned on ppc64. Measured on `powerpc64-linux-musl` and
     `powerpc64le-linux-musl` with a `_Static_assert` and a `printf` probe:
     `_Alignof(unsigned __int128)=16`, `_Alignof(jmp_buf)=16`,
     `sizeof(jmp_buf)=656`, `_Alignof(struct { jmp_buf; long; })=16`. On
     `x86_64-linux-musl` the same probe reports `_Alignof(jmp_buf)=8`, which is
     why every other 64-bit row passes.
  3. `libc/include/powerpc64-linux-musl/bits/alltypes.h:33` makes musl's
     `max_align_t` `struct { long long __ll; long double __ld; }`, and
     `lib/std/Target.zig:3105-3119` gives `long double` **64 bits** for
     `.powerpc64` on the musl ABIs, so that struct is 8-byte aligned. Measured:
     `_Alignof(max_align_t)=8`, `sizeof(long double)=8` on both ppc64 rows;
     16 and 16 on `x86_64-linux-musl`.
  4. `lib/c/malloc.zig:20-21` sizes the libc allocator's alignment from
     `max_align_t`:
     `const alignment_bytes = @max(@alignOf(std.c.max_align_t), @sizeOf(Header));`.
     So on ppc64-musl, `malloc` returns 8-byte aligned memory. Measured under
     `qemu-ppc64` and `qemu-ppc64le`: `malloc mod 8 == 0`, `malloc mod 16 == 8`.
* **This package CAN fix it, and did. Decision (a), not a boundary.** The
  earlier note here recorded this as a bound. That was wrong, and the error was
  assuming the only remedies were inside `src/`. `PNG_USER_MEM_SUPPORTED` is
  defined (`src/scripts/pnglibconf.h.prebuilt:131`), so libpng itself publishes
  the seam: `png_create_read_struct_2` and `png_create_write_struct_2`
  (`src/png.h:997-1006`) accept a caller-supplied `malloc_fn`/`free_fn`, and
  `src/png.c:298-300` installs them through `png_set_mem_fn` **before**
  `src/png.c:331-332` allocates the `png_struct`. Every later allocation routes
  back through them too (`src/pngmem.c:88-99` for allocation, `:234-244` for
  release, including the `png_struct` itself through `png_destroy_png_struct`
  at `src/pngmem.c:24-37`). The hook is consulted before the system `malloc`,
  so an over-aligning allocator supplied there governs the very first
  allocation — the one that panicked. That is a caller-side remedy, and a
  caller-side remedy is inside this package's remit.
* **Fix, in fork-authored code only.** `zig/root.zig` now installs an
  over-allocating allocator pair on both create calls:
  `zig/root.zig:508-517` (the alignment and its reason), `:521-523` (the
  header), `:535-549` (`libpngMallocThunk`), `:557-564` (`libpngFreeThunk`),
  wired in at `:600-607` for `Reader.open` and `:814-821` for `Writer.open`.
  Each block is allocated with one whole alignment step of slack plus the
  header, so a 16-byte aligned address always exists inside it, and `free`
  recovers the original pointer from the header instead of guessing. `src/` is
  byte-identical: no vendored file was edited.
* **Measured, not asserted.** With the fix in place and nothing else changed,
  `zig build test -Dtarget=powerpc64-linux-musl` reports `Build Summary:
  12/12 steps succeeded; 9/9 tests passed` and
  `powerpc64le-linux-musl` reports the same. Before the fix, standalone
  `zig cc` probes against this tree's own `libpng16.a` under `/bin/qemu-ppc64`
  showed the default allocator aborting at `src/pngread.c:52` and the
  caller-supplied one printing `png_ptr=0x...010 align16=1`. A stress probe ran
  20 000 rounds over ten sizes straddling the header and alignment boundary and
  then 5 000 full read and write struct lifecycles: `alloc=220000
  free=220000 live=0`, every pointer 16-byte aligned, exit 0. The allocator
  balances, leaks nothing and over-aligns on both rows.
* **What this is not.** Not a weakened test, not a skipped cell, not a relabelled
  one. The same nine tests now execute on both ppc64 rows and pass; the fix is
  below the tests, in the allocator, and the pixels they check are unchanged.
* **Upstream is still not at fault, and the boundary that remains is upstream's.**
  `src/pngmem.c:98` returning plain `malloc` is correct C against the C
  standard's guarantee, which is `max_align_t`. Upstream musl's own allocator
  happens to hand out 16 bytes anyway (`#define ALIGN 16` in
  `src/malloc/lite_malloc.c`), which is why an Alpine ppc64 build of libpng is
  not reported broken; Zig's `lib/c/malloc.zig:20-21` sizes from `max_align_t`
  and so does not. That gap stays where it is — in the toolchain — and the
  package now works around it the way libpng's own API is meant to be used,
  rather than leaving two rows red.
* **Targets bound.** `powerpc64-linux` and `powerpc64le-linux` on Zig 0.16.0's
  musl. The same gap would appear for any C library that embeds a `jmp_buf` as
  the first member of a heap struct on that target; it is not libpng-specific
  and not Zig-facade-specific, which is why the remedy is a caller-supplied
  allocator rather than anything libpng does.

### Fourteen netbsd and openbsd rows — the pinned toolchain's own libc headers do not translate

* **Condition.** The `*-netbsd` and 32-bit plus mips64 `*-openbsd` rows.
* **Symptom.** `Build Summary: 8/12 steps succeeded (1 failed)`, all of them on
  the facade's `translate-c` step. The sibling zlib library and its per-target
  `zconf.h` generator compiled for every one of these rows; only the C
  translation of `zig/translate.h` failed.
* **Cause, read out of the pinned toolchain, and reproduced without libpng.**
  A probe header that includes only `<stddef.h>`, `<sys/types.h>` and `<stdio.h>`
  — no libpng header at all — fails the same way for the same rows, so the cause
  is in the toolchain's headers and not in this package:
  * **netbsd, seven rows** (`aarch64-netbsd`, `aarch64_be-netbsd`, `arm-netbsd`,
    `armeb-netbsd`, `powerpc-netbsd`, `x86-netbsd`, `x86_64-netbsd`):
    `libc/include/generic-netbsd/stdio.h:151` `__END_DECLS` expands through
    `sys/cdefs.h:432` and `:413` to `_Pragma("GCC visibility pop")`, which Aro's
    translator rejects with `error: unknown type name 'pragma'` and three
    follow-ons. 97 translation errors per cell.
  * **`mips-netbsd`, `mipsel-netbsd`** additionally stop earlier:
    `libc/include/mips-netbsd-eabi/machine/endian_machdep.h:8`
    `#error neither __MIPSEL__ nor __MIPSEB__ are defined.`
  * **`x86-openbsd`, `arm-openbsd`, `powerpc-openbsd`**: Aro's own
    `lib/compiler/aro/include/stddef.h:8` `typedef __SIZE_TYPE__ size_t;`
    collides with `libc/include/generic-openbsd/sys/types.h:173`
    `typedef __size_t size_t;` — `error: typedef redefinition with different
    types ('unsigned int' vs '__size_t' (aka 'unsigned long'))`.
  * **`mips64-openbsd`, `mips64el-openbsd`**:
    `libc/include/generic-openbsd/mips64/endian.h:40` `#error "__MIPSEL__ or
    __MIPSEB__ must be defined to define BYTE_ORDER!!!"`.
* **The boundary is narrower than "the BSDs".** `aarch64-openbsd`,
  `riscv64-openbsd`, `x86_64-openbsd`, `powerpc64-openbsd`, `aarch64-maccatalyst`
  and `x86_64-maccatalyst` all translate cleanly on the same toolchain and are
  build-only only because no runner exists for them. So the split is 32-bit
  netbsd, 32-bit openbsd and mips64 openbsd — not netbsd or openbsd as a family.
* **Fix.** None available here, and none attempted. Aro translating
  `_Pragma` inside `__END_DECLS`, and the netbsd/openbsd headers' own
  `size_t` and endianness guards, are the pinned toolchain's to fix. Editing a
  vendored libpng header or vendoring a replacement `sys/types.h` would break
  upstream integrity and is forbidden, so it was not done. The rows stay in the
  matrix and stay red.
* **Targets bound.** The listed rows on Zig 0.16.0 at the pinned compiler path.
  A toolchain that translates `_Pragma` in Aro, or that agrees with openbsd's
  `__size_t`, retires the relevant rows without a change here.

### `wasm32-wasi` — section 5's boundary, now observed on the `test` step too

* **Condition.** The `wasm32-wasi` row of the same matrix.
* **Symptom.** `Build Summary: 7/12 steps succeeded (2 failed)`. Both halves
  fail with the same pinned-toolchain message section 5 already records:
  `libc/include/wasm-wasi-musl/setjmp.h:13` `#error Setjmp/longjmp support
  requires Exception handling support`, reached from `src/pngconf.h:50` —
  `compile lib png16 Debug wasm32-wasi 15 errors` and `translate-c 2 errors`.
* **What is new.** Section 5 recorded this from `zig build check`, which
  compiles but runs nothing. This cell is the `test` step, so it confirms the
  same refusal when a run step is attached, and it confirms the zlib side is
  clean for the target: `compile lib zlib Debug wasm32-wasi success` and
  `run exe zlib-genzconf-wasm32-wasi.0.1...0.3-musl (zconf.h) success 98ms`
  both appear in the cell's log. The pressure point section 5 called unmeasured
  is measured and clean; the refusal is in wasi-libc's `setjmp.h` alone.
* **Status of the cell.** Unchanged from section 5: not a pass, not a refusal,
  not dropped. It is also **not** `build_only` — it does not compile.
* **Targets bound.** `wasm32-wasi` on Zig 0.16.0's wasi-libc. See section 5 for
  why `PNG_SETJMP_SUPPORTED` cannot be turned off from this package.

### Receipts for all three

Two harness invocations, both 2026-10-05, both from the library root, both with
`ZIG` pointing at the pinned 0.16.0 binary and both
`--jobs 8 --build-jobs 8`. Both **exited 1** over 53 targets.

**Before the fix**, `--output .../cross/libpng`, run id
`20261005-191611-72648-28081`, `pass=18 fail=17 partial=18`, summary at
`/home/tmp2/gertullj/scratch/foundation-libs/cross/libpng/cross-test-summary.json`.

**After the fix**, `--output .../cross/libpng2`, run id
`20261005-205643-73372-27975`, `pass=20 fail=15 partial=18`, summary at
`/home/tmp2/gertullj/scratch/foundation-libs/cross/libpng2/cross-test-summary.json`
(schema 2, `bookkeeping_failure: false`), per-cell logs at
`.../cross/libpng2/runs/20261005-205643-73372-27975/build-TARGET.log`, and the
fork-owned source digests taken before and after that run at
`.../cross/libpng2/fork-source-digests-before.txt` and
`.../fork-source-digests-after.txt`, which are identical — that is what makes
this run usable as evidence, and section 12 says why.

The alignment probes and the allocator stress probe quoted above are
standalone `zig cc` programs built for `powerpc64-linux-musl`,
`powerpc64le-linux-musl`, `x86_64-linux-musl` and `aarch64-linux-musl`, run
under `/bin/qemu-ppc64`, `/bin/qemu-ppc64le` and natively, and linked against
this tree's own `libpng16.a`. They live under scratch; nothing was written into
`src/`, and `tools/check-provenance.sh` reports all 614 upstream files matching
`UPSTREAM.sha256`.

## 12. Running this matrix honestly: hash the fork-owned sources, then hold still

* **Condition.** Any 53-cell run of `cross-test` in this tree.
* **Why this is written down.** A matrix is only evidence about *one* state of
  the sources. `build.zig` compiles each cell from the tree as it stands when
  that cell starts, so a run that spans two source states silently mixes
  results from two different packages and the summary is worse than useless —
  it looks authoritative. In this workspace that is not hypothetical: a sibling
  fork discarded three of its four runs for exactly this reason.
* **The rule.** Before starting a run, hash every fork-owned source — everything
  outside `src/` that a cell can read: `build.zig`, `build.zig.zon`, `zig/`,
  `runtime/`, `tools/`, `tests.zig`, `smoke.zig`, `consumer/`. After the run,
  hash them again. If the two sets differ, **the run is void**: discard it and
  start again. Do not reinterpret it, and do not re-run it and keep whichever
  answer looks better.
* **Hashes alone are not sufficient.** A file can be byte-identical across the
  window while a concurrent rename leaves a sibling half-merged and not
  compiling. The gate therefore has a second half: before the run, confirm the
  tree actually builds with the flags `build.zig` passes, and after the run,
  confirm the hashes still match. Both, or the run is void.
* **Classify from one summary file.** Take the per-cell numbers from a single
  `cross-test-summary.json`, never from comparing two runs. Two runs of the
  same tree can legitimately differ on a cell if the host changed underneath
  them — a fixed emulator port that another agent's run held is enough — and
  attributing that difference to the code is how a wrong cause gets recorded.
* **Re-read every citation before reporting.** Build graphs shift as this tree
  is edited, so a `file:line` written earlier in the same session can be stale
  by the time it is quoted. Verify each one against the tree as it stands at
  reporting time.
* **Targets bound.** The hashes are over this tree's own fork-owned files at the
  moment of the run; they say nothing about the sibling `../zlib`, whose own
  worker owns its stability. Nothing about the vendored `src/` is involved,
  because `tools/check-provenance.sh` already covers those 614 files by digest.