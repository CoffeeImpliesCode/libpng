# cross-test settings profile for the libpng SDK.
#
# `cross-test` looks for this file at the root of the project it is run from
# (or names it with --profile; --no-profile ignores it). It is trusted Bash that
# the harness `source`s, so this file is *settings only*: ordinary variable
# assignments and nothing else. No command runs, no compiler is probed, and no
# path in here names a host.
#
# There is deliberately no CROSS_MATRIX. The published 53-platform Zig 0.16
# Tier 1/2 table is the matrix this package is checked against, and a matrix
# named here would replace it. There is no TARGETS array either, for the same
# reason: a subset selected here would narrow the run rather than add to it.
# Both belong on the command line, where --targets selects from the active
# matrix and never adds to it.
#
# CROSS_BUILD_STEP stays the standard `test` step, which is what this profile
# states explicitly. There are no `cross_build_command` / `cross_artifact`
# hooks here, so the harness keeps its standard Zig-build mode and runs
# `zig build test -Dtarget=TARGET` per target with a fresh cache. What that
# means for a given target is the harness's decision, not this package's: a
# host target runs, a foreign target runs under whatever executor the harness
# detects (QEMU user mode, Wine, wasmtime), and a foreign target with no
# executor is reported as build-only coverage -- compiled, never executed, and
# never counted as a pass. `build.zig` gives the test binary a Run step for
# every target, which is what leaves that choice open.
#
# A target graph compiles the whole 16-unit closure of `src/Makefile.am`'s
# libpng16_la_SOURCES (`src/Makefile.am:127-129`), generates `pnglibconf.h`
# from `src/scripts/pnglibconf.h.prebuilt`, links the sibling zlib so its
# `zlib.h` reaches the include line, translates `zig/translate.h`, and links the
# facade and the test root. Keep a few build jobs available: each matrix cell
# compiles all 16 units and relinks the archive, so a low job count turns a
# 53-cell run into a very long one.
#
# Nothing here narrows the gate to what is expected to work. A cell that fails
# is a fact to record and diagnose; it is not a reason to drop the cell, sample
# the tests or remap Debug to an optimized mode to make it pass. In particular
# `wasm32-wasi` is an unknown for this package -- neither refused by build.zig
# nor claimed to work -- so its cell must report what actually happened rather
# than being tolerated; see FORK-NOTES.md section 5.

CROSS_BUILD_STEP=test
CROSS_BUILD_JOBS=4
CROSS_BUILD_TIMEOUT=3600
CROSS_TIMEOUT=1800