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
	mov	cx,@SPRITE_X
	mov	dx,@SPRITE_Y
	mov	ex,#0		; Counter
	mov	fx,#100
	mov	[cx],fx
	mov	[dx],fx
loop:
	; Wait frame
	mov	fx,@wait_frame
	jsr	fx

	; Display switches
	mov	fx,[bx]
	mov	[ax],fx

	; Move sprite
	inc	ex
	and	ex,#$FF
	mov	[dx],ex
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
