AddCSLuaFile()
local TOOL = TOOL	-- so we can TOOL within hooks and functions

if CLIENT then
	-- custom language files are broken in addons! need to add them manually here until that's fixed... That also means no translations possible for now.
	language.Add("tool.hl_camera.name","Advanced Camera")
	language.Add("tool.hl_camera.reset","Reset Settings")
	language.Add("tool.hl_camera.key","Activation Key")
	language.Add("Undone_advanced_camera", "Undone Advanced Camera")
end

TOOL.Category = "Render"
TOOL.Name = "#tool.hl_camera.name"

TOOL.ClientConVar.key = KEY_PAD_0
TOOL.ClientConVar.toggle = 1
TOOL.ClientConVar.fov = 0
TOOL.ClientConVar.nearz = 0
TOOL.ClientConVar.farz = 0
TOOL.ClientConVar.roll = 0

TOOL.Information = {
	{ name = "left" }
}

function TOOL:LeftClick(tr)
	if CLIENT then return true end

	local ply = self:GetOwner()

	local camera = ents.Create("hl_camera")
	camera:SetCreator(ply)
	camera:SetFOV(self:GetClientNumber("fov"))
	camera:SetNearZ(self:GetClientNumber("nearz"))
	camera:SetFarZ(self:GetClientNumber("farz"))
	camera:SetRoll(self:GetClientNumber("roll"))

	camera:SetPos(tr.StartPos)
	camera:SetAngles(ply:EyeAngles())
	camera:Spawn()
	camera:Activate()

	camera:SetPlayerKey(ply, self:GetClientNumber("key"), tobool(self:GetClientNumber("toggle")))

	undo.Create("advanced_camera")
		undo.AddEntity(camera)
		undo.SetPlayer(ply)
	undo.Finish()

	return true
end

function TOOL.BuildCPanel( CPanel )
	CPanel:AddControl("numpad", {label = "#tool.hl_camera.key", command = "hl_camera_key"})
	CPanel:CheckBox("#tool.toggle", "hl_camera_toggle")
	CPanel:NumSlider("#hl_camera.fov", "hl_camera_fov", 0, 179.99, 4)
	CPanel:NumSlider("#hl_camera.nearz", "hl_camera_nearz", 0, 1000000, 4)
	CPanel:NumSlider("#hl_camera.farz", "hl_camera_farz", 0, 1000000, 4)
	CPanel:NumSlider("#hl_camera.roll", "hl_camera_roll", -180, 180, 4)

	-- reset button
	local reset_cmd = ""
	for k, v in pairs(TOOL.ClientConVar) do
		reset_cmd = reset_cmd .. "hl_camera_" .. k .. " " .. v .. ";"
	end
	CPanel:AddControl("button", {label = "#tool.hl_camera.reset", command = reset_cmd})
end
