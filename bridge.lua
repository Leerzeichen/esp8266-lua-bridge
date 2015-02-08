-- bridge.lua ESP8266-bridge
-- bridges TCP connections with the UART on the ESP8266 and adds some features to 
-- toggle GPIO pins so microcontrollers attached to the UART can be reset and put
-- into "programming mode"
-- (c) 2015 Thorsten von Eicken, see LICENSE file

print("=== esp8266-bridge ===")

activeConsole = nil
activePass = nil
connCnt = 1

ser2net = net.createServer(net.TCP, 60)
ser2net:listen(2000, function(conn)
  local id, kind
  id, connCnt = connCnt, connCnt+1

  print("New ser2net connection #" .. id)

  conn:on("disconnection", function(conn)
    if kind == 'UP' then
      file.close()
    elseif kind == 'CON' then
      node.output(nil)
      if activeConsole == conn then activeConsole = nil end
    elseif kind == 'PASS' then
      if activePass == conn then activePass = nil end
    end
  end)

  function lua_out(str)
    if conn ~= nil then
      conn:send(str)
    end
  end

  conn:on("receive", function(conn, data) 
    -- if this is the beginning of the connection, determine the type of connection
    if kind == nil then
      print("Got " .. string.sub(data, 1, 2))
      if string.sub(data, 1, 2) == '--' then
        -- file upload
  kind = 'UP'
  file.open("ser2net.lua", "w")
      elseif string.sub(data, 1, 1) == "@" then
  -- console
  kind = 'CON'
        node.output(lua_out, 0)
  if activeConsole ~= nil then
    activeConsole:close()
        end
        activeConsole = conn
      else
  -- pass-through to uart
  kind = 'PASS'
  if activePass ~= nil then
    activePass:close()
  end
  activePass = conn
      end
      print("Connection #" .. id .. " is " .. kind)
    end

    if kind == "PASS" then
      uart.write(0, data)
    elseif kind == 'CON' then
      node.input(data)
    elseif kind == 'UP' then
      file.write(data)
    end
  end)

  function uart_input(data)
    if conn ~= nil then
      conn:send(data)
    end
  end
  uart.on("data", 0, uart_input, 0)

end)

