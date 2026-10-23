// SPDX-License-Identifier: MIT
// See ../FORK-LICENSE.md for what that identifier covers.

//! Zig facade over libpng's C API.
//! `Reader` and `Writer` own their C structures; `Rows` owns its allocations.
//! Facade errors cover checked conditions; other libpng errors may longjmp.

const std = @import("std");

/// The translated libpng C API for declarations not wrapped by this facade.
/// It uses the same headers and library as the typed interface.
pub const c = @import("c");

const rt = @import("rt");

/// Whether the module uses runtime-loaded native symbols.
pub const runtime_loaded: bool = if (@hasDecl(c, "rt_runtime_loaded")) c.rt_runtime_loaded else false;

/// An explicit file path or platform-loader name for the native library.
/// The loader retains a copy of the request.
pub const LoadSource = if (runtime_loaded) c.LoadSource else rt.LoadSource;

/// Errors returned while loading a runtime provider.
pub const LoadError = if (runtime_loaded) c.LoadError else rt.LoadError;

/// Loads an explicit provider in runtime builds; linked builds panic.
/// A successful provider stays loaded for the process lifetime.
pub fn load(source: LoadSource) LoadError!void {
    // `c.load` exists only in runtime-loaded builds.
    if (runtime_loaded) return c.load(source);
    std.debug.panic(
        "libpng: load was called on a linked build; this module is not " ++
            "runtime-loaded, so there is no library to load. Build with " ++
            "runtime loading configured, or do not call load.",
        .{},
    );
}

/// Returns the retained provider request, or null in linked builds.
pub fn loadedSource() ?LoadSource {
    if (runtime_loaded) return c.loadedSource();
    return null;
}

/// Conditions the facade can detect and return; libpng longjmp errors are excluded.
pub const Error = error{
    /// A libpng read or write structure allocation failed.
    OutOfMemory,
    /// The libpng info structure allocation failed.
    InfoStructUnavailable,
    /// The input does not have the PNG signature.
    NotPng,
    /// libpng did not provide an image header.
    HeaderMissing,
    /// libpng did not provide a row stride.
    RowBytesUnavailable,
    /// A row buffer is too short or a `Rows` stride differs.
    RowStrideMismatch,
    /// The fixed output buffer dropped bytes.
    SinkOverflow,
};

/// The eight-byte PNG signature checked by `Source`.
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

/// IHDR fields reported by libpng.
pub const Header = struct {
    width: u32,
    height: u32,
    bit_depth: c_int,
    color_type: ColorType,
    interlace: Interlace,
    compression_method: c_int,
    filter_method: c_int,

    /// The colour type as the raw C integer.
    pub fn rawColorType(self: Header) c_int {
        return @intFromEnum(self.color_type);
    }

    /// The interlace method as the raw C integer.
    pub fn rawInterlace(self: Header) c_int {
        return @intFromEnum(self.interlace);
    }
};

/// Borrowed PNG input bytes and the current read offset.
/// The caller must keep the byte slice alive during each read.
pub const Source = struct {
    bytes: []const u8,
    offset: usize = 0,

    pub fn init(bytes: []const u8) Source {
        return .{ .bytes = bytes };
    }

    /// Checks the PNG signature with libpng; shorter input returns false.
    pub fn hasSignature(self: Source) bool {
        if (self.bytes.len < signature.len) return false;
        return c.png_sig_cmp(self.bytes.ptr, 0, signature.len) == 0;
    }
};

/// Fixed caller-owned output storage; overflow is recorded, not returned from C.
/// Writer methods report `SinkOverflow`; the retained prefix may be incomplete.
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

    /// Appends as much as fits, returns accepted length, and records dropped bytes.
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

    // libpng's callback cannot fail; report short writes at the next Zig call.
    fn writeThunk(png_ptr: c.png_structp, data: c.png_bytep, length: usize) callconv(.c) void {
        const sink: *Sink = @ptrCast(@alignCast(c.png_get_io_ptr(png_ptr).?));
        _ = sink.append(data[0..length]);
    }
};

/// Row storage owned by this value and passed to libpng's image APIs.
/// Rows use the exact transformed stride; `deinit` frees both allocations.
pub const Rows = struct {
    allocator: std.mem.Allocator,
    /// One contiguous allocation, `height * row_bytes` bytes, top row first.
    storage: []u8,
    /// One row pointer per row, in the same order as `storage`.
    pointers: []c.png_bytep,
    row_bytes: usize,

    /// Allocates exact-stride rows owned by the returned value.
    /// Errors: `RowBytesUnavailable`, `RowStrideMismatch`, or `OutOfMemory`.
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

    /// Returns the row-pointer array required by libpng's image APIs.
    pub fn asPointers(self: *const Rows) c.png_bytepp {
        return self.pointers.ptr;
    }

    /// Whether `len` equals this image's row stride.
    pub fn fitsRow(self: *const Rows, len: usize) bool {
        return len == self.row_bytes;
    }
};

/// libpng structures inherit 16-byte `jmp_buf` alignment on powerpc64-musl (`src/pngstruct.h:125`).
const libpng_alignment: std.mem.Alignment = .@"16";

/// Bookkeeping stored immediately before the pointer given to libpng.
const AllocHeader = struct {
    /// The pointer the C allocator returned, which is what must be freed.
    base: ?*anyopaque,
};

/// Supplies aligned blocks and records the original C pointer for `free_fn`.
fn libpngMallocThunk(png_ptr: c.png_structp, size: c.png_alloc_size_t) callconv(.c) ?*anyopaque {
    _ = png_ptr;
    const wanted: usize = @intCast(size);
    // Keep the checked addition even though libpng caps allocation size first.
    const slack = libpng_alignment.toByteUnits() + @sizeOf(AllocHeader);
    const total = std.math.add(usize, wanted, slack) catch return null;
    const base = std.c.malloc(total) orelse return null;
    const base_addr = @intFromPtr(base) + @sizeOf(AllocHeader);
    const aligned = std.mem.alignForward(usize, base_addr, libpng_alignment.toByteUnits());
    const header: *AllocHeader = @ptrFromInt(aligned - @sizeOf(AllocHeader));
    header.base = base;
    return @ptrFromInt(aligned);
}

/// Frees the original C allocation saved by `libpngMallocThunk`.
fn libpngFreeThunk(png_ptr: c.png_structp, ptr: ?*anyopaque) callconv(.c) void {
    _ = png_ptr;
    const raw = ptr orelse return;
    const header: *AllocHeader = @ptrFromInt(@intFromPtr(raw) - @sizeOf(AllocHeader));
    const base = header.base orelse return;
    header.base = null;
    std.c.free(base);
}

/// Owns libpng's read and info structures; release them with `deinit`.
/// Malformed image data may longjmp inside libpng instead of returning `Error`.
pub const Reader = struct {
    /// The owned structure, or null once `deinit` has run.
    raw: ?*c.png_struct = null,
    /// The owned header, or null once `deinit` has run.
    info: ?*c.png_info = null,

    /// The `Source` the last `setSource` installed, if any.
    source: ?*Source = null,

    /// Errors returned while creating the reader's libpng structures.
    pub const OpenError = error{ OutOfMemory, InfoStructUnavailable };

    /// Creates a reader that owns its libpng read and info structures.
    /// Errors: `OutOfMemory` or `InfoStructUnavailable`.
    pub fn open() OpenError!Reader {
        // Null means allocation failed; the version check passed above.
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
        // A null info pointer means its allocation failed.
        const info = c.png_create_info_struct(raw) orelse {
            // Destroy the partial reader before returning the error.
            var nothing: ?*c.png_struct = raw;
            c.png_destroy_read_struct(&nothing, null, null);
            return error.InfoStructUnavailable;
        };
        return .{ .raw = raw, .info = info };
    }

    /// Destroys both owned structures; a second call on the same value is safe.
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

    /// Returns the live libpng structure; panics after `deinit`.
    pub fn handle(self: *const Reader) *c.png_struct {
        return self.raw orelse @panic(
            "libpng: this Reader was closed; deinit() clears the handle and there " ++
                "is nothing left to call. Check isOpen() if the lifetime is not " ++
                "obvious.",
        );
    }

    /// Returns the owned `png_info` structure; panics after `deinit`.
    pub fn infoHandle(self: *const Reader) *c.png_info {
        return self.info orelse @panic(
            "libpng: this Reader was closed; deinit() destroys both structures.",
        );
    }

    /// Sets the borrowed source for subsequent reads; it must outlive each call.
    pub fn setSource(self: *Reader, source: *Source) void {
        self.source = source;
        c.png_set_read_fn(self.handle(), @ptrCast(source), readThunk);
    }

    /// Reads the header, returning facade errors such as `NotPng` or `HeaderMissing`.
    /// Malformed data may longjmp inside libpng instead of returning an error.
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
        // Check libpng's zero-on-unavailable header result.
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

    /// Returns the transformed row stride; errors if libpng reports zero.
    pub fn rowBytes(self: *const Reader) Error!usize {
        const n = c.png_get_rowbytes(self.handle(), self.infoHandle());
        if (n == 0) return error.RowBytesUnavailable;
        return n;
    }

    /// Reads every row into storage with this reader's exact stride.
    /// Returns `RowStrideMismatch` when the row size differs.
    pub fn readImage(self: *Reader, rows: *const Rows) Error!void {
        const stride = try self.rowBytes();
        if (rows.fitsRow(stride) == false) return error.RowStrideMismatch;
        if (rows.height() == 0) return;
        // libpng writes through each mutable row pointer.
        c.png_read_image(self.handle(), @constCast(rows.asPointers()));
    }

    /// Reads one row; a buffer shorter than `rowBytes` returns `RowStrideMismatch`.
    pub fn readRow(self: *Reader, row: []u8) Error!void {
        const stride = try self.rowBytes();
        if (row.len < stride) return error.RowStrideMismatch;
        c.png_read_row(self.handle(), row.ptr, null);
    }

    /// Reads trailing chunks; malformed data may longjmp inside libpng.
    pub fn readEnd(self: *Reader) void {
        c.png_read_end(self.handle(), self.infoHandle());
    }

    // Fills libpng's request from the source; short input follows its error path.
    fn readThunk(png_ptr: c.png_structp, data: c.png_bytep, length: usize) callconv(.c) void {
        const source: *Source = @ptrCast(@alignCast(c.png_get_io_ptr(png_ptr).?));
        const available = source.bytes.len - source.offset;
        const taken = @min(available, length);
        @memcpy(data[0..taken], source.bytes[source.offset..][0..taken]);
        if (taken < length) @memset(data[taken..length], 0);
        source.offset += taken;
    }
};

/// Owns libpng's write and info structures; release them with `deinit`.
pub const Writer = struct {
    /// The owned structure, or null once `deinit` has run.
    raw: ?*c.png_struct = null,
    /// The owned header, or null once `deinit` has run.
    info: ?*c.png_info = null,

    /// The `Sink` the last `writeInfo` installed, if any.
    sink: ?*Sink = null,

    /// Errors returned while creating the writer's libpng structures.
    pub const OpenError = error{ OutOfMemory, InfoStructUnavailable };

    /// Creates a writer that owns its libpng write and info structures.
    /// Errors: `OutOfMemory` or `InfoStructUnavailable`.
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

    /// Destroys both owned structures; a second call on the same value is safe.
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

    /// Returns the live libpng structure; panics after `deinit`.
    pub fn handle(self: *const Writer) *c.png_struct {
        return self.raw orelse @panic(
            "libpng: this Writer was closed; deinit() clears the handle and there " ++
                "is nothing left to call.",
        );
    }

    /// Returns the owned `png_info` structure; panics after `deinit`.
    pub fn infoHandle(self: *const Writer) *c.png_info {
        return self.info orelse @panic(
            "libpng: this Writer was closed; deinit() destroys both structures.",
        );
    }

    /// Writes the image header and installs the caller-owned output sink.
    /// Later writer methods can return `SinkOverflow`.
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

    /// Writes one row; a short buffer returns `RowStrideMismatch`.
    pub fn writeRow(self: *Writer, row: []const u8) Error!void {
        const stride = try self.rowBytes();
        if (row.len < stride) return error.RowStrideMismatch;
        c.png_write_row(self.handle(), row.ptr);
        try self.checkSink();
    }

    /// Writes all rows; their stride must match this writer's `rowBytes`.
    pub fn writeImage(self: *Writer, rows: *const Rows) Error!void {
        const stride = try self.rowBytes();
        if (rows.fitsRow(stride) == false) return error.RowStrideMismatch;
        c.png_write_image(self.handle(), @constCast(rows.asPointers()));
        try self.checkSink();
    }

    /// Writes trailing chunks and reports `SinkOverflow` if bytes were dropped.
    pub fn writeEnd(self: *Writer) Error!void {
        c.png_write_end(self.handle(), self.infoHandle());
        try self.checkSink();
    }

    /// Returns the transformed row stride after `writeInfo`; zero is an error.
    pub fn rowBytes(self: *const Writer) Error!usize {
        const n = c.png_get_rowbytes(self.handle(), self.infoHandle());
        if (n == 0) return error.RowBytesUnavailable;
        return n;
    }

    /// Returns the caller-owned sink; panics before `writeInfo`.
    pub fn sinkHandle(self: *const Writer) *Sink {
        return self.sink orelse @panic(
            "libpng: writeInfo() installs the sink; nothing has been written yet.",
        );
    }

    // The callback cannot fail; report recorded overflow at this Zig boundary.
    fn checkSink(self: *Writer) Error!void {
        if (self.sink != null and self.sink.?.hasOverflowed()) return error.SinkOverflow;
    }
};
