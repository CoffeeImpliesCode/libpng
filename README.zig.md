# Consuming the libpng SDK

Four ways in, one library underneath. Nothing here claims a route works: **no
gate has been run for this package**, and the examples are written against the
interfaces the package publishes, not against an observed run. Where a fact is
read out of upstream source it is cited; where it is a decision of this fork it
names the file that makes it.

## The two names, and why they are one string apart on purpose

| | |
|---|---|
| Zig module name | `libpng` → `dep.module("libpng")`, `@import("libpng")` |
| C artifact name | `png16` → `dep.artifact("png16")`, emitting `libpng16.a` and `libpng16.so.16.59.0` |

Zig prepends the platform's `lib` prefix to an artifact name, which is what makes
the emitted files carry the names upstream's own build produces:
`lib_LTLIBRARIES=libpng@PNGLIB_MAJOR@@PNGLIB_MINOR@.la` is `libpng16`
(`src/Makefile.am:125`), and `-version-number
@PNGLIB_MAJOR@@PNGLIB_MINOR@:@PNGLIB_RELEASE@:0` is `16:59:0`
(`src/Makefile.am:178-180`), which is what produces
`libpng16.so.16.59.0` with soname `libpng16.so.16`. The `16` is the ABI number
upstream states itself at `src/png.h:281`
(`PNG_LIBPNG_VER_SHAREDLIB 16`).

Neither name is a typo and neither may be changed to match the other.

## 1. The typed Zig surface

```zig
// build.zig.zon of the dependent
.dependencies = .{
    .libpng = .{ .path = "../libpng/libpng" },
},
```

```zig
// build.zig of the dependent
const target = b.standardTargetOptions(.{});
const optimize = b.standardOptimizeOption(.{});

const dep = b.dependency("libpng", .{ .target = target, .optimize = optimize });

const libpng = dep.module("libpng");
exe_mod.addImport("libpng", libpng);
exe_mod.linkLibrary(dep.artifact("png16"));   // the C side of the same library
```

```zig
// src/main.zig of the dependent
const libpng = @import("libpng");
```

`dep.module("libpng")` is the **typed facade**, published by `zig/root.zig`: a
documented Zig surface over the same library. It is one module, not two — there
is no separate "libpng headers" module to register.

### What that module exposes

| Name | What it is |
|---|---|
| the facade itself | typed Zig functions over the C library, documented in the source |
| `pub const c` | **the raw escape hatch**: the translated C declarations, exactly as `png.h` and `pngconf.h` declare them |
| `pub const runtime_loaded` | `comptime bool` — whether this build took the runtime-loading route |
| `pub const load` | the runtime load, when `runtime_loaded` is true |
| `pub const loadedSource` | where the loaded library came from: an explicit `.path`, or a named `.system` |
| `pub const unload` | release the loaded table |
| `LoadSource`, `LoadError` | re-exported from the `rt` module |

`pub const c` is the honest escape hatch and the one to reach for when the typed
surface has not wrapped something you need. It is the *translated C*, not a
second hand-written binding: it is what `zig translate-c` produced from
`zig/translate.h`, so it cannot disagree with what was compiled.

### The one include-order requirement, and it is upstream's shape

`zig/translate.h` includes **`<stdio.h>` and `<setjmp.h>` before `<png.h>`**,
and an installed C consumer is expected to do the same. That is not a quirk of
this fork's wrapper; it follows from upstream's own header:

* `src/png.h`'s entire include closure is `pnglibconf.h` (`src/png.h:328`) and
  `pngconf.h` (`src/png.h:333`).
* `src/pngconf.h:30-31` includes only `<limits.h>` and `<stddef.h>`.
* Yet `src/png.h:1629` declares `png_init_io(png_structrp png_ptr, FILE *fp)`
  under `PNG_STDIO_SUPPORTED`, and `src/png.h:971` declares
  `png_set_longjmp_fn(..., jmp_buf *, ...)` under `PNG_SETJMP_SUPPORTED`.

So `FILE` and `jmp_buf` have to be in scope before `png.h` is parsed. `FILE *`
and `jmp_buf` are read here in those two declarations; `zig/translate.h` supplies
both headers, and says so in its own comment.

## 2. The raw C route from Zig

`pub const c` is the same thing as route 1's escape hatch, and is worth naming
separately because it is the honest way to use a C binding you have not wrapped:

```zig
const libpng = @import("libpng");
const c = libpng.c;

pub fn main() !void {
    const version = c.png_access_version_number();   // 10659 for libpng 1.6.59
    _ = version;
}
```

`png_access_version_number` is declared at `src/png.h:920` and its contract is
`src/png.h:319` (`#define PNG_LIBPNG_VER 10659 /* 1.6.59 */`);
`png_get_libpng_ver` is declared at `src/png.h:2574` and its contract is
`src/png.h:277` (`#define PNG_LIBPNG_VER_STRING "1.6.59"`).

**There is no version symbol to look up at load time.** libpng exports no
`libpng_version()` function; those macros are compile-time constants in the
generated `pnglibconf.h`. The two functions above are the load-time check that
exists, and it is an ABI check rather than a name check — which is the honest
form of the question.

## 3. The C route

A C consumer, or a C translation unit inside a Zig build, takes the artifact:

```zig
const dep = b.dependency("libpng", .{ .target = target, .optimize = optimize });
c_mod.linkLibrary(dep.artifact("png16"));
```

and the include path comes from the artifact's installed headers. That is also
why `dep.artifact("zlib")` has to be linked into the dependency chain: libpng is
a zlib binding, `src/pngpriv.h` and `src/png.c` include `<zlib.h>` and call
`inflateInit2_`/`deflateInit2_`, and linking the zlib artifact is what puts its
`zlib.h` and `zconf.h` on the include line
(`lib/std/Build/Module.zig:649-659`, `:183-184`). No separate `-I` is written
anywhere in this package. The wire was a `PENDING-VERIFICATION` while the zlib
tree was still absent from disk; on 2026-10-05 `zig build` exited 0 and
`zig build check` compiled this package's 15 units, its generated
`pnglibconf.h`, the facade and the example for five of the six targets with the
sibling zlib's library and its per-target `zconf.h` generator on the chain. The
`wasm32-wasi` row failed for the unrelated reason in
[`FORK-NOTES.md`](FORK-NOTES.md) §5. What is still unproven by that is the
*behaviour*: no test or smoke binary has been executed for this package.

## 4. The installed tree

`zig build install --prefix <dir>` lays out:

```
<dir>/include/libpng16/png.h
<dir>/include/libpng16/pngconf.h
<dir>/include/libpng16/pnglibconf.h        # generated, not a file in src/
<dir>/lib/libpng16.a                        # -Dlinkage=static (default)
<dir>/lib/libpng16.so.16.59.0               # -Dlinkage=dynamic
<dir>/lib/libpng16.so.16                    # soname link
<dir>/lib/libpng16.so                       # linker name
<dir>/lib/pkgconfig/libpng16.pc
<dir>/share/man/man3/libpng.3
<dir>/share/man/man3/libpngpf.3
<dir>/share/man/man5/png.5
<dir>/share/licenses/...
```

* The `libpng16` include subdirectory is upstream's own choice:
  `pkgincludedir = $(includedir)/$(PNGLIB_BASENAME)` (`src/Makefile.am:205`) and
  `pkginclude_HEADERS = png.h pngconf.h` with
  `nodist_pkginclude_HEADERS = pnglibconf.h` (`src/Makefile.am:206-207`).
* `pnglibconf.h` in that directory is the **generated** header, not a copy of
  `src/scripts/pnglibconf.h.prebuilt` under a new name; that prebuilt file is
  what the generator reads.
* The `.pc` file is upstream's own `src/libpng.pc.in`, named by
  `pkgconfig_DATA = libpng@PNGLIB_MAJOR@@PNGLIB_MINOR@.pc`
  (`src/Makefile.am:212`). It declares `Requires.private: zlib` and
  `Cflags: -I${includedir}` with `includedir=@includedir@/libpng@...`, so a
  consumer that links statically still resolves zlib through pkg-config.
* The three man pages are upstream's `dist_man_MANS = libpng.3 libpngpf.3 png.5`
  (`src/Makefile.am:117`).

An installed C consumer needs `<stdio.h>` before `png.h>`, for the reason in
"the one include-order requirement" above.

## 5. The runtime-loading route

`-Druntime=true` selects the load-at-runtime route instead of direct linkage. It
is orthogonal to `-Dlinkage`.

Its properties, which are design rules rather than observations:

* **Explicit selection.** A `.path` naming one file, or a `.system` naming one
  provider. **No fallback**: if the named thing is not there, the load fails and
  says so.
* **One process-lifetime table.** Every call goes through it.
* **Atomic publication.** The table is published whole or not at all; no caller
  ever sees a half-populated table.
* **Explicit retry.** After a failed load, a later `load` tries again — because
  retry is the caller's decision, not something that happens silently.
* **An ordinary panic before initialization**, in every optimize mode — not
  `std.debug.assert`, which a release build compiles out, and not a silently
  ignored null table.

`runtime_loaded` is `comptime`, so a build knows which route it has without a
runtime query, and the linked route stays direct: no indirect call, no table.

## A worked example

A Zig program that decodes a fixture through the raw C surface and prints what
the library reports. This is the shape a dependent writes; **this program has not
been run**, because no test, smoke or consumer run has been observed for this
package. `zig build` and `zig build check` compile this package and its example,
which is a type-level fact and not a behavioural one. Every declaration the
example names was read out of `src/png.h` and is cited below.

```zig
// src/main.zig
const std = @import("std");
const libpng = @import("libpng");

pub fn main() !void {
    const c = libpng.c;

    // The ABI check that exists. libpng exports no version symbol.
    std.debug.print("libpng reports {d}\n", .{c.png_access_version_number()});

    // Read a fixture through the simplified API, which allocates and frees
    // the libpng-side state itself.
    var image: c.png_image = std.mem.zeroes(c.png_image);
    image.version = c.PNG_IMAGE_VERSION;          // src/png.h:2916, :2922

    // PNG_FORMAT_RGBA is 6 in src/png.h's own format table.
    image.format = 6;

    const path = "fixtures/rgba2x2.png";
    const path_z = try std.fmt.allocPrintSentinel(
        std.heap.page_allocator, "{s}", .{path}, 0,
    );
    defer std.heap.page_allocator.free(path_z);

    if (c.png_image_begin_read_from_file(&image, path_z.ptr) == 0) {
        // image.message holds libpng's own error text (src/png.h:2929-2945).
        std.debug.print("read failed: {s}\n", .{std.mem.span(image.message)});
        return error.PngReadFailed;
    }
    defer c.png_image_free(&image);                // src/png.h:3278-3282

    std.debug.print("{d}x{d}\n", .{ image.width, image.height });

    const pixels = try std.heap.page_allocator.alloc(u8, 2 * 2 * 4);
    defer std.heap.page_allocator.free(pixels);

    if (c.png_image_finish_read(&image, null, pixels.ptr, 2 * 4, null) == 0) {
        std.debug.print("decode failed: {s}\n", .{std.mem.span(image.message)});
        return error.PngDecodeFailed;
    }

    // The independent known answer, from UPSTREAM.md: the top-left pixel is
    // (0,0,0,0) and the top-right is (255,0,0,64).
    std.debug.print("{d} {d} {d} {d}\n", .{
        pixels[0], pixels[1], pixels[2], pixels[3],
    });
}
```

and the `build.zig` that builds it:

```zig
const exe = b.addExecutable(.{
    .name = "read-a-png",
    .root_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    }),
});

const dep = b.dependency("libpng", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("libpng", dep.module("libpng"));
exe.root_module.linkLibrary(dep.artifact("png16"));

b.installArtifact(exe);
```

The declarations this example rests on, each read out of the vendored header:
`png_access_version_number` (`src/png.h:920`, contract at `src/png.h:319`);
`png_image` and `PNG_IMAGE_VERSION` (`src/png.h:2916`, `:2919-2922`);
`png_image_begin_read_from_file` (`src/png.h:3227`);
`png_image_finish_read` (`src/png.h:3242`);
`png_image_free` (`src/png.h:3278`).

Four things in that example are worth calling out, because they are the parts
people get wrong:

1. **`version` must be set before the first call.** `src/png.h:2885` states it
   as a step of the documented sequence, and `src/png.h:2921` says the `opaque`
   pointer is initialised to NULL. Zeroing the struct with
   `std.mem.zeroes` is what supplies both.
2. **`linkLibrary` is not optional.** Importing the module alone gives you the
   declarations; the archive has to be linked for anything to resolve.
3. **`png_image_free` releases what libpng allocated.** libpng's own default
   allocator is the C library's, so `std.testing.allocator` cannot be a leak
   oracle for the inside of a `png_image`. The ownership transition is what a
   test can prove, and that is what the `defer` is.
4. **The version check is `png_access_version_number()`, not a symbol lookup.**
   libpng exports no version function.

## The behaviour to check, and what it does not prove

A decoded fixture matching its expected pixels is an **independent known
answer** — the pixels were computed by hand from ISO/IEC 15948 and written down
in [`UPSTREAM.md`](UPSTREAM.md) before anything was run. That is a different
kind of evidence from a round trip, which would only prove the code agrees with
itself.

Conversely, none of the following proves anything and none of them appears here
as a test: that the archive compiled, that `zig fmt` exited 0, that a facade
function forwards to its raw member, or that a call did not throw.