; SPDX-License-Identifier: GPL-2.0-only
; Original replacement-MR16 diagnostic and counted serial driver.
; Proposed OP5[7:0]->P1, IP1[5]<-T1 wiring, not native 80C49 firmware.
; r14=GPIO; r15=stack. Serial helpers clobber r0..r5 and arithmetic flags.
; Buffer format is little-endian sec,min,hour,day,month:weekday,unused.
; Only qualified unprefixed LDM/STM are used; no inherited STW macro quirk.
    cseg
    org 0
    dw entry
    ds 14
entry:
    mov r15,#1800h
    mov r14,#2000h
    mov r13,#1000h
    ldm r0,(r13)
    cmp r0,#1:8
    beq wait_ready
    mov r1,#payload
    mov r0,#1:8
    jsr rtc_mode
    jsr rtc_write40
    mov r0,#2:8
    jsr rtc_mode
    mov r0,#0:8
    jsr rtc_mode
    mov r0,#1:8
    stm (r13),r0
wait_ready:
    ldm r0,(r14,#4)
    cmp r0,#1:8
    bne wait_ready
    mov r0,#3:8
    jsr rtc_mode
    mov r0,#1:8
    jsr rtc_mode
    mov r1,#1020h
    jsr rtc_read40
    mov r0,#0:8
    jsr rtc_mode
    mov r0,#2:8
    stm (r13),r0
done:
    bra done

; r0=register command 0..3. OE=1, CLK=0, DI=0, qualified STB rise.
rtc_mode:
    or r0,#4:8
    stm (r14,#10),r0
    or r0,#8:8
    stm (r14,#10),r0
    xor r0,#8:8
    stm (r14,#10),r0
    ret

; r1=three-word buffer. Shift exactly 40 LSB-first bits, then return.
rtc_write40:
    mov r2,#40:8
    mov r3,#16:8
    ldm r4,(r1)
write_bit:
    mov r0,r4
    and r0,#1:8
    mlt r0,#16:8
    or r0,#5:8
    stm (r14,#10),r0
    or r0,#20h:8
    stm (r14,#10),r0
    xor r0,#20h:8
    stm (r14,#10),r0
    mlh r4,#8000h
    sub r3,#1:8
    bne write_next
    add r1,#2:8
    ldm r4,(r1)
    mov r3,#16:8
write_next:
    sub r2,#1:8
    bne write_bit
    ret

; r1=three-word destination. Sample T1 before each shift clock; the last
; eight bits occupy the low byte of word 3 and its high byte stays zero.
rtc_read40:
    mov r2,#40:8
    mov r3,#16:8
    mov r4,#0:8
    mov r5,#1:8
read_bit:
    ldm r0,(r14,#2)
    and r0,#20h:8
    beq read_zero
    or r4,r5
read_zero:
    mov r0,#25h:8
    stm (r14,#10),r0
    xor r0,#20h:8
    stm (r14,#10),r0
    add r5,r5
    sub r3,#1:8
    bne read_next
    stm (r1),r4
    add r1,#2:8
    mov r4,#0:8
    mov r5,#1:8
    mov r3,#16:8
read_next:
    sub r2,#1:8
    bne read_bit
    stm (r1),r4
    ret
driver_end:
payload:
    dw 3456h,3112h,00c6h
code_end:
