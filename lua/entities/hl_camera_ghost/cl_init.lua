include("shared.lua")

function ENT:DrawTranslucent()
	local camera = self:GetParent()
	if not camera then return end
	if not camera:ShouldDraw() then return end

	-- in all other cases, draw
	self:DrawModel()
end
