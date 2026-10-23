// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md for what that identifier covers.

//! Tests the facade against fixture pixels, row sizes, ownership, errors, and writes.

const std = @import("std");
const libpng = @import("libpng");
const testing = std.testing;

const provider_variable = "LIBPNG_TEST_PROVIDER";

const rgb4x3 = @embedFile("fixtures/rgb4x3.png");
const rgba2x2 = @embedFile("fixtures/rgba2x2.png");
const grey8x8 = @embedFile("fixtures/grey8x8-200.png");

/// Loads the explicit runtime provider once; linked builds need no load.
fn nativeReady() void {
    if (comptime !libpng.runtime_loaded) return;
    if (libpng.loadedSource() != null) return;

    var buffer: [4096]u8 = undefined;
    const value = std.testing.environ.getAlloc(testing.allocator, provider_variable) catch
        missingProvider();
    defer testing.allocator.free(value);
    if (value.len == 0 or value.len > buffer.len) missingProvider();
    @memcpy(buffer[0..value.len], value);
    libpng.load(.{ .path = buffer[0..value.len] }) catch |err| {
        std.debug.print(
            "tests.zig: loading " ++ provider_variable ++ " = \"{s}\" failed: {t}\n",
            .{ buffer[0..value.len], err },
        );
        @panic("tests.zig: the provider named by " ++ provider_variable ++
            " did not load; nothing below this line ran");
    };
}

fn missingProvider() noreturn {
    @panic(
        "tests.zig: this is a runtime-loading build and " ++ provider_variable ++
            " is not set. Point it at a shared object exporting the declarations " ++
            "of zig/translate.h - for example the libpng16.so this package's " ++
            "`zig build -Dlinkage=dynamic` installs - and export it for the whole " ++
            "`zig build` invocation: the build cannot inject a path into a run " ++
            "step's environment.",
    );
}

fn decode(bytes: []const u8, allocator: std.mem.Allocator) !struct { reader: libpng.Reader, header: libpng.Header, rows: libpng.Rows } {
    var source = libpng.Source.init(bytes);
    var reader = try libpng.Reader.open();
    errdefer reader.deinit();
    const header = try reader.readInfo(&source);
    var rows = try libpng.Rows.alloc(allocator, header.height, try reader.rowBytes());
    errdefer rows.deinit();
    try reader.readImage(&rows);
    return .{ .reader = reader, .header = header, .rows = rows };
}

test "rgb4x3.png decodes to the pixels the fixture states" {
    nativeReady();

    var decoded = try decode(rgb4x3, testing.allocator);
    defer decoded.rows.deinit();
    defer decoded.reader.deinit();

    try testing.expectEqual(@as(u32, 4), decoded.header.width);
    try testing.expectEqual(@as(u32, 3), decoded.header.height);
    try testing.expectEqual(@as(c_int, 8), decoded.header.bit_depth);
    try testing.expectEqual(libpng.ColorType.rgb, decoded.header.color_type);
    try testing.expectEqual(libpng.Interlace.none, decoded.header.interlace);

    // The transformed row stride excludes the PNG filter byte.
    try testing.expectEqual(@as(usize, 12), try decoded.reader.rowBytes());
    try testing.expectEqual(@as(usize, 3), decoded.rows.height());

    const expected = [3][4][3]u8{
        .{ .{ 0, 0, 0 }, .{ 255, 0, 0 }, .{ 0, 255, 0 }, .{ 0, 0, 255 } },
        .{ .{ 255, 255, 255 }, .{ 128, 128, 128 }, .{ 255, 255, 0 }, .{ 0, 255, 255 } },
        .{ .{ 1, 2, 3 }, .{ 10, 20, 30 }, .{ 200, 100, 50 }, .{ 7, 255, 0 } },
    };
    for (expected, 0..) |row, y| {
        for (row, 0..) |pixel, x| {
            const at = decoded.rows.slice(y)[x * 3 ..][0..3];
            testing.expectEqualSlices(u8, &pixel, at) catch |err| {
                std.debug.print(
                    "rgb4x3.png pixel ({d},{d}): expected {any}, decoded {any}\n",
                    .{ x, y, pixel, at },
                );
                return err;
            };
        }
    }
}

test "rgba2x2.png decodes to the pixels the fixture states, alpha included" {
    nativeReady();

    var decoded = try decode(rgba2x2, testing.allocator);
    defer decoded.rows.deinit();
    defer decoded.reader.deinit();

    try testing.expectEqual(@as(u32, 2), decoded.header.width);
    try testing.expectEqual(@as(u32, 2), decoded.header.height);
    try testing.expectEqual(@as(c_int, 8), decoded.header.bit_depth);
    try testing.expectEqual(libpng.ColorType.rgba, decoded.header.color_type);
    try testing.expectEqual(libpng.Interlace.none, decoded.header.interlace);
    try testing.expectEqual(@as(usize, 8), try decoded.reader.rowBytes());

    const expected = [2][2][4]u8{
        .{ .{ 0, 0, 0, 0 }, .{ 255, 0, 0, 64 } },
        .{ .{ 0, 255, 0, 128 }, .{ 0, 0, 255, 255 } },
    };
    for (expected, 0..) |row, y| {
        for (row, 0..) |pixel, x| {
            const at = decoded.rows.slice(y)[x * 4 ..][0..4];
            testing.expectEqualSlices(u8, &pixel, at) catch |err| {
                std.debug.print(
                    "rgba2x2.png pixel ({d},{d}): expected {any}, decoded {any}\n",
                    .{ x, y, pixel, at },
                );
                return err;
            };
        }
    }
}

test "grey8x8-200.png decodes to 200 in every one of its 64 samples" {
    nativeReady();

    var decoded = try decode(grey8x8, testing.allocator);
    defer decoded.rows.deinit();
    defer decoded.reader.deinit();

    try testing.expectEqual(@as(u32, 8), decoded.header.width);
    try testing.expectEqual(@as(u32, 8), decoded.header.height);
    try testing.expectEqual(@as(c_int, 8), decoded.header.bit_depth);
    try testing.expectEqual(libpng.ColorType.greyscale, decoded.header.color_type);
    try testing.expectEqual(libpng.Interlace.none, decoded.header.interlace);
    try testing.expectEqual(@as(usize, 8), try decoded.reader.rowBytes());

    const every: [64]u8 = @splat(200);
    var at: usize = 0;
    for (0..8) |y| {
        const row = decoded.rows.slice(y);
        testing.expectEqualSlices(u8, every[at..][0..8], row) catch |err| {
            std.debug.print("grey8x8-200.png row {d}: expected {any}, decoded {any}\n", .{
                y,
                every[at..][0..8],
                row,
            });
            return err;
        };
        at += 8;
    }
}

test "a buffer that is not a PNG is refused before libpng ever sees it" {
    nativeReady();

    var reader = try libpng.Reader.open();
    defer reader.deinit();

    // A wrong final signature byte is rejected before decoding.
    var almost = libpng.signature;
    almost[7] = 0;
    var source = libpng.Source.init(&almost);
    try testing.expect(source.hasSignature() == false);
    try testing.expectError(error.NotPng, reader.readInfo(&source));

    // Input shorter than the signature is rejected before libpng is called.
    var short = libpng.Source.init(rgb4x3[0..5]);
    try testing.expect(short.hasSignature() == false);
    try testing.expectError(error.NotPng, reader.readInfo(&short));

    // Refusing a bad signature leaves this reader usable.
    try testing.expect(reader.isOpen());
    var good = libpng.Source.init(rgb4x3);
    const header = try reader.readInfo(&good);
    try testing.expectEqual(@as(u32, 4), header.width);
}

test "a row buffer that is not the row size libpng reports is refused" {
    nativeReady();

    var source = libpng.Source.init(rgb4x3);
    var reader = try libpng.Reader.open();
    defer reader.deinit();
    const header = try reader.readInfo(&source);
    const stride = try reader.rowBytes();

    // Deliberately one byte shorter than the RGB row stride.
    var rows = try libpng.Rows.alloc(testing.allocator, header.height, stride - 1);
    defer rows.deinit();
    try testing.expect(rows.fitsRow(stride) == false);
    try testing.expectError(error.RowStrideMismatch, reader.readImage(&rows));

    // The writer rejects short rows before libpng reads past the buffer.
    var out: [4096]u8 = undefined;
    var sink = libpng.Sink.init(&out);
    var writer = try libpng.Writer.open();
    defer writer.deinit();
    try writer.writeInfo(&sink, header);
    const short_row: [16]u8 = @splat(0);
    try testing.expectError(error.RowStrideMismatch, writer.writeRow(short_row[0 .. stride - 1]));
}

test "destroying a reader destroys exactly what it created" {
    nativeReady();

    var first = try libpng.Reader.open();
    var second = try libpng.Reader.open();
    try testing.expect(first.isOpen() and second.isOpen());

    // Destroying one reader leaves the other reader's decode intact.
    first.deinit();
    try testing.expect(first.isOpen() == false);
    try testing.expect(second.isOpen());

    var source = libpng.Source.init(grey8x8);
    const header = try second.readInfo(&source);
    try testing.expectEqual(@as(u32, 8), header.width);
    var rows = try libpng.Rows.alloc(testing.allocator, header.height, try second.rowBytes());
    defer rows.deinit();
    try second.readImage(&rows);
    const expected_row: [8]u8 = @splat(200);
    try testing.expectEqualSlices(u8, &expected_row, rows.slice(3));

    // `deinit` is idempotent for the same reader value.
    first.deinit();
    try testing.expect(first.isOpen() == false);

    second.deinit();
    try testing.expect(second.isOpen() == false);
    second.deinit();
    try testing.expect(second.isOpen() == false);
}

test "a sink too small for the image reports it instead of growing" {
    nativeReady();

    var source = libpng.Source.init(grey8x8);
    var reader = try libpng.Reader.open();
    defer reader.deinit();
    const header = try reader.readInfo(&source);
    var rows = try libpng.Rows.alloc(testing.allocator, header.height, try reader.rowBytes());
    defer rows.deinit();
    try reader.readImage(&rows);

    // A fixed sink records dropped bytes for the next writer call.
    var small: [32]u8 = undefined;
    var sink = libpng.Sink.init(&small);
    var writer = try libpng.Writer.open();
    defer writer.deinit();
    try testing.expectError(error.SinkOverflow, writer.writeInfo(&sink, header));
    try testing.expect(sink.hasOverflowed());
    try testing.expectEqual(@as(usize, 32), sink.written().len);

    var roomy: [4096]u8 = undefined;
    var out = libpng.Sink.init(&roomy);
    var ok_writer = try libpng.Writer.open();
    defer ok_writer.deinit();
    try ok_writer.writeInfo(&out, header);
    try ok_writer.writeImage(&rows);
    try ok_writer.writeEnd();
    try testing.expect(out.hasOverflowed() == false);
    try testing.expect(libpng.Source.init(out.written()).hasSignature());
}

test "pixels written by this package read back unchanged through a second decode" {
    nativeReady();

    // Supplements fixture oracles with a write/read round trip.
    var source = libpng.Source.init(rgb4x3);
    var reader = try libpng.Reader.open();
    defer reader.deinit();
    const header = try reader.readInfo(&source);
    var original = try libpng.Rows.alloc(testing.allocator, header.height, try reader.rowBytes());
    defer original.deinit();
    try reader.readImage(&original);

    var out: [4096]u8 = undefined;
    var sink = libpng.Sink.init(&out);
    var writer = try libpng.Writer.open();
    defer writer.deinit();
    try writer.writeInfo(&sink, header);
    try writer.writeImage(&original);
    try writer.writeEnd();
    try testing.expect(sink.hasOverflowed() == false);

    var again = libpng.Source.init(sink.written());
    var reader2 = try libpng.Reader.open();
    defer reader2.deinit();
    const header2 = try reader2.readInfo(&again);
    try testing.expectEqual(header.width, header2.width);
    try testing.expectEqual(header.height, header2.height);
    var round = try libpng.Rows.alloc(testing.allocator, header2.height, try reader2.rowBytes());
    defer round.deinit();
    try reader2.readImage(&round);
    for (0..original.height()) |y| {
        try testing.expectEqualSlices(u8, original.slice(y), round.slice(y));
    }
}

test "one row at a time decodes what the whole-image call decodes" {
    nativeReady();

    // Also compare `readRow` with the fixture's expected pixels.
    var source = libpng.Source.init(rgba2x2);
    var reader = try libpng.Reader.open();
    defer reader.deinit();
    const header = try reader.readInfo(&source);
    try testing.expectEqual(@as(u32, 2), header.height);
    const stride = try reader.rowBytes();

    const expected = [2][2][4]u8{
        .{ .{ 0, 0, 0, 0 }, .{ 255, 0, 0, 64 } },
        .{ .{ 0, 255, 0, 128 }, .{ 0, 0, 255, 255 } },
    };
    var row: [16]u8 = undefined;
    for (0..header.height) |y| {
        const into = row[0..stride];
        try reader.readRow(into);
        for (expected[y], 0..) |pixel, x| {
            try testing.expectEqualSlices(u8, &pixel, into[x * 4 ..][0..4]);
        }
    }
}
