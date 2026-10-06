# DMA search implementation contract (not implemented)

October 6, 2026. Next work-group-2 gate after automatic restart.
Current RTL still rejects WR0 search/transfer-search and WR3 Stop on Match.
No tests or emulator execution below establish these as working features.

## Primary evidence and unresolved details

The existing local [Zilog UM008101-0601](https://www.zilog.com/docs/z80/um0081.pdf)
was reread at printed 58, 75–77, 92 and 99. Tables 11/12 were visually
checked in PDF pages 94/95, not just text extraction. Mask bits set to one
exclude comparison bits. WR0 distinguishes transfer, search and combined
transfer/search; WR3 governs stop and match-byte/mask programming.

Search cannot inherit the sequential engine's counter policy unchanged.
The table distinguishes Byte versus Burst/continuous stop counts and
search-only versus sequential transfer/search. Ready near a matched read and
two-cycle simultaneous timing introduce additional exceptions. The scan
itself has truncated sequential rows (`M+`, `M-`), not merely OCR damage;
these need corroboration rather than literal arithmetic or silent correction.
Pure search has no destination write. Simultaneous transfer relies on external
hardware and is not a software-only extra destination transaction.

These differences rule out enabling search simply by removing `unsupported`,
or returning a fabricated match status after copying a block. The primary
pipeline explanation also requires distinguishing a matched byte, terminal
byte, and any subsequent observable read. Counter and bus traces, not just
RAM contents, must qualify each supported mode. Existing MAME is a second
implementation, not authority for the known primary counter disagreements.

## Implementation and qualification order

1. Define operation-class completion independently of bus ownership. Preserve
   original transfer and automatic-restart gates, Ready/WAIT/reset drainage,
   read-mask ordering and one side effect per held strobe. Add explicit
   latched match status, reset/LOAD/8B rules and remaining-count policies.
2. Add comparison using original mask/match streams. Test all 256 masks,
   matching/nonmatching bytes, both sources, memory/I/O, fixed/inc/dec/wrap,
   and command-shaped associated bytes. Keep stop disabled first to inspect
   match visibility independently of release decisions.
3. Implement sequential transfer/search and pure search, all ownership modes.
   Corroborate truncated primary rows before asserting their expected counts.
   Test first/middle/last/no match, simultaneous EOB/match, repeated matches,
   source/destination/counter readback and exact bus transactions. Pure search
   must never emit a destination write or touch its address counter.
4. Sweep Ready before grant, at the matched source completion, between
   pipeline reads and during any destination write; include WAIT and stopped
   CE. Verify the documented extra-read cases rather than globally forcing
   all modes to stop on the same operation.
5. Test DISABLE and software/hardware resets at each started search phase,
   retained short reset at the machine ownership seam, LOAD/CONTINUE and
   match/status reinitialization. Combine match-stop and EOB automatic restart
   only according to the actual event contract.
6. Extend genuine shared-CPU programs with masked status and full counter
   readback, source/destination guards and real grants. Requalify original
   disk/GRAM/PCG/SIO diagnostics; never patch firmware to avoid unsupported
   search or fake an interrupt vector. Add IRQ/vector/IP/IUS/RETI afterwards
   using persistent real match/EOB/Ready events and qualified device ownership.

DMA model state changes require fresh native/diagnostic snapshots and an
appropriate version/profile rejection before deserialization. Keep base
and ordinary board DMA defaults disabled until their independent native,
Quartus/CDC and hardware gates pass. This plan does not narrow the active
goal to sequential-only DMA or defer the required search classes out of scope.
