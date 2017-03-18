AddCSLuaFile("cl_init.lua")
AddCSLuaFile("language.lua")
include("shared.lua")

util.AddNetworkString("hl_camera_key")

local ENT = ENT	-- so we can use ENT within hooks and functions
local dev = GetConVar("developer")
DEFINE_BASECLASS(ENT.Base)

-- The client is either probing us because it doesn't know which key is assigned to the camera
-- or it's telling us that it wants to assign a new key (or change the toggle setting)
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

function ENT:OnRemove()
	for _, ply in pairs(player.GetAll()) do
		if ply:GetViewEntity() == self then
			ply:SetViewEntity(nil)
		end
	end
end

function ENT:PhysicsUpdate(phys)
	-- If we're not being held by the physgun, we should be frozen.
	if not self:IsPlayerHolding() then
		phys:EnableMotion(false)
		phys:Sleep()
	end
end
