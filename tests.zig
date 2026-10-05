// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md for what that identifier covers.

//! Behavioural tests for the libpng facade.
//!
//! Nothing here pins a version, an export list or a default. Every expectation
//! is a pixel value or a header field that the fixture itself states, and those
//! values are computed from the PNG specification rather than from anything
//! libpng said: the arguments are below, so a reader can check them without
//! running anything.
//!
//! ## Where the answers come from
//!
//! The three fixtures are written by `tools/make-fixtures.py` from these
//! specifications, with no image library involved. Each is a real PNG: the
//! eight signature bytes, an `IHDR`, one `IDAT` and an `IEND`.
//!
//! **`fixtures/rgb4x3.png`** - 4 wide, 3 high, colour type 2 (RGB), bit depth
//! 8, not interlaced. Row filters are None, Sub, None, so the filtered bytes are
//! not the pixel bytes and the Sub row has to be undone to be checked:
//!
//!   row 0, filter None: (0,0,0) (255,0,0) (0,255,0) (0,0,255)
//!   row 1, filter Sub:  (255,255,255) (128,128,128) (255,255,0) (0,255,255)
//!   row 2, filter None: (1,2,3) (10,20,30) (200,100,50) (7,255,0)
//!
//! The Sub arithmetic, which is the whole reason this fixture exists: a Sub
//! filtered byte is the difference from the byte `bpp` positions earlier in the
//! same row, `bpp` being 3 for colour type 2 at depth 8. So pixel 0 of row 1 is
//! its own bytes, `(255,255,255)`. Pixel 1's stored bytes are `(129,129,129)`,
//! and adding the previous pixel componentwise modulo 256 gives
//! `(255+129, 255+129, 255+129) = (128,128,128)` - note that the sum wraps, which
//! is why the answer is 128 and not 384. Pixel 2's stored bytes are
//! `(127,127,128)`, so `(128+127, 128+127, 128+128) = (255,255,0)`. Pixel 3's
//! stored bytes are `(1,0,255)`, so `(255+1, 255+0, 0+255) = (0,255,255)`.
//!
//! **`fixtures/rgba2x2.png`** - 2 by 2, colour type 6 (RGBA), depth 8, not
//! interlaced, Sub filter on both rows. `bpp` is 4 here, so the first pixel of a
//! row is stored raw and each later pixel is a difference from four bytes back:
//!
//!   row 0: (0,0,0,0) (255,0,0,64)     - stored (0,0,0,0) then (255,0,0,64)
//!   row 1: (0,255,0,128) (0,0,255,255) - stored (0,255,0,128) then (0,0,255,127);
//!                                      the last byte is 128+127 = 255
//!
//! The alpha channel is what makes this fixture worth having: `64`, `128` and
//! `255` are three different values that a decoder which quietly premultiplies,
//! clamps or forces opaque would collapse into one.
//!
//! **`fixtures/grey8x8-200.png`** - 8 by 8, colour type 0 (greyscale), depth 8,
//! not interlaced, filter None on every row, every sample exactly 200. `200` is
//! `0xC8`, which is neither 0 nor 255, so a decoder that mishandles the
//! greyscale path or the bit-depth scaling shows it on every one of the 64
//! samples rather than on a corner.
//!
//! Every fixture's row size follows from its header rather than being assumed:
//! `1 + width * channels` bytes per row at depth 8, so 13 for the 4-wide RGB
//! image, 9 for the 2-wide RGBA image and 8 for the greyscale one. That is
//! `png_get_rowbytes` (`src/png.h:1938`) answering, and the tests compare against
//! the arithmetic rather than against the number the library printed.
//!
//! ## The allocator
//!
//! libpng allocates through its own `png_malloc_default`/`png_free_default`,
//! and `Reader.open`/`Writer.open` pass null for the allocator hooks
//! (`src/png.h:997-1001`, `:1002-1006`), so none of the structures or decoded
//! data come from `std.testing.allocator`. That allocator cannot be a leak
//! oracle for them and no test here claims it is.
//!
//! What a test can check is the ownership transition this package owns, and two
//! tests below do: that `deinit` destroys the structures and a second `deinit`
//! is not a second destroy, and that destroying one reader leaves another
//! reader's decode untouched. `Rows` is the one thing allocated here, and it is
//! allocated with `testing.allocator`, so its own leak check is real.
//!
//! ## The longjmp boundary
//!
//! Every libpng error ends in `png_longjmp` (`src/pngerror.c:672-690`), which
//! calls an installed `longjmp_fn` if the caller established a jump point and
//! otherwise calls `PNG_ABORT()`, which is `abort()` (`src/pngpriv.h:579-580`).
//! This facade installs no jump point, so a stream with a valid signature and
//! corrupt data after it terminates the process. That is stated, not papered
//! over, and no test here feeds libpng such a stream and pretends to have got
//! an error back.
//!
//! What *is* tested is the half this package can see: a signature that does not
//! match, a buffer shorter than the signature, and a row buffer whose size does
//! not match `png_get_rowbytes` are all refused by a Zig comparison before
//! libpng is entered. `error.NotPng` and `error.RowStrideMismatch` are facts
//! about this package's guard, not about libpng's error handling.

const std = @import("std");
const libpng = @import("libpng");
const testing = std.testing;

/// A shared object exporting the declarations of `zig/translate.h`, named by the
/// environment in a runtime-loading build.
const provider_variable = "LIBPNG_TEST_PROVIDER";

/// The three fixtures, embedded so that a test run needs no file system and no
/// working directory.
const rgb4x3 = @embedFile("fixtures/rgb4x3.png");
const rgba2x2 = @embedFile("fixtures/rgba2x2.png");
const grey8x8 = @embedFile("fixtures/grey8x8-200.png");

/// Make the native library usable, once, before a test calls the facade.
///
/// In a linked build the facade is usable already and this is a no-op at
/// comptime. In a runtime-loading build every call into the module goes through
/// a table that `load` fills, so this is where the one explicit load happens.
/// It is safe to call from every test: the contract makes the same request
/// idempotent, and the loader keeps the handle to the end of the process.
///
/// A build that was not told which file to load stops here with the variable's
/// name, rather than reporting a test failure that says nothing about the
/// reason. A suite that quietly stopped testing because a variable was unset
/// would report success for nothing.
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

/// Decode one fixture completely and hand back its header and rows.
///
/// `Rows` is allocated with `testing.allocator`, so a leak here is a real leak
/// of *this* package's memory rather than of libpng's.
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

    // The header, from the fixture specification rather than from libpng's own
    // description of itself.
    try testing.expectEqual(@as(u32, 4), decoded.header.width);
    try testing.expectEqual(@as(u32, 3), decoded.header.height);
    try testing.expectEqual(@as(c_int, 8), decoded.header.bit_depth);
    try testing.expectEqual(libpng.ColorType.rgb, decoded.header.color_type);
    try testing.expectEqual(libpng.Interlace.none, decoded.header.interlace);

    // width * 3 bytes per row, computed here rather than read back. The stride
    // carries no filter byte: `src/pngrtran.c:2269` is
    // `PNG_ROWBYTES(pixel_depth, width)`, and `src/pngpriv.h:754-757` defines
    // that without one. The on-disk format's leading filter byte is added
    // separately, at `src/pngread.c:448`.
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
    // 2 * 4 bytes per row, for the reason the first fixture gives: the
    // reported stride is the transformed row and has no filter byte.
    try testing.expectEqual(@as(usize, 8), try decoded.reader.rowBytes());

    // The three alpha values 0, 64, 128, 255 are the point of this fixture.
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

    const every = [_]u8{200} ** 64;
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

    // The signature bytes with the last one wrong. `png_sig_cmp`
    // (`src/png.h:934`) compares byte by byte and answers non-zero, so this is
    // a fact about the bytes and not about a decode that might have gone wrong
    // later.
    var almost = libpng.signature;
    almost[7] = 0;
    var source = libpng.Source.init(&almost);
    try testing.expect(source.hasSignature() == false);
    try testing.expectError(error.NotPng, reader.readInfo(&source));

    // Shorter than the signature: there is nothing to compare, and
    // `Source.hasSignature` says so before calling libpng at all.
    var short = libpng.Source.init(rgb4x3[0..5]);
    try testing.expect(short.hasSignature() == false);
    try testing.expectError(error.NotPng, reader.readInfo(&short));

    // The same reader is still usable, and still open: a refused `readInfo`
    // consumed no libpng state.
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

    // One byte too narrow for the 13-byte RGB rows.
    var rows = try libpng.Rows.alloc(testing.allocator, header.height, stride - 1);
    defer rows.deinit();
    try testing.expect(rows.fitsRow(stride) == false);
    try testing.expectError(error.RowStrideMismatch, reader.readImage(&rows));

    // And the write side refuses a short row for the same reason: `png_write_row`
    // reads exactly `png_get_rowbytes` bytes and takes no length
    // (`src/png.h:1450-1451`), so nothing downstream could have caught it.
    var out: [4096]u8 = undefined;
    var sink = libpng.Sink.init(&out);
    var writer = try libpng.Writer.open();
    defer writer.deinit();
    try writer.writeInfo(&sink, header);
    try testing.expectError(error.RowStrideMismatch, writer.writeRow((&([_]u8{0} ** 16))[0..stride - 1]));
}

test "destroying a reader destroys exactly what it created" {
    nativeReady();

    var first = try libpng.Reader.open();
    var second = try libpng.Reader.open();
    try testing.expect(first.isOpen() and second.isOpen());

    // Two readers over two sources are independent. Decoding through `second`
    // after `first` is gone is the ownership transition: `first`'s destroy
    // released only `first`'s structures.
    first.deinit();
    try testing.expect(first.isOpen() == false);
    try testing.expect(second.isOpen());

    var source = libpng.Source.init(grey8x8);
    const header = try second.readInfo(&source);
    try testing.expectEqual(@as(u32, 8), header.width);
    var rows = try libpng.Rows.alloc(testing.allocator, header.height, try second.rowBytes());
    defer rows.deinit();
    try second.readImage(&rows);
    try testing.expectEqualSlices(u8, &[_]u8{200} ** 8, rows.slice(3));

    // A second `deinit` on the same variable is a no-op, not a second destroy:
    // `deinit` clears the field before calling libpng.
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

    // The 64 greyscale samples are 64 bytes; a PNG around them is larger than
    // that, and this buffer cannot hold it. libpng's write callback cannot
    // report a failure (`png_write_data`, `src/pngwio.c:31-41`, calls it and
    // ignores the result), so the sink records the overflow and the next
    // Zig-level call reports it.
    var small: [32]u8 = undefined;
    var sink = libpng.Sink.init(&small);
    var writer = try libpng.Writer.open();
    defer writer.deinit();
    try testing.expectError(error.SinkOverflow, writer.writeInfo(&sink, header));
    try testing.expect(sink.hasOverflowed());
    try testing.expectEqual(@as(usize, 32), sink.written().len);

    // A sink that is large enough does not overflow, and the bytes it holds are
    // a PNG: the signature is what `Source.hasSignature` looks for.
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

    // This is a same-code round trip and is only a supplement to the three
    // tests above, which compare against independently computed values. What it
    // does add is the write path, which the fixture tests do not reach, and it
    // says so here rather than standing alone as the evidence.
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

    // `png_read_row` (`src/png.h:1439-1440`) is the other half of the read API
    // and is not exercised by `readImage`. The comparison below is against the
    // independently computed expectations, not against the whole-image result,
    // so a shared mistake could not pass both.
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