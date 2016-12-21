

# to connect to bus pirate,
rlwrap ~/reactor/examples/serial.out -d /dev/ttyUSB2 -s 115200 -p 8n1

choose 5 spi, defaults, then 2 for normal output

# do integration
SPI>[ 0xcc ]

# to read 4 bytes...
SPI> [ r:4 ]
/CS ENABLED
READ: 0x00 0x2C 0x56 0xFC

# start integration, wait 200ms, read 4 bytes
SPI> [ 0xcc ] %:200  [ r:4 ]


# issues - the source isn't very accurate
  - ceramic not nco caps.
  - inductance on inputs ...
  - we're using a 1M resistor.... should be ok... input is unbuffered... 
  - bad transistor switching...

  - slow slew rate of op-amp
  - slow slew rate of transistor...?



// need to adjust op-amp so that 0V will still work, triggering positive, then 
// negative cross...

// perhaps should only record what ha


// TODO - should support setting the initial integration period...
// and the initial short time? perhaps...
// - also perhaps fire a signal when we've read a value...
// - also support querying any of the variables...





