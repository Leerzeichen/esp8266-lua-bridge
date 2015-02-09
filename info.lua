-- info.lua

majorVer, minorVer, devVer, chipid, flashid, flashsize, flashmode, flashspeed = node.info();
print("NodeMCU "..majorVer.."."..minorVer.."."..devVer)
print("ChipIP "..chipid .. ", Flash id=" .. flashid.." sz="..flashsize.."KB mode="..flashmode.." spd="..flashspeed)
--print("Vdd " .. node.readvdd33())
print("Files:")
local k, v
for k, v in pairs(file.list()) do
  print(string.format("%-15s", k) .. "   " .. v .. " bytes")
end
print("Heap " .. node.heap() .. " bytes")
