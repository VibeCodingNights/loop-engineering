#!/usr/bin/env python3
"""char_guard.py - guard a file against exceeding a Unicode character budget.

Usage:
    char_guard.py FILE [MAX]

Counts the number of Unicode characters (len(text)) in FILE and compares it
against MAX (default 4000).

Behavior:
    N <= MAX  -> print "OK: <FILE> <N>/<MAX> chars" to stdout, exit 0
    N >  MAX  -> print "OVER: <FILE> <N>/<MAX> chars (over by <K>)" to stderr,
                 exit 1  (K = N - MAX)

Errors (missing file, bad arguments) are written to stderr with exit code 2.
Pure Python 3 standard library, no third-party dependencies.
"""

import sys

DEFAULT_MAX = 4000

USAGE = "usage: char_guard.py FILE [MAX]"

HELP = """{usage}

Count Unicode characters in FILE and check against a maximum budget.

Positional arguments:
  FILE   path to the file to measure
  MAX    maximum allowed character count (default: {default_max})

Exit codes:
  0  file is within budget (prints "OK: ..." to stdout)
  1  file exceeds budget   (prints "OVER: ..." to stderr)
  2  usage error or file could not be read (message to stderr)
""".format(usage=USAGE, default_max=DEFAULT_MAX)


def _die_usage(message):
    """Write a usage error to stderr and exit with code 2."""
    sys.stderr.write("char_guard.py: error: {0}\n".format(message))
    sys.stderr.write(USAGE + "\n")
    raise SystemExit(2)


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)

    # Help is handled before any other validation so -h always works.
    if "-h" in argv or "--help" in argv:
        sys.stdout.write(HELP)
        return 0

    if not argv:
        _die_usage("missing required argument FILE")
    if len(argv) > 2:
        _die_usage("too many arguments (expected FILE [MAX])")

    path = argv[0]

    if len(argv) == 2:
        raw_max = argv[1]
        try:
            max_chars = int(raw_max)
        except ValueError:
            _die_usage("MAX must be an integer (got {0!r})".format(raw_max))
        if max_chars < 0:
            _die_usage("MAX must be non-negative (got {0})".format(max_chars))
    else:
        max_chars = DEFAULT_MAX

    try:
        with open(path, "r", encoding="utf-8") as handle:
            text = handle.read()
    except FileNotFoundError:
        sys.stderr.write("char_guard.py: error: no such file: {0}\n".format(path))
        return 2
    except IsADirectoryError:
        sys.stderr.write("char_guard.py: error: is a directory: {0}\n".format(path))
        return 2
    except OSError as exc:
        sys.stderr.write(
            "char_guard.py: error: cannot read {0}: {1}\n".format(path, exc.strerror or exc)
        )
        return 2

    count = len(text)

    if count <= max_chars:
        print("OK: {0} {1}/{2} chars".format(path, count, max_chars))
        return 0

    over_by = count - max_chars
    sys.stderr.write(
        "OVER: {0} {1}/{2} chars (over by {3})\n".format(path, count, max_chars, over_by)
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
