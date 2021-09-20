ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:Initialize()
	self:SetModel("models/dav0r/camera.mdl")
	self:SetRenderMode(RENDERMODE_TRANSCOLOR)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:SetColor(Color(255, 255, 255, 155))
	self:DrawShadow(false)
	self:SetNotSolid(true)
end
