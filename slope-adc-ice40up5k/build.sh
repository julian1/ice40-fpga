

##!/bin/bash

# see https://github.com/damdoy/ice40_ultraplus_mains/tree/master/leds

set -e

rm -rf ./build
mkdir ./build


# yosys -p "synth_ice40  -top top  -blif ./build/main.blif" main.v
# arachne-pnr -d 5k -P sg48 -p main.pcf  ./build/main.blif -o ./build/main.asc

yosys -p "synth_ice40  -top top  -json ./build/main.json" main.v 
nextpnr-ice40 --up5k  --package  sg48 --pcf  main.pcf --json ./build/main.json  --asc  ./build/main.asc


icepack ./build/main.asc ./build/main.bin

# TODO check
#icetime ./build/main.asc -d hx4k

icetime ./build/main.asc -d up5k


echo "finished"



