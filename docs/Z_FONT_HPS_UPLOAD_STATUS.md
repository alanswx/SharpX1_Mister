# Full-font HPS upload error recovery

Later October 15: [separate CPU-visible completion diagnostics](Z_FONT_CPU_COMPLETION_STATUS.md)
now observe the final VRAM-check success path on the same RBF, with matched
failing ROMs at both widths. They do not retroactively qualify the older
malformed-retry IPL's unobserved completion or physical warm-reset causality.

October 15, 2026. A full image plus excess bytes could leave the frontend's
sticky upload error holding `ioctl_wait` forever. Main then could not finish
the current SPI ACK and send FILE_TX=0. The previous c6 fix covered exact-size
uploads only. The new frontend drains rejected payload while separately
blocking every post-error DDR write. Readiness stays false until a fresh,
complete upload succeeds. Ordinary board profiles remain unchanged.

`make -C verilator test-z-font-hps-upload` passes one positive and four exact
rejecting controls. It compiles the real `sys/hps_io.sv` file decoder and a
source-checked copy of the `sys_top` ACK seam. At SYS 32 MHz, public FIO
index/START/DATA/END commands encounter a stalled synthetic DDR sink; each
accepted byte's address, byte enable and data is checked independently.
There is no forced private DUT state or patched output memory.

The positive completes 7,690,193 SYS cycles with 1,048,596 DDR writes and
1,048,653 host words: four full-size streams, full-plus-overflow, short and
high/gapped-address failures, then complete retries. An additional valid
address after the gap must still be discarded. Mutants reject at exactly
`Z_HPS_ACK_FALL` (sticky WAIT), `Z_HPS_GAP_WRITE` (post-error admission), or
`Z_HPS_END_STATE` (failed-image publication and a host ignoring WAIT).
Compilation failure and the global timeout never count as rejection.

Sources, executables, warning inventories and logs are frozen in
`x1-z-font-hps-ew6zq638`; terminal SHA-256
`6e33de6f1a9dd0360ae4813ef3d423b2c02da1f8884a31d9834733d258efc0d8`.
All 53 emitted diagnostics are checked against the exact reviewed inventory:
inherited HPS static/width/case warnings and a packed bidirectional-port
UNOPTFLAT dependency. The latter settles throughout the complete positive
run; no RTL framework suppression or functional loop was introduced.
Unused observation outputs are omitted; functional inputs are pinned.
The fixture, frontend and DDR backend introduce no diagnostics of their own.

The same repair passes all 39 standalone frontend cases (terminal SHA
`d56dd7166bcfe1dacd48f4cc7be0f50cfbea195ebf7d17aaa82340e07e7c20bd`),
the five-case whole-machine CPU/pixel gate (terminal SHA
`68091784ee9698392cd15cfda7eaf102dee9f76e7c0badb400fc9a486167905f`)
and wrapper lint. These gates remain bounded synthetic qualifications.

The source-bound Quartus 17.0.2 full flow is terminal zero, 17m34s / 170
warnings, in `misterubuntu:/tmp/x1-z-font-error-drain-g1603x4v/source`.
RBF SHA-256 `fd9a085061a5fa5f6cc3c929a37f5b266d2391b5dd1b14752f3d8f794db83692`,
4,183,692 bytes. Fit: 25,384 ALMs, 37,244 registers, 534 M10Ks, 32 DSPs and
four PLLs. All 428 local inputs match; 427 remote inputs are unchanged plus
an audited generated QPF metadata rewrite. Only the frontend differs from c6.
[Build evidence](../output_files/X1ErrorDrain_20261015T145753Z/rebuild/).

Original-SDC timing still FAILS: slow setup −14.851 ns / recovery −8.257 ns;
fast hold −0.098 ns at measurement snapshot bit 4. Same-clock SYS/VID setup
+8.258/+9.540 ns does not qualify cross-clock payloads. No new cuts were added.
On mister14, the valid 80-column control matches 256,000 pixels and full DDR.
An oversized-only MGL returns a fresh raw screenshot; the next RBF/MGL load
also succeeds without a Linux reboot. Within one loaded core, full g0 →
262,146-byte oversized image → complete changed g1 matches all 256,000
80-column pixels and the full DDR hash. Full g0 → 16-byte short image → g1
matches all 128,000 40-column pixels and the full DDR hash. These are actual
Main/MGL and DDR/renderer observations, not just executed simulations.

The oversized-only raw capture equals the earlier g0 frame; it is not an
externally observed readiness/error flag and may be a held frame. Physical
failed-image publication rejection is therefore not claimed from that PNG;
the real-decoder simulation checks that state explicitly. The physical retry
frames differ from g0 and match g1 exactly. Final CPU VRAM-readback completion
and warm-reset dispatch causality remain unobserved, as in the earlier
[hardware diagnostic scope](TURBO_Z_EXTERNAL_HARDWARE_STATUS.md).
The protocol gate alone does not qualify lifecycle reset, CPU reads, rendered
pixels, native fonts, electrical HPS timing or timing closure.

Hardware files are separately deployed under
`/media/fat/_Computer/X1ErrorDrain_20261015T145753Z/`, with protected disposable
media in `games/SharpX1/HWTest/X1ErrorDrain_20261015T145753Z/`. Select the
`*-shortname.mgl` files: the first attempt's 32-character setnames exceeded
Main's 31-character name report; those initial files/logs are preserved.
All successful setnames are `X1ED_20261015T145753Z_01..05`.

| MGL | Physical acceptance |
| --- | --- |
| `01_Valid80-shortname` | Full g0, 256,000 exact pixels, full DDR hash. |
| `02_OverflowOnly-shortname` | Fresh Main raw capture and subsequent core-load recovery; no error-state pixel claim. |
| `03_OverflowRetry80-shortname` | Full → oversized → changed full within one core, 256,000 exact pixels/full DDR. |
| `04_ShortRetry40-shortname` | Full → short → changed full within one core, 128,000 exact pixels/full DDR. |
| `05_CrossTurbo-shortname` | Native Turbo IPL and protected CROSS Chase disk; synthetic font g1. |

The three exact controls total **640,000 pixels**, with no resize or tolerance.
[Actual screenshots](../output_files/X1ErrorDrain_20261015T145753Z/screenshots.html),
[manifest](../output_files/X1ErrorDrain_20261015T145753Z/manifest.json),
[new RBF](../output_files/X1ErrorDrain_20261015T145753Z/rebuild/sharpx1_turbo_z_font_fd9a0850.rbf).
CROSS Chase reaches a visually inspected populated playfield; 14 raw frames
match the known 531-pixel border signature. This is not a full-frame or
input-displacement oracle. Final audit passes 38 screenshot hashes, all 30
staged files, three private original assets, all 428 compiler inputs and fresh
full-DDR readback. Final manifest SHA-256:
`9afac5f022c53f46ae101b3ef15dd51dfa5406d92ab8cf6c1ace4f72dafecfbb`.
All jobs are terminal; MiSTer is left on CROSS Chase setname `…_05`.


