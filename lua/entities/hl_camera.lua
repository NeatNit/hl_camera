AddCSLuaFile()
local ENT = ENT	-- so we can use ENT within hooks and functions
local dev = GetConVar("developer")

ENT.Category = "HeavyLight"
ENT.Spawnable = true
ENT.Editable = true
ENT.PrintName = "Advanced Camera"

ENT.Base = "base_anim"
DEFINE_BASECLASS(ENT.Base)
ENT.RenderGroup = RENDERGROUP_BOTH

if CLIENT then
	-- custom language files are broken in addons! need to add them manually here until that's fixed... That also means no translations possible for now.
	language.Add("hl_camera.fov", "FOV")
	language.Add("hl_camera.roll", "Roll")
	language.Add("hl_camera.nearz", "Near Z")
	language.Add("hl_camera.farz", "Far Z")
	language.Add("hl_camera.unassigned", "Unassigned")
end

function ENT:SetupDataTables()
	if dev:GetBool() then MsgN("SetupDataTables ", self) end
	self:NetworkVar("Float", 0, "FOV", { KeyName = "fov", Edit = { title = "#hl_camera.fov", type = "Float", order = 0, min = 0, max = 179.99 } } )
	self:NetworkVar("Float", 1, "NearZ", { KeyName = "nearz", Edit = { title = "#hl_camera.nearz", type = "Float", order = 1, min = 0, max = 1000000 } } )
	self:NetworkVar("Float", 2, "FarZ", { KeyName = "farz", Edit = { title = "#hl_camera.farz", type = "Float", order = 2, min = 0, max = 1000000 } } )
	self:NetworkVar("Float", 3, "Roll", { KeyName = "roll", Edit = { title = "#hl_camera.roll", type = "Float", order = 3, min = -180, max = 180 } } )

	-- initialize our required table
	if SERVER then self.PlayerBinds = {} else self.AssignedKey = {} end
end

function ENT:Initialize()
	if dev:GetBool() then MsgN("Initialize ", self) end
	self:SetModel("models/dav0r/camera.mdl")

	-- I don't actually understand how these work
	self:SetMoveType(MOVETYPE_VPHYSICS)
	if SERVER then
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
	end

	-- Check in 1 second whether a key has been assigned to us. If not, ask the server what's going on!
	if CLIENT then
		timer.Simple(1, function()
			if IsValid(self) and self.AssignedKey.key == nil then
				net.Start("hl_camera_key")
				net.WriteEntity(self)
				net.SendToServer()
			end
		end)
	end

	self:SetGravity(0)

	return BaseClass.Initialize(self)
end

function ENT:OnDuplicated(dupdata)
	if dev:GetBool() then MsgN("OnDuplicated ", self) end

	-- don't actually want to inherit the player binds table
	table.Empty(self.PlayerBinds)

	-- but in singleplayer we want to recreate it
	if game.SinglePlayer() then
		for steamid, info in pairs(dupdata.PlayerBinds) do
			local ply = player.GetBySteamID(steamid)
			if dev:GetBool() then MsgN("OnDuplicated ", self, " ", steamid, " ", ply) end
			if IsValid(ply) then
				self:SetPlayerKey(ply, info.key, info.toggle)
			end
		end
	end
end

function ENT:PostEntityPaste(...)
	if dev:GetBool() then MsgN("PostEntityPaste ", self, ...) end
end

if SERVER then
	util.AddNetworkString("hl_camera_key")

	-- when received on the server, it means the client is probing us because it doesn't know which key is assigned to the camera
	-- this is currently unused until I find a reason for the client to ask the server for a forced update
	net.Receive("hl_camera_key", function(len, ply)
		local camera = net.ReadEntity()

		if len <= 16 then
			camera:UpdatePlayer(ply)
			return
		end

		local key = net.ReadInt(10)
		local toggle = net.ReadBool()
		camera:SetPlayerKey(ply, key, toggle)
	end)


	-- Send the
	function ENT:UpdatePlayer(ply)
		-- gotta give it a small delay, otherwise the net message is sent too early
		-- and received before the client has initialized the entity
		-- (in the case of calling this method immediately after spawning)
		timer.Simple(0.1, function()
			net.Start("hl_camera_key")
			net.WriteEntity(self)

			local steamid = ply:SteamID()
			if not self.PlayerBinds[steamid] then
				net.WriteInt(KEY_NONE, 10)
				net.WriteBool(false)
			else
				net.WriteInt(self.PlayerBinds[steamid].key, 10)
				net.WriteBool(self.PlayerBinds[steamid].toggle)
			end
			net.Send(ply)
		end)
	end

	-- register numpad functions
	numpad.Register("hl_camera_on", function(ply, camera)
		if not IsValid(camera) then return false end
		ply:SetViewEntity(camera)
	end)
	numpad.Register("hl_camera_off", function(ply, camera)
		if not IsValid(camera) then return false end
		if ply:GetViewEntity() == camera then ply:SetViewEntity(nil) end
	end)
	numpad.Register("hl_camera_toggle", function(ply, camera)
		if not IsValid(camera) then return false end
		if ply:GetViewEntity() == camera then
			ply:SetViewEntity(nil)
		else
			ply:SetViewEntity(camera)
		end
	end)

	-- lookup table for each player's assigned camera for a certain key
	-- saved globally to stop glitches during development
	HL_CAMERA_PKC = HL_CAMERA_PKC or {}
	local PlayerKeyCamera = HL_CAMERA_PKC

	function ENT:SetPlayerKey(ply, key, toggle)
		steamid = ply:SteamID()	-- get player's SteamID

		-- remove the existing bind for this player for this camera, if one exists
		if self.PlayerBinds[steamid] then

			for _, impulseID in ipairs(self.PlayerBinds[steamid].impulse) do
				numpad.Remove(impulseID)
			end

			-- remove from tracking table and our own table
			local oldkey = self.PlayerBinds[steamid].key
			PlayerKeyCamera[steamid][oldkey] = nil
			self.PlayerBinds[steamid] = nil
		end

		if	-- validity check. if key isn't a valid key, just unbind the camera.
			not key
			or key < KEY_FIRST
			or key == KEY_NONE
			or key > BUTTON_CODE_LAST
		then
			-- make sure player isn't stuck viewing through us
			if ply:GetViewEntity() == self then ply:SetViewEntity(nil) end

			self:UpdatePlayer(ply)
			return
		end

		-- make sure we have this player in our lookup table
		PlayerKeyCamera[steamid] = PlayerKeyCamera[steamid] or {}

		-- If the player has another camera assigned to this key, unassign it
		if IsValid(PlayerKeyCamera[steamid][key]) then
			PlayerKeyCamera[steamid][key]:SetPlayerKey(ply, nil)
		end

		-- Assign the player
		toggle = tobool(toggle)	-- don't want nil or non-boolean crap
		self.PlayerBinds[steamid] = {}
		self.PlayerBinds[steamid].key = key
		self.PlayerBinds[steamid].toggle = toggle
		self.PlayerBinds[steamid].impulse = {}
		PlayerKeyCamera[steamid][key] = self

		timer.Simple(0.1, function()
			if toggle then
				table.insert(self.PlayerBinds[steamid].impulse, numpad.OnDown(ply, key, "hl_camera_toggle", self))
			else
				table.insert(self.PlayerBinds[steamid].impulse, numpad.OnDown(ply, key, "hl_camera_on", self))
				table.insert(self.PlayerBinds[steamid].impulse, numpad.OnUp(ply, key, "hl_camera_off", self))
			end
		end)
		self:UpdatePlayer(ply)
	end
end

function ENT:OnRemove()
	if (IsValid(self.UsingPlayer)) then
		self.UsingPlayer:SetViewEntity(nil)
	end
end

function ENT:PhysicsUpdate(phys)
	-- If we're not being held by the physgun, we should be frozen.
	if not self:IsPlayerHolding() then
		phys:EnableMotion(false)
		phys:Sleep()
	end
end

if CLIENT then
	local trapping_camera
	net.Receive("hl_camera_key", function(len)
		-- we are being updated with a new key
		local camera = net.ReadEntity()
		if not IsValid(camera) or camera:GetClass() ~= ENT.ClassName then return end

		camera.AssignedKey.key = net.ReadInt(10)
		camera.AssignedKey.toggle = net.ReadBool()

		camera:UpdateText()
	end)

	function ENT:UpdateText()
		local keyname = input.GetKeyName(self.AssignedKey.key)
		self.AssignedKey.text = keyname and language.GetPhrase(keyname)
	end

	function ENT:GetText()
		if trapping_camera == self then return "Press any key" end
		return self.AssignedKey.text or "#hl_camera.unassigned"
	end

	function ENT:StartSetNewKey()
		if IsValid(trapping_camera) then
			trapping_camera:CancelSetNewKey()
		end

		trapping_camera = self
		if not input.IsKeyTrapping() then input.StartKeyTrapping() end
	end

	function ENT:CancelSetNewKey()

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

		if not self.StartLookTime or (LocalPlayer():GetEyeTrace().Entity ~= self and trapping_camera ~= self) then
			self.StartLookTime = RealTime()
			return
		end

		-- must be aiming at this camera for at least 0.7 second
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
			origin = self:GetPos(),
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
end

-- add properties to change assignment
local property

-- Toggle checkbox
property = {
	Type = "toggle",
	MenuLabel = "Toggle",
	Order = 100000	-- I guess? it goes at the bottom anyway no matter what I put here :/
}

function property:Filter(ent)
	return IsValid(ent) and ent:GetClass() == ENT.ClassName
end

function property:Checked(camera)
	return camera.AssignedKey.toggle or false
end

function property:Action(camera)
	if not IsValid(camera) then return end

	net.Start("hl_camera_key")
	net.WriteEntity(camera)
	net.WriteInt(camera.AssignedKey.key, 10)
	net.WriteBool(not camera.AssignedKey.toggle)
	net.SendToServer()

	-- change the setting internally, just so the checkbox appears correct if you right-click very fast after toggling (i.e. before the server updated us)
	camera.AssignedKey.toggle = not camera.AssignedKey.toggle
end

properties.Add( ENT.Folder .. "ToggleToggle", property)

-- Reassign key
property = {
	MenuLabel = "Assign Key",
	Order = 1,	-- should appear first
	MenuIcon = "icon16/keyboard.png"
}

function property:Filter(ent)
	return IsValid(ent) and ent:GetClass() == ENT.ClassName
end

function property:Action(camera)
	if not IsValid(camera) then return end

	camera:StartSetNewKey()
end

properties.Add( ENT.Folder .. "AssignKey", property)
