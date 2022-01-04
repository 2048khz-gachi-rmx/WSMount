WSMount.PathToMissingMat = WSMount.PathToMissingMat or {}
WSMount.MissingMatToPath = WSMount.MissingMatToPath or {}

function WSMount.IsBadMaterial(ret)
	if ret and ret:IsError() then
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
local ignore = {}
local is_bad = {}

-- override material parameter getters/setters for addons that
-- change them dynamically (ie rendertargets (CW2 scopes) or SF2)

for k,v in pairs(IMat) do
	if isfunction(v) and not k:match("^_") and k ~= "IsError" then
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
				if not is_bad[self] then
					-- not ignored but not bad; we dont know this mat
					local tbl = WSMount.IsBadMaterial(self) and is_bad or ignore
					tbl[self] = true
				end

				-- this mat is valid; just do regular behavior
				if ignore[self] then
					return orig_fn(self, name, ...)
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