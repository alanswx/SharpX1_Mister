# Default v14 delay-aware baseline acceptance

October 9, 2026: `make -C verilator test` terminates with exit zero.
Log `/tmp/x1-v14-full-baseline.log`. Current default executable SHA-256:
`ed7164fc2b4ea7c34becbc176c05a0342e41a9d7dc459a5aedcaca23c54b8b99`.
The video/disk fixtures' logged runner hashes bind that same executable.
Machine RTL binds the single-screen text checkpoint `5418588`; subsequent
reverse/opacity work changes acceptance fixtures/docs, not machine behavior.

This runs the shared machine with default options, SYS 32 MHz / actual-board
VID 28,571,428 Hz, independent clocks, reset/loading through the runner and
inherited intra-assignment delays enabled. It does not enable X3, DMA, Kanji,
SIO, FM or any experimental Turbo Z palette/text profile.

The Make target executes its original ordered prerequisite/unit and CPU suite:
RGB12 capture, sub-timer, FDC abort/SD/reset, scanner/CRC/metadata and CPU bus;
key-script parsing, all configured base video/attribute/PCG/blink rasters and
live mixed-width transitions; keyboard/poll/IRQ, warm reset, D88 bounds,
timing/FST/determinism, memory/CTC-base/bus traces, drive selection/A-B disks,
real sub-CPU, graphics/DAM, audio/PSG, PPI/system ports, PCG, disk read/write/
metadata cases; loader, joystick, PCG access and drive/index control checks.
Individual configured scopes and limits remain in their test/status documents.

This is a completed **default local regression command**, not complete TODO
groups 1–6. It does not prove native BASIC, five newly booted v14 commercial
titles, native Turbo/Z, exact chip/pin timing, physical OSD resets, licensing,
Quartus/CDC closure or a newly qualified RBF. Optional-renderer matrices still
run separately on their own frozen executables and assets.
