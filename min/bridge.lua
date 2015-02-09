-- bridge.lua ESP8266-bridge
print("-- esp8266-bridge")
function lua_out(conn)
return function(str)
if conn ~= nil then conn:send(str) end
end
end
function uart_input(conn)
inputFun = function(str) if conn ~= nil then conn:send(str) end end
uart.on("data", 0, inputFun, 0)
end
function arm_reset()
gpio.write(3, gpio.LOW)
gpio.mode(3, gpio.OUTPUT)
gpio.write(4, gpio.LOW)
gpio.mode(4, gpio.OUTPUT)
tmr.sleep(250*1000)
gpio.write(4, gpio.HIGH)
gpio.mode(4, gpio.PULLUP)
gpio.write(3, gpio.HIGH)
gpio.mode(3, gpio.PULLUP)
tmr.sleep(500*1000)
end
actions = {
["^-- *(%w+%.lua)"] = {
"FILE",
function(conn, name) print("Writing " .. name) file.open(name, "w") end,
function(conn, data) file.write(data) end,
function(conn) print("File close") file.close() end,
},
["^--[\r\n]"] = {
"CONS",
function(conn, name) node.output(lua_out(conn), 0) end,
function(conn, data) node.input(data) end,
function(conn) node.output(nil) end,
},
["^?\r\n"] = {
"ARM",
function(conn, name) uart_input(conn) arm_reset() end,
function(conn, data) uart.write(0, data) end,
function(conn) end,
},
[""] = {
"THRU",
function(conn, name) uart_input(conn) end,
function(conn, data) uart.write(0, data) end,
function(conn) end,
},
}
function findAction(conn, data)
local m
local kind, sf, rf, ef = actions[""]
for patt, v in pairs(actions) do
kind, sf, rf, ef = unpack(v)
if patt ~= "" then
m = string.match(data, patt)
if m then break end
end
end
print(kind)
if conn and sf then sf(conn, m) end
return kind, rf, ef
end
ser2net = net.createServer(net.TCP, 300)
ser2net:listen(23, function(conn)
print("New connection")
local kind, recvFun, stopFun
conn:on("disconnection", function(conn) if stopFun then stopFun(conn) end end)
conn:on("receive", function(conn, data) 
if kind == nil then
kind, recvFun, stopFun = findAction(conn, data)
end
if conn ~= nil and recvFun then recvFun(conn, data) end
end)
end)
