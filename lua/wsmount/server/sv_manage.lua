net.Receive("WSMount_UpdateAddon", function(len, ply)
	if not WSMount.CanManage(ply) then return end

	local finish = net.ReadBool()
	if finish then
		WSMount.Net_RequestMount() -- tell everyone to mount the changes
		return
	end

	local wsid = net.ReadDouble()
	local add = net.ReadBool()

	if add then
		WSMount.AddAddon(wsid)
	else
		WSMount.RemoveAddon(wsid)
	end
end)