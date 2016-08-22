
# Minimal ice40, yosys, arachne-pnr, icestorm example for ICEStick

#### verilog

verilog in one day tutorial,

http://www.asic-world.com/verilog/verilog_one_day.html

http://www.asic-world.com/verilog/veritut.html

#### install
```
s apt-get install yosys
s apt-get install arachne-pnr
s apt-get install fpga-icestorm   (already installed)
```

---
#### run
```
./build.sh

```


#### send to the device

```

:~/ice40$ iceprog example.bin
init..
cdone: high
reset..
cdone: low
flash ID: 0x20 0xBA 0x16 0x10 0x00 0x00 0x23 0x50 0x81 0x14 0x24 0x00 0x13 0x00 0x22 0x10 0x04 0x15 0xF1 0xE6
file size: 32220
erase 64kB sector at 0x000000..
programming..
reading..
VERIFY OK
cdone: high
Bye.
....
```

