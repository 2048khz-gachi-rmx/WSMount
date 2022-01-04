-- setfenv(1, _G)
WSMount = WSMount or {}
WSMount.Hooks = WSMount.Hooks or {}

local function addHook(ev, name, fn)
	WSMount.Hooks[ev] = WSMount.Hooks[ev] or {}
	WSMount.Hooks[ev][name] = fn
end

--[==================================[
	override default behiavor
	SERVER:
		- replace resource.AddWorkshop to probe addons
		- noop resource.AddWorkshop if the added addon is
		  already designated to be mounted live

	CLIENT:
		- replace every material-settting function to
		  use a swapped (ie newly mountted) material instead
		  (if one exists)
		- replace all IMaterial methods to
		  work with swapped materials instead

--]==================================]
if SERVER then
	include("sh_storage.lua")
	include("sh_core.lua")

	local addons = WSMount.Storage.LoadInitial(true)
	addons = addons and addons.Addons or {}

	WSMount.CaughtPreBoot = WSMount.CaughtPreBoot or {}

	_oldAddWorkshop = _oldAddWorkshop or resource.AddWorkshop

	function resource.AddWorkshop(wsid)
		if WSMount.GetAddons then
			addons = WSMount.GetAddons()
		end

		wsid = tostring(wsid)
		WSMount.CaughtPreBoot[wsid] = true

		if WSMount.CatchAddon then
			WSMount.CatchAddon(wsid)
		end

		-- do not add workshop addons that
		-- are supposed to be mounted live
		if table.HasValue(addons, wsid) then
			-- also tell the admins about it
			WSMount.Log("Preventing resource.AddWorkshop: %s (will be mounted live)", wsid or "[wtf!? no WSID given!?]")
			return
		end
		return _oldAddWorkshop(wsid)
	end

	function WSMount.AddWorkshop(wsid)
		return WSMount.AddAddon(wsid)
	end
	return
end

_WSMountOverrides = _WSMountOverrides or {}
WSMount.SwapMaterials = WSMount.SwapMaterials or {}
WSMount.MaterialProperties = WSMount.MaterialProperties or {}

for k,v in ipairs(file.Find("wsmount/detours/*.lua", "LUA")) do
	include("wsmount/detours/" .. v)
end

WSMount.Mounted = WSMount.Mounted or {}

function WSMount.InitialMount()
	-- mount using data from previous sessions; try to mount before any rendering n shit happens
	include("sh_storage.lua")
	local data = WSMount.Storage.LoadInitial(true)

	if not data or not data.Paths then return end

	for wsid, path in pairs(data.Paths) do
		local ok, contents = game.MountGMA(path)
		wsid = tostring(wsid)
		if not ok then
			-- failed for some reason; remove path from associates so we redownload it
			print("!! WSMount failed cached mount, removing path from cache...", wsid, path)
			WSMount.AssociatePath(wsid, nil)
		else
			-- mounted ok; mark as such so we dont remount it again
			contents.Reloaded = true
			WSMount.Mounted[wsid] = contents
		end
	end
end

WSMount.InitialMount()

