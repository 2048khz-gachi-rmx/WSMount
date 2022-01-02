-- no libs as dependencies on my watch,,,,

local FRAME = {}

local greyed = Color(80, 80, 80)

local borderWide = Color(0, 0, 0, 150)
local border = Color(10, 10, 10)

local close_hov = Color(235, 90, 90)
local close_unhov = Color(205, 50, 50)

local function LC(col, dest, vel)
	local v = vel or 10
	if not IsColor(col) or not IsColor(dest) then return end

	col.r = Lerp(FrameTime() * v, col.r, dest.r)
	col.g = Lerp(FrameTime() * v, col.g, dest.g)
	col.b = Lerp(FrameTime() * v, col.b, dest.b)

	if dest.a ~= col.a then
		col.a = Lerp(FrameTime() * v, col.a, dest.a)
	end

	return col
end

function FRAME:Init()
	self:SetSize(128, 128)
	self:Center()
	self:SetTitle("")
	self:ShowCloseButton(false)

	local w = self:GetWide()

	local b = vgui.Create("DButton", self)
	self.CloseButton = b
	b:SetPos(w - 64 - 4, 4)
	b:SetSize(64, 20) --28)
	b:SetText("")
	b.Color = Color(205, 50, 50)

	function b:Paint(w, h)
		b.Color = LC(b.Color,
			(self.PreventClosing and greyed) or (self:IsHovered() and close_hov) or close_unhov, 15)
		draw.RoundedBox(4, 0, 0, w, h, b.Color)
	end

	b.DoClick = function()
		if self.PreventClosing then return end

		local ret = self:OnClose()
		if ret == false then return end

		if self:GetDeleteOnClose() then
			self:Remove()
		else
			self:Hide()
		end
	end

	self.m_bCloseButton = b

	self.HeaderSize = 24 --32

	-- gmod dframes have a 24px draggable header hardcoded
	-- im not copypasting the entire Think for proper headers, not here

	self.BackgroundColor = Color(50, 50, 50)
	self.HeaderColor = Color(40, 40, 40, 255)

	self:DockPadding(4, self.HeaderSize + 4, 4, 4)
end

function FRAME:OnClose() end

function FRAME:PerformLayout()
	if not self.m_bCloseButton then return end

	self.m_bCloseButton:SetPos(self:GetWide() - self.m_bCloseButton:GetWide() - 4, 2)
end

function FRAME.DrawHeaderPanel(self, w, h, x, y)
	local rad = 4

	local hc = self.HeaderColor
	local bg = self.BackgroundColor

	x = x or 0
	y = y or 0

	local hh = self.HeaderSize
	local tops = true

	-- add a cheap fuckoff border cuz no shadows
	local bSz = 2

	local p = DisableClipping(true)
		draw.RoundedBoxEx(rad, x - bSz, y - bSz, w + bSz * 2, h + bSz * 2, borderWide, tops, tops, true, true)
		bSz = bSz / 2
		draw.RoundedBoxEx(rad, x - bSz, y - bSz, w + bSz * 2, h + bSz * 2, border, tops, tops, true, true)
	if not p then DisableClipping(false) end

	if hh > 0 then
		draw.RoundedBoxEx(self.HRBRadius or rad, x, y, w, hh, hc, true, true)
		tops = false
	end

	draw.RoundedBoxEx(rad, x, y + hh, w, h - hh, bg, tops, tops, true, true)
end

function FRAME:Paint(w, h)
	return self:DrawHeaderPanel(w, h)
end

vgui.Register("WSM_Frame", FRAME, "DFrame")