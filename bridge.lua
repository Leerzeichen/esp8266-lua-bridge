-- bridge.lua ESP8266-bridge
-- bridges TCP connections with the UART on the ESP8266 and adds some features to 
-- toggle GPIO pins so microcontrollers attached to the UART can be reset and put
-- into "programming mode", assumes: GPIO-0 = RTS = ARM-ROM-boot, GPIO-2 = DTR = RESET
-- (c) 2015 Thorsten von Eicken, see LICENSE file

print("-- esp8266-bridge")

-- ensure gpio's are in pull-up state
gpio.mode(4, gpio.PULLUP) -- GPIO-2=reset=DTR
gpio.mode(3, gpio.PULLUP) -- GPIO-0=wakeup=RTS

-- toggle reset while holding wakeup low
-- the timing here isn't particularly scientific...
function start_reset()
  gpio.write(3, gpio.LOW)
  gpio.mode(3, gpio.OUTPUT)
  gpio.write(4, gpio.LOW)
  gpio.mode(4, gpio.OUTPUT)
end

function stop_reset()
  gpio.write(4, gpio.HIGH)
  gpio.mode(4, gpio.PULLUP)
  gpio.write(3, gpio.HIGH)
  gpio.mode(3, gpio.PULLUP)
end

-- connection modes
CONS = 1        -- Lua console
FILE = 2        -- upload file
ARM  = 3        -- program ARM (LPC8xx)
AVR  = 4        -- program AVR (Arduino optiboot)
THRU = 5        -- pass-through to uart

modes = {
  "^--[\r\n]",          -- CONS
  "^-- *(%w+%.lua)",    -- FILE
  "^?\r\n",             -- ARM
  "^0",                 -- AVR
}

-- determine the connection mode from the first few bytes
-- returns the mode and the string match
function find_mode(data)
  for i = 1, #modes do
    local m = string.match(data, modes[i])
    if m then return i, m end
  end
  return THRU, ""
end

consConn = nil -- current connection that lua console output goes to
uartConn = nil -- current connection that uart input goes to
connCnt = 0

consBuf = ""
-- buffer a little bit of console output for debugging, can't send it to UART
-- 'cause that interferes with programming
function consoleSink(data)
  if #data > 256 then
    consBuf = string.sub(data, -300) -- keep last 300 bytes
  elseif #consBuf + #data > 300 then
    consBuf = string.sub(consBuf, -(300-#data)) .. data
  else
    consBuf = consBuf .. data
  end
end

node.output(consoleSink, 0)
uart.on("data", 0, function(data) end, 0)

ser2net = net.createServer(net.TCP, 300)
ser2net:listen(23, function(conn)
  connCnt = connCnt + 1
  local id = connCnt
  print("#"..connCnt.." connect h:"..node.heap())
  local mode

  local buf = "" -- send buffer
  local sendLock -- true when we can't send

  -- send data on the connection
  function sender(data)
    if conn == nil then return end
    if sendLock then
      -- send is pending, can't send more, add to buffer, hope it doesn't fill memory
      if #buf < 1000 then buf = buf .. data end
    else
      -- we can send, doing and lock, but avoid race conditions with conn:on("sent", ...)
      sendLock = true
      conn:send(buf .. data)
      buf = ""
    end
  end

  -- done sending, send anything that has accumulated, else clear send lock
  conn:on("sent", function(conn)
    if #buf > 0 then
      conn:send(buf)
      buf = ""
    else
      sendLock = false
    end
  end)

  -- oops, we're dead
  conn:on("disconnection", function(conn)
    if mode == CONS and consConn == conn then
      consConn = nil
      node.output(consoleSink, 0) -- lua console back to sink
    elseif mode == FILE then
      print("File close")
      file.close()
    end
    print("#"..id.." closed")
  end)

  conn:on("receive", function(conn, data) 
    if mode == nil then
      -- beginning of the connection, determine the type of connection
      local match
      mode, match = find_mode(data)
      if mode == CONS then
        if consConn then consConn:close() end
        consConn = conn
        if #consBuf > 0 then
          sender(consBuf)
          consBuf = ""
        end
        node.output(sender, 0)
      elseif mode == FILE then
        print("Writing " .. match)
        file.open(match, "w")
      else
        if uartConn then uartConn:close() end
        uartConn = conn
        uart.on("data", 0, sender, 0)
        --uart.on("data", "\n", sender, 0) -- ok for ARM, not ok for AVR
        if mode == ARM  or mode == AVR then
  	  start_reset()
	  tmr.delay(1*1000)
          stop_reset()
	  return
        end
      end
      print("#"..id.."="..mode)
    end

    if mode == CONS then
      node.input(data)
    elseif mode == FILE then
      file.write(data)
    else
      -- uart.write(0, "[".. #data ..",".. data:byte(-2,-1) ..",".. data:byte(-1) .."]")
      uart.write(0, data)
    end

  end)

end)
