# Changelog

- Restore the Forgejo verification workflow on Zig 0.17, using the manifest's pinned CoffeeImpliesCode/zlib package instead of a stale sibling-checkout precondition.
- Restore the upstream AppVeyor file and its checksum, the release byte-count spelling, and the fixture provenance table required by the unchanged integrity gates.
- Enable WASI exception handling and C setjmp/longjmp lowering for the portable libpng build.
- Install manual pages under `share/man`, check the package-scoped licence directory, and parse readelf's SONAME field without requiring a nonexistent adjacent bracket.
- Deliver the pinned zlib archive and its licence with installed libpng, and name `-lzlib -lm` in static pkg-config metadata so plain C consumers do not substitute system zlib.
- Fix Nix package evaluation with the PNG Reference Library version 2 license metadata.
- Supply pinned zlib sources through the Zig package cache for sandboxed Nix builds, with an overridable `zlibSrc` argument.
- Fix runtime provider version-string validation for Zig 0.17.0 with static or dynamic library delivery.
- Fix the ELF export-map terminator for shared builds and document the unsupported build-time system integration options.
- Exclude targets without a dynamic loader from the automatic check matrix for dynamic linkage or runtime loading.
- Port to Zig 0.17.0.

- Align allocations passed to libpng on ppc64, where `jmp_buf` requires 16-byte alignment.
- Fix C translation for `riscv64-linux-gnu` by defining the target's floating-point ABI macro.
- Add the libpng 1.6.59 package with `libpng` module, `png16` artifact, and optional `-Druntime=true` route.
