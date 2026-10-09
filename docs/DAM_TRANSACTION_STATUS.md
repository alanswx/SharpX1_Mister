# PPI control-write / retained-GRAM correction

The connected Z renderer's retained-reset pixel test exposes a shared-machine
defect: a falling PPI C5 arms DAM while the CPU still holds the PPI control
OUT. Remaining held write strobes then reach all three GRAM planes at the
control port's low fourteen address bits. Cold graphics initialization hides
this by subsequently filling GRAM; retained reset does not.

With the frozen pre-fix X3 renderer, both identity and custom-palette retained
reset captures differ at seven pixels of character x=280..287, y=99. The
source base there is `3*2048 + 12*40 + 35 = 1A03h`, matching the mode-set
port. Both cold captures pass every pixel. Original failed images and logs
remain ignored under `obj_dir_v12_z_video/{identity-warm-io,custom-warm-long}`.
This is a reproduced simulator defect, not a claim about native ASIC edge timing.

Original `x1_dam_control.sv` retains a pending falling-C5 event until the
control write ends. The already-started OUT cannot redirect into GRAM; the
following OUT still sees DAM. A genuine I/O read clears both pending/active
state, with priority; reset cancels both. No inherited PPI/vendor source is
modified. Physical ASIC arming phase remains unqualified.

## Executed tests

- `test-dam-control`: 64 held control-write widths, zero redirected writes,
  following-write arming, read-clear priority, inactive transition and reset
  while pending. Verilator 5.044, 32 MHz fixture, assertions enabled.
- Original actual-Z80 diagnostic `test_dam_control.py`: initialize three
  planes at both `1A02h`/`1A03h` offsets, execute mode-set and port-C falling-C5
  writes, clear with IN and check all six retained bytes per scenario.
  Fixed default delay-aware runner passes; unchanged old X3 renderer reaches
  the expected `EE` failure. The fixed X3 check is recorded separately.
- Existing graphics-bus DAM masks/read-clear/peripheral/IPL-isolation test
  and default timing/reset/FST regression pass after the correction.
- Fresh v13 fast snapshot continuation, all RAM dumps, clock mismatch,
  joystick persistence/override and prior-v12 rejection pass. Pending state
  changes serialization: **regenerate from execution; never convert states**.

CPU fixture SHA-256:
`b6e33432f291fa0f40ef980af62e1c66ee52c6517d8769aa1ddd7babba5e296a`.
Fixed default runner:
`fb0b6a7764210609335083c07255122278c16a80776f59fa0278fff98572ca16`;
old X3 negative control:
`6294b37f86d41cc1f26a61a71783479a140aab72fb10fdd8f8b20956cdd99e9e`.
Logs `/tmp/x1-dam-cpu-{fixed,original,x3-fixed}.log`,
`/tmp/x1-z-video-damfix-{build,graphics-bus,timing}.log` and
`/tmp/x1-dam-v13-snapshot.log` bind their respective executables, not a board fit.

Fixed identity/custom retained-reset tests now each pass all 64,000 pixels,
including the seven original failures. I/O traces prove genuine CRTC/PPI reboot
with no GRAM/text/palette refill. Fixed X3 CPU regression also passes with
runner `d25519800d563fc840d564aa125066682d0f6b6c0b644e7de1e065eb92b798e6`.
The new complete baseline suite is in progress. Broader pending-DAM/reset phases, native game
requalification, fitted/hardware/OSD behavior remain required. Existing RBFs
do not contain this correction; historical v12 game evidence stays historical.
