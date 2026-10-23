// SPDX-License-Identifier: MIT
// See FORK-LICENSE.md for what that identifier covers.
//
//!
//! Runtime-loading build graph for libpng. Do not link the C archive alongside
//! this dispatch; doing so bypasses the runtime loader.

const std = @import("std");

/// Prefix shared with `runtime/sync.c` and `runtime/library.zig`.
/// Change both when building an independent second instance.
const sync_prefix = "libpng_rt";

/// C-library declarations from translated headers; keep these direct.
/// Each name, including the last on each source line, needs its comma delimiter.
/// `__longjmp_chk` covers fortified glibc headers.
const libc_noise =
    \\
    \\___mb_cur_max,___mb_cur_max_l,__acrt_iob_func,__asprintf,__asprintf_chk,__attrib2,__attrib3,__bos,
    \\__bos0,__deprecated_msg,__dprintf_chk,__feof_unlocked_body,__ferror_unlocked_body,__fgets_alias,
    \\__fgets_chk,__fgets_chk_warn,__fgets_unlocked_alias,__fgets_unlocked_chk,__fgets_unlocked_chk_warn,
    \\__fprintf_chk,__fread_alias,__fread_chk,__fread_chk_warn,__fread_unlocked_alias,__fread_unlocked_chk,
    \\__fread_unlocked_chk_warn,__getc_unlocked_body,__getdelim,__gets_chk,__gets_warn,__glibc_has_extension,
    \\__glibc_unlikely,__iob_func,__isoc23_fscanf,__isoc23_scanf,__isoc23_sscanf,__isoc23_vfscanf,__isoc23_vscanf,
    \\__isoc23_vsscanf,__isoc99_fscanf,__isoc99_scanf,__isoc99_sscanf,__isoc99_vfscanf,__isoc99_vscanf,
    \\__isoc99_vsscanf,__isthreaded,__libc_ptrchk_strbuf_chk,__local_stdio_printf_options,__local_stdio_scanf_options,
    \\__longjmp_chk,__mingw_asprintf,__mingw_call_fgets,__mingw_call_fread,__mingw_call_gets_warn,__mingw_call_sprintf,
    \\__mingw_call_tmpnam,__mingw_call_vsprintf,__mingw_fprintf,__mingw_fscanf,__mingw_fwprintf,__mingw_fwscanf,
    \\__mingw_get_crt_info,__mingw_longjmp,__mingw_printf,__mingw_scanf,__mingw_setjmp,__mingw_snwprintf,
    \\__mingw_sprintf,__mingw_sscanf,__mingw_str_free,__mingw_str_utf8_wide,__mingw_str_wide_utf8,__mingw_swprintf,
    \\__mingw_swscanf,__mingw_vasprintf,__mingw_vfprintf,__mingw_vfscanf,__mingw_vfwprintf,__mingw_vfwscanf,
    \\__mingw_vprintf,__mingw_vscanf,__mingw_vsnwprintf,__mingw_vsprintf,__mingw_vsscanf,__mingw_vswprintf,
    \\__mingw_vswscanf,__mingw_vwprintf,__mingw_vwscanf,__mingw_wprintf,__mingw_wscanf,__ms_fprintf,
    \\__ms_fscanf,__ms_fwprintf,__ms_fwscanf,__ms_printf,__ms_scanf,__ms_snprintf,__ms_snwprintf,__ms_sprintf,
    \\__ms_sscanf,__ms_swprintf,__ms_swscanf,__ms_vfprintf,__ms_vfscanf,__ms_vfwprintf,__ms_vfwscanf,
    \\__ms_vprintf,__ms_vscanf,__ms_vsnprintf,__ms_vsnwprintf,__ms_vsprintf,__ms_vsscanf,__ms_vswprintf,
    \\__ms_vswscanf,__ms_vwprintf,__ms_vwscanf,__ms_wprintf,__ms_wscanf,__obstack_printf_chk,__obstack_vprintf_chk,
    \\__overflow,__posix_getopt,__printf_chk,__putc_unlocked_body,__sF,__sigsetjmp,__snprintf_chk,__sprintf_chk,
    \\__sputc,__srget,__stderr,__stderrp,__stdin,__stdinp,__stdio_common_vfprintf,__stdio_common_vfprintf_p,
    \\__stdio_common_vfprintf_s,__stdio_common_vfscanf,__stdio_common_vfwprintf,__stdio_common_vfwprintf_s,
    \\__stdio_common_vfwscanf,__stdio_common_vsnprintf_s,__stdio_common_vsnwprintf_s,__stdio_common_vsprintf,
    \\__stdio_common_vsprintf_p,__stdio_common_vsprintf_s,__stdio_common_vsscanf,__stdio_common_vswprintf,
    \\__stdio_common_vswprintf_s,__stdio_common_vswscanf,__stdout,__stdoutp,__svfscanf,__swbuf,__swprintf_l,
    \\__sysconf,__uflow,__va_arg_pack,__vasprintf_chk,__vdprintf_chk,__vfprintf_chk,__vprintf_chk,__vsnprintf_chk,
    \\__vsprintf_chk,__vswprintf_l,__warnattr,__wasi_args_get,__wasi_args_sizes_get,__wasi_clock_res_get,
    \\__wasi_clock_time_get,__wasi_environ_get,__wasi_environ_sizes_get,__wasi_fd_advise,__wasi_fd_allocate,
    \\__wasi_fd_close,__wasi_fd_datasync,__wasi_fd_fdstat_get,__wasi_fd_fdstat_set_flags,__wasi_fd_fdstat_set_rights,
    \\__wasi_fd_filestat_get,__wasi_fd_filestat_set_size,__wasi_fd_filestat_set_times,__wasi_fd_pread,
    \\__wasi_fd_prestat_dir_name,__wasi_fd_prestat_get,__wasi_fd_pwrite,__wasi_fd_read,__wasi_fd_readdir,
    \\__wasi_fd_renumber,__wasi_fd_seek,__wasi_fd_sync,__wasi_fd_tell,__wasi_fd_write,__wasi_path_create_directory,
    \\__wasi_path_filestat_get,__wasi_path_filestat_set_times,__wasi_path_link,__wasi_path_open,__wasi_path_readlink,
    \\__wasi_path_remove_directory,__wasi_path_rename,__wasi_path_symlink,__wasi_path_unlink_file,__wasi_poll_oneoff,
    \\__wasi_proc_exit,__wasi_random_get,__wasi_sched_yield,__wasi_sock_accept,__wasi_sock_recv,__wasi_sock_send,
    \\__wasi_sock_shutdown,__wasi_thread_spawn,__weak_alias,__zeroll,_errno,_fclose_nolock,_fcloseall,
    \\_fdopen,_fflush_nolock,_fgetc_nolock,_fgetchar,_fgetwc_nolock,_fgetwchar,_filbuf,_fileno,_flsbuf,
    \\_flushall,_fprintf_l,_fprintf_p,_fprintf_p_l,_fprintf_s_l,_fputc_nolock,_fputchar,_fputwc_nolock,
    \\_fputwchar,_fread_nolock,_fread_nolock_s,_fscanf_l,_fscanf_s_l,_fseek_nolock,_fseeki64,_fseeki64_nolock,
    \\_fsopen,_ftell_nolock,_ftelli64,_ftelli64_nolock,_fwprintf_l,_fwprintf_p,_fwprintf_p_l,_fwprintf_s_l,
    \\_fwrite_nolock,_fwscanf_l,_fwscanf_s_l,_get_errno,_get_output_format,_get_printf_count_output,
    \\_getc_nolock,_getmaxstdio,_getw,_getws,_getws_s,_lock_file,_longjmp,_pclose,_popen,_printf_l,_printf_p,
    \\_printf_p_l,_printf_s_l,_putc_nolock,_putw,_putws,_rmtmp,_scanf_l,_scanf_s_l,_scprintf,_scprintf_l,
    \\_scprintf_p,_scprintf_p_l,_scwprintf,_scwprintf_l,_scwprintf_p,_scwprintf_p_l,_set_errno,_set_output_format,
    \\_set_printf_count_output,_setjmp,_setjmp3,_setjmpex,_setmaxstdio,_snprintf,_snprintf_c,_snprintf_c_l,
    \\_snprintf_l,_snprintf_s,_snprintf_s_l,_snscanf,_snscanf_l,_snscanf_s,_snscanf_s_l,_snwprintf,_snwprintf_l,
    \\_snwprintf_s,_snwprintf_s_l,_snwscanf,_snwscanf_l,_snwscanf_s,_snwscanf_s_l,_spawnv,_spawnve,_spawnvp,
    \\_spawnvpe,_sprintf_l,_sprintf_p,_sprintf_p_l,_sprintf_s_l,_sscanf_l,_sscanf_s_l,_swprintf,_swprintf_c,
    \\_swprintf_c_l,_swprintf_p,_swprintf_p_l,_swprintf_s_l,_swscanf_l,_swscanf_s_l,_tempnam,_ungetc_nolock,
    \\_ungetwc_nolock,_unlink,_unlock_file,_vfprintf_l,_vfprintf_p,_vfprintf_p_l,_vfprintf_s_l,_vfscanf_l,
    \\_vfscanf_s_l,_vfwprintf_l,_vfwprintf_p,_vfwprintf_p_l,_vfwprintf_s_l,_vfwscanf_s_l,_vprintf_l,
    \\_vprintf_p,_vprintf_p_l,_vprintf_s_l,_vscanf_l,_vscanf_s_l,_vscprintf,_vscprintf_l,_vscprintf_p,
    \\_vscprintf_p_l,_vscwprintf,_vscwprintf_l,_vscwprintf_p,_vscwprintf_p_l,_vsnprintf,_vsnprintf_c,
    \\_vsnprintf_c_l,_vsnprintf_l,_vsnprintf_s,_vsnprintf_s_l,_vsnwprintf,_vsnwprintf_l,_vsnwprintf_s,
    \\_vsnwprintf_s_l,_vsnwscanf_s_l,_vsprintf_l,_vsprintf_p,_vsprintf_p_l,_vsprintf_s_l,_vsscanf_l,
    \\_vsscanf_s_l,_vswprintf,_vswprintf_c,_vswprintf_c_l,_vswprintf_p,_vswprintf_p_l,_vswprintf_s_l,
    \\_vswscanf_s_l,_vwprintf_l,_vwprintf_p,_vwprintf_p_l,_vwprintf_s_l,_vwscanf_s_l,_wfdopen,_wfopen,
    \\_wfopen_s,_wfreopen,_wfreopen_s,_wfsopen,_wperror,_wpopen,_wprintf_l,_wprintf_p,_wprintf_p_l,_wprintf_s_l,
    \\_wremove,_wscanf_l,_wscanf_s_l,_wspawnl,_wspawnle,_wspawnlp,_wspawnlpe,_wspawnv,_wspawnve,_wspawnvp,
    \\_wspawnvpe,_wtempnam,_wtmpnam,_wtmpnam_s,asprintf,asprintf_l,clearerr,clearerr_s,clearerr_unlocked,
    \\ctermid,ctermid_r,cuserid,dprintf,dprintf_l,fclose,fcloseall,fdclose,fdopen,feof,feof_unlocked,
    \\ferror,ferror_unlocked,fflush,fflush_unlocked,fgetc,fgetc_unlocked,fgetchar,fgetln,fgetpos,fgetpos64,
    \\fgets,fgets_unlocked,fgetwc,fgetws,fileno,fileno_unlocked,flockfile,flushall,fmemopen,fmtcheck,
    \\fopen,fopen64,fopen_s,fopencookie,fparseln,fprintf,fprintf_l,fprintf_s,fpurge,fputc,fputc_unlocked,
    \\fputchar,fputs,fputs_unlocked,fputwc,fputws,fread,fread_s,fread_unlocked,freopen,freopen64,freopen_s,
    \\fscanf,fscanf_l,fscanf_s,fseek,fseeko,fseeko64,fsetpos,fsetpos64,ftell,ftello,ftello64,ftruncate,
    \\ftrylockfile,funlockfile,funopen,funopen2,fwprintf,fwprintf_s,fwrite,fwrite_unlocked,fwscanf,fwscanf_s,
    \\getc,getc_unlocked,getchar,getchar_unlocked,getdelim,getline,getopt,gets,gets_s,getw,getwc,getwchar,
    \\longjmp,longjmperror,lseek,mingw_getsp,mkstemp,mmap,obstack_printf,obstack_vprintf,open_memstream,
    \\open_wmemstream,optarg,opterr,optind,optopt,pclose,perror,popen,popenve,printf,printf_l,printf_s,
    \\putc,putc_unlocked,putchar,putchar_unlocked,puts,putw,putwc,putwchar,remove,rename,renameat,renameat2,
    \\renameatx_np,renamex_np,rewind,rmtmp,scanf,scanf_l,scanf_s,setbuf,setbuffer,setjmp,setlinebuf,
    \\setvbuf,siglongjmp,sigsetjmp,snprintf,snprintf_l,snwprintf,sprintf,sprintf_l,sprintf_s,sscanf,
    \\sscanf_l,sscanf_s,stderr,stdin,stdout,swap16,swprintf,swprintf_s,swscanf,swscanf_s,sys_errlist,
    \\sys_nerr,tempnam,tmpfile,tmpfile64,tmpfile_s,tmpnam,tmpnam_r,tmpnam_s,truncate,ungetc,ungetwc,
    \\unlink,vasprintf,vasprintf_l,vdprintf,vdprintf_l,vfprintf,vfprintf_l,vfprintf_s,vfscanf,vfscanf_l,
    \\vfscanf_s,vfwprintf,vfwprintf_s,vfwscanf,vfwscanf_s,vprintf,vprintf_l,vprintf_s,vscanf,vscanf_l,
    \\vscanf_s,vsnprintf,vsnprintf_l,vsnprintf_s,vsnwprintf,vsprintf,vsprintf_l,vsprintf_s,vsscanf,vsscanf_l,
    \\vsscanf_s,vswprintf,vswprintf_s,vswscanf,vswscanf_s,vwprintf,vwprintf_s,vwscanf,vwscanf_s,wprintf,
    \\wprintf_s,wscanf,wscanf_s,
    \\
;

/// Optional provider exports. None; all translated libpng symbols are required.
const provider_optional = "";

/// Provider exports this build does not require. None.
const provider_excluded = "";

/// Loader core for a linked build, to expose the same public loader types.
/// Runtime-loaded builds import the single core through the generated dispatch.
pub fn createCoreModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    return b.createModule(.{
        .root_source_file = b.path("runtime/loader.zig"),
        .target = target,
        .optimize = optimize,
        // Unix `dlopen` needs libc; linked builds do not compile this module.
        .link_libc = true,
    });
}

/// Runtime-loaded `c` module generated from this target's translation step.
pub fn createModule(
    b: *std.Build,
    translate: *std.Build.Step.TranslateC,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const core = createCoreModule(b, target, optimize);

    const library = b.createModule(.{
        .root_source_file = b.path("runtime/library.zig"),
        .target = target,
        .optimize = optimize,
    });
    library.addImport("rt", core);

    return createDispatchModule(b, translate, target, optimize, core, library);
}

const GeneratedSources = struct {
    native: std.Build.LazyPath,
    dispatch: std.Build.LazyPath,
};

fn createDispatchModule(
    b: *std.Build,
    translate: *std.Build.Step.TranslateC,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    core: *std.Build.Module,
    library: *std.Build.Module,
) *std.Build.Module {
    const sources = generateDispatch(b, translate, target);

    const dispatch = b.createModule(.{
        .root_source_file = sources.dispatch,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    dispatch.addImport("rt", core);
    dispatch.addImport("library", library);
    // The patched translation re-exports types and routes macro-expanded
    // function members through the dispatch.
    const native = b.createModule(.{
        .root_source_file = sources.native,
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    native.addImport("c_routed", dispatch);
    dispatch.addImport("c_native", native);
    dispatch.addCSourceFiles(.{
        .files = &.{"runtime/sync.c"},
        .flags = &.{b.fmt("-DRT_SYNC_PREFIX={s}", .{sync_prefix})},
        .language = .c,
    });
    return dispatch;
}

/// Generate dispatch from the selected target's translated headers.
fn generateDispatch(
    b: *std.Build,
    translate: *std.Build.Step.TranslateC,
    target: std.Build.ResolvedTarget,
) GeneratedSources {
    const generator = b.addExecutable(.{
        .name = b.fmt("libpng-runtime-generate-{s}", .{
            target.result.zigTriple(b.allocator) catch @panic("unspellable target"),
        }),
        .root_module = b.createModule(.{
            .root_source_file = b.path("runtime/generate.zig"),
            .target = b.graph.host,
            .optimize = .Debug,
        }),
    });

    const run = b.addRunArtifact(generator);
    run.addArg("--library");
    run.addArg("libpng");
    run.addArg("--translate");
    run.addFileArg(translate.getOutput());
    if (libc_noise.len != 0) {
        run.addArg("--noise");
        run.addArg(libc_noise);
    }
    if (provider_optional.len != 0) {
        run.addArg("--optional");
        run.addArg(provider_optional);
    }
    if (provider_excluded.len != 0) {
        run.addArg("--exclude");
        run.addArg(provider_excluded);
    }
    run.addArg("--native-output");
    const native_source = run.addOutputFileArg("native.zig");
    run.addArg("--output");
    const dispatch_source = run.addOutputFileArg("dispatch.zig");
    return .{ .native = native_source, .dispatch = dispatch_source };
}
