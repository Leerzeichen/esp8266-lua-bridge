-- init.lua
-- esp8266-bridge init file - sets-up WIFI and attempts to provide a robust environment to
-- run the actual bridge application with reasonable fallbacks
-- This could easily be adapted to other apps

-- Functionality:
--   If config.lua does not exist, sets up an AP and runs normal operation
--   If config.lua exists, connects to an AP and runs normal operation
--   Supports file uploads, in particular of config.lua to change the config and of bridge.lua to
--     update the bridging app
--   Supports connecting to the lua interpreter via TCP (telnet)
--   Supports connections by avrdude to upload an arduino sketch to an AVR
--   Supports connections by lpc8xx to upload an ARM program
--   Supports plain telnet connections to communicate with the UART

-- Constants
AP_SSID    = "esp8266-bridge"
AP_PWD     = "jeelabs"
CONFIG     = "config.lua"

-- Launch application
function launch()
  print("Loading "..CMDFILE .. " heap:"..node.heap())
  local chunk, err = loadfile(CMDFILE)
  if chunk == nil then
    print(err)
  else
    pcall(chunk)
    print("Heap: ", node.heap())
  end
end

-- wifi.sta.status() retun values offset by 1 (status=0=idle)
wifiStates = { "idle", "connecting", "wrong_password", "no_AP_found", "connect_fail", "connected" }

-- Check whether we're connected and once we are launch the actual app
function checkWIFI()
  local status, ipAddr = wifiStatus()
  if status == 5 and ipAddr ~= nil and ipAddr ~= "0.0.0.0" then
    -- lauch() -- Cannot call the function directly from here, NodeMcu crashes...
    print("WIFI " .. wifiStates[status+1] .. " IP=" .. ipAddr)
    if ABORT == nil  and CMDFILE ~= nil then
      tmr.alarm(1, 5000, 0, launch)
    end
  else
    -- Reset alarm again
    print("WIFI " .. wifiStates[status+1])
    tmr.alarm(0, 1000, 0, checkWIFI)
  end
end

-- Main init code

tmr.delay(250*1000) -- give Lua time to print "Hard Restart..." line
uart.setup(0, 115200, 8, 0, 1, 0)
tmr.delay(250*1000)

-- Load config.lua
print("\n\n-- esp8266-init\nLoading config.lua")
configChunk, err = loadfile("config.lua")
if configChunk == nil then
  print(err)
else
  configOk = pcall(configChunk)
end

-- If we have a valid config and it defines an SSID then start STA mode, else start AP mode
if configOk and STA_SSID ~= nil then
  print("WIFI Station on " .. STA_SSID)
  wifi.setmode(wifi.STATION)
  -- wifi.sleeptype(wifi.LIGHT_SLEEP) -- powers down between beacons
  wifi.sta.config(STA_SSID, STA_PWD)
  function wifiStatus() return wifi.sta.status(), wifi.sta.getip() end
else
  print("WIFI AP")
  wifi.setmode(wifi.STATIONAP)
  wifi.ap.config({ssid=AP_SSID, pwd=AP_PWD})
  function wifiStatus() return 5, wifi.ap.getip() end
end

-- Launch the periodic connection check, which will kick off the app
if wifiStatus then tmr.alarm(0, 1000, 0, checkWIFI) end

-- Drop through here to let NodeMcu run
