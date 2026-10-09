# Turbo Z sequential GRAM fetch buffer

Original `rtl/x1_z_gram_fetch.sv` obtains the extra source bytes required by
the [primary screen-chapter matrix](TURBO_Z_PALETTE_CONTRACT.md#multi-mode-fetch-requirements-from-the-same-chapter).
This is an integration building block, **not connected to the shared renderer**
and not a claim that any Turbo Z graphics mode displays correctly yet.

## Interface and implemented schedule

One synchronous video address per component is retained; no GRAM replication,
extra memory read ports or CPU-port multiplexing is introduced. The request
captures an already formed 14-bit within-bank base, an internal mode ID,
screen selection and raster parity. Mode IDs are not native ASIC register bits.
Live changes/competing requests while busy cannot redirect the buffer.

| Internal ID | Component byte lanes in increasing colour-bit significance |
|---|---|
| 0, 320×200/4096 | bank 0 q; bank 0 q+400h; bank 1 q; bank 1 q+400h |
| 1, two-screen 320×200/64 | selected screen bank q; same bank q+400h |
| 2, 640×200/64 | bank 0 q; bank 1 q |
| 3, 320×400/64 | raster-parity bank q; same bank q+400h |
| 4, 640×400/8 | raster-parity bank q |

The buffer issues one address on each physical video edge and captures each
RAM response on the following edge, using a pending lane tag. Output valid is
a one-edge pulse after 5/3/2 edges for four/two/one-byte layouts respectively,
measured from acceptance. All component lanes arrive together; unused lanes
are explicitly zero, not previous-mode data. Only valid buffers may be used.
`request`/`ready` is an ordinary handshake, not held-strobe deduplication.
Modes 5–7 reject without starting a fetch. Reset masks reads/ready, flushes
pending responses and buffer data, and does not clear the component RAMs.

The `+400h` offset wraps within the chosen 16 KiB bank. That explicit interface
policy prevents accidental bank carries; it **does not qualify native CRTC
wrap/address formation**. Reduced-colour index expansion, palette banks,
two-screen priority, internal eight-colour palette and pixel serialization are
upstream/downstream integration work, not secretly inferred here.

## Executed verification

```sh
make -C verilator test-z-gram-fetch
```

Verilator 5.044, assertions/delays enabled, no warning suppressions. The fixture
instantiates three actual `x1_video_ram #(15)` machine primitives. Genuine
CPU-port writes initialize all 96 KiB with original address/component patterns;
no direct array pokes, ROM/fonts or commercial bytes. The CPU clock is 32 MHz;
independent video half-periods are 17,500 / 11,640 / 25,000 ps. These are test
clock ratios, not a fitted frequency or exact nominal X3 qualification.

For each profile, all 16,384 base addresses cover all five layouts, both
screen pages and both raster parities: 131,072 requests / 262,144 selected
reads in the exhaustive matrix. A division/modulo-based oracle independently
predicts bank/offset and each returned byte. Every request checks exactly one
read per required lane, latency, frozen live metadata, zero unused lanes and
one response pulse. Additional tests cover invalid IDs, reset at every
four-byte pipeline seam, no old response replay, fresh post-reset reads and
retained CPU-port data. Concurrent same-address CPU writes are not observed;
no dual-clock collision value or CPU/display arbitration is claimed.
The final fixture also instantiates the actual `x1_video_timing` enable
generator. At each clock ratio, all four high/low-scan × 40/80-column settings
run 2,048 physical edges apiece: phase-0 requests must finish before the
existing enabled renderer's phase-14 shifter-load event. Each setting observes
more than twenty completed character deadlines with no admission overrun.
This qualifies the proposed enabled-profile fetch deadline, not CRTC address
formation, legacy fabric phase or pixel alignment.

All three initial profiles exit zero in `/tmp/x1-z-gram-fetch-qualified.log`.
The extended deadline fixture also passes all profiles in
`/tmp/x1-z-gram-fetch-deadline-qualified.log`.
Runner SHA-256 is unchanged before/after qualification:
`642b952d164dca9ce64046a29fab1e88a862a17b02fb4f2bd067f6ad57289393`.
RTL / fixture SHA-256:
`a80483da107961d7bfc57391c22b5902ee5b25237421687f0276105863b6304d` /
`0279cd5dba4ea775470cde83ca727c65ca7d656477592fe2c038e2ae010c3c58`.
An isolated mutation always choosing bank 0 in full-colour mode fails the
unchanged fixture on its first full-colour request, exit one, with wrong
component byte lanes. Production RTL is unmodified. Logs:
`/tmp/x1-z-gram-negative-build.log` and `/tmp/x1-z-gram-negative-run.log`.
The same mutation is rebuilt against the final extended fixture; evidence is
recorded separately in `/tmp/x1-z-gram-negative-deadline-build.log` and
`/tmp/x1-z-gram-negative-deadline-run.log`.

## Next integration gates

Connect this schedule to actual CRTC phase and native base-address formation,
then serialize component bits and perform real synchronous palette reads.
The legacy fabric-clock CRTC and opt-in enabled CRTC do not advance at the
same master phase; do not copy a single start phase between profiles without
an executed timing check. Prove the buffer deadline before each shifter load,
RGB/sync/blank/CE latency, MA/raster wrap and live mode exits with CPU-written
GRAM. Implement palette ownership before enabling its display consumer.
Qualify all five pixel formats and both low-scan screens, text/blackclip,
native software, combined Quartus resources/timing/CDC and physical RGB12.
This module is outside `rtl/machine.qip` until connected. No board revision,
snapshot layout, ordinary profile or RBF changes; Z3 remains incomplete.
