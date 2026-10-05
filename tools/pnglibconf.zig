// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md for what that identifier covers.
//
//! The deterministic `pnglibconf.h` generator for libpng 1.6.59.
//!
//! `build.zig` runs this on the *build machine* and gives it the vendored
//! prebuilt configuration header by path. It reads those bytes, checks the two
//! facts that make the file usable as `pnglibconf.h` for this release, and
//! writes them out unchanged. It writes exactly one output and nothing else.
//!
//! ## The upstream chain this stands in for
//!
//! Upstream generates `pnglibconf.h` from `scripts/pnglibconf.dfa` by running
//! three AWK programs, and this package does not run any of them:
//!
//!   * `src/Makefile.am:345-352` is the autotools rule that produces
//!     `pnglibconf.out` from the `.dfa` files, and it runs `options.awk` twice
//!     (`:347` and `:350`). `src/Makefile.am:335-341` is the generic `.c.out`
//!     suffix rule, which runs `scripts/dfn.awk` (`:340`) and is what produces
//!     `scripts/prefix.out` and `scripts/intprefix.out` from
//!     `scripts/pnglibconf.dfa` (`:257`, `:259`). `src/Makefile.am:287-289` then
//!     copies `pnglibconf.out` to `pnglibconf.h` in the non-`PNG_PREFIX` case
//!     this build is.
//!   * `src/CMakeLists.txt:488-518` is the CMake wiring for the same three
//!     scripts, configuring them into the binary directory (with `NEWLINE_STYLE
//!     LF`, for the Windows AWK CRLF limitation at `:471-476`) before running
//!     them.
//!   * `src/CMakeLists.txt:439` is the probe that decides whether that
//!     machinery runs at all: `find_program(AWK NAMES gawk nawk awk)`.
//!
//! When that probe finds nothing, upstream itself takes the path this program
//! takes. `src/CMakeLists.txt:457-462`:
//!
//!     elseif(NOT AWK)
//!       # No AWK program available to generate pnglibconf.h.
//!       # Configure libpng with pnglibconf.h.prebuilt.
//!       png_check_libconf(HEADER "${PNG_LIBCONF_HEADER_PREBUILT}")
//!       configure_file("${PNG_LIBCONF_HEADER_PREBUILT}"
//!                      "${CMAKE_CURRENT_BINARY_DIR}/pnglibconf.h" @ONLY)
//!       add_custom_target(png_genfiles)
//!     endif()
//!
//! and autotools says the same thing in prose: `src/Makefile.am:295-300` is the
//! rule that refuses to invent a `scripts/pnglibconf.h.prebuilt` and tells the
//! builder to make `pnglibconf.out` and "AND set PNG_ZLIB_VERNUM to 0 (you MUST
//! do this)". The prebuilt file is upstream's own, it is in the release tarball
//! at `src/scripts/pnglibconf.h.prebuilt`, and this package ships it unmodified.
//! Taking this path is not a shortcut invented here; it is one of the two
//! branches upstream writes and selects.
//!
//! This package also has no AWK to run: an AWK program is a host toolchain
//! dependency this build graph does not acquire, and shelling out to one would
//! make the build depend on whatever happens to be installed. So the AWK branch
//! is not selected here for a reason of portability, and the *same* bytes
//! upstream's no-AWK branch configures are what this program writes.
//!
//! ## What this program is and is not
//!
//! It is a validating copier, not a configuration generator. The output is
//! byte-identical to the input, so a diff of the generated `pnglibconf.h`
//! against `src/scripts/pnglibconf.h.prebuilt` is empty by construction, and
//! the vendored file stays the record of what the configuration is. Nothing
//! here merges a target's macros onto the file, and `builtin.target` appears
//! nowhere in this program: there is nothing target-dependent in the output to
//! be wrong about, which is the same property `mbed-tls/zig/config_gen.zig`
//! gets by receiving every fact as an argument.
//!
//! It validates rather than assuming, because the two checks below are the two
//! ways the prebuilt file can be the wrong file, and both would fail silently
//! or confusingly later:
//!
//!   * The banner `/* libpng version 1.6.59 */` is `src/scripts/pnglibconf.h
//!     .prebuilt:3`. A prebuilt header from another release would configure
//!     cleanly and describe a different library's options, so the banner is
//!     checked against `--expect-version` and the build stops if they differ.
//!   * The guard `#ifndef PNGLCONF_H` is
//!     `src/scripts/pnglibconf.h.prebuilt:15`, matched by the `#define
//!     PNGLCONF_H` on the next line. Without it the header's `#define`s would be
//!     re-read on a second inclusion and every option would be redefined.
//!
//! Both are checks that `build.zig` can also see failing; this program is
//! where they are made, because it is the program that would otherwise copy
//! the wrong bytes without noticing.
//!
//! ## The one behavioural consequence
//!
//! `src/scripts/pnglibconf.h.prebuilt:226` is
//! `#define PNG_ZLIB_VERNUM 0 /* unknown */`. `src/pngpriv.h:1026-1028` is
//! the only place that value is read:
//!
//!     #if PNG_ZLIB_VERNUM != 0 && PNG_ZLIB_VERNUM != ZLIB_VERNUM
//!     #  error The include path of <zlib.h> is incorrect
//!
//! With the value at 0 the first conjunct is false, so the check is skipped
//! entirely: this build does not re-verify that the `<zlib.h>` on the include
//! path is the same revision the configuration header was generated against.
//! That is a *compile-time consistency check between two files of one
//! autotools build*, not a runtime behaviour of libpng - the error it would
//! raise is an `#error` at preprocessing time, and no `png_*` function changes
//! what it does either way. `PNG_Z_DEFAULT_COMPRESSION`,
//! `PNG_Z_DEFAULT_STRATEGY`, `PNG_ZLIB_VERNUM` and the rest of the zlib-related
//! options in the prebuilt file carry their real values, so zlib's presence,
//! its decompression and its version-adaptive code paths are all configured as
//! upstream configures them; only the redundant cross-check is off. That is
//! upstream's own documented trade for this branch, named at
//! `src/Makefile.am:299`.

const std = @import("std");
const Io = std.Io;

/// Everything this program can refuse, in its own words: each one names an
/// invariant that broke, so a build log says which check fired instead of
/// printing a bare `error`. The allocator's own error set is folded in because
/// every allocation here can fail with it.
///
/// `main`'s error set is wider than this one, because the two filesystem calls
/// add theirs; nothing below returns an error that is not named here or
/// borrowed from the standard library.
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

/// The command line. Every field is required; there is no default for any of
/// them, so a caller that forgets one is refused rather than silently pointed
/// somewhere else.
const Options = struct {
    /// `--input`: the vendored `scripts/pnglibconf.h.prebuilt`.
    input: []const u8 = "",
    /// `--output`: where the validated bytes are written. Only this path is
    /// written, and only after both checks have passed.
    output: []const u8 = "",
    /// `--expect-version`: the release the banner must name, without the `v`
    /// and without the `/* ... */`. `build.zig` passes the same string
    /// `src/png.h:277` carries, so the header and the manifest cannot disagree
    /// without this program refusing.
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

/// Consumes the value that follows a flag.
///
/// A flag with no value after it yields the empty string, which every
/// `Options.parse` check above then refuses. The index is only advanced when
/// there is something to advance onto, so a trailing `--input` cannot run off
/// the end of the argument list.
fn take(args: []const [:0]const u8, index: *usize) []const u8 {
    if (index.* + 1 >= args.len) return "";
    index.* += 1;
    return args[index.*];
}

/// The include guard this program requires, and its line in the vendored file.
const include_guard = "#ifndef PNGLCONF_H";

/// The release whose configuration this package compiles, read out of
/// `src/png.h:277` (`PNG_LIBPNG_VER_STRING "1.6.59"`), `src/png.h:286-288`
/// (the three components) and `src/png.h:319` (`PNG_LIBPNG_VER 10659`).
///
/// It appears here only as the value `build.zig` is expected to pass as
/// `--expect-version`, and in the two refusal messages below. It is not a
/// default: `--expect-version` is required, so this constant cannot quietly
/// make the check pass for a `--input` from another release.
const compiled_release = "1.6.59";

/// Writes the validated bytes and returns nothing on success.
///
/// The file is read once, both checks run against those bytes, and the write
/// happens only after both have passed - so a rejected input leaves no output
/// file behind for a later step to find.
pub fn main(init: std.process.Init) !void {
    // `init.arena` is the process-lifetime allocator `std.process.Init` already
    // owns and frees on exit, so nothing here has to be released by hand. Every
    // allocation below - the arguments, the input bytes, the two printed
    // strings - lives exactly as long as this program does.
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const options = Options.parse(args) catch |err| {
        usage();
        return err;
    };

    // The vendored prebuilt header is 8 090 bytes upstream; 8 MiB is a ceiling,
    // not a budget, and it is there so a wrong `--input` pointing at some other
    // file in this repository cannot be slurped whole.
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
        // Read out of the file rather than assumed: this program states the
        // line number in its own report so a reader can go and look.
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

    // The banner is checked as a whole line rather than as a substring, so a
    // file that merely mentions the release inside some other comment cannot
    // pass. Exactly one banner line must be present, and it must be the
    // expected one: two distinct banners is a file that is neither release.
    // `++` is comptime-only on a slice, and `options.expect_version` is a
    // runtime argument, so the banner is formatted into the process arena.
    const want_banner = try std.fmt.allocPrint(
        arena,
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

    // Byte-identical, which is the whole point: `const bytes`, not a
    // re-render. A generated `pnglibconf.h` that differed from the vendored
    // file by even one byte would be a second configuration with no record of
    // where it came from.
    try Io.Dir.cwd().writeFile(init.io, .{
        .sub_path = options.output,
        .data = bytes,
    });

    std.debug.print(
        "tools/pnglibconf.zig: wrote {d} bytes to {s} (banner '{s}', guard '{s}')\n",
        .{ bytes.len, options.output, want_banner, include_guard },
    );
}

/// The one-based line number of `at` in `bytes`.
fn lineOf(bytes: []const u8, at: usize) usize {
    var line: usize = 1;
    for (bytes[0..at]) |byte| {
        if (byte == '\n') line += 1;
    }
    return line;
}

/// The first bytes of a rejected input, as hex, for a message.
///
/// Hex rather than text, because the input of a rejection is by definition not
/// the text this program expected and printing it as text would put whatever
/// bytes are in it into a terminal.
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