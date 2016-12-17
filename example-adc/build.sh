#!/bin/bash

# http://www.clifford.at/icestorm/
# iCE40HX-8K CT256 device

# Part  Package Pin Spacing                               I/Os  arachne-pnr opts  icetime opts
# iCE40-HX8K-CT256  256-ball caBGA (14 x 14 mm) 0.80 mm 206 -d 8k -P ct256  -d hx8k


rm -rf ./build
mkdir ./build

echo ------- yosys
yosys -p 'synth_ice40 -top top -blif ./build/example.blif' example.v | grep -iE 'Warning|Error' || exit

echo ------- arachne-pnr
arachne-pnr -d 8k -P ct256 -o ./build/example.asc -p example.pcf ./build/example.blif 2> /dev/null || exit
# arachne-pnr -d 8k -P ct256 -o ./build/example.asc -p example.pcf ./build/example.blif  || exit


echo ------- icepack
icepack ./build/example.asc ./build/example.bin || exit

echo ------- icetime
icetime ./build/example.asc -d hx8k || exit

echo ------- iceprog
iceprog build/example.bin

