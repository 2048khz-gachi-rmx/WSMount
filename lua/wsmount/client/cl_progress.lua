--

-- list of WSID's waiting to be downloaded ([wsid] = true)
WSMount.DLQueue = WSMount.DLQueue or {}

-- paths to downloaded addons, waiting for game.MountGMA ([wsid] = path)
WSMount.MountQueue = WSMount.MountQueue or {}
WSMount.Mounted = WSMount.Mounted or {}

-- [IMaterial_Old] = IMaterial_New
WSMount.SwapMaterials = WSMount.SwapMaterials or {}

local function matchAll(path, tbl)
	if tbl[path] then return tbl[path], path end

	local noExt = string.StripExtension(path)
	if tbl[noExt] then return tbl[noExt], noExt end

	path = path:gsub("^materials/", "")
	if tbl[path] then return tbl[path], path end

	noExt = noExt:gsub("^materials/", "")
	if tbl[noExt] then return tbl[noExt], noExt end

	-- todo: resolve ../ ?
	return false
end

local function tryFindMat(path)
	local mat, foundPath = matchAll(path, WSMount.PathToMissingMat)
	local texIDs, texPath = matchAll(path, WSMount.PathToTex)

	return mat, foundPath or texPath, texIDs
end

function WSMount.RefreshContent(wsid, cont)
	for _, fn in ipairs(cont) do
		if not fn:match("%.vtf$") and
			not fn:match("%.png$") and
			not fn:match("%.jpg$") and
			not fn:match("%.vmt$") then
			continue
		end

		local missingMats, usePath, missingIDs = tryFindMat(fn)

		if missingIDs then
			local texID = surface.GetTextureID("\\" .. usePath)
			for oldID, _ in pairs(missingIDs) do
				WSMount.TexSwap[oldID] = texID
			end
		end

		if missingMats then
			-- a material using this texture was attempted to be loaded before mount
			-- add an override for any lua material-setting function so it'd use this
			-- new material we just created instead of the old erroring one

			local newMat = Material(usePath)
			if not newMat or newMat:IsError() then
				print("failed to create:", usePath, newMat)
				continue
			end -- ?

			for _, mat in ipairs(missingMats) do
				WSMount.MaterialMerge(mat, newMat) -- questionable practice
				WSMount.SwapMaterials[mat] = newMat
			end
		end

		--RunConsoleCommand("mat_reloadmaterial", fn)
		--RunConsoleCommand("mat_reloadtexture", fn)
	end

	hook.Run("WSMount_MountContent", wsid, cont)
end

function WSMount.RefreshAll()
	-- after everything has been mounted

	RunConsoleCommand("r_flushlod") -- reload all models
	RunConsoleCommand("snd_restart") -- sounds
	-- ??
end

local screen = CreateMaterial("WSMount_Screen", "GMODScreenspace", {
	["$basetexture"] = "_rt_FullFrameFB",
	["$texturealpha"] = "0",
	["$vertexalpha"] = "0",
})

surface.CreateFont("WSMount_Overlay", {
	font = "Roboto",
	size = 36,
	weight = 400,
})

function WSMount.DrawMountingOverlay()
	cam.Start2D()
		render.SetMaterial(screen)
		render.DrawScreenQuad()

		surface.SetDrawColor(0, 0, 0, 230)
		surface.DrawRect(0, 0, ScrW(), ScrH())

		draw.SimpleText("mounting content, please wait...", "WSMount_Overlay",
			ScrW() / 2, ScrH() / 2 + 16, color_white,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	cam.End2D()
end

local function doMount()
	local preMcore = GetConVar("gmod_mcore_test"):GetInt()
	local preQueue = GetConVar("mat_queue_mode"):GetInt()

	-- trip up anticheats 5head
	local frames = 0

	hook.Add("PreRender", "WSMount_AvoidCrashHack", function()
		frames = frames + 1
		if frames < 2 then
			WSMount.DrawMountingOverlay()
			return true
		end

		for k,v in pairs(WSMount.MountQueue) do
			local ok, contents = game.MountGMA(v)

			WSMount.Mounted[k] = contents
			WSMount.MountQueue[k] = nil
		end

		hook.Remove("PreRender", "WSMount_AvoidCrashHack")
		hook.Remove("RenderScreenspaceEffects", "WSMount_Fill")

		if table.IsEmpty(WSMount.DLQueue) and table.IsEmpty(WSMount.MountQueue) then
			timer.Simple(0, function()
				for wsid, cont in pairs(WSMount.Mounted) do
					if not cont.Reloaded then
						WSMount.RefreshContent(wsid, cont)
						cont.Reloaded = true
					end
				end

				WSMount.RefreshAll()

				-- ACK
				timer.Simple(0.5, function()
					RunConsoleCommand("gmod_mcore_test", tostring(preMcore))
					RunConsoleCommand("mat_queue_mode", tostring(preQueue))
				end)
			end)
		end

		if frames < 4 then
			WSMount.DrawMountingOverlay()
			return true
		end
	end)
end

local function reqMount()
	if timer.Exists("WSMount_Delay") then return end

	hook.Add("RenderScreenspaceEffects", "WSMount_Fill", function()
		-- will only run when allowed to render (ie, not returning true from PrePrender)
		render.UpdateScreenEffectTexture()
	end)

	timer.Create("mount_delay", 1, 1, doMount)
end

function WSMount.BeginMount()
	for k,v in ipairs(WSMount.GetAddons()) do
		if WSMount.Mounted[v] or WSMount.DLQueue[v] then continue end

		WSMount.DLQueue[v] = true
		steamworks.DownloadUGC(v, function(path, fobj)
			WSMount.MountQueue[v] = path
			WSMount.AssociatePath(v, path)
			WSMount.DLQueue[v] = nil
			reqMount()
		end)
	end
end