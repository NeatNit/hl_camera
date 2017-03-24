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
	self:NetworkVar("Float", 0, "FOV", {
		KeyName = "fov",
		Edit = {
			title = "#hl_camera.fov",
			order = 0,
			type = "Float",
			min = 0,
			max = 179.99
		}
	})

	self:NetworkVar("Float", 1, "NearZ", {
		KeyName = "nearz",
		Edit = {
			title = "#hl_camera.nearz",
			order = 1,
			type = "Float",
			min = 0,
			max = 1000000
		}
	})

	self:NetworkVar("Float", 2, "FarZ", {
		KeyName = "farz",
		Edit = {
			title = "#hl_camera.farz",
			order = 2,
			type = "Float",
			min = 0,
			max = 1000000
		}
	})

	self:NetworkVar("Float", 3, "Roll", {
		KeyName = "roll",
		Edit = {
			title = "#hl_camera.roll",
			order = 3,
			type = "Float",
			min = -180,
			max = 180
		}
	})

	self:NetworkVar("Bool", 0, "ProjectionOn", {
		KeyName = "projectionon",
		Edit = {
			title = "#hl_camera.projection.on",
			order = 4,
			category = "Projection",
			type = "Boolean"
		}
	})

	self:NetworkVar("Int", 0, "ProjectionRatioID", {
		KeyName = "projectionratioid",
		Edit = {
			title = "#hl_camera.projection.ratio",
			order = 5,
			category = "Projection",
			type = "Combo",
			--text = "16:9",
			values = self.ProjectionRatioValues	-- see projection_enum.lua
		}
	})

	self:NetworkVar("Vector", 0, "ProjectionColor", {
		KeyName = "projectioncolor",
		Edit = {
			title = "#hl_camera.projection.color",
			order = 5,
			category = "Projection",
			type = "VectorColor"
		}
	})

	self:NetworkVar("Float", 4, "ProjectionBrightness", {
		KeyName = "projectionbr",
		Edit = {
			title = "#hl_camera.projection.brightness",
			order = 7,
			category = "Projection",
			type = "Float",
			min = 0,
			max = 10
		}
	})

	-- initialize our required table and on the server, register projected texture hooks
	if SERVER then
		self.PlayerBinds = {}
		self:NetworkVarNotify("ProjectionBrightness", self.UpdateProjectionVar)
		self:NetworkVarNotify("ProjectionRatioID", self.UpdateProjectionVar)
		self:NetworkVarNotify("ProjectionColor", self.UpdateProjectionVar)
		self:NetworkVarNotify("ProjectionOn", self.UpdateProjectionVar)
		self:NetworkVarNotify("NearZ", self.UpdateProjectionVar)
		self:NetworkVarNotify("FarZ", self.UpdateProjectionVar)
		self:NetworkVarNotify("Roll", self.UpdateProjectionVar)
		self:NetworkVarNotify("FOV", self.UpdateProjectionVar)
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

	-- defaults
	self:SetProjectionColor(Vector(1, 1, 0))
	self:SetProjectionBrightness(1)

	-- Tell the server that we are ready to receive the key of this camera
	if CLIENT and IsValid(self) and self.AssignedKey.key == nil then
		net.Start("hl_camera_key")
		net.WriteEntity(self)
		net.SendToServer()
	end

	return BaseClass.Initialize(self)
end
