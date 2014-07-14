local musicfs = {}
local computer = require "computer"

--[[
	MUSIC FS SPECS
	
	song structure:
	64 bytes - song title
	4 bytes - song length (in bytes)
	2 bytes - song speed (in hertz)
	n bytes - song data
	
	fs structure:
	1 byte - number of songs on disk
	n songs - all the songs on the disk
]]--

local function tou4(n)
	return string.char(bit32.band(n,255),bit32.band(bit32.rshift(n,8),255),bit32.band(bit32.rshift(n,16),255),bit32.band(bit32.rshift(n,24),255))
end

local function tou2(n)
	return string.char(bit32.band(n,255),bit32.band(bit32.rshift(n,8),255))
end

local function fromu4(s)
	return s:byte(1)+bit32.lshift(s:byte(2),8)+bit32.lshift(s:byte(3),16)+bit32.lshift(s:byte(4),24)
end

local function fromu2(s)
	return s:byte(1)+bit32.lshift(s:byte(2),8)
end

local function stripnull(s)
	return s:gsub("\0","")
end

function musicfs.format(td)
	td.seek(-math.huge)
	td.write("\0") -- indicate that there are 0 songs on the tape
end

function musicfs.open(td)
	td.stop()
	print("Opening tape "..td.address.." for musicfs")
	td.seek(-math.huge)
	local mfs = {}
	
	local playingSongIndex
	local playingSongCurrent
	local playingSongStartTime
	
	local paused = false
	local pausePointer
	local pauseTime
	
	local onSongFinish
	
	local songs = {}
	--read songs from disk
	local nsongs = td.read(1):byte()
	print("nSongs: "..nsongs)
	local ptr = 1
	for i=1, nsongs do
		local song = {}
		song.name = stripnull(td.read(64))
		song.length = fromu4(td.read(4))
		song.speed = (fromu2(td.read(2))+1)/32768
		song.lis = song.length/(song.speed*4096) --length in seconds
		song.ptr = ptr
		td.seek(song.length)
		songs[i] = song
		ptr = ptr+64+4+2+song.length
		song.next = ptr
		print("Song "..i..": "..song.name.." "..song.length.." "..song.speed.." "..song.ptr)
	end
	
	function mfs.addSong(title,speed,buffer)
		td.stop()
		local length = buffer:seek("end",0)
		print("buffer length "..length)
		buffer:seek("set",0)
		--get eost (end of song table)
		local eost = 1
		if songs[nsongs] then
			eost = songs[nsongs].next
		end
		print("eost "..eost)
		--pad song title
		if #title>64 then
			title = title:sub(1,64)
		elseif #title<64 then
			title = title..string.rep("\0",64-#title)
		end
		td.seek(-math.huge)
		td.seek(eost)
		print("writing title")
		td.write(title)
		print("writing length")
		td.write(tou4(length))
		print("writing speed")
		td.write(tou2((speed*32768)-1))
		print("writing data")
		local b = buffer:read(8192)
		while b do
			td.write(b)
			b = buffer:read(8192)
		end
		nsongs = nsongs+1
		print("adding to song table")
		td.seek(-math.huge)
		td.write(string.char(nsongs))
		songs[nsongs] = {name=title,length=length,speed=speed,ptr=eost,next=eost+64+4+2+length,lis = length/(speed*4096)}
		buffer:close()
	end
	
	function mfs.removeSong(index)
		td.stop()
		if index ~= nsong then
			print("we have songs to move")
			print("shittytapedmav1")
			--we get the number of affected songs
			--we get the size of all those songs+their headers
			--then we get how much we want to move them by
			--and then we move them
			local srcsong = songs[index]
			local src = srcsong.ptr+64+4+2+srcsong.length
			local srcsize = 0
			for i=index, nsongs do
				srcsize = srcsize+64+4+2+songs[i].length
			end
			local dest = srcsong.ptr
			local srcdestdifference = src-dest --the number of bytes to move stuff by
			--now we do a sloppy data move, 8192 bytes per thing
			local srcdp = src
			local destdp = dest
			--say if src was 0 and dest was 100
			--srcdestdifference = 100
			while srcdp < src+srcsize do --this might fucking break
				print(srcdp,"<",src+srcsize)
				td.seek(-math.huge)
				td.seek(srcdp) --seek to 0
				local rd = td.read(8192) --we are now at 8192
				td.seek(-math.huge)
				td.seek(destdp) --seek back to src and add 100 to get in position for dest, go back to 0, then to 100
				td.write(rd) --we are now at 8292
				srcdp = srcdp+#rd
				destdp = destdp+#rd
			end
			for i=index, nsongs do
				--for all the songs update their pointer to -srcdestdifference
				songs[i].ptr = songs[i].ptr-srcdestdifference
				songs[i].next = songs[i].next-srcdestdifference
			end
		end
		table.remove(songs,index)
		nsongs = nsongs-1
		td.seek(-math.huge)
		td.write(string.char(nsongs))
	end
	
	function mfs.listSongs()
		return ipairs(songs)
	end
	
	function mfs.getNumberOfSongs()
		return nsongs
	end
	
	function mfs.playSong(index)
		if paused and index == nil then paused = false td.seek(-math.huge) td.seek(pausePointer) td.play() return end
		paused = false
		td.seek(-math.huge)
		td.seek(songs[index].ptr+64+4+2)
		td.setSpeed(songs[index].speed)
		td.play()
		playingSongIndex = index
		playingSongCurrent = 0
		playingSongStartTime = computer.uptime()
	end
	
	function mfs.stopSong()
		paused = false
		td.stop()
		playingSongIndex = nil
		playingSongCurrent = nil
		playingSongStartTime = nil
	end
	
	function mfs.pauseSong()
		td.stop()
		paused = true
		pausePointer = mfs.getTapePtr()
		pauseTime = computer.uptime()-playingSongStartTime
	end
	
	function mfs.isPaused() return paused end
	
	function mfs.update()
		if paused then
			playingSongStartTime = computer.uptime()-pauseTime
			playingSongCurrent = pauseTime
		else
			playingSongCurrent = computer.uptime()-playingSongStartTime
			if playingSongCurrent>songs[playingSongIndex].lis then
				--song finished
				mfs.stopSong()
				if onSongFinish then onSongFinish(playingSongIndex) end
			end
		end
	end
	
	function mfs.onSongFinish(func)
		onSongFinish = func
	end
	
	function mfs.isPlaying()
		return playingSongIndex
	end
	
	function mfs.getCurrentPosition()
		if playingSongIndex then
			return playingSongCurrent, songs[playingSongIndex].lis
		end
	end
	
	function mfs.getSong(i)
		return songs[i]
	end
	
	function mfs.getTapePtr()
		local ptr = td.seek(-math.huge)
		td.seek(-ptr)
		return -ptr
	end
	
	return mfs
end

return musicfs
