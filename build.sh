#!/bin/sh
set +xe
nasm -f elf32 -o stas.o stas.asm
ld -m elf_i386 -o stas stas.o
