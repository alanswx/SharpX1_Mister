# SPDX-License-Identifier: GPL-2.0-only
"""Fixed CZ-8FB01 native SAVE/NEW/LOAD transcripts, independent of observed RGB."""
from check_basic_reference import BANNER, check_rows

MARKER = b'94217365'
MUTANT = b'94217364'
PROGRAM = b'10 PRINT "' + MARKER + b'"'
SAVE = b'SAVE "X1TST01"'
LOAD = b'LOAD "X1TST01"'


def rows(kind, lower=True, mutant=False):
    echo = lambda s: s.lower() if lower else s
    p, s, l = map(echo, (PROGRAM, SAVE, LOAD))
    empty = (p, s, b'Ok', echo(b'NEW'), b'Ok', echo(b'LIST'), b'Ok')
    if kind == 'program':
        return 13, (p,)
    if kind == 'saved':
        return 13, (p, s, b'Ok')
    if kind == 'protected':
        return 13, (p, s, b'Device I/O error', b'Ok')
    if kind == 'cleared':
        return 13, empty
    if kind == 'loaded':
        return 13, (*empty, l, b'Ok')
    if kind == 'final':
        return 9, (*empty, l, b'Ok', echo(b'LIST'), PROGRAM, b'Ok', echo(b'RUN'), MARKER, b'Ok')
    if kind == 'no-load':
        return 13, (*empty, echo(b'LIST'), b'Ok', echo(b'RUN'), b'Ok')
    if kind == 'cold-loaded':
        return 13, (l, b'Ok')
    if kind == 'cold-no-load':
        return 13, (echo(b'LIST'), b'Ok', echo(b'RUN'), b'Ok')
    if kind == 'cold-final':
        marker = MUTANT if mutant else MARKER
        program = b'10 PRINT "' + marker + b'"'
        return 13, (l, b'Ok', echo(b'LIST'), program, b'Ok', echo(b'RUN'), marker, b'Ok')
    raise AssertionError(kind)


def check(dimensions, pixels, font, kind, vertical=2, lower=True, mutant=False):
    first, transcript = rows(kind, lower, mutant)
    return dict(banner=check_rows(dimensions, pixels, font, 0 if kind == 'final' else 4, (BANNER,), vertical),
                transcript=check_rows(dimensions, pixels, font, first, transcript, vertical))


def result(dimensions, pixels, font, cold=False, vertical=2):
    return check_rows(dimensions, pixels, font, 19 if cold else 22, (MARKER, b'Ok'), vertical)


def sectors(data):
    """Parse the selected fixed 40x2x16x256 local D88 fixture, not native FS."""
    assert len(data) >= 0x2b0 and int.from_bytes(data[28:32], 'little') == len(data)
    offsets = [int.from_bytes(data[32 + i * 4:36 + i * 4], 'little') for i in range(164)]
    assert all(offsets[:80]) and not any(offsets[80:])
    result = []
    for track, offset in enumerate(offsets[:80]):
        stop = offsets[track + 1] if track < 79 else len(data)
        for sector in range(16):
            header = data[offset:offset + 16]
            assert len(header) == 16 and header[:4] == bytes((track // 2, track % 2, sector + 1, 1))
            assert int.from_bytes(header[4:6], 'little') == 16
            size = int.from_bytes(header[14:16], 'little')
            assert size == 256 and offset + 16 + size <= stop
            result.append((track, sector + 1, offset, offset + 16, offset + 16 + size))
            offset += 16 + size
        assert offset == stop
    return result


def disk_changes(original, written):
    assert len(original) == len(written) and original[:0x2b0] == written[:0x2b0]
    layout = sectors(original)
    assert sectors(written) == layout
    changed = []
    for track, sector, header, start, end in layout:
        assert original[header:start] == written[header:start], 'native SAVE must not alter D88 transport metadata'
        if original[start:end] != written[start:end]:
            changed.append(dict(track=track, sector=sector, changed_bytes=sum(a != b for a, b in zip(original[start:end], written[start:end]))))
    assert changed, 'no native sector payload write'
    return changed
