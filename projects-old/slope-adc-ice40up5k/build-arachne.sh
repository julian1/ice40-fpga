##!/bin/bash

# see https://github.com/damdoy/ice40_ultraplus_mains/tree/master/leds

#echo DEPRECATED.
#echo use build2 instead.
#exit

set -e

rm -rf ./build
mkdir ./build


# yosys -p 'synth_ice40 -top top -blif ./build/main.blif' main.v
yosys -p "synth_ice40  -top top  -blif ./build/main.blif" main.v

#arachne-pnr -d 1k -o ./build/main.asc -p main.pcf ./build/main.blif
arachne-pnr -d 5k -P sg48 -p main.pcf  ./build/main.blif -o ./build/main.asc

# icepack ./build/main.asc ./build/main.bin
# icepack $(filename).asc $(filename).bin
icepack ./build/main.asc ./build/main.bin

# TODO check
#icetime ./build/main.asc -d hx4k

icetime ./build/main.asc -d up5k


echo "finished"


if [ "$1" = "-flash" ]; then
  # send to device -
  iceprog ./build/main.bin
fi

# if [ "$1" = "-touch" ]; then
#  # read flash id
#  iceprog -t
# fi





