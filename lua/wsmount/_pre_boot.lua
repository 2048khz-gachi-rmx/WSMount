WSMount = WSMount or {}
WSMount.Hooks = WSMount.Hooks or {}

include("_sh_core.lua")
WSMount.Log("Loaded core...")

WSMount.PreBooting = true

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
	include("_sh_core.lua")

	local addons = WSMount.Storage.LoadInitial(true)
	addons = addons and addons.Addons or {}

	WSMount.CaughtPreBoot = WSMount.CaughtPreBoot or {}

	_oldAddWorkshop = _oldAddWorkshop or resource.AddWorkshop
	WSMount.RealAddWorkshop = WSMount.RealAddWorkshop or _oldAddWorkshop
	resource.OldAddWorkshop = resource.OldAddWorkshop or WSMount.RealAddWorkshop -- compat with https://www.gmodstore.com/market/view/4868 i believe

	function resource.AddWorkshop(wsid)
		if WSMount.GetAddons then
			addons = WSMount.GetAddons()
		end

		wsid = tostring(wsid)

		if tonumber(wsid) then
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
		else
			WSMount.LogError("Some addon attempted to add a Workshop item with an invalid non-number ID: \"%s\"", wsid)
			WSMount.LogError("%s", debug.traceback("", 2))
		end

		return _oldAddWorkshop(wsid)
	end

	function WSMount.AddWorkshop(wsid)
		return WSMount.AddAddon(wsid)
	end
	WSMount.PreBooting = nil
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

	if not data or not data.Paths or not data.Addons then
		WSMount.Log("Missing %s, not mounting on startup.",
			(not data and "all data") or
			(not data.Paths and not data.Addons and "paths & addons") or
			(not data.Paths and "paths") or
			(not data.Addons and "addons") or "???"
		)
		return
	end

	WSMount.Log("Aware of %s addons; mounting...", #data.Addons)

	for _, wsid in ipairs(data.Addons) do
		local path = data.Paths[wsid]
		if not isstring(path) then
			WSMount.LogError("	Aware of an addon, but missing the path, somehow? `%s` => `%s`", wsid, path)
			WSMount.AssociatePath(wsid, nil)
			continue
		end

		WSMount.LogContinuous("Mounting known addon `% -12s`... ", wsid)

		local ok, contents = game.MountGMA(path)
		wsid = tostring(wsid)
		if not ok then
			-- failed for some reason; remove path from associates so we redownload it
			WSMount.LogErrorContinue("failed!\n")
			WSMount.LogError("	Failed to mount at path `%s`; removing from cache...", path)

			WSMount.AssociatePath(wsid, nil)
		else
			-- mounted ok; mark as such so we dont remount it again
			WSMount.LogContinue("success!\n")

			contents.Reloaded = true
			WSMount.Mounted[wsid] = contents
		end
	end
end

WSMount.InitialMount()
WSMount.PreBooting = nil
