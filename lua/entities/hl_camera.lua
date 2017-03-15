AddCSLuaFile()
local ENT = ENT	-- so we can ENT within hooks and functions

ENT.Category = "HeavyLight"
ENT.Spawnable = true
ENT.Editable = true
ENT.PrintName = "Advanced Camera"

ENT.Base = "base_anim"
DEFINE_BASECLASS(ENT.Base)

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "NearZ", { KeyName = "nearz", Edit = { type = "Float", order = 1, min = 0, max = 1000000 } } )
	self:NetworkVar("Float", 1, "FarZ", { KeyName = "farz", Edit = { type = "Float", order = 2, min = 0, max = 1000000 } } )
	self:NetworkVar("Float", 2, "Roll", { KeyName = "roll", Edit = { type = "Float", order = 3, min = -180, max = 180 } } )
	self:NetworkVar("Float", 3, "FOV", { KeyName = "fov", Edit = { type = "Float", order = 4, min = 0, max = 179.99 } } )
end

ENT.NumpadRegisters = {}
function ENT:ReassignNumpad(whatchanged, old, new)
	if whatchanged ~= "duplicator" and old == new then return end

	local key = self:GetKey()
	local toggle = self:GetToggle()

	if whatchanged == "Key" then
		key = new
	elseif whatchanged == "Toggle" then
		toggle = new
	end

	-- remove old numpad registrations for this entity
	for k, v in pairs(self.NumpadRegisters) do
		numpad.Remove(v)
	end

	-- if key isn't a valid key, don't do anything else
	if key < KEY_FIRST then return end
	if key == KEY_NONE then return end

	-- Remove any previous camera that has the same key
	if not IsValid(self:GetCreator()) then return end

	for _, ent in pairs(ents.FindByClass(ENT.ClassName)) do
		if ent ~= self and ent:GetKey() == key then
			ent:Remove()
		end
	end

	-- create new numpad registrations
	self.NumpadRegisters = {}
	-- uses the same functions as the vanilla gmod camera
	if toggle then
		table.insert(self.NumpadRegisters, numpad.OnDown(self:GetCreator(), key, "Camera_Toggle", self))
	else
		table.insert(self.NumpadRegisters, numpad.OnDown(self:GetCreator(), key, "Camera_On", self))
		table.insert(self.NumpadRegisters, numpad.OnUp(self:GetCreator(), key, "Camera_Off", self))
	end
end

duplicator.RegisterEntityClass("hl_camera", function(ply, data)
	local camera = duplicator.GenericDuplicatorFunction(ply, data)
	print(ply)
	camera:SetCreator(ply)
	camera:ReassignNumpad("duplicator")
end, "Data")

function ENT:Initialize()
	self:SetModel("models/dav0r/camera.mdl")

	self:SetMoveType(MOVETYPE_VPHYSICS)
	if SERVER then
		self:PhysicsInit(SOLID_VPHYSICS)
		self:SetCollisionGroup(COLLISION_GROUP_WORLD)
	end

	self:SetGravity(0)
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

function ENT:Use(activator, caller, useType, value, ...)
	if useType == USE_ON then
		activator:SetViewEntity(self)
	else
		activator:SetViewEntity(nil)
	end
end

function ENT:Draw()
	-- obey cl_drawcameras that is used for vanilla cameras
	if not cvars.Bool("cl_drawcameras", true) then return end

	-- don't draw cameras while looking through another camera
	local ply = LocalPlayer()
	if ply:GetViewEntity():GetClass() == ENT.ClassName then return end

	-- don't draw cameras while using the camera weapon
	local wep = ply:GetActiveWeapon()
	if IsValid(wep) and wep:GetClass() == "gmod_camera" then return end

	self:DrawModel()
end

function ENT:CalcView(ply, origin, angles, fov, znear, zfar)
	local view = {}
	view.origin = origin
	view.angles = angles + Angle(0, 0, self:GetRoll())
	view.znear = self:GetNearZ() > 0 and self:GetNearZ() or znear
	view.zfar = self:GetFarZ() > 0 and self:GetFarZ() or zfar
	view.fov = self:GetFOV() > 0 and self:GetFOV() or fov

	return view
end

if CLIENT then
	hook.Add("CalcView", ENT.Folder, function(ply, ...)
		local viewent = ply:GetViewEntity()
		if IsValid(viewent) and viewent:GetClass() == ENT.ClassName then
			return viewent:CalcView(ply, ...)
		end
	end)
end
