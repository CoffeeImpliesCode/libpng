// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md for what that identifier covers.
//
//! Validates and copies libpng's vendored prebuilt configuration header.
//! Checks the release banner and include guard, then preserves the input bytes.

const std = @import("std");
const Io = std.Io;

/// Errors for invalid arguments or configuration; allocation errors are included.
pub const Failure = error{
    UnknownArgument,
    MissingInput,
    MissingOutput,
    MissingExpectedVersion,
    MissingBanner,
    UnexpectedBanner,
    MissingIncludeGuard,
    EmptyInput,
} || std.mem.Allocator.Error;

/// Required command-line paths and release identifier.
const Options = struct {
    /// Vendored `pnglibconf.h.prebuilt` input path.
    input: []const u8 = "",
    /// Output path, written only after both checks pass.
    output: []const u8 = "",
    /// Expected release string, without the `v` prefix.
    expect_version: []const u8 = "",

    fn parse(args: []const [:0]const u8) Failure!Options {
        var self: Options = .{};
        var index: usize = 1;
        while (index < args.len) : (index += 1) {
            const flag = args[index];
            const value = take(args, &index);
            if (std.mem.eql(u8, flag, "--input")) {
                self.input = value;
            } else if (std.mem.eql(u8, flag, "--output")) {
                self.output = value;
            } else if (std.mem.eql(u8, flag, "--expect-version")) {
                self.expect_version = value;
            } else {
                std.debug.print(
                    "tools/pnglibconf.zig: unknown argument '{s}'; the only three " ++
                        "are --input, --output and --expect-version\n",
                    .{flag},
                );
                return error.UnknownArgument;
            }
        }
        if (self.input.len == 0) return error.MissingInput;
        if (self.output.len == 0) return error.MissingOutput;
        if (self.expect_version.len == 0) return error.MissingExpectedVersion;
        return self;
    }
};

/// Returns an empty value for a trailing flag without advancing past the arguments.
fn take(args: []const [:0]const u8, index: *usize) []const u8 {
    if (index.* + 1 >= args.len) return "";
    index.* += 1;
    return args[index.*];
}

/// Required include guard in the vendored file.
const include_guard = "#ifndef PNGLCONF_H";

/// Version read from upstream headers and checked against `--expect-version`.
const compiled_release = "1.6.59";

/// Validate and copy the prebuilt bytes unchanged.
pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const options = Options.parse(args) catch |err| {
        usage();
        return err;
    };

    // Cap input size so a mistaken path cannot read an unexpectedly large file.
    const bytes = try Io.Dir.cwd().readFileAlloc(
        init.io,
        options.input,
        arena,
        .limited(8 * 1024 * 1024),
    );

    if (bytes.len == 0) {
        std.debug.print(
            "tools/pnglibconf.zig: {s} is empty; a zero-length configuration header " ++
                "would leave every PNG_*_SUPPORTED macro undefined\n",
            .{options.input},
        );
        return error.EmptyInput;
    }

    if (std.mem.indexOf(u8, bytes, include_guard)) |guard_at| {
        // Report the guard's source line.
        std.debug.print(
            "tools/pnglibconf.zig: {s}:{d}: include guard '{s}' found\n",
            .{ options.input, lineOf(bytes, guard_at), include_guard },
        );
    } else {
        std.debug.print(
            "tools/pnglibconf.zig: {s} has no '{s}' line, so it is not a " ++
                "pnglibconf.h: src/pngpriv.h:81 includes it by that exact name " ++
                "and every PNG_* option it carries would be undefined\n",
            .{ options.input, include_guard },
        );
        std.debug.print("  first bytes (hex): {s}\n", .{preview(arena, bytes)});
        return error.MissingIncludeGuard;
    }

    // Require exactly one complete banner line, not a substring match.
    const want_banner = try arena.print(
        "/* libpng version {s} */",
        .{options.expect_version},
    );
    const banner_prefix = "/* libpng version ";
    var banner_count: usize = 0;
    var found_banner = false;
    var it = std.mem.splitScalar(u8, bytes, '\n');
    while (it.next()) |raw| {
        const line = std.mem.trim(u8, raw, " \t\r");
        if (std.mem.eql(u8, line, want_banner)) {
            found_banner = true;
            banner_count += 1;
            continue;
        }
        if (std.mem.startsWith(u8, line, banner_prefix) and
            std.mem.endsWith(u8, line, "*/"))
        {
            banner_count += 1;
        }
    }
    if (!found_banner) {
        std.debug.print(
            "tools/pnglibconf.zig: {s} does not carry the banner line '{s}'.\n",
            .{ options.input, want_banner },
        );
        std.debug.print(
            "  Upstream's no-AWK path (src/CMakeLists.txt:457-462) configures the\n" ++
                "  file for the release the tree is at, so a prebuilt header from\n" ++
                "  another release describes a different library's options and must\n" ++
                "  not be compiled against this source. This package compiles " ++
                "{s}.\n",
            .{compiled_release},
        );
        return error.MissingBanner;
    }
    if (banner_count != 1) {
        std.debug.print(
            "tools/pnglibconf.zig: {s} carries {d} version banner lines, not 1\n",
            .{ options.input, banner_count },
        );
        return error.UnexpectedBanner;
    }

    // Copy the validated bytes unchanged.
    try Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = options.output,
        .data = bytes,
    });

    std.debug.print(
        "tools/pnglibconf.zig: wrote {d} bytes to {s} (banner '{s}', guard '{s}')\n",
        .{ bytes.len, options.output, want_banner, include_guard },
    );
}

/// Returns the one-based line number containing `at`.
fn lineOf(bytes: []const u8, at: usize) usize {
    var line: usize = 1;
    for (bytes[0..at]) |byte| {
        if (byte == '\n') line += 1;
    }
    return line;
}

/// Hex avoids writing arbitrary rejected input bytes to the terminal.
fn preview(arena: std.mem.Allocator, bytes: []const u8) []const u8 {
    const window: usize = 32;
    const head = bytes[0..@min(window, bytes.len)];
    const digits = "0123456789abcdef";
    var out: std.ArrayList(u8) = .empty;
    for (head) |byte| {
        out.appendSlice(arena, &.{ digits[byte >> 4], digits[byte & 0x0f], ' ' }) catch break;
    }
    if (bytes.len > window) out.appendSlice(arena, "...") catch {};
    return out.items;
}

fn usage() void {
    std.debug.print(
        \\
        \\usage: pnglibconf.zig --input <scripts/pnglibconf.h.prebuilt>
        \\                      --output <pnglibconf.h>
        \\                      --expect-version <1.6.59>
        \\
        \\Validates upstream's own prebuilt configuration header for this release
        \\and copies it out byte for byte. This is the path upstream's own CMake
        \\build takes when no AWK program is available to generate pnglibconf.h
        \\from scripts/pnglibconf.dfa (src/CMakeLists.txt:457-462); see this file's
        \\header for the whole chain.
        \\
    , .{});
}
