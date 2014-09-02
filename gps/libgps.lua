PORT_GPS = 8192

local gps = {}
local vector = require "libvec"
local component = require "component"
local event = require "event"
local term = require "term"

local function trilaterate( A, B, C )
	local a2b = B.vPosition - A.vPosition
	local a2c = C.vPosition - A.vPosition
		
	if math.abs( a2b:normalize():dot( a2c:normalize() ) ) > 0.999 then
		return nil
	end
	
	local d = a2b:length()
	local ex = a2b:normalize( )
	local i = ex:dot( a2c )
	local ey = (a2c - (ex * i)):normalize()
	local j = ey:dot( a2c )
	local ez = ex:cross( ey )

	local r1 = A.nDistance
	local r2 = B.nDistance
	local r3 = C.nDistance
		
	local x = (r1*r1 - r2*r2 + d*d) / (2*d)
	local y = (r1*r1 - r3*r3 - x*x + (x-i)*(x-i) + j*j) / (2*j)
		
	local result = A.vPosition + (ex * x) + (ey * y)

	local zSquared = r1*r1 - x*x - y*y
	if zSquared > 0 then
		local z = math.sqrt( zSquared )
		local result1 = result + (ez * z)
		local result2 = result - (ez * z)
		
		local rounded1, rounded2 = result1:round( 0.01 ), result2:round( 0.01 )
		if rounded1.x ~= rounded2.x or rounded1.y ~= rounded2.y or rounded1.z ~= rounded2.z then
			return rounded1, rounded2
		else
			return rounded1
		end
	end
	return result:round( 0.01 )
end

local function narrow( p1, p2, fix )
	local dist1 = math.abs( (p1 - fix.vPosition):length() - fix.nDistance )
	local dist2 = math.abs( (p2 - fix.vPosition):length() - fix.nDistance )
	
	if math.abs(dist1 - dist2) < 0.01 then
		return p1, p2
	elseif dist1 < dist2 then
		return p1:round( 0.01 )
	else
		return p2:round( 0.01 )
	end
end

function gps.locate( timeout, modem, debug )

	modem = modem or component.modem
	timeout = timeout or 2

	if modem == nil then
		if debug then
			print( "No wireless modem attached" )
		end
		return nil
	end
	
	if debug then
		print( "Finding position..." )
	end
	
	-- Open a port
	local port = math.random(1,PORT_GPS-1)
	local openedPort = false
	if not modem.isOpen( port ) then
		modem.open( port )
		openedPort = true
	end
	
	-- Send a ping to listening GPS hosts
	modem.broadcast( PORT_GPS, "GPS", chan, "PING" )
		
	-- Wait for the responses
	local fixes = {}
	local pos1, pos2 = nil, nil
	while true do
		local e = {event.pull(_nTimeout)}
		if e[1] == "modem_message" then
			-- We received a message from a modem
			local address, from, port, distance, header = table.unpack(e,2,6)
			local message = {table.unpack(e,7,#e)}
			if address == modem.address and port == port and header == "GPS" then
				-- Received the correct message from the correct modem: use it to determine position
				if #message == 3 then
					local fix = { position = vector.new( tMessage[1], tMessage[2], tMessage[3] ), distance = distance }
					if debug then
						print( fix.distance.." meters from "..tostring( fix.position ) )
					end
					if fix.distance == 0 then
					    pos1, pos2 = fix.position, nil
					else
                        table.insert( fixes, fix )
                        if #tFixes >= 3 then
                            if not pos1 then
                                pos1, pos2 = trilaterate( fixes[1], fixes[2], fixes[#fixes] )
                            else
                                pos1, pos2 = narrow( pos1, pos2, fixes[#fixes] )
                            end
                        end
                    end
					if pos1 and not pos2 then
						break
					end
				end
			end
		elseif e[1] == nil then
			break
		end 
	end
	
	-- Close the port, if we opened one
	if openedPort then
		modem.close( chan )
	end
	
	-- Return the response
	if pos1 and pos2 then
		if debug then
			print( "Ambiguous position" )
			print( "Could be "..pos1.x..","..pos1.y..","..pos1.z.." or "..pos2.x..","..pos2.y..","..pos2.z )
		end
		return nil
	elseif pos1 then
		if debug then
			print( "Position is "..pos1.x..","..pos1.y..","..pos1.z )
		end
		return pos1.x, pos1.y, pos1.z
	else
		if debug then
			print( "Could not determine position" )
		end
		return nil
	end
end

function gps.host(x,y,z,modem)
	-- Find a modem
	modem = modem or component.modem

	if modem == nil then
		print( "No wireless modems found. One required." )
		return
	end
	
	-- Open a channel
    print( "Opening port on modem "..modem.address )
	local openedChannel = false
	if not modem.isOpen(PORT_GPS) then
		modem.open( PORT_GPS )
		openedChannel = true
	end

	-- Determine position
	if not x then
		-- Position is to be determined using locate		
		x,y,z = gps.locate( 2, true )
		if not x then
			print( "Could not locate, set position manually" )
			if openedChannel then
				print( "Closing GPS port" )
				modem.close( PORT_GPS )
			end
			return
		end
	end
	
	-- Serve requests indefinately
	local nServed = 0
	while true do
		local e = {event.pull(_nTimeout)}
		if e[1] == "modem_message" then
			-- We received a message from a modem
			local address, from, port, distance, header = table.unpack(e,2,6)
			local message = {table.unpack(e,7,#e)}
			if address == modem.address and port == PORT_GPS and header == "GPS" and message[2] == "PING" then
				-- We received a ping message on the GPS channel, send a response
				local reply = message[1]
				modem.send( from, reply, "GPS", x, y, z )
			
				-- Print the number of requests handled
				nServed = nServed + 1
				if nServed > 1 then
					local x,y = term.getCursorPosition()
					term.setCursorPosition(1,y-1)
				end
				print( nServed.." GPS requests served" )
			end
		end
	end
	
	print( "Closing channel" )
	modem.close( PORT_GPS )
end

return gps
