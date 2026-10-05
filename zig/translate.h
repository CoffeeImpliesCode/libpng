/* SPDX-License-Identifier: MIT */
/* See ../FORK-LICENSE.md for what that identifier covers. */

/* The one header this package translates.
 *
 * `zig build` runs translate-c over this file, and what that translation
 * becomes is the `c` module the Zig facade in zig/root.zig imports. Its whole
 * job is to name the public headers of the library this build compiles.
 *
 * Which headers those are
 * -----------------------
 * libpng 1.6.59 names two installed source headers (src/Makefile.am:204-207)
 * and one generated one, and this wrapper names the two source headers:
 *
 *   png.h         the core API. It includes `pnglibconf.h` itself
 *                 (src/png.h:328) and `pngconf.h` (src/png.h:333), and
 *                 those two are the *whole* of its include closure inside this
 *                 repository: those are the only two `#include` directives in
 *                 src/png.h.
 *   pngconf.h     the machine and platform configuration. src/png.h reaches
 *                 it, so including it separately adds nothing that is not
 *                 already reachable, and it is listed for the same reason
 *                 libpng lists it as installed: a reader of this file should
 *                 see the complete public header set named in one place.
 *
 * So two are named, not three: `pkginclude_HEADERS` at src/Makefile.am:206 is
 * exactly `png.h pngconf.h`, and `:207` adds the generated `pnglibconf.h` as a
 * `nodist_` header. `build.zig` installs those three and no fourth.
 *
 * Both are included whole, with their own include guards, so this wrapper
 * cannot disagree with the real headers by omission and cannot re-declare a
 * prototype with a different type.
 *
 * Why pnglibconf.h is not listed separately
 * ------------------------------------------
 * It is a *generated* configuration header, not a declaration surface: nothing
 * in it declares a function. It reaches the translation through png.h
 * (src/png.h:328), so the `PNG_*_SUPPORTED` macros that decide which
 * declarations exist at all are the same ones the compiled C saw. The build
 * generates that file into a directory placed before `src/` on the include
 * line; see build.zig and tools/pnglibconf.zig.
 *
 * Two headers of the C library, and why they are here
 * ---------------------------------------------------
 * `src/pngconf.h:30-31` opens `<limits.h>` and `<stddef.h>` and nothing else, so
 * png.h's whole closure reaches no other system header. Two declarations in
 * png.h nevertheless name types those two do not provide, and both are inside
 * `#ifdef`s that the configuration this build generates turns on:
 *
 *   * `png_init_io` is declared `PNG_EXPORT(74, void, png_init_io,
 *     (png_structrp png_ptr, FILE *fp))` under `PNG_STDIO_SUPPORTED`
 *     (src/png.h:1628-1630), and `PNG_STDIO_SUPPORTED` is defined in the
 *     configuration this build uses (src/scripts/pnglibconf.h.prebuilt:124).
 *     `FILE` is defined by `<stdio.h>`, which nothing in png.h's closure opens.
 *   * `png_set_longjmp_fn` is declared `PNG_EXPORT(8, jmp_buf*, png_set_longjmp_fn,
 *     (png_structrp png_ptr, png_longjmp_ptr longjmp_fn, size_t jmp_buf_size))`
 *     under `PNG_SETJMP_SUPPORTED` (src/png.h:971-972), and that macro is also
 *     defined in this configuration (src/scripts/pnglibconf.h.prebuilt:113).
 *     `jmp_buf` is defined by `<setjmp.h>`, and png.h says so itself:
 *     "This must match the function definition in <setjmp.h>, and the
 *     application must include this before png.h to obtain the definition of
 *     jmp_buf." (src/png.h:835-837).
 *
 * Both are therefore included *before* `<png.h>` here. This is not a
 * convenience: without them the translation of png.h does not compile in this
 * configuration, because the two declarations above name types no reached
 * header defines.
 *
 * An installed C consumer needs exactly the same two lines, in the same order,
 * for the same reason. `png.h` does not include them itself and says at
 * src/png.h:835-837 that the application must supply `<setjmp.h>` first; the
 * `FILE` case is the same situation one declaration later. A consumer that
 * includes `<png.h>` alone gets a diagnostic from its own compiler about an
 * incomplete `FILE`/`jmp_buf`.
 *
 * What is deliberately not here
 * -----------------------------
 * A copy of any declaration, and no macro of this build's own.
 *
 * `pngpriv.h`, `pngstruct.h`, `pngdebug.h` and `pngusr.dfa` are not included,
 * because they are not part of the installed header set (src/Makefile.am:204-
 * 207) and are not public API:
 *
 *   pngpriv.h    is libpng's internal declarations. It names private state,
 *                private functions and, at src/pngpriv.h:1026-1028, an `#error`
 *                that fires when the `zlib.h` seen while building the library
 *                was not the one it was configured against. A consumer that
 *                included it would be compiling against a private ABI that
 *                changes between releases under the same header names.
 *   pngstruct.h  defines `struct png_struct_def` (src/pngstruct.h:122), the
 *                layout of the opaque `png_struct`. src/png.h:437 deliberately
 *                forward-declares it and keeps the definition out of the public
 *                header so that a caller cannot depend on the layout.
 *   pngdebug.h   installs the `png_debug`/`png_debug1`... debug machinery.
 *                It is a debugging aid for building libpng, not an interface.
 *   pngusr.dfa   is the source for upstream's symbol-version script
 *                (`libpng.sym`, src/Makefile.am:192-193): a grammar for a
 *                build-time tool, not a header at all.
 *
 * A `PNG_*` macro that selects a code path inside libpng's own `.c` units is
 * likewise not here. Those are on the compile line in build.zig, so the code
 * compiled and the declarations translated are the same build.
 */

#ifndef LIBPNG_TRANSLATE_H
#define LIBPNG_TRANSLATE_H

/* See the comment above: png.h's own closure reaches neither of these. */
#include <stdio.h>
#include <setjmp.h>

#include <png.h>
#include <pngconf.h>

#endif /* LIBPNG_TRANSLATE_H */