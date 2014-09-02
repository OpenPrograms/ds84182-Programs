local address, port, codef, dataf = ...
port = tonumber(port)

local fs = require "filesystem"
local component = require "component"
local code,data = ""

do
	codef = require "shell".resolve(codef)
	local fh = fs.open(codef,"r")
	local s = fh:read(2048)
	while s do
		code = code..s
		s = fh:read(2048)
	end
end

if dataf then
	data = ""
	local fh = fs.open(dataf,"rb")
	local s = fh:read(2048)
	while s do
		data = data..s
		s = fh:read(2048)
	end
end

local flashdata = code..(data and "\0"..data or "")

local modem = component.modem
modem.send(address,port,"flash")
os.sleep(0.25)
modem.send(address,port,"size",#flashdata)
os.sleep(0.25)
local idx = 1
while idx<=#flashdata do
	local block = flashdata:sub(idx,idx+64)
	modem.send(address,port,"data",block)
	idx = idx+#block
	os.sleep(0.05)
end
