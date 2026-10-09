# Turbo Z control crossing: in-flight reset with stopped video

October 9, 2026. This extends the original `z_priority_machine_cdc_tb.sv`
fixture with default-off `INFLIGHT_RESET=1`. No production RTL, native register
policy, palette contents, snapshot format or board profile changes.
Turbo/X3, palette/video/multi-mode and text/priority CPU experiments are on;
DMA/SIO/FM/Kanji are off. No private ROM or injected bus/shifter state is used.

## Completed acceptance

The real CPU's generated IPL programs PPI, mode 90h and a 256-byte priority
sweep. The fixture waits for the actual coherent source payload `5A900001h`
to be published while its acknowledgement has not crossed the video-domain
synchronizer, then physically stops VID before asserting reset. CPU must
still be running, so this is not the older after-HALT reset case.

It requires immediate destination reset assertion and cleared requested/pixel
priority and composition even though VID cannot advance. Over 32 running SYS
edges, the unconsumed payload, request and acknowledgement remain unchanged:
reset cannot destroy the bundled-data handshake. On restarting VID with reset
still held, no old controls can enable composition. The reset control payload
must cross before reset release. The inherited PPI width latch remains 40-column
(reset payload `00000001h`), not an invented cleared width.

After releasing reset, the unchanged retained IPL executes every one of the
256 priorities, exits into actual 640x200/64 mode and returns. Existing
character-bound priority/eligibility, live-versus-captured differences,
excluded-layout samples, both stopped-clock and complete warm reboot checks
remain required. No asset reload or substitute completion condition is added.

Both commands finish with exit zero:

```sh
make -C verilator test-machine-z-priority-inflight-reset
make -C verilator test-machine-z-priority-cdc
```

SYS is 32 MHz. Each recipe uses three independent VID half-periods:
17,500 / 11,640 / 25,000 ps (approximately 28.571428 / 42.955326 / 20 MHz).
These are test clocks, not fitted PLL measurements. Final combined log:
`/tmp/x1-z-priority-inflight-all-final.log`, including the unchanged
disabled-priority negative and all three old and new configurations.

| Artifact | SHA-256 |
|---|---|
| Final fixture | `cce161f104751f12ce28b36cb0e274572fe6f596081354dfc431f48a57ccbab4` |
| Shared machine | `ddb49969b0c4e3cb0000c0aaac434c175e841e4dfa8c99f14b8c2f568e333b67` |
| In-flight executable | `9b7252a065ed82ee5aa1ee5bca4fbdbb8fba90707835f8de936cf33be165fe9d` |

Pre/post hashes match. New signed-audio outputs are explicitly disconnected
because FM is off; no missing-pin suppression is added. An initial disabled
build exposed an observer referencing an absent composition hierarchy. The
observer now has generate-qualified wires, retaining the disabled negative's
original `CPU sweep incomplete` failure. Initial logs are preserved separately.
CI now selects the new target; hosted terminal acceptance is not yet claimed.

## Deliberately failing control / remaining scope

An isolated temporary machine copy removes only asynchronous reset sensitivity
from the paired-composition state. The unchanged new diagnostic fails at
`stopped-video in-flight reset retained composition`
(`/tmp/x1-z-inflight-negative.log`), not a watchdog or missing capability.
The mutation is not applied to production RTL. Initial negative-build attempts
hit the local old Make's missing `--eval` support and source-list newline
handling; the final flat-list build succeeds and executes that specific failure.

This proves the tested coherent-control/composition reset seam. It does not
prove exact post-reset RGB frames, live palette RAM ownership, pending DMA/
GRAM/PCG transactions, native ASIC pin timing, metastability/placement, native
Turbo Z firmware, fitted CDC or physical video output. Those gates remain
required; neither Turbo Z nor work groups 1–6 are complete.
