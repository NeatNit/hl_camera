include("shared.lua")

local function CheckIfCanDraw() -- copypasted from the advcamera
	-- obey cl_drawcameras that is used in vanilla cameras
	if not cvars.Bool("cl_drawcameras", true) then return false end

	-- don't draw cameras while looking through another camera
	if GetViewEntity():GetClass() == "hl_camera" then return false end

	-- don't draw cameras while using the camera swep
	local wep = LocalPlayer():GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == "gmod_camera" then return false end

	return true
end

function ENT:DrawTranslucent()
	if not CheckIfCanDraw() then return end

	-- in all other cases, draw
	self:DrawModel()
end