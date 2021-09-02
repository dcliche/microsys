XOSERA_ADDRESS	equ	$f80060

XVID_AUX_ADDR	equ	$00
XVID_CONST_VAL	equ	$04
XVID_WRITE_ADDR	equ	$0C
XVID_DATA	equ	$10
XVID_AUX_DATA	equ	$18
XVID_WRITE_INC	equ	$24
XVID_WR_PR_CMD	equ	$38

	org	$2000

init:

	; Wait until Xosera is ready
	lea	XOSERA_ADDRESS,a0
	move.l	#$55AA,d0
init0:
	movep.w	d0,(XVID_CONST_VAL,a0)
	movep.w	(XVID_CONST_VAL,a0),d0
	cmp.w	#$55AA,d0
	bne	init0

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
	movep.w	d0,(XVID_WRITE_INC,a1)

	
	move.l	#2400,d3 	; d3 = Number of characters (80x25)
	move.l	#0,d4		; d4 = Write address

xcls0:
	;
	; Set write address
	;

	movep.w	d4,(XVID_WRITE_ADDR,a1)

	;
	; Write color
	;

	move.l	(4,a0),d0
	move.b	d0,(XVID_DATA,a1)

	;
	; Write character
	;

	move.l	(8,a0),d0
	move.b	d0,(XVID_DATA+2,a1)

	; Increment and continue

	addq.l	#1,d4
	subq.l	#1,d3
	bne	xcls0

	movem.l (sp)+,d2-d4

	rts


