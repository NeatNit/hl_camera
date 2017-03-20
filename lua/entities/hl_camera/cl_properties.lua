local ENT = ENT	-- so we can use ENT within hooks and functions
local property


-- Toggle checkbox
-- ===============

property = {
	Type = "toggle",
	MenuLabel = "#tool.toggle",
	Order = 100202	-- I guess? it goes at the bottom anyway no matter what I put here :/
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



-- Assign key
-- ==========

property = {
	MenuLabel = "#hl_camera.assign",
	Order = 100200,	-- should appear first
	MenuIcon = "icon16/keyboard.png",
	PrependSpacer = true
}

function property:Filter(ent)
	return IsValid(ent) and ent:GetClass() == ENT.ClassName
end

function property:Action(camera)
	if not IsValid(camera) then return end

	camera:StartSetNewKey()
end

properties.Add( "hl_camera_assign", property)



-- Unassign key
-- ============

property = {
	MenuLabel = "#hl_camera.unassign",
	Order = 100201,	-- should appear first
	MenuIcon = "icon16/keyboard_delete.png"
}

function property:Filter(ent)
	return IsValid(ent) and ent:GetClass() == ENT.ClassName
		and ent.AssignedKey.key and ent.AssignedKey.key ~= KEY_NONE
end

function property:Action(camera)
	if not IsValid(camera) then return end

	net.Start("hl_camera_key")
	net.WriteEntity(camera)
	net.WriteInt(KEY_NONE, 10)
	net.WriteBool(camera.AssignedKey.toggle)
	net.SendToServer()

	-- change the setting internally, just so the checkbox appears correct if you right-click very fast after toggling (i.e. before the server updated us)
	camera.AssignedKey.key = KEY_NONE
end

properties.Add( "hl_camera_unassign", property)
