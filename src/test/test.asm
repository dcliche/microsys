.arch microsys
;.org 0x0000
;.len 32768

.define LEDS		$8000
.define SWITCHES	$9000
.define X_REG		$A000
.define X_DATA		$B000
.define X_CTRL		$C000
.define VIDEO_FRAME	$F000

.define XVID_WRITE_ADDR_LSB	$03
.define XVID_DATA_LSB		$04
.define XVID_WRITE_INC_LSB	$09

.define XVID_WRITE_ADDR_MSB	$13
.define XVID_DATA_MSB		$14
.define XVID_WRITE_INC_MSB	$19

start:
	mov	sp,@$7f00

	;
	; Wait a little for Xosera initialization
	;

	mov	ax,@$1fff
start0:
	dec	ax
	bnz	start0		

	;
	; Clear screen
	;

	mov	fx,#42
	mov	[p0],fx
	mov	fx,#2
	mov	[p1],fx
	mov	fx,@xcls
	jsr	fx

	;
	; Loop
	;

	mov	ax,@LEDS
	mov	bx,@SWITCHES
loop:
	; Wait frame
	mov	fx,@wait_frame
	jsr	fx

	; Display switches
	mov	fx,[bx]
	mov	[ax],fx

	jmp	loop

; ----------------------------------------------------------------------------------------------------------------------
; Write to Xosera
; ax: register
; bx: data
; Modified registers: ax, bx, cx
xwrite:
	mov	cx,@X_REG
	mov	[cx],ax
	mov	cx,@X_DATA
	mov	[cx],bx

	; Wait
	;mov	ax,@$000f
xwrite0:
	;dec	ax
	;bnz	xwrite0	

	; Strobe
	mov	cx,@X_CTRL
	mov	bx,#0
	mov	[cx],bx		

	; Wait
	;mov	ax,@$000f
xwrite1:
	;dec	ax
	;bnz	xwrite1

	mov	bx,#1
	mov	[cx],bx

	; Wait
	;mov	ax,@$0fff
xwrite2:
	;dec	ax
	;bnz	xwrite2

	rts

; ----------------------------------------------------------------------------------------------------------------------
; Clear screen
; p0: character
; p1: color
; Modified registers: ax, bx, cx, dx, ex, fx
xcls:

	; Set write increment to 0
	mov	ax,#XVID_WRITE_INC_LSB
	mov	bx,#0
	mov	fx,@xwrite
	jsr	fx

	mov	ex,@2000 	; Number of characters (80x25)
	mov	dx,@$0000	; Current address

xcls0:
	; Set write address LSB
	mov	ax,#XVID_WRITE_ADDR_LSB	; Write address
	mov	bx,dx
	mov	fx,@xwrite
	jsr	fx

	; Set write address MSB
	mov	ax,#XVID_WRITE_ADDR_MSB	; Write address
	mov	bx,dx
	lsr	bx
	lsr	bx
	lsr	bx
	lsr	bx
	lsr	bx
	lsr	bx
	lsr	bx
	lsr	bx
	mov	fx,@xwrite
	jsr	fx	

	; Write character

	mov	ax,#XVID_DATA_MSB	; XVID data
	mov	fx,@p1
	mov	bx,[fx]
	mov	fx,@xwrite
	jsr	fx

	mov	ax,#XVID_DATA_LSB	; XVID data
	mov	fx,@p0
	mov	bx,[fx]
	mov	fx,@xwrite
	jsr	fx

	inc	dx
	dec	ex
	bnz	xcls0

	rts


; ----------------------------------------------------------------------------------------------------------------------
; Wait frame
wait_frame:
	;push fx
	; Wait until in VSYNC
	mov	fx,@VIDEO_FRAME
	mov	fx,[fx]
	and	fx,#1
	bz	wait_frame
	; Wait until out of VSYNC
wait_frame0:
	mov	fx,@VIDEO_FRAME
	mov	fx,[fx]
	and	fx,#1
	bnz	wait_frame0
	;pop	fx
	rts

p0:
.data $0000
p1:
.data $0000
p2:
.data $0000
p3:
.data $0000