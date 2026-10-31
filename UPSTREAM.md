# Upstream

| Field | Value |
|---|---|
| Project | libpng, the PNG Reference Library |
| Project site | <http://www.libpng.org/pub/png/libpng.html> |
| Release | 1.6.59 (2026-09-28) |
| Source archive | `libpng-1.6.59.tar.gz` |
| Download | <https://downloads.sourceforge.net/project/libpng/libpng16/1.6.59/libpng-1.6.59.tar.gz> |
| Archive size | 1589315 bytes |
| SHA-256 | `86a3e4b501f7f50e392c4e456ea158893e9a595b1c63eb88c7bb9f6cf8772dad` |
| Imported files | 614 |
| Source | Full release archive; no upstream Git history or commit SHA |
| Removed upstream files | None |
| Digest inventory | [`UPSTREAM.sha256`](UPSTREAM.sha256) |

The `src/` tree is the unmodified archive content. `README.upstream.md` is a copy of upstream's `src/README`.

## Fork-authored fixtures

`tools/make-fixtures.py` constructs these PNGs from the format specification,
without libpng. Their pixels are independent known answers in `tests.zig`.
They are not part of the upstream archive.

| Fixture | SHA-256 | Bytes |
|---|---|---:|
| `fixtures/grey8x8-200.png` | `4cd467a6c469e7890696808a829808d1137a991a8f6a55c9113339853272a283` | 71 |
| `fixtures/rgb4x3.png` | `a37878d39ff5765cfa4cee3cd7d9723b3cb761e65ae0d9f3f0873ff96adf44ff` | 97 |
| `fixtures/rgba2x2.png` | `3c5f2d8cdf5195958619e1ff666f9a2fb439863996996e2de09f54b15f512ba9` | 80 |
