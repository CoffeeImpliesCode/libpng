// SPDX-License-Identifier: MIT
// See ../FORK-LICENSE.md for what that identifier covers.

//! Zig facade over the libpng 1.6.59 C implementation.
//!
//! No part of libpng is reimplemented here. Every pixel, every row byte and
//! every header field this module reports was produced by the C under `src/`,
//! reached through `pub const c`, the module the translation step produces from
//! `zig/translate.h`. What the facade adds is the part a C header cannot
//! express: an owner that says exactly what destroying it means, a memory scope
//! for row buffers that libpng writes through but does not own, byte-exact row
//! handling with an ordinary comparison rather than a debug assertion, and one
//! honest answer for each condition libpng can report without raising.
//!
//! ## Import routes
//!
//! One Zig route is published: `dep.module("libpng")` in the dependent's
//! `build.zig`, which is `@import("libpng")` in source. The translated headers
//! are `c` on that same module and are not published as a module of their own,
//! so the declarations and the library that satisfies them arrive through one
//! route. A C consumer takes the installed headers and the installed library
//! instead; the installed `png.h` needs `<stdio.h>` and `<setjmp.h>` before it,
//! for the reasons `zig/translate.h` sets out.
//!
//! ```zig
//! const libpng = @import("libpng");
//! const std = @import("std");
//!
//! pub fn main() !void {
//!     const bytes = @embedFile("fixtures/grey8x8-200.png");
//!     var source = libpng.Source.init(bytes);
//!     var reader = try libpng.Reader.open();
//!     defer reader.deinit();
//!     const header = try reader.readInfo(&source);
//!     var rows = try libpng.Rows.alloc(std.heap.page_allocator, header.height, reader.rowBytes());
//!     defer rows.deinit();
//!     try reader.readImage(rows.asPointers());
//! }
//! ```
//!
//! ## Allocation, and the third-party allocator
//!
//! This module allocates nothing for libpng. `Reader` and `Writer` are two
//! pointers each; `Source` and `Sink` are a slice and a slice plus a length.
//! The only Zig allocation the facade asks for is `Rows.alloc`, which is the
//! caller's row storage and is freed by `Rows.deinit`.
//!
//! Everything libpng allocates is still libpng's, but it comes from the
//! over-allocating allocator this module installs, not from upstream's
//! `png_malloc_default`. `Reader.open` and `Writer.open` pass
//! `libpngMallocThunk`/`libpngFreeThunk` for the `malloc_fn`/`free_fn` that
//! `png_create_read_struct_2` and `png_create_write_struct_2` accept
//! (`src/png.h:997-1006`), so every block libpng allocates is 16-byte aligned.
//! That is what makes `png_struct` - whose first member is a `jmp_buf`
//! (`src/pngstruct.h:125`), 16-byte aligned on ppc64-musl - correctly aligned
//! on targets where `max_align_t` is only 8. Each block is still owned and freed
//! by the C allocator underneath, so `deinit` remains the whole answer this
//! module can give about libpng's memory: it destroys the structures, and
//! destroying them releases everything libpng attached to them. Nothing here
//! can bound, intercept or account for those allocations, and
//! `std.testing.allocator` cannot be given a leak oracle for them. See
//! `libpng_alignment` for the measurement that fixes the number at 16.
//!
//! ## Two configurations: linked and runtime-loaded
//!
//! This module is built in one of two shapes, and `runtime_loaded` says which
//! at comptime.
//!
//! *Linked* is the default. The C library is linked, `c` is the translation of
//! `zig/translate.h`, and every call below is a direct call with no table and
//! no check.
//!
//! *Runtime-loaded* is opt-in (`-Druntime`). The library is not linked; `c` is
//! a dispatch generated from the same translation step's output, and every
//! `png_*` declaration the translated headers make is resolved through the
//! platform loader when the caller calls
//!
//! ```zig
//! try libpng.load(.{ .path = "/usr/lib/libpng16.so.16.59.0" });
//! ```
//!
//! before using anything else. A call into a module that has not loaded stops
//! the program with a message naming the function, in every optimization mode.
//! That is a programming error rather than a recoverable condition: the table
//! does not exist yet and there is no partial state to fall back on.
//!
//! The provider is reached, never guessed. `.path` names a file and `.system`
//! names a library for the platform loader; neither falls back to the other,
//! the module has no unload and no reset, and it keeps the handle to the end of
//! the process. `runtime/library.zig` states what a provider must be,
//! including the libpng 1.6 external ABI family this SDK supports and why a
//! provider built against a different `pnglibconf.h` is refused rather than
//! half used.
//!
//! ## Errors: what libpng raises, and what it returns
//!
//! libpng has two very different failure shapes and this module treats them
//! differently rather than smoothing them over.
//!
//! The returning ones become Zig errors here, and they are exactly the
//! conditions this file checked:
//!
//!   * `OutOfMemory` - `png_create_read_struct_2` or `png_create_info_struct`
//!     answered null (`src/png.c:359-363`, `:387-390`).
//!   * `NotPng` - `png_sig_cmp` (`src/png.h:934-935`) found no PNG signature.
//!   * `HeaderMissing` - `png_get_IHDR` answered zero (`src/pngget.c:945-946`).
//!   * `RowBytesUnavailable` - `png_get_rowbytes` answered zero
//!     (`src/pngget.c:42-45`).
//!   * `RowStrideMismatch` - this module's own check, described under `Rows`.
//!   * `SinkOverflow` - a `Sink` ran out of room; see `Sink`.
//!
//! The raising one is not turned into a Zig error, because it cannot be.
//! Every libpng error ends in `png_longjmp` (`src/pngerror.c:672-690`): it
//! calls the installed `longjmp_fn` if the caller established a jump point with
//! `png_set_longjmp_fn` (`src/png.h:971-972`), and otherwise calls
//! `PNG_ABORT()`, which is `abort()` (`src/pngpriv.h:579-580`). A longjmp does
//! not unwind a Zig frame - it skips it - so a `defer` that would have released
//! memory does not run and the error in flight never becomes a Zig error.
//! `Reader` and `Writer` pass null for `error_fn` and `warning_fn`
//! (`src/png.h:997-1001`), so upstream's default handler is installed and a
//! malformed stream terminates the process rather than returning.
//!
//! That is stated rather than hidden. A caller who needs a recoverable error
//! installs a jump point itself, through `c`:
//!
//! ```zig
//! // A Zig frame cannot survive the longjmp: install this from C, or accept
//! // that libpng errors abort the process.
//! const buf = libpng.c.png_set_longjmp_fn(reader.raw, longjmp, @sizeOf(jmp_buf));
//! ```
//!
//! `Source` and `Rows` are how this module keeps a caller *out* of that
//! territory for the common cases: `Reader.readInfo` refuses input whose
//! signature does not match before any libpng state exists, and `Rows` refuses
//! a row buffer that does not match `png_get_rowbytes` before
//! `png_read_image` writes through a pointer.
//!
//! ## Lifetime
//!
//! `Reader` owns exactly one `png_struct` and one `png_info`, and `deinit`
//! destroys exactly those through the same `c` route that created them - the
//! same provider in a runtime-loaded build. `deinit` clears both fields first,
//! so a second `deinit` on the same variable is a no-op rather than a second
//! destroy. Zig cannot make a struct non-copyable, so the remaining rule is the
//! usual one: copy a `Reader` before `deinit` and you have two owners of one
//! pair of structures.
//!
//! `Source` is a borrowed view of bytes the caller owns. It is passed to each
//! call that reads rather than stored inside `Reader`, because a `Reader` is a
//! value and a pointer into it would dangle the moment the caller moved it.
//!
//! `Sink` is the write-side counterpart and is likewise borrowed; `deinit` on a
//! `Writer` does not free the sink's buffer.
//!
//! ## Threading
//!
//! A `png_struct` is plain mutable state with no locking: upstream documents
//! that one `png_struct` must not be used from two threads at once. A `Reader`
//! or `Writer` therefore belongs to one thread at a time. Two `Reader`s over
//! two `Source`s are independent and may run on two threads, because
//! everything they touch is per-structure except the loader's own table, which
//! the loader core synchronises.

const std = @import("std");

/// The translated `png.h` and `pngconf.h`, i.e. upstream's ABI exactly as
/// published.
///
/// This is the escape hatch for every declaration the facade does not name
/// (`png_init_io`, the `png_set_*` transform family, the simplified
/// `png_image` API, `png_set_error_fn`, `png_set_longjmp_fn`), and it is the
/// same module the facade calls, on the same library, so importing the facade
/// is all a dependent needs to reach it.
///
/// The declarations are for whichever headers this build selected, which is
/// `src/png.h` and `src/pngconf.h` together with the generated
/// `pnglibconf.h`. A caller that reaches past the facade gets
/// upstream behaviour and inherits every obligation upstream declares.
pub const c = @import("c");

/// The loader core, which is where a linked build's two public types come
/// from.
///
/// It is imported only by the linked configuration. In a runtime-loading build
/// the dispatch carries its own copy of the same declarations, and this module
/// is never referenced, so it is never resolved and never compiled.
const rt = @import("rt");

/// Whether this module was configured to resolve its native symbols at run
/// time.
///
/// False for the ordinary build, where the C library is linked and `c` is the
/// translation of `zig/translate.h`. True when the build generated a dispatch
/// that resolves the same symbols through the platform loader, in which case
/// `load` is the call that makes the library usable.
///
/// It is a comptime constant, so a consumer can write two different code paths
/// and have only the one it chose analyzed.
pub const runtime_loaded: bool = if (@hasDecl(c, "rt_runtime_loaded")) c.rt_runtime_loaded else false;

/// Which native library `load` should open.
///
/// `.path` is an explicit file path and `.system` is an explicit name for the
/// platform loader. There is no path-to-system fallback and no implicit
/// fallback of any kind; a request that cannot be honoured is an error, not a
/// different library.
pub const LoadSource = if (runtime_loaded) c.LoadSource else rt.LoadSource;

/// Every way `load` can decline.
///
/// Declared here, in the module a consumer imports, rather than only inside the
/// loader: the caller names the failure it is handling.
pub const LoadError = if (runtime_loaded) c.LoadError else rt.LoadError;

/// Load the native library this module dispatches to.
///
/// In a runtime-loading build this is the whole contract: call it once, then
/// use this module as if it were linked. Calling it again with the same request
/// succeeds and changes nothing; calling it with a different request after a
/// success is `ProviderMismatch`, and the library already in use stays in use.
/// A failed attempt publishes nothing and can be retried explicitly, by
/// calling this again.
///
/// It keeps the process handle and its own copy of the request to the end of
/// the process. There is no unload and no reset.
///
/// In a linked build there is no provider, no table and nothing to resolve, so
/// this stops the program with a message saying so instead of quietly
/// succeeding. `runtime_loaded` is false there, so a consumer that supports
/// both configurations can tell the two apart at comptime.
pub fn load(source: LoadSource) LoadError!void {
    // `c.load` exists only in a runtime-loading build. The condition is known
    // at comptime, so the branch this build does not take is never analyzed.
    if (runtime_loaded) return c.load(source);
    std.debug.panic(
        "libpng: load was called on a linked build; this module is not " ++
            "runtime-loaded, so there is no library to load. Build with " ++
            "runtime loading configured, or do not call load.",
        .{},
    );
}

/// The request that succeeded, or null when nothing has loaded yet.
///
/// The answer is the loader's own retained copy and stays valid for the life of
/// the process. Null in a linked build, which has no request.
pub fn loadedSource() ?LoadSource {
    if (runtime_loaded) return c.loadedSource();
    return null;
}

/// Every way a facade call can report a condition it checked.
///
/// Each tag is one condition this file actually checked; see the module
/// comment for which upstream call produces it and what libpng does with the
/// conditions it does *not* appear here for.
pub const Error = error{
    /// `png_create_read_struct_2` or `png_create_write_struct_2` answered null.
    OutOfMemory,
    /// `png_create_info_struct` answered null.
    InfoStructUnavailable,
    /// `png_sig_cmp` found no PNG signature in the first eight bytes.
    NotPng,
    /// `png_get_IHDR` answered zero, so there is no header to describe.
    HeaderMissing,
    /// `png_get_rowbytes` answered zero.
    RowBytesUnavailable,
    /// The row buffer does not match the row size libpng reports, checked here
    /// rather than left to a write past the end of a buffer.
    RowStrideMismatch,
    /// The `Sink` ran out of room and dropped bytes; see `Sink`.
    SinkOverflow,
};

/// The eight bytes every PNG file begins with.
///
/// This is `png_signature` as `src/png.c:82` spells it, `{137, 80, 78, 71, 13,
/// 10, 26, 10}`. `Source` compares against the same values through libpng's
/// own `png_sig_cmp`, so this constant is a convenience for a caller that wants
/// to test bytes without a library, not the thing that decides.
pub const signature = [8]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };

/// A PNG colour type (`src/png.h:666-673`).
pub const ColorType = enum(c_int) {
    greyscale = c.PNG_COLOR_TYPE_GRAY,
    rgb = c.PNG_COLOR_TYPE_RGB,
    indexed = c.PNG_COLOR_TYPE_PALETTE,
    greyscale_alpha = c.PNG_COLOR_TYPE_GRAY_ALPHA,
    rgba = c.PNG_COLOR_TYPE_RGBA,
};

/// How a PNG file's rows are ordered (`src/png.h:685-686`).
pub const Interlace = enum(c_int) {
    none = c.PNG_INTERLACE_NONE,
    adam7 = c.PNG_INTERLACE_ADAM7,
};

/// What the IHDR chunk of a PNG file says.
///
/// Every field is libpng's own: `width`, `height`, `bit_depth`, `color_type`,
/// `interlace`, `compression_method` and `filter_method` come from
/// `png_get_IHDR` (`src/png.h:2169-2173`), which copies them out of the `png_info`
/// (`src/pngget.c:948-970`). Nothing here is re-derived.
pub const Header = struct {
    width: u32,
    height: u32,
    bit_depth: c_int,
    color_type: ColorType,
    interlace: Interlace,
    compression_method: c_int,
    filter_method: c_int,

    /// The colour type as the raw `int` libpng reported, for a caller that
    /// wants to compare against a value it computed itself.
    pub fn rawColorType(self: Header) c_int {
        return @intFromEnum(self.color_type);
    }

    /// The interlace method as the raw `int`.
    pub fn rawInterlace(self: Header) c_int {
        return @intFromEnum(self.interlace);
    }
};

/// The bytes of one PNG file, read from memory.
///
/// A `Source` owns nothing: the slice is borrowed from the caller and must
/// outlive every call that takes a `*Source`. Nothing is copied, so a source can
/// be `@embedFile` output or a mapped file with no intermediate buffer.
///
/// libpng reads through a callback rather than through `FILE *`, so this type
/// has no `FILE` in it and does not need `<stdio.h>` at run time; see
/// `zig/translate.h` for why the *header* still needs it.
pub const Source = struct {
    bytes: []const u8,
    offset: usize = 0,

    pub fn init(bytes: []const u8) Source {
        return .{ .bytes = bytes };
    }

    /// Whether the first eight bytes are the PNG signature, decided by libpng's
    /// own `png_sig_cmp` (`src/png.h:934-935`) rather than by a comparison
    /// written here.
    ///
    /// Fewer than eight bytes is not a signature: `png_sig_cmp` compares only
    /// what it was given and returns non-zero for anything shorter than a match
    /// (`src/png.c:87-97`), so a truncated buffer is rejected here rather than
    /// inside a read.
    pub fn hasSignature(self: Source) bool {
        if (self.bytes.len < signature.len) return false;
        return c.png_sig_cmp(self.bytes.ptr, 0, signature.len) == 0;
    }
};

/// Where a `Writer` puts the bytes it produces.
///
/// The sink is a fixed buffer the caller owns, plus the number of bytes written
/// so far. libpng writes through a callback that cannot report a failure
/// (`png_write_data`, `src/pngwio.c:31-41`, calls it and ignores everything
/// else), so an overflowing sink cannot become a C error. This module handles
/// that honestly rather than by growing the buffer behind the caller's back:
///
///   * `append` never writes past the end. Bytes that do not fit are dropped.
///   * `overflowed` becomes true, and stays true.
///   * `Writer.writeRow` and `Writer.writeImage` check it and return
///     `error.SinkOverflow`.
///
/// A rejected write therefore leaves the sink holding a *truncated* PNG: the
/// bytes written before the overflow are kept and are not a valid file. That is
/// what upstream's callback signature permits, and it is stated here so that a
/// caller sizes the sink with `PNG_IMAGE_SIZE`-equivalent arithmetic rather than
/// discovering it afterwards.
pub const Sink = struct {
    buffer: []u8,
    len: usize = 0,
    overflowed: bool = false,

    pub fn init(buffer: []u8) Sink {
        return .{ .buffer = buffer };
    }

    /// The bytes written so far.
    pub fn written(self: *const Sink) []const u8 {
        return self.buffer[0..self.len];
    }

    /// Append as much of `bytes` as fits, and record whether anything did not.
    ///
    /// The one place bytes enter the sink, so the bound is in one place. It
    /// returns what was accepted, which is the whole of `bytes.len` unless the
    /// sink filled first.
    pub fn append(self: *Sink, bytes: []const u8) usize {
        const room = self.buffer.len - self.len;
        if (bytes.len > room) {
            self.overflowed = true;
            @memcpy(self.buffer[self.len..], bytes[0..room]);
            self.len = self.buffer.len;
            return room;
        }
        @memcpy(self.buffer[self.len..][0..bytes.len], bytes);
        self.len += bytes.len;
        return bytes.len;
    }

    /// Whether the sink has ever dropped bytes.
    pub fn hasOverflowed(self: *const Sink) bool {
        return self.overflowed;
    }

    // The callback libpng calls. It cannot fail, so a short write is recorded
    // and reported by the next Zig-level call instead; see the type comment.
    fn writeThunk(png_ptr: c.png_structp, data: c.png_bytep, length: usize) callconv(.c) void {
        const sink: *Sink = @ptrCast(@alignCast(c.png_get_io_ptr(png_ptr).?));
        _ = sink.append(data[0..length]);
    }
};

/// Row storage, and the pointer array libpng writes an image through.
///
/// libpng does not own row buffers. `png_read_image` takes `png_bytepp` and
/// writes a scanline into each element (`src/png.h:1445-1446`, and
/// `src/pngread.c:612-...` where it calls `png_read_row` per row);
/// `png_write_image` and `png_write_row` read from them (`src/png.h:1450-1451`,
/// `:1462-1463`). A caller that gets this wrong writes past the end of its own
/// buffer, and a C header cannot express the constraint, so this module owns it:
///
/// `alloc` takes the row size from `png_get_rowbytes` and refuses a height or
/// a size that cannot be satisfied. `asPointers` hands libpng the array it will
/// write through, and it stays valid exactly as long as `Rows` is alive; nothing
/// reallocates it.
///
/// The stride is *not* padded: `png_get_rowbytes` is "number of bytes needed to
/// hold a transformed row" (`src/png.h:1936`) and that is exactly the size each
/// row occupies here, so `slice(row)` returns a byte-exact row and nothing has
/// to be undone before comparing pixels.
pub const Rows = struct {
    allocator: std.mem.Allocator,
    /// One contiguous allocation, `height * row_bytes` bytes, top row first.
    storage: []u8,
    /// One row pointer per row, in the same order as `storage`.
    pointers: []c.png_bytep,
    row_bytes: usize,

    /// Allocate `height` rows of `row_bytes` bytes each.
    ///
    /// `error.RowStrideMismatch` is what a caller gets if the size it passed and
    /// the multiplication do not agree; `error.OutOfMemory` is the allocator's.
    /// Nothing is padded and nothing is rounded, so `rows.slice(y)` is exactly
    /// `row_bytes` long.
    pub fn alloc(allocator: std.mem.Allocator, rows_wanted: u32, row_bytes: usize) (Error || std.mem.Allocator.Error)!Rows {
        if (row_bytes == 0) return error.RowBytesUnavailable;
        const count: usize = @intCast(rows_wanted);
        const total = std.math.mul(usize, count, row_bytes) catch
            return error.RowStrideMismatch;
        const storage = try allocator.alloc(u8, total);
        errdefer allocator.free(storage);
        const pointers = try allocator.alloc(c.png_bytep, count);
        errdefer allocator.free(pointers);

        for (pointers, 0..) |*slot, row| {
            slot.* = storage[row * row_bytes ..][0..row_bytes].ptr;
        }
        return .{
            .allocator = allocator,
            .storage = storage,
            .pointers = pointers,
            .row_bytes = row_bytes,
        };
    }

    /// Release both allocations.
    pub fn deinit(self: *Rows) void {
        self.allocator.free(self.pointers);
        self.allocator.free(self.storage);
        self.* = undefined;
    }

    /// The number of rows.
    pub fn height(self: *const Rows) usize {
        return self.pointers.len;
    }

    /// The bytes of one row, byte-exact: no padding, no alignment slack.
    pub fn slice(self: *const Rows, row: usize) []u8 {
        return self.storage[row * self.row_bytes ..][0..self.row_bytes];
    }

    /// The array `png_read_image` and `png_write_image` take.
    ///
    /// `png_bytepp` is `[ * ]png_bytep` in C (`src/png.h:1446`), so this is a
    /// pointer to the first element rather than a slice: upstream reads
    /// `image_height` elements and no length is passed.
    pub fn asPointers(self: *const Rows) c.png_bytepp {
        return self.pointers.ptr;
    }

    /// Whether `len` bytes is what a row of this image occupies.
    ///
    /// An ordinary comparison on purpose: this guards a public contract a caller
    /// can get wrong, and `std.debug.assert` is compiled out in a release build,
    /// which would leave the caller writing through a short buffer.
    pub fn fitsRow(self: *const Rows, len: usize) bool {
        return len == self.row_bytes;
    }
};

/// The alignment every libpng-owned allocation is given.
///
/// `src/pngstruct.h:125` makes `jmp_buf jmp_buf_local` the first member of
/// `struct png_struct_def`, so `png_struct` inherits `jmp_buf`'s alignment.
/// On `powerpc64-linux-musl` and `powerpc64le-linux-musl` that is 16 bytes,
/// because `__int128` is 16-byte aligned there. The C library's `malloc` only
/// guarantees `max_align_t`, which those targets size at 8 bytes, so upstream's
/// `png_malloc_default` can hand back an 8-byte aligned `png_struct` and every
/// access through it is misaligned.
const libpng_alignment: std.mem.Alignment = .@"16";

/// One allocation's bookkeeping, stored immediately below the pointer handed
/// to libpng.
const AllocHeader = struct {
    /// The pointer the C allocator returned, which is what must be freed.
    base: ?*anyopaque,
};

/// The `malloc_fn` handed to `png_create_read_struct_2` and
/// `png_create_write_struct_2`.
///
/// `src/pngmem.c:88-99` routes every allocation through this when
/// `PNG_USER_MEM_SUPPORTED` is set, which `pnglibconf.h` enables
/// (`src/scripts/pnglibconf.h.prebuilt:131`). The block is over-allocated by one
/// whole alignment step plus this header, so a correctly aligned address always
/// exists inside it, and `free_fn` recovers the original pointer from the
/// header rather than guessing.
fn libpngMallocThunk(png_ptr: c.png_structp, size: c.png_alloc_size_t) callconv(.c) ?*anyopaque {
    _ = png_ptr;
    const wanted: usize = @intCast(size);
    // `png_malloc_base` has already rejected `size > PNG_SIZE_MAX`
    // (`src/pngmem.c:85`), so the additions below cannot wrap in practice. The
    // checks are kept because a release build compiles the cast away.
    const slack = libpng_alignment.toByteUnits() + @sizeOf(AllocHeader);
    const total = std.math.add(usize, wanted, slack) catch return null;
    const base = std.c.malloc(total) orelse return null;
    const base_addr = @intFromPtr(base) + @sizeOf(AllocHeader);
    const aligned = std.mem.alignForward(usize, base_addr, libpng_alignment.toByteUnits());
    const header: *AllocHeader = @ptrFromInt(aligned - @sizeOf(AllocHeader));
    header.base = base;
    return @ptrFromInt(aligned);
}

/// The `free_fn` paired with `libpngMallocThunk`.
///
/// `src/pngmem.c:234-244` calls this for everything `libpngMallocThunk`
/// returned, including the `png_struct` itself through `png_destroy_png_struct`
/// (`src/pngmem.c:24-37`), so the header read here is always one this module
/// wrote.
fn libpngFreeThunk(png_ptr: c.png_structp, ptr: ?*anyopaque) callconv(.c) void {
    _ = png_ptr;
    const raw = ptr orelse return;
    const header: *AllocHeader = @ptrFromInt(@intFromPtr(raw) - @sizeOf(AllocHeader));
    const base = header.base orelse return;
    header.base = null;
    std.c.free(base);
}

/// The reading side: one `png_struct` and one `png_info`, and what destroying
/// them means.
///
/// `open` creates both through `png_create_read_struct_2`
/// (`src/png.h:997-1001`) and `png_create_info_struct` (`src/png.h:1033-1035`),
/// passing null for `user_png_ver` and for the error and warning functions,
/// which leaves upstream's own default error handler installed, and passing
/// this module's over-allocating allocator pair. See the module comment for
/// both of those, and for what a malformed stream means here.
pub const Reader = struct {
    /// The owned structure, or null once `deinit` has run.
    raw: ?*c.png_struct = null,
    /// The owned header, or null once `deinit` has run.
    info: ?*c.png_info = null,

    /// The `Source` the last `setSource` installed, if any.
    source: ?*Source = null,

    /// Every way `open` can fail.
    pub const OpenError = error{ OutOfMemory, InfoStructUnavailable };

    /// Create a reader that has not yet seen any bytes.
    ///
    /// `user_png_ver` is `PNG_LIBPNG_VER_STRING`, which `src/png.h:277` already
    /// defines and the translation carries as a Zig constant, so nothing is
    /// restated here. It has to be passed: `src/png.c:327-329` allocates the
    /// structure only when `png_user_version_check` returns non-zero, and
    /// `src/png.c:227-229` reports a mismatch for a null `user_png_ver` - which
    /// is a refusal, not the warning the surrounding `png_warning` suggests.
    /// With it null this function failed on every call.
    pub fn open() OpenError!Reader {
        // `png_create_read_struct_2` returns null when the version check
        // refuses or the allocation fails (`src/png.c:327-363`); the check
        // passes here, so only the allocation can do it.
        const raw = c.png_create_read_struct_2(
            c.PNG_LIBPNG_VER_STRING,
            null,
            null,
            null,
            null,
            libpngMallocThunk,
            libpngFreeThunk,
        ) orelse
            return error.OutOfMemory;
        // `png_create_info_struct` returns null only when `png_malloc_base`
        // could not satisfy the structure (`src/png.c:387-390`).
        const info = c.png_create_info_struct(raw) orelse {
            // A partial reader is not a reader: release what was created before
            // reporting, so a rejected `open` leaks nothing.
            var nothing: ?*c.png_struct = raw;
            c.png_destroy_read_struct(&nothing, null, null);
            return error.InfoStructUnavailable;
        };
        return .{ .raw = raw, .info = info };
    }

    /// Destroy the structures and everything libpng attached to them.
    ///
    /// Both fields are cleared first, so a second `deinit` on the same variable
    /// is a no-op rather than a second destroy.
    pub fn deinit(self: *Reader) void {
        const raw = self.raw orelse return;
        self.raw = null;
        self.info = null;
        var owned: ?*c.png_struct = raw;
        c.png_destroy_read_struct(&owned, null, null);
    }

    /// Whether this reader is still open.
    pub fn isOpen(self: *const Reader) bool {
        return self.raw != null;
    }

    /// The structures themselves, for anything the facade does not name.
    ///
    /// Stopping the program on a closed reader is deliberate: calling into a
    /// destroyed `png_struct` is not a condition to recover from, and the field
    /// is null precisely so that this is caught at the call rather than inside
    /// libpng.
    pub fn handle(self: *const Reader) *c.png_struct {
        return self.raw orelse @panic(
            "libpng: this Reader was closed; deinit() clears the handle and there " ++
                "is nothing left to call. Check isOpen() if the lifetime is not " ++
                "obvious.",
        );
    }

    /// The header structure, for anything the facade does not name.
    pub fn infoHandle(self: *const Reader) *c.png_info {
        return self.info orelse @panic(
            "libpng: this Reader was closed; deinit() destroys both structures.",
        );
    }

    /// Point this reader at `source`'s bytes for the next read.
    ///
    /// `png_set_read_fn` (`src/png.h:1664-1666`) stores the pointer verbatim and
    /// hands it back to the callback through `png_get_io_ptr`
    /// (`src/png.h:1669-1670`), so the callback recovers the exact `Source` the
    /// caller passed rather than a copy of its contents.
    pub fn setSource(self: *Reader, source: *Source) void {
        self.source = source;
        c.png_set_read_fn(self.handle(), @ptrCast(source), readThunk);
    }

    /// Read the header and report it.
    ///
    /// Order matters and is upstream's: the signature is checked first, through
    /// `png_sig_cmp`, because a stream that is not a PNG must be refused before
    /// any libpng state can raise. Then `png_read_info` (`src/png.h:1053-1054`)
    /// reads through to the first `IDAT`, and `png_get_IHDR`
    /// (`src/png.h:2169-2173`) copies the header fields out.
    ///
    /// A valid signature over corrupt data is not caught here: `png_read_info`
    /// ends in `png_error`, and this module does not install a jump point. See
    /// the module comment.
    pub fn readInfo(self: *Reader, source: *Source) Error!Header {
        if (!source.hasSignature()) return error.NotPng;
        self.setSource(source);
        c.png_read_info(self.handle(), self.infoHandle());

        var width: c.png_uint_32 = 0;
        var height: c.png_uint_32 = 0;
        var bit_depth: c_int = 0;
        var color_type: c_int = 0;
        var interlace: c_int = 0;
        var compression: c_int = 0;
        var filter: c_int = 0;
        // Zero means the arguments were unusable (`src/pngget.c:945-946`), which
        // for a live reader and a live info struct does not happen; it is
        // checked rather than assumed.
        if (c.png_get_IHDR(
            self.handle(),
            self.infoHandle(),
            &width,
            &height,
            &bit_depth,
            &color_type,
            &interlace,
            &compression,
            &filter,
        ) == 0) return error.HeaderMissing;

        return .{
            .width = width,
            .height = height,
            .bit_depth = bit_depth,
            .color_type = @enumFromInt(color_type),
            .interlace = @enumFromInt(interlace),
            .compression_method = compression,
            .filter_method = filter,
        };
    }

    /// The number of bytes one transformed row of this image occupies.
    ///
    /// `png_get_rowbytes` (`src/png.h:1938-1939`) returns
    /// `info_ptr->rowbytes`, or zero if either pointer is null
    /// (`src/pngget.c:40-46`). Call this after `readInfo`; before that there is
    /// no row size to report.
    pub fn rowBytes(self: *const Reader) Error!usize {
        const n = c.png_get_rowbytes(self.handle(), self.infoHandle());
        if (n == 0) return error.RowBytesUnavailable;
        return n;
    }

    /// Read every row into `rows`.
    ///
    /// `png_read_image` (`src/png.h:1445-1446`) writes one scanline into each
    /// element of the array and takes no length, so the only thing that makes
    /// this safe is that `rows` was built from *this* reader's `rowBytes`. That
    /// is checked with an ordinary comparison here, because a mismatch is a
    /// caller mistake this module can see and a release-mode debug assertion
    /// would not.
    ///
    /// `png_read_image` turns on Adam7 pass handling itself when the caller has
    /// not (`src/pngread.c:617-624`), so an interlaced image needs nothing extra
    /// from here.
    pub fn readImage(self: *Reader, rows: *const Rows) Error!void {
        const stride = try self.rowBytes();
        if (rows.fitsRow(stride) == false) return error.RowStrideMismatch;
        if (rows.height() == 0) return;
        // `png_read_image` writes through every element, so the array is passed
        // as a mutable pointer to mutable row pointers; nothing here constrains
        // it further.
        c.png_read_image(self.handle(), @constCast(rows.asPointers()));
    }

    /// Read one row into `row`.
    ///
    /// `png_read_row` (`src/png.h:1439-1440`) writes `png_get_rowbytes` bytes
    /// into `row`, and `display_row` is null here because no blending transform
    /// is installed: `src/pngread.c:546-547` says the display buffer is ignored
    /// when `png_set_interlace_handling` has not been called.
    pub fn readRow(self: *Reader, row: []u8) Error!void {
        const stride = try self.rowBytes();
        if (row.len < stride) return error.RowStrideMismatch;
        c.png_read_row(self.handle(), row.ptr, null);
    }

    /// Read the chunks that follow the image data.
    ///
    /// `png_read_end` (`src/png.h:1471-1472`) is what finishes a read; a reader
    /// that stops before it has decoded the trailing chunks, and this does not
    /// hide that.
    pub fn readEnd(self: *Reader) void {
        c.png_read_end(self.handle(), self.infoHandle());
    }

    // The callback libpng calls for bytes. It fills exactly what it was asked
    // for, because libpng treats a short read as an error
    // (`src/pngread.c` routes a short read to `png_error`), and it keeps the
    // source's own offset so successive calls continue where the last stopped.
    fn readThunk(png_ptr: c.png_structp, data: c.png_bytep, length: usize) callconv(.c) void {
        const source: *Source = @ptrCast(@alignCast(c.png_get_io_ptr(png_ptr).?));
        const available = source.bytes.len - source.offset;
        const taken = @min(available, length);
        @memcpy(data[0..taken], source.bytes[source.offset..][0..taken]);
        if (taken < length) @memset(data[taken..length], 0);
        source.offset += taken;
    }
};

/// The writing side: one `png_struct` and one `png_info`, and what destroying
/// them means.
///
/// `open` mirrors `Reader.open` and calls `png_create_write_struct_2`
/// (`src/png.h:1002-1006`) with the same arguments, so the allocator and the
/// error handler are the same for the same reasons.
pub const Writer = struct {
    /// The owned structure, or null once `deinit` has run.
    raw: ?*c.png_struct = null,
    /// The owned header, or null once `deinit` has run.
    info: ?*c.png_info = null,

    /// The `Sink` the last `writeInfo` installed, if any.
    sink: ?*Sink = null,

    /// Every way `open` can fail.
    pub const OpenError = error{ OutOfMemory, InfoStructUnavailable };

    /// Create a writer that has written nothing yet.
    ///
    /// `user_png_ver` is `PNG_LIBPNG_VER_STRING` for the reason `Reader.open`
    /// gives: `src/png.c:227-229` reports a mismatch for a null version and the
    /// create call then returns null, so this is the same fact, not a second
    /// one.
    pub fn open() OpenError!Writer {
        const raw = c.png_create_write_struct_2(
            c.PNG_LIBPNG_VER_STRING,
            null,
            null,
            null,
            null,
            libpngMallocThunk,
            libpngFreeThunk,
        ) orelse
            return error.OutOfMemory;
        const info = c.png_create_info_struct(raw) orelse {
            var nothing: ?*c.png_struct = raw;
            c.png_destroy_write_struct(&nothing, null);
            return error.InfoStructUnavailable;
        };
        return .{ .raw = raw, .info = info };
    }

    /// Destroy the structures and everything libpng attached to them.
    ///
    /// Both fields are cleared first, so a second `deinit` is a no-op.
    pub fn deinit(self: *Writer) void {
        const raw = self.raw orelse return;
        self.raw = null;
        self.info = null;
        var owned: ?*c.png_struct = raw;
        c.png_destroy_write_struct(&owned, null);
    }

    /// Whether this writer is still open.
    pub fn isOpen(self: *const Writer) bool {
        return self.raw != null;
    }

    /// The structure itself, for anything the facade does not name.
    pub fn handle(self: *const Writer) *c.png_struct {
        return self.raw orelse @panic(
            "libpng: this Writer was closed; deinit() clears the handle and there " ++
                "is nothing left to call.",
        );
    }

    /// The header structure, for anything the facade does not name.
    pub fn infoHandle(self: *const Writer) *c.png_info {
        return self.info orelse @panic(
            "libpng: this Writer was closed; deinit() destroys both structures.",
        );
    }

    /// Write the IHDR and everything libpng needs to start an image.
    ///
    /// `png_set_IHDR` (`src/png.h:2175-2179`) is a plain setter on the info
    /// struct; `png_write_info` (`src/png.h:1048-1049`) then emits every chunk
    /// the configuration demands before the image data.
    ///
    /// The compression and filter methods are upstream's own defaults,
    /// `PNG_COMPRESSION_TYPE_DEFAULT` and `PNG_FILTER_TYPE_DEFAULT`
    /// (`src/png.h:677`, `:682`), passed through unchanged rather than
    /// re-derived here.
    pub fn writeInfo(self: *Writer, sink: *Sink, header: Header) Error!void {
        self.sink = sink;
        c.png_set_write_fn(
            self.handle(),
            @ptrCast(sink),
            Sink.writeThunk,
            null,
        );
        c.png_set_IHDR(
            self.handle(),
            self.infoHandle(),
            header.width,
            header.height,
            header.bit_depth,
            header.rawColorType(),
            header.rawInterlace(),
            c.PNG_COMPRESSION_TYPE_DEFAULT,
            c.PNG_FILTER_TYPE_DEFAULT,
        );
        c.png_write_info(self.handle(), self.infoHandle());
        try self.checkSink();
    }

    /// Write one row.
    ///
    /// `png_write_row` (`src/png.h:1450-1451`) reads exactly
    /// `png_get_rowbytes` bytes from `row`. A shorter row is refused here rather
    /// than read past, because libpng takes no length and cannot check.
    pub fn writeRow(self: *Writer, row: []const u8) Error!void {
        const stride = try self.rowBytes();
        if (row.len < stride) return error.RowStrideMismatch;
        c.png_write_row(self.handle(), row.ptr);
        try self.checkSink();
    }

    /// Write every row of `rows`, top row first.
    ///
    /// `png_write_image` (`src/png.h:1462-1463`) reads one row from each element
    /// of the array, again with no length.
    pub fn writeImage(self: *Writer, rows: *const Rows) Error!void {
        const stride = try self.rowBytes();
        if (rows.fitsRow(stride) == false) return error.RowStrideMismatch;
        c.png_write_image(self.handle(), @constCast(rows.asPointers()));
        try self.checkSink();
    }

    /// Write the `IEND` chunk and any trailing chunks libpng holds.
    pub fn writeEnd(self: *Writer) Error!void {
        c.png_write_end(self.handle(), self.infoHandle());
        try self.checkSink();
    }

    /// The number of bytes one row of the image being written occupies.
    ///
    /// The same `png_get_rowbytes` as on the read side: it reads the value
    /// `png_set_IHDR` stored, and it is zero until `writeInfo` has run.
    pub fn rowBytes(self: *const Writer) Error!usize {
        const n = c.png_get_rowbytes(self.handle(), self.infoHandle());
        if (n == 0) return error.RowBytesUnavailable;
        return n;
    }

    /// The sink this writer was pointed at.
    pub fn sinkHandle(self: *const Writer) *Sink {
        return self.sink orelse @panic(
            "libpng: writeInfo() installs the sink; nothing has been written yet.",
        );
    }

    // A libpng write callback cannot fail, so the only honest place a full sink
    // can surface is here, at the next Zig-level boundary. See `Sink`.
    fn checkSink(self: *Writer) Error!void {
        if (self.sink != null and self.sink.?.hasOverflowed()) return error.SinkOverflow;
    }
};