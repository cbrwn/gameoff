@echo off
cd src
NESASM3 main.asm
:: clean up src folder
del *.fns
move *.nes ../
cd ..