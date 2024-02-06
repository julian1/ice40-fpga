##!/bin/bash


# nix-shell -p yosys arachne-pnr icestorm usbutils
# nix-shell ~/nixos-config/examples/icestorm.nix

# ./build.sh  2>&1  | grep warning

# trap for failure
set -e

rm -rf ./build
mkdir ./build


yosys -p 'synth_ice40 -top top -blif ./build/main.blif' main.v 

arachne-pnr -d 1k -o ./build/main.asc -p main.pcf ./build/main.blif 


icepack ./build/main.asc ./build/main.bin

icetime ./build/main.asc -d hx1k

#
echo "finished"

# send to device - 
# TODO pass arg?
# iceprog ./build/example.bin


