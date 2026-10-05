# X3 video status → PPI crossing

October 5, 2026. Follow-up to PCG/metadata checkpoint `15a0655`.
`rtl/sharpx1.v` previously fed video-domain VSYNC and VDISP directly into
system-domain PPI/CPU data. The earlier source-bound X3 fit exposed a real
video→CPU setup failure; assembler success was not timing closure.

`rtl/x1_video_status.sv` adds two independent two-stage level synchronizers
only for `TURBO_VIDEO_MASTER=1`. The default base and ordinary/single-clock
Turbo profiles retain their exact combinational status path. PPI B7 remains
VDISP and B2 remains VSYNC; polarity, decode and other PPI inputs are unchanged.
No clocks, enables, dot rates, rendering, ROM or CPU timing were changed.

These are independent levels, not a coherent snapshot of two related bits
and not an event queue. A pulse shorter than the sampling interval is not
guaranteed to be observed. Machine reset asserts both output levels low;
reset-release recovery/metastability and placement still need hardware review.
Quartus 17 previously ignored `async_reg`; the source attribute alone is not
an SDC constraint or a successful fitted synchronizer/MTBF report.

## Original tests and remaining signoff

`make -C verilator test-video-status` passes three asynchronous clock ratios
(system half-period 5 versus video 3/7/31), checking exact pipeline latency,
all independent level combinations, compatible bypass, persistent levels,
stopped destination clock, asynchronous reset and resumed sampling.
Log: `/tmp/x1-x3-ppi-status-unit.log`. This is functional simulation,
not analog metastability validation.

`test_video_status.py` is an original real-CPU diagnostic: it programs a CRTC
and input-mode PPI, polls B7/B2 into CPU-written OR/AND accumulators and
requires both asserted/deasserted states after cold and warm reset. It does
not inject registers/PC/RAM or use native assets. Rebuilt delay-aware X3
execution passes both cold and 25 ms/10 us warm-reset cases at system
32 MHz / nominal video 42.954540 MHz: OR=`84`, AND=`00`.
`make -C verilator test-video-status-cpu` repeats that check. The diagnostic's
short custom CRTC is for level polling, not normal-frame/render acceptance.
The existing PPI/PSG port diagnostic also passes rebuilt fast base and
delay-aware X3 runners. The original CPU-programmed 80-column/raster-1 ANK16
case passes all 640×400 actual RGB pixels with eight complete frames, unchanged
frame hash `3eab7f8f2c08d9a5`, HS=41.718750 us and VS=18.689906250 ms.
It retains the original 200 ms duration (6,400,000 reference cycles), generated
4096-byte font and delay-aware X3 clock profile. Log:
`/tmp/x1-v08-pixels.log`. Raster-3/40-column warm-reset also passes every
320×400 pixel: retained generated font, 120 ms/10 us reset, six completed
frames and unchanged hash `8ec9d6393e3dde65` (`/tmp/x1-v08-pixels-warm.log`).
HS=41.718750 us, VS=18.689875000 ms; both retain the original duration and
sampling-edge tolerance. This is focused coverage, not native compatibility.

Logs: `/tmp/x1-x3-ppi-cpu.log`, `/tmp/x1-v08-base-ppi.log`,
`/tmp/x1-v08-x3-ppi.log`. Runner SHA-256s:

| Profile | SHA-256 |
|---|---|
| Delay-aware X3 | `466ab72cca8d8f3edb4cad56d20a2d61307d4d1f05d04e79bca3574d5328ccf3` |
| Fast base, SDL/savable | `f6cb0d69bec12ca3bd0ef00a94fa680038cd92239d05d958953e900385662808` |
| Delay-aware base | `aa3dabc096e482f47d7943dec84c28a2dcb797a84b82a887ce69f641f422addb` |

The rebuilt base passes timing/reset/delayed-event/FST determinism and
v08 snapshot continuity, v07 rejection, clock-profile rejection and SDL
joystick adapter checks (`/tmp/x1-v08-timing.log`, `/tmp/x1-v08-snapshot.log`).
X3 wrapper lint passes with inherited warnings; it is not Quartus validation.

The new serialized state requires **v08**, rejecting v07 and earlier models.
The separate Quartus worker is building frozen `15a0655`, which **predates
this crossing**. Its results cannot verify this follow-up or remove the
remaining PCG upload, reset, bundled measurement and HDMI clock-mux issues.
No timing exceptions or clock-group constraints have been added here.

Next: broaden active-pixel/mode-transition coverage and refit this exact
source; review first-stage constraints/chain recognition,
second-stage timing, recovery and all remaining crossings. Do not blanket-cut
the actual system/video clocks or claim timing closure from lint/unit tests.
