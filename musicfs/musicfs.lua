--musicfs: musical storage filesystem for tapes--

-- copypasta
function split(str, pat)
	local t = {}  -- NOTE: use {n = 0} in Lua-5.0
	local fpat = "(.-)" .. pat
	local last_end = 1
	local s, e, cap = str:find (fpat, 1)
	while s do
		if s ~= 1 or cap ~= "" then
	 table.insert(t,cap)
		end
		last_end = e+1
		s, e, cap = str:find(fpat, last_end)
	end
	if last_end <= #str then
		cap = str:sub(last_end)
		table.insert(t, cap)
	end
	return t
end

local musicfs = dofile("/usr/lib/libmusicfs.lua")
local component = require "component"
local term = require "term"

local openfs

local function getTapeDrive(addr)
	return addr and component.proxy(component.get(addr)) or component.tape_drive
end

local commands = {}

function commands.format(addr)
	musicfs.format(getTapeDrive(addr))
end

function commands.open(addr)
	openfs = musicfs.open(getTapeDrive(addr))
end

function commands.play(song)
	if song == nil then openfs.playSong() return end --unpause logic
	song = tonumber(song) or song
	if type(song) == "string" then
		--find a string that contains "song"
		for i, s in openfs.listSongs() do
			if s.name:find(song) then
				song = i
				break
			end
		end
	end
	openfs.playSong(song)
end

function commands.stop()
	openfs.stopSong()
end

function commands.pause()
	openfs.pauseSong()
end

function commands.getStatus()
	if not openfs then
		print("Status: No FS opened")
		return
	end
	if not openfs.isPlaying() then
		print("Status: Not playing")
	else
		local index = openfs.isPlaying()
		local song = openfs.getSong(index)
		local curp, finp = openfs.getCurrentPosition()
		print("Status: Playing "..song.name.." ("..index..") "..curp.."/"..finp)
	end
end

function commands.add(title,speed,file)
	speed = tonumber(speed)
	openfs.addSong(title,speed,(require "filesystem").open(file,"r"))
end

function commands.remove(song)
	if song == nil then openfs.playSong() return end --unpause logic
	song = tonumber(song) or song
	if type(song) == "string" then
		--find a string that contains "song"
		for i, s in openfs.listSongs() do
			if s.name:find(song) then
				song = i
				break
			end
		end
	end
	openfs.removeSong(song)
end

function commands.exit()
	error()
end

(require "event").timer(0.5,function()
	if openfs then
		openfs.update()
	end
end,math.huge)

print("MusicFS CLI")
while true do
	io.write("> ")
	local incmd = term.read()
	if not incmd then break end
	incmd = incmd:sub(1,-2)
	local args = split(incmd," ")
	local cmd = table.remove(args,1)
	if commands[cmd] then
		commands[cmd](table.unpack(args))
	elseif cmd then
		print("Unknown command: "..cmd)
	end
end
