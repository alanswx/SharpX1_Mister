# Wider D88 storage experiment

October 10, 2026. `turbo-wide-d88` is a separate, delay-aware, non-savable
shared-machine runner. It requests Turbo foundation, 24-bit byte addresses,
12-bit sector indices and 4,095 usable entries. Ordinary profiles and all
existing board revisions retain 20-bit addresses and 1,992 usable entries.
This is the storage prerequisite in [the HD plan](TURBO_HD_DISK_PLAN.md), not
native density, RPM, FM decoding, format or 2HD software acceptance.

## Executed standalone gates

Final controller source SHA-256:
`3ebfac927dd294fb281a0c621031dc4532f1b75bda32169eeb771dddb2242b68`.
The agent's frozen width suite completes all ten combinations of address
widths 20–24 and capacities 1,992/4,095. It exercises real host SD reads/writes,
high addresses and selected-volume bases, split-block deleted/CRC metadata,
entry 4,003 (128/256-byte payloads), 4,095-entry admission and 4,096 rejection.
Both address width and index capacity independently constrain admission.

Wide EDSK's 1,993-entry fixture exposed a missing overflow guard when width
was expanded but capacity retained at 1,992. The corrected condition rejects
that case; inherited default behavior is unchanged. Default D88 scanner,
CRC and metadata checks also pass, including enable dividers 1/8.
Evidence is under local temporary directory
`x1-fdc-address-width-fqriodc6`; the main agent independently checks all eight
current source hashes against its frozen manifest and reads the result logs.

Default vendor state comparison against `aa05dd2` passes four profiles:
RAM legacy, SD legacy, SD strict and SD without index. Main independently
compares all sixteen generated declaration/serializer files byte-for-byte.
Evidence: `x1-fdc-default-state-l1mjhtkb/comparison.json`. This does **not**
prove whole-machine snapshot v17 compatibility; the later whole-machine state
comparison and executed ordinary fast regression are recorded below.

## Integrated CPU gates

`test-machine-wide-d88` uses original generated IPL/media, frozen runner
copies, actual Z80 port transfers and disposable disk outputs. It requires
exact payload/status/RAM readback and unchanged gaps, headers, neighboring
sectors and private originals. A high-gap 1,024-byte case tests mark/CRC
bytes split across SD blocks. A separate emulator-derived 77x2x26x256 case
seeks physically to cylinder 76, selects side 1 and accesses sector 26/index
4,003. Neither fixture selects a native 2HD rate or tests mechanical timing.
Ordinary admission and wide-profile snapshot requests must reject without
creating outputs or modifying state sentinels.

The first two-second gap case ends at the actual readiness poll with 1,924
SD requests and zero data transfers; it fails the completion assertion.
Preserved evidence: `obj_dir_v17_wide_d88/cpu-wide-858ti7_1` and
`/tmp/x1-machine-wide-d88-first.log`. More than 2,050 block scans are needed
before transfer. Both cases are now running for four seconds, with unchanged
completion/payload/status assertions. No pass is inferred from launch.

Those first four-second cases complete all sector transfers but fail the CPU
comparison: the fixture used buffers at `4000/4800`, underneath the retained
IPL's lower-32-KiB read overlay. Actual RAM dumps contain the original read
payload, while CPU reads see mirrored IPL zeros and therefore write `5A`.
This is a fixture initialization error, not evidence of a broken high-address
controller. Original failing outputs are preserved under `cpu-wide-u_r78x1_`
and `cpu-wide-us1hnuer`. The corrected IPL uses visible upper RAM at
`9000/9800`; fresh four-second cases are running with identical byte/status
requirements. The geometry case additionally counts its real SEEK data-port
write separately from its 256 payload writes.

Both corrected cases subsequently finish **exit zero**. The high-gap case
performs 2,048 real CPU data reads/1,024 writes and five host writes; the
4,004-sector case performs 512 reads/256 payload writes, one SEEK target
write and three host writes. Both reach the original CPU `WIDE`/HALT marker,
with exact original/transformed RAM and byte-for-byte expected disk copies.
Ordinary rejection, save/restore sentinel rejection and unchanged input hashes
pass in both invocations. The four-second delay-aware profile reports SYS
32 MHz/VID 28,571,428 Hz, 128,000,000 SYS edges and 8,256 reset edges. No
CRTC is programmed and there are zero frames; these are bus/storage gates.
Evidence: `obj_dir_v17_wide_d88/cpu-wide-ow45r6tg` (gap),
`obj_dir_v17_wide_d88/cpu-wide-zva34lcg` (geometry).
Frozen executable SHA-256:
`d4eaad14ea0f0af3fa4064430ba83399e698c3059ccb91295f1bbb49670c46f0`;
ordinary negative runner:
`5dd1227d29ab508a306987d2c454b7a4c6c4d122730129267d26deefd6e7bd37`;
checked fixture:
`34dc91ef172cdc6e395af191c16af4026aa088969181a92303f0f85063314c68`.

The new runner's build-isolation check passes, covering thirty shared C++
recipes with internal make `-B` and an actual borrowed-parent-object negative.
The freshly rebuilt ordinary runner also passes 27 D88 preflight cases and a
200,000-cycle smoke. That smoke has no IPL/CRTC initialization and zero frames;
it does not establish software boot. Source manifests and diagnostic media
remain in ignored outputs; no private firmware or disk bytes are committed.

## Remaining gates

The current default `test-fast` regression subsequently completes exit zero
with 144 PASS lines, including actual save/restore, CPU/video/disk/reset/SD
transport checks; log `/tmp/x1-wide-default-fast-regression.log`. It uses the
separate no-timing fast runner, not delay-aware timing acceptance.
An independent ordinary whole-machine code-generation comparison against
`9a49a03` uses the same 103-source manifest order and Verilator 5.044 savable
options. All five headers and three complete serializer-containing C++ files
are byte-identical; root checksum remains `0x15a674813a657c3e`.
Evidence: `/tmp/x1-whole-state-3Gzlvx/comparison.json`. This comparison is state
identity, not execution of an old private snapshot or a changed C++ envelope.

The warning audit in the same directory finds no introduced address/index
assignment truncation. Twelve Boolean-context truncation warnings are inherited;
wide instances add five zero-expansion warnings for inherited 20-bit raw-geometry
expressions. Wider raw geometry is not qualified here. No warning suppression
is added; standalone EDSK arithmetic remains separate from native HD timing.

No FPGA revision enables this experiment.
Native capacity-selection ports, FDCCLK/byte timing, drive RPM, FM/format
and native/hardware 2HD tests remain distinct work, not waived by these tests.
