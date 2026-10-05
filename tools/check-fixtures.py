#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# See ../FORK-LICENSE.md for what that identifier covers.

"""Fixture-digest check for the libpng SDK.

Three questions, all answerable without an image library and without a
compiler:

  1. Do the three PNG fixtures still hash to the digests UPSTREAM.md records?
  2. Are they still the recorded byte lengths?
  3. Do UPSTREAM.md and this script actually name the same digests?  Otherwise
     the check would pass against a table nobody else reads.

This is a **provenance check, not a behavioural gate.** It decodes nothing,
asserts nothing about libpng, and runs no target binary. Its only subject is
that the fixture bytes have not moved underneath the tests that read them.

Why the digests matter at all: the expected pixels in `tests.zig` were computed
by hand from ISO/IEC 15948 and written into `tools/make-fixtures.py`, so a
fixture is an **independent known answer** rather than a round trip. That
property only survives while the file is the same file. A silently edited
fixture would turn the strongest kind of test in this package into the weakest.

Usage:
    python3 tools/check-fixtures.py

Exit status is 0 when every fixture matches, 1 otherwise.
"""

import hashlib
import os
import re
import sys

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# path, sha256, byte length. The digests and sizes are the ones recorded in
# UPSTREAM.md, in CHANGELOG.md entry 1 and in tools/check-provenance.sh.
FIXTURES = (
    (
        "fixtures/grey8x8-200.png",
        "4cd467a6c469e7890696808a829808d1137a991a8f6a55c9113339853272a283",
        71,
    ),
    (
        "fixtures/rgb4x3.png",
        "a37878d39ff5765cfa4cee3cd7d9723b3cb761e65ae0d9f3f0873ff96adf44ff",
        97,
    ),
    (
        "fixtures/rgba2x2.png",
        "3c5f2d8cdf5195958619e1ff666f9a2fb439863996996e2de09f54b15f512ba9",
        80,
    ),
)


def digest_of(path):
    """SHA-256 of one file, read in full."""
    hasher = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(65536), b""):
            hasher.update(block)
    return hasher.hexdigest()


def main():
    failures = []

    for relative, expected_digest, expected_size in FIXTURES:
        path = os.path.join(REPO_ROOT, relative)
        if not os.path.isfile(path):
            failures.append(f"{relative} is missing")
            continue

        actual_digest = digest_of(path)
        actual_size = os.path.getsize(path)

        if actual_digest != expected_digest:
            failures.append(
                f"{relative}: digest is {actual_digest}, not the recorded "
                f"{expected_digest}"
            )
            continue
        if actual_size != expected_size:
            failures.append(
                f"{relative}: {actual_size} bytes, not the recorded {expected_size}"
            )
            continue
        print(f"{relative}: {actual_digest} ({actual_size} bytes) as recorded")

    # The records and this script must not drift apart. Without this, a later
    # wave could change one of the two tables and the check would keep passing
    # against a digest no document states.
    upstream_md = os.path.join(REPO_ROOT, "UPSTREAM.md")
    try:
        with open(upstream_md, "r", encoding="utf-8") as handle:
            prose = handle.read()
    except OSError as error:
        failures.append(f"UPSTREAM.md could not be read: {error}")
        prose = ""

    for relative, expected_digest, _ in FIXTURES:
        if expected_digest not in prose:
            failures.append(
                f"UPSTREAM.md no longer records the digest for {relative}; this "
                "script and the record disagree and one of them has to move"
            )
        if os.path.basename(relative) not in prose:
            failures.append(
                f"UPSTREAM.md no longer mentions {os.path.basename(relative)}"
            )

    # A recorded digest has to be a real digest. This catches a truncated or
    # mistyped value that would otherwise be compared as an unequal-but-plausible
    # string.
    for _, expected_digest, _ in FIXTURES:
        if re.fullmatch(r"[0-9a-f]{64}", expected_digest) is None:
            failures.append(
                f"the recorded digest {expected_digest!r} is not 64 lowercase "
                "hex characters, so it cannot be a sha256"
            )

    if failures:
        for line in failures:
            print(f"check-fixtures: {line}", file=sys.stderr)
        print(
            "check-fixtures: a fixture changed. Re-deriving one means deciding "
            "whether the expected pixels in tests.zig are still right, moving "
            "the digests in UPSTREAM.md, UPSTREAM.md's fixture table and "
            "tools/check-provenance.sh, and adding a CHANGELOG.md entry -- in "
            "the same change. A fixture is an independent known answer; "
            "editing it silently turns the strongest test in this package into "
            "a round trip.",
            file=sys.stderr,
        )
        return 1

    print("all three fixtures match their recorded digests and sizes")
    print("check-fixtures: provenance only -- no image was decoded and no "
          "assertion about libpng was made")
    return 0


if __name__ == "__main__":
    sys.exit(main())