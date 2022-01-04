-- override CLuaEmitter:Add because SF2 uses it
local PEm = FindMetaTable("CLuaEmitter")
_WSMountOverrides["CLuaEmitter.Add"] = _WSMountOverrides["CLuaEmitter.Add"] or PEm.Add

local realAdd = _WSMountOverrides["CLuaEmitter.Add"]
function PEm:Add(mat, ...)
	mat = WSMount.SwapMaterials[mat] or mat
	return realAdd(self, mat, ...)
end