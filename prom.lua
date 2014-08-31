local args = {...}

if args[1] == "help" or not args[1] then
	print("prom - A tool to help flash OpenGX Glasses")
	print("Usage:")
	print("prom flash [code] ([data]) - flash the primary prom device, with optional trailing data")
end

if args[1] == "flash" then
	local fs = require "filesystem"
	local component = require "component"
	local code,data = ""
	
	do
		local fh = fs.open(args[2],"r")
		local s = fh:read(2048)
		while s do
			code = code..s
			s = fh:read(2048)
		end
	end
	
	if args[3] then
		data = ""
		local fh = fs.open(args[3],"rb")
		local s = fh:read(2048)
		while s do
			data = data..s
			s = fh:read(2048)
		end
	end
	
	component.prom.set(code..(data and "\0"..data or ""))
end
