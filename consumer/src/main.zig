// SPDX-License-Identifier: MIT
// See ../FORK-LICENSE.md for what that identifier covers.

//! End-to-end consumer for the published libpng dependency.
//! Checks fixture bytes, decoded pixels, encoding, and documented error boundaries.

const std = @import("std");
const libpng = @import("libpng");

/// Runtime-loaded builds require an explicit provider.
const ConfigurationError = error{NoProviderConfigured};

/// Selects the provider from `--provider <path>` or `LIBPNG_TEST_PROVIDER`.
/// No implicit search or fallback is performed.
fn providerRequest(init: std.process.Init) ConfigurationError![]const u8 {
    const args = init.minimal.args.toSlice(init.arena.allocator()) catch
        return noProvider();
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        if (std.mem.eql(u8, args[index], "--provider")) {
            if (index + 1 >= args.len) return noProvider();
            return args[index + 1];
        }
    }
    return init.environ_map.get("LIBPNG_TEST_PROVIDER") orelse
        return noProvider();
}

fn noProvider() ConfigurationError {
    std.debug.print(
        "consumer: this is a runtime-loading build. Pass --provider <path>, or " ++
            "export LIBPNG_TEST_PROVIDER with a shared object exporting the png_* " ++
            "names of zig/translate.h. Nothing is loaded by default and no other " ++
            "file is tried.\n",
        .{},
    );
    return error.NoProviderConfigured;
}

fn label(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) []const u8 {
    return allocator.print(fmt, args) catch @panic("OOM");
}

/// Embedded greyscale fixture with an independently recorded digest.
const grey8x8_200_png =
    "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52" ++
    "\x00\x00\x00\x08\x00\x00\x00\x08\x08\x00\x00\x00\x00\xE1\x64\xE1" ++
    "\x57\x00\x00\x00\x0E\x49\x44\x41\x54\x78\xDA\x63\x38\x01\x05\x0C" ++
    "\x94\x31\x00\x08\xB1\x32\x01\xB5\xC0\xAB\x65\x00\x00\x00\x00\x49" ++
    "\x45\x4E\x44\xAE\x42\x60\x82";

/// RGB fixture with nontrivial samples and an independently recorded digest.
const rgb4x3_png =
    "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52" ++
    "\x00\x00\x00\x04\x00\x00\x00\x03\x08\x02\x00\x00\x00\x3B\x96\x39" ++
    "\x91\x00\x00\x00\x28\x49\x44\x41\x54\x78\xDA\x63\x60\x60\x60\xF8" ++
    "\x0F\xC3\x8C\xFF\xFF\xFF\x6F\x6C\x6C\xAC\xAF\x6F\x60\x04\x0A\x30" ++
    "\x32\x31\x73\x89\xC8\x9D\x48\x31\x62\xFF\xCF\x00\x00\xF8\xC3\x0C" ++
    "\xA3\x53\x7F\x0C\x57\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60" ++
    "\x82";

/// RGBA fixture with transparent, midpoint, and opaque alpha values.
const rgba2x2_png =
    "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52" ++
    "\x00\x00\x00\x02\x00\x00\x00\x02\x08\x06\x00\x00\x00\x72\xB6\x0D" ++
    "\x24\x00\x00\x00\x17\x49\x44\x41\x54\x78\xDA\x63\x64\x00\x82\xFF" ++
    "\x0C\x0C\x0E\x8C\x40\xB2\x81\x81\xF1\x7F\x3D\x00\x1B\x99\x04\x40" ++
    "\x09\x68\x4A\xA8\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82";

/// Fixture metadata and specification-derived expectations.
const Declared = struct {
    name: []const u8,
    bytes: []const u8,
    sha256: []const u8,
    length: usize,
    width: u32,
    height: u32,
    bit_depth: c_int,
    color_type: libpng.ColorType,
    interlace: libpng.Interlace,
    /// Expected unpadded row size from width, depth, and channel count.
    row_bytes: usize,
    pixels: []const u8,
};

const grey8x8_200_pixels: [64]u8 = @splat(200);

const declared = [_]Declared{
    .{
        .name = "grey8x8-200.png",
        .bytes = grey8x8_200_png,
        .sha256 = "4cd467a6c469e7890696808a829808d1137a991a8f6a55c9113339853272a283",
        .length = 71,
        .width = 8,
        .height = 8,
        .bit_depth = 8,
        .color_type = .greyscale,
        .interlace = .none,
        .row_bytes = 8,
        .pixels = &grey8x8_200_pixels,
    },
    .{
        .name = "rgb4x3.png",
        .bytes = rgb4x3_png,
        .sha256 = "a37878d39ff5765cfa4cee3cd7d9723b3cb761e65ae0d9f3f0873ff96adf44ff",
        .length = 97,
        .width = 4,
        .height = 3,
        .bit_depth = 8,
        .color_type = .rgb,
        .interlace = .none,
        .row_bytes = 12,
        .pixels = &.{
            0,   0,   0,   255, 0,   0,   0,   255, 0,   0,   0,   255,
            255, 255, 255, 128, 128, 128, 255, 255, 0,   0,   255, 255,
            1,   2,   3,   10,  20,  30,  200, 100, 50,  7,   255, 0,
        },
    },
    .{
        .name = "rgba2x2.png",
        .bytes = rgba2x2_png,
        .sha256 = "3c5f2d8cdf5195958619e1ff666f9a2fb439863996996e2de09f54b15f512ba9",
        .length = 80,
        .width = 2,
        .height = 2,
        .bit_depth = 8,
        .color_type = .rgba,
        .interlace = .none,
        .row_bytes = 8,
        .pixels = &.{
            0,   0,   0,   0,   255, 0,   0,   64,
            0,   255, 0,   128, 0,   0,   255, 255,
        },
    },
};

// ISO/IEC 15948 colour-type codes, independent of the facade enum.
const png_color_type_greyscale: u8 = 0;
const png_color_type_rgb: u8 = 2;
const png_color_type_rgba: u8 = 6;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();

    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(io, &buffer);
    const w = &stdout.interface;

    if (comptime libpng.runtime_loaded) {
        try libpng.load(.{ .path = try providerRequest(init) });
    }

    try w.print("libpng consumer\n", .{});
    try w.print("{s} provider\n", .{
        if (libpng.runtime_loaded) "loaded" else "linked",
    });

    // Check both provider-reported version values through the public raw module;
    // generated constants alone do not prove which provider loaded.
    try w.print("png_access_version_number {d}\n", .{
        libpng.c.png_access_version_number(),
    });
    try w.print("png_get_libpng_ver {s}\n", .{
        std.mem.span(libpng.c.png_get_libpng_ver(null)),
    });
    try checkInt(w, "the provider reports libpng 1.6.59", libpng.c.png_access_version_number(), 10659);

    inline for (declared) |fixture| {
        try checkDigest(w, fixture);
        try checkContainer(w, allocator, fixture);
        try checkPixels(w, allocator, fixture);
    }

    // The writing side, and the three boundaries the facade documents. A
    // program that only ever succeeds proves nothing about them.
    try checkWrite(w, allocator);
    try checkErrorPaths(w, allocator);

    try w.print("every answer matched the specification\n", .{});
    try w.flush();
}

fn checkDigest(w: *std.Io.Writer, comptime fixture: Declared) !void {
    // Zig 0.16 re-exports SHA-256 as `std.crypto.hash.sha2`.
    const Sha256 = std.crypto.hash.sha2.Sha256;
    var digest: [Sha256.digest_length]u8 = undefined;
    Sha256.hash(fixture.bytes, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    try checkString(w, fixture.name ++ " sha256", &hex, fixture.sha256);
    try checkInt(w, fixture.name ++ " byte length", fixture.bytes.len, fixture.length);
}

/// Parsed chunk data and the declared and recomputed CRC values.
const Chunk = struct {
    kind: []const u8,
    data: []const u8,
    /// CRC carried by the file.
    declared: u32,
    /// CRC recomputed over the type and data.
    computed: u32,
};

/// Parses the PNG chunk stream and returns its records.
fn parseChunks(bytes: []const u8, out: []Chunk) ![]Chunk {
    if (bytes.len < libpng.signature.len) return error.Truncated;
    for (libpng.signature, 0..) |byte, i| {
        if (bytes[i] != byte) return error.NotASignature;
    }
    var at: usize = libpng.signature.len;
    var count: usize = 0;
    while (at < bytes.len) {
        if (at + 8 > bytes.len) return error.TruncatedChunkHeader;
        const length = std.mem.readInt(u32, bytes[at..][0..4], .big);
        const kind = bytes[at + 4 ..][0..4];
        const data_start = at + 8;
        const data_end = data_start + length;
        if (data_end + 4 > bytes.len) return error.TruncatedChunkData;
        const data = bytes[data_start..data_end];
        const computed = std.hash.crc.@"CRC-32/ISO-HDLC".hash(bytes[at + 4 ..][0 .. 4 + length]);
        const declared_crc = std.mem.readInt(u32, bytes[data_end..][0..4], .big);
        if (count == out.len) return error.TooManyChunks;
        out[count] = .{
            .kind = kind,
            .data = data,
            .declared = declared_crc,
            .computed = computed,
        };
        count += 1;
        at = data_end + 4;
        if (std.mem.eql(u8, kind, "IEND")) break;
    }
    return out[0..count];
}

fn checkContainer(w: *std.Io.Writer, allocator: std.mem.Allocator, comptime fixture: Declared) !void {
    var storage: [8]Chunk = undefined;
    const chunks = try parseChunks(fixture.bytes, &storage);

    // ISO/IEC 15948 §5.6 defines IHDR's 13-byte field order.
    try checkString(w, fixture.name ++ ": first chunk", chunks[0].kind, "IHDR");
    try checkInt(w, fixture.name ++ ": IHDR length", chunks[0].data.len, 13);

    // Read fields directly from bytes, independent of the decoder.
    try checkInt(w, fixture.name ++ ": IHDR width", std.mem.readInt(u32, chunks[0].data[0..4], .big), fixture.width);
    try checkInt(w, fixture.name ++ ": IHDR height", std.mem.readInt(u32, chunks[0].data[4..8], .big), fixture.height);
    try checkInt(w, fixture.name ++ ": IHDR bit depth", chunks[0].data[8], @as(u8, @intCast(fixture.bit_depth)));
    try checkInt(w, fixture.name ++ ": IHDR colour type", chunks[0].data[9], switch (fixture.color_type) {
        .greyscale => png_color_type_greyscale,
        .rgb => png_color_type_rgb,
        .rgba => png_color_type_rgba,
        // Unsupported fixture colour types fail at compile time.
        .greyscale_alpha, .indexed => @compileError("no fixture declares this colour type"),
    });
    // ISO/IEC 15948 defines only compression and filter method zero.
    try checkInt(w, fixture.name ++ ": IHDR compression method", chunks[0].data[10], 0);
    try checkInt(w, fixture.name ++ ": IHDR filter method", chunks[0].data[11], 0);
    try checkInt(w, fixture.name ++ ": IHDR interlace method", chunks[0].data[12], 0);

    // §5.5: every chunk's CRC is over its type and data.
    for (chunks) |chunk| {
        try checkInt(
            w,
            // `label` builds a runtime string from the parsed chunk type.
            label(allocator, "{s}: {s} CRC-32", .{ fixture.name, chunk.kind }),
            chunk.declared,
            chunk.computed,
        );
    }

    // §5.3: the stream is IHDR, IDAT (one or more) and IEND, in that order.
    try checkString(w, fixture.name ++ ": last chunk", chunks[chunks.len - 1].kind, "IEND");
    try checkInt(w, fixture.name ++ ": IEND is empty", chunks[chunks.len - 1].data.len, 0);
    var idat: usize = 0;
    for (chunks[1 .. chunks.len - 1]) |chunk| {
        try checkString(w, fixture.name ++ ": middle chunk", chunk.kind, "IDAT");
        idat += 1;
    }
    try checkInt(w, fixture.name ++ ": IDAT chunk count", idat, 1);
}

fn checkPixels(w: *std.Io.Writer, allocator: std.mem.Allocator, comptime fixture: Declared) !void {
    var source = libpng.Source.init(fixture.bytes);
    try checkInt(
        w,
        fixture.name ++ ": png_sig_cmp accepts it",
        @intFromBool(source.hasSignature()),
        1,
    );

    var reader = try libpng.Reader.open();
    defer reader.deinit();
    try checkInt(w, fixture.name ++ ": the reader is open", @intFromBool(reader.isOpen()), 1);

    const header = try reader.readInfo(&source);
    try checkInt(w, fixture.name ++ ": width", header.width, fixture.width);
    try checkInt(w, fixture.name ++ ": height", header.height, fixture.height);
    try checkInt(w, fixture.name ++ ": bit depth", header.bit_depth, fixture.bit_depth);
    try checkInt(w, fixture.name ++ ": colour type", @backingInt(header.color_type), @backingInt(fixture.color_type));
    try checkInt(w, fixture.name ++ ": interlace", @backingInt(header.interlace), @backingInt(fixture.interlace));

    // At 8-bit depth, row bytes are width times channels with no padding.
    try checkInt(w, fixture.name ++ ": png_get_rowbytes", try reader.rowBytes(), fixture.row_bytes);

    var rows = try libpng.Rows.alloc(allocator, fixture.height, fixture.row_bytes);
    defer rows.deinit();
    try reader.readImage(&rows);
    reader.readEnd();

    try checkInt(w, fixture.name ++ ": row count", rows.height(), fixture.height);
    for (0..fixture.height) |y| {
        try checkBytes(
            w,
            label(allocator, "{s}: row {d}", .{ fixture.name, y }),
            rows.slice(y),
            fixture.pixels[y * fixture.row_bytes ..][0..fixture.row_bytes],
        );
    }
}

fn checkWrite(w: *std.Io.Writer, allocator: std.mem.Allocator) !void {
    // Encode the RGB fixture, then validate the output from its PNG bytes.
    const fixture = declared[1];

    // Keep the buffer large so the separate overflow check measures the limit.
    var storage: [4096]u8 = undefined;
    var sink = libpng.Sink.init(&storage);

    var writer = try libpng.Writer.open();
    defer writer.deinit();
    try writer.writeInfo(&sink, .{
        .width = fixture.width,
        .height = fixture.height,
        .bit_depth = fixture.bit_depth,
        .color_type = fixture.color_type,
        .interlace = fixture.interlace,
        .compression_method = 0,
        .filter_method = 0,
    });
    try checkInt(w, "encoded: png_get_rowbytes on the writer", try writer.rowBytes(), fixture.row_bytes);

    var rows = try libpng.Rows.alloc(allocator, fixture.height, fixture.row_bytes);
    defer rows.deinit();
    for (0..fixture.height) |y| {
        @memcpy(rows.slice(y), fixture.pixels[y * fixture.row_bytes ..][0..fixture.row_bytes]);
    }
    try writer.writeImage(&rows);
    try writer.writeEnd();

    try checkInt(w, "encoded: the sink never overflowed", @intFromBool(sink.hasOverflowed()), 0);
    const produced = sink.written();
    try checkInt(w, "encoded: the PNG signature", @intFromBool(std.mem.eql(u8, produced[0..libpng.signature.len], &libpng.signature)), 1);

    var chunk_storage: [8]Chunk = undefined;
    const chunks = try parseChunks(produced, &chunk_storage);
    try checkString(w, "encoded: first chunk", chunks[0].kind, "IHDR");
    try checkInt(w, "encoded: IHDR length", chunks[0].data.len, 13);
    try checkInt(w, "encoded: IHDR width", std.mem.readInt(u32, chunks[0].data[0..4], .big), fixture.width);
    try checkInt(w, "encoded: IHDR height", std.mem.readInt(u32, chunks[0].data[4..8], .big), fixture.height);
    try checkInt(w, "encoded: IHDR colour type", chunks[0].data[9], png_color_type_rgb);
    for (chunks) |chunk| {
        try checkInt(
            w,
            label(allocator, "encoded: {s} CRC-32", .{chunk.kind}),
            chunk.declared,
            chunk.computed,
        );
    }

    // Independent expected pixels prevent encoder/decoder agreement from masking errors.
    var source = libpng.Source.init(produced);
    var reader = try libpng.Reader.open();
    defer reader.deinit();
    const header = try reader.readInfo(&source);
    try checkInt(w, "round trip: width", header.width, fixture.width);
    try checkInt(w, "round trip: height", header.height, fixture.height);
    var back = try libpng.Rows.alloc(allocator, header.height, try reader.rowBytes());
    defer back.deinit();
    try reader.readImage(&back);
    reader.readEnd();
    for (0..fixture.height) |y| {
        try checkBytes(
            w,
            label(allocator, "round trip: row {d}", .{y}),
            back.slice(y),
            fixture.pixels[y * fixture.row_bytes ..][0..fixture.row_bytes],
        );
    }
}

fn checkErrorPaths(w: *std.Io.Writer, allocator: std.mem.Allocator) !void {
    // A non-PNG signature is rejected before libpng state exists.
    var not_png = libpng.Source.init("this is not a PNG file, it is only text\x00\xff");
    try checkInt(w, "a non-PNG source has no signature", @intFromBool(not_png.hasSignature()), 0);
    var reader = try libpng.Reader.open();
    defer reader.deinit();
    try checkError(w, "readInfo refuses a non-PNG", reader.readInfo(&not_png) == error.NotPng);

    // `png_sig_cmp` compares only the bytes it receives.
    var short = libpng.Source.init(libpng.signature[0..7]);
    try checkInt(w, "seven signature bytes are not a signature", @intFromBool(short.hasSignature()), 0);

    // Reject a mismatched row stride before C writes through an unchecked pointer.
    // libpng's `png_read_image` receives no buffer length.
    var source = libpng.Source.init(rgb4x3_png);
    var stride_reader = try libpng.Reader.open();
    defer stride_reader.deinit();
    _ = try stride_reader.readInfo(&source);
    var wrong = try libpng.Rows.alloc(allocator, 3, 11);
    defer wrong.deinit();
    try checkError(
        w,
        "a row buffer one byte short per row is refused",
        stride_reader.readImage(&wrong) == error.RowStrideMismatch,
    );

    // The void write callback cannot report overflow; the facade surfaces it at
    // the next Zig boundary and marks the truncated bytes invalid.
    // 64 bytes lets `writeInfo` finish so overflow occurs during image data.
    var tiny: [64]u8 = undefined;
    var tiny_sink = libpng.Sink.init(&tiny);
    var overflowing = try libpng.Writer.open();
    defer overflowing.deinit();
    try overflowing.writeInfo(&tiny_sink, .{
        .width = 4,
        .height = 3,
        .bit_depth = 8,
        .color_type = .rgb,
        .interlace = .none,
        .compression_method = 0,
        .filter_method = 0,
    });
    try checkInt(w, "a 64-byte sink holds the header", @intFromBool(tiny_sink.hasOverflowed()), 0);
    var rows = try libpng.Rows.alloc(allocator, 3, 12);
    defer rows.deinit();
    @memset(rows.storage, 0xA5);
    try checkError(
        w,
        "a sink that fills reports SinkOverflow",
        overflowing.writeImage(&rows) == error.SinkOverflow,
    );
    try checkInt(w, "the full sink says so", @intFromBool(tiny_sink.hasOverflowed()), 1);
    try checkInt(w, "the full sink kept exactly what it had", tiny_sink.len, 64);

    // `deinit` clears the handle, making repeated calls harmless.
    overflowing.deinit();
    try checkInt(w, "deinit closes the writer", @intFromBool(overflowing.isOpen()), 0);
}

fn checkInt(w: *std.Io.Writer, what: []const u8, got: anytype, expected: anytype) !void {
    try w.print("{s: <56}{d}\n", .{ what, got });
    if (got != expected) {
        std.debug.print("consumer: {s}: expected {d}, computed {d}\n", .{ what, expected, got });
        return error.ConsumerCheckFailed;
    }
}

fn checkString(w: *std.Io.Writer, what: []const u8, got: []const u8, expected: []const u8) !void {
    try w.print("{s: <56}{s}\n", .{ what, got });
    if (!std.mem.eql(u8, got, expected)) {
        std.debug.print("consumer: {s}: expected \"{s}\", computed \"{s}\"\n", .{
            what,
            expected,
            got,
        });
        return error.ConsumerCheckFailed;
    }
}

fn checkBytes(w: *std.Io.Writer, what: []const u8, got: []const u8, expected: []const u8) !void {
    try w.print("{s: <56}{x}\n", .{ what, got });
    if (!std.mem.eql(u8, got, expected)) {
        std.debug.print("consumer: {s}: expected {x}, computed {x}\n", .{
            what,
            expected,
            got,
        });
        return error.ConsumerCheckFailed;
    }
}

fn checkError(w: *std.Io.Writer, what: []const u8, got: bool) !void {
    try w.print("{s: <56}{s}\n", .{ what, if (got) "yes" else "no" });
    if (!got) {
        std.debug.print("consumer: {s}: the documented error was not reported\n", .{what});
        return error.ConsumerCheckFailed;
    }
}
