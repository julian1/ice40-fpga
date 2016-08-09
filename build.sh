#!/bin/bash


rm -rf ./build
mkdir ./build

yosys -p 'synth_ice40 -top top -blif ./build/example.blif' example.v || exit

arachne-pnr -d 1k -o ./build/example.asc -p example.pcf ./build/example.blif || exit


icepack ./build/example.asc ./build/example.bin || exit


# think it will be just this... to send to the device
# iceprog ./build/example.bin


