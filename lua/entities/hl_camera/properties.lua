local ENT = ENT	-- so we can use ENT within hooks and functions

local property

-- Toggle checkbox
property = {
	Type = "toggle",
	MenuLabel = "Toggle",
	Order = 100000	-- I guess? it goes at the bottom anyway no matter what I put here :/
}

function property:Filter(ent)
	return IsValid(ent) and ent:GetClass() == ENT.ClassName
		and ent.AssignedKey.key ~= KEY_NONE
end

function property:Checked(camera)
	return camera.AssignedKey.toggle or false
end

function property:Action(camera)
	if not IsValid(camera) then return end

	net.Start("hl_camera_key")
	net.WriteEntity(camera)
	net.WriteInt(camera.AssignedKey.key, 10)
	net.WriteBool(not camera.AssignedKey.toggle)
	net.SendToServer()

	-- change the setting internally, just so the checkbox appears correct if you right-click very fast after toggling (i.e. before the server updated us)
	camera.AssignedKey.toggle = not camera.AssignedKey.toggle
end

properties.Add( "hl_camera_toggle", property)

-- Reassign key
property = {
	MenuLabel = "Assign Key",
	Order = 1,	-- should appear first
	MenuIcon = "icon16/keyboard.png"
}

function property:Filter(ent)
	return IsValid(ent) and ent:GetClass() == ENT.ClassName
end

function property:Action(camera)
	if not IsValid(camera) then return end

	camera:StartSetNewKey()
end

properties.Add( "hl_camera_assign", property)
