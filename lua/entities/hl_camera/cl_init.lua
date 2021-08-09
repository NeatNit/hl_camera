include("shared.lua")
include("cl_properties.lua")
include("projection_enum.lua")

local ENT = ENT	-- so we can use ENT within hooks and functions
local trapping_camera

net.Receive("hl_camera_key", function(len)
	-- we are being updated with a new key
	local camera = net.ReadEntity()
	if not IsValid(camera) or camera:GetClass() ~= ENT.ClassName or not camera.AssignedKey then return end

	camera.AssignedKey.key = net.ReadInt(10)
	camera.AssignedKey.toggle = net.ReadBool()

	camera:UpdateText()
end)

function ENT:UpdateText()
	local keyname = input.GetKeyName(self.AssignedKey.key)
	self.AssignedKey.text = keyname and language.GetPhrase(keyname)
end

function ENT:GetText()
	if trapping_camera == self then return "#hl_camera.assign.instruction" end
	return self.AssignedKey.text or "#hl_camera.unassigned"
end

function ENT:StartSetNewKey()
	trapping_camera = self
	if not input.IsKeyTrapping() then input.StartKeyTrapping() end
end

function ENT:Think()
	if trapping_camera == self and input.IsKeyTrapping() then
		local key = input.CheckKeyTrapping()
		if key then
			if key ~= KEY_ESCAPE then
				net.Start("hl_camera_key")
				net.WriteEntity(self)
				net.WriteInt(key, 10)
				net.WriteBool(self.AssignedKey.toggle)
				net.SendToServer()

				-- change the setting internally, just so the checkbox appears correct if you right-click very fast after toggling (i.e. before the server updated us)
				self.AssignedKey.key = key
				self:UpdateText()
			end

			trapping_camera = nil
		end
	end
end

function ENT:Draw()
	-- obey cl_drawcameras that is used in vanilla cameras
	if not cvars.Bool("cl_drawcameras", true) then return end

	-- don't draw cameras while looking through another camera
	if GetViewEntity():GetClass() == ENT.ClassName then return end

	-- don't draw cameras while using the camera swep
	local wep = LocalPlayer():GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == "gmod_camera" then return end

	-- in all other cases, draw
	self:DrawModel()
end

-- draw the label, if we're looking at this camera
function ENT:DrawTranslucent()
	-- obey cl_drawcameras that is used in vanilla cameras
	if not cvars.Bool("cl_drawcameras", true) then return end

	-- keep track of the last time the player wasn't looking directly at us
	if LocalPlayer():GetEyeTrace().Entity ~= self or not self.StartLookTime then
		self.StartLookTime = RealTime()
	end

	-- must be aiming at this camera for at least some time
	-- always draw label if we are trapping
	if trapping_camera ~= self and RealTime() < self.StartLookTime + 0.7 then return end

	local screenpos = self:GetPos():ToScreen()
	if not screenpos.visible then return end

	cam.Start2D()
		surface.SetFont("DermaDefaultBold")
		local w, h = surface.GetTextSize(self:GetText())
		screenpos.x = screenpos.x - (w / 2)
		screenpos.y = screenpos.y - (h / 2)

		local verts = {
			{ x = screenpos.x + w, y = screenpos.y - 2 },
			{ x = screenpos.x + w + 3, y = screenpos.y },
			{ x = screenpos.x + w + 3, y = screenpos.y + h },
			{ x = screenpos.x + w, y = screenpos.y + h + 2 },
			{ x = screenpos.x, y = screenpos.y + h + 2 },
			{ x = screenpos.x - 3, y = screenpos.y + h },
			{ x = screenpos.x - 3, y = screenpos.y },
			{ x = screenpos.x, y = screenpos.y - 2 }
		}

		surface.SetDrawColor(220, 220, 220)
		draw.NoTexture()
		surface.DrawPoly(verts)

		surface.SetTextPos(screenpos.x, screenpos.y)
		surface.SetTextColor(10, 10, 10)
		surface.DrawText(self:GetText())
	cam.End2D()
end

function ENT:CalcView(ply, origin, angles, fov, znear, zfar)
	local view = {
		origin = self:GetPos() + (self:LocalToWorld(self:GetViewOffset()) - self:GetPos()), -- probably there must be a simpler way to get local coordinates
		angles = self:GetAngles() + Angle(0, 0, self:GetRoll()),
		znear = self:GetNearZ() > 0 and self:GetNearZ() or znear,
		zfar = self:GetFarZ() > 0 and self:GetFarZ() or zfar,
		fov = self:GetFOV() > 0 and self:GetFOV() or fov
	}

	if view.znear <= 0 then view.znear = znear end
	if view.zfar <= 0 then view.zfar = zfar end
	if view.fov <= 0 then view.fov = fov end

	return view
end

hook.Add("CalcView", ENT.Folder, function(ply, ...)
	local camera = ply:GetViewEntity()
	if IsValid(camera) and camera:GetClass() == ENT.ClassName then
		return camera:CalcView(ply, ...)
	end
end)
