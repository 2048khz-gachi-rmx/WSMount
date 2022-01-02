--

net.Receive("WSMount_UpdateAddon", function()
	local want_mount = net.ReadBool()
	if want_mount then
		WSMount.BeginMount()
		return
	end

	local added = net.ReadBool()
	local wsid = net.ReadDouble()

	if added then
		WSMount.AddAddon(wsid)
	else
		WSMount.RemoveAddon(wsid)
	end
end)

net.Receive("WSMount_RequestList", function(len, ply)
	local probed = net.ReadBool()

	if not probed then
		local amt = net.ReadUInt(16)
		hook.Run("WSMount_PreListReceived")

		for i=1, amt do
			local wsid = net.ReadDouble()
			WSMount.AddAddon(wsid)
		end

		hook.Run("WSMount_ListReceived")
	else
		local amt = net.ReadUInt(16)
		for i=1, amt do
			local wsid = net.ReadDouble()
			WSMount.CatchAddon(wsid)
		end

		hook.Run("WSMount_ProbedListReceived")
	end
end)


hook.Add("HUDPaint", "WSM_UglyHack", function()
	hook.Remove("HUDPaint", "WSM_UglyHack")

	-- send sync request once we can render
	net.Start("WSMount_RequestList")
		net.WriteBool(false)
	net.SendToServer()

	hook.Add("WSMount_PreListReceived", "WSM_ClearCache", function()
		-- received updated initial list; purge cache
		WSMount.PurgeList()
	end)

	hook.Add("WSMount_ListReceived", "WSM_InitialMount", function()
		hook.Remove("WSMount_ListReceived", "WSM_InitialMount")
		WSMount.BeginMount()
	end)
end)