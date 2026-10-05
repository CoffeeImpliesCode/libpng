// SPDX-License-Identifier: MIT
// See ../FORK-LICENSE.md for what that identifier covers.

//! Consumes the `libpng` package the way an outside project would.
//!
//! Everything here goes through the published surface only: `dep.module` in
//! `build.zig`, and `@import("libpng")` here. No path reaches into the library's
//! own tree and no file is read at run time, so if this builds and produces the
//! answers below, the module contract is real: the typed facade, the translated
//! headers it re-exports as `c`, and the native library behind both arrived
//! through one dependency line.
//!
//! ## The answers are not this code talking to itself
//!
//! A round trip proves only that the two halves agree. Every check below is
//! stated against a value from outside the library:
//!
//!   * **The container.** ISO/IEC 15948 is parsed *by this program*, from the
//!     fixture bytes alone: the eight-byte signature of §5.1, the chunk framing
//!     of §5.3, the CRC-32 of §5.5 over each chunk's type and data, and the
//!     13-byte IHDR payload layout of §5.6. None of that goes through libpng, so
//!     a decoder that agreed with itself about a malformed file would still fail
//!     here.
//!   * **The pixels.** The expected samples are the ones
//!     `../tools/make-fixtures.py` states in decimal, written out of ISO/IEC
//!     15948's filter definitions rather than out of any decoder.
//!   * **The bytes.** Each fixture's SHA-256 and byte length, as
//!     `../tools/check-fixtures.py`, `../UPSTREAM.md` and `../CHANGELOG.md` all
//!     record them. This program recomputes both from the bytes it was given, so
//!     a fixture edited underneath the tests becomes a failure instead of a
//!     weakened check.
//!
//! The same source builds against a linked package and against a
//! runtime-loaded one. `libpng.runtime_loaded` is a comptime constant, so the
//! difference is one branch and no duplicated program: in the runtime-loaded
//! build the provider is named on the command line (`--provider <path>`) or in
//! `LIBPNG_TEST_PROVIDER`, loaded once, and the same answers follow.

const std = @import("std");
const libpng = @import("libpng");

/// A runtime-loading build has no provider until one is named.
const ConfigurationError = error{NoProviderConfigured};

/// The provider this run should load, from `--provider <path>` or from
/// `LIBPNG_TEST_PROVIDER`.
///
/// Both are explicit. Nothing here looks in a default location, and a build
/// that was not told which file to load says so rather than loading something
/// else.
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

/// Say which variable is missing. An error name on its own would send the next
/// person into the loader instead of to the command line.
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

/// A line label built for one diagnostic. Nothing freed: `main` allocates this
/// from the process arena, and a check that is about to fail does not need its
/// own bookkeeping.
fn label(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) []const u8 {
    return std.fmt.allocPrint(allocator, fmt, args) catch @panic("OOM");
}

// ---------------------------------------------------------------------------
// The fixtures, and the digests this repository records for them
// ---------------------------------------------------------------------------

/// `fixtures/grey8x8-200.png`: 8x8, 8-bit greyscale, one flat block of 200.
///
/// The same 71 bytes the fixture file holds, embedded rather than read from a
/// path: a gate that depends on a working directory can pass for the wrong
/// reason. `sha256` and `length` are `tools/check-fixtures.py:41-45`.
const grey8x8_200_png =
    "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52" ++
    "\x00\x00\x00\x08\x00\x00\x00\x08\x08\x00\x00\x00\x00\xE1\x64\xE1" ++
    "\x57\x00\x00\x00\x0E\x49\x44\x41\x54\x78\xDA\x63\x38\x01\x05\x0C" ++
    "\x94\x31\x00\x08\xB1\x32\x01\xB5\xC0\xAB\x65\x00\x00\x00\x00\x49" ++
    "\x45\x4E\x44\xAE\x42\x60\x82";

/// `fixtures/rgb4x3.png`: 4x3, 8-bit truecolour, the rows written out in full in
/// `tools/make-fixtures.py:163-167`. Row 2 is four arbitrary triples that are
/// neither 0 nor 255, so a decoder that clamped, truncated or rounded
/// differently would be caught. `sha256` and `length` are
/// `tools/check-fixtures.py:46-50`.
const rgb4x3_png =
    "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52" ++
    "\x00\x00\x00\x04\x00\x00\x00\x03\x08\x02\x00\x00\x00\x3B\x96\x39" ++
    "\x91\x00\x00\x00\x28\x49\x44\x41\x54\x78\xDA\x63\x60\x60\x60\xF8" ++
    "\x0F\xC3\x8C\xFF\xFF\xFF\x6F\x6C\x6C\xAC\xAF\x6F\x60\x04\x0A\x30" ++
    "\x32\x31\x73\x89\xC8\x9D\x48\x31\x62\xFF\xCF\x00\x00\xF8\xC3\x0C" ++
    "\xA3\x53\x7F\x0C\x57\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60" ++
    "\x82";

/// `fixtures/rgba2x2.png`: 2x2, 8-bit truecolour with alpha, the rows in
/// `tools/make-fixtures.py:177-180`. Alpha covers both ends of the range and
/// both midpoints, and one pixel is fully transparent. `sha256` and `length`
/// are `tools/check-fixtures.py:51-55`.
const rgba2x2_png =
    "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52" ++
    "\x00\x00\x00\x02\x00\x00\x00\x02\x08\x06\x00\x00\x00\x72\xB6\x0D" ++
    "\x24\x00\x00\x00\x17\x49\x44\x41\x54\x78\xDA\x63\x64\x00\x82\xFF" ++
    "\x0C\x0C\x0E\x8C\x40\xB2\x81\x81\xF1\x7F\x3D\x00\x1B\x99\x04\x40" ++
    "\x09\x68\x4A\xA8\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82";

/// One fixture's declared shape, as ISO/IEC 15948 states it.
///
/// These are the numbers a consumer writes down from the specification before
/// running anything. None of them is read back out of a decode.
const Declared = struct {
    name: []const u8,
    /// The file, byte for byte.
    bytes: []const u8,
    /// Its SHA-256, as `tools/check-fixtures.py` records it.
    sha256: []const u8,
    /// Its byte length, from the same table.
    length: usize,
    width: u32,
    height: u32,
    bit_depth: c_int,
    color_type: libpng.ColorType,
    /// `PNG_INTERLACE_NONE` (ISO/IEC 15948 table 24, value 0).
    interlace: libpng.Interlace,
    /// `png_get_rowbytes`: width times channels at 8 bits per sample, unpadded.
    row_bytes: usize,
    /// The decoded rows, top row first, concatenated and unpadded.
    pixels: []const u8,
};

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
        .pixels = &([_]u8{200} ** 64),
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

/// The colour-type codes ISO/IEC 15948 table 11 assigns, which are the values
/// upstream publishes as `PNG_COLOR_TYPE_GRAY`, `PNG_COLOR_TYPE_RGB` and
/// `PNG_COLOR_TYPE_RGBA` (`src/png.h:666-673`). The container check compares
/// against these literals rather than against the facade's enum, so a facade
/// that mislabelled its own enum could not make that check agree.
const png_color_type_greyscale: u8 = 0;
const png_color_type_rgb: u8 = 2;
const png_color_type_rgba: u8 = 6;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.arena.allocator();

    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(io, &buffer);
    const w = &stdout.interface;

    // In a runtime-loading build every call below goes through a table that this
    // one call fills. In a linked build the branch is not analyzed at all.
    if (comptime libpng.runtime_loaded) {
        try libpng.load(.{ .path = try providerRequest(init) });
    }

    try w.print("libpng consumer\n", .{});
    try w.print("{s} provider\n", .{
        if (libpng.runtime_loaded) "loaded" else "linked",
    });

    // The load-time ABI self-check this repository's README.md names, reached
    // through the published module's own raw route. libpng exports no version
    // symbol: `PNG_LIBPNG_VER_STRING` and `PNG_LIBPNG_VER` are compile-time
    // constants in the generated `pnglibconf.h`, so the only two things a caller
    // can ask the library itself are these (`src/png.h:920`, `src/png.h:2574`).
    //
    // They are printed as well as compared: a version string is provenance, and
    // AGENTS.md §7 keeps version pinning in the provenance gate. The pixels
    // below are what this program decides on.
    try w.print("png_access_version_number {d}\n", .{
        libpng.c.png_access_version_number(),
    });
    // `png_get_libpng_ver` returns a `[*:0]const u8`, so the printed form is
    // the sentinel-terminated slice that pointer names; the `orelse "<null>"`
    // branch could not be peer'd with it because a string literal is
    // `*const [6:0]u8`, not a C pointer.
    try w.print("png_get_libpng_ver {s}\n", .{
        std.mem.span(libpng.c.png_get_libpng_ver(null)),
    });
    try checkInt(w, "the provider reports libpng 1.6.59", libpng.c.png_access_version_number(), 10659);

    // The container, parsed here rather than through libpng, and the pixels,
    // decoded through libpng and compared against the specification's numbers.
    // `inline for`, so `fixture` is comptime-known and every
    // `fixture.name ++ "..."` label is a comptime slice. `declared` is a
    // `const` array of literals, so the three iterations cost nothing.
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

// ---------------------------------------------------------------------------
// 1. The bytes are the bytes this repository records
// ---------------------------------------------------------------------------

// `comptime fixture`, so every `fixture.name ++ "..."` label in this function
// is a comptime slice. The caller reaches it through an `inline for`, which is
// what makes the value comptime-known at the call site.
fn checkDigest(w: *std.Io.Writer, comptime fixture: Declared) !void {
    // `std.crypto.sha2` does not exist in Zig 0.16.0. The pinned stdlib
    // re-exports the module as `std.crypto.hash.sha2` (`lib/std/crypto.zig:146`).
    const Sha256 = std.crypto.hash.sha2.Sha256;
    var digest: [Sha256.digest_length]u8 = undefined;
    Sha256.hash(fixture.bytes, &digest, .{});
    const hex = std.fmt.bytesToHex(digest, .lower);
    try checkString(w, fixture.name ++ " sha256", &hex, fixture.sha256);
    try checkInt(w, fixture.name ++ " byte length", fixture.bytes.len, fixture.length);
}

// ---------------------------------------------------------------------------
// 2. The container, from ISO/IEC 15948 and from nothing else
// ---------------------------------------------------------------------------

/// One PNG chunk as this program parsed it, with nothing from libpng in it.
const Chunk = struct {
    kind: []const u8,
    data: []const u8,
    /// The CRC-32 the file carries, big-endian on the wire (§5.5).
    declared: u32,
    /// The CRC-32 recomputed here over the type and the data (§5.5).
    computed: u32,
};

/// Walks the chunk stream of `bytes` and returns the chunks.
///
/// §5.1 gives the eight-byte signature; §5.3 gives what follows it: a sequence
/// of chunks, each a 4-byte big-endian length, a 4-byte type, that many bytes of
/// data, and a 4-byte CRC. §5.5 gives the CRC's cover, which is the type field
/// and the data and not the length.
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
        const computed = std.hash.crc.Crc32.hash(bytes[at + 4 ..][0 .. 4 + length]);
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

    // §5.6: the first chunk of every PNG file is IHDR, and its payload is
    // exactly 13 bytes: width and height as 4-byte big-endian integers, then
    // bit depth, colour type, compression method, filter method and interlace
    // method as one byte each.
    try checkString(w, fixture.name ++ ": first chunk", chunks[0].kind, "IHDR");
    try checkInt(w, fixture.name ++ ": IHDR length", chunks[0].data.len, 13);

    // The header fields are read out of the payload here, so a decoder that
    // agreed with the encoder about a wrong geometry would still be caught.
    try checkInt(w, fixture.name ++ ": IHDR width", std.mem.readInt(u32, chunks[0].data[0..4], .big), fixture.width);
    try checkInt(w, fixture.name ++ ": IHDR height", std.mem.readInt(u32, chunks[0].data[4..8], .big), fixture.height);
    try checkInt(w, fixture.name ++ ": IHDR bit depth", chunks[0].data[8], @as(u8, @intCast(fixture.bit_depth)));
    try checkInt(w, fixture.name ++ ": IHDR colour type", chunks[0].data[9], switch (fixture.color_type) {
        .greyscale => png_color_type_greyscale,
        .rgb => png_color_type_rgb,
        .rgba => png_color_type_rgba,
        // No fixture above declares these two, so nothing reaches the arm; the
        // compile error names the gap instead of guessing a code for it.
        .greyscale_alpha, .indexed => @compileError("no fixture declares this colour type"),
    });
    // §5.6: compression method 0 and filter method 0 are the only values this
    // version of the specification defines.
    try checkInt(w, fixture.name ++ ": IHDR compression method", chunks[0].data[10], 0);
    try checkInt(w, fixture.name ++ ": IHDR filter method", chunks[0].data[11], 0);
    try checkInt(w, fixture.name ++ ": IHDR interlace method", chunks[0].data[12], 0);

    // §5.5: every chunk's CRC is over its type and data.
    for (chunks) |chunk| {
        try checkInt(
            w,
            // `chunk.kind` is parsed at run time, so this label cannot be a
            // comptime concatenation. `label` builds it in the arena.
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

// ---------------------------------------------------------------------------
// 3. The pixels, through libpng and against the specification's numbers
// ---------------------------------------------------------------------------

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
    try checkInt(w, fixture.name ++ ": colour type", @intFromEnum(header.color_type), @intFromEnum(fixture.color_type));
    try checkInt(w, fixture.name ++ ": interlace", @intFromEnum(header.interlace), @intFromEnum(fixture.interlace));

    // `png_get_rowbytes` is "number of bytes needed to hold a transformed row"
    // (`src/png.h:1936`), and at 8 bits per sample that is width times channels
    // with nothing padded on. Channels is 1 for colour type 0, 3 for colour type
    // 2 and 4 for colour type 6 (ISO/IEC 15948 table 11), which is where
    // `row_bytes` above comes from.
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

// ---------------------------------------------------------------------------
// 4. The writing side
// ---------------------------------------------------------------------------

fn checkWrite(w: *std.Io.Writer, allocator: std.mem.Allocator) !void {
    // The 4x3 truecolour pixels again, encoded here through the published
    // facade. The produced file is then parsed with the same ISO/IEC 15948
    // checks the fixtures went through, so the encoder is measured against the
    // specification rather than against the decoder.
    const fixture = declared[1];

    // A sink far larger than the file, so `SinkOverflow` is not what this is
    // measuring; the overflow boundary has its own check below.
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
            // `chunk.kind` is parsed from the encoded bytes at run time, so
            // this label is built rather than concatenated at comptime.
            label(allocator, "encoded: {s} CRC-32", .{chunk.kind}),
            chunk.declared,
            chunk.computed,
        );
    }

    // The round trip, and nothing more: it compares this build's encoder with
    // this build's decoder. The three fixtures above are what make that
    // comparison meaningful, because their pixels came from ISO/IEC 15948 and
    // from neither half of this program.
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

// ---------------------------------------------------------------------------
// 5. The boundaries the facade documents
// ---------------------------------------------------------------------------

fn checkErrorPaths(w: *std.Io.Writer, allocator: std.mem.Allocator) !void {
    // A signature that is not PNG's is refused before any libpng state exists,
    // so this is `error.NotPng` and not an abort through `png_longjmp`.
    var not_png = libpng.Source.init("this is not a PNG file, it is only text\x00\xff");
    try checkInt(w, "a non-PNG source has no signature", @intFromBool(not_png.hasSignature()), 0);
    var reader = try libpng.Reader.open();
    defer reader.deinit();
    try checkError(w, "readInfo refuses a non-PNG", reader.readInfo(&not_png) == error.NotPng);

    // Eight bytes are not enough for a signature either: `png_sig_cmp` compares
    // only what it was given (`src/png.c:87-97`).
    var short = libpng.Source.init(libpng.signature[0..7]);
    try checkInt(w, "seven signature bytes are not a signature", @intFromBool(short.hasSignature()), 0);

    // A row buffer whose row size is not the one `png_get_rowbytes` reports is
    // refused before `png_read_image` writes through a pointer, because libpng
    // takes no length there and cannot check it itself.
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

    // A sink that fills cannot become a C error: libpng's write callback returns
    // void and cannot report one (`src/pngwio.c:31-41`). The facade records the
    // overflow and surfaces it at the next Zig-level boundary, and says plainly
    // that the truncated bytes it kept are not a valid file.
    //
    // 64 bytes is deliberate: the signature plus IHDR is 33, so `writeInfo`
    // completes and the overflow happens on the image data, which is the path
    // under test. A sink that filled during `writeInfo` would report the same
    // error one call earlier.
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

    // Ownership transition: `deinit` clears the handle, so the second call is a
    // no-op rather than a second destroy, and the object is closed.
    overflowing.deinit();
    try checkInt(w, "deinit closes the writer", @intFromBool(overflowing.isOpen()), 0);
}

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

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
    // `{x}` on a byte slice is two hex digits per byte written straight to the
    // writer, which is what makes the bytes readable as bytes with nothing
    // allocated to say it.
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