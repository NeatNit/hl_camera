AddCSLuaFile()
local ENT = ENT	-- so we can use ENT within hooks and functions
local dev = GetConVar("developer")

if CLIENT then
	-- custom language files are broken in addons! need to add them manually here until that's fixed... That also means no translations possible for now.
	language.Add("hl_camera.fov","FOV")
	language.Add("hl_camera.roll","Roll")
	language.Add("hl_camera.nearz","Near Z")
	language.Add("hl_camera.farz","Far Z")
end

ENT.Category = "HeavyLight"
ENT.Spawnable = true
ENT.Editable = true
ENT.PrintName = "Advanced Camera"

ENT.Base = "base_anim"
DEFINE_BASECLASS(ENT.Base)

function ENT:SetupDataTables()
	if dev:GetBool() then MsgN("SetupDataTables ", self) end
	self:NetworkVar("Float", 0, "FOV", { KeyName = "fov", Edit = { title = "#hl_camera.fov", type = "Float", order = 0, min = 0, max = 179.99 } } )
	self:NetworkVar("Float", 1, "NearZ", { KeyName = "nearz", Edit = { title = "#hl_camera.nearz", type = "Float", order = 1, min = 0, max = 1000000 } } )
	self:NetworkVar("Float", 2, "FarZ", { KeyName = "farz", Edit = { title = "#hl_camera.farz", type = "Float", order = 2, min = 0, max = 1000000 } } )
	self:NetworkVar("Float", 3, "Roll", { KeyName = "roll", Edit = { title = "#hl_camera.roll", type = "Float", order = 3, min = -180, max = 180 } } )
	if SERVER then self.PlayerBinds = {} end
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

	self:SetGravity(0)

	return BaseClass.Initialize(self)
end

function ENT:OnDuplicated(dupdata)
	if dev:GetBool() then
		PrintTable(dupdata)
		PrintTable(self.PlayerBinds)
	end
end

if SERVER then
	util.AddNetworkString("hl_camera_key")

	net.Receive("hl_camera_key", function(len, ply)
		-- when received on the server, it means the client is probing us because it doesn't know which key is assigned to the camera
		local camera = net.ReadEntity()
		camera:UpdatePlayer(ply)
	end)

	function ENT:UpdatePlayer(ply)
		-- gotta put it on the next Think, otherwise the net message is sent too early and received before the client has initialized the entity (in the case of calling this method immediately after spawning)
		timer.Simple(0, function()
			net.Start("hl_camera_key")
			net.WriteEntity(self)

			local steamid = ply:SteamID()
			if not self.PlayerBinds[steamid] then
				net.WriteInt(KEY_NONE, 10)
			else
				net.WriteInt(self.PlayerBinds[steamid].key, 10)
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

		if toggle then
			table.insert(self.PlayerBinds[steamid].impulse, numpad.OnDown(ply, key, "hl_camera_toggle", self))
		else
			table.insert(self.PlayerBinds[steamid].impulse, numpad.OnDown(ply, key, "hl_camera_on", self))
			table.insert(self.PlayerBinds[steamid].impulse, numpad.OnUp(ply, key, "hl_camera_off", self))
		end
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
	net.Receive("hl_camera_key", function(len)
		-- when received on the client, we are being updated with a new key
		local camera = net.ReadEntity()
		local key = net.ReadInt(10)

		camera.AssignedKey = key
	end)

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

		if self.AssignedKey and self.AssignedKey ~= KEY_NONE then
			-- temporary!
			local screenpos = self:GetPos():ToScreen()
			cam.Start2D()
				draw.DrawText(language.GetPhrase(input.GetKeyName(self.AssignedKey)), nil, screenpos.x, screenpos.y, Color(0, 255, 0), TEXT_ALIGN_CENTER)
			cam.End2D()
		end
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
		local viewent = ply:GetViewEntity()
		if IsValid(viewent) and viewent:GetClass() == ENT.ClassName then
			return viewent:CalcView(ply, ...)
		end
	end)
end
