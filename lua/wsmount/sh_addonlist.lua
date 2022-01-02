WSMount.Addons = WSMount.Addons or {} -- [seq_idx] = wsid,
WSMount.AddonPaths = WSMount.AddonPaths or (CLIENT and {} or nil)
WSMount.CaughtAddons = WSMount.CaughtAddons or {}

function WSMount.AddAddon(wsid, noHook)
	wsid = tostring(wsid)
	if table.HasValue(WSMount.Addons, wsid) then return end
	table.insert(WSMount.Addons, wsid)

	if not noHook then
		hook.Run("WSMount_AddedAddon", wsid)
	end
end

function WSMount.RemoveAddon(wsid)
	wsid = tostring(wsid)
	table.RemoveByValue(WSMount.Addons, wsid)

	if CLIENT then
		WSMount.AssociatePath(wsid, nil)
	end

	hook.Run("WSMount_RemovedAddon", wsid)
end

function WSMount.CatchAddon(wsid)
	wsid = tostring(wsid)
	-- caught addons are append-only
	if table.HasValue(WSMount.CaughtAddons, wsid) then return end
	table.insert(WSMount.CaughtAddons, wsid)

	hook.Run("WSMount_CaughtAddon", wsid)
end

function WSMount.GetAddons() -- immutable pretty please
	return WSMount.Addons
end

function WSMount.PurgeList()
	table.Empty(WSMount.Addons)
end

function WSMount.GetCaughtAddons()
	return WSMount.CaughtAddons
end


if WSMount.CaughtPreBoot then
	for wsid, _ in pairs(WSMount.CaughtPreBoot) do
		WSMount.CatchAddon(wsid)
	end
end