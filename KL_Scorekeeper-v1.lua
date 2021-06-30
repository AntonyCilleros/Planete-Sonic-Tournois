--Scorekeeper
-- was called Global Count, untill i renamed it
--by Callmore#4947

local FILENAME = "scorekeeper.txt"
local globalData = {}
local dectimer = 0

local cv_hourstoreset = CV_RegisterVar{
	name = "sk_hoursuntilreset",
	defaultvalue = 168,
	flags = CV_NETVAR,
	PossibleValue = CV_Natural
}

-- Here we attempt to open the score file to read the scores into memory.
-- If the file doesent exsist, io.open silently fails.
-- io.open needs to be wrapped inside of an assert to error when a file is
--   failed to be opened.
local f = io.open(FILENAME, "r")
if f then
	-- file already exsists, load from it
	print('Loading scores from "scorekeeper.txt"...')
	for l in f:lines() do
		local name, score, matchreset = string.match(l, "(.*);(.*);(.*)")

		if name then
			globalData[name] = {tonumber(score), tonumber(matchreset)}
		end
	end
	f:close()
end

local function getHoursToReset()
	return TICRATE*60*60*cv_hourstoreset.value
end

local function _saveFileFunc()
	-- This function actully opens the file.
	-- If the file failed to open for whatever reason, the assert would catch
	--   it and return back to the pcall that called this function.
	local f = assert(io.open(FILENAME, "w"))
	for pn, s in pairs(globalData) do
		if pn:find(";") then continue end -- reject any names that contain a semicolon, since OOPS HOSTS CAN DO THAT LOL
		f:write(pn, ";", s[1], ";", s[2], "\n")
	end
	f:close()
end

local function saveFile()
	-- This function is effectivly a wrapper for the real open file function.
	-- The real open file function opens the file through an assert,
	--   if the file failed to open, it would immediatly stop execution and
	--   return here with a false, causing the if block to be ran and to print
	--   the message.
	if consoleplayer ~= server then return end
	print('Saving scores to "scorekeeper.txt"...')
	if not pcall(_saveFileFunc) then
		print("Failed to save file!")
	end
end

local function incdec()
	dectimer = min($+1, getHoursToReset())
end

local hasRanInt = false

local function think()
	if hasRanInt then
		hasRanInt = false
	end
	
	incdec()
	
	for p in players.iterate do
		if not p.sk_loaded then
			p.sk_loaded = true
			if globalData[p.name] then
				p.score = globalData[p.name][1]
			end
		elseif p.name ~= p.sk_lastname then
			if globalData[p.name] ~= nil then
				p.score = globalData[p.name][1]
			else
				--check if oldname exsists
				if globalData[p.sk_lastname] then
					--they exsist, save score and reset
					globalData[p.sk_lastname][0] = p.score
				end
				globalData[p.name] = {0, getHoursToReset()}
				p.score = 0
			end
		end
		p.sk_lastname = p.name
	end
end
addHook("ThinkFrame", think)

local function intThink()
	incdec()
	if hasRanInt then return end
	hasRanInt = true
	local pingame = {}
	for p in players.iterate do
		globalData[p.name] = {p.score, getHoursToReset()}
		pingame[p.name] = true
	end
	for n, v in pairs(globalData) do
		if pingame[n] then continue end
		if tonumber(v[2])-dectimer > 0 then
			globalData[n][2] = $-dectimer
		else
			--they havent played in too long, wipe data
			globalData[n] = nil
		end
	end
	saveFile()
	dectimer = 0
end
addHook("IntermissionThinker", intThink)

local function voteThink()
	incdec()
end
addHook("VoteThinker", voteThink)

local function netvars(net)
	globalData = net($)
	dectimer = net($)
end
addHook("NetVars", netvars)
