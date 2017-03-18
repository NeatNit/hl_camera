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

function ENT:SetupDataTables()
	--if dev:GetBool() then MsgN("SetupDataTables ", self) end
	self:NetworkVar("Float", 0, "FOV", { KeyName = "fov", Edit = { title = "#hl_camera.fov", type = "Float", order = 0, min = 0, max = 179.99 } } )
	self:NetworkVar("Float", 1, "NearZ", { KeyName = "nearz", Edit = { title = "#hl_camera.nearz", type = "Float", order = 1, min = 0, max = 1000000 } } )
	self:NetworkVar("Float", 2, "FarZ", { KeyName = "farz", Edit = { title = "#hl_camera.farz", type = "Float", order = 2, min = 0, max = 1000000 } } )
	self:NetworkVar("Float", 3, "Roll", { KeyName = "roll", Edit = { title = "#hl_camera.roll", type = "Float", order = 3, min = -180, max = 180 } } )

	-- initialize our required table
	if SERVER then
		self.PlayerBinds = {}
	else
		self.AssignedKey = {}
	end
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
	self:DrawShadow(false)

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

	return BaseClass.Initialize(self)
end
