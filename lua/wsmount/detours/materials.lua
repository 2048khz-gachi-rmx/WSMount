WSMount.MissingMatToPath = WSMount.MissingMatToPath or {}
WSMount.PathToMissingMat = WSMount.PathToMissingMat or {}

function WSMount.IsBadMaterial(ret)
	if ret and type(ret) == "IMaterial" and ret:IsError() then
		return true
	end

	return false
end

_oldMaterial = _oldMaterial or Material -- this wont cover everything
function Material(path, flags, ...)
	local ret, time, w, t, f = _oldMaterial(path, flags, ...)

	if WSMount.IsBadMaterial(ret) then
		-- i hate you and everything you stand for
		local lc_path = path:lower() -- MountGMA returns lowercase paths
		WSMount.PathToMissingMat[path] = WSMount.PathToMissingMat[path] or {}
		WSMount.PathToMissingMat[lc_path] = WSMount.PathToMissingMat[path]

		table.insert(WSMount.PathToMissingMat[path], {ret, flags}) -- oof

		WSMount.MissingMatToPath[ret] = path
	end

	return ret, time, w, t, f
end

local IMat = FindMetaTable("IMaterial")
WSMount.IgnoreMaterials_Cache = setmetatable({}, {__mode = "k"})
WSMount.BadMaterials_Cache = setmetatable({}, {__mode = "k"})

local is_bad = WSMount.BadMaterials_Cache
local ignore = WSMount.IgnoreMaterials_Cache

-- override material parameter getters/setters for addons that
-- change them dynamically (ie rendertargets (CW2 scopes) or SF2)

IMat.__GetName = IMat.__GetName or IMat.GetName

for k,v in pairs(IMat) do
	if isfunction(v) and not k:match("^_") --[[and k ~= "IsError"]] then
		local key = "IMaterial." .. k
		local orig_fn = _WSMountOverrides[key] or v
		_WSMountOverrides[key] = orig_fn

		if not k:match("^Set") then
			-- everything thats not a setter just does/returns what it would
			-- but on the swap material instead (if one exists)
			IMat[k] = function(self, ...)
				self = WSMount.SwapMaterials[self] or self
				return orig_fn(self, ...)
			end
		else
			-- setters get special treatment: they may set shit on a bad material before we load the swap
			-- so we store eveything set on them until a swap arrives

			IMat[k] = function(self, name, ...)
				-- rather than check if a material is bad each time
				-- we set something, do quick lookups instead

				local cacheKey = IMat.__GetName(self)

				-- this mat is valid; just do regular behavior
				if ignore[cacheKey] then
					return orig_fn(self, name, ...)
				end

				-- not ignored but not bad; we dont know this mat
				if not is_bad[cacheKey] then
					local tbl = WSMount.IsBadMaterial(self) and is_bad or ignore
					tbl[cacheKey] = true
				end

				-- material is bad!!! (= error mat)
				local new = WSMount.SwapMaterials[self] or self

				if self == new then
					-- no new material loaded yet
					WSMount.MaterialProperties[self] = WSMount.MaterialProperties[self] or {}
					WSMount.MaterialProperties[self][k] = {name, ...}
				end

				return orig_fn(new, name, ...)
			end

		end
	end
end

function WSMount.MaterialMerge(from, to)
	if WSMount.MaterialProperties[from] then
		for k,v in pairs(WSMount.MaterialProperties[from]) do
			to[k] (to, unpack(v))
		end
	end

	local tex = from:GetTexture("$basetexture")
	if tex then
		tex:Download()
	end

	from:Recompute()
end