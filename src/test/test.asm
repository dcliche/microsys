.arch microsys
;.org 0x0000
;.len 32768

.define LEDS		$8000
.define SWITCHES	$9000
.define SPRITE_X	$A000
.define SPRITE_Y	$A001
.define VIDEO_FRAME	$B000

start:
	mov	sp,@$7f00
	mov	ax,@LEDS
	mov	bx,@SWITCHES
	mov	ex,#0		; Counter
loop:
	; Wait frame
	mov	fx,@wait_frame
	jsr	fx

	; Display switches
	mov	fx,[bx]
	mov	[ax],fx

	jmp	loop
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
