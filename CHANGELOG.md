# Changelog

- Fix Nix package evaluation with the PNG Reference Library version 2 license metadata.
- Supply pinned zlib sources through the Zig package cache for sandboxed Nix builds, with an overridable `zlibSrc` argument.
- Fix runtime provider version-string validation for Zig 0.17.0 with static or dynamic library delivery.
- Fix the ELF export-map terminator for shared builds and document the unsupported build-time system integration options.
- Exclude targets without a dynamic loader from the automatic check matrix for dynamic linkage or runtime loading.
- Port to Zig 0.17.0.

- Align allocations passed to libpng on ppc64, where `jmp_buf` requires 16-byte alignment.
- Fix C translation for `riscv64-linux-gnu` by defining the target's floating-point ABI macro.
- Add the libpng 1.6.59 package with `libpng` module, `png16` artifact, and optional `-Druntime=true` route.
