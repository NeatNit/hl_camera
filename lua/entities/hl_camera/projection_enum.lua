AddCSLuaFile()

-- internal enum, used for projection.lua but that is a serverside file and we need this enum on both
ENT.PROJECTION_RATIO_16_9 = 0
ENT.PROJECTION_RATIO_16_10 = 1
ENT.PROJECTION_RATIO_4_3 = 2
ENT.PROJECTION_FOV_IS_ZERO = 500

if CLIENT then

	-- This is used in the edit menu (see shared.lua)

	ENT.ProjectionRatioValues = {
		["16:9"] = ENT.PROJECTION_RATIO_16_9,
		["16:10"] = ENT.PROJECTION_RATIO_16_10,
		["4:3"] = ENT.PROJECTION_RATIO_4_3,
	}

else	-- SERVER

	-- These are multipliers used in projection.lua to increase the size of the projection so the rectangle matches the camera exactly
	-- In Source, the FOV value means 'horizontal FOV at 4:3', BUT, the deciding factor is actually the VERTICAL FOV.
	-- So we need to calculate based on that.

	-- The calculation is the same for all:
	-- 1. Multiply by 3/4 to get the height FOV, which is the actual meaning of the setting
	-- 2. Multiply by the constant value based on the pixels in the texture - how much % of the texture do they take

	ENT.ProjectionRatioMultipliers = {
		[ENT.PROJECTION_RATIO_4_3]   = 2,		-- 3/4 * 8/3 = 2
		[ENT.PROJECTION_RATIO_16_9]  = 8/3,	-- 3/4 * 32/9 = 8/3 = 2+2/3
		[ENT.PROJECTION_RATIO_16_10] = 2.4		-- 3/4 * 16/5 = 12/5 = 2.4
	}

	-- Actual texture names
	ENT.ProjectionRatioTextures = {
		[ENT.PROJECTION_RATIO_4_3]   = "hl_camera/4_3",
		[ENT.PROJECTION_RATIO_16_9]  = "hl_camera/16_9",
		[ENT.PROJECTION_RATIO_16_10] = "hl_camera/16_10",
		[ENT.PROJECTION_FOV_IS_ZERO] = "hl_camera/no_fov"
	}

end
