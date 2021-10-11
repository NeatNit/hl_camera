function ENT:GhostCreate()
	if IsValid(self.ACGhost) then
		-- this should never happen, but to be on the safe side:
		return self.ACGhost
	end

	local ghost = ents.Create("hl_camera_ghost")

	ghost:Spawn()

	ghost:SetParent(self)
	ghost:SetLocalPos(self:GetViewOffset())
	ghost:SetLocalAngles(Angle(0, 0, self:GetRoll()))
	self:DeleteOnRemove(ghost)
	return ghost
end

function ENT:UpdateGhostVar(varchanged, oldvalue, newvalue)
	if oldvalue == newvalue then return end

	if varchanged == "EnableGhost" then
		self:SwitchGhost(newvalue)
	elseif varchanged == "ViewOffset" then
		self:UpdateGhostOffset(newvalue, self:GetRoll(), self:GetEnableGhost())
	elseif varchanged == "Roll" then
		self:UpdateGhostOffset(self:GetViewOffset(), newvalue, self:GetEnableGhost())
	end

end

function ENT:SwitchGhost(on)
	if not IsValid(self.ACGhost) and on and not (self:GetViewOffset() == vector_origin and self:GetRoll() == 0)  then
		self.ACGhost = self:GhostCreate()
	elseif not on and IsValid(self.ACGhost) then
		self.ACGhost:Remove()
	end
end

function ENT:UpdateGhostOffset(offset, roll, on)
	if offset == vector_origin and roll == 0 then
		if IsValid(self.ACGhost) then
			self.ACGhost:Remove()
		end
	elseif on then
		if not IsValid(self.ACGhost) then
			self.ACGhost = self:GhostCreate()
		end
		self.ACGhost:SetLocalPos(offset)
		self.ACGhost:SetLocalAngles(Angle(0, 0, roll))
	end
end
