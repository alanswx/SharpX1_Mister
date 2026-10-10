# Turbo Z capture/effect control contract

October 9, 2026. Z8 prerequisite, not implemented video capture or effects.
The new original `rtl/x1_z_effect_control.sv` decodes supplied control bytes;
it has no CPU storage, input-video clock, line buffer, GRAM ownership, pixel
composition or capability signature. No machine manifest or board/runner
profile enables it. Existing frozen pixel matrices are unchanged.

## Primary programming evidence

Visually inspected X1-Techknow Appendix A PDF pages 8–10, printed pages
280–282, rendered locally from the existing image-only scan. SHA-256:
`720c79f24169ad33ea91d5b4e2c32b98fab41c91430f226462eb254ac9e5505c`.
See [manual inventory](../references/manuals/README.md) and the
[source archive](https://github.com/UnsatisfactoryResult/Sharp-X1-Fun/tree/main/Documents/X1-Techknow).
No new PDF or emulator was downloaded for this audit.

| Register | Documented meaning | Decoder boundary |
|---|---|---|
| `1FB0` bits 7/3/2 | Multi-color mode admits capture; bit 3 enables capture; bit 2 inverts captured levels only when capture is enabled. | Capture enable requires caller enable and bits 7/3. Inversion requires that enable and bit 2. No input quantizer is implemented. |
| `1FC1` | Capture-position correction count 0–255 dots; valid only in 200-line scan. | Exposes the byte/count in low scan. Origin, direction, sync phase and application to external samples remain unresolved. |
| `1FC2` bits 2:0 | Horizontal mosaic 1/2/4/8/16/32/64 dots for encodings 0–6; encoding 7 is a dash. | Returns dimensions only for defined combinations, with a separate validity output. Undefined does not mean wrap, clamp or a native black pixel. |
| `1FC2` bits 5:3 | Vertical mosaic 1/2/4/8/16/32 lines for encodings 0–5; encodings 6/7 are dashes. | Same validity policy; no spatial sample/hold engine yet. |
| `1FC2` bits 7:6 | Capture uses 4/3/2/1 bits per component for encodings 00/01/10/11 (4096/512/64/8 colors). In 64-color mode, bit 7 is treated as 1. | Reports component width, forcing the high selector bit when the caller qualifies a 64-color format. This is not limited to two-screen 320x200; bit 4 of `1FB0` alone is not a complete format decode. |
| `1FC3` | Bit 7 enables chroma key; bit 6 enables inverse key and is valid only with bit 7. Key color G/R/B uses bits 5/3/1; bits 4/2/0 are unused. | Decodes enable/inverse and three-bit key code, not an RGB12 comparator or inferred ADC threshold. |
| `1FC4` | Bit 3 makes bits 0–2 effective. Bit 0 selects scroll-in/out; bit 1 requests repeating in/out; bit 2 disables CRT output. Bits 4–7 are unused. | Exposes qualified controls, not scroll movement or immediate global video blanking. The text explicitly requires superimpose, CRTC and second-8255 setup. |

`enabled` is a caller-qualified permission, not a native readback/reset/ASIC
decode claim. The pure decoder keeps programmed dimensions and quantization
available independently of the capture trigger; a future consumer must still
honor `capture_enabled`, `mosaic_defined` and its own valid sample/ownership.
The helper returns zero dimensions with validity false for undefined settings;
it does not choose what the real ASIC displays for those settings.

## Emulator cross-check, inspected not executed

The existing local MAME `x1.cpp` has logging-only `z_img_cap_w`, `z_mosaic_w`,
`z_chroma_key_w` and `z_extra_scroll_w`; these cannot validate effects.
Current inspected file SHA-256:
`daff0118d09c7f8e5e9fcf1edfd2d474ff3faae48e0cf75752ec5dbe76e5e079`.
The local Common Source X1 `display.cpp` stores/reads these four registers when
AEN is set and saves their state, but its only references to those fields
are initialization, register access and state serialization, not rendering.
File SHA-256:
`2bd722cb871a90d92adc20a52f09ea3d8ad61be81b486d6915add19b4dd6cc87`.
Neither storage/readback agreement nor MAME's labels prove digitizer behavior.

## Executed decoder acceptance

`make -C verilator test-z-effect-control` terminates zero with Verilator 5.044,
without warning suppressions. The original arithmetic/table oracle exhausts
**264,192** configurations: all mode/mosaic bytes crossed with enabled and
qualified 64-color capture mode, all position bytes in both scan modes,
all chroma controls and all scroll controls including disabled/unused bits.
Two matched negative controls fail the unchanged oracle: omission of forced
64-color quantization and ignoring the scroll activation bit. Log:
`/tmp/x1-z-effect-control-final.log`. Current decoder SHA-256:
`94f0fc068e26aa0d174a6dc7efdfaf04870e015edde04abf9af4ac27c6f20f21`;
fixture SHA-256:
`b6cec587ee8ff6cf701a59e27407401d1e8d01cc9aa7c8bd369f94a740a90ee4`.
Adjacent priority-order/negative and 120-case matrix-plan tests also pass
(`/tmp/x1-z-effect-control-adjacent.log`). CI now schedules this asset-free target;
hosted results are separate from this local pass.

## Implementation still required

1. Resolve native CPU write/read/reset policies and capture/CRTC/PPI gating;
   add opt-in real-CPU register tests without exposing a false Z capability.
2. Trace input sync, dot-position correction direction/origin, ADC bit order,
   quantization threshold/retained-bit policy and capture inversion through
   CZ-880 sheets. Define a deterministic RGB/sync input source with validity;
   absent input must never masquerade as a functioning digitizer.
3. Implement bounded line-buffer/sample-hold behavior and capture GRAM writes
   through actual ownership, including both pages/planes and all formats.
   Exercise stopped clocks, reset, DMA contention and uncompleted writes.
4. Apply mosaic/key/scroll/telopper at their documented pipeline stages; verify
   all pixels, source-presence/key decisions, timing and mode exits. Do not
   guess a full-color chroma comparison from the three-bit key selector.
5. Qualify native Z software, fitted resources/CDC/timing and physical video
   input/output separately. Decoder success does not complete Z8 or the goal.
