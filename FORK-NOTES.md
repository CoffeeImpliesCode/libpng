# Fork notes

## Source deviations

| Path | Change | Reason |
|---|---|---|
| `src/` | No upstream file is modified. | Preserve the release source. |
| `tools/pnglibconf.zig` | Emits `src/scripts/pnglibconf.h.prebuilt` into the build cache unchanged. | Avoid an AWK dependency and use upstream's fallback configuration. |
| `zig/root.zig` | Adds the Zig facade and over-aligned allocator callbacks for libpng read/write structures. | Expose a typed API and satisfy ppc64 musl's 16-byte structure alignment. |
| `zig/translate.h` | Includes `<stdio.h>` and `<setjmp.h>` before libpng's public headers for translation. | Those headers define `FILE` and `jmp_buf` used by the declarations. |
| `tests.zig` | Adds fork-owned facade tests. | Exercise the wrapper independently of upstream's test programs. |
| `smoke.zig` | Adds a facade smoke program. | Exercise the basic API in a standalone executable. |
| `fixtures/` | Adds three fork-owned image fixtures. | Provide known inputs for facade tests. |
| `consumer/` | Adds a separate package that consumes the module and library artifact. | Demonstrate the package's consumer interface. |

The prebuilt configuration sets `PNG_ZLIB_VERNUM` to `0`; this disables only the compile-time zlib-header version check. The required sibling zlib dependency supplies headers and the library.

## Build graph deviations

- Zig builds the 16 portable C units listed by upstream. It does not build architecture-specific SIMD units, assembly, upstream tests, examples, or `contrib/` tools.
- `pnglibconf.h` is generated in the build cache from the upstream prebuilt header, not written into `src/`.
- The sibling zlib dependency is required; there is no optional-zlib mode. No system zlib include path is added.
- Static linkage is the default. Dynamic linkage produces `libpng16.so.16.59.0` with ELF soname `libpng16.so.16`; Darwin shared builds also export internal symbols because the build has no equivalent version script.
- `-Druntime=true` selects explicit runtime loading. System mode is not implemented; `-Dsystem=true` is refused rather than falling back to the bundled library.

## Known platform boundaries

The recorded Zig 0.16.0 53-target matrix ran all nine tests on 20 targets, built 18 targets without a local runner, and failed to build 15 targets.

- `wasm32-wasi` fails because wasi-libc requires exception-handling support for `setjmp`/`longjmp`.
- Build failures affect `aarch64`, `aarch64_be`, `arm`, `armeb`, `mips`, `mipsel`, `powerpc`, `x86`, and `x86_64` NetBSD; `arm`, `x86`, `powerpc`, `mips64`, and `mips64el` OpenBSD; and `wasm32-wasi`. The BSD failures occur in Zig's libc-header translation: Aro rejects NetBSD visibility pragmas, some OpenBSD targets have `size_t` conflicts, and MIPS targets lack endianness macros. Other listed BSD targets compile; their matrix status is build-only when no runner exists.
- `riscv64-linux-gnu` translation requires the target floating-point ABI macro so Aro matches the C compiler. The build supplies it for translation; unsupported single-float ABI layouts still fail in glibc.
- ppc64 musl read/write alignment is handled by the facade's caller-supplied allocator; both ppc64 test targets passed in the recorded matrix.
