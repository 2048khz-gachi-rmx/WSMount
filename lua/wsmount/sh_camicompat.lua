function WSMount.HasCAMIAccess(actor, permName)
	return CAMI.PlayerHasAccess(actor, permName)
end

function WSMount.CanManage(ply)
	return ply:IsSuperAdmin() or WSMount.HasCAMIAccess(ply, "WSMount_Modify")
end

WSMount.PrivilegeName = CAMI.RegisterPrivilege({
	Name = "WSMount_Modify",
	MinAccess = "superadmin"
})