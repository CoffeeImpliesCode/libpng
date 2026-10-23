# Zig facade API

The facade wraps common read and write operations and exposes the translated C API as `c`. `Reader` and `Writer` own libpng structures; `Rows` owns its allocations. `Source` and `Sink` borrow caller-owned storage. Facade errors cover checked conditions; malformed input may cause libpng to `longjmp` instead of returning an error.

Treat each `Reader`, `Writer`, and `Rows` as a single-owner value: copying one does not create a second owner. Call its `deinit` once.

## Module exports

| Export | Contract |
|---|---|
| `c` | Translated declarations from the same headers used to build the library. |
| `Error` | Checked conditions: `OutOfMemory`, `InfoStructUnavailable`, `NotPng`, `HeaderMissing`, `RowBytesUnavailable`, `RowStrideMismatch`, and `SinkOverflow`. |
| `runtime_loaded` | Compile-time `bool` identifying the runtime-loading build. |
| `LoadSource`, `LoadError` | Provider selector and errors returned by `load`. |
| `load(source)` | Opens the explicitly named path or system provider in runtime builds; a successful provider remains loaded for the process lifetime. Calling it in a linked build panics. |
| `loadedSource()` | Returns the retained provider request, or `null` in a linked build. |

## Value types

- `signature` is the eight-byte PNG signature. `Source.hasSignature()` checks it.
- `ColorType` maps libpng colour types; tags are `greyscale`, `rgb`, `indexed`, `greyscale_alpha`, and `rgba`. `Interlace` is `none` or `adam7`.
- `Header` stores the IHDR fields. `rawColorType()` and `rawInterlace()` return the corresponding C integer values.
- `Source.init(bytes)` borrows the input slice; keep both the `Source` and its bytes alive while reading. `offset` is the next byte read. Short input makes `hasSignature()` return `false`.
- `Sink.init(buffer)` borrows fixed output storage. `written()` returns the prefix stored so far; `append()` records dropped bytes, and `hasOverflowed()` reports them. A writer reports `SinkOverflow`; the stored prefix is incomplete.
- `Rows.alloc(allocator, height, row_bytes)` allocates contiguous exact-stride storage and a row-pointer array. It returns `RowBytesUnavailable` for zero stride, `RowStrideMismatch` on size overflow, or an allocator error. Call `deinit()` to release both allocations with the stored allocator; keep that allocator valid until then. `slice(row)`, `height()`, `asPointers()`, and `fitsRow(len)` expose the rows.

## Reader

`Reader.open()` returns `OpenError!Reader`, where `OpenError` is `OutOfMemory` or `InfoStructUnavailable`. The reader owns its libpng structures; `deinit()` releases them and is safe to call again. `isOpen()` reports the state. `handle()` and `infoHandle()` panic after teardown.

- `setSource(source)` installs a borrowed input source; keep it alive for reads.
- `readInfo(source)` checks the PNG signature and returns `Header`; it can return `NotPng` or `HeaderMissing`.
- `rowBytes()` returns the transformed row stride or `RowBytesUnavailable`.
- `readImage(rows)` requires rows with the exact stride. `readRow(row)` requires a buffer at least that long. Both return `RowStrideMismatch` for an insufficient stride.
- `readEnd()` consumes trailing chunks.

## Writer

`Writer.open()` returns `OpenError!Writer` with the same allocation errors as `Reader.open()`. The writer owns its libpng structures; `deinit()` releases them and is safe to call again. `isOpen()` reports the state. `handle()` and `infoHandle()` panic after teardown.

- `writeInfo(sink, header)` installs the borrowed sink and writes the header; keep the sink and its buffer alive while writing.
- `rowBytes()` returns the required stride or `RowBytesUnavailable`.
- `writeRow(row)` requires at least that stride; `writeImage(rows)` requires an exact-stride `Rows` value.
- `writeEnd()` writes trailing chunks. Write operations return `SinkOverflow` if the fixed sink dropped bytes.

`Writer.sinkHandle()` returns the installed sink and panics before `writeInfo()`.
