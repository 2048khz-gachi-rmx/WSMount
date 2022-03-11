-- e

local WaitingList = false

local function tryOpen(ply)
	local has_access = WSMount.CanManage(ply)

	if not has_access then
		ply:ChatPrint("No access!")
		return
	end

	gui.HideGameUI()

	net.Start("WSMount_RequestList")
		net.WriteBool(false)
	net.SendToServer()

	WaitingList = true
end

concommand.Add("wsmount_settings", function(...) tryOpen(...) end)

hook.Add("WSMount_ListReceived", "WSMount_DoOpen", function()
	if not WaitingList then return end
	WSMount.OpenSettingsGUI()
	WaitingList = false
end)

surface.CreateFont("WSMount_Title", {
	font = "Roboto",
	size = 24,
	weight = 400,
})

surface.CreateFont("WSMount_Text", {
	font = "Roboto",
	size = 18,
	weight = 400,
})

surface.CreateFont("WSMount_SmallText", {
	font = "Roboto",
	size = 14,
	weight = 400,
})

local function Ease(num, how) --garry easing
	num = math.Clamp(num, 0, 1)
	local Frac = 0

	if ( how < 0 ) then
		Frac = num ^ ( 1.0 - ( num - 0.5 ) ) ^ -how
	elseif ( how > 0 and how < 1 ) then
		Frac = 1 - ( ( 1 - num ) ^ ( 1 / how ) )
	else --how > 1 = ease in
		Frac = num ^ how
	end

	return Frac
end

local function LerpColor(frac, col, dest, src)
	col.r = Lerp(frac, src.r, dest.r)
	col.g = Lerp(frac, src.g, dest.g)
	col.b = Lerp(frac, src.b, dest.b)

	local sA, c1A, c2A = src.a, col.a, dest.a

	if sA ~= c2A or c1A ~= c2A then
		col.a = Lerp(frac, sA, c2A)
	end
end

local active_shine = Color(60, 160, 255)
local active = Color(35, 120, 205)
local inactive = Color(70, 70, 70)

local inactive_tx = Color(150, 150, 150)
local active_tx = color_white

function WSMount.OpenWorkshop()
	if IsValid(WSMount.HTML) then return end

	local f = vgui.Create("WSM_Frame")
	WSMount.HTML = f

	local fw, fh = ScrW() * 0.85, ScrH() * 0.9

	f:SetSize(fw, fh)
	f:Center()
	f:MakePopup()

	f:SetAlpha(0)
	f:AlphaTo(255, 0.1, 0)

	f:SetY(f:GetY() + 24)
	f:MoveBy(0, -24, 0.4, 0, 0.15)

	local ctrl_canv = vgui.Create("DPanel", f)
	function ctrl_canv:Paint() end
	ctrl_canv:Dock(TOP)
	ctrl_canv:SetTall(36)
	ctrl_canv:DockMargin(8, 0, 8, 0)

	local req = vgui.Create("DButton", ctrl_canv)
	req:Dock(RIGHT)
	req:SetSize(f:GetWide() * 0.2, ctrl_canv:GetTall())
	req:SetText("Use Addon")
	req:DockMargin(0, 0, 0, 0)
	req:SetFont("WSMount_Title")

	local ctrl = vgui.Create("DHTMLControls", ctrl_canv)
	ctrl:Dock(FILL)

	local html = vgui.Create("DHTML", f)
	html:Dock(FILL)
	html:OpenURL("https://steamcommunity.com/app/4000/workshop/")
	ctrl:SetHTML(html)
	ctrl:DockPadding(0, 0, 16, 0)
	-- hack to stop it from saying gorjle
	ctrl.AddressBar:SetText("https://steamcommunity.com/app/4000/workshop/")
	function req:Think()
		local url = ctrl.AddressBar:GetText()
		local wsid = url and url:match("filedetails/%?id=(%d+)") -- no steamcommunity.com check waa waa

		if not wsid then
			self:SetEnabled(false)
		else
			self:SetEnabled(true)
			self.WSID = wsid
		end
	end

	local cur = Color(70, 70, 70)

	function req:Paint(w, h)
		if not self:IsEnabled() then
			draw.RoundedBoxEx(8, 0, 0, w, h, inactive, false, true, false, false)
			self:SetTextColor(inactive_tx)
		else
			local fr = (SysTime() % 1)
			LerpColor(fr, cur, active, active_shine)

			draw.RoundedBoxEx(8, 0, 0, w, h, cur, false, true, false, false)
			self:SetTextColor(active_tx)
		end
	end

	function req:DoClick()
		net.Start("WSMount_UpdateAddon")
			net.WriteBool(false)
			net.WriteDouble(self.WSID)
			net.WriteBool(true)
		net.SendToServer()

		self:SetText("Added!")
		surface.PlaySound("buttons/button14.wav")

		timer.Create("WSMount_ChangeBtnText", 2, 1, function()
			if IsValid(self) then
				self:SetText("Use Addon")
			end
		end)
	end
end

local gu = Material("vgui/gradient-u")
local gd = Material("vgui/gradient-d")
local gr = Material("vgui/gradient-r")
local gl = Material("vgui/gradient-l")

local bgCol = Color(60, 60, 60)

local grUnhovCol = Color(70, 70, 70)
local grCol = Color(70, 70, 70)
local grHovCol = Color(75, 90, 110)
local binW = 36

local function hovLogic(self)
	local hf = self.HovFrac or 0

	if self:IsHovered() then
		self.HovFrac = math.min(1, hf + FrameTime() * 4)
		hf = Ease(self.HovFrac, 0.2)
	else
		self.HovFrac = math.max(0, hf - FrameTime() * 1.5)
		hf = Ease(self.HovFrac, 2.5)
	end

	return hf
end

local function addonPaint(self, w, h)
	local hf = hovLogic(self)

	local binW = self.CanDelete and binW or 0

	surface.SetDrawColor(bgCol)
	surface.DrawRect(0, 0, w - binW, h)

	local gSz = math.floor(h * (0.4 + hf * 0.1) / 2)
	local src = 150
	grCol.a = src + (255 - src) * hf
	LerpColor(hf, grCol, grHovCol, grUnhovCol)

	surface.SetDrawColor(grCol)
	surface.SetMaterial(gu)
	surface.DrawTexturedRect(0, 0, w - binW, gSz)

	surface.SetMaterial(gd)
	surface.DrawTexturedRect(0, h - gSz, w - binW, gSz)
end

local binHovCol = Color(200, 50, 50)
local binCol = Color(150, 40, 40)

local binIcon = Material("wsmount/trash.png")

local function makeDel(wsid, pnl)
	local in_the_bin = vgui.Create("DButton", pnl)
	in_the_bin:Dock(RIGHT)
	in_the_bin:SetSize(binW)
	in_the_bin:SetText("")

	local hovF = 0

	function in_the_bin:Paint(w, h)
		local hf = hovLogic(self)
		local rnd = 8
		draw.RoundedBoxEx(rnd, 0, 0, w, h,
			self:IsHovered() and binHovCol or binCol, false, true, false, true)

		render.PushFilterMin(TEXFILTER.ANISOTROPIC)
		render.PushFilterMag(TEXFILTER.ANISOTROPIC)
			surface.SetMaterial(binIcon)
			surface.SetDrawColor(255, 255, 255)
			surface.DrawTexturedRectRotated(w / 2, h / 2, 24 + 4 * hf, 24 + 4 * hf, hf * 8)
		render.PopFilterMin()
		render.PopFilterMag()
	end

	function in_the_bin:DoClick()
		net.Start("WSMount_UpdateAddon")
			net.WriteBool(false)
			net.WriteDouble(wsid)
			net.WriteBool(false)
		net.SendToServer()
	end
end

local function makeAdd(wsid, pnl)
	local in_the_bin = vgui.Create("DButton", pnl)
	in_the_bin:Dock(RIGHT)
	in_the_bin:SetSize(binW)
	in_the_bin:SetText("")

	local hovF = 0

	function in_the_bin:Paint(w, h)
		local hf = hovLogic(self)
		local rnd = 8
		draw.RoundedBoxEx(rnd, 0, 0, w, h,
			self:IsHovered() and active_shine or active, false, true, false, true)

		draw.SimpleText("+", "DermaLarge", w / 2, h / 2, color_white,
			TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end

	function in_the_bin:DoClick()
		net.Start("WSMount_UpdateAddon")
			net.WriteBool(false)
			net.WriteDouble(wsid)
			net.WriteBool(true)
		net.SendToServer()
	end
end

local function createAddon(scr, wsid, insta, canDel)
	canDel = canDel == nil or canDel

	local pnl = vgui.Create("DPanel", scr)
	pnl:SetTall(44)
	pnl:Dock(TOP)
	pnl:DockMargin(0, 1, 2, 0)

	pnl.Paint = addonPaint
	pnl.CanDelete = true -- canDel

	local icon = vgui.Create("DImageButton", pnl)
	icon:Dock(LEFT)
	icon:SetSize(pnl:GetTall(), pnl:GetTall())

	function icon:DoClick()
		gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=" .. wsid)
	end

	local nm = vgui.Create("DLabel", pnl)
	nm:SetPos(icon:GetWide() + 4, 2)
	nm:SetText("loading name...")
	nm:SetFont("WSMount_Text")

	local sz = vgui.Create("DLabel", pnl)
	sz:SetPos(icon:GetWide() + 4, 2)
	sz:SetFont("WSMount_SmallText")
	sz:SetText("loading size...")

	nm:SizeToContents()
	sz:SizeToContents()

	local total = nm:GetTall() + sz:GetTall() + 2
	local startY = math.floor( (pnl:GetTall() - total) / 2 )
	nm:SetY(startY)
	sz:SetY(startY + nm:GetTall() + 2)

	steamworks.FileInfo(wsid, function(info)
		if not IsValid(nm) then return end

		nm:SetText(info.title)
		sz:SetText(string.NiceSize(info.size))

		nm:SizeToContents()
		sz:SizeToContents()
		steamworks.Download(info.previewid, true, function(path)
			local icMat = AddonMaterial(path)
			icon:SetMaterial(icMat)
		end)
	end)

	if canDel then
		makeDel(wsid, pnl)
	else
		makeAdd(wsid, pnl)
	end

	function pnl:Disappear()
		self:SizeTo(self:GetWide(), 0, 0.3, 0, 0.3, function()
			self:Remove()
		end)
		surface.PlaySound("garrysmod/balloon_pop_cute.wav")
	end

	return pnl
end

local steam = Material("wsmount/steam32.png")
local paper = Material("wsmount/paper32.png") -- 26x32

function WSMount.OpenSettingsGUI()
	local f = vgui.Create("WSM_Frame")
	local h = math.min(ScrH() * 0.6, 500)

	f:SetSize(400, h)
	f:Center()
	f:MakePopup()

	f:SetAlpha(0)
	f:AlphaTo(255, 0.1, 0)

	-- move right to left
	f:SetX(f:GetX() + 16)
	f:MoveBy(-16, 0, 1.2, 0, 0.1)

	function f:OnRemove()
		net.Start("WSMount_UpdateAddon")
			net.WriteBool(true) -- tell the server to broadcast mount command
		net.SendToServer()
	end

	local lbl = vgui.Create("DLabel", f)
	lbl:Dock(TOP)
	lbl:SetText("Workshop Mounter Settings")
	lbl:SetFont("WSMount_Title")
	lbl:SizeToContents()
	lbl:SetContentAlignment(5)
	lbl:DockMargin(0, 4, 0, 8)

	local btns = vgui.Create("DPanel", f)
	btns:Dock(BOTTOM)
	btns:SetTall(40)
	function btns:Paint() end

	local web = vgui.Create("DButton", btns)
	web:Dock(RIGHT)
	web:SetSize(32, 32)
	local w, h = web:GetSize()
	local s, v = 4, (btns:GetTall() - h) / 2
	web:DockMargin(s, v, s, v)
	web.DoClick = function() WSMount.OpenWorkshop() end -- autorefresh
	web:SetText("")

	function web:Paint(w, h)
		surface.SetMaterial(steam)
		surface.SetDrawColor(255, 255, 255)
		surface.DrawTexturedRect(0, 0, w, h)
	end

	local caught = vgui.Create("DButton", btns)
	caught:Dock(RIGHT)
	caught:SetSize(32, 32)
	caught:DockMargin(s, v, s, v)
	caught:SetText("")

	function caught:Paint(w, h)
		surface.SetMaterial(paper)
		surface.SetDrawColor(255, 255, 255)
		surface.DrawTexturedRect(w / 2 - 26 / 2, 0, 26, h)
	end

	function caught:DoClick()
		net.Start("WSMount_RequestList")
			net.WriteBool(true)
		net.SendToServer()

		self:SetEnabled(false)
		timer.Simple(1, function()
			if IsValid(self) then self:SetEnabled(true) end
		end)

		hook.Add("WSMount_ProbedListReceived", caught, function()
			WSMount.OpenProbedGUI()
		end)
	end

	local scr = vgui.Create("WSScrollPanel", f)
	scr:Dock(FILL)
	scr:DockMargin(0, 0, 0, 4)
	scr:GetCanvas():DockPadding(0, 1, 0, 0)

	local IDToBtn = {}

	for _, wsid in ipairs(WSMount.Addons) do
		IDToBtn[wsid] = createAddon(scr, wsid, true)
	end


	hook.Add("WSMount_RemovedAddon", f, function(_, wsid)
		if IDToBtn[wsid] then
			IDToBtn[wsid]:Disappear()
			IDToBtn[wsid] = nil
		end
	end)

	hook.Add("WSMount_AddedAddon", f, function(_, wsid)
		if not IDToBtn[wsid] then
			IDToBtn[wsid] = createAddon(scr, wsid, true)
		end
	end)

end

function WSMount.OpenProbedGUI()
	local f = vgui.Create("WSM_Frame")
	local h = math.min(ScrH() * 0.6, 500)

	f:SetSize(400, h)
	f:Center()
	f:MakePopup()

	f:SetAlpha(0)
	f:AlphaTo(255, 0.1, 0)

	f:SetX(f:GetX() + f:GetWide() / 3)
	f:MoveBy(f:GetWide() / 6, 0, 0.6, 0, 0.3)

	local lbl = vgui.Create("DLabel", f)
	lbl:Dock(TOP)
	lbl:SetText("Caught Workshop Addons")
	lbl:SetFont("WSMount_Title")
	lbl:SizeToContents()
	lbl:SetContentAlignment(5)
	lbl:DockMargin(0, 4, 0, 8)

	local addAll = vgui.Create("DButton", f)
	addAll:Dock(BOTTOM)
	addAll:DockMargin(32, 0, 32, 4)
	addAll:SetTall(32)
	addAll:SetText("Add All")
	addAll:SetFont("WSMount_Title")
	addAll:SetTextColor(active_tx)

	local cur = Color(0, 0, 0)

	function addAll:Paint(w, h)
		local hfr = hovLogic(self)
		LerpColor(hfr, cur, active_shine, active)
		draw.RoundedBoxEx(8, 0, 0, w, h, cur, false, false, true, true)
	end

	local IDToBtn = {}

	function addAll:DoClick()
		local toAdd = table.Copy(WSMount.CaughtAddons)
		local cur = 1

		local function doTimer()
			if not toAdd[cur] then return end

			timer.Simple(0.1, function()
				net.Start("WSMount_UpdateAddon")
					net.WriteBool(false)
					net.WriteDouble(toAdd[cur])
					net.WriteBool(true)
				net.SendToServer()

				if IDToBtn[toAdd[cur]] then
					IDToBtn[toAdd[cur]]:Disappear()
					IDToBtn[toAdd[cur]] = nil
				end

				cur = cur + 1
				doTimer()
			end)
		end

		doTimer()
	end

	local scr = vgui.Create("WSScrollPanel", f)
	scr:Dock(FILL)
	scr:DockMargin(0, 0, 0, 0)
	scr:GetCanvas():DockPadding(0, 1, 0, 0)

	for _, wsid in ipairs(WSMount.GetCaughtAddons()) do
		-- lazy & unoptimized but w/e, not like this runs too often
		if table.HasValue(WSMount.GetAddons(), wsid) then continue end

		IDToBtn[wsid] = createAddon(scr, wsid, true, false)
	end

	hook.Add("WSMount_AddedAddon", f, function(_, wsid)
		if IDToBtn[wsid] then
			IDToBtn[wsid]:Disappear()
			IDToBtn[wsid] = nil
		end
	end)
end