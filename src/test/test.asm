;
; Test
;
start:	NOR	allone
		ADD	value
count:	NOR	zero
		ADD	one
		NOR	zero
		STA	result
		STA	$20			; Write to LED
		JCC	count
		JCC	count
one:	FDB	$01
allone:	FDB	$FF
zero:	FDB	$00
value:	FDB	$20
result:	FDB	$00
