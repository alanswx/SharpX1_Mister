# DMA search implementation contract (partial comparison increment)

October 6, 2026. Next work-group-2 gate after automatic restart.
The [comparison increment](DMA_COMPARE_STATUS.md) now accepts sequential
transfer/search without stopping and tests real masked/sticky status.
[Pure Byte search](DMA_PURE_SEARCH_STATUS.md) now has a read-only completion
path and independently tested match/EOB counter policies.
[Byte search automatic restart](DMA_SEARCH_RESTART_STATUS.md)
now reloads both buffers without a destination write.
[Non-stopping Burst/continuous search](DMA_NONBYTE_SEARCH_STATUS.md) has
distinct EOB counts and Ready ownership. Non-Byte WR3 Stop on Match remains
rejected pending the actual extra-read pipeline and exceptions. The new
[Byte stop increment](DMA_BYTE_STOP_STATUS.md) follows the untruncated
sequential Byte row. The remaining class/pipeline
requirements below are not made complete by those comparison tests.

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

The October 6 follow-up downloaded and inspected Zilog's **1982/83 Data
Book**, printed 60, DMA Figure 19 prose: Burst/continuous match release is
described at the following operation, including the following write for
transfer/search. This is not clean corroboration of the later sequential
Burst row's `M` transfers. Preserve this primary-reference disagreement
before implementing those modes; do not extrapolate Byte stop to them.
Local ignored `references/manuals/Zilog_1982_Data_Book.pdf`, SHA-256
`f95c54fc8ff0e5524434132340e644b94ae7dc9ad861b0976114b6ba8a37bf84`,
[publisher scan hosted at Bitsavers](https://bitsavers.trailing-edge.com/components/zilog/_dataBooks/1982_Zilog_Data_Book.pdf).

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
