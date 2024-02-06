#!/bin/bash


rm -rf ./build
mkdir ./build

echo -------
yosys -p 'synth_ice40 -top top -blif ./build/example.blif' example.v | grep -iE 'Warning|Error' || exit

echo -------
arachne-pnr -d 1k -o ./build/example.asc -p example.pcf ./build/example.blif 2> /dev/null || exit


echo -------
icepack ./build/example.asc ./build/example.bin || exit

echo -------
icetime ./build/example.asc -d hx1k || exit


echo -------

# send to device

iceprog build/example.bin

