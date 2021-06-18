"""
as01.py

Created by Daniel Cliche on 2012-04-07.
Copyright (c) 2012-2021 Daniel Cliche.
"""

import sys
import os

opcodes = {'NOR':0b00000000, 'ADD':0b01000000, 'STA':0b10000000, 'JCC':0b11000000}
labels = {}

memory = []

def pass1(code):
	lines = code.splitlines()
	addr = 0
	for line in lines:
		sline = line.split(';')[0]
		tokens = sline.split()
		if len(tokens) > 0:
			label = tokens[0]
			if label[-1] == ':':
				labels[label[:-1].upper()] = addr
			addr = addr + 1
			
	print("Labels: " + str(labels))

def pass2(code):
	lines = code.splitlines()
	for line in lines:
		sline = line.split(';')[0]
		tokens = sline.split()
		if len(tokens) == 3:
			label = tokens[0].upper()
			op = tokens[1].upper()
			param = tokens[2].upper()
		elif len(tokens) == 2:
			op = tokens[0].upper()
			param = tokens[1].upper()
		else:
			continue

		print(tokens)

		if op in opcodes:
			data = opcodes[op]
		elif op == "FDB":
			data = 0b00000000
		else:
			print("Invalid opcode " + op)
			return
		
		if param[0] == '$':
			data += int(param[1:], 16)
		else:
			if param in labels:
				data += labels[param]
			else:
				print("Unknown label " + param)
				return
			
		memory.append(data)

def main():
	if (len(sys.argv) > 2):
		
		f = open(sys.argv[1], "r")
		code = f.read()
		f.close()
		
		pass1(code)
		pass2(code)

		fo = open(sys.argv[2], "w")
		str = ""
		for i in memory:
			str += "%02x " % i
		print(str)
		fo.write(str)
		fo.close()
		memory.reverse()
		str = ""
		for i in memory:
			str += "%02x " % i
		print(str)

	else:
		print("Usage: " + sys.argv[0] + " file.asm file.hex")
		
if __name__ == '__main__':
	main()

