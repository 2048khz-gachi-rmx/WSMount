--

-- list of WSID's waiting to be downloaded ([wsid] = true)
WSMount.DLQueue = WSMount.DLQueue or {}

-- paths to downloaded addons, waiting for game.MountGMA ([wsid] = path)
WSMount.MountQueue = WSMount.MountQueue or {}
WSMount.Mounted = WSMount.Mounted or {}

-- [IMaterial_Old] = IMaterial_New
WSMount.SwapMaterials = WSMount.SwapMaterials or {}

--[==================================[
	tries to match the filepath of the file from the mounted GMA
	to the filepath used in Lua (in a `Material()` call, for example)

	this way we know if a file from the GMA fixes a missing IMaterial
--]==================================]

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

function WSMount.IsMaterialPath(fn)
	return fn:match("%.vtf$")
		or fn:match("%.png$")
		or fn:match("%.jpg$")
		or fn:match("%.vmt$")
		-- or fn:match("^materials/")
end

function WSMount.RefreshContent(wsid, cont)
	for _, fn in ipairs(cont) do
		if not WSMount.IsMaterialPath(fn) then continue end

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
	end

	hook.Run("WSMount_MountContent", wsid, cont)
end

-- reload engine assets (models, sounds)
-- used to also reload materials but i don't remember why i removed it
-- TODO: try again?

function WSMount.ReloadEngine()
	-- after everything has been mounted

	WSMount.Log("Reloading ALL mounted materials...")

	for wsid, cont in pairs(WSMount.Mounted) do
		for _, fn in ipairs(cont) do
			if not WSMount.IsMaterialPath(fn) then continue end

			-- RunConsoleCommand("mat_reloadmaterial", fn)
			-- RunConsoleCommand("mat_reloadtexture", fn)
		end
	end

	WSMount.Log("Reloading models...")
	RunConsoleCommand("r_flushlod") -- reload all models

	WSMount.Log("Restarting sound...")
	RunConsoleCommand("snd_restart") -- sounds

	hook.Run("WSMount_ReloadEngine")
end

WSMount.RefreshAll = WSMount.ReloadEngine -- backwards compat

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

WSMount.RenderLocked = false
WSMount.MountAllowed = true

local function preventRender()
	WSMount.DrawMountingOverlay()
	WSMount.Log("Preventing render...")
	return true
end

local amtMounted = 0

function WSMount.LockRender()
	if WSMount.RenderLocked then return end
	WSMount.RenderLocked = true
	WSMount.MountAllowed = false -- lock mounting for first N frames

	local frames = 0

	hook.Add("PreRender", "WSMount_AvoidCrashHack", function()
		frames = frames + 1
		if frames < 3 then -- first few frames, disallow rendering anything but don't mount
			return preventRender()
		end

		-- frames passed; allow mounting from Think (`WSMount_MountLogic`)
		WSMount.MountAllowed = true

		return preventRender()
	end)
end


function WSMount.ReleaseRender()
	timer.Remove("WSM_ReleaseRender")

	-- restore mcore convars, but wait before releasing render Just In Case™️
	RunConsoleCommand("gmod_mcore_test", tostring(preMcore))
	RunConsoleCommand("mat_queue_mode", tostring(preQueue))

	hook.Add("Think", "WSMount_thxvalve", function()
		timer.Create("WSM_ReleaseRender", 0.05, 1, function()
			hook.Remove("PreRender", "WSMount_AvoidCrashHack")
			hook.Remove("RenderScreenspaceEffects", "WSMount_Fill")
			preFixed = false
		end)

		WSMount.Say("Mounted %d addons!", amtMounted)
		amtMounted = 0

		hook.Remove("Think", "WSMount_thxvalve")
	end)

	hook.Remove("Think", "WSMount_MountLogic")
end

function WSMount.PerformMount(force_remount, force_reload)
	if force_remount then
		for k,v in pairs(WSMount.Mounted) do
			WSMount.MountQueue[k] = v.FilePath
		end
	end

	if table.IsEmpty(WSMount.MountQueue) then return end -- u w0t

	if not preFixed then
		preMcore = GetConVar("gmod_mcore_test"):GetInt()
		preQueue = GetConVar("mat_queue_mode"):GetInt()
		preFixed = true
	end

	RunConsoleCommand("gmod_mcore_test", 0)
	RunConsoleCommand("mat_queue_mode", 0)

	WSMount.LockRender()

	-- this hook is removed in WSMount.ReleaseRender
	hook.Add("Think", "WSMount_MountLogic", function()
		if not WSMount.MountAllowed then return end -- not our time...

		local justMounted = {}

		-- locked a few frames down; should be able to mount safely now
		for k,v in pairs(WSMount.MountQueue) do
			WSMount.Log("Mounting addon '%s' (@ %s)...", k, v)
			local st1 = SysTime()
			local ok, cont = game.MountGMA(v)
			local st2 = SysTime()

			WSMount.Log("Mounted addon '%s' in %.2fs.", k, st2 - st1)

			if not ok then
				WSMount.LogError("	Mount unsuccessful! No clue why.") -- gmod isn't very helpful
			end

			WSMount.Mounted[k] = cont
			WSMount.MountQueue[k] = nil
			amtMounted = amtMounted + 1

			cont.FilePath = v
			justMounted[k] = cont
		end

		local refreshed = 0

		-- if forced to reload, reload ALL mounted items
		-- instead of what we just mounted
		for k, cont in pairs(force_reload and WSMount.Mounted or justMounted) do
			refreshed = refreshed + 1

			local st1 = SysTime()
			WSMount.RefreshContent(wsid, cont)
			local st2 = SysTime()

			cont.Reloaded = true -- this isn't used anymore xx

			WSMount.Log("Refreshed content for '%s' in %.2fs.", k, st2 - st1)
		end

		if not table.IsEmpty(WSMount.DLQueue) then
			-- we haven't downloaded everything; reloading now would be wasteful
			-- release render and do it after the rest is downloaded and mounted
			WSMount.ReleaseRender()
			return
		end

		-- nothing left to download & everything has been mounted (above)
		-- refresh all content so errors stop being errors, etc.

		WSMount.Log("Queue empty; reloading all materials!")

		WSMount.ReloadEngine()
		WSMount.ReleaseRender()
	end)
end

local function reqMount()
	hook.Add("RenderScreenspaceEffects", "WSMount_Fill", function()
		-- will only run when allowed to render (ie, not returning true from PrePrender)
		render.UpdateScreenEffectTexture()
	end)

	timer.Create("mount_delay", 3, 1, WSMount.PerformMount)
end

WSMount.GotAddons = WSMount.GotAddons or 0

-- going above 50 megs of addons awaiting mount will request mount
local MountSizeCap = 50 * 1024 * 1024

function WSMount.BeginMount(redownload)
	WSMount.Say("Beginning download of %d addons...", #WSMount.GetAddons())

	local awaitingMountSz = 0
	WSMount.GotAddons = 0

	for k,v in ipairs(WSMount.GetAddons()) do
		WSMount.Log("\tis %s (%s) mounted? %s", v, type(v), WSMount.Mounted[v])
		if redownload and WSMount.Mounted[v] then
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