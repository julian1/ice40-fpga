##!/bin/bash

# see https://github.com/damdoy/ice40_ultraplus_examples/tree/master/leds

set -e

rm -rf ./build
mkdir ./build


# yosys -p 'synth_ice40 -top top -blif ./build/example.blif' example.v
yosys -p "synth_ice40  -top top  -blif ./build/example.blif" example.v

#arachne-pnr -d 1k -o ./build/example.asc -p example.pcf ./build/example.blif
arachne-pnr -d 5k -P sg48 -p example.pcf  ./build/example.blif -o ./build/example.asc

# icepack ./build/example.asc ./build/example.bin
# icepack $(filename).asc $(filename).bin
icepack ./build/example.asc ./build/example.bin

#icetime ./build/example.asc -d hx4k

echo "finished"

# send to device -
# iceprog ./build/example.bin




