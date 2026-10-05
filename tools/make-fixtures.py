#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# See ../FORK-LICENSE.md for what that identifier covers.

"""Independent encoder for this SDK's PNG test fixtures.

This program does not use libpng, Pillow, ImageMagick or any other image
library. It writes the container by hand from ISO/IEC 15948: the eight-byte
signature, an `IHDR`, one `IDAT` holding a zlib stream over the filtered
scanlines, and an `IEND`. The only facility it borrows is `zlib.compress`,
because `IDAT` is *defined* as a zlib stream (ISO/IEC 15948 section 11.2.4) and
the ADLER-32 and CRC-32 the format specifies are the ones zlib computes.

That is what makes the fixtures independent answers rather than a round trip:
the bytes are produced by an encoder written from the specification, and the
pixels a test expects are written out in the table below in plain arithmetic,
not read back out of a file this SDK wrote.

Each fixture is fully determined by the `FIXTURES` table. Re-running this
program must reproduce the same bytes; `tools/check-fixtures.py` is what
compares the result against the recorded SHA-256 digests, and that comparison
is a provenance check rather than a behavioural gate.

Usage:
    python3 tools/make-fixtures.py <output-directory>

The output directory receives one `.png` per table entry. It is normally
`fixtures/`.
"""

import os
import struct
import sys
import zlib

# ISO/IEC 15948 section 5.6: the eight-byte PNG signature.
SIGNATURE = b"\x89PNG\r\n\x1a\n"

# Colour type codes (ISO/IEC 15948 table 11).
GREYSCALE = 0
TRUECOLOUR = 2
GREYSCALE_ALPHA = 4
TRUECOLOUR_ALPHA = 6

# Bytes per complete pixel, by colour type, at bit depth 8.
CHANNELS = {
    GREYSCALE: 1,
    TRUECOLOUR: 3,
    GREYSCALE_ALPHA: 2,
    TRUECOLOUR_ALPHA: 4,
}

# Filter type codes (ISO/IEC 15948 table 24).
FILTER_NONE = 0
FILTER_SUB = 1


def chunk(kind: bytes, payload: bytes) -> bytes:
    """One PNG chunk: length, type, data, CRC over type and data.

    The CRC is the CRC-32 of the chunk type followed by the chunk data, exactly
    as ISO/IEC 15948 section 5.1 requires. `zlib.crc32` is that CRC.
    """
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    )


def ihdr(width: int, height: int, colour_type: int) -> bytes:
    """The `IHDR` chunk of an 8-bit, non-interlaced image.

    Compression method and filter method are 0, which section 5.6 defines as
    "deflate/inflate" and "adaptive filtering with the five filter types"; the
    interlace method is 0, "no interlace".
    """
    return chunk(
        b"IHDR",
        struct.pack(
            ">IIBBBBB",
            width,
            height,
            8,  # bit depth
            colour_type,
            0,  # compression method: deflate
            0,  # filter method: adaptive
            0,  # interlace method: none
        ),
    )


def filter_scanline(row: bytes, previous: bytes, method: int) -> bytes:
    """Apply one PNG row filter, returning the filter byte and the filtered row.

    `FILTER_NONE` stores the row unchanged. `FILTER_SUB` stores the difference
    between each byte and the byte `bpp` positions before it, which is what
    ISO/IEC 15948 section 6.2.3 defines and what a reader must undo.
    """
    if method == FILTER_NONE:
        return bytes([FILTER_NONE]) + row
    if method != FILTER_SUB:
        raise ValueError("this generator implements only filters 0 and 1")
    out = bytearray()
    for index, byte in enumerate(row):
        left = row[index - CHANNELS_BPP] if index >= CHANNELS_BPP else 0
        out.append((byte - left) & 0xFF)
    return bytes([FILTER_SUB]) + bytes(out)


def encode(width: int, height: int, colour_type: int, rows, filter_of_row) -> bytes:
    """A complete single-`IDAT` PNG file."""
    bpp = CHANNELS[colour_type]
    stride = width * bpp
    if len(rows) != height:
        raise ValueError("row count does not match height")
    raw = bytearray()
    previous = bytes(stride)
    for index, row in enumerate(rows):
        if len(row) != stride:
            raise ValueError("row %d has the wrong length" % index)
        raw += filter_scanline(row, previous, filter_of_row(index))
        previous = row
    # ISO/IEC 15948 section 11.2.4: the IDAT payload is a zlib stream. Level 9
    # is chosen so the bytes are a function of the pixels alone and not of a
    # library's default level.
    idat = zlib.compress(bytes(raw), 9)
    return SIGNATURE + ihdr(width, height, colour_type) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")


# `filter_scanline` reads CHANNELS_BPP from the enclosing scope; it is set per
# fixture below so the helper stays free of a width argument.
CHANNELS_BPP = 1


def flat(value: bytes, count: int) -> bytes:
    return value * count


def flat_rgb(r: int, g: int, b: int, count: int) -> bytes:
    return bytes([r, g, b]) * count


# The fixture table.
#
# Each entry names the file, the geometry, the colour type, the per-row pixel
# data written out in full, and the filter used on each row. The pixel values
# are the expected values a test asserts; they are stated here in decimal so
# they can be checked by eye against the specification tables above.
#
# `filters` is one filter code per row, or a single code used for every row.
FIXTURES = [
    {
        "name": "rgb4x3.png",
        "width": 4,
        "height": 3,
        "colour_type": TRUECOLOUR,
        "filters": [FILTER_NONE, FILTER_SUB, FILTER_NONE],
        # Row 0: black, red, green, blue. Row 1: white, mid grey, yellow, cyan.
        # Row 2: four arbitrary triples that are neither 0 nor 255, so a decoder
        # that clamps, truncates or rounds differently is caught.
        "rows": [
            bytes([0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255]),
            bytes([255, 255, 255, 128, 128, 128, 255, 255, 0, 0, 255, 255]),
            bytes([1, 2, 3, 10, 20, 30, 200, 100, 50, 7, 255, 0]),
        ],
    },
    {
        "name": "rgba2x2.png",
        "width": 2,
        "height": 2,
        "colour_type": TRUECOLOUR_ALPHA,
        "filters": FILTER_SUB,
        # Alpha values 0, 64, 128, 255 cover both ends of the range and the two
        # midpoints, and (0, 0, 0, 0) is the fully transparent pixel.
        "rows": [
            bytes([0, 0, 0, 0, 255, 0, 0, 64]),
            bytes([0, 255, 0, 128, 0, 0, 255, 255]),
        ],
    },
    {
        "name": "grey8x8-200.png",
        "width": 8,
        "height": 8,
        "colour_type": GREYSCALE,
        "filters": FILTER_NONE,
        # One flat block of mid-grey. A greyscale image has one channel, so
        # `flat` repeats a single byte 64 times per row.
        "rows": [flat(bytes([200]), 8)] * 8,
    },
]


def main() -> int:
    if len(sys.argv) != 2:
        sys.stderr.write("usage: make-fixtures.py <output-directory>\n")
        return 2
    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    for fixture in FIXTURES:
        global CHANNELS_BPP
        CHANNELS_BPP = CHANNELS[fixture["colour_type"]]
        filters = fixture["filters"]
        if isinstance(filters, int):
            filter_of_row = lambda _index, code=filters: code
        else:
            if len(filters) != fixture["height"]:
                raise ValueError("%s: one filter per row is required" % fixture["name"])
            filter_of_row = lambda index: filters[index]
        data = encode(
            fixture["width"],
            fixture["height"],
            fixture["colour_type"],
            fixture["rows"],
            filter_of_row,
        )
        path = os.path.join(out_dir, fixture["name"])
        with open(path, "wb") as handle:
            handle.write(data)
        print("%-18s %6d bytes" % (fixture["name"], len(data)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
