-- bridge.lua ESP8266-bridge
-- bridges TCP connections with the UART on the ESP8266 and adds some features to 
-- toggle GPIO pins so microcontrollers attached to the UART can be reset and put
-- into "programming mode"
-- (c) 2015 Thorsten von Eicken, see LICENSE file

print("-- esp8266-bridge")

-- receive a string from lua interpreter and send to appropriate connection
function lua_out(conn)
  return function(str)
    if conn ~= nil then conn:send(str) end
  end
end

-- receive data from the uart and send to appropriate connection
function uart_input(conn)
  inputFun = function(str) if conn ~= nil then conn:send(str) end end
  uart.on("data", 0, inputFun, 0)
end


-- Actions have a start function, a receive-data function, and a close function
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
    function(conn, name) uart_input(conn) end,
    function(conn, data) uart.write(0, data) end,
    function(conn) end,
  },
  ["^\0"] = {
    "AVR",
    function(conn, name) uart_input(conn) end,
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

-- determine the action based on the string
function findAction(conn, data)
  local m
  local kind, sf, rf, ef = actions[""] -- default
  for patt, v in pairs(actions) do
    kind, sf, rf, ef = unpack(v)
    -- print ("Try "..patt.." with "..kind, sf, rf, ef)
    if patt ~= "" then
      m = string.match(data, patt)
      if m then break end
    end
  end
  if conn and sf then sf(conn, m) end
  return kind, rf, ef
end

ser2net = net.createServer(net.TCP, 300)
ser2net:listen(23, function(conn)
  print("New connection")
  local kind, recvFun, stopFun

  conn:on("disconnection", function(conn) if stopFun then stopFun(conn) end end)

  conn:on("receive", function(conn, data) 
    -- if this is the beginning of the connection, determine the type of connection
    if kind == nil then
      kind, recvFun, stopFun = findAction(conn, data)
    end
    if conn ~= nil and recvFun then recvFun(conn, data) end
  end)

end)

