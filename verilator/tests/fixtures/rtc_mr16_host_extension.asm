; SPDX-License-Identifier: GPL-2.0-only
; Original replacement-MR16 firmware extension, NOT native 80C49 firmware.
; Included after the unchanged inherited code/data. Existing host_r/host_w
; preserve their byte order. YEAR stays the inherited software RAM byte:
; no annual carry, leap calculation or battery-backed YEAR is invented here.
; OP5 -> RTC P1, IP1[5] <- T1. Real machine integration is still required.
    dseg
    org 1156h
rtc_buffer ds 6
    cseg
    org 4000h
; No stack exists yet. Release a retained Time Set transaction before the
; inherited reset routine clears work RAM and initializes its actual stack.
rtc_boot:
    mov r14,#R14_BASE
    mov r0,#4:8
    stm (r14,#10),r0
    mov r0,#12:8
    stm (r14,#10),r0
    mov r0,#4:8
    stm (r14,#10),r0
    jmp reset

rtc_cmd_ec:
    mov r1,#3:8
    jsr host_r
    push r4
    push r5
    jsr rtc_snapshot
    mov r1,#calender
    ldm r0,(r1)
    mov r2,r0
    and r0,#0ffh:8
    mlt r0,#100h
    mov r1,#rtc_buffer
    ldm r3,(r1,#2)
    and r3,#0ffh:8
    or r0,r3
    stm (r1,#2),r0
    mlh r2,#100h
    stm (r1,#4),r2
    jsr rtc_program
    pop r5
    pop r4
    ret

rtc_cmd_ee:
    mov r1,#3:8
    jsr host_r
    push r4
    push r5
    jsr rtc_snapshot
    mov r1,#time
    ldm r2,(r1)
    ldm r3,(r1,#2)
    and r3,#0ffh:8
    mov r0,r2
    and r0,#0ff00h
    or r0,r3
    mov r1,#rtc_buffer
    stm (r1),r0
    and r2,#0ffh:8
    ldm r0,(r1,#2)
    and r0,#0ff00h
    or r0,r2
    stm (r1,#2),r0
    jsr rtc_program
    pop r5
    pop r4
    ret

rtc_cmd_ed:
    jsr rtc_refresh_host
    mov r0,#calender
    mov r1,#3:8
    jmp host_w
rtc_cmd_ef:
    jsr rtc_refresh_host
    mov r0,#time
    mov r1,#3:8
    jmp host_w

rtc_refresh_host:
    push r4
    push r5
    jsr rtc_snapshot
    mov r1,#rtc_buffer
    ldm r2,(r1)
    ldm r3,(r1,#2)
    ldm r0,(r1,#4)
    mlt r0,#100h
    mov r4,r3
    mlh r4,#100h
    or r0,r4
    mov r1,#calender
    stm (r1),r0
    ; Deliberately do not overwrite calender+2 (software YEAR).
    and r3,#0ffh:8
    mov r0,r2
    and r0,#0ff00h
    or r0,r3
    mov r1,#time
    stm (r1),r0
    and r2,#0ffh:8
    stm (r1,#2),r2
    pop r5
    pop r4
    ret

rtc_snapshot:
    mov r0,#3:8
    jsr rtc_mode
    mov r0,#1:8
    jsr rtc_mode
    mov r1,#rtc_buffer
    jsr rtc_read40
    mov r0,#0:8
    jmp rtc_mode
rtc_program:
    mov r0,#1:8
    jsr rtc_mode
    mov r1,#rtc_buffer
    jsr rtc_write40
    mov r0,#2:8
    jsr rtc_mode
    mov r0,#0:8
    jmp rtc_mode
; The builder appends the counted serial helpers from the qualified fixture,
; without its test entry point or payload. These helpers clobber r0..r5.
