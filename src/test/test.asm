XOSERA_ADDRESS	equ	$f80060

XM_XR_ADDR	equ	$00
XM_XR_DATA	equ	$04
XM_RD_INCR	equ	$08
XM_RD_ADDR	equ	$0C
XM_WR_INCR	equ	$10
XM_WR_ADDR	equ	$14
XM_DATA		equ	$18
XM_DATA_2	equ	$1C
XM_SYS_CTRL	equ	$20
XM_TIMER	equ	$24
XM_WR_PR_CMD	equ	$28
XM_UNUSED_B	equ	$2C
XM_RW_INCR	equ	$30
XM_RW_ADDR	equ	$34
XM_RW_DATA	equ	$38
XM_RW_DATA_2	equ	$3C

	org	$2000

init:

	; Wait until Xosera is ready
	lea	XOSERA_ADDRESS,a0
init0:
	move.l	#$F5A5,d0
	movep.w	d0,(XM_XR_ADDR,a0)
	movep.w	(XM_XR_ADDR,a0),d0
	cmp.w	#$F5A5,d0
	bne	init0

init1:
	move.l	#$FA5A,d0
	movep.w	d0,(XM_XR_ADDR,a0)
	movep.w	(XM_XR_ADDR,a0),d0
	cmp.w	#$FA5A,d0
	bne	init1

	move.l	#42,-(sp)	; character
	move.l	#2,-(sp)	; color
	jsr	xcls
	addq.l	#8,sp

	jmp	*
	

; ----------------------------------------------------------------------------------------------------------------------
; Clear screen
; p1: color
; p2: character
xcls:
	move.l	sp,a0

	movem.l d2-d4,-(sp)

	lea	XOSERA_ADDRESS,a1

	;
	; Set write increment to 0
	;

	move.l	#0,d0
	movep.w	d0,(XM_WR_INCR,a1)

	
	move.l	#2400,d3 	; d3 = Number of characters (80x25)
	move.l	#0,d4		; d4 = Write address

xcls0:
	;
	; Set write address
	;

	movep.w	d4,(XM_WR_ADDR,a1)

	;
	; Write color
	;

	move.l	(4,a0),d0
	move.b	d0,(XM_DATA,a1)

	;
	; Write character
	;

	move.l	(8,a0),d0
	move.b	d0,(XM_DATA+2,a1)

	; Increment and continue

	addq.l	#1,d4
	subq.l	#1,d3
	bne	xcls0

	movem.l (sp)+,d2-d4

	rts


