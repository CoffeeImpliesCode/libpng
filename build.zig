// SPDX-License-Identifier: MIT

const std = @import("std");

/// Keep `LoadSource` and `LoadError` identical in linked and runtime builds.
const graph = @import("runtime/graph.zig");

const manifest = @import("build.zig.zon");

const manifest_version = std.SemanticVersion.parse(manifest.version) catch
    @panic("build.zig.zon: .version is not a semantic version");

const facade_source = "zig/root.zig";

const translate_header = "zig/translate.h";

const test_source = "tests.zig";

const example_source = "smoke.zig";
const generator_source = "tools/pnglibconf.zig";

/// Upstream's no-AWK `pnglibconf.h` input (src/CMakeLists.txt:457-462).
const prebuilt_libconf = "src/scripts/pnglibconf.h.prebuilt";

const source_dir = "src";

const lib_name = "libpng";

/// C artifact name; Zig adds the platform prefix (src/Makefile.am:125).
const artifact_name = "png16";

const zlib_package = "zlib";

/// Release version from upstream's `png.h`; checked against the manifest.
const upstream_version: std.SemanticVersion = .{ .major = 1, .minor = 6, .patch = 59 };

/// Shared-object ABI version from upstream's libtool flags (src/Makefile.am:178-179).
const abi_version: std.SemanticVersion = .{ .major = 16, .minor = 59, .patch = 0 };

/// Upstream's compiled C units (src/Makefile.am:127-129).
const core_sources = [_][]const u8{
    "src/png.c",
    "src/pngerror.c",
    "src/pngget.c",
    "src/pngmem.c",
    "src/pngpread.c",
    "src/pngread.c",
    "src/pngrio.c",
    "src/pngrtran.c",
    "src/pngrutil.c",
    "src/pngset.c",
    "src/pngtrans.c",
    "src/pngwio.c",
    "src/pngwrite.c",
    "src/pngwtran.c",
    "src/pngwutil.c",
};

/// Disable all upstream `PNG_*_OPT` architecture units not compiled here.
/// The macros and off values are defined by `src/pngpriv.h:136-225`.
const simd_opt_macros = [_][]const u8{
    "PNG_ARM_NEON_OPT",
    "PNG_INTEL_SSE_OPT",
    "PNG_MIPS_MSA_OPT",
    "PNG_MIPS_MMI_OPT",
    "PNG_POWERPC_VSX_OPT",
    "PNG_LOONGARCH_LSX_OPT",
    "PNG_RISCV_RVV_OPT",
};

const PublicHeader = struct {
    source: []const u8,
    basename: []const u8,
    generated: bool,
};

const public_headers = [_]PublicHeader{
    .{ .source = "src/png.h", .basename = "png.h", .generated = false },
    .{ .source = "src/pngconf.h", .basename = "pngconf.h", .generated = false },
    .{ .source = "pnglibconf.h", .basename = "pnglibconf.h", .generated = true },
};

const ManPage = struct {
    source: []const u8,
    section: []const u8,
};

const man_pages = [_]ManPage{
    .{ .source = "src/libpng.3", .section = "man3" },
    .{ .source = "src/libpngpf.3", .section = "man3" },
    .{ .source = "src/png.5", .section = "man5" },
};

const licence_records = [_][]const u8{
    "src/LICENSE",
    "src/example.c",
    "src/REUSE.toml",
    "README.upstream.md",
    "NOTICE.md",
    "FORK-LICENSE.md",
    "UPSTREAM.md",
    "UPSTREAM.sha256",
    "FORK-NOTES.md",
    "CHANGELOG.md",
};

/// Pin the C dialect; upstream requires C89 compliance (`src/pngconf.h:25-34`).
const c_flags = [_][]const u8{"-std=gnu99"};
const wasi_c_flags = c_flags ++ [_][]const u8{ "-mllvm", "-wasm-enable-sjlj" };

/// Default compile-check targets; WASI `setjmp.h` requires exception handling
/// when `PNG_SETJMP_SUPPORTED` is enabled (`src/pngconf.h:48-50`).
const check_targets = [_]std.Target.Query{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .aarch64, .os_tag = .macos, .abi = .none },
    .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu },
    .{ .cpu_arch = .riscv64, .os_tag = .linux, .abi = .gnu },
    .{ .cpu_arch = .wasm32, .os_tag = .wasi },
};

const refused_check_targets = [_]std.Target.Query{};

fn artifactLabel(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    public: bool,
) []const u8 {
    if (public) return artifact_name;
    const triple = target.result.zigTriple(b.allocator) catch @panic("unspellable target");
    return b.fmt("{s}-{s}-{s}", .{ artifact_name, lib_name, triple });
}

/// Match Clang's RISC-V float-ABI macro for Aro translation.
/// glibc has no `jmp_buf` layout for single-float ABI (`bits/setjmp.h:32-36`);
/// derive the macro from the target, never the host.
const Graph = struct {
    c_lib: *std.Build.Step.Compile,
    module: *std.Build.Module,
};
fn translateCRiscvFloatAbi(target: std.Build.ResolvedTarget) ?[2][]const u8 {
    switch (target.result.cpu.arch) {
        .riscv32, .riscv32be, .riscv64, .riscv64be => {},
        else => return null,
    }
    const abi: []const u8 = if (std.Target.riscv.featureSetHas(target.result.cpu.features, .d))
        "__riscv_float_abi_double"
    else if (std.Target.riscv.featureSetHas(target.result.cpu.features, .f))
        "__riscv_float_abi_single"
    else
        "__riscv_float_abi_soft";
    return .{ abi, "1" };
}

fn configureTarget(b: *std.Build, target: std.Build.ResolvedTarget) std.Build.ResolvedTarget {
    if (target.result.os.tag != .wasi) return target;
    // libpng's public longjmp API requires WASI's exception-handling extension.
    var query = target.query;
    query.cpu_features_add.addFeature(@backingInt(std.Target.wasm.Feature.exception_handling));
    return b.resolveTargetQuery(query);
}

/// Build one target graph; cross-target checks use private modules.
fn addGraph(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    linkage: std.lang.LinkMode,
    runtime_loaded: bool,
    public: bool,
    libconf: std.Build.LazyPath,
) Graph {
    if (refusalFor(target.result.os.tag) != null) refuseTarget(b, target);

    // Resolve linkage once so compilation and translation use the same mode.
    const delivered = deliveredLinkage(target, linkage);

    const zlib_dep = b.dependency(zlib_package, .{
        .target = target,
        .optimize = optimize,
    });
    const zlib_lib = zlib_dep.artifact(zlib_package);
    if (public) {
        // Plain C static consumers need the same archive used by the Zig graph.
        b.installArtifact(zlib_lib);
        const zlib_license = b.addInstallFileWithDir(
            zlib_dep.path("src/LICENSE"),
            .prefix,
            "share/licenses/zlib/LICENSE",
        );
        b.getInstallStep().dependOn(&zlib_license.step);
    }

    // Share one generated `pnglibconf.h` step across target graphs.
    const c_lib = add_c_library(
        b,
        target,
        optimize,
        delivered,
        artifactLabel(b, target, public),
        libconf,
        zlib_lib,
    );

    // Put the generated header directory before `src` for bare-name includes.
    const translate = b.addTranslateC(.{
        .root_source_file = b.path(translate_header),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    translate.addIncludePath(libconf.dirname());
    translate.addIncludePath(b.path(source_dir));
    // Match the Windows shared-build macro; consumers set `PNG_USE_DLL` (`src/pngconf.h:255-263`).
    if (delivered == .dynamic and target.result.ofmt == .coff) {
        translate.defineCMacro("PNG_BUILD_DLL", "1");
    }
    if (translateCRiscvFloatAbi(target)) |macro| translate.defineCMacro(macro[0], macro[1]);
    if (target.result.os.tag == .wasi) {
        // Aro does not expose this target feature as a predefined C macro.
        translate.defineCMacro("__wasm_exception_handling__", "1");
    }

    const module = if (public)
        b.addModule(lib_name, .{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        })
    else
        b.createModule(.{
            .root_source_file = b.path(facade_source),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });

    // Reuse the translated module and one loader core so public types stay identical.
    if (runtime_loaded) {
        module.addImport("c", graph.createModule(b, translate, target, optimize));
    } else {
        // Keep translated C private; dependents import the facade.
        module.addImport("c", translate.createModule());
        module.addImport("rt", graph.createCoreModule(b, target, optimize));
        module.linkLibrary(c_lib);
    }

    // Use the same include order for dependent C modules.
    module.addIncludePath(libconf.dirname());
    module.addIncludePath(b.path(source_dir));

    return .{ .c_lib = c_lib, .module = module };
}

/// Generate the upstream prebuilt `pnglibconf.h` once per build.
/// Its contents are target-independent and the run step is cacheable.
fn addLibconf(b: *std.Build) std.Build.LazyPath {
    const generator_mod = b.createModule(.{
        .root_source_file = b.path(generator_source),
        // This generator runs on the build host, not the target.
        .target = b.graph.host,
        .optimize = .safe,
    });
    const generator = b.addExecutable(.{
        .name = "pnglibconf-gen",
        .root_module = generator_mod,
    });

    const run = b.addRunArtifact(generator);
    run.setName("generate pnglibconf.h");
    run.addArg("--input");
    run.addFileArg2(b.path(prebuilt_libconf), .{});
    run.addArg("--output");
    const out = run.addOutputFileArg2("pnglibconf.h", .{});
    run.addArg("--expect-version");
    run.addArg(b.fmt("{d}.{d}.{d}", .{
        upstream_version.major,
        upstream_version.minor,
        upstream_version.patch,
    }));
    return out;
}

fn add_c_library(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    linkage: std.lang.LinkMode,
    name: []const u8,
    libconf: std.Build.LazyPath,
    zlib_lib: *std.Build.Step.Compile,
) *std.Build.Step.Compile {
    const c_lib = b.addLibrary(.{
        .name = name,
        .linkage = linkage,
        // Only shared objects carry the upstream ABI version.
        .version = if (linkage == .dynamic) abi_version else null,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .pic = if (linkage == .dynamic) true else null,
        }),
    });
    const c_mod = c_lib.root_module;

    // `pnglibconf.h` is included by bare name, so this directory comes first.
    c_mod.addIncludePath(libconf.dirname());
    c_mod.addIncludePath(b.path(source_dir));

    for (simd_opt_macros) |macro| {
        c_mod.addCMacro(macro, "0");
    }

    // Match the translator's Windows shared-build macro.
    if (linkage == .dynamic and target.result.ofmt == .coff) {
        c_mod.addCMacro("PNG_BUILD_DLL", "1");
    }

    for (core_sources) |source| {
        c_mod.addCSourceFile(.{
            .file = b.path(source),
            .flags = if (target.result.os.tag == .wasi) &wasi_c_flags else &c_flags,
        });
    }

    // Linking the zlib artifact also adds its installed headers to this module.
    c_mod.linkLibrary(zlib_lib);

    if (linkage == .dynamic) setVersionScript(b, c_lib, target);

    // Install upstream's headers under `libpng16/`; the third is generated.
    for (public_headers) |header| {
        c_lib.installHeader(
            if (header.generated) libconf else b.path(header.source),
            b.fmt("libpng16/{s}", .{header.basename}),
        );
    }

    return c_lib;
}

/// Restrict ELF exports to upstream's `png_*` API (`src/Makefile.am:186`).
/// Mach-O has no version-script equivalent and exports internal symbols too.
fn setVersionScript(
    b: *std.Build,
    c_lib: *std.Build.Step.Compile,
    target: std.Build.ResolvedTarget,
) void {
    if (target.result.ofmt != .elf) return;

    const files = b.addWriteFiles();
    c_lib.setVersionScript(files.add("libpng.map",
        \\{
        \\  global:
        \\    png_*;
        \\  local:
        \\    *;
        \\};
    ));
}

fn add_target_check(
    b: *std.Build,
    step: *std.Build.Step,
    query: std.Target.Query,
    optimize: std.lang.Optimize,
    linkage: std.lang.LinkMode,
    runtime_loaded: bool,
    libconf: std.Build.LazyPath,
) void {
    const cross_target = configureTarget(b, b.resolveTargetQuery(query));
    // Include the target triple in each matrix artifact name.
    const triple = cross_target.result.zigTriple(b.allocator) catch @panic("unspellable target");

    const cross = addGraph(b, cross_target, optimize, linkage, runtime_loaded, false, libconf);

    const test_mod = b.createModule(.{
        .root_source_file = b.path(test_source),
        .target = cross_target,
        .optimize = optimize,
        .link_libc = true,
    });
    test_mod.addImport(lib_name, cross.module);
    step.dependOn(&b.addTest(.{
        .name = b.fmt("libpng-tests-{s}", .{triple}),
        .root_module = test_mod,
    }).step);

    const example_mod = b.createModule(.{
        .root_source_file = b.path(example_source),
        .target = cross_target,
        .optimize = optimize,
        .link_libc = true,
    });
    example_mod.addImport(lib_name, cross.module);
    step.dependOn(&b.addExecutable(.{
        .name = b.fmt("libpng-smoke-{s}", .{triple}),
        .root_module = example_mod,
    }).step);

    step.dependOn(&cross.c_lib.step);
}

fn runConsumer(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.lang.Optimize,
    linkage: std.lang.LinkMode,
    runtime_loaded: bool,
) *std.Build.Step.Run {
    const triple = target.query.zigTriple(b.allocator) catch @panic("OOM");
    defer b.allocator.free(triple);
    // Forward the CPU query separately from the target triple.
    const cpu = target.query.serializeCpuAlloc(b.allocator) catch @panic("OOM");
    defer b.allocator.free(cpu);

    // Reuse this build's Zig executable for the nested build.
    const run = b.addSystemCommand(&.{ b.graph.zig_exe, "build" });
    run.setName("consumer package");
    run.setCwd(b.path("consumer"));
    run.addArgs(&.{ "run", "install" });
    run.addArg(b.fmt("-Dtarget={s}", .{triple}));
    run.addArg(b.fmt("-Dcpu={s}", .{cpu}));
    run.addArg(b.fmt("-Doptimize={s}", .{@tagName(optimize)}));
    // Preserve linkage and dispatch options in the nested build.
    run.addArg(b.fmt("-Dlinkage={s}", .{@tagName(linkage)}));
    run.addArg(b.fmt("-Druntime={s}", .{if (runtime_loaded) "true" else "false"}));
    run.addArg(b.fmt("-fno-sys={s}", .{artifact_name}));
    run.addThirdPartyEnabledArgDarling(.{ .enabled = "-fdarling" });
    run.addThirdPartyEnabledArgQemu(.{ .enabled = "-fqemu" });
    run.addThirdPartyEnabledArgRosetta(.{ .enabled = "-frosetta" });
    run.addThirdPartyEnabledArgWasmtime(.{ .enabled = "-fwasmtime" });
    run.addThirdPartyEnabledArgWine(.{ .enabled = "-fwine" });
    const libc_runtimes = b.option(
        []const u8,
        "consumer-libc-runtimes",
        "Libc runtimes for a nested cross-target consumer run",
    );
    if (libc_runtimes) |runtimes| {
        run.addArg("--libc-runtimes");
        run.addDirectoryArg2(b.graph.cwdRelativePath(runtimes), .{ .make_absolute = true });
    }
    run.addArg("-j8");
    run.addArg("--summary");
    run.addArg("all");
    run.addArg("--cache-dir");
    run.addDirectoryArg2(std.Build.LazyPath.cache_root.path(b, "consumer"), .{ .make_absolute = true });
    run.addArg("--prefix");
    run.addDirectoryArg2(.{ .relative = .{ .base = .install_prefix } }, .{ .make_absolute = true });
    // The nested build forwards these after its own option parsing.
    run.addArg("--");
    run.addPassthruArgs();
    run.has_side_effects = true;
    return run;
}

/// Write a relocatable pkg-config file using the delivered dependency's name.
/// Static consumers need the pinned libzlib archive and libpng's math symbols.
fn add_pkg_config(b: *std.Build) void {
    const files = b.addWriteFiles();
    // Keep the install-file step in the graph so the generated `.pc` is installed.
    const install_pc = b.addInstallFileWithDir(
        files.add("libpng16.pc", b.fmt(
            \\# libpng16.pc for the libpng 1.6.59 SDK.
            \\#
            \\# Generated from upstream's own template, src/scripts/libpng.pc.in, by
            \\# substituting the four @VAR@s configure would. `prefix` is pcfiledir-relative
            \\# so the installed file is correct wherever --prefix put it. build.zig's
            \\# add_pkg_config names the upstream line each field comes from.
            \\prefix=${{pcfiledir}}/../..
            \\exec_prefix=${{prefix}}
            \\libdir=${{prefix}}/lib
            \\includedir=${{prefix}}/include/libpng16
            \\
            \\Name: libpng
            \\Description: Loads and saves PNG files
            \\Version: {f}
            \\
            \\Libs: -L"${{libdir}}" -lpng16
            \\Libs.private: -lzlib -lm
            \\Cflags: -I"${{includedir}}"
            \\
        , .{upstream_version})),
        .prefix,
        "lib/pkgconfig/libpng16.pc",
    );
    b.getInstallStep().dependOn(&install_pc.step);
}

fn install_licence_records(b: *std.Build) void {
    for (licence_records) |record| {
        const install_record = b.addInstallFileWithDir(
            b.path(record),
            .prefix,
            b.fmt("share/licenses/libpng/{s}", .{std.fs.path.basename(record)}),
        );
        b.getInstallStep().dependOn(&install_record.step);
    }
}

fn install_man_pages(b: *std.Build) void {
    for (man_pages) |page| {
        const install_page = b.addInstallFileWithDir(
            b.path(page.source),
            .prefix,
            b.fmt("share/man/{s}/{s}", .{ page.section, std.fs.path.basename(page.source) }),
        );
        b.getInstallStep().dependOn(&install_page.step);
    }
}

pub fn build(b: *std.Build) void {
    const target = configureTarget(b, b.standardTargetOptions(.{}));
    const optimize = b.standardOptimizeOption(.{});

    const system_default = b.option(
        bool,
        "system",
        "Refused in this package: no system mode is implemented, and the module " ++
            "comment says why (a system mode would have to translate the installed " ++
            "pnglibconf.h alongside the installed png.h and check its " ++
            "PNG_ZLIB_VERNUM against the zlib that prefix links, which is the " ++
            "silent-ABI failure AGENTS.md rule 4 forbids). This option supplies the " ++
            "default of systemIntegrationOption(\"png16\"); a build runner that " ++
            "decides the mode itself (-fsys=png16) overrides it. Either spelling " ++
            "that selects the system stops the build before a compiler is invoked.",
    ) orelse false;

    if (b.systemIntegrationOption(artifact_name, .{ .default = system_default })) {
        std.log.err(
            \\libpng: -fsys=png16 selects a system mode this package does not
            \\implement, and the rule is recorded as vacuous rather than
            \\satisfied.
            \\
            \\src/png.h:328 includes the *generated* pnglibconf.h and
            \\src/png.h:333 includes pngconf.h, so a system mode must translate
            \\the installed pnglibconf.h alongside the installed png.h from the
            \\same prefix and check its PNG_ZLIB_VERNUM against the zlib that
            \\prefix links (src/pngpriv.h:1026-1028). Bundling this tree's own
            \\src/png.h against an older installed libpng is the silent ABI
            \\mismatch AGENTS.md rule 4 forbids.
            \\
            \\Build the bundled graph instead: drop -Dsystem and do not pass
            \\-fsys=png16.
            \\
        , .{});
        @panic("libpng: refusing a system mode this package does not implement");
    }

    const linkage_option = b.option(
        std.lang.LinkMode,
        "linkage",
        "Deliver the native library as a static archive (the default) or as a real " ++
            "shared object with upstream's libpng16 ABI name " ++
            "(libpng16.so.16.59.0, soname libpng16.so.16). This selects the delivery " ++
            "and never the dispatch: the same 16 C units are compiled either way.",
    );

    const linkage: std.lang.LinkMode = linkage_option orelse .static;

    // Dispatch selection is independent of static/shared artifact delivery.
    // Runtime mode resolves a provider through the explicit loader.
    const runtime_loaded = b.option(
        bool,
        "runtime",
        "Resolve the native entry points at run time instead of linking them. " ++
            "The facade keeps the same translated headers and the same public " ++
            "types; each selected native function becomes a dispatch through " ++
            "one process-lifetime table that an explicit load(source) fills, " ++
            "and the module links no archive. Independent of -Dlinkage, which " ++
            "still decides which artifact this build delivers and installs. " ++
            "Default off, and a linked build is unchanged in every respect.",
    ) orelse false;

    // Keep the manifest release aligned with upstream's version macros.
    if (manifest_version.order(upstream_version) != .eq) {
        @panic("build.zig.zon .version no longer matches the version read out " ++
            "of src/png.h:277; see UPSTREAM.md");
    }

    checkMatrixPartition(b);

    const libconf = addLibconf(b);

    const published = addGraph(b, target, optimize, linkage, runtime_loaded, true, libconf);

    const c_lib = published.c_lib;

    b.installArtifact(c_lib);
    add_pkg_config(b);
    install_licence_records(b);
    install_man_pages(b);

    const example_mod = b.createModule(.{
        .root_source_file = b.path(example_source),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    example_mod.addImport(lib_name, published.module);
    const example = b.addExecutable(.{
        .name = "libpng-smoke",
        .root_module = example_mod,
    });
    b.getInstallStep().dependOn(&example.step);

    const run_example = b.addRunArtifact(example);
    run_example.has_side_effects = true;
    run_example.addPassthruArgs();
    b.step("smoke", "Run the deterministic example program").dependOn(&run_example.step);

    // Use the test root so Zig discovers its test blocks.
    const test_mod = b.createModule(.{
        .root_source_file = b.path(test_source),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    test_mod.addImport(lib_name, published.module);
    const unit_tests = b.addTest(.{
        .name = "libpng-tests",
        .root_module = test_mod,
    });
    const run_tests = b.addRunArtifact(unit_tests);
    run_tests.has_side_effects = true;
    b.step("test", "Run the behavioural tests").dependOn(&run_tests.step);

    b.step("consumer", "Build or run the consumer/ package for the selected target")
        .dependOn(&runConsumer(b, target, optimize, deliveredLinkage(target, linkage), runtime_loaded).step);

    const check_step = b.step(
        "check",
        "Compile the native library, the facade, the tests and the example for " ++
            "the compatible check targets without running any of them",
    );
    if (!target.query.isNative()) {
        add_target_check(b, check_step, target.query, optimize, linkage, runtime_loaded, libconf);
    } else {
        for (check_targets[0..]) |query| {
            // Filter only the automatic matrix; explicit targets keep their linkage checks.
            if ((linkage == .dynamic or runtime_loaded) and
                !targetHasDynamicLinker(b.resolveTargetQuery(query))) continue;
            add_target_check(b, check_step, query, optimize, linkage, runtime_loaded, libconf);
        }
    }

    std.debug.print("libpng: {d} C units from src/Makefile.am:127-129, C99 (gnu99), no SIMD unit compiled\n", .{
        core_sources.len,
    });
    std.debug.print("libpng: {s}\n", .{switch (deliveredLinkage(target, linkage)) {
        .static => "static archive libpng16.a (default)",
        .dynamic => b.fmt("shared object libpng16.so.{d}.{d}.{d}, soname libpng16.so.{d} " ++
            "(src/png.h:281 PNG_LIBPNG_VER_SHAREDLIB {d}, src/Makefile.am:178-179 -version-number {d}:{d}:0)", .{
            abi_version.major,
            abi_version.minor,
            abi_version.patch,
            abi_version.major,
            abi_version.major,
            abi_version.major,
            abi_version.minor,
        }),
    }});
    std.debug.print(
        "libpng: SIMD configuration is none; all seven PNG_*_OPT macros are 0 and no " ++
            "arm/ intel/ mips/ powerpc/ loongarch/ riscv/ unit is compiled " ++
            "(src/pngusr.dfa carries no options, and src/Makefile.am:132-174 adds those " ++
            "units only under its own if PNG_*_OPT blocks)\n",
        .{},
    );
    std.debug.print(
        "libpng: pnglibconf.h is generated by tools/pnglibconf.zig from " ++
            "{s} into the build cache, on the include line ahead of src/; PNG_ZLIB_VERNUM " ++
            "is 0 (src/scripts/pnglibconf.h.prebuilt:226), so src/pngpriv.h:1026-1028 " ++
            "skips its include-path check\n",
        .{prebuilt_libconf},
    );
    std.debug.print(
        "libpng: the zlib package dependency declared in build.zig.zon supplies " ++
            "the archive and headers; no system zlib path is added\n",
        .{},
    );
    if (runtime_loaded) {
        std.debug.print(
            "libpng: runtime-loaded dispatch (-Druntime=true, sync prefix libpng_rt); " ++
                "the facade module links no archive and a provider is named by an " ++
                "explicit load(source)\n",
            .{},
        );
    }
    if (deliveredLinkage(target, linkage) == .dynamic and target.result.ofmt != .elf) {
        std.debug.print(
            "libpng: {s} has no version-script mechanism here, so the shared " ++
                "object exports libpng's internal symbols as well as its API\n",
            .{@tagName(target.result.ofmt)},
        );
    }
}

/// Windows uses the PE loader; WASI has no dynamic linker.
fn targetHasDynamicLinker(target: std.Build.ResolvedTarget) bool {
    return target.result.os.tag == .windows or std.Target.DynamicLinker.kind(target.result.os.tag) != .none;
}

/// Refuse dynamic linkage when no dynamic linker exists; do not substitute an archive.
fn deliveredLinkage(
    target: std.Build.ResolvedTarget,
    requested: std.lang.LinkMode,
) std.lang.LinkMode {
    if (requested == .dynamic and !targetHasDynamicLinker(target)) {
        // Use run-time formatting for the target tag.
        std.debug.panic(
            "libpng: -Dlinkage=dynamic was asked for {s}, which has no dynamic " ++
                "linker: std.Target.DynamicLinker.kind is .none for it, so it cannot " ++
                "carry a shared object at all. This build does not substitute a static " ++
                "archive for a requested shared object. Build that target with the " ++
                "default -Dlinkage=static, or leave -Dlinkage unset.",
            .{@tagName(target.result.os.tag)},
        );
    }
    return requested;
}

const Refusal = struct {
    summary: []const u8,
    detail: []const u8,
};

fn refusalFor(os_tag: std.Target.Os.Tag) ?Refusal {
    _ = os_tag;
    return null;
}

fn refuseTarget(b: *std.Build, target: std.Build.ResolvedTarget) noreturn {
    const refusal = refusalFor(target.result.os.tag) orelse
        @panic("build.zig internal error: refusalFor returned null for a target addGraph refused");
    const triple = target.result.zigTriple(b.allocator) catch @panic("unspellable target");
    std.log.err("libpng: {s}: {s}\n{s}", .{ triple, refusal.summary, refusal.detail });
    @panic("libpng: refusing a target this package has no buildable configuration for");
}

/// Ensure the check and refusal target sets stay consistent.
fn checkMatrixPartition(b: *std.Build) void {
    for (check_targets) |query| {
        const resolved = b.resolveTargetQuery(query);
        if (refusalFor(resolved.result.os.tag) != null) {
            @panic(b.fmt(
                "build.zig: {s} is in check_targets but this build refuses its operating system",
                .{resolved.result.zigTriple(b.allocator) catch @panic("unspellable check target")},
            ));
        }
    }
    for (refused_check_targets) |query| {
        const resolved = b.resolveTargetQuery(query);
        if (refusalFor(resolved.result.os.tag) == null) {
            @panic(b.fmt(
                "build.zig: {s} is in refused_check_targets but refusalFor no longer refuses it; move it to check_targets and prove it builds",
                .{resolved.result.zigTriple(b.allocator) catch @panic("unspellable check target")},
            ));
        }
    }
}
