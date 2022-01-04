-- mfw no funny lib
WSMount = WSMount or {} -- do not recreate this table; use WSMount.Reset() instead

function WSMount.Reset()
	-- reset networking state
	if SERVER then table.Empty(WSMount.Known) end

	-- reset addon cache
	WSMount.PurgeList()

	-- do not reset caught addons serverside (cause we cant catch them anymore)
	if CLIENT then
		WSMount.GotAddons = 0

		table.Empty(WSMount.CaughtAddons)
		table.Empty(WSMount.Mounted)
		table.Empty(WSMount.MountQueue)
	end

	WSMount.Storage.LoadInitial()

	-- request refetch
	if CLIENT then
		net.Start("WSMount_RequestList")
			net.WriteBool(false)
		net.SendToServer()
	end

	timer.Remove("WSM_Flush")
end

--[[
-- debug

function WSMount.Resync()
	WSMount.Reset()
	include("wsmount/client/cl_networking.lua")
end
]]

local root = "wsmount/"

local function recInc(sub, cl, sv, recurse)
	recurse = recurse == nil or recurse

	local slashsub = sub:gsub("/$", "") .. "/"
	local path = (root .. sub):gsub("/$", "") .. "/" -- force a / at the end

	local should_inc =
		CLIENT and (cl == nil or cl) or
		SERVER and (sv == nil or sv)

	local should_share = SERVER and (cl == nil or cl)

	local files, folders = file.Find(path .. "*", "LUA")

	for k,v in ipairs(files) do
		local fn = path .. v
		if not fn:match("%.lua$") or fn:match("/_.+%.lua$") then continue end -- ignore lua files starting with _

		if should_inc then
			include(fn)
		end

		if should_share then
			AddCSLuaFile(fn)
		end
	end

	if recurse then
		for k,v in ipairs(folders) do
			local fn = path .. v
			if fn:match("/_.+$") then continue end

			recInc(slashsub .. v, cl, sv)
		end
	end
end

WSMount.IncludeFolder = recInc

recInc("", true, true, false) -- everything in root is shared
recInc("server", false, true)
recInc("client", true, false)
recInc("detours", SERVER, false) -- basically only AddCSLua the stuff; it'll be included in preboot