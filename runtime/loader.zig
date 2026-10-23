// SPDX-License-Identifier: MIT
//
//! Generic process-wide dynamic loader for translated C APIs.
//! It opens the requested provider, publishes a complete symbol table once, and never unloads.

const std = @import("std");
const builtin = @import("builtin");

/// Explicit file-path or platform-search request; neither kind falls back to the other.
pub const LoadSource = union(enum) {
    /// Absolute file path; relative paths return `InvalidSource`.
    path: []const u8,
    /// Basename or SONAME; separators and NUL bytes return `InvalidSource`.
    system: []const u8,
};

/// Every way `load` can decline.
pub const LoadError = error{
    /// Empty path or system name, rejected before calling the platform loader.
    EmptySource,
    /// Request exceeds `max_source_len`; it is refused, never truncated.
    SourceTooLong,
    /// Path is not absolute, system name has a path component, or input contains NUL.
    InvalidSource,
    /// Target has no dynamic library loader.
    UnsupportedTarget,
    /// Platform loader refused the request or a dependency.
    OpenFailed,
    /// Opened provider does not export a required translated symbol.
    MissingSymbol,
    /// Provider failed its post-resolution validation.
    ValidationFailed,
    /// A different provider is loaded or currently loading.
    ProviderMismatch,
    /// Load was called recursively by the thread running an attempt.
    ReentrantLoad,
};

/// Longest remembered request, in bytes.
pub const max_source_len = 32768;

/// Request tag and copied bytes, retained without allocation.
/// The copy supports idempotence after caller-owned storage expires.
const SourceRecord = struct {
    tag: enum(u8) { none = 0, path, system } = .none,
    len: u32 = 0,
    bytes: [max_source_len]u8 = undefined,

    /// Called under the loader lock after checking request length.
    fn set(self: *SourceRecord, request: LoadSource) void {
        const text = switch (request) {
            .path => |p| p,
            .system => |s| s,
        };
        @memcpy(self.bytes[0..text.len], text);
        self.len = @intCast(text.len);
        self.tag = switch (request) {
            .path => .path,
            .system => .system,
        };
    }

    /// Returns the remembered request, valid for the process lifetime.
    pub fn source(self: *const SourceRecord) ?LoadSource {
        const text = self.bytes[0..self.len];
        return switch (self.tag) {
            .none => null,
            .path => .{ .path = text },
            .system => .{ .system = text },
        };
    }
};

/// Requests match only when their kind and bytes are identical.
pub fn eqlSource(a: LoadSource, b: LoadSource) bool {
    return switch (a) {
        .path => |pa| switch (b) {
            .path => |pb| std.mem.eql(u8, pa, pb),
            .system => false,
        },
        .system => |sa| switch (b) {
            .system => |sb| std.mem.eql(u8, sa, sb),
            .path => false,
        },
    };
}

fn validateSource(source: LoadSource) LoadError!void {
    const text = switch (source) {
        .path => |p| p,
        .system => |s| s,
    };
    if (text.len == 0) return error.EmptySource;
    if (text.len > max_source_len) return error.SourceTooLong;
    if (std.mem.indexOfScalar(u8, text, 0) != null) return error.InvalidSource;
    switch (source) {
        .path => {
            const absolute = if (builtin.target.os.tag == .windows)
                switch (std.fs.path.getWin32PathType(u8, text)) {
                    .drive_absolute, .unc_absolute, .local_device, .root_local_device => true,
                    .relative, .rooted, .drive_relative => false,
                }
            else
                std.fs.path.isAbsolutePosix(text);
            if (!absolute) return error.InvalidSource;
        },
        .system => {
            for (text) |byte| {
                if (std.fs.path.isSep(byte)) return error.InvalidSource;
                if (builtin.target.os.tag == .windows and byte == ':') return error.InvalidSource;
            }
        },
    }
}

/// Table state for one configured module.
pub const Phase = enum(u8) {
    /// No successful load; failed attempts return here and may be retried.
    not_loaded = 0,
    /// One thread is filling the table; it is not published.
    loading = 1,
    /// Table is published and routed calls are usable.
    ready = 2,
};

/// Readiness flag for the table.
/// A release store publishes all fields; routed calls read it with acquire ordering.
pub const Ready = struct {
    phase: std.atomic.Value(u8) = .init(@backingInt(Phase.not_loaded)),

    /// Acquire-load readiness check for routed calls.
    pub fn isReady(self: *const Ready) bool {
        return self.phase.load(.acquire) == @backingInt(Phase.ready);
    }

    /// Current state for decisions under the loader lock.
    pub fn state(self: *const Ready) Phase {
        return @fromBackingInt(@intCast(self.phase.load(.acquire)));
    }

    /// Publish or withdraw the table with release ordering.
    pub fn set(self: *Ready, value: Phase) void {
        self.phase.store(@backingInt(value), .release);
    }
};

/// Kind of required export; both are resolved at load time.
pub const SymbolKind = enum {
    /// Store the exact function-pointer type declared by the translated header.
    function,
    /// Store the provider-owned object's address, not a copy.
    data,
};

/// One required export name and its kind.
pub const Symbol = struct {
    /// Exported name as spelled by the C header.
    name: [:0]const u8,
    /// Value stored for this symbol.
    kind: SymbolKind,
};

/// Stop on a routed call before a successful load.
/// The panic names the library and function in every optimization mode.
pub fn panicNotReady(library: []const u8, comptime symbol: []const u8) noreturn {
    std.debug.panic(
        "{s}: {s} was called before this module was loaded; call " ++
            "load({{ .path = \"...\" }}) or load({{ .system = \"...\" }}) first",
        .{ library, symbol },
    );
}

/// Whether this target has a dynamic library loader.
pub const supported_target: bool = switch (builtin.target.os.tag) {
    .wasi, .emscripten, .freestanding => false,
    else => true,
};

/// Process-global loader for one dispatch configuration.
/// Same-source calls are idempotent; failures can retry, while another source returns `ProviderMismatch`.
pub fn Loader(comptime Config: type) type {
    return struct {
        const LoaderType = @This();

        /// Table type filled by this configuration.
        pub const table_type = Config.table;

        /// Active or undrained attempt, if any.
        attempt: ?Attempt = null,

        /// Request copied for each attempt; immutable after publication.
        request: SourceRecord = .{},

        /// Load a provider, or return the reason it was refused.
        /// Concurrent same-source callers join one attempt; different sources return `ProviderMismatch`.
        pub fn load(self: *LoaderType, source: LoadSource) LoadError!void {
            try validateSource(source);
            if (Config.ready().isReady()) return self.accept(source);

            Config.sync.lock();
            while (true) {
                switch (Config.ready().state()) {
                    .ready => {
                        Config.sync.unlock();
                        return self.accept(source);
                    },
                    .loading => {
                        const attempt = &self.attempt.?;
                        if (attempt.owner == Config.sync.threadSelf()) {
                            Config.sync.unlock();
                            return error.ReentrantLoad;
                        }
                        if (!eqlSource(self.request.source().?, source)) {
                            Config.sync.unlock();
                            return error.ProviderMismatch;
                        }
                        // Join the active same-source attempt instead of starting another.
                        attempt.waiters += 1;
                        while (Config.ready().state() == .loading) Config.sync.wait();
                        const result = attempt.result;
                        attempt.waiters -= 1;
                        // Keep the result until every waiter has read it.
                        Config.sync.broadcast();
                        Config.sync.unlock();
                        return result;
                    },
                    .not_loaded => {
                        // Wait for the previous attempt's waiters to drain before retrying.
                        if (self.attempt != null) {
                            Config.sync.wait();
                            continue;
                        }
                        break;
                    },
                }
            }

            self.request.set(source);
            self.attempt = .{ .owner = Config.sync.threadSelf() };
            Config.ready().set(.loading);
            Config.sync.unlock();

            // Run provider constructors without holding the loader lock.
            const outcome = runAttempt(self.request.source().?);
            const succeeded = if (outcome) |_| true else |_| false;

            Config.sync.lock();
            self.attempt.?.result = outcome;
            Config.ready().set(if (succeeded) .ready else .not_loaded);
            // Wake every waiter attached to this attempt.
            Config.sync.broadcast();
            // Keep the record until all waiters have taken the result.
            while (self.attempt.?.waiters > 0) Config.sync.wait();
            self.attempt = null;
            Config.sync.broadcast();
            Config.sync.unlock();

            return outcome;
        }

        /// Request that succeeded, or null before a successful load.
        pub fn loadedSource(self: *const LoaderType) ?LoadSource {
            if (!Config.ready().isReady()) return null;
            return self.request.source();
        }

        /// Check a new request against the loaded provider.
        fn accept(self: *const LoaderType, source: LoadSource) LoadError!void {
            // Readiness was checked with acquire ordering before this call.
            const published = self.request.source() orelse unreachable;
            if (eqlSource(published, source)) return;
            return error.ProviderMismatch;
        }

        /// Open, resolve, and validate without publishing; close every failure.
        fn runAttempt(source: LoadSource) LoadError!void {
            const handle = platform.open(source) catch |err| return err;

            var retain = false;
            defer if (!retain) platform.close(handle);

            if (@hasDecl(Config, "optional_symbols")) {
                inline for (Config.optional_symbols, 0..) |_, index| {
                    Config.assignMissing(index, Config.tablePtr());
                }
            }

            inline for (Config.symbols, 0..) |symbol, index| {
                const address = platform.lookup(handle, symbol.name) orelse
                    return error.MissingSymbol;
                Config.assign(index, Config.tablePtr(), address);
            }

            if (@hasDecl(Config, "optional_symbols")) {
                inline for (Config.optional_symbols, 0..) |symbol, index| {
                    if (platform.lookup(handle, symbol.name)) |address| {
                        Config.assignOptional(index, Config.tablePtr(), address);
                    }
                }
            }

            if (@hasDecl(Config, "validate")) {
                if (Config.validate(Config.tablePtr())) |refusal| {
                    std.debug.print("{s}: refusing this provider: {s}\n", .{
                        Config.library_name,
                        refusal,
                    });
                    return error.ValidationFailed;
                }
            }

            // Keep the handle: the dispatch table points into this provider for process lifetime.
            retain = true;
        }
    };
}

/// Platform dynamic-loader backend.
/// One active or undrained load attempt.
const Attempt = struct {
    /// Thread running the attempt, used for reentrancy detection.
    owner: u64,
    /// Attempt result, written under the lock before readiness leaves `loading`.
    result: LoadError!void = error.OpenFailed,
    /// Attached waiters; retain the record until they drain.
    waiters: usize = 0,
};

/// Windows UTF-16 path buffer, including room for the terminator.
const windows_path_units = 32768;

const platform = if (builtin.target.os.tag == .windows)
    Windows
else if (supported_target)
    Unix
else
    NoLoader;

/// Target without a dynamic loader; requests return `UnsupportedTarget`.
const NoLoader = struct {
    const OpenError = error{ OpenFailed, UnsupportedTarget };

    fn open(source: LoadSource) OpenError!*anyopaque {
        _ = source;
        return error.UnsupportedTarget;
    }
    fn lookup(handle: *anyopaque, name: [:0]const u8) ?*const anyopaque {
        _ = handle;
        _ = name;
        return null;
    }
    fn close(handle: *anyopaque) void {
        _ = handle;
    }
};

/// Unix dynamic loader backend.
const Unix = struct {
    const OpenError = error{ OpenFailed, UnsupportedTarget };

    fn open(source: LoadSource) OpenError!*anyopaque {
        const text = switch (source) {
            .path => |p| p,
            .system => |s| s,
        };
        var buffer: [max_source_len + 1]u8 = undefined;
        @memcpy(buffer[0..text.len], text);
        buffer[text.len] = 0;
        // `RTLD_NOW` reports dependency failures here; `RTLD_LOCAL` avoids symbol leakage.
        return std.c.dlopen(
            // Pass the NUL-terminated path required by the C loader.
            buffer[0..text.len :0].ptr,
            .{ .NOW = true, .GLOBAL = false },
        ) orelse error.OpenFailed;
    }

    fn lookup(handle: *anyopaque, name: [:0]const u8) ?*const anyopaque {
        return std.c.dlsym(handle, name.ptr);
    }

    fn close(handle: *anyopaque) void {
        _ = std.c.dlclose(handle);
    }
};

const kernel32 = struct {
    extern "kernel32" fn LoadLibraryExW(
        file_name: [*:0]const u16,
        file: ?*anyopaque,
        flags: u32,
    ) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn GetProcAddress(module: *anyopaque, name: [*:0]const u8) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn FreeLibrary(module: *anyopaque) callconv(.winapi) i32;
};

/// Windows dynamic loader backend.
const Windows = struct {
    const OpenError = error{ OpenFailed, UnsupportedTarget, SourceTooLong };

    /// Search standard directories for bare names without adding the current directory.
    const load_library_search_default_dirs: u32 = 0x0000_1000;
    const load_library_search_dll_load_dir: u32 = 0x0000_0100;

    fn open(source: LoadSource) OpenError!*anyopaque {
        const text = switch (source) {
            .path => |p| p,
            .system => |s| s,
        };
        if (text.len > windows_path_units) return error.SourceTooLong;
        var buffer: [windows_path_units + 1]u16 = undefined;
        const units = std.unicode.utf8ToUtf16Le(buffer[0..text.len], text) catch
            return error.OpenFailed;
        buffer[units] = 0;
        return kernel32.LoadLibraryExW(
            buffer[0..units :0],
            null,
            load_library_search_default_dirs | switch (source) {
                .path => load_library_search_dll_load_dir,
                .system => @as(u32, 0),
            },
        ) orelse error.OpenFailed;
    }

    fn lookup(handle: *anyopaque, name: [:0]const u8) ?*const anyopaque {
        return kernel32.GetProcAddress(handle, name.ptr);
    }

    fn close(handle: *anyopaque) void {
        _ = kernel32.FreeLibrary(handle);
    }
};
