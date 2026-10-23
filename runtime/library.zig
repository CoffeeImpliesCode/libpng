// SPDX-License-Identifier: MIT
// See ../FORK-LICENSE.md for what that identifier covers.
//
//!
//! libpng-specific runtime-loader descriptor with provider ABI checks.
//! A provider must match this package's `pnglibconf.h` configuration.
const std = @import("std");

const rt = @import("rt");

/// Synchronization ABI shared with `runtime/sync.c`.
/// Namespaced symbols keep each SDK instance's loader state independent.
pub const Sync = struct {
    extern fn libpng_rt_lock() void;
    extern fn libpng_rt_unlock() void;
    extern fn libpng_rt_wait() void;
    extern fn libpng_rt_broadcast() void;
    // C `unsigned long long` is 64 bits on supported targets.
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

/// Build-time descriptor for the generated dispatch.
pub fn Config(comptime dispatch: type) type {
    return struct {
        /// Name used in pre-load panics.
        pub const library_name = "libpng";

        /// Generated table and required symbols.
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

        /// Checks the provider after symbol resolution and before publication.
        /// A non-null message rejects and closes the candidate.
        pub fn validate(dst: *const table) ?[]const u8 {
            // Numeric family check against translated `PNG_LIBPNG_VER`.
            const number = dst.png_access_version_number();
            // Compare as `u32`, matching `png_uint_32`; do not use floating point.
            const expected: u32 = @intCast(dispatch.PNG_LIBPNG_VER);
            if (number != expected) {
                // Print details here because `validate` has no allocator.
                std.debug.print(
                    "libpng: provider reports png_access_version_number {d}, this " ++
                        "SDK's headers describe {d}; they are different external ABIs\n",
                    .{ number, expected },
                );
                return "this provider was built from different libpng headers " ++
                    "than the ones this SDK describes";
            }

            // Null is accepted by libpng; prefix comparison rejects short or mismatched strings.
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
