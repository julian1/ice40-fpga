##!/bin/bash

# nix-shell -p yosys arachne-pnr icestorm usbutils

# should add a trap for failure
set -e

rm -rf ./build
mkdir ./build


yosys -p 'synth_ice40 -top top -blif ./build/example.blif' example.v

arachne-pnr -d 1k -o ./build/example.asc -p example.pcf ./build/example.blif


icepack ./build/example.asc ./build/example.bin

icetime ./build/example.asc -d hx1k

#
echo "finished"

# send to device
# iceprog ./build/example.bin


