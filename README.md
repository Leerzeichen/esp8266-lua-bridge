esp8266-bridge
==============

ESP8266 software to allow programming and debugging of arduino, JeeNodes, and ARM nodes over wifi.
The idea is to replace the standard FTDI connection, which often requires some "fun" serial
mumbo-jumbo or USB pain by a tiny ESP8266 board which "extends" the serial port over wifi
so it can be accessed from whatever computer is convenient.

There are really two main use-cases this projects targets:
- plug a JeeNode into the esp8266-bridge and start programming it without having serial cables
  floating around on your desk (you still need a power cable for the thing), and you don't have
  to wrangle with controlling RTS&DTR (more of a pain with ARM than with AVRs)
- plug the esp8266-bridge into a JeeNode out in the field in order to reprogram it or simply in
  order to get debugging output via the serial port

Overview
--------

In order to get there, these are the steps you'll have to go through:
- power-up your ESP8266
- connect your ESP8266 to your Mac or Windows box to reflash it with a lua firmware
- tweak some params in this repo to match your local wifi
- load the lua firmware available in this repo
- disconnect the ESP8266 and connect it to a JeeNode (or other 3.3v arduino)
- telnet to the EPS8266 and get connected through to the JeeNode for reprogramming or debugging

Getting started
---------------

There are many tutorials around on how to get started with your ESP8266 which depend slightly on the
model you have. Be sure to tie CH_PD high and to provide enough power (200-300mA) at 3.3v.
I used a modified USB BUB II by adding an MCP1702 LDO. I would start by applying power and tieing
CH_PD high and then seeing it start its built-in access point on my phone (e.g. using Wifi Analyzer
on Android).

Once you see the AP you can hook up RX/TX and a jumper for GPIO_0 plus a reset button. Note that
for the USB BUB II I had to solder a 1K ohm resistor across R5, which is 10K and too high to
actually drive RX on the ESP, ouch. Use a terminal program to see the ESP say "hello" when reset,
mine ran at 115200bps, others run at 9600bps. Note that if you te GPIO_0 to ground for reflashing
the serial runs at 77400 bps.

Now use one the of reflashing programs (e.g. http://benlo.com/esp8266/index.html#LuaLoader)
to flash NODEmcu lua from https://github.com/nodemcu/nodemcu-firmware/tree/master/pre_build/latest

Remove the reflashing jumper from GPIO_0 and reset the ESP, you should see it start lua. You can
now upload the files from this repo to install the esp8266-bridge software.

(to be continued...)

TCP Version
-----------

The first version of the esp8266-bridge uses simple TCP connections and dispatches to multiple
functions based on the first few characters sent over the TCP connection. Clients connect to
port 23 and the first few characters are interpreted as follows:
- "--\n" (lua comment string followed by newline) causes the connection to be connected to the lua
  interpreter allowing any lua commands to be entered
- "-- filename.lua" causes everything received to be written into the file with the given name
  on the ESP8266, this is used to update the esp8266-bridge app over wifi by putting a comment with the
  filename at the start of each file and then "net-catting" the file to the ESP (use something like
  "nc 192.168.1.1 23 < bridge.lua" on linux)
- "\0" (NULL character) causes GPIO_0 and GPIO_2 to be pulsed low to reset an ARM then passes all characters
  transparently between the connetion and the uart (assumes GPIO_2 is connected to the ARM's reset input and
  GPIO_0 to its ROM boot selector pin)
- "0" causes GPIO_2 to be pulsed low to reset an AVR (Arduino) then passes all characters
  transparently between the connection and the uart (assumes GPIO_2 is connectoed to the AVR's reset input)
- anything else causes a transparent pass-through between the connection and the uart
