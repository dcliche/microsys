XOSERA_ADDRESS	equ	$f80060

XVID_AUX_ADDR	equ	$00
XVID_WRITE_ADDR	equ	$03
XVID_DATA	equ	$04
XVID_AUX_DATA	equ	$06
XVID_WRITE_INC	equ	$09
XVID_WR_PR_CMD	equ	$0E

init:

	; Wait until Xosera is ready
	move.l	#$ffff,d0
init0:
	subq.l	#1,d0
	bne	init0

	bsr	xcls

	jmp	*
	
; ---------------------------------------------
; Write byte to Xosera
; d0: register
; d1: value
; d2: msb (0) / lsb (1)
xwrite:
	move.l	d0,-(sp)
	move.l	d1,-(sp)

	lsl.w	#8,d0
	or.b	d1,d0
	lsl.w	#8,d2
	lsl.w	#4,d2
	or.w	d2,d0
	move.w	d0,XOSERA_ADDRESS

	move.l	(sp)+,d1
	move.l	(sp)+,d0

	rts

; ---------------------------------------------
; Write word to Xosera
; d0: register
; d1: value
xwritew:
	move.l	d2,-(sp)

; Write MSB
	move.l	d1,-(sp)
	lsr.l	#8,d1
	move.l	#0,d2
	bsr	xwrite
	move.l	(sp)+,d1

; Write LSB
	move.l	#1,d2
	bsr	xwrite

	move.l	(sp)+,d2
	rts

; ----------------------------------------------------------------------------------------------------------------------
; Clear screen
; d0: character
; d1: color
xcls:
	;
	; Set write increment to 0
	;

	move.l	#XVID_WRITE_INC,d0
	move.l	#0,d1
	bsr	xwritew

	
	move.l	#2400,d3 	; d3 = Number of characters (80x25)
	move.l	#0,d4		; d4 = Write address

xcls0:
	;
	; Set write address
	;

	move.l	#XVID_WRITE_ADDR,d0
	move.l	d4,d1
	bsr	xwritew

	;
	; Write color
	;

	move.l	#XVID_DATA,d0
	move.l	#2,d1
	move.l	#0,d2
	bsr	xwrite

	;
	; Write character
	;

	move.l	#XVID_DATA,d0
	move.l	#42,d1
	move.l	#1,d2
	bsr	xwrite

	; Increment and continue

	addq.l	#1,d4
	subq.l	#1,d3
	bne	xcls0

	rts


