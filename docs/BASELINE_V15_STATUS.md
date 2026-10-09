# Ordinary v15 baseline acceptance

October 9, 2026. After the default-off shared SIO interface increment, both
complete ordinary suites exit zero with Verilator 5.044:

```sh
make -C verilator test HEADLESS_DIR=obj_dir_v15_sio_machine
make -C verilator test-fast
```

The first command ran after `test-machine-sio` in the same invocation/log.
`/tmp/x1-v15-machine-and-baseline.log` is terminal, exit zero, with 145 PASS
reports including the preceding initial machine checks. The subsequently
strengthened shared SIO WAIT fixture independently passes in
`/tmp/x1-machine-sio-wait-final.log`. `/tmp/x1-v15-fast.log` is terminal, exit
zero, with 137 PASS reports. These are reports, not counts of exhaustive cases.

The ordinary top remains base X1 with SIO/Turbo/DMA/Kanji/Z off, SYS=32 MHz
and VID=28.571428 MHz. The timing reference includes inherited RTL delays;
fast uses synthesis-style `--no-timing` and is not the timing reference.
Both retain the normal runner reset/download sequence and existing test
assertions. Full suites cover clock/reset determinism, actual CPU/memory/video,
keyboard/MR16/IRQ, PSG/audio, PPI/joystick, PCG, D88 metadata/read/write/reset/
eject and CPU BUSRQ/BUSACK diagnostics. Fast additionally passes the actual
snapshot/SDL adapter assertions, not a mocked serialization test.

| Runner | SHA-256 |
|---|---|
| `obj_dir_v15_sio_machine/Vtop`, delay-aware | `f1af4f88f4d3ba1c2467558ae7ca408444f98c6a4f0d34daa0f3bdcca1aad6d7` |
| `obj_dir_fast/Vtop`, savable fast | `f484bede6fde9a1f0bbba6ff30b6f5727c05041762a5b6179520b3b094e987f9` |

Snapshot format v15 rejects earlier states; `test_snapshot.py` deliberately
corrupts only its generated negative fixture to v14 and requires early
version rejection. Real old states are never converted. A separate direct
snapshot execution also exits zero (`/tmp/x1-v15-snapshot.log`). All five
commercial titles additionally pass [fresh native v15 qualifications](COMMERCIAL_COMPATIBILITY.md)
on the frozen fast runner, not old restored states.

The builds retain inherited warnings and broad existing accommodations.
Base, Turbo DMA and X3 board wrapper PLL-stand-in lint exits zero; this is
not Intel PLL simulation, current-source Quartus fit or physical hardware
acceptance. The opt-in shared SIO is qualified separately through generated
IPL/real CPU/RX/WAIT/nested service/reset tests, not these ordinary suites.
Native CTC/SIO phases, serial pin CDC, enabled serial snapshots, native Turbo Z
and broad hardware acceptance remain open. Historical v14 baselines/frames
and fitted RBFs retain their original source identities.
