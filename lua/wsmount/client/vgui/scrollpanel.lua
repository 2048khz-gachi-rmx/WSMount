--[[-------------------------------------------------------------------------
--  FScrollPanel
---------------------------------------------------------------------------]]
local gu = Material("vgui/gradient-u")
local gd = Material("vgui/gradient-d")
local gr = Material("vgui/gradient-r")
local gl = Material("vgui/gradient-l")

local FScrollPanel = {}

function FScrollPanel:Init()
	local scroll = self.VBar

	self.ScrollColor = Color(30, 30, 30)

	function scroll.Paint(me, w, h)
		draw.RoundedBox(4, 0, 0, w, h, self.ScrollColor)
	end

	scroll:SetWide(10)
	scroll.CurrentWheel = 0
	local grip = scroll.btnGrip
	local up = scroll.btnUp
	local down = scroll.btnDown

	self.GripColor = Color(60, 60, 60)
	self.ButtonColor = Color(80, 80, 80)

	function grip.Paint(me, w, h)
		draw.RoundedBox(4, 0, 0, w, h, self.GripColor)
	end

	function up.Paint(me, w, h)
		draw.RoundedBoxEx(4, 0, 0, w, h, self.ButtonColor, true, true)
	end

	function down.Paint(me, w, h)
		draw.RoundedBoxEx(4, 0, 0, w, h, self.ButtonColor, false, false, true, true)
	end

	self.pnlCanvas:SetName("FScrollPanel Canvas")

	self.GradBorder = true

	self.BorderColor = Color(20, 20, 20)
	self.BorderTH = 4
	self.BorderBH = 4
	self.BorderL = 4
	self.BorderR = 4

	self.RBRadius = 0

	self.BackgroundColor = Color(40, 40, 40)
end


function FScrollPanel:Draw(w, h)
	if self.NoDraw then return end

	local sx, sy = self:LocalToScreen(0, 0)

	local x, y = 0, 0

	draw.RoundedBox(self.RBRadius or 0, x, y, w, h, self.BackgroundColor)
end

function FScrollPanel:PaintOver(w, h)
	if self.GradBorder and not self.NoDraw then
		local bl, bt, br, bb = self:GetBorders()
		self:DrawBorder(w, h, bt, bb, br, bl)
	end
end

function FScrollPanel:PostPaint(w, h)
end

function FScrollPanel:PrePaint(w, h)
end

function FScrollPanel:Paint(w, h)
	self:PrePaint(w, h)
		self:Draw(w, h)
	self:PostPaint(w, h)
end

function FScrollPanel:DrawBorder(w, h, bt, bb, br, bl)
	--bt, bb, br, bl = border top, border bottom, etc...

	surface.SetDrawColor(self.BorderColor)

	if bt then
		surface.SetMaterial(gu)
		surface.DrawTexturedRect(0, 0, w, bt)
	end

	if bb then
		surface.SetMaterial(gd)
		surface.DrawTexturedRect(0, h - bb, w, bb)
	end

	if br then
		surface.SetMaterial(gr)
		surface.DrawTexturedRect(w - br, 0, br, h)
	end

	if bl then
		surface.SetMaterial(gl)
		surface.DrawTexturedRect(0, 0, bl, h)
	end

end

function FScrollPanel:GetBorders()
	local bb, bt = self.BorderBH, self.BorderTH
	local br, bl = self.BorderR, self.BorderL

	return bl, bt, br, bb
end

function FScrollPanel:SetBorders(bl, bt, br, bb)
	self.BorderBH = bb
	self.BorderTH = bt
	self.BorderR = br
	self.BorderL = bl
end

vgui.Register("WSScrollPanel", FScrollPanel, "DScrollPanel")