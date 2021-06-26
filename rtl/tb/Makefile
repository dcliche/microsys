CPU = $(wildcard ../cpu/*.sv)

build:
	iverilog -g2012 -o computer -Wall -I../cpu \
		$(CPU) \
		cpu/cpu_tb.sv

run: build
	vvp -n computer

clean:
	rm computer

view:
	gtkwave cpu.vcd

.PHONY: build run clean view
