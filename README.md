# libpng

libpng 1.6.59, the PNG Reference Library, packaged as a Zig SDK. It builds the upstream C library and publishes a typed facade and translated C declarations.
Requires Zig 0.17.0.

## Source deviations from upstream

No files under the vendored `src/` tree are modified. The fork adds a Zig facade and build tooling outside that tree.

## Build deviations

- Zig builds the same 16 portable C units named by upstream's `Makefile.am`; CMake and autotools are not used.
- The build generates `pnglibconf.h` in the build cache from upstream's `src/scripts/pnglibconf.h.prebuilt`. Its `PNG_ZLIB_VERNUM=0` disables only the compile-time zlib-header version check.
- The package requires the sibling zlib dependency; there is no optional-zlib configuration. Architecture-specific SIMD units are not compiled.
- `-Dlinkage=static` is the default and builds `libpng16.a`. `-Dlinkage=dynamic` builds a shared library; on ELF, its name is `libpng16.so.16.59.0` and soname is `libpng16.so.16`.
- `-Druntime=true` selects explicit runtime loading instead of direct linkage. The caller chooses a path or system provider; there is no fallback.

## Support matrix

Pre-port baseline, recorded with Zig 0.16.0:

| Gate | Result |
|---|---|
| Six-target `zig build check` | Compiles `x86_64-linux-gnu`, `aarch64-linux-gnu`, `aarch64-macos-none`, `x86_64-windows-gnu`, and `riscv64-linux-gnu`. `wasm32-wasi` fails in wasi-libc's `setjmp.h`. |
| 53-target `cross-test` | 20 targets ran all 9 tests successfully; 18 compiled but had no runner; 15 failed to build; none were refused. |

The 20 passing targets are `aarch64-linux`, `aarch64_be-linux`, `arm-linux`, `armeb-linux`, `hexagon-linux`, `loongarch64-linux`, `mips-linux`, `mipsel-linux`, `mips64-linux`, `mips64el-linux`, `powerpc-linux`, `powerpc64-linux`, `powerpc64le-linux`, `riscv32-linux`, `riscv64-linux`, `s390x-linux`, `thumb-linux`, `thumbeb-linux`, `x86-linux`, and `x86_64-linux`.

The 18 build-only targets are `aarch64-freebsd`, `aarch64-maccatalyst`, `aarch64-macos`, `aarch64-openbsd`, `aarch64-windows`, `arm-freebsd`, `powerpc64-freebsd`, `powerpc64-openbsd`, `powerpc64le-freebsd`, `riscv64-freebsd`, `riscv64-openbsd`, `thumb-windows`, `x86-windows`, `x86_64-freebsd`, `x86_64-maccatalyst`, `x86_64-macos`, `x86_64-openbsd`, and `x86_64-windows`.

The 15 build failures are `aarch64-netbsd`, `aarch64_be-netbsd`, `arm-netbsd`, `arm-openbsd`, `armeb-netbsd`, `mips-netbsd`, `mips64-openbsd`, `mips64el-openbsd`, `mipsel-netbsd`, `powerpc-netbsd`, `powerpc-openbsd`, `x86-netbsd`, `x86-openbsd`, `x86_64-netbsd`, and `wasm32-wasi`. The BSD failures are in the pinned toolchain's libc-header translation; WASI fails on setjmp/longjmp support. See `FORK-NOTES.md` for boundaries and causes.

## Consumption

For a sibling checkout, set the dependency path to the package directory:

```zig
.dependencies = .{
    .libpng = .{ .path = "../libpng" },
},
```

Use the `libpng` module for the typed facade and translated declarations, and link the `png16` artifact:

```zig
const dep = b.dependency("libpng", .{ .target = target, .optimize = optimize });
exe_mod.addImport("libpng", dep.module("libpng"));
exe_mod.linkLibrary(dep.artifact("png16"));
```

The installed headers are under `include/libpng16/`; pkg-config uses `libpng16.pc`. C consumers must include `<stdio.h>` and `<setjmp.h>` before `<png.h>`.
