



##!/bin/bash

# see https://github.com/damdoy/ice40_ultraplus_mains/tree/master/leds

set -e

rm -rf ./build
mkdir ./build


# yosys -p "synth_ice40  -top top  -blif ./build/main.blif" main.v
# arachne-pnr -d 5k -P sg48 -p main.pcf  ./build/main.blif -o ./build/main.asc

yosys -p "synth_ice40  -top top  -json ./build/main.json" main.v  2>&1 | tee ./build/yosys.txt


nextpnr-ice40 --hx1k  --package  tq144 --pcf  main.pcf --json ./build/main.json  --asc  ./build/main.asc 2>&1 | tee ./build/nextpnr.txt


icepack ./build/main.asc ./build/main.bin

icetime ./build/main.asc -d hx1k 2>&1 | tee ./build/icetime.txt



echo "finished"



