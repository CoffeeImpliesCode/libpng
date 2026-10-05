// SPDX-License-Identifier: MIT
// See ../FORK-LICENSE.md for what that identifier covers.
//
//! libpng's side of the runtime loader: the names its synchronization binding
//! has, what it requires of a provider beyond resolving its symbols, and what
//! the external ABI boundary for this provider actually is.
//!
//! Everything else about the runtime route is generic. `runtime/loader.zig` is
//! the state machine and the platform layer; `runtime/generate.zig` builds the
//! dispatch from whatever the translation step actually produced;
//! `runtime/graph.zig` wires them together. This file is what makes them
//! libpng's, and it is the file another SDK replaces.
//!
//! ## What a provider must be
//!
//! Every `extern` declaration `zig/translate.h` produces that is not the C
//! library's own. In this configuration that is every `png_*` name the four
//! translated headers declare, with no exception: the generated
//! `pnglibconf.h` turns on `PNG_READ_SUPPORTED`
//! (`src/scripts/pnglibconf.h.prebuilt:81`), `PNG_WRITE_SUPPORTED` (`:154`) and
//! `PNG_SEQUENTIAL_READ_SUPPORTED` (`:112`), which together keep the reading
//! and writing sections of `src/png.h` in the translation.
//!
//! Nothing sits behind a macro this build leaves off, so `provider_optional`
//! and `provider_excluded` in `runtime/graph.zig` are both empty and a provider
//! that does not export the whole set is refused rather than half used.
//!
//! The C library's own surface reaches the translation and is classified as
//! noise in `runtime/graph.zig` rather than being part of what a provider
//! owes: `<stdio.h>` and `<setjmp.h>` are included by `zig/translate.h` for
//! `FILE *` in `png_init_io` (`src/png.h:1628-1629`) and for `jmp_buf` in
//! `png_set_longjmp_fn` (`src/png.h:971-972`), and `src/pngconf.h:30-31` adds
//! `<limits.h>` and `<stddef.h>`. A `libpng.so` exports none of those. There is
//! **no zlib name anywhere in the translation**: png.h's include closure reaches
//! no `zlib.h` at all - the only mention of zlib in png.h is a comment at
//! `src/png.h:1514` - and the `#error` at `src/pngpriv.h:1026-1028` is in a
//! header this build does not translate. A provider is still linked against a
//! zlib, but this package asks it for no zlib symbol directly.
//!
//! ## The ABI boundary, stated honestly
//!
//! The supported external ABI family is **libpng 1.6**, configured as the
//! generated `pnglibconf.h` in this package describes it. That is a narrower
//! claim than "a shared object that exports these names", and the difference is
//! real:
//!
//!   * **The provider must have been built with `PNG_SETJMP_SUPPORTED`.**
//!     `png_set_longjmp_fn` (`src/png.h:971-972`) is the declaration a caller
//!     uses to learn the size of the jump buffer, and `png_longjmp`
//!     (`src/pngerror.c:672-690`) is the C function every libpng error path
//!     ends in. A provider built without it has no `longjmp_fn` field to call,
//!     so a caller that sets a jump point against this header would be reading
//!     a field the provider does not have.
//!   * **The provider must have been built with `PNG_READ_SUPPORTED` and
//!     `PNG_WRITE_SUPPORTED`**, and with `PNG_STDIO_SUPPORTED`
//!     (`src/scripts/pnglibconf.h.prebuilt:124`) if `png_init_io` is to exist,
//!     because the declarations `src/png.h` publishes are exactly the ones the
//!     configuration selected. The `pnglibconf.h` a provider was configured
//!     with decides which `PNG_*_SUPPORTED` blocks are compiled at all, so a
//!     provider configured differently is a different ABI under the same
//!     symbol names - a different set of functions may simply not be there.
//!   * **`png_struct` and `png_info` are opaque here on purpose.**
//!     `src/png.h:437` and `:451` forward-declare both; the definitions live in
//!     `src/pngstruct.h:122` and `src/pnginfo.h:31`, which are private headers.
//!     A caller therefore holds pointers it cannot dereference, and the library
//!     is free to change either layout between releases without breaking this
//!     header. A provider built from a different 1.6 release keeps the same
//!     opaque names but may pair them with different internal layouts, which is
//!     exactly why the two facts checked below are checked through *its* own
//!     exported functions rather than through any size computed here.
//!   * **The allocator is still the provider's, and it is still not
//!     observable here.** `png_create_read_struct_2` and
//!     `png_create_write_struct_2` (`src/png.h:997-1006`) take `mem_ptr`,
//!     `malloc_fn` and `free_fn`. The linked facade passes its own
//!     over-allocating pair for the last two, so libpng allocates through it
//!     rather than through `png_malloc_default` - see `zig/root.zig` for why,
//!     and for the ppc64-musl misalignment that makes it necessary. What does
//!     not change is the boundary: every block remains owned and freed by the C
//!     allocator underneath, so nothing in this package can observe, bound or
//!     account for those allocations, and a Zig test allocator cannot be given
//!     a leak oracle for memory a third-party allocator owns.
//!
//!     A runtime-loaded provider is reached through the same `Reader.open` and
//!     `Writer.open` — `zig/root.zig` makes no configuration-dependent choice
//!     about the allocator — so it would get the same pair. That is a statement
//!     about the source, not an observed run: `-Druntime=true` does not compile
//!     today, on an unrelated pre-existing type error at
//!     `runtime/library.zig:240` (`[...c]const u8` where `std.mem.startsWith`
//!     wants `[]const u8`). That configuration is out of scope here and no gate
//!     in this change exercises it.
//!   * **`png_longjmp` is a longjmp boundary a Zig `defer` cannot survive.**
//!     `png_longjmp` (`src/pngerror.c:672-690`) calls the installed
//!     `longjmp_fn` on the stored `jmp_buf`, and where control cannot go it
//!     calls `PNG_ABORT()` (`src/pngpriv.h:579-580`, `abort()`). A longjmp does
//!     not unwind a Zig frame; it skips it, so a `defer` that would have
//!     released memory does not run. `zig/root.zig` states the same boundary to
//!     its callers and does not paper over it.
//!   * **Function-pointer types cross the boundary in both directions.**
//!     `png_rw_ptr`, `png_flush_ptr` and `png_error_ptr` (`src/png.h:788-796`)
//!     are called by the provider's own C with the provider's own calling
//!     convention.
//!
//! Resolving the symbols and translating the header is the boundary. They are
//! not proof that a provider is compatible, and this file does not pretend to
//! add more than it checks. What is checked at load time, before anything is
//! published:
//!
//!   * `png_access_version_number` answers with this header's `PNG_LIBPNG_VER`
//!     (`src/png.h:319`, declared `src/png.h:920-921`). `src/png.c:991-995`
//!     returns the compile-time `PNG_LIBPNG_VER` from the `.c` files, so this is
//!     a statement about the *provider's* build rather than about a constant
//!     compiled into this program.
//!   * `png_get_libpng_ver` answers with a string beginning with this header's
//!     `PNG_LIBPNG_VER_STRING` (`src/png.h:277`, declared `src/png.h:2574`).
//!     `src/png.c:842-854` shows the implementation: it returns
//!     `png_get_header_ver`, which returns `PNG_LIBPNG_VER_STRING` from the
//!     header the provider compiled against. Together with the number above,
//!     that is the pair that separates a provider built from these headers from
//!     one built from a different release or a different `pnglibconf.h`.
//!
//! What is deliberately *not* called here is anything that can raise. A load
//! that must be able to answer `ValidationFailed` cannot call a function whose
//! failure mode is `abort()` or a longjmp, which is every error path in
//! `src/pngerror.c`.
const std = @import("std");

const rt = @import("rt");

/// The synchronization this loader calls, bound by exact name.
///
/// The names below are `runtime/sync.c` compiled with
/// `RT_SYNC_PREFIX=libpng_rt`, which is what `runtime/graph.zig` passes. Two
/// spellings of that prefix have to agree: this file names the symbols, and
/// graph.zig defines the macro. A build where they disagree does not link, and
/// that is the whole error report: there is no runtime path that could hide it.
///
/// The core in `runtime/loader.zig` never names a symbol of its own, which is
/// what lets two SDKs, or two configurations of one SDK, hold their own loader
/// state in one process without sharing any of it.
pub const Sync = struct {
    extern fn libpng_rt_lock() void;
    extern fn libpng_rt_unlock() void;
    extern fn libpng_rt_wait() void;
    extern fn libpng_rt_broadcast() void;
    // `unsigned long long`. Declared as u64, which is the same type in every
    // ABI this SDK targets: 64-bit on x86_64, aarch64, riscv64 and wasm32.
    extern fn libpng_rt_thread_self() u64;

    pub fn lock() void {
        libpng_rt_lock();
    }
    pub fn unlock() void {
        libpng_rt_unlock();
    }
    pub fn wait() void {
        libpng_rt_wait();
    }
    pub fn broadcast() void {
        libpng_rt_broadcast();
    }
    pub fn threadSelf() u64 {
        return libpng_rt_thread_self();
    }
};

/// The loader's configuration for this SDK, given the dispatch that owns the
/// table.
///
/// `dispatch` is the generated module, passed as a type by the dispatch itself
/// so that this file never has to import it. The direction is one-way on
/// purpose: the descriptor knows what the loader needs, the dispatch knows what
/// the header said, and neither imports the other.
pub fn Config(comptime dispatch: type) type {
    return struct {
        /// Named in the pre-load panic, so the message says which library was
        /// reached for before it was loaded.
        pub const library_name = "libpng";

        /// The table the generated dispatch declares, and the symbols it needs
        /// to fill it. Both come from the translated headers, not from this file.
        pub const table = dispatch.Table;
        pub const symbols = dispatch.symbols;
        pub const optional_symbols = dispatch.optional_symbols;

        /// The project's namespaced synchronization binding.
        pub const sync = Sync;

        pub fn tablePtr() *table {
            return dispatch.tablePtr();
        }

        pub fn ready() *rt.Ready {
            return &dispatch.ready;
        }

        pub fn assign(comptime index: usize, dst: *table, address: *const anyopaque) void {
            dispatch.assign(index, dst, address);
        }

        pub inline fn assignOptional(comptime index: usize, dst: *table, address: *const anyopaque) void {
            dispatch.assignOptional(index, dst, address);
        }

        pub inline fn assignMissing(comptime index: usize, dst: *table) void {
            dispatch.assignMissing(index, dst);
        }

        /// The library-specific checks, run after every symbol resolved and
        /// before anything is published.
        ///
        /// A non-null answer is `ValidationFailed` and the candidate is closed
        /// without being published. Both checks are facts about the provider:
        /// the number comes from the `.c` files the provider was built from
        /// (`src/png.c:991-995`) and the string from the header it was built
        /// against (`src/png.c:848-854`), so neither can be satisfied by this
        /// package's own constants unless the provider really carries them.
        pub fn validate(dst: *const table) ?[]const u8 {
            // The numeric family check: 10659 for 1.6.59 (`src/png.h:319`).
            const number = dst.png_access_version_number();
            // `png_access_version_number` returns `png_uint_32`
            // (`src/png.h:920`), which is `unsigned int`, so the expected value
            // is the same width and the comparison is an integer one. An `f64`
            // here would not compare against a `png_uint_32` at all.
            const expected: u32 = @intCast(dispatch.PNG_LIBPNG_VER);
            if (number != expected) {
                // The numbers go to the diagnostic stream rather than into the
                // returned text: `validate` has no allocator and the loader
                // reports whatever string it is given.
                std.debug.print(
                    "libpng: provider reports png_access_version_number {d}, this " ++
                        "SDK's headers describe {d}; they are different external ABIs\n",
                    .{ number, expected },
                );
                return "this provider was built from different libpng headers " ++
                    "than the ones this SDK describes";
            }

            // The header check. `png_get_libpng_ver` ignores its argument
            // (`src/png.c:842-846` passes straight through to
            // `png_get_header_ver`, which does `PNG_UNUSED(png_ptr)`), so null is
            // what upstream's own definition accepts.
            // `startsWith` rather than a fixed-length slice: a provider whose
            // string is shorter than this header's must be refused, not read
            // past the end of.
            const reported = dst.png_get_libpng_ver(null);
            if (reported == null or
                std.mem.startsWith(u8, reported.?, dispatch.PNG_LIBPNG_VER_STRING) == false)
            {
                return "png_get_libpng_ver does not begin with the version string " ++
                    "this SDK's png.h defines, so this provider was built from " ++
                    "different headers than the ones these declarations describe";
            }

            return null;
        }
    };
}