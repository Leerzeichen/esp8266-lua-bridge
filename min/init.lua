-- init.lua
AP_SSID    = "esp8266-bridge"
AP_PWD     = "jeelabs"
CONFIG     = "config.lua"
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
wifiStates = { "idle", "connecting", "wrong_password", "no_AP_found", "connect_fail", "connected" }
function checkWIFI()
local status, ipAddr = wifiStatus()
if status == 5 and ipAddr ~= nil and ipAddr ~= "0.0.0.0" then
print("WIFI " .. wifiStates[status+1] .. " IP=" .. ipAddr)
if ABORT == nil  and CMDFILE ~= nil then
tmr.alarm(1, 5000, 0, launch)
end
else
print("WIFI " .. wifiStates[status+1])
tmr.alarm(0, 1000, 0, checkWIFI)
end
end
tmr.delay(250*1000)
uart.setup(0, 115200, 8, 0, 1, 0)
tmr.delay(250*1000)
print("\n\n-- esp8266-init\nLoading config.lua")
configChunk, err = loadfile("config.lua")
if configChunk == nil then
print(err)
else
configOk = pcall(configChunk)
end
if configOk and STA_SSID ~= nil then
print("WIFI Station on " .. STA_SSID)
wifi.setmode(wifi.STATION)
wifi.sta.config(STA_SSID, STA_PWD)
function wifiStatus() return wifi.sta.status(), wifi.sta.getip() end
else
print("WIFI AP")
wifi.setmode(wifi.STATIONAP)
wifi.ap.config({ssid=AP_SSID, pwd=AP_PWD})
function wifiStatus() return 5, wifi.ap.getip() end
end
tmr.alarm(0, 1000, 0, checkWIFI)
