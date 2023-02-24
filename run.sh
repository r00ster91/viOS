#!/bin/sh

nasm -f bin -o viOS.img main.s -Ox -werror=all &&
qemu-system-x86_64 -drive file=viOS.img,format=raw
