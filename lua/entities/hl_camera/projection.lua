

function ENT:UpdateProjectionVar(varchanged, oldvalue, newvalue)
	if oldvalue == newvalue then return end

	if varchanged == "ProjectionOn" then
		self:SwitchProjection(newvalue)
	elseif varchanged == "NearZ" then
		self:UpdateProjectionNearZ(newvalue)
	elseif varchanged == "FarZ" then
		self:UpdateProjectionFarZ(newvalue)
	elseif varchanged == "Roll" then
		self:UpdateProjectionRoll(newvalue)
	elseif varchanged == "FOV" then
		self:UpdateProjectionFOV(newvalue)
	end
end

function ENT:UpdateProjectionNearZ(newnearz)
	if not IsValid(self.ptexture) then return end
	self.ptexture:SetKeyValue("nearz", newnearz)
end

function ENT:UpdateProjectionFarZ(newfarz)
	if not IsValid(self.ptexture) then return end
	self.ptexture:SetKeyValue("farz", newfarz)
end

function ENT:UpdateProjectionRoll(newroll)
	if not IsValid(self.ptexture) then return end
	self.ptexture:SetLocalAngles(Angle(0, 0, newroll))
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
		self.ptexture:SetLocalPos(Vector(0, 0, 0))
		self.ptexture:SetKeyValue("enableshadows", 1)
		self.ptexture:SetKeyValue("lightcolor", Format( "%i %i %i 255", 255, 255, 0))
		self.ptexture:Input("SpotlightTexture", NULL, NULL, "screenratios/16_10")

		-- self.ptexture:SetLocalAngles(Angle(0, 0, self:GetRoll()))
		-- self.ptexture:SetKeyValue("nearz", self:GetNearZ())
		-- self.ptexture:SetKeyValue("farz", self:GetFarZ())
		self:UpdateProjectionRoll(self:GetRoll())
		self:UpdateProjectionNearZ(self:GetNearZ())
		self:UpdateProjectionFarZ(self:GetFarZ())
		self:UpdateProjectionFOV(self:GetFOV())
	end
end

function ENT:UpdateProjectionFOV(newfov)
	if not IsValid(self.ptexture) then return end
	-- let's do some math
	-- the projected texture is twice the width we need it to be
	-- this is because the edges have to be black so it has to be less than 100%
	-- so I made it 50% for the easier math

	-- get wanted fov in radians
	local fov = math.rad(newfov)
	-- but the math we're gonna do is for 0-90 degrees so let's get half of the 0-180 fov
	fov = fov / 2
	-- now get the tangent of that. this is the width of the texture as we want to project it
	fov = math.tan(fov)
	-- but the content in the texture we're projecting only fills half the texture, so we project twice the width
	fov = fov * (32/10) * (3/4)
	-- and we need the fov as an angle
	fov = math.atan(fov)
	-- source uses degrees
	fov = math.deg(fov)
	-- and we were working with half for the math, so
	fov = fov * 2

	self.ptexture:SetKeyValue("lightfov", fov)

	-- the temptation was high to just do this
	--self.ptexture:SetKeyValue("lightfov",math.deg(atan(tan(math.rad(newfov)/2)*2))*2)
	-- which is just as good, right?
end
