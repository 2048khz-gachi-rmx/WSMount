-- setfenv(1, _G)
WSMount = WSMount or {}

if SERVER then
	include("sh_storage.lua")

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
			print("[WSMount] Preventing resource.AddWorkshop: " .. (wsid or "[what]") ..
				" (will be mounted live)")
			return
		end
		return _oldAddWorkshop(wsid)
	end

	function WSMount.AddWorkshop(wsid)
		return WSMount.AddAddon(wsid)
	end
else
	WSMount.PathToMissingMat = WSMount.PathToMissingMat or {}
	WSMount.MissingMatToPath = WSMount.MissingMatToPath or {}

	local function isBadMaterial(ret)
		local base = ret and ret:GetTexture("$basetexture")
		if ret and ret:IsError() then
			return true
		end

		return false
	end

	_oldMaterial = _oldMaterial or Material -- this wont cover everything
	function Material(path, flags, ...)
		local ret, time, w, t, f = _oldMaterial(path, flags, ...)

		if isBadMaterial(ret) then
			-- i hate you and everything you stand for
			local lc_path = path:lower() -- MountGMA returns lowercase paths
			WSMount.PathToMissingMat[path] = WSMount.PathToMissingMat[path] or {}
			WSMount.PathToMissingMat[lc_path] = WSMount.PathToMissingMat[path]

			table.insert(WSMount.PathToMissingMat[path], ret) -- oof

			WSMount.MissingMatToPath[ret] = path
		end

		return ret, time, w, t, f
	end

	-- do this before anyone loads so no localizing bullshit occurs

	local setters = {
		render = {
			render,
			"SetMaterial",
			"MaterialOverride",
			"ModelMaterialOverride",
			"BrushMaterialOverride",
		},

		surface = {
			surface,
			"SetMaterial"
		}
	}

	_WSMountOverrides = _WSMountOverrides or {}
	WSMount.SwapMaterials = WSMount.SwapMaterials or {}
	WSMount.MaterialProperties = WSMount.MaterialProperties or {}

	for namespace, fns in pairs(setters) do
		local tbl = fns[1] -- i dont want to use "_" .. "G", so no bekdor scanerz
		for i=2, #fns do
			local name = fns[i]
			local key = namespace .. "." .. name

			local orig_fn = _WSMountOverrides[key] or tbl[name]
			_WSMountOverrides[key] = orig_fn

			tbl[name] = function(mat, ...)
				mat = WSMount.SwapMaterials[mat] or mat
				return orig_fn(mat, ...)
			end
		end
	end

	local IMat = FindMetaTable("IMaterial")
	local ignore = {}
	local is_bad = {}

	for k,v in pairs(IMat) do
		if isfunction(v) and not k:match("^_") then
			local key = "IMaterial." .. k
			local orig_fn = _WSMountOverrides[key] or v
			_WSMountOverrides[key] = orig_fn

			if k:match("^Set") then
				IMat[k] = function(self, ...)
					if not is_bad[self] then
						-- not ignored but not bad; we dont know this mat
						local tbl = isBadMaterial(self) and is_bad or ignore
						tbl[self] = true
					end

					if ignore[self] then return orig_fn(self, ...) end

					-- material is bad!!!
					local new = WSMount.SwapMaterials[self] or self

					if self == new then
						-- no new material loaded yet
						--print("yo calling setter on old mat, storing",
						--	self, WSMount.MissingMatToPath[self])
						WSMount.MaterialProperties[self] = WSMount.MaterialProperties[self] or {}
						WSMount.MaterialProperties[self][k] = {...}
					end

					return orig_fn(new, ...)
				end
				continue
			end

			IMat[k] = function(self, ...)
				--print("called overridden", key, self, WSMount.SwapMaterials[self], ...)
				self = WSMount.SwapMaterials[self] or self
				--[[if WSMount.SwapMaterials[self] then
					print("lol", key, "overridden")
				end]]
				return orig_fn(self, ...)
			end
		end
	end

	function WSMount.MaterialMerge(from, to)
		local done = {}

		if WSMount.MaterialProperties[from] then
			print("---\nmerge: found properties", from)
			PrintTable(WSMount.MaterialProperties[from])
			print("running them on", to)
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

	local realTexID = _WSMountOverrides["surface.GetTextureID"] or surface.GetTextureID
	_WSMountOverrides["surface.GetTextureID"] = realTexID

	local realSetTex = _WSMountOverrides["surface.SetTexture"] or surface.SetTexture
	_WSMountOverrides["surface.SetTexture"] = realSetTex

	WSMount.PathToTex = WSMount.PathToTex or {}
	WSMount.TexToPath = WSMount.TexToPath or {}
	WSMount.TexSwap = WSMount.TexSwap or {} 	-- [texID_old] = texID_new

	function surface.GetTextureID(path)
		-- whyyyyyy must you do this to me
		local ret = realTexID(path)

		WSMount.PathToTex[path] = WSMount.PathToTex[path] or {}
		WSMount.PathToTex[path][ret] = true -- a
		WSMount.TexToPath[ret] = path

		return ret
	end

	function surface.SetTexture(id)
		id = WSMount.TexSwap[id] or id

		return realSetTex(id)
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
end