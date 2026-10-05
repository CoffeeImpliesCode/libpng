#!/usr/bin/env bash
# Source-integrity and licence-notice check for the libpng SDK.
#
# Six questions, all answerable without a compiler:
#
#   1. Do the 614 upstream files still hash to the digests UPSTREAM.sha256 records?
#   2. Is the vendored file set exactly that set -- no missing, extra or renamed
#      file under src/?  A plain checksum run cannot see an addition.
#   3. Do UPSTREAM.md and UPSTREAM.sha256 name the same release digest?
#   4. Is README.upstream.md still byte-identical to src/README?
#   5. Is every per-file licence notice that NOTICE.md claims still in the file
#      that carries it?  libpng is NOT MIT: the core is the PNG Reference
#      Library License version 2, ci/** is MIT, .github/workflows/** is MIT-0,
#      example.c is public domain, and pngusr.dfa carries no notice at all.
#      A single-label check would miss all of that.
#   6. Do the three fixtures still hash to the digests UPSTREAM.md records?
#      (tools/check-fixtures.py does the same thing in Python; both are here so
#      a provenance gate does not depend on a Python interpreter being present.)
#
# This is a provenance gate, not a build gate. Nothing here compiles, links or
# runs a target binary; it is the check that an edit to the vendored upstream
# source cannot pass as a routine change.
#
# Usage: tools/check-provenance.sh   (run from anywhere in the repository)
#
# SPDX-License-Identifier: MIT
# See FORK-LICENSE.md for what that identifier covers.

set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
    echo "$1" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# 1. Bytes.
# ---------------------------------------------------------------------------
sha256sum -c --quiet UPSTREAM.sha256 || fail "an upstream file no longer matches UPSTREAM.sha256"
echo "all 614 upstream files match UPSTREAM.sha256"

# ---------------------------------------------------------------------------
# 2. File set.  A checksum run above cannot see a file that was ADDED, only one
#    whose bytes changed.
# ---------------------------------------------------------------------------
expected_tree=$(awk '/^[0-9a-f]{64}  / { print $2 }' UPSTREAM.sha256 | grep -E '^src/' | LC_ALL=C sort)
actual_tree=$(find src -type f | LC_ALL=C sort)
if [ "$expected_tree" != "$actual_tree" ]; then
    echo "the vendored file set differs from the recorded one:" >&2
    diff -u <(echo "$expected_tree") <(echo "$actual_tree") >&2 || true
    echo >&2
    echo "An intentional change to the native source needs an observed failure, a" >&2
    echo "small causal patch, an explicit per-file deviation record in NOTICE.md," >&2
    echo "updated digests here, and a CHANGELOG.md entry in the same change." >&2
    exit 1
fi
echo "the vendored file set is exactly the recorded 614 files"

# ---------------------------------------------------------------------------
# 3a. The release digest must be recorded identically in both records, so the
#     two files cannot disagree about which upstream release this is.
#     `-m1` rather than a pipe into `head -1`: with `pipefail` a `head` that
#     closes the pipe early sends SIGPIPE to grep and turns a successful match
#     into a failed pipeline.
# ---------------------------------------------------------------------------
digest_md=$(grep -m1 -oE '[0-9a-f]{64}' UPSTREAM.md)
digest_list=$(grep -m1 -oE '[0-9a-f]{64}' UPSTREAM.sha256)
[ -n "$digest_md" ] || fail "UPSTREAM.md records no sha256 digest"
[ "$digest_list" = "$digest_md" ] ||
    fail "UPSTREAM.md and UPSTREAM.sha256 name different release digests ($digest_md vs $digest_list)"
echo "the release digest is recorded consistently: $digest_md"

# ---------------------------------------------------------------------------
# 3b. The two records also have to agree about the byte count and the date.
# ---------------------------------------------------------------------------
for fact in "1589315 bytes" "2026-09-28"; do
    grep -qF "$fact" UPSTREAM.md || fail "UPSTREAM.md does not record '$fact'"
    grep -qF "$fact" UPSTREAM.sha256 || fail "UPSTREAM.sha256 does not record '$fact'"
done
echo "the release size and date are recorded consistently in both files"

# ---------------------------------------------------------------------------
# 4. The preserved upstream README.  README.upstream.md is the exact bytes of
#    the tarball's README; src/README is the imported original.
# ---------------------------------------------------------------------------
cmp -s src/README README.upstream.md ||
    fail "src/README and README.upstream.md are no longer byte-identical"
echo "README.upstream.md is byte-identical to the imported upstream src/README"

# ---------------------------------------------------------------------------
# 5. The per-file licence notices, exactly where NOTICE.md says they are.
#    This is the check that a single "libpng is MIT" label cannot make.
# ---------------------------------------------------------------------------

# 5a. The compiled core: the PNG Reference Library License version 2, whose
#     heading is at src/LICENSE:4.  NOT the MIT text.
grep -q '^PNG Reference Library License version 2$' src/LICENSE ||
    fail "the PNG Reference Library License version 2 heading is missing from src/LICENSE"
# 5b. ... and the historical version 1 text for libpng 0.5 through 1.6.35,
#     which the same file carries at src/LICENSE:39-42.
grep -q '^PNG Reference Library License version 1 (for libpng 0.5 through 1.6.35)$' src/LICENSE ||
    fail "the version 1 licence text is missing from src/LICENSE"
# 5c. Neither licence file may be swapped for the MIT text that is present
#     elsewhere in the same tree.
if grep -q 'MIT License' src/LICENSE; then
    fail "src/LICENSE now carries an MIT text; the core licence is PNG Reference Library version 2"
fi
echo "src/LICENSE carries the version 2 grant and the historical version 1 text, and no MIT text"

# 5d. The two MIT texts, each at the path REUSE.toml points the group at.
[ -f src/LICENSES/MIT.txt ] || fail "src/LICENSES/MIT.txt is missing"
[ -f src/LICENSES/MIT-0.txt ] || fail "src/LICENSES/MIT-0.txt is missing"
grep -q '^MIT License$' src/LICENSES/MIT.txt ||
    fail "src/LICENSES/MIT.txt no longer carries the MIT text NOTICE.md cites at its line 1"
grep -q '^MIT No Attribution$' src/LICENSES/MIT-0.txt ||
    fail "src/LICENSES/MIT-0.txt no longer carries the MIT-0 text NOTICE.md cites at its line 1"
# ... and the mapping that assigns them.
grep -q 'SPDX-License-Identifier = "MIT"' src/REUSE.toml ||
    fail "the ci/** -> MIT mapping is missing from src/REUSE.toml"
grep -q 'path = "ci/\*\*"' src/REUSE.toml ||
    fail "the ci/** mapping in src/REUSE.toml no longer names ci/**"
grep -q 'SPDX-License-Identifier = "MIT-0"' src/REUSE.toml ||
    fail "the .github/workflows/** -> MIT-0 mapping is missing from src/REUSE.toml"
grep -q 'path = ".github/workflows/\*\*"' src/REUSE.toml ||
    fail "the MIT-0 mapping in src/REUSE.toml no longer names .github/workflows/**"
echo "the ci/** MIT and .github/workflows/** MIT-0 mappings and both texts are in place"

# 5e. src/example.c's public-domain dedication. The sentence is wrapped across
#     src/example.c:18-19, so it is matched with the comment leader and the line
#     break collapsed rather than as one literal line: a single-line grep for
#     "is hereby placed in the public domain" found nothing on a file that
#     carries the dedication, and the check failed on unmodified upstream bytes.
tr '\n' ' ' < src/example.c | tr -s ' *' ' ' |
    grep -q 'is hereby placed in the public domain' ||
    fail "the public-domain dedication in src/example.c is missing"
echo "src/example.c still carries its own public-domain dedication"

# 5f. src/pngusr.dfa carries NO notice at all.  That is a fact NOTICE.md
#     records, and a fact that has to keep being true: if someone adds a header
#     the inventory has to change with it.
if head -20 src/pngusr.dfa | grep -qiE 'copyright|licen[cs]e|SPDX'; then
    fail "src/pngusr.dfa now carries a notice; NOTICE.md says it carries none and must be updated"
fi
echo "src/pngusr.dfa still carries no copyright or licence header, as NOTICE.md records"

# 5g. Each SIMD directory restates the libpng licence in its own contributor
#     block, individually, exactly as NOTICE.md's table says.
for simd_file in \
    src/arm/filter_neon_intrinsics.c \
    src/intel/filter_sse2_intrinsics.c \
    src/mips/filter_msa_intrinsics.c \
    src/powerpc/filter_vsx_intrinsics.c \
    src/loongarch/filter_lsx_intrinsics.c \
    src/riscv/filter_rvv_intrinsics.c
do
    grep -q 'This code is released under the libpng license' "$simd_file" ||
        fail "the libpng licence statement is missing from $simd_file"
done
echo "all six architecture directories still restate the libpng licence in their own headers"

# 5h. Upstream's own ignore file is preserved, and no fork entry has eaten it.
[ -f src/.gitignore ] || fail "src/.gitignore is missing; upstream's ignore file must be preserved"
grep -q '^pnglibconf\.\[ch\]$' src/.gitignore ||
    fail "src/.gitignore no longer carries upstream's pnglibconf.[ch] entry"
echo "upstream's src/.gitignore is preserved, including its pnglibconf.[ch] entry"

# 5i. The records themselves have to keep naming the terms they inventory, so a
#     future edit cannot quietly relabel the tree.
for record in NOTICE.md FORK-LICENSE.md; do
    grep -q 'PNG Reference Library License version 2' "$record" ||
        fail "$record no longer names the PNG Reference Library License version 2"
done
grep -q 'MIT' FORK-LICENSE.md ||
    fail "FORK-LICENSE.md no longer carries the MIT permission text for the fork's own files"
grep -q 'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND' FORK-LICENSE.md ||
    fail "FORK-LICENSE.md does not reproduce the MIT permission and warranty text"
echo "the licence records still name the terms they inventory"

# ---------------------------------------------------------------------------
# 6. The fixtures.  These are fork-authored, and they are inputs to the
#    behavioural tests, so a silent edit to one changes what the tests prove.
# ---------------------------------------------------------------------------
check_fixture() {
    local path="$1" digest="$2" size="$3"
    [ -f "$path" ] || fail "$path is missing"
    local actual
    actual=$(sha256sum "$path" | awk '{ print $1 }')
    [ "$actual" = "$digest" ] ||
        fail "$path no longer matches the digest UPSTREAM.md records ($actual vs $digest)"
    local actual_size
    actual_size=$(wc -c < "$path" | tr -d ' ')
    [ "$actual_size" = "$size" ] ||
        fail "$path is $actual_size bytes, not the recorded $size"
}
check_fixture fixtures/grey8x8-200.png \
    4cd467a6c469e7890696808a829808d1137a991a8f6a55c9113339853272a283 71
check_fixture fixtures/rgb4x3.png \
    a37878d39ff5765cfa4cee3cd7d9723b3cb761e65ae0d9f3f0873ff96adf44ff 97
check_fixture fixtures/rgba2x2.png \
    3c5f2d8cdf5195958619e1ff666f9a2fb439863996996e2de09f54b15f512ba9 80
# The digests above have to be the ones the records actually carry, or this
# check would pass against a table nobody else reads.
for digest in \
    4cd467a6c469e7890696808a829808d1137a991a8f6a55c9113339853272a283 \
    a37878d39ff5765cfa4cee3cd7d9723b3cb761e65ae0d9f3f0873ff96adf44ff \
    3c5f2d8cdf5195958619e1ff666f9a2fb439863996996e2de09f54b15f512ba9
do
    grep -qF "$digest" UPSTREAM.md ||
        fail "UPSTREAM.md no longer records the fixture digest $digest"
done
echo "all three fixtures match the digests and sizes UPSTREAM.md records"

echo "provenance checks passed"