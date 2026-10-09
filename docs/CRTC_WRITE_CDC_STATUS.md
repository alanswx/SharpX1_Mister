# Experimental X3 coherent CRTC writes

## Scope

`TURBO_VIDEO_MASTER=1` now transfers a held nine-bit `{RS,data}` packet
from SYS to VID before the actual inherited CRTC MPU consumes it. Ordinary
machine profiles retain their original direct MPU bus. CPU and DMA WAIT
remain asserted until destination consumption and synchronized acknowledgement.
This is functional transport latency, not a measured native ASIC bus contract.
The mirrored `18xx` write decode and address-bit-zero RS selection are retained;
no CRTC readback port is invented. Local MAME `src/mame/sharp/x1.cpp` maps
address/register writes at `1800`/`1801` without a corresponding read mapping.

`rtl/x1_crtc_write.sv` is original GPL-2.0-only code in the shared machine
manifest. Its request and acknowledgement each use two destination samples;
the bundled packet stays held until acknowledgement. The destination registers
the packet, then acknowledges on the following edge when the MPU actually
consumes the write. Only the MPU bus clock changes: other inherited video
CPU-bus consumers are not silently moved. CRTC programming is retained by
warm reset, as before. A reset before consumption cancels a pending write;
a reset after consumption must not replay it.

## Executed local checks

- `test-crtc-write`: actual inherited MPU, four video half-periods
  11,640/17,500/15,625/125,000 ps against SYS half-period 15,625 ps. R5/R9
  packet sweeps, altered source data after capture, held selection, exact
  single writes, stopped SYS/VID and pre/post-consumption reset checks pass.
  The actual raw-bus negative control fails the expected coherence assertion.
- `test-machine-crtc-write`: generated original IPL uploaded through ioctl,
  real CPU writes through mirrored ports, 132 writes plus retained-IPL warm
  reboot, exactly 264 MPU commits. Three video half-periods
  11,640/17,500/125,000 ps pass, including genuine stopped-video CPU WAIT.
- `test-machine-crtc-dma-reset`: five actual BUSACK-owned reset scenarios
  pass: reset during read/write, stopped SYS, attempted asset upload during
  drain, and stopped VID while a CRTC write is pending. Each drains one
  pair, reboots from retained IPL and completes sixteen more pairs; exactly
  seventeen actual MPU writes and correct R5 values are required.
  The four RAM and five PCG reset controls also pass again.
- The fresh delay-aware X3 pixel matrix passes all sixteen 40/80-column
  graphics/text/mixed/pattern/stretch/PCG/blink cases, checking 1,536,000
  exact pixels at SYS=32 MHz and nominal VID=42,954,540 Hz. Frozen inputs
  are under ignored `verilator/obj_dir_headless/crtc-qualification-KkSnAN/`.
- Current X3 snapshot continuation/profile checks and ordinary snapshot
  checks pass. X3 identity adds bit 62 while retaining format v17; actual
  unmodified pre-CRTC and pre-blink X3 states are rejected before
  deserialization. Ordinary serialized layout/checksum remains unchanged
  against the archived baseline. This is not byte conversion or native boot.
- Connected experimental control/reset tests and wrapper lint pass;
  wrapper lint does not qualify Quartus or physical CDC placement.

### DMA diagnostic correction, not a DMA RTL workaround

The first new CRTC fixture failed: actual DMA I/O address was `0000`, with
IORQ active and M1 inactive-high, rather than intended `1801`. Explicit bus
assertions reproduced that failure in `/tmp/x1-crtc-dma-address-probe.log`.
The generated CPU program omitted the already-qualified fixed-destination
two-LOAD sequence (`dma_tb.sv`, `DMA_CPU_BUS_STATUS.md`): LOAD initializes
only the selected source counter. It now temporarily selects B as source,
LOADs B, then selects/LOADs true A before ENABLE. No DMA RTL was changed.
The actual-address assertion remains, and all five reset cases pass in
`/tmp/x1-crtc-dma-qualified.log`. No assertions or target values were relaxed.

## Source and evidence binding

Machine SHA-256:
`4970b7922499432ae2106ab650b0bc635af9f3a988df0b0254c5822f575f0d7e`.
Transport SHA-256:
`e7a0711caa01b04c84b1174efcc076bb2d5aae199a1bf75f72b5a6aed7897fa7`.
Legacy video SHA-256:
`0441f52361d5a668d356b2a05a9ce566571dc35d527cc3c5d1c2b274121033db`.
Frozen X3 delay-aware runner SHA-256:
`0a479baab7e5656de37abb33056fe6ffba995d512e51a3c3b772cf0121b41e99`.
Logs: `/tmp/x1-crtc-write-phases.log`,
`/tmp/x1-crtc-machine-regression.log`,
`/tmp/x1-crtc-x3-pixel-matrix-cwd.log`,
`/tmp/x1-crtc-x3-snapshot.log`, `/tmp/x1-crtc-base-snapshot.log`,
`/tmp/x1-crtc-connected-regression.log`.

## Still open

Full ordinary regression is running in `/tmp/x1-crtc-full-baseline.log`;
partial PASS reports are not completion. The two older frozen 120-case Z
matrices are historical for this changed machine. Fresh combined-Z pixels,
commercial/native Turbo software, physical reset/input/audio and current-source
Quartus fitting/timing remain required. The earlier `6e334b4` blink RBF does
not include this change and fails overall setup timing.

FPGA acceptance needs source-bound request/ack synchronizer inventories,
held nine-bit packet bounds, actual VID MPU/consumer endpoints, reset-release
checks and complete global timing. Do not waive whole clock domains or treat
per-bit synchronizers as coherent register writes. No new timing exception
or physical hardware acceptance is established by these simulation tests.
