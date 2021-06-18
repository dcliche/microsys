"""
as01.py

Created by Daniel Cliche on 2012-04-07.
Copyright (c) 2012 Meldora Inc. All rights reserved.
"""

import sys
import os
import pygame as pg



memory = []

def read(addr):
	if addr >= 0b100000:
		print("LED READ")
		return 0
	else:
		return memory[addr]
	
def write(addr, data):
	if addr >= 0b100000:
		print("LED WRITE: %02x" % data)
	else:
		memory[addr] = data

def getch():
	# get input
	while True:
		for event in pg.event.get():
			if event.type == pg.KEYDOWN:
				return event.key

def execute():
	accu = 0
	pc = 0
	carry = 0
	
	while 1:
		data = read(pc)
		opcode = data & 0xc0
		opaddr = data & 0x3f
		if opcode == 0b00000000: # NOR
			print("%02x NOR $%02x" % (pc, opaddr))
			accu = ~(accu | read(opaddr)) & 0xff
			pc = pc + 1
		elif opcode == 0b01000000: # ADD
			print("%02x ADD $%02x" % (pc, opaddr))
			accu = (accu + read(opaddr))
			if (accu & 0x100):
				carry = 1
			else:
				carry = 0
			accu &= 0xff
			pc = pc + 1
		elif opcode == 0b10000000: # STA
			print("%02x STA $%02x" % (pc, opaddr))
			write(opaddr, accu)
			pc = pc + 1
		elif opcode == 0b11000000: # JCC
			print("%02x JCC $%02x" % (pc, opaddr))
			if carry == 0:
				pc = opaddr
			else:
				pc = pc + 1
			carry = 0
		else:
			print("Unknown opcode")
			return
		
		print("Opcode: %02x, pc: %02x, accu: %02x, carry: %d" % (data, pc, accu, carry))
		while True:
			key = getch()
			if key == "q":
				return
			elif key == "m":
				print(str(memory))
			else:
				break
			

def main():
	if (len(sys.argv) > 1):
		
		f = open(sys.argv[1], "r")
		
		while True:
			hexbyte = f.read(2)
			if hexbyte == "":
				break
			memory.append(int(hexbyte, 16))

		pg.init()
		game_display = pg.display.set_mode((800, 600))
		pg.display.set_caption('Sim01')

		execute()
		f.close()
	else:
		print("Usage: " + sys.argv[0] + " file.hex")



if __name__ == '__main__':
	main()

