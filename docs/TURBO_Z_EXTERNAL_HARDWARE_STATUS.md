# October 15 external-font MiSTer tests

Later October 15: [separate retained-reset controls](Z_FONT_RETAINED_RESET_STATUS.md)
now prove bounded post-HALT Main keyboard-chord reset causality and retained
IPL/font/VRAM at both widths, with real no-reset and wrong-table negatives.
The new IPLs and nine hardware PNGs do not retroactively strengthen the older
firmware/images below; other reset paths, native fonts and timing remain open.

Later October 15: [CPU-visible completion controls](Z_FONT_CPU_COMPLETION_STATUS.md)
add actual post-check corner markers and matched one-byte failure controls on
fd9a0850, 1,024,000 exact pixels. They qualify the final-readback path for new
IPLs; older images below retain their original limited scope.

October 15 follow-up: [matched CROSS Chase controls](CROSS_CHASE_HARDWARE_CONTROLS.md)
now capture populated playfields with both IPLs on both cores. The earlier
comparison below used insufficient start input. The subsequent
[malformed-upload repair](Z_FONT_HPS_UPLOAD_STATUS.md) has a new fd9a0850 RBF:
full build passes, timing fails; actual oversized/short-file retries match
640,000 total pixels across three controls and full DDR hashes. Main remains
responsive without a Linux reboot. The c6 historical results below do not
contain this second repair.

The user authorized copying local ROMs, creating MGLs and testing on
**mister14 / 10.0.2.14**, through misterubuntu. Private assets, screenshots,
manifests and build evidence are under
`output_files/X1ZF_20261015T131918Z/`. Existing installed cores and original
media were preserved. The previously active core was MacPPC7300.

## Initial hardware failure and repair

The source-bound October 14 external-font RBF `52be576d…` loads and transfers
all **262,144** generated physical font bytes to reserved DDR
30000000–3003FFFF. Read-only `/dev/mem` readback hashes the complete range to
`d18c7cb9c91d05b3d70e9061ce0ef36d2976960e1bb74984f3ef85fd17d7032b`,
exactly matching the uploaded original synthetic font. This is physical DDR
upload/readback evidence, not native Kanji or CPU/renderer acceptance.

Main then stalls at the final SPI ACK. GPIO output `8004004B` has the last
font byte 4B and SPI clock low; input `00060000` retains ACK bit 17 high.
The frontend's terminal-count WAIT prevents the framework ACK from falling,
so Main cannot send FILE_TX=0. Subsequent screenshot/core-load requests do
not execute. The failed requests and GPIO/DDR evidence are preserved. Sync
and a MiSTer reboot recover to MENU; no services were replaced.

`rtl/x1_z_kanji_frontend.sv` now releases WAIT after the final backend command
drains and limits write admission separately to the first 262,144 bytes.
Extra writes still invalidate the upload and cannot wrap to byte zero.
The frontend gate adds an end-command WAIT deadline and a control restoring
the original terminal-count condition. All **39** cases pass; that control
fails exactly at `Z_FRONTEND_END_COMMAND_WAIT`, without a compiler or global
timeout failure. Frozen report `x1-z-kanji-frontend-t559wfie/terminal.json`
SHA-256: `4e6e1a982f6e938e0cfab23c00c11dc9c21ee2a35ff6b32202488a6947897baa`.

The five-case shared-machine regression also passes after this repair:
280 CPU reads, 12,358 commits and six exact frames / 1,152,000 pixels,
including changed-font replacement and three rejecting controls. Frozen
report `x1-z-external-machine-0i_usm3g/terminal.json` SHA-256:
`d8dd01bfe8ce365b6b1e5bff42784925975ddf5b355931f4512ed169b6d25a66`.
Wrapper interface lint passes. These are simulation results.

## Repaired build and exact hardware pixels

The isolated full Quartus 17 flow is terminal zero, session `94988`, in
`misterubuntu:/tmp/x1-z-font-hps-fix-H3qQo2ok/source`. It ran 13:25:57–13:42:11
UTC, **16m14s**, with 170 warnings. Fit: **25,419 ALMs, 37,216 registers,
534/553 M10Ks**, 32 DSPs and four PLLs. All 428 local compiler inputs match
the captured source; 427 remote inputs remain unchanged, with only Quartus's
expected QPF DATE/revision metadata rewrite. Only the frontend differs from
the October 14 input manifest.

Repaired RBF SHA-256:
`c6a2ac021173a18fa1f45ac2ea0d9ed8b2a44db1979db1d18de549125afc3880`
(4,182,840 bytes). Local [RBF](../output_files/X1ZF_20261015T131918Z/rebuild/sharpx1_turbo_z_font_c6a2ac02.rbf)
and [deployment manifest](../output_files/X1ZF_20261015T131918Z/manifest.json).
Raw build evidence archive SHA-256:
`3f96eb3b5165199f32f09e7aab587715ae061d7874fc1945cb9ee704e2ac1d56`.

**Timing still fails:** slow 100C setup -14.956 ns, recovery -8.277 ns;
fast -40C hold -0.084 ns. Same-clock SYS/VID setup is +7.147/+7.735 ns;
SYS/VID and VID/SYS bundles are -10.447/-9.234 ns. Original SDC only, no new
exceptions. The reporting sidecar passes without changing the RBF; its initial
missing-script invocation and successful separately supplied reporter are both
preserved. Sidecar archive SHA-256:
`e02b57a6e87778673612e4fdecef7f6c1e27968a17a7a1bd1da698cd09084163`.
SYS is configured at 32 MHz and fitted VID at 42.954545 MHz; neither clock was
measured on the board.

Actual raw mrext PNGs compare directly with the frozen synthetic RGB oracle:

| Diagnostic | Cold capture | After warm-reset request | Pixel mismatches |
| --- | ---: | ---: | ---: |
| 80 columns, 640×400 | 256,000 pixels | 256,000 pixels | 0 |
| 40 columns, 320×400 | 128,000 pixels | 128,000 pixels | 0 |

**768,000 pixels match exactly**, including dimensions and PNG CRC checks,
without resizing, cropping or color tolerance. See
[the pixel review](../output_files/X1ZF_20261015T131918Z/hardware-pixel-review.json).
The original IPL's pre-fill ANK/PCG and two 16-row CPU font probes must pass
before it writes these patterns. The later CPU VRAM readback completion marker
is not externally observed; pixels alone do not prove that final CPU oracle.

The hardware IPL explicitly removes its RAM warm-flag branch and always fills
VRAM, avoiding unspecified physical cold RAM. Consequently the matching reset
captures qualify repeated output after the requested Ctrl/LeftAlt/RightAlt
chord without asset reload, **not retained-VRAM cache reconstruction**. No boot
counter independently proves reset dispatch; stopped-clock/owned-reset cases
remain simulation gates. Error-path Main recovery after malformed/overflowing
uploads is also unqualified; the physical tests use exact valid full images.

Native Turbo IPL + unchanged ANK16 + the synthetic full font separately reach
Galaga, Mappy and Xevious title screens on this repaired core. This is bounded
base-game boot through the Turbo IPL, not Turbo-only games or native Kanji.

On the MiSTer, browse **`_Computer/X1ZF_20261015T131918Z/`**:

| MGL | Inspected result |
| --- | --- |
| `10_Diagnostic_80_fixed` / `11_Diagnostic_40_fixed` | Exact synthetic hardware frames above. |
| `12_Galaga_Turbo_IPL_fixed` | Native title; gameplay unqualified. |
| `13_Mappy_Turbo_IPL_fixed` | Populated native stage and visible score 30 after Space/intro. |
| `14_Xevious_Turbo_IPL_fixed` | AREA 1 / SOLVALOU LIFT OFF, aircraft and changing landscape after Space. |
| `15_Cross_Chase_Turbo_IPL_fixed` | Native title, then score/Press key; no playfield captured in its 15-frame extended burst. Gameplay unqualified. |
| `09_Cross_Chase_baseline` | Separate historical single-clock core; live playfield captured. |

At this checkpoint, the repaired-core CROSS Chase observation was unresolved:
the control also changed IPL, clock and machine profile. The subsequent
[matched controls](CROSS_CHASE_HARDWARE_CONTROLS.md) show fields on both cores
with both IPLs after enough start input.
The failed/incomplete screenshots remain preserved. Input-specific movement,
complete gameplay and physical controllers are not qualified by these bursts.
The MiSTer is left on repaired-core Mappy (`…_13` setname).

The [screenshot gallery](../output_files/X1ZF_20261015T131918Z/screenshots.html)
links unmodified actual PNGs and distinguishes the two RBFs. The ordinary
`headless`, 200,000-cycle smoke and `test` sequence is terminal zero, with
**164 PASS reports** and unchanged ordinary executable SHA-256 `afcf9711…`.
The ignored manifest records staged/original asset hashes and capture audits;
protection uses zero status requesting protected disk writes and disposable
copies, without claiming that FAT chmod makes the volume read-only.

## Separate historical-core controls

Four additional MGLs select the preserved `f013d02` single-clock Turbo
subset RBF `eaca279a7c137dd6b9cef50a3da2fbb793b558eced3c3177ebb5b454352a3e1d`.
This is a separate 28.571428-MHz experiment; it enables neither X3 nor
external font/Z/DMA/FM. Each uses the ordinary base IPL and a disposable
protected D88 copy. Galaga, Mappy and Xevious reach inspected native title
screens. Galaga Space reaches its level menu. CROSS Chase also boots, and a
short on-device mrext burst after Space captures its populated playfield with
changing enemy positions. Twelve requests 0.18 seconds apart produce four
actual PNGs; requests can coalesce. Frames `09_Cross_Chase_baseline_burst-01`
through `-03` show the running playfield. This establishes bounded native
playfield activity, not exact movement equivalence or physical keyboard input.
No full gameplay claim follows from the other titles' screenshots.

The initial failed RBF/MGLs have been preserved with `.disabled` suffixes on
the MiSTer, so they are not selectable as ordinary core/game entries. Their
original local MGLs, hashes and failed observations remain in the manifest.

## Capturing with mrext

Installed mrext reports version 0.5, updated October 10. Main SHA-256:
`adeae62b09e63537fc33fbebbee5145e66fbecdd950ed6b9f856a441147556ff`.
`POST /api/screenshots` returns before the PNG appears and requests a scaled
capture, which was black on the historical X1 core. Use
`POST /api/controls/keyboard/raw_screenshot`, then poll `GET /api/screenshots`
for a new path and retrieve `GET /api/screenshots/<path>`. Inspected raw PNGs
show the native game pixels. The initial black scaled capture is preserved;
it does not establish a black physical HDMI output.

All full-size Kanji backing here is **synthetic**. The local native Turbo IPL
and ANK16 remain unchanged user-supplied assets. Earlier 128-KiB model-40
fonts were not padded, truncated or relabeled as native Z fonts. Timing
closure, native font conversion, broader text policies, physical input/audio
and general native Turbo software acceptance remain open.
