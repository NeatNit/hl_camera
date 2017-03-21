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
	self:NetworkVar("Float", 0, "FOV", { KeyName = "fov", Edit = { title = "#hl_camera.fov", type = "Float", order = 0, min = 0, max = 179.99 } } )
	self:NetworkVar("Float", 1, "NearZ", { KeyName = "nearz", Edit = { title = "#hl_camera.nearz", type = "Float", order = 1, min = 0, max = 1000000 } } )
	self:NetworkVar("Float", 2, "FarZ", { KeyName = "farz", Edit = { title = "#hl_camera.farz", type = "Float", order = 2, min = 0, max = 1000000 } } )
	self:NetworkVar("Float", 3, "Roll", { KeyName = "roll", Edit = { title = "#hl_camera.roll", type = "Float", order = 3, min = -180, max = 180 } } )
	self:NetworkVar("Bool", 0, "ProjectionOn", { KeyName = "projectionon", Edit = { title = "#hl_camera.projectionon", type = "Boolean", order = 4, category = "Projection" } } )

	-- initialize our required table
	if SERVER then
		self.PlayerBinds = {}
		self:NetworkVarNotify("ProjectionOn", self.UpdateProjectionVar)
		self:NetworkVarNotify("FOV", self.UpdateProjectionVar)
		self:NetworkVarNotify("NearZ", self.UpdateProjectionVar)
		self:NetworkVarNotify("FarZ", self.UpdateProjectionVar)
		self:NetworkVarNotify("Roll", self.UpdateProjectionVar)
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

	-- Tell the server that we are ready to receive the key of this camera
	if CLIENT and IsValid(self) and self.AssignedKey.key == nil then
		net.Start("hl_camera_key")
		net.WriteEntity(self)
		net.SendToServer()
	end

	return BaseClass.Initialize(self)
end
