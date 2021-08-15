include("projection_enum.lua")



function ENT:UpdateProjectionVar(varchanged, oldvalue, newvalue)
	if oldvalue == newvalue then return end

	if varchanged == "ProjectionOn" then
		self:SwitchProjection(newvalue)
	elseif varchanged == "ProjectionRatioID" then
		self:UpdateProjectionTexture(newvalue, self:GetFOV())
	elseif varchanged == "NearZ" then
		self:UpdateProjectionNearZ(newvalue)
	elseif varchanged == "FarZ" then
		self:UpdateProjectionFarZ(newvalue)
	elseif varchanged == "Roll" then
		self:UpdateProjectionRoll(newvalue)
	elseif varchanged == "FOV" then
		self:UpdateProjectionFOV(newvalue, self:GetProjectionRatioID(), oldvalue)
	elseif varchanged == "ProjectionColor" then
		self:UpdateProjectionColor(newvalue, self:GetProjectionBrightness())
	elseif varchanged == "ProjectionBrightness" then
		self:UpdateProjectionColor(self:GetProjectionColor(), newvalue)
	elseif varchanged == "ViewOffset" then
		self:UpdateProjectionOffset(newvalue)
	end
end

function ENT:UpdateProjectionColor(newcolor, newbrightness)
	if not IsValid(self.ptexture) then return end

	local r = newcolor.x * newbrightness * 255
	local g = newcolor.y * newbrightness * 255
	local b = newcolor.z * newbrightness * 255

	self.ptexture:SetKeyValue("lightcolor", Format( "%i %i %i 255", r, g, b))
end

function ENT:UpdateProjectionTexture(newratioid, fov)
	if not IsValid(self.ptexture) then return end

	local tex = self.ProjectionRatioTextures[newratioid]

	-- if FOV is 0, texture must be set to a warning
	if fov and fov <= 0 then tex = self.ProjectionRatioTextures[self.PROJECTION_FOV_IS_ZERO] end

	self.ptexture:Input("SpotlightTexture", NULL, NULL, tex)
	if fov then self:UpdateProjectionFOV(fov, newratioid) end
end

function ENT:UpdateProjectionNearZ(newnearz)
	if not IsValid(self.ptexture) then return end
	if newnearz <= 0 then
		newnearz = math.max(self:OBBMaxs().x, 12)
	end
	self.ptexture:SetKeyValue("nearz", newnearz)
end

local defaultfarz = 16384 * math.sqrt(3)	-- 16384 is r_mapextents's default value and r_mapextents is multiplied by the square root of 3 in the fallback farz
function ENT:UpdateProjectionFarZ(newfarz)
	if not IsValid(self.ptexture) then return end
	if newfarz <= 0 then
		newfarz = defaultfarz
	end
	self.ptexture:SetKeyValue("farz", newfarz)
end

function ENT:UpdateProjectionRoll(newroll)
	if not IsValid(self.ptexture) then return end
	self.ptexture:SetLocalAngles(Angle(0, 0, newroll))
end

function ENT:UpdateProjectionOffset(newoffset)
	if not IsValid(self.ptexture) then return end
	self.ptexture:SetLocalPos(newoffset)
end

function ENT:SwitchProjection(on)
	if not on and IsValid(self.ptexture) then
		-- Turning projection off
		self.ptexture:Remove()
		self.ptexture = nil
		return
	end
	if on and not IsValid(self.ptexture) then
		-- Turning projection on
		self.ptexture = ents.Create("env_projectedtexture")
		self.ptexture:SetParent(self)
		self:DeleteOnRemove(self.ptexture)
		self.ptexture:SetLocalPos(self:GetViewOffset())
		self.ptexture:SetKeyValue("enableshadows", 1)
		self.ptexture:Spawn()

		self:UpdateProjectionColor(self:GetProjectionColor(), self:GetProjectionBrightness())
		self:UpdateProjectionTexture(self:GetProjectionRatioID())
		self:UpdateProjectionFOV(self:GetFOV(), self:GetProjectionRatioID())
		self:UpdateProjectionNearZ(self:GetNearZ())
		self:UpdateProjectionFarZ(self:GetFarZ())
		self:UpdateProjectionRoll(self:GetRoll())
	end
end

function ENT:UpdateProjectionFOV(newfov, ratioid, oldfov)
	if not IsValid(self.ptexture) then return end

	if newfov <= 0 then
		-- if the fov changed to 0, we must change the texture to a warning
		self:UpdateProjectionTexture(self.PROJECTION_FOV_IS_ZERO)
		self.ptexture:SetKeyValue("lightfov", 50)
		return
	elseif oldfov and oldfov <= 0 then
		-- if the old FOV was 0 then we must update the texture again
		self:UpdateProjectionTexture(self:GetProjectionRatioID())
	end

	-- let's do some math
	-- the projected texture is not the size we need it to be projected in
	-- this is because the edges have to be black

	-- get wanted fov in radians
	local fov = math.rad(newfov)
	-- but the math we're gonna do is for 0-90 degrees so let's get half of the 0-180 fov
	fov = fov / 2
	-- now get the tangent of that. this is the width of the texture as we want to project it
	fov = math.tan(fov)
	-- but the content in the texture we're projecting only fills half the texture, so we multiply by the texture's magic constant
	fov = fov * self.ProjectionRatioMultipliers[ratioid]
	-- and we need the fov as an angle
	fov = math.atan(fov)
	-- source uses degrees
	fov = math.deg(fov)
	-- and we were working with half for the math, so
	fov = fov * 2

	self.ptexture:SetKeyValue("lightfov", fov)

	-- the temptation was high to just do this
	--self.ptexture:SetKeyValue("lightfov",math.deg(math.atan(math.tan(math.rad(newfov)/2)*self.ProjectionRatioMultipliers[ratioid]))*2)
	-- which is just as good, right?
end
