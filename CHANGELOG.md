# Changelog

- Align allocations passed to libpng on ppc64, where `jmp_buf` requires 16-byte alignment.
- Fix C translation for `riscv64-linux-gnu` by defining the target's floating-point ABI macro.
- Add the libpng 1.6.59 package with `libpng` module, `png16` artifact, and optional `-Druntime=true` route.
