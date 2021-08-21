##!/bin/bash

set -e

rm -rf ./build
mkdir ./build


# yosys -p 'synth_ice40 -top top -blif ./build/example.blif' example.v
yosys -p "synth_ice40 -blif $(filename).blif" $(filename).v

#arachne-pnr -d 1k -o ./build/example.asc -p example.pcf ./build/example.blif
arachne-pnr -d 5k -P sg48 -p $(pcf_file) $(filename).blif -o $(filename).asc

# icepack ./build/example.asc ./build/example.bin
icepack $(filename).asc $(filename).bin

#icetime ./build/example.asc -d hx4k

echo "finished"

# send to device -
iceprog ./build/example.bin




