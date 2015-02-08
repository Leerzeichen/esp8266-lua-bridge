-- Constants
SSID    = "tve-home"
APPWD   = "tve@home"
CMDFILE = "ser2net.lua" -- File that is executed after connection
PORT    = 80

-- Launch application
function launch()
  print("Launching " .. CMDFILE)
  dofile(CMDFILE)
end

-- Check whether we're connected and once we are launch the actual app
function checkWIFI()
  status = wifi.sta.status()
  ipAddr = wifi.sta.getip()
  if status == 5 and ipAddr ~= nil and ipAddr ~= "0.0.0.0" then
    -- lauch() -- Cannot call the function directly from here, NodeMcu crashes...
    print("Connected to WIFI!")
    print("IP Address: " .. ipAddr)
    if ABORT == nil then
      tmr.alarm(1, 5000, 0, launch)
    end
  else
    -- Reset alarm again
    print("Waiting on WIFI, status=" .. status)
    tmr.alarm(0, 1000, 0, checkWIFI)
  end
end

uart.setup(0, 115200, 8, 0, 1, 0)
tmr.delay(100*1000)
print("--")
print("--")
tmr.delay(100*1000)
print("-- Starting up! loading LLbin")
dofile("LLbin.lua")

print("Connecting to " .. SSID)
-- Lets see if we are already connected by getting the IP
status = wifi.sta.status()
ipAddr = wifi.sta.getip()
if status == 5 and ipAddr ~= nil and ipAddr ~= "0.0.0.0" then
  print("Already connected as " .. ipAddr)
  tmr.alarm(1, 5000, 0, launch)
else
  -- We aren't connected, so let's connect
  print("Configuring WIFI....")
  wifi.setmode(wifi.STATION)
  wifi.sta.config(SSID, APPWD)
  tmr.alarm(0, 1000, 0, checkWIFI)
end
-- Drop through here to let NodeMcu run

