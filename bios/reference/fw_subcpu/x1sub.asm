;******************************************************************************
;   X1 NISE-SUBCPU firmware for mr16
;
; 2005. 3.19 trnasrated from MRISC
;
;******************************************************************************
;
;DMA_TEST equ 1
;
;7seg display optopn
;SHOW_INIT equ 1
;SHOW_HOST_W equ 1
;SHOW_HOST_R equ 1 
;SHOW_PS2_RAW equ 1 ;ps/2 RX code
;SHOW_KEYCODE equ 1  ;ascii & ctrl code
;
;
;minimize option
;GRAPH_ASCII equ 1
;KANA_ASCII equ 1
;F_GAME_KEY equ 1
Z80DMA	equ 1
;
;******************************************************************************
; memory map
;******************************************************************************
	include "mr16.inc"
;******************************************************************************
; register map
;******************************************************************************
;
CPU_MHZ	equ	32
;
;r14 GPIO/TIMER
;r13 X1 SUB CPU
;r12 PS/2
;r11 Memory Mapped I/O
;r10 FDC/FDD
;r9  OS next event counter
;r8  16usTimerCounter
;
ROM_TOP	equ	0000h
ROM_END	equ	1000h
;
RAM_TOP		equ	1000h
WORK_TOP	equ	1080h
STACK_END	 equ	1800h
RAM_END		equ	1800h
;
TIME_TICK	equ	 16  ; 16us OS time ticker
;
;---------- OS(task switch) Timer Step ----------
T500MS	equ	 500000/TIME_TICK
T200MS	equ	 200000/TIME_TICK
T100MS	equ	 100000/TIME_TICK
T20MS	equ	  20000/TIME_TICK
T4MS	equ	   4000/TIME_TICK
T800US	equ	    800/TIME_TICK
T160US	equ	    400/TIME_TICK
;
;---------- PS/2 Timeout Timer Step ----------
PS2_TICK equ	64

;-----------------------------------------------------
;Memoy Mapped Direct I/O
;-----------------------------------------------------
;-------------------------------
MEM_IO		equ	1000h ; memory mapped direct I/O
R11_BASE	equ	MEM_IO
;-------------------------------
HOST_RD equ	MEM_IO+00h
HOST_WD equ	MEM_IO+02h
;
DMA_RD  equ	MEM_IO+04h
DMA_WD  equ	MEM_IO+06h
;
DMAM_DO equ	MEM_IO+08h
DMAM_DI equ	MEM_IO+0ah
;
FDC_CMD equ	MEM_IO+10h
FDC_TRK equ	MEM_IO+12h
FDC_SEC equ	MEM_IO+14h
FDC_DAT equ	MEM_IO+16h
;
FDC_MOT equ	MEM_IO+18h
;
IO_TRP	equ	MEM_IO+1fh ;I/O TRAP PORT
;
;-----------------------------------------------------
;GPOUT I/O assign
;-----------------------------------------------------
R14_BASE	equ	GPIO
;
DMA_DATA	equ	PORT0     ; R/W to SRAM in RFSH cycle for FDD data accesss
;
HOST_STS	equ	PORT1     ; IN  host/sub communication status
HOST_CTRL	equ	PORT1     ; OUT host/sub communication controll
PS2_STS 	equ	PORT2     ; PS2 status
PS2_CTRL	equ	PORT2     ; PS2 controll
;
FDC_STS		equ	PORT3     ; FDC status (R/W)
FDC_IN		equ	PORT3     ; FDC IN
;
FDD_PORT	equ	PORT4     ; FDD emulation port
;FREE PORT5
;
JOY_PORT	equ	PORT6
SEG7_NUM	equ	PORT7
;
FDM_AL		equ	PORT8     ;DMA ADDRESS port
FDM_AH		equ	PORT9     ;DMA BANK & CONTROLL
DMA_RDY		equ	PORTA     ;DMA RDY controll
;
PCM_DATA	equ	PORTB     ; PCM 8bit out
;
;----- DUMMY ACK inport ----------
HRD_SET		equ	PORT4     ; HRD clear (dummy read)
HWD_CLR		equ	PORT5     ; HRD clear (dummy read)
FDC_DRQ_SET	equ	PORT6     ; FDC DRQ set
FDC_DRQ_CLR	equ	PORT7     ; FDC DRQ clear
;
;
;DMA_DATA bit mask
DMAM_RDY	equ	0400h ;DMA RDY signal(IRQ)
DMAM_BUSY	equ	0200h ;in RFSH access cycle
DMAM_BUSAK	equ	0100h ;Z80 BUSAK signal
;
;FDM_AH
DMAM_WR		equ	8000h
DMAM_RD		equ	4000h
DMAM_IORQ	equ	2000h
DMAM_MREQ	equ	1000h
DMAM_BUSRQ	equ	0800h
DMAM_RFSH_REQ	equ	0100h
;
;HOST_STS / HOST_CTRL bit assign
CLK_1HZ	equ	10h     ;read/write
PIO_IRQ	equ	08h     ;read/write
PIO_BRK	equ	04h	;read/write
HWD_FUL	equ	02h     ;read only
HRD_FUL	equ	01h     ;read only
;
;PS2_STS / PS2_CTRL bit assign
PS2_DT	equ	01h
PS2_CT	equ	02h
;
;--------------------------------------
	include "KEYCODE.INC"
;--------------------------------------
	include "x1sub.inc"
;--------------------------------------
	include "rtos.inc"
;--------------------------------------

;PS2 INDICATOR BIT ASSIGN
;
IND_SCRL equ	01h
IND_NUM  equ	02h
IND_CAPS equ	04h

;******************************************************************************
	DSEG
	org	WORK_TOP
;
;----------- HOST I/F work ------------
X1_WORK_BASE	equ	$
;---------------------------------------
host_cmd	ds	2
key_wp		ds	2 ;key buffer write pointer
key_rp		ds	2 ;key buffer read pointer
irq_vct		ds	2 ;IRQ vector
;
cmt_ctrl	ds	2 ;CMT controll / state
cmt_sens	ds	2
;
fdc_cnt		ds	2 ;FDC task counter
fdc_sp		ds	2 ;FDC task stack pointer
main_sp		ds	2 ;main task stack pointer
;
;----------- KEY / PS2 work ------------
R12_BASE	equ	$
;---------------------------------------
ps2_flag:	ds	2	;
;
JOY_EN		equ	001h  ;JOY-EMU enable
IND_REQ		equ	002h  ;LED controll rdsest
RCV_F0		equ	080h  ;break(f0) receice
RCV_E0		equ	040h  ;esc(e0) receive
;
sft_key		ds	2     ;L-SHIFT / R-SHIFT
;
SFT_R_GRPH	equ	1000h
SFT_R_SHIFT	equ	0200h
SFT_R_CTRL	equ	0100h
SFT_TENKEY	equ	80h
SFT_KEYIN	equ	40h     ; preset key IN 
SFT_REP		equ	20h
SFT_L_GRPH	equ	10h
SFT_CAPS	equ	08h
SFT_KANA	equ	04h
SFT_L_SHIFT	equ	02h
SFT_L_CTRL	equ	01h
;
cur_ascii       ds      2 ; current key-on ascii code
joy_data        ds      2 ; joystick emulation data
;
ps2_sreg	ds	2 ; PS2 serial register
ps2_scnt	ds	2 ; PS2 serial counter / timeout counter
PS2_TXM1	equ	80h ; break PSC
PS2_TXM2	equ	40h ; transmit bit
ps2_tout	ds	2 ; PS2 timeout counter
;
oc_500ms	ds	2 ; output capture for 1sec clock/calender
;
;----------- subcpu work ------------
tv_ctrl		ds	2 ;TV last controll
tmr_dmy		ds	6
calender	ds	3+1
time		ds	3+1
game_key	ds	3+1
seg7_val	ds	2
;
;----------- key buffer ------------
key_buf		ds	16*2 ;ASCII + CTRL x 16
key_buf_e
;

;---------------------------------------
R10_BASE	equ	$
;---------------------------------------
;----------- FDC emulation ----------
fdc_ip		ds	2 ;IndexPulse counter
fdc_slen	ds	2 ;sector length counter
;
;----------- FDD emiulation ------------
;for FDC contact
fdd_trk:	ds	2 ;track data top position
fdd_num_sec	ds	2 ;data
fdd_c		ds	2 ;C
fdd_h		ds	2 ;H
fdd_r		ds	2 ;R
fdd_n		ds	2 ;N
;
fdd_sts		ds	2 ;status
;
fdd_sec_ptr	ds	2 ;sector pointer
;
fdd_meml	ds	2 ;FDD sector data memory point
fdd_memh	ds	2 ;FDD sector data memory point
fdd_len		ds	2 ;FDD sector data counter
;
;FD Drive Data
fdd_ptr		ds	2 ;pointer of FD physical data
;
;Drive0 Phisical Status
fd_phy0:
fd_phy_trk	ds	2 ;track , status(insert,type,etc)
fd_phy_ml:	ds	2 ;FD Image Base address L
fd_phy_mh:	ds	2 ;FD Image Base address H
fd_phy_size	equ	$-fd_phy0
;Drive1 Phisical Status
fd_phy1:
		ds	fd_phy_size
;
PCM_S	ds	2
PCM_E	ds	2
;
;******************************************************************************
;vector
;******************************************************************************
	CSEG
	org	0000h
;
;----------------------------------------------------------------------------
; vector
;----------------------------------------------------------------------------
	dw	reset
	dw	tmr_isr
	dw	ps2_isr
	dw	fdc_isr ;command trap
	dw	dma_isr ;command trap
;
;----------------------------------------------------------------------------
; isr end 
;----------------------------------------------------------------------------
isr_r2_r:
	pop	r2
isr_r1_r:
	pop	r1
isr_r0_r:
	pop	r0
isr_f_r:
	pop	flag
	ret	sti

;----------------------------------------------------------------------------
; interval timer ISR
;----------------------------------------------------------------------------
;8us interval == 256clock cycle
tmr_isr:
	push	flag
	add	r8,#1:8
	tst	r8,#1:8
	jne	OS_Timer_isr ;xxxxxxxxxxxxxxx1 : 16us TASK switch timer
;
	tst	r8,#2:8
	beq	isr_500ms ;xxxxxxxxxxxxxx00 : 32us 500ms timer
;
	tst	r8,#4:8
	beq	isr_ps2   ;xxxxxxxxxxxxx010 : 64us ps2 timeout
;
	tst	r8,#8:8
	beq	isr_pcm   ;xxxxxxxxxxxx0110 : 128us PCM PLAY
;
	pop	flag
	ret	sti
;
;---- for 1sec counter -----
isr_500ms:
	push	r0
	ldm	r0,(r12,#oc_500ms-R12_BASE)
	cmp	r0,r8
	bne	isr_r0_r
	add	r0,#500000/8  ;next 500ms
	stm	(r12,#oc_500ms-R12_BASE),r0
;1Hz text Blink Timer
	ldm	r0,(r14,#HOST_CTRL-R14_BASE)
	xor	r0,#CLK_1HZ:8
	stm	(r14,#HOST_CTRL-R14_BASE),r0
;1Hz interval timer for clock
;	tst	r0,#CLK_1HZ:8
;	beq	clk_1sec
;
	bra	isr_r0_r
;
;---- PS/2 timeout isr -----
isr_ps2:
	push	r0
	ldm	r0,(r12,#ps2_tout-R12_BASE)
	sub	r0,#1:8
	bmi	isr_r0_r ;timer stopped
;decrement timer
	stm	(r12,#ps2_tout-R12_BASE),r0
	bne	isr_r0_r
;timeout event
	ldm	r0,(r12,#ps2_scnt-R12_BASE)
	tst	r0,#PS2_TXM1:8
	bne	ps2_tmr_tx1     ;TX request -> waiting TX
	tst	r0,#PS2_TXM2:8
	bne	ps2_tmr_tx2     ;waiting TX timeout
;
;---------- recevice timeout error ----------
ps2_tmr_rx:
	push	r1
;	mov	r0,#0ffh:8  ;reset command
;	jsr	ps2_tx
	jsr	ps2_rx_en
	bra	isr_r1_r
;
;---------- release transmit break ----------
ps2_tmr_tx1:
	mov	r0,#PS2_CT:8                 ; DAT=L,CLK=Z
	stm	(r14,#PS2_CTRL-R14_BASE),r0
;----- change TX mode & set timeout -----
	mov	r0,#15000/PS2_TICK:8          ;15ms
	stm	(r12,#ps2_tout-R12_BASE),r0
;
	mov	r0,#PS2_TXM2:8                ;TX2 mode
	stm	(r12,#ps2_scnt-R12_BASE),r0
	bra	isr_r0_r
;
;---------- transmit timeout error ----------
ps2_tmr_tx2:
	mov	r0,#PS2_CT | PS2_DT:8         ; DAT=Z , CLK=Z
	stm	(r14,#PS2_CTRL-R14_BASE),r0
;
	push	r1
;	mov	r0,#0ffh:8  ;reset command
;	jsr	ps2_tx
	jsr	ps2_rx_en
	bra	isr_r1_r
;
;-------------------------------------
;PCM isr
;-------------------------------------
;32us * 4 = 128us = 7.8125KHz
isr_pcm:
	push	r0
	push	r1
	push	r2
	mov	r2,#PCM_S
	ldm	r0,(r2,#PCM_S-PCM_S)
	ldm	r1,(r2,#PCM_E-PCM_S)
	cmp	r0,r1
	bhs	isr_r2_r
	ldm	r1,(r0)
	tst	r2,#1:8
	beq	isr_pcm_1
	mlh	r1,#100h
isr_pcm_1:
	stm	(r14,#PCM_DATA-R14_BASE),r1
	add	r0,#1:8
	stm	(r2,#PCM_S-PCM_S),r0
	bra	isr_r2_r
;
;----------------------------------------------------------------------------
; PS2 CLK fall ISR
;----------------------------------------------------------------------------
ps2_isr:
	push	flag
	push	r0
	push	r1
;
	ldm	r0,(r12,#ps2_scnt-R12_BASE)
	tst	r0,#PS2_TXM1 | PS2_TXM2:8
	bne	ps2_tx_isr
;RX mode
	ldm	r0,(r12,#ps2_sreg-R12_BASE)
	mlh	r0,#8000h                   ;right shift
;bit shift in
	ldm	r1,(r14,#PS2_STS-R14_BASE)
	and	r1,#PS2_DT:8
	beq	ps2_isr2
	or	r0,#8000h                   ;set bit
ps2_isr2:
	stm	(r12,#ps2_sreg-R12_BASE),r0
;count down & RX finish?
	ldm	r0,(r12,#ps2_scnt-R12_BASE)
	sub	r0,#1:8
	stm	(r12,#ps2_scnt-R12_BASE),r0
	beq	ps2_isr_in
;set timeout
	mov	r0,#1000/PS2_TICK:8              ;1ms timeout
	stm	(r12,#ps2_tout-R12_BASE),r0
	bra	ps2_isr_e
;
;byte received
ps2_isr_in:
;stop receiver
	push	r2
	push	r3
	push	r4
	push	r5
	push	r6
	push	r7
	jsr	ps2_rx
	pop	r7
	pop	r6
	pop	r5
	pop	r4
	pop	r3
	pop	r2
ps2_isr_e:
	pop	r1
	pop	r0
	pop	flag
	ret	sti
;
ps2_tx_isr:
	tst	r0,#PS2_TXM1:8
	bne	ps2_isr_e
;
	ldm	r0,(r12,#ps2_sreg-R12_BASE)
;-- output next DATA bit
	mov	r1,#PS2_CT:8  ; DAT = L
	tst	r0,#1:8
	beq	ps2_tx_i2
	or	r1,#PS2_DT:8                     ; DAT = Z
ps2_tx_i2:
	stm	(r14,#PS2_CTRL-R14_BASE),r1
;-- input DAT line for ACK check --
	ldm	r1,(r14,#PS2_STS-R14_BASE)
;-- next bit select & loop
	mlh	r0,#8000h  ;right shift
	bne	ps2_tx_i3
;finish TX
	mov	r0,r1          ;save ACK bit
	jsr	ps2_rx_en
ps2_tx_i3:
	stm	(r12,#ps2_sreg-R12_BASE),r0
	bra	ps2_isr_e
;
;----------------------------------------------------------------------------
; RESET entry
;----------------------------------------------------------------------------
reset:
;----- fixed registers -----
	mov	r15,#STACK_END
	mov	r14,#R14_BASE ; GPIO / TIMER
	mov	r13,#X1_WORK_BASE ; X1 SUB CPU work
	mov	r12,#R12_BASE ; PS/2 work
	mov	r11,#R11_BASE ; Memory mapped I/O
	mov	r10,#R10_BASE ; FDC / FDD emulation
	mov	r8,#0:8       ; 16us Timer Counter
;
.ifdef SHOW_INIT
	mov	r0,#1000h
	stm	(r14,#SEG7_NUM-R14_BASE),r0
.endif
.ifdef DMA_TEST
;dump 10000H to TEXT 
	mov	r1,#0000h
	mov	r2,#3000h
	mov	r3,#40:8
dma_tst1:
	stm	(r14,#FDM_AL-R14_BASE),r1
	mov	r0,#0001h | DMAM_RFSH_REQ | DMAM_MREQ | DMAM_RD
	stm	(r14,#FDM_AH-R14_BASE),r0
dma_tst2:
	ldm	r0,(r14,#DMA_DATA-R14_BASE)
	tst	r0,#DMAM_BUSY
	bne	dma_tst2
;
	ldm	r0,(r14,#DMA_DATA-R14_BASE)
	stm	(r14,#DMA_DATA-R14_BASE),r0
	mov	r0,#0:8
	stm	(r14,#FDM_AH-R14_BASE),r0
;
	stm	(r14,#FDM_AL-R14_BASE),r2
	mov	r0,#DMAM_RFSH_REQ | DMAM_IORQ | DMAM_WR
	stm	(r14,#FDM_AH-R14_BASE),r0
dma_tst3:
	ldm	r0,(r14,#DMA_DATA-R14_BASE)
	tst	r0,#DMAM_BUSY
	bne	dma_tst3
	mov	r0,#0:8
	stm	(r14,#FDM_AH-R14_BASE),r0
;
	mov	r0,#DMAM_RFSH_REQ | DMAM_MREQ | DMAM_WR
	stm	(r14,#FDM_AH-R14_BASE),r0
dma_tst4:
	ldm	r0,(r14,#DMA_DATA-R14_BASE)
	tst	r0,#DMAM_BUSY
	bne	dma_tst4
	mov	r0,#0:8
	stm	(r14,#FDM_AH-R14_BASE),r0
;
	add	r1,#1:8
	add	r2,#1:8
	sub	r3,#1:8
	bne	dma_tst1
.endif

;----- initialize I/O -----
;reset host port
;	ldm	r0,(r14,#HRD_SET-R14_BASE)    ;set hrd flag
	ldm	r0,(r14,#HWD_CLR-R14_BASE)    ;set hrd flag
;reset PS2 port
	mov	r0,#PS2_CT |PS2_DT:8
	stm	(r14,#PS2_CTRL-R14_BASE),r0
;IRQ off , break off
	mov	r0,#0:8
	stm	(r14,#HOST_CTRL-R14_BASE),r0
;Timer Stop
	mov	r0,#0:8
	stm	(r14,#TMR_CTR-R14_BASE),r0
;----- initialize internal work -----
;----- clear work RAM -----
	mov	r0,#RAM_TOP
	mov	r1,#RAM_END
	mov	r2,#0:8
clr0:
	stm	(r0),r2
	add	r0,#2:8
	cmp	r0,r1
	bne	clr0
;----- DMAC -----
.ifdef Z80DMA
	jsr	dma_init
.endif
;-- START RTOS -----
	mov	r0,#start ;entry point
	mov	r1,#80:8      ;stack size
	mov	r2,#STACK_END
	jmp	OS_Init
;
;----------------------------------------------------------------------------
;RTOS entry (base TASK ,X1 subcpu and some handling)
;----------------------------------------------------------------------------
start:
;set CAPS ON
	mov	r0,#0ffffh ^ SFT_CAPS
	stm	(r12,#sft_key-R12_BASE),r0
;clear key buf
	mov	r0,#key_buf
	mov	r1,#0ffh:8                   ; CTRL + ASCII
	stm	(r13,#key_wp-X1_WORK_BASE),r0
	stm	(r13,#key_rp-X1_WORK_BASE),r0
	stm	(r0),r1
;CMT status
	mov	r0,#CMT_STOP:8 ; command
	mov	r1,#0ffh:8     ; sensor
	stm	(r13,#cmt_ctrl-X1_WORK_BASE),r0
	stm	(r13,#cmt_sens-X1_WORK_BASE),r1
;----- JOY-KEY default on , LED setup ON  -----
	mov	r0,#JOY_EN | IND_REQ:8
	stm	(r12,#ps2_flag-R12_BASE),r0
	jsr	joy_clr
;
;----- start FDC task -----
	mov	r0,#fdc_entry
	mov	r1,#80:8      ;stack size
;	mov	r2,#OS_NEVER
	mov	r2,#OS_RUN:8
	jsr	OS_CreateTask
;
;----- start timer ------
;Timer
	mov	r0,#CPU_MHZ*8                 ; 8usec
	mov	r1,#TC_RUN | TC_IEN | TC_RST:8
	stm	(r14,#TMR_INT-R14_BASE),r0
	stm	(r14,#TMR_CTR-R14_BASE),r1
;----- PS/2 reset & start -----
;	mov	r0,#0edh:8
	mov	r0,#0ffh:8  ;RESET command
	jsr	PS2_TX
;
	sti
;
;----------------------------------------------------------------------------
; MAIN LOOP 
;----------------------------------------------------------------------------
MAIN:
;------ command in check ------
	ldm	r0,(r14,#HOST_STS-R14_BASE)
	tst	r0,#HWD_FUL:8
	beq	main1
	jsr	cmd_in
	bra	MAIN
main1:
	jsr	key_irq
	bra	MAIN
;
;----------------------------------------------------------------------------
; HOST COMMAND handling
;----------------------------------------------------------------------------
cmd_in:
	mov	r0,#host_cmd
	mov	r1,#1:8
	jsr	host_r    ; get CMD byte
;branch cmd
	ldm	r0,(r13,#host_cmd-X1_WORK_BASE)
;
	cmp	r0,#0f0h:8 ; F0-FF
	bhs	cmd_fx
	cmp	r0,#0e0h:8 ; E0-EF
	bhs	cmd_ex
	cmp	r0,#0d8h:8 ; D8-DF
	bhs	TMR_GET
	cmp	r0,#0d0h:8 ; D0-D7
	bhs	TMR_SET
;00-CF
cmd_r:
	ret
;
;----- CMD F0-FF -----
cmd_fx:
	cmp	r0,#0f0h:8 ; F0 ?
	beq	cmd_f0
	ret
;f0 : 7SEG LED controll
cmd_f0:
	mov	r0,#seg7_val
	mov	r1,#2:8
	jsr	host_r
	sub	r0,#2:8
	ldm	r0,(r0)
	stm	(r14,#SEG7_NUM-R14_BASE),r0
	ret
;
;----- TIMER SET -----
TMR_SET:
	mov	r0,#tmr_dmy
	mov	r1,#6:8
	jmp	host_r
;----- TIMER GET -----
TMR_GET:
	mov	r0,#tmr_dmy
	mov	r1,#6:8
	jmp	host_w
;----- CMD E0-EF -----
cmd_ex:
.ifdef SHOW_HOST_W
	mov	r3,r0
	or	r3,#3000h
	stm	(r14,#SEG7_NUM-R14_BASE),r3
.endif
	and	r0,#0fh:8
	mlt	r0,#4:8
	add	r0,#cmd_tbl
	ldm	r2,(r0,#0) ;entry
	ldm	r0,(r0,#2) ;r0 value : pointer
	mov	r1,#1:8    ;length default == 1
	jmp	r2
cmd_tbl:
;length.bit15 : pre-receive nBytes
	dw	MAIN   ,0       ;E0
	dw	MAIN   ,0       ;E1
	dw	MAIN   ,0       ;E2
	dw	host_w3,game_key;E3 GAME KEY
	dw	CMD_E4 ,irq_vct ;E4
	dw	MAIN   ,0       ;E5
	dw	CMD_E6 ,0       ;E6
	dw	CMD_E7 ,tv_ctrl ;E7 TV CTRL
	dw	host_w ,tv_ctrl ;E8 TV READ
	dw	CMD_E9 ,cmt_ctrl;E9 CMT CTRL
	dw	host_w ,cmt_ctrl;EA CMT Status
	dw	host_w ,cmt_sens;EB CMT sensor
	dw	CMD_EC ,calender;EC calender set
	dw	host_w3,calender;ED calender read
	dw	CMD_EE ,time    ;EE time set
	dw	host_w3,time    ;EF time read
;
;----- 3byte WR -----
host_w3:
	mov	r1,#3:8  ;3byte
	jmp	host_w
;
;----- IRQ VECTOR -----
CMD_E4:
	jsr	host_r
	ldm	r0,(r13,#key_wp-X1_WORK_BASE)
	stm	(r13,#key_rp-X1_WORK_BASE),r0
	ret
;
;----- KEY READ -----
CMD_E6:
	mov	r1,#2:8
	ldm	r0,(r13,#key_wp-X1_WORK_BASE) ;last key code
	jmp	host_w
;----- TV control -----
CMD_E7:
	jsr	host_r
	ret
;----- CMT control -----
CMD_E9:
	jsr	host_r
	ret
;----- calender set -----
CMD_EC:
	mov	r1,#3:8  ;3byte
	jsr	host_r
	ret
;----- time set -----
CMD_EE:
	mov	r1,#3:8  ;3byte
	jsr	host_r
	ret
;
;----------------------------------------------------------------------------
;  KEYBOARD IRQ
;----------------------------------------------------------------------------
key_irq:
	ldm	r0,(r13,#key_wp-X1_WORK_BASE)
	ldm	r1,(r13,#key_rp-X1_WORK_BASE)
	cmp	r0,r1	;key avaiable?
	beq	no_irq
;CMT not play or rec
	ldm	r0,(r13,#cmt_ctrl-X1_WORK_BASE)
	cmp	r0,#CMT_PLAY:8
	beq	no_irq
	cmp	r0,#CMT_REC:8
	beq	no_irq
;
;and vector != 00h
	ldm	r0,(r13,#irq_vct-X1_WORK_BASE)
	and	r0,#0ffh:8
	beq	no_irq
;--------------------
;assert key IRQ
;--------------------
;IRQ enable
	cli
	ldm	r0,(r14,#HOST_CTRL-R14_BASE)
	or	r0,#PIO_IRQ:8
	stm	(r14,#HOST_CTRL-R14_BASE),r0
	sti
;TX IRQ vecor
	mov	r0,#irq_vct
	mov	r1,#1:8
	jsr	host_w
;IRQ disable
	cli
	ldm	r0,(r14,#HOST_CTRL-R14_BASE)
	xor	r0,#PIO_IRQ:8
	stm	(r14,#HOST_CTRL-R14_BASE),r0
	sti
;update key buffer
	ldm	r0,(r13,#key_rp-X1_WORK_BASE)
	add	r0,#2:8
	cmp	r0,#key_buf_e
	bne	upd_rp
	mov	r0,#key_buf
upd_rp:
	stm	(r13,#key_rp-X1_WORK_BASE),r0
;return key code from key buffer
	mov	r1,#2:8
	jmp	host_w
no_irq:
	ret
;
;----------------------------------------------------------------------------
;  JOY KEY clear
;----------------------------------------------------------------------------
joy_clr:
	mov	r0,#0ffffh
	stm	(r13,#joy_data-X1_WORK_BASE),r0
	stm	(r14,#JOY_PORT-R14_BASE),r0 ; output port
	ret
;
;----------------------------------------------------------------------------
; PS2 receive data handling
;----------------------------------------------------------------------------
;r0-r2 work
;
;r5 = work (raw_code / ascii code)
;r6 = work (sft_key)
;r7 = work (ps2_flag)
;
ps2_rx:
	ldm	r0,(r12,#ps2_sreg-R12_BASE) ;get RX reg
	jsr	ps2_rx_en                   ;restart RX
;IRQ enable for next receive bit
	sti
;load fixed data value
	ldm	r7,(r12,#ps2_flag-R12_BASE)
	ldm	r6,(r12,#sft_key -R12_BASE)
;receive code handling
	mlh	r0,#0400h ;MSB in -> LSB in ,bit8 = parity,bit10 = stop
.ifdef SHOW_PS2_RAW
	stm	(r14,#SEG7_NUM-R14_BASE),r0
.endif
;check stop bit
	tst	r0,#200h  ;STOP bit ?
	beq	ps2_err
;check parity
	jsr	ps2_pty
	tst	r0,#100h  ;parity ODD ?
	beq	ps2_err
;BYTE CODE
	and	r0,#0ffh:8  ;PS/2 Receive BYTE
;
	tst	r0,#80h:8
	beq	ps2_code
;80-FFH ctrl code
	cmp	r0,#0f0h:8
	beq	ps2_f0		;F0 release code
	cmp	r0,#0e0h:8
	beq	ps2_e0		;E0 shift code
	cmp	r0,#0fah:8
	beq	ps2_fa		;E0 shift code
	cmp	r0,#0e1h:8
	beq	ps2_e1		;E1 shift code for pause key
	cmp	r0,#0aah:8
	beq	ps2_aa		;AA reset code
;
	jmp	ps2_rxe
;
;---------- F0 release code -----------
ps2_f0:
	or	r7,#RCV_F0:8
	jmp	ps2_rxe
;---------- E0 shift code -----------
ps2_e0:
	or	r7,#RCV_E0:8
	jmp	ps2_rxe
;---------- FA ack code -----------
ps2_fa:
;	tst	r7,IND_REQ ; set LED ack?
;	bne	ps2_rst    ; unknown ack
	and	r7,#0ffh ^ IND_REQ:8
;----- LED IND parameter -----
;LED data
	mov	r0,#0:8
	tst	r6,#SFT_KANA:8
	bne	ps2_l1
	or	r0,#IND_NUM:8
ps2_l1:
	tst	r6,#SFT_CAPS:8
	bne	ps2_l2
	or	r0,#IND_CAPS:8
ps2_l2:
	tst	r7,#JOY_EN:8
	beq	ps2_l3
	or	r0,#IND_SCRL:8
ps2_l3:
	jsr	PS2_TX
	jmp	ps2_rxe
;
;----- E1 shift for pause ----
ps2_e1		;E1 shift code for pause key
	jmp	ps2_rxe
;
;----- AA RESET ----
ps2_err:
;	jsr	ps2_rx_en        ;format error
ps2_aa:
	mov	r5,#0:8          ; clear raw_key code
;
	or	r7,#IND_REQ:8    ; LED req on
	jmp	ps2_led          ; IND transmit & end
;
;----- F12:JOY-KEY mode change -----
joy_mode:
	tst	r7,#RCV_F0:8
	jne	ps2_rxc		; MAKE only
;
	xor	r7,#JOY_EN:8	; flip JOY EMU mode
	or	r7,#IND_REQ:8	; LED controll request
;reset JOY KEY
	jsr	joy_clr
	jmp	ps2_rxc
;
;----- 00-7F : Key Code -----
ps2_code:
;PS2 scan code to RAW code convert
	tst	r7,#RCV_E0:8
	beq	ps2_c1
	or	r0,#80h:8         ;E0 shift code -> 80-ff
ps2_c1:
;get raw code from scan code
	add	r0,#ps2_raw
	jsr	ldmb_r0
	mov	r5,r0         ; r5 = raw code
	beq	ps2_rxc
;----- JOY-KEY emulation ------
	tst	r7,#JOY_EN:8
	beq	joy_no_r
;
	jsr	joy_emu
	or	r0,r0
	beq	joy_no_r
;output to joy port
	ldm	r1,(r13,#joy_data-X1_WORK_BASE)
	or	r1,r0    ;set   GAME bit
	tst	r7,#RCV_F0:8
	bne	joy_off
	xor	r1,r0    ;reset GAME bit
joy_off:
	stm	(r13,#joy_data-X1_WORK_BASE),r1
	stm	(r14,#JOY_PORT-R14_BASE),r1
	bra	ps2_rxc
;
joy_no_r:
;----- shift key ?? -----
	or	r6,#SFT_KEYIN | SFT_TENKEY | SFT_REP:8 ;preset some CTRL bit
	tst	r5,#80h:8    ;special raw code?
	bne	key_special
;----- game key sense -----
.ifdef F_GAME_KEY
set_gkey:
	mov	r0,r5
	add	r0,#raw_x1_gk-1  ;orign 1
	jsr	ldmb_r0
	tst	r0,#080h:8
	bne	set_gkey_e
;hit game key
	mov	r1,r0
	mlh	r1,#100h     ;offset
	add	r1,r1        ;x2
	add	r1,#game_key
	jsr	bit2mask    ;get bitmask
	ldm	r2,(r1)     ;LOAD current game key
	or	r2,r0       ;set   GAME-KEY bit
	tst	r7,#RCV_F0:8;is release ?
	beq	set_gk3
	xor	r2,r0       ;clear GAME-KEY bit
set_gk3:
	stm	(r1),r2     ;update current game key
set_gkey_e:
	add	r1,#game_key
;
.endif
	xor	r6,#SFT_KEYIN:8 ; set ASCII KEY mark
	bra	key_ascii
;
;-----------------------------------------------------------
;SHIFT / SFR KEY GROUP?
key_special:
;----- Special Function key ckeck -----
	cmp	r5,#KC_JOY_EMU:8
	beq	joy_mode       ; JOY EMULATION on/off
;
;----- SHIFT KEYS -----
key_shift:
;----- left or right sel -----
	mov	r0,r5
	jsr	bit2mask
	tst	r0,#SFT_CAPS | SFT_KANA:8 ; altanate group
	bne	sh_toggle
	or	r6,r0        ; when SHIFT,CTRL,GRPH
sh_toggle:
	tst	r7,#RCV_F0:8
	bne	key_sh_e
	xor	r6,r0        ; when press
key_sh_e:
	or	r7,#IND_REQ:8 ; LED controll request ON
;----- end of shift handle -----
end_sh:
	mov	r5,#00h:8       ; non-ascii code mark
;----- ASCII key group -----
key_ascii:
;-------------------------------------
;TENKEY marking
	cmp	r5,#KC_F1:8
	blo	tenkey_r
	xor	r6,#SFT_TENKEY:8  ; set TENKEY !
tenkey_r:
;-------------------------------------
;REPEAT marking
	tst	r6,#SFT_KEYIN:8
	bne	rep_1          ; SHIFT KEY -> ignore repeat
	ldm	r0,(r13,#cur_ascii-X1_WORK_BASE)
	cmp	r0,r5
	bne	rep_1
	xor	r6,#SFT_REP:8  ; mark REPEAT bit
rep_1:
;-------------------------------------
;KEY ON / OFF
	tst	r7,#RCV_F0:8 ;key off event?
	beq	key_on
;BERAK OFF
	jsr	brk_off
;-------------------------------------
;KEY off handling
	tst	r6,#SFT_REP:8
	bne	ps2_rxc                   ; release OLD pressed key
;last press key is off
	or	r6,#SFT_REP | SFT_KEYIN:8 ; clear repeat & key in bit
	mov	r5,#00h:8                 ; clear keycode (ASCII=00H)
	stm	(r13,#cur_ascii-X1_WORK_BASE),r5 ; clear last ASCII-IN key
;save last ASCII press key
key_on:
	tst	r6,#SFT_KEYIN:8
	bne	key_on1
;save last raw key
	stm	(r13,#cur_ascii-X1_WORK_BASE),r5 ; save last ASCII-IN key
key_on1:
;-------------------------------------
;r1 = multiplex LEFT & RIGHT SHIFT flags
	mov	r1,r6
	mlh	r1,#100h
	and	r1,r6
	and	r1,#0ffh:8
;get ASCII code
	jsr	get_asc ;r1 = ctrl , r0 ascii
;conbine ,ASCII & CTRL
	mlt	r0,#100h
	or	r0,r1
;store to key buffer
	ldm	r1,(r13,#key_wp-X1_WORK_BASE) ;WP
;when no IRQ mode , keep last key only
	ldm	r2,(r13,#irq_vct-X1_WORK_BASE)
	or	r2,r2
	beq	key_wb2          ; keep pointer
;next pointer
	add	r1,#2:8
	cmp	r1,#key_buf_e
	bne	key_wb1
	mov	r1,#key_buf
key_wb1:
	ldm	r2,(r13,#key_rp-X1_WORK_BASE)
	cmp	r2,r1
	beq	key_wbe	                   ;buffer full?
	stm	(r13,#key_wp-X1_WORK_BASE),r1  ;save new Write point
key_wb2:
	stm	(r1),r0  ;store key data
key_wbe:
.ifdef SHOW_KEYCODE
	stm	(r14,#SEG7_NUM-R14_BASE),r0
.endif
;BREAK port controll
	jsr	brk_ctrl
;----- clear receive status -----
ps2_rxc:
	and	r7,#0ffh ^ RCV_E0 ^ RCV_F0:8
;----- LED controll request -----
	tst	r7,#IND_REQ:8 ; LED req?
	beq	ps2_rxe
ps2_led:
	mov	r0,#0edh:8 ;IND command
	jsr	PS2_TX
;----- return page 0 -----
ps2_rxe:
;store fixed data value
	stm	(r12,#ps2_flag-R12_BASE),r7
	stm	(r12,#sft_key -R12_BASE),r6
	ret
;----- break port controll -----
;BREAK PORT check
;r0 = ascii code
brk_ctrl:
	cmp	r0,#03h:8  ;BREAK CODE?
	bne	brk_off
brk_on:
	cli
	mov	r0,#CMT_STOP:8
	mov	r1,#cmt_ctrl
	stm	(r1),r0   ; CMT STOP!!
;
	ldm	r0,(r14,#HOST_CTRL-R14_BASE)
	or	r0,#PIO_BRK:8
	bra	brk_sret
;
brk_off:
	cli
	ldm	r0,(r14,#HOST_CTRL-R14_BASE)
	and	r0,#0ffh ^ PIO_BRK:8
brk_sret:
	stm	(r14,#HOST_CTRL-R14_BASE),r0
	sti
	ret
;
;----------------------------------------------------------------------------
;  PS2 parity bit calcration
;----------------------------------------------------------------------------
;r0[7:0] = byte code
;r0[8]   = parity bit
;r1      = broken
ps2_pty:
	mov	r1,#1:8
ps2_pty1:
	tst	r0,r1
	beq	ps2_pty2
	xor	r0,#100h ;flip parity bit
ps2_pty2:
	add	r1,r1
	and	r1,#0ffh:8
	bne	ps2_pty1
	ret
;----------------------------------------------------------------------------
;  PS2 enable receiver
;----------------------------------------------------------------------------
;r1 broken
ps2_rx_en:
;	mov	r1,#0ffffh
;	stm	(r12,#ps2_sreg-R12_BASE),r1
	mov	r1,#11:8   ;receive bit
	stm	(r12,#ps2_scnt-R12_BASE),r1
;
	mov	r1,#0:8
	stm	(r12,#ps2_tout-R12_BASE),r1 ;no timeout
;
	ret
;
;----------------------------------------------------------------------------
;  PS2 TX byte
;----------------------------------------------------------------------------
;r0 = transmit data
PS2_TX:
;----- set TX mode and waiting -----
.ifdef PS2_RECEIVE_ONLY
;MiSTer HPS sends a one-way PS/2 stream; transmit pins are not connected.
;Same-size entry substitution preserves the inherited ROM layout. The active
;RTL ROM profile applies this one instruction without regenerating binaries.
	bra	ps2_rx_en
.else
	mov	r1,#0:8
.endif
	stm	(r12,#ps2_tout-R12_BASE),r1
	mov	r1,#PS2_TXM1:8
	stm	(r12,#ps2_scnt-R12_BASE),r1
;----- drive CLK=L
	mov	r1,#PS2_DT:8   ; DAT=Z,CLK=L
	stm	(r14,#PS2_CTRL-R14_BASE),r1
;----- calcurate parity bit & set transmit word -----
	or	r0,#100h  ; parity ODD
	jsr	ps2_pty
	or	r0,#600h  ;STOP BIT + ACK BIT
;r0 = 11bit TX data(8xdata + 1xparity + 1xstop + 1xack)
	stm	(r12,#ps2_sreg-R12_BASE),r0
;----- set timer for start transmit
	mov	r1,#280/PS2_TICK+1:8  ;160-320us for TX start
	stm	(r12,#ps2_tout-R12_BASE),r1
;continue to ISR
	ret
;
;----------------------------------------------------------------------------
;  bit postion to mask conversion
;----------------------------------------------------------------------------
;r0 = bit -> mask
bit2mask:
	and	r0,#0fh:8
	add	r0,r0
	add	r0,#mask_data
	ldm	r0,(r0)
	ret
mask_data:
	dw	0001h
	dw	0002h
	dw	0004h
	dw	0008h
	dw	0010h
	dw	0020h
	dw	0040h
	dw	0080h
	dw	0100h
	dw	0200h
	dw	0400h
	dw	0800h
	dw	1000h
	dw	2000h
	dw	4000h
	dw	8000h
;
;----------------------------------------------------------------------------
; read date from host
;----------------------------------------------------------------------------
;r0 = receive pointer
;r1 = receive counter
;r2 = broken
host_r:
;wait for data in
	ldm	r2,(r14,#HOST_STS-R14_BASE)
	tst	r2,#HWD_FUL:8
	beq	host_r
;data read
	ldm	r2,(r11,#HOST_WD-R11_BASE)
;store byte
	tst	r0,#1:8
	beq	hr1
;when high word conbine with memory
	mlt	r2,#100h
	ldm	r3,(r0)
	and	r3,#0ffh:8
	or	r2,r3
hr1:
	stm	(r0),r2                     ; save receive data
	ldm	r2,(r14,#HWD_CLR-R14_BASE)  ; clear hwd_full
;next pointer
	add	r0,#1:8
	sub	r1,#1:8
	bne	host_r
	ret
;
;----------------------------------------------------------------------------
; write data to host
;----------------------------------------------------------------------------
;r0 = transmit pointer
;r1 = transmit counter
;r2 = broken
host_w:
	ldm	r2,(r0) ; read tx data
	tst	r0,#1:8
	beq	hw1
	mlh	r2,#100h ; high word select
hw1:
.ifdef SHOW_HOST_R
	mov	r3,r1
	mlt	r3,#100h
	or	r3,r2
	stm	(r14,#SEG7_NUM-R14_BASE),r3
.endif
	stm	(r11,#HOST_RD-R11_BASE),r2    ;store data
	ldm	r2,(r14,#HRD_SET-R14_BASE)    ;set hrd flag
hw2:
;wait for port free
	ldm	r2,(r14,#HOST_STS-R14_BASE)
	tst	r2,#HRD_FUL:8
	bne	hw2
;
	add	r0,#1:8
	sub	r1,#1:8
	bne	host_w
	ret
;
;---------- JOY-KEY
;r5 = raw_code
;out
;r0 = joymask
joy_emu:
	mov	r0,#1:8
	mov	r1,#joy_tbl
joy_e1:
	ldm	r2,(r1)
	cmp	r2,r5
	beq	joy_ok
	add	r1,#2:8
	add	r0,r0
	bne	joy_e1
joy_ok:
	ret
joy_tbl:
;JOYA
	dw	KC_KP_8  ; UP
	dw	KC_KP_2  ; DN
	dw	KC_KP_4  ; LT
	dw	KC_KP_6  ; RT
	dw	KC_A     ; T4
	dw	KC_Z     ; T1
	dw	KC_X     ; T2
	dw	KC_C     ; T3
;JOYB
	dw	0
	dw	0
	dw	0
	dw	0
	dw	0
	dw	0
	dw	0
	dw	0
;	dw	KC_U_ARROW
;	dw	KC_L_ARROW
;	dw	KC_D_ARROW
;	dw	KC_R_ARROW
;	dw	KC_SPACE
;	dw	KC_ENTER
;	dw	KC_L_CTRL
;	dw	KC_L_SHFT
joy_tbl_e:
;
;******************************************************************************
; GET ASCI CODE from PS2 raw code
;******************************************************************************
;r1 combined shift keys
;
get_asc:
	mov	r0,r5         ; ascii code ?
	beq	get_asc_e
;
	tst	r1,#SFT_L_CTRL:8
	beq	asc_ctrl

.ifdef GRAPH_ASCII
	tst	r1,#SFT_L_GRPH:8
	beq	asc_graph
.endif
.ifdef KANA_ASCII
	tst	r1,#SFT_KANA:8
	beq	asc_kana
.endif
	cmp	r0,#KC_Z+1:8
	blo	asc_alpha
;
	tst	r1,#SFT_L_SHIFT:8
	beq	asc_shift
;---------- NORMAL (not alphabet)
	add	r0,#raw_x1_no-KC_Z-1
	jmp	ldmb_r0
;---------- SHIFT (not alphabet)
asc_shift:
	add	r0,#raw_x1_sh-KC_Z-1
	jmp	ldmb_r0
;---------- CTRL
asc_ctrl:
	cmp	r0,#KC_Z+1:8
	blo	asc_alpha
;not alphabet
	add	r0,#raw_x1_ct-KC_Z-1 ;+CTRL
	bra	get_asc_r
;
;---------- GRAPH
.ifdef GRAPH_ASCII
asc_graph:
	add	r0,#raw_x1_gr-1 ;+CTRL
	bra	get_asc_r
.endif
;
.ifdef KANA_ASCII
asc_kana:
	tst	r1,#SFT_L_SHIFT:8
	beq	asc_skana
;---------- KANA
	add	r0,#raw_x1_ka-1
	bra	get_asc_r
asc_skana:
;---------- SHIFT+KANA
	add	r0,#raw_x1_sk-1
	bra	get_asc_r
.endif
;
asc_alpha:
;---------- Alphabet A-Z / a-z
	or	r0,#60h:8 ; a-z
	tst	r1,#SFT_CAPS:8
	bne	asc_al1
	xor	r0,#20h:8 ; A-Z <-> a-z
asc_al1:
	tst	r1,#SFT_L_SHIFT:8
	bne	asc_al2
	xor	r0,#20h:8 ; A-Z <-> a-z
asc_al2:
	tst	r1,#SFT_L_CTRL:8
	bne	asc_al3
	and	r0,#1fh:8 ; 00H-1AH
asc_al3:
get_asc_e:
	ret
;
get_asc_r:
	jmp	ldmb_r0
;******************************************************************************
; BYTE access
;******************************************************************************
ldmb_r0:
	tst	r0,#1:8
	bne	ldmb_r0_o
;EVEN
	ldm	r0,(r0)
	and	r0,#0ffh:8
	ret
;ODD
ldmb_r0_o:
	ldm	r0,(r0)
	mlh	r0,#100h
	ret
;
;----------------------------------------------------------------------------
; PCM driver
;----------------------------------------------------------------------------
pcm_play:
	push	r2
	mov	r2,#PCM_S
	stm	(r2,#PCM_S-PCM_S),r0
	stm	(r2,#PCM_E-PCM_S),r1
	pop	r2
	ret
;
;----------------------------------------------------------------------------
; RTOS kernel
;----------------------------------------------------------------------------
	include "rtos.asm"
;----------------------------------------------------------------------------
; FDC & FDD Emulator
;----------------------------------------------------------------------------
	include "mb8877a.asm"
	include "fdd_emu.asm"
;----------------------------------------------------------------------------
; Z80 DMA Emulator
;----------------------------------------------------------------------------
;
.ifdef Z80DMA
	include "z80dma.asm"
.else
dma_isr:
	ret	sti
.endif
;
;******************************************************************************
; PS2 keyvode table
;******************************************************************************
	include "ps2map.inc"
;******************************************************************************
; X1 ASCII code table
;******************************************************************************
raw_x1_no:
	include "x1map0.inc"
	.align 2
raw_x1_sh:
	include "x1map1.inc"
	.align 2
raw_x1_ct:
	include "x1map2.inc"
	.align 2
.ifdef GRAPH_ASCII
raw_x1_gr:
	include "x1map3.inc"
	.align 2
.endif
;minimize option
.ifdef KANA_ASCII
raw_x1_ka:
	include "x1map4.inc"
	.align 2
raw_x1_sk:
	include "x1map5.inc"
	.align 2
.endif

;
.ifdef F_GAME_KEY
;KC_Q     KC_W     KC_E      KC_A      KC_D      KC_Z     KC_X     KC_C
;KC_KP_7  KC_KP_4  KC_KP_1   KC_KP_8   KC_KP_2   KC_KP_9  KC_KP_6  KC_KP_3
;KC_ESC   KC_1     KC_KP_MIN KC_KP_PUL KC_KP_MUL KC_TAB   KC_SPACE KC_ENTER
raw_x1_gk:
	include "x1map6.inc"
	.align 2
.endif
;
code_end
;
		END
