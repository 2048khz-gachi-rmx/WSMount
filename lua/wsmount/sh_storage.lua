local fn = "wsmount_list.dat"

if CLIENT then
	-- security hazard? other servers can override the list with shit
	-- and get users stuck in downloading the entirety of workshop

	-- w/e lol

	fn = "wsmount/list" .. game.GetIPAddress():gsub("[%.:]", "_") .. ".dat"
	file.CreateDir("wsmount")
end

WSMount.Storage = WSMount.Storage or {}

WSMount.Storage.Data = WSMount.Storage.Data or {
	Addons = {
		-- [seq_idx] = "wsid",
		-- ...
	},
	Paths = CLIENT and {} or nil, -- this is inefficient storage btw but idgaf
	Settings = {}, -- NYI? might not even be implemented
}

local st = WSMount.Storage
local data = WSMount.Storage.Data

function st.SyncAddons()
	table.Empty(data.Addons)

	for k,v in ipairs(WSMount.GetAddons()) do
		data.Addons[k] = v
	end

	st.Flush()
end

local function doFlush()
	local json = util.TableToJSON(data, true)
	file.Write(fn, json)
end

function st.Flush()
	if not timer.Exists("WSM_Flush") then -- 1s delay on flushing
		timer.Create("WSM_Flush", 1, 1, doFlush)
	end
end

if CLIENT then
	WSMount.AddonPaths = WSMount.AddonPaths or {}

	function WSMount.AssociatePath(wsid, path)
		WSMount.AddonPaths[wsid] = path
		data.Paths[wsid] = path,
		st.Flush()
	end

	function WSMount.GetPath(wsid)
		return WSMount.AddonPaths[wsid]
	end
end

function st.LoadInitial(readRaw)
	if WSMount.ReadingData then return end

	WSMount.ReadingData = true

	local function fileRead(filename)
		local f = file.Open(filename, "rb", "DATA")
		if not f then return end

		local str = f:Read(f:Size())
		f:Close()

		return str or ""
	end

	fileRead = file.Read or fileRead -- allow potentially detoured file.Read to work

	local datJson = fileRead(fn, "DATA")
	local storedData = datJson and util.JSONToTable(datJson) or {}

	if storedData.Paths then
		-- workaround: JSON turns string keys that look like numbers into actual numbers
		-- we need them as strings though

		local rep = {}
		for k,v in pairs(storedData.Paths) do
			-- just doing `storedData[tostring(k)] = v` might cause shit to break,
			-- what with creating keys during iteration and all
			rep[tostring(k)] = v
		end

		storedData.Paths = rep
	end

	if readRaw then
		WSMount.ReadingData = false
		return storedData
	end

	-- json doesnt have circular references anyways
	local function merge(dest, src)
		for k,v in pairs(src) do
			if istable(v) then
				dest[k] = istable(dest[k]) and dest[k] or {}
				merge(dest[k], v)
			else
				dest[k] = v
			end
		end
	end

	merge(data, storedData)

	for k,v in ipairs(data.Addons) do
		WSMount.AddAddon(v, true)
	end

	WSMount.ReadingData = false
end

if hook and not WSMount.PreBooting then
	-- this file can run from preboot (ie no hook lib) or autorun
	-- when ran from autorun, hook this stuff
	-- otherwise the loading is initial; no hooks required
	WSMount.Storage.LoadInitial()

	hook.Add("WSMount_AddedAddon", "StoreList", st.SyncAddons)
	hook.Add("WSMount_RemovedAddon", "StoreList", st.SyncAddons)
end