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
				WSMount.LogError("Failed to create a mounted material!? Tried path: %s", usePath)
				continue
			end

			for _, mat in ipairs(missingMats) do
				local errMat, flags = mat[1], mat[2]
				local useMat = newMat
				if flags and flags ~= "" then
					useMat = Material(usePath, flags) -- have to make a new mat with desired flags
				end
				WSMount.MaterialMerge(errMat, useMat) -- questionable practice
				WSMount.SwapMaterials[errMat] = useMat
			end
		end

		--RunConsoleCommand("mat_reloadmaterial", fn)
		--RunConsoleCommand("mat_reloadtexture", fn)
	end

	hook.Run("WSMount_MountContent", wsid, cont)
end

function WSMount.RefreshAll()
	-- after everything has been mounted

	WSMount.Log("Reloading models...")
	RunConsoleCommand("r_flushlod") -- reload all models

	WSMount.Log("Restarting sound...")
	RunConsoleCommand("snd_restart") -- sounds
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

local preMcore, preQueue
local preFixed = false

local function preventRender()
	WSMount.DrawMountingOverlay()
	return true
end

local amtMounted = 0

local function releaseRender()
	timer.Create("WSM_ReleaseRender", 0.1, 1, function()
		RunConsoleCommand("gmod_mcore_test", tostring(preMcore))
		RunConsoleCommand("mat_queue_mode", tostring(preQueue))

		-- i realize the concommand delay is intentional but still,
		-- a giant fuck you goes to valve for this
		hook.Add("Think", "WSMount_thxvalve", function()
			preFixed = false
		end)

		hook.Remove("PreRender", "WSMount_AvoidCrashHack")
		hook.Remove("RenderScreenspaceEffects", "WSMount_Fill")

		WSMount.Say("Mounted %d addons!", amtMounted)
		amtMounted = 0
	end)
end

local function doMount()
	if table.IsEmpty(WSMount.MountQueue) then return end -- u w0t

	if not preFixed then
		preMcore = GetConVar("gmod_mcore_test"):GetInt()
		preQueue = GetConVar("mat_queue_mode"):GetInt()
		preFixed = true
	end

	RunConsoleCommand("gmod_mcore_test", 0)
	RunConsoleCommand("mat_queue_mode", 0)

	local frames = 0
	local refreshing = false

	-- lock rendering -> mount -> refresh -> release
	hook.Add("PreRender", "WSMount_AvoidCrashHack", function()
		frames = frames + 1
		if frames < 3 then -- first few frames, disallow rendering anything but don't mount
			return preventRender()
		end

		-- nothing to mount; dont care about refresh nor mount logic
		if table.IsEmpty(WSMount.MountQueue) then
			return preventRender()
		end

		if refreshing then
			return preventRender()
		end

		-- after N frames are prevented, start mounting crap

		for k,v in pairs(WSMount.MountQueue) do
			WSMount.Log("Mounting addon '%s' (@ %s)...", k, v)
			local ok, contents = game.MountGMA(v)

			if not ok then
				WSMount.LogError("	Mount unsuccessful! No clue why.") -- gmod isn't very helpful
			end

			WSMount.Mounted[k] = contents
			WSMount.MountQueue[k] = nil
			amtMounted = amtMounted + 1
		end

		refreshing = true

		if table.IsEmpty(WSMount.DLQueue) then
			-- nothing left to download & everything has been mounted (above)
			-- refresh all content so errors stop being errors, etc.
			timer.Simple(0, function()
				-- do it outside of a rendering context, just in case lol
				WSMount.Log("Queue empty; reloading all materials!")

				local refreshed = 0

				for wsid, cont in pairs(WSMount.Mounted) do
					if not cont.Reloaded then
						refreshed = refreshed + 1
						WSMount.RefreshContent(wsid, cont)
						cont.Reloaded = true
					end
				end

				if refreshed > 0 then
					WSMount.RefreshAll()
				end

				releaseRender()
			end)
		else
			-- we're still downloading something, just release rendering from being hostage for now
			-- we'll refresh content once the queue is empty
			releaseRender()
		end

		return preventRender()
	end)
end

local function reqMount()
	--if timer.Exists("WSMount_Delay") then return end

	hook.Add("RenderScreenspaceEffects", "WSMount_Fill", function()
		-- will only run when allowed to render (ie, not returning true from PrePrender)
		render.UpdateScreenEffectTexture()
	end)

	timer.Create("mount_delay", 3, 1, doMount)
end

WSMount.GotAddons = WSMount.GotAddons or 0

-- going above 50 megs of addons awaiting mount will request mount
local MountSizeCap = 50 * 1024 * 1024

function WSMount.BeginMount(remount)
	WSMount.Say("Beginning download of %d addons...", #WSMount.GetAddons())

	local awaitingMountSz = 0
	WSMount.GotAddons = 0

	for k,v in ipairs(WSMount.GetAddons()) do
		if remount and WSMount.Mounted[v] then
			WSMount.Mounted[v] = nil
		end

		local mounted = WSMount.Mounted[v]
		if mounted then
			-- This addon was already mounted; just increment the counter and ignore it
			WSMount.GotAddons = WSMount.GotAddons + 1
			continue
		end

		local in_queue = WSMount.DLQueue[v]
		if in_queue then continue end -- The addon is already downloading; the UGC callback will increment the counter already

		WSMount.DLQueue[v] = true
		steamworks.DownloadUGC(v, function(path, fobj)
			if not path then
				WSMount.Say("Failed to download addon \"%s\"!", v)
				ErrorNoHalt("Failed to download addon \"" .. v .. "\"!")
				return
			end

			WSMount.GotAddons = WSMount.GotAddons + 1
			awaitingMountSz = awaitingMountSz + fobj:Size()

			local total = #WSMount.GetAddons()
			local left = total - WSMount.GotAddons

			WSMount.MountQueue[v] = path
			WSMount.AssociatePath(v, path)
			WSMount.DLQueue[v] = nil

			if left > 5 and left % 5 == 0
			or left <= 5 then

				WSMount.Say("%d/%d addons downloaded...",
					WSMount.GotAddons, total)
			end

			if left % 5 == 0 or awaitingMountSz > MountSizeCap then
				-- mount in batches of 5 addons or some random size i picked, lol
				reqMount()
				awaitingMountSz = 0
			end
		end)
	end
end