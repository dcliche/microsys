.arch microsys
;.org 0x0000
;.len 32768

.define LEDS		$8000
.define SWITCHES	$9000
.define X_REG		$A000
.define X_DATA		$B000
.define X_CTRL		$C000
.define VIDEO_FRAME	$F000

.define XVID_AUX_ADDR		$00
.define XVID_WRITE_ADDR		$03
.define XVID_DATA		$04
.define XVID_AUX_DATA		$06
.define XVID_WRITE_INC		$09
.define XVID_WR_PR_CMD		$0E

.define AUX_GFXCTRL		$04

.define PR_COORDX1		$0000
.define PR_COORDY1		$1000
.define PR_COORDX2		$2000
.define PR_COORDY2		$3000
.define PR_COLOR		$4000
.define PR_EXECUTE		$F000

start:
	mov	sp,@$7fff

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

	mov	ax,#42
	mov	bx,#2
	mov	fx,@xcls
	jsr	fx

	;
	; Wait 60 frames
	;

	mov	ax,#60
	mov	fx,@delay
	jsr	fx

	;
	; Set bitmap mode
	;

	mov	fx,@xwritew

	mov	ax,#XVID_AUX_ADDR
	mov	bx,@AUX_GFXCTRL
	jsr	fx

	mov	ax,#XVID_AUX_DATA
	mov	bx,@$8000
	jsr	fx

	;
	; Clear the bitmap
	;

	mov	fx,@xwritew

	; Reset memory address
	mov	ax,#XVID_WRITE_ADDR
	mov	bx,@0
	jsr	fx

	; Set write increment
	mov	ax,#XVID_WRITE_INC
	mov	bx,@1
	jsr	fx

	; Draw pixels
	mov	cx,@38400	; 480 * 80
start1:
	mov	ax,#XVID_DATA
	mov	bx,@$1111
	jsr	fx
	dec	cx
	bnz	start1

	; Send draw line command
	mov	ax,#XVID_WR_PR_CMD

	mov	bx,@PR_COORDX1
	or	bx,@0
	jsr	fx

	mov	bx,@PR_COORDY1
	or	bx,@0
	jsr	fx

	mov	bx,@PR_COORDX2
	or	bx,@79
	jsr	fx

	mov	bx,@PR_COORDY2
	or	bx,@200
	jsr	fx

	mov	bx,@PR_COLOR
	or	bx,@4		; red
	jsr	fx

	mov	bx,@PR_EXECUTE
	jsr	fx

	;
	; Wait 60 frames
	;

	push	ax
	push	fx
	mov	ax,#60
	mov	fx,@delay
	jsr	fx
	pop	fx
	pop	ax	

	; Second line
	mov	bx,@PR_COORDX1
	or	bx,@79
	jsr	fx

	mov	bx,@PR_COORDY1
	or	bx,@200
	jsr	fx

	mov	bx,@PR_COORDX2
	or	bx,@50
	jsr	fx

	mov	bx,@PR_COORDY2
	or	bx,@300
	jsr	fx

	mov	bx,@PR_COLOR
	or	bx,@2			; green
	jsr	fx

	mov	bx,@PR_EXECUTE
	jsr	fx

	;
	; Wait 60 frames
	;

	push	ax
	push	fx
	mov	ax,#60
	mov	fx,@delay
	jsr	fx
	pop	fx
	pop	ax

	; Third line
	mov	bx,@PR_COORDX1
	or	bx,@50
	jsr	fx

	mov	bx,@PR_COORDY1
	or	bx,@300
	jsr	fx

	mov	bx,@PR_COORDX2
	or	bx,@10
	jsr	fx

	mov	bx,@PR_COORDY2
	or	bx,@100
	jsr	fx

	mov	bx,@PR_COLOR
	or	bx,@14		; yellow
	jsr	fx

	mov	bx,@PR_EXECUTE
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
xwrite:
	push	ax
	push	bx
	push	cx

	mov	cx,@X_REG
	mov	[cx],ax
	mov	cx,@X_DATA
	mov	[cx],bx

	; Wait
	;mov	ax,@$000f
;xwrite0:
	;dec	ax
	;bnz	xwrite0	

	; Strobe
	mov	cx,@X_CTRL
	mov	bx,#0
	mov	[cx],bx		

	; Wait
	;mov	ax,@$000f
;xwrite1:
	;dec	ax
	;bnz	xwrite1

	mov	bx,#1
	mov	[cx],bx

	; Wait
	;mov	ax,@$0fff
;xwrite2:
	;dec	ax
	;bnz	xwrite2

	pop	cx
	pop	bx
	pop	ax

	rts

; ----------------------------------------------------------------------------------------------------------------------
; Write to Xosera
; ax: register
; bx: data
xwritew:
	push	fx
	mov	fx,@xwrite

	;
	; Write MSB
	;

	push	ax
	push	bx
	or	ax,#$10
	lsr	bx
	lsr	bx
	lsr	bx
	lsr	bx
	lsr	bx
	lsr	bx
	lsr	bx
	lsr	bx
	jsr	fx
	pop	bx
	pop	ax

	;
	; Write LSB
	;

	jsr	fx

	pop	fx
	rts

; ----------------------------------------------------------------------------------------------------------------------
; Clear screen
; ax: character
; bx: color
; Modified registers: ax, bx, cx, dx, ex, fx
xcls:
	;
	; Set write increment to 0
	;

	push	ax
	push	bx
	push	fx

	mov	ax,#XVID_WRITE_INC
	mov	bx,#0
	mov	fx,@xwrite
	jsr	fx

	pop	fx
	pop	bx
	pop	ax

	push	ex
	push	dx

	mov	ex,@2400 	; ex = Number of characters (80x25)
	mov	dx,@$0000	; dx = Current address

xcls0:
	;
	; Set write address
	;

	push	ax
	push	bx

	mov	ax,#XVID_WRITE_ADDR	; Write address
	mov	bx,dx
	mov	fx,@xwritew
	jsr	fx

	pop	bx
	pop	ax

	;
	; Write color
	;

	push	ax
	push	fx

	mov	ax,#XVID_DATA		; XVID data
	or	ax,#$10
	; bx is already the color
	mov	fx,@xwrite
	jsr	fx

	pop	fx
	pop	ax

	;
	; Write character
	;

	push	cx
	mov	cx,ax			; cx = character

	push	ax
	push	bx
	push	fx

	mov	ax,#XVID_DATA		; XVID data
	mov	bx,cx
	mov	fx,@xwrite
	jsr	fx

	pop	fx
	pop	bx
	pop	ax

	pop	cx

	; Increment and continue

	inc	dx
	dec	ex
	bnz	xcls0

	pop	dx
	pop	ex

	rts


; ----------------------------------------------------------------------------------------------------------------------
; Wait frame
wait_frame:
	push fx
wait_frame0:
	; Wait until in VSYNC
	mov	fx,@VIDEO_FRAME
	mov	fx,[fx]
	and	fx,#1
	bz	wait_frame0
	; Wait until out of VSYNC
wait_frame1:
	mov	fx,@VIDEO_FRAME
	mov	fx,[fx]
	and	fx,#1
	bnz	wait_frame1
	pop	fx
	rts

; ----------------------------------------------------------------------------------------------------------------------
; Delay
; ax: nb frames
delay:
	push	ax
	push	fx

delay0:
	mov	fx,@wait_frame
	jsr	fx
	dec	ax
	bnz	delay0

	pop	fx
	pop	ax
	rts
