util.AddNetworkString("WSMount_RequestList")
util.AddNetworkString("WSMount_UpdateAddon")

WSMount.Known = {}
WSMount.Cooldowns = {}

local cdRate = 2
local disableAwareness = true

function WSMount.Net_SendList(ply)
	if IsEntity(ply) and not IsValid(ply) then return end

	-- cooldown logic
	local sinceReq = CurTime() - (WSMount.Cooldowns[ply] or -999)

	if sinceReq < 2 then
		-- automatically send the list in X seconds, but not now
		local id = ("WSM_RateLimit:%s"):format(ply:SteamID64())
		timer.Create(id, cdRate - sinceReq, 1, function()
			WSMount.Net_SendList(ply)
		end)

		return
	end

	local new = {}
	local known = WSMount.Known[ply] or {}
	WSMount.Known[ply] = known

	for k,v in ipairs(WSMount.GetAddons()) do
		if disableAwareness or not known[v] then
			table.insert(new, v)
			known[v] = true
		end
	end

	net.Start("WSMount_RequestList")
		net.WriteBool(false)
		net.WriteUInt(#new, 16)
		for k,v in ipairs(new) do
			net.WriteDouble(tonumber(v)) -- i hope workshop ids dont go over 53bit!!!!!!!
		end
	net.Send(ply)
end

function WSMount.Net_NotifyAddon(wsid, added)
	assert( isbool(added) )

	net.Start("WSMount_UpdateAddon")
		net.WriteBool(false) -- not a mount request
		net.WriteBool(added)
		net.WriteDouble(wsid)
	net.Broadcast()
end

function WSMount.Net_RequestMount(ply)
	net.Start("WSMount_UpdateAddon")
		net.WriteBool(true) -- is a mount request; JUST DO IT MAYNE
	net.Broadcast()
end

function WSMount.Net_SendCaught(ply)
	-- admin only; just spew everything out whatever

	local spew = {}

	for k,v in ipairs(WSMount.GetCaughtAddons()) do
		table.insert(spew, v)
	end

	net.Start("WSMount_RequestList")
		net.WriteBool(true)
		net.WriteUInt(#spew, 16)
		for k,v in ipairs(spew) do
			net.WriteDouble(tonumber(v))
		end
	net.Send(ply)
end

net.Receive("WSMount_RequestList", function(len, ply)
	local probed = net.ReadBool() -- want probed addons?

	if not probed then
		WSMount.Net_SendList(ply) -- send list of wanted addons
	else
		if not WSMount.CanManage(ply) then return end
		WSMount.Net_SendCaught(ply) -- only if they can manage, send probed
	end
end)

hook.Add("WSMount_AddedAddon", "NetworkChanges", function(wsid)
	WSMount.Net_NotifyAddon(wsid, true)
end)

hook.Add("WSMount_RemovedAddon", "NetworkChanges", function(wsid)
	WSMount.Net_NotifyAddon(wsid, false)
end)