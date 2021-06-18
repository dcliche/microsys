;
; Dijkstras algorithm to calculate the greatest common divisor of two numbers
;
;	ORG	$100
;
;zero	FDB	$00
;allone	FDB	$FF
;one	FDB	$01
;
;a	FDB	$00
;b	FDB	$00
;
;start:
;	NOR	allone	; accu = 0
;	NOR	b
;	ADD	one	; accu = -b
;
;	ADD	a	; accu = a - b
;			; carry set when accu >= 0
;
;	JCC	neg
;
;	STA	a
;
;	ADD	allone
;	JCC	end	; a = 0 ? => end
;
;	JCC	start
;neg:
;	NOR	zero
;	ADD	one	; accu = -accu
;
;	STA	b
;	JCC	start	; carry was not altered
;end:
;	JCC	end
;
