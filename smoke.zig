// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md for what that identifier covers.

//! A runnable, deterministic demonstration of the libpng facade.
//!
//! `zig build smoke` runs this. There is no input to supply and no output that
//! depends on the host, the clock or a random seed, so the same lines come out
//! every time.
//!
//! Every answer below is an expected value computed from the PNG specification,
//! not a value this program printed for comparison. The arguments for the three
//! fixtures are in the module comment of `tests.zig`; the short version is that
//! the 4x3 RGB fixture's rows are
//!
//!   (0,0,0) (255,0,0) (0,255,0) (0,0,255)
//!   (255,255,255) (128,128,128) (255,255,0) (0,255,255)
//!   (1,2,3) (10,20,30) (200,100,50) (7,255,0)
//!
//! with the middle row stored Sub-filtered, so `(255+129, 255+129, 255+129)`
//! wraps to `(128,128,128)`. A mismatch prints both sides and exits non-zero, so
//! this is a check and not a demo.
//!
//! In a runtime-loading build the provider is named on the command line
//! (`--provider <path>`) or in `LIBPNG_TEST_PROVIDER`, and the program says
//! which configuration it is in the first two lines. In a linked build neither is
//! needed and neither is read.
//!
//! What it exercises, in order: the three fixtures decoded to their stated
//! pixels, a header's fields, a buffer that is not a PNG refused, the raw
//! translated route for a signature comparison and for the library's own version
//! string, and a write into a fixed sink followed by a read of what was written.

const std = @import("std");
const libpng = @import("libpng");

/// The three fixtures, embedded so the run needs no file system.
const rgb4x3 = @embedFile("fixtures/rgb4x3.png");
const rgba2x2 = @embedFile("fixtures/rgba2x2.png");
const grey8x8 = @embedFile("fixtures/grey8x8-200.png");

/// A runtime-loading build has no provider until one is named.
const ConfigurationError = error{NoProviderConfigured};

/// The provider this run should load, from `--provider <path>` or from
/// `LIBPNG_TEST_PROVIDER`.
///
/// Both are explicit. Nothing here looks in a default location or falls back
/// to a linked copy: a runtime-loading build that was not told which file to
/// load reports that it was not told, rather than loading something else.
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
        "smoke: this is a runtime-loading build. Pass --provider <path>, or " ++
            "export LIBPNG_TEST_PROVIDER with a shared object exporting the " ++
            "declarations of zig/translate.h. Nothing is loaded by default and " ++
            "no other file is tried.\n",
        .{},
    );
    return error.NoProviderConfigured;
}

/// Decode one fixture and check every byte against `expected`.
///
/// `expected` is the whole image in top-row-first order, one byte per channel
/// per pixel, so `expected_width * channels` bytes per row is also what
/// `png_get_rowbytes` has to report at depth 8.
fn checkFixture(
    w: *std.Io.Writer,
    label: []const u8,
    bytes: []const u8,
    expected_width: u32,
    expected_height: u32,
    channels: usize,
    expected_color_type: c_int,
    expected: []const u8,
) !void {
    var source = libpng.Source.init(bytes);
    var reader = try libpng.Reader.open();
    defer reader.deinit();
    const header = try reader.readInfo(&source);

    try checkInt(w, "width", header.width, expected_width);
    try checkInt(w, "height", header.height, expected_height);
    try checkInt(w, "bit depth", header.bit_depth, 8);
    try checkInt(w, "colour type (raw)", header.rawColorType(), expected_color_type);
    try checkInt(w, "interlace (raw)", header.rawInterlace(), 0);
    // width * channels at depth 8, computed rather than read back. The stride
    // `png_get_rowbytes` reports is the transformed row and carries no filter
    // byte: `src/pngrtran.c:2269` is `PNG_ROWBYTES(pixel_depth, width)` and
    // `src/pngpriv.h:754-757` defines that without one. The on-disk format's
    // leading filter byte is added separately, at `src/pngread.c:448`.
    try checkInt(w, "row bytes", try reader.rowBytes(), expected_width * channels);
    var rows = try libpng.Rows.alloc(std.heap.page_allocator, header.height, try reader.rowBytes());
    defer rows.deinit();
    try reader.readImage(&rows);

    try w.print("{s}: {d} row(s) of {d} bytes\n", .{
        label,
        rows.height(),
        try reader.rowBytes(),
    });
    var at: usize = 0;
    for (0..rows.height()) |y| {
        const row = rows.slice(y);
        if (!std.mem.eql(u8, row, expected[at..][0..row.len])) {
            try w.print("{s} row {d}: expected {x}\n", .{ label, y, expected[at..][0..row.len] });
            try w.print("{s} row {d}: decoded {x}\n", .{ label, y, row });
            std.debug.print("smoke: {s} row {d} does not match the stated pixels\n", .{ label, y });
            return error.SmokeCheckFailed;
        }
        try w.print("{s} row {d}: {d} bytes match\n", .{ label, y, row.len });
        at += row.len;
    }
    if (at != expected.len) {
        std.debug.print(
            "smoke: {s}: decoded {d} bytes but the stated image has {d}\n",
            .{ label, at, expected.len },
        );
        return error.SmokeCheckFailed;
    }
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var buffer: [4096]u8 = undefined;
    var stdout = std.Io.File.stdout().writerStreaming(io, &buffer);
    const w = &stdout.interface;

    // In a runtime-loading build nothing below can run until a provider is
    // loaded, and the load is the one explicit step the contract asks for. In a
    // linked build this is a no-op at comptime and the module is already
    // usable.
    if (comptime libpng.runtime_loaded) {
        try libpng.load(.{ .path = try providerRequest(init) });
    }

    try w.print("libpng smoke\n", .{});
    try w.print("{s} build\n", .{if (libpng.runtime_loaded) "runtime-loaded" else "linked"});
    // Through the raw escape hatch, so this line names the library this build
    // reached rather than a constant compiled into this program. It is printed,
    // not compared: a version string is provenance, not behaviour.
    try w.print("{s} provider reports: {s}\n", .{
        if (libpng.runtime_loaded) "loaded" else "linked",
        std.mem.span(libpng.c.png_get_libpng_ver(null)),
    });
    try w.flush();

    // The 4x3 RGB fixture, including the Sub row.
    try checkFixture(w, "rgb4x3", rgb4x3, 4, 3, 3, libpng.c.PNG_COLOR_TYPE_RGB, &[_]u8{
        0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255,
        255, 255, 255, 128, 128, 128, 255, 255, 0, 0, 255, 255,
        1, 2, 3, 10, 20, 30, 200, 100, 50, 7, 255, 0,
    });

    // The 2x2 RGBA fixture, whose alpha channel is 0, 64, 128 and 255.
    try checkFixture(w, "rgba2x2", rgba2x2, 2, 2, 4, libpng.c.PNG_COLOR_TYPE_RGBA, &[_]u8{
        0, 0, 0, 0, 255, 0, 0, 64,
        0, 255, 0, 128, 0, 0, 255, 255,
    });

    // The 8x8 greyscale fixture, every sample 200.
    try checkFixture(w, "grey8x8-200", grey8x8, 8, 8, 1, libpng.c.PNG_COLOR_TYPE_GRAY, &([_]u8{200} ** 64));

    // A buffer that is not a PNG is refused by the signature comparison, before
    // any libpng state exists. This is the one failure this package can report
    // as a Zig error: every other libpng error ends in `png_longjmp`
    // (`src/pngerror.c:672-690`) and terminates the process.
    var almost = libpng.signature;
    almost[7] = 0;
    var rejected = libpng.Source.init(&almost);
    var reader = try libpng.Reader.open();
    defer reader.deinit();
    const refusal = reader.readInfo(&rejected);
    if (refusal) |_| {
        std.debug.print("smoke: a buffer with a broken signature was accepted\n", .{});
        return error.SmokeCheckFailed;
    } else |err| {
        try w.print("{s: <44}{s}\n", .{ "a buffer that is not a PNG", @errorName(err) });
    }

    // The raw translated route, through the same module the facade calls: the
    // signature comparison and the header version string, neither of which the
    // facade names.
    try checkInt(
        w,
        "raw png_sig_cmp on the fixture",
        libpng.c.png_sig_cmp(rgb4x3.ptr, 0, 8),
        0,
    );
    // `png_sig_cmp` is `memcmp(&sig[start], &png_signature[start], n)`
    // (`src/png.c:96`), so it returns zero iff the signature matches, and
    // otherwise the first differing byte taken as `sig - signature`. `almost`
    // differs from the signature only in its last byte, 0 against 10.
    try checkInt(
        w,
        "raw png_sig_cmp on a broken signature",
        libpng.c.png_sig_cmp(almost[0..].ptr, 0, 8),
        @as(c_int, almost[7]) - @as(c_int, libpng.signature[7]),
    );
    try w.print("{s: <44}{s}\n", .{ "raw png_get_header_ver", std.mem.span(libpng.c.png_get_header_ver(null)) });

    // Write a PNG into a fixed sink and read it back, which exercises the write
    // path the fixture decodes do not touch.
    {
        var out: [4096]u8 = undefined;
        var sink = libpng.Sink.init(&out);
        var writer = try libpng.Writer.open();
        defer writer.deinit();
        const header = libpng.Header{
            .width = 2,
            .height = 1,
            .bit_depth = 8,
            .color_type = .greyscale,
            .interlace = .none,
            .compression_method = libpng.c.PNG_COMPRESSION_TYPE_DEFAULT,
            .filter_method = libpng.c.PNG_FILTER_TYPE_DEFAULT,
        };
        try writer.writeInfo(&sink, header);
        try writer.writeRow(&[_]u8{ 17, 200 });
        try writer.writeEnd();
        try checkInt(w, "the sink overflowed", @intFromBool(sink.hasOverflowed()), 0);
        try checkInt(w, "bytes written", @intFromBool(sink.written().len > 8), 1);

        var written = libpng.Source.init(sink.written());
        var back = try libpng.Reader.open();
        defer back.deinit();
        const read_header = try back.readInfo(&written);
        try checkInt(w, "round-trip width", read_header.width, 2);
        try checkInt(w, "round-trip height", read_header.height, 1);
        var rows = try libpng.Rows.alloc(std.heap.page_allocator, read_header.height, try back.rowBytes());
        defer rows.deinit();
        try back.readImage(&rows);
        try checkBytes(w, "round-trip row", rows.slice(0), &[_]u8{ 17, 200 });
    }

    try w.print("every answer matched the stated value\n", .{});
    try w.flush();
}

fn checkInt(w: *std.Io.Writer, what: []const u8, got: anytype, expected: anytype) !void {
    try w.print("{s: <44}{d}\n", .{ what, got });
    if (got != expected) {
        std.debug.print("smoke: {s}: expected {d}, computed {d}\n", .{ what, expected, got });
        return error.SmokeCheckFailed;
    }
}

fn checkBytes(w: *std.Io.Writer, what: []const u8, got: []const u8, expected: []const u8) !void {
    // `{x}` on a byte slice is `printHex` writing two digits per byte straight to
    // the writer (`std/Io/Writer.zig`), which is what makes the bytes readable as
    // bytes with nothing allocated to say it.
    try w.print("{s: <44}{x}\n", .{ what, got });
    if (!std.mem.eql(u8, got, expected)) {
        std.debug.print("smoke: {s}: expected {x}, computed {x}\n", .{ what, expected, got });
        return error.SmokeCheckFailed;
    }
}