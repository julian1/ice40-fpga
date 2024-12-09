
# nix-shell -p yosys arachne-pnr icestorm usbutils nextpnr -I  nixpkgs=/home/me/devel/nixpkgs02

##!/bin/bash

# see https://github.com/damdoy/ice40_ultraplus_mains/tree/master/leds

set -e

rm -rf ./build
mkdir ./build


# yosys -p "synth_ice40  -top top  -blif ./build/main.blif" top.v
# arachne-pnr -d 5k -P sg48 -p main.pcf  ./build/main.blif -o ./build/main.asc



# https://stackoverflow.com/questions/33380477/yosys-cant-open-include-file
# https://www.reddit.com/r/yosys/comments/277kh0/include_directory_syntax_in_read_verilog_command/
# https://github.com/YosysHQ/yosys/issues/331

yosys -p 'synth_ice40 -top top -json ./build/main.json'  top.v  2>&1 | tee ./build/yosys.txt

# why doesn't this work??
# yosys -p "synth_ice40  -top top  -json ./build/main.json  " top.v  2>&1 | tee ./build/yosys.txt
# yosys -p "synth_ice40 -top top      -json ./build/main.json  -I../../common " top.v  2>&1 | tee ./build/yosys.txt
# yosys -p ' verilog_defaults -add -I../../     synth_ice40 -top top -json ./build/main.json   '  top.v  2>&1 | tee ./build/yosys.txt
# yosys -p "    synth_ice40 -top top -json ./build/main.json  verilog_defaults -add -I../../common  "  top.v  2>&1 | tee ./build/yosys.txt
# yosys -p "    synth_ice40 -top top -json ./build/main.json  read -I../../common  "  top.v  2>&1 | tee ./build/yosys.txt


egrep -i 'warning|error' ./build/yosys.txt  > ./build/yosys-errors.txt


#nextpnr-ice40 --up5k  --package  sg48 --pcf  main.pcf --json ./build/main.json  --asc  ./build/main.asc 2>&1 | tee ./build/nextpnr.txt
nextpnr-ice40 --hx4k   --package  tq144 --pcf  main.pcf --json ./build/main.json  --asc  ./build/main.asc 2>&1 | tee ./build/nextpnr.txt


icepack ./build/main.asc ./build/main.bin

# icetime ./build/main.asc -d up5k  2>&1 | tee ./build/icetime.txt
icetime ./build/main.asc -d hx4k 2>&1 | tee ./build/icetime.txt

cat ./build/yosys-errors.txt

echo "finished"

if [ "$1" = "-flash" ]; then
  iceprog ./build/main.bin
fi


################

# TLV encoding. type-len-val https://en.wikipedia.org/wiki/Type%E2%80%93length%E2%80%93value

# see
# https://stackoverflow.com/questions/9955020/how-to-write-integer-to-binary-file-using-bash
# test
# echo "0xfefefefe" | xxd -r -g0 | hexdump -C
# printf "0: %.8x" 0xffffff00 | sed -E 's/0: (..)(..)(..)(..)/0: \4\3\2\1/' | xxd -r -g0 | hexdump -C
# echo "size $size"

# add crc also
#  rhash --crc32 ./bus

#magic=0xfe00fe00
#size=$( stat -c "%s" ./build/main.bin )
#
#echo $magic             | sed -E 's/0x(..)(..)(..)(..)/0: \4\3\2\1/' | xxd -r -g0 >>   ./build/main.bin.hdr
#
#printf "0: %.8x" $size  | sed -E 's/0: (..)(..)(..)(..)/0: \4\3\2\1/' | xxd -r -g0   >>   ./build/main.bin.hdr
#
#cat ./build/main.bin                  >>   ./build/main.bin.hdr


