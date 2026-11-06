-- Prism menu shell. factory(deps) -> bundle
return function(deps)
	local Prism = deps.Prism
	local Esp = deps.Esp
	local Aim = deps.Aim
	local World = deps.World
	local Misc = deps.Misc
	local bundleVersion = deps.BundleVersion or "2.9.5"

	Prism.ReduceMotion = true
	Prism.Sounds = false
	if Prism._unloadAll then
		Prism:_unloadAll()
	end

	Esp:cleanupBeforeLoad()

	local Window = Prism:CreateWindow({
		Title = "Fust Hub",
		Subtitle = bundleVersion,
		Footer = bundleVersion,
		Intro = false,
		ToggleKey = Enum.KeyCode.RightControl,
		Size = Vector2.new(640, 640),
	})

	local aimTab = Window:Tab({ Name = "Aimbot", Icon = "crosshair" })

	local aimSec = aimTab:Section({ Name = "Aiming", Icon = "target", Side = "Left" })
	aimSec:Toggle({
		Name = "Enabled",
		Default = false,
		Risky = true,
		Flag = "Fust_AimOn",
		Callback = function(v)
			Aim.aimbotEnabled = v
			Aim.lockAssist = v
			Aim:syncBind()
		end,
	})
	aimSec:Toggle({
		Name = "Prediction",
		Default = true,
		Flag = "Fust_AimPred",
		Callback = function(v)
			Aim.prediction = v
		end,
	})
	aimSec:Toggle({
		Name = "Instant",
		Default = false,
		Flag = "Fust_InstantAim",
		Callback = function(v)
			Aim.instantAim = v
		end,
	})
	aimSec:Slider({
		Name = "Bullet speed",
		Min = 100,
		Max = 2000,
		Default = 900,
		Increment = 10,
		Flag = "Fust_BulletSpeed",
		DependsOn = "Fust_AimPred",
		Callback = function(v)
			Aim.bulletSpeed = v
		end,
	})
	aimSec:Dropdown({
		Name = "Bone",
		Multi = true,
		Default = { "Head" },
		Options = { "Head", "Neck", "Chest", "Pelvis" },
		Flag = "Fust_AimBones",
		Callback = function(v)
			if type(v) == "table" and #v > 0 then
				Aim.targetBones = v
			end
		end,
	})
	aimSec:Slider({
		Name = "Smoothing",
		Min = 1,
		Max = 20,
		Default = 2,
		Increment = 0.1,
		Flag = "Fust_AimSmooth",
		Callback = function(v)
			Aim.smoothing = v
		end,
	})
	aimSec:Slider({
		Name = "FOV",
		Min = 20,
		Max = 600,
		Default = 220,
		Increment = 1,
		Flag = "Fust_WeaponFov",
		Callback = function(v)
			Aim.weaponFovPx = v
		end,
	})
	aimSec:Slider({
		Name = "Max distance",
		Min = 25,
		Max = 3000,
		Default = 1500,
		Increment = 5,
		Flag = "Fust_AimRange",
		Callback = function(v)
			Aim.maxDist = v
		end,
	})
	aimSec:Toggle({
		Name = "Target NPCs",
		Default = true,
		Flag = "Fust_AimNpcs",
		Callback = function(v)
			Aim.targetNpcs = v
		end,
	})
	aimSec:Toggle({
		Name = "Wall check",
		Default = false,
		Flag = "Fust_VisCheck",
		Callback = function(v)
			Aim.visibleCheck = v
		end,
	})
	aimSec:Toggle({
		Name = "Team check",
		Default = false,
		Flag = "Fust_IgnTeam",
		Callback = function(v)
			Aim.ignoreTeam = v
		end,
	})
	aimSec:Toggle({
		Name = "Require hold key",
		Default = false,
		Flag = "Fust_ReqHold",
		Callback = function(v)
			Aim.requireHoldKey = v
		end,
	})
	aimSec:Toggle({
		Name = "Aim key",
		Default = false,
		Flag = "Fust_AimKey1",
		Mode = "Hold",
		Keybind = Enum.KeyCode.B,
		Callback = function(v)
			Aim.aimKey1Held = v
		end,
		KeyChanged = function(key)
			Aim.aimKey1 = key
		end,
	})
	aimSec:Toggle({
		Name = "Aim key 2",
		Default = false,
		Flag = "Fust_AimKey2",
		Mode = "Hold",
		Keybind = Enum.KeyCode.V,
		Callback = function(v)
			Aim.aimKey2Held = v
		end,
		KeyChanged = function(key)
			Aim.aimKey2 = key
		end,
	})

	local bowAimSec = aimTab:Section({ Name = "Bow", Icon = "target", Side = "Left" })
	bowAimSec:Toggle({
		Name = "Bow prediction",
		Default = false,
		Flag = "Fust_BowPred",
		Callback = function(v)
			Aim.bowPrediction = v
		end,
	})
	bowAimSec:Toggle({
		Name = "Gravity",
		Default = true,
		Flag = "Fust_BowGrav",
		DependsOn = "Fust_BowPred",
		Callback = function(v)
			Aim.bowGravity = v
		end,
	})
	bowAimSec:Slider({
		Name = "Arrow speed",
		Min = 80,
		Max = 600,
		Default = 280,
		Increment = 5,
		Flag = "Fust_BowSpeed",
		DependsOn = "Fust_BowPred",
		Callback = function(v)
			Aim.bowSpeed = v
		end,
	})
	bowAimSec:Slider({
		Name = "Gravity scale",
		Min = 0,
		Max = 2,
		Default = 1,
		Increment = 0.05,
		Flag = "Fust_BowGravScale",
		DependsOn = "Fust_BowGrav",
		Callback = function(v)
			Aim.bowGravityScale = v
		end,
	})

	local silentSec = aimTab:Section({ Name = "Silent aim", Icon = "crosshair", Side = "Left" })
	silentSec:Toggle({
		Name = "Enabled",
		Default = false,
		Risky = true,
		Flag = "Fust_SilentOn",
		Callback = function(v)
			Aim.silentOn = v
			Aim:syncBind()
		end,
	})
	silentSec:Toggle({
		Name = "Shot only",
		Default = false,
		Flag = "Fust_SilentShotOnly",
		DependsOn = "Fust_SilentOn",
		Callback = function(v)
			Aim.silentShotOnly = v
		end,
	})
	silentSec:Slider({
		Name = "Silent FOV",
		Min = 20,
		Max = 600,
		Default = 220,
		Increment = 1,
		Flag = "Fust_SilentFov",
		DependsOn = "Fust_SilentOn",
		Callback = function(v)
			Aim.silentFovPx = v
		end,
	})
	silentSec:Slider({
		Name = "Silent distance",
		Min = 0,
		Max = 2000,
		Default = 525,
		Increment = 5,
		Flag = "Fust_SilentDist",
		DependsOn = "Fust_SilentOn",
		Callback = function(v)
			Aim.silentMaxDist = v
		end,
	})

	local trigSec = aimTab:Section({ Name = "Triggerbot", Icon = "mouse-pointer-click", Side = "Right" })
	trigSec:Toggle({
		Name = "Enabled",
		Default = false,
		Risky = true,
		Flag = "Fust_TrigOn",
		Callback = function(v)
			Aim.triggerEnabled = v
			Aim:syncBind()
		end,
	})
	trigSec:Slider({
		Name = "Delay (ms)",
		Min = 0,
		Max = 200,
		Default = 10,
		Increment = 1,
		Flag = "Fust_TrigDelay",
		DependsOn = "Fust_TrigOn",
		Callback = function(v)
			Aim.triggerDelayMs = v
		end,
	})
	trigSec:Toggle({
		Name = "Trigger key",
		Default = false,
		Flag = "Fust_TrigKey",
		Mode = "Hold",
		Keybind = Enum.KeyCode.B,
		DependsOn = "Fust_TrigOn",
		Callback = function(v)
			Aim.triggerKeyHeld = v
		end,
		KeyChanged = function(key)
			Aim.triggerKey = key
		end,
	})

	local aimMisc = aimTab:Section({ Name = "Options", Icon = "sliders", Side = "Right" })
	aimMisc:Toggle({
		Name = "Draw FOV",
		Default = true,
		Flag = "Fust_DrawFov",
		Callback = function(v)
			Aim.drawFov = v
			Aim:syncBind()
		end,
	})
	aimMisc:Toggle({
		Name = "Filled FOV",
		Default = false,
		Flag = "Fust_FillFov",
		Callback = function(v)
			Aim.filledFov = v
			Aim:syncBind()
		end,
	})
	aimMisc:Toggle({
		Name = "Crosshair",
		Default = true,
		Flag = "Fust_CrossOn",
		Callback = function(v)
			Aim.showCrosshair = v
			Aim:syncBind()
		end,
	})
	aimMisc:Toggle({
		Name = "Mouse drive",
		Default = true,
		Flag = "Fust_MouseAim",
		Callback = function(v)
			Aim.useMouseDrive = v
		end,
	})
	aimMisc:Slider({
		Name = "Mouse strength",
		Min = 0.25,
		Max = 2,
		Default = 1,
		Increment = 0.05,
		Flag = "Fust_MouseStr",
		Callback = function(v)
			Aim.mouseDriveStrength = v
		end,
	})
	aimMisc:Slider({
		Name = "Deadzone",
		Min = 0,
		Max = 40,
		Default = 1,
		Increment = 0.1,
		Flag = "Fust_Deadzone",
		Callback = function(v)
			Aim.deadzonePx = v
		end,
	})
	aimMisc:Toggle({
		Name = "Ignore knocked",
		Default = true,
		Flag = "Fust_IgnKnock",
		Callback = function(v)
			Aim.ignoreKnocked = v
		end,
	})
	aimMisc:Toggle({
		Name = "Require ADS",
		Default = false,
		Flag = "Fust_AimAds",
		Callback = function(v)
			Aim.requireAds = v
		end,
	})
	aimMisc:Toggle({
		Name = "Battlemode",
		Default = true,
		Risky = true,
		Flag = "Fust_Battle",
		Callback = function(v)
			Aim.battleMode = v
		end,
	})
	aimMisc:ColorPicker({
		Name = "FOV colour",
		Default = Color3.fromRGB(235, 70, 70),
		Flag = "Fust_AimCol",
		Callback = function(c)
			Aim.crossColor = c
			Aim.fovRingColor = c
			Aim:destroyCrosshair()
			if Aim.drawFov or Aim.showCrosshair then
				Aim:ensureCrosshair()
				Aim:syncBind()
			end
		end,
	})

	----------------------------------------------------------------------
	-- Tab: Visuals (player ESP)
	----------------------------------------------------------------------
	local visTab = Window:Tab({ Name = "Visuals", Icon = "eye" })
	local mainSec = visTab:Section({ Name = "Master", Icon = "toggle-right", Side = "Left" })
	local holdOn, toggleOn = false, false
	local function syncMaster()
		Esp:setMaster(holdOn or toggleOn)
	end
	mainSec:Toggle({
		Name = "Enabled",
		Default = false,
		Flag = "Fust_EspToggle",
		Callback = function(v)
			toggleOn = v
			syncMaster()
		end,
	})
	mainSec:Toggle({
		Name = "Hold key",
		Default = false,
		Flag = "Fust_EspHold",
		Mode = "Hold",
		Keybind = Enum.KeyCode.X,
		Callback = function(v)
			holdOn = v
			syncMaster()
		end,
	})

	local visSec = visTab:Section({ Name = "Players", Icon = "users", Side = "Left" })
	visSec:Toggle({ Name = "Box", Default = true, Flag = "Fust_EspBox", Callback = function(v)
		Esp.box = v
	end })
	visSec:Dropdown({
		Name = "Box style",
		Options = { "Full", "Corners" },
		Default = "Full",
		Flag = "Fust_EspBoxStyle",
		DependsOn = "Fust_EspBox",
		Callback = function(v)
			Esp.boxStyle = v
		end,
	})
	visSec:Toggle({ Name = "Skeleton", Default = true, Flag = "Fust_EspSkel", Callback = function(v)
		Esp.skeleton = v
	end })
	visSec:Toggle({ Name = "Joints", Default = true, Flag = "Fust_EspJoints", DependsOn = "Fust_EspSkel", Callback = function(v)
		Esp.joints = v
	end })
	visSec:Toggle({ Name = "Outline", Default = true, Flag = "Fust_EspOutline", Callback = function(v)
		Esp.outline = v
	end })
	visSec:Toggle({ Name = "Name", Default = true, Flag = "Fust_EspName", Callback = function(v)
		Esp.name = v
	end })
	visSec:Toggle({ Name = "Distance", Default = true, Flag = "Fust_EspDist", Callback = function(v)
		Esp.distance = v
	end })
	visSec:Toggle({ Name = "Weapon", Default = true, Flag = "Fust_EspHeld", Callback = function(v)
		Esp.held = v
	end })
	visSec:Toggle({ Name = "Armour", Default = false, Flag = "Fust_EspArmor", Callback = function(v)
		Esp.armor = v
	end })
	visSec:Toggle({ Name = "Health bar", Default = true, Flag = "Fust_EspHpBar", Callback = function(v)
		Esp.healthBar = v
	end })
	visSec:Toggle({ Name = "Health text", Default = false, Flag = "Fust_EspHpTxt", Callback = function(v)
		Esp.healthText = v
	end })
	visSec:ColorPicker({
		Name = "Colour",
		Default = Color3.fromRGB(235, 235, 235),
		Flag = "Fust_EspCol",
		Callback = function(c)
			Esp.color = c
		end,
	})
	visSec:Slider({
		Name = "Thickness",
		Min = 1,
		Max = 4,
		Default = 1.5,
		Increment = 0.5,
		Flag = "Fust_EspThick",
		Callback = function(v)
			Esp.thickness = v
		end,
	})

	local rangeSec = visTab:Section({ Name = "Range", Icon = "gauge", Side = "Right" })
	rangeSec:Slider({
		Name = "Max distance",
		Min = 100,
		Max = 5000,
		Default = 2500,
		Increment = 50,
		Flag = "Fust_EspRange",
		Callback = function(v)
			Esp.maxDist = v
		end,
	})
	rangeSec:Slider({
		Name = "Skeleton range",
		Min = 50,
		Max = 1000,
		Default = 400,
		Increment = 25,
		Flag = "Fust_EspSkelRange",
		Callback = function(v)
			Esp.skelDist = v
		end,
	})
	rangeSec:Slider({
		Name = "Health bar range",
		Min = 25,
		Max = 400,
		Default = 50,
		Increment = 5,
		Flag = "Fust_EspHpRange",
		Callback = function(v)
			Esp.healthBarMaxDist = v
		end,
	})
	rangeSec:Slider({
		Name = "Max players",
		Min = 1,
		Max = Esp.MAX_SLOTS or 20,
		Default = 12,
		Increment = 1,
		Flag = "Fust_EspMaxTargets",
		Callback = function(v)
			Esp.maxTargets = v
		end,
	})
	rangeSec:Slider({
		Name = "ESP FPS",
		Min = 5,
		Max = 60,
		Default = 30,
		Increment = 1,
		Flag = "Fust_EspRate",
		Callback = function(v)
			Esp.rate = v
		end,
	})

	local infoSec = visTab:Section({ Name = "Info", Icon = "info", Side = "Right" })
	infoSec:Toggle({
		Name = "Inv viewer",
		Default = false,
		Flag = "Fust_InvViewer",
		Callback = function(v)
			if Misc then
				Misc.invViewer = v
				Misc:syncInv()
			end
		end,
	})
	infoSec:Toggle({
		Name = "Target info",
		Default = false,
		Flag = "Fust_TargetInfo",
		Callback = function(v)
			if Misc then
				Misc.targetInfo = v
				Misc:syncTargetInfo()
			end
		end,
	})

	----------------------------------------------------------------------
	-- Tab: World
	----------------------------------------------------------------------
	local worldTab = Window:Tab({ Name = "World", Icon = "globe" })
	local wMaster = worldTab:Section({ Name = "Master", Icon = "toggle-right", Side = "Left" })
	wMaster:Toggle({
		Name = "Enabled",
		Default = false,
		Flag = "Fust_WorldEsp",
		Callback = function(v)
			World:setEsp(v)
		end,
	})
	wMaster:Slider({
		Name = "Max distance",
		Min = 50,
		Max = 2500,
		Default = 600,
		Increment = 25,
		Flag = "Fust_WorldDist",
		Callback = function(v)
			World.maxDist = v
		end,
	})
	wMaster:Slider({
		Name = "Rate (Hz)",
		Min = 5,
		Max = 30,
		Default = 15,
		Increment = 1,
		Flag = "Fust_WorldRate",
		Callback = function(v)
			World.rate = v
		end,
	})
	wMaster:Slider({
		Name = "Font size",
		Min = 10,
		Max = 18,
		Default = 12,
		Increment = 1,
		Flag = "Fust_WorldFont",
		Callback = function(v)
			World.fontsize = v
		end,
	})

	local function worldToggle(sec, name, flag, key)
		sec:Toggle({
			Name = name,
			Default = World.toggles[key] == true,
			Flag = flag,
			DependsOn = "Fust_WorldEsp",
			Callback = function(v)
				World:setToggle(key, v)
			end,
		})
	end

	local wFarm = worldTab:Section({ Name = "Farming", Icon = "axe", Side = "Left" })
	worldToggle(wFarm, "Trees", "Fust_W_Trees", "trees")
	worldToggle(wFarm, "Stone", "Fust_W_Stone", "stone")
	worldToggle(wFarm, "Metal", "Fust_W_Metal", "metal")
	worldToggle(wFarm, "Sulfur", "Fust_W_Sulfur", "sulfur")
	worldToggle(wFarm, "Hemp", "Fust_W_Hemp", "hemp")
	worldToggle(wFarm, "Food", "Fust_W_Food", "food")
	worldToggle(wFarm, "Mushroom", "Fust_W_Mushroom", "mushroom")
	worldToggle(wFarm, "Wood piles", "Fust_W_Woodpile", "woodpile")

	local wLoot = worldTab:Section({ Name = "Loot", Icon = "package", Side = "Right" })
	worldToggle(wLoot, "Loot barrels", "Fust_W_Barrel", "loot_barrel")
	worldToggle(wLoot, "Loot crates", "Fust_W_Crate", "loot_crate")
	worldToggle(wLoot, "Military crates", "Fust_W_Mil", "military_crate")
	worldToggle(wLoot, "Elite crates", "Fust_W_Elite", "elite_crate")
	worldToggle(wLoot, "Wooden boxes", "Fust_W_Box", "wooden_box")
	worldToggle(wLoot, "Large boxes", "Fust_W_LBox", "large_box")
	worldToggle(wLoot, "Backpacks", "Fust_W_Pack", "backpack")
	worldToggle(wLoot, "World items", "Fust_W_Item", "world_item")
	worldToggle(wLoot, "Airdrop", "Fust_W_Air", "airdrop")

	local wMobs = worldTab:Section({ Name = "Mobs", Icon = "skull", Side = "Left" })
	worldToggle(wMobs, "NPCs", "Fust_W_Npc", "npc")
	worldToggle(wMobs, "Bear", "Fust_W_Bear", "bear")
	worldToggle(wMobs, "Boar", "Fust_W_Boar", "boar")
	worldToggle(wMobs, "Deer", "Fust_W_Deer", "deer")
	worldToggle(wMobs, "Sleepers", "Fust_W_Sleeper", "sleeper")

	local wThreat = worldTab:Section({ Name = "Deployables", Icon = "shield", Side = "Right" })
	worldToggle(wThreat, "Turrets", "Fust_W_Turret", "auto_turret")
	worldToggle(wThreat, "Traps", "Fust_W_Trap", "shotgun_trap")
	worldToggle(wThreat, "Landmines", "Fust_W_Mine", "landmine")
	worldToggle(wThreat, "Tool cupboard", "Fust_W_TC", "tool_cupboard")

	local wVeh = worldTab:Section({ Name = "Vehicles", Icon = "car", Side = "Left" })
	worldToggle(wVeh, "ATV", "Fust_W_Atv", "atv")
	worldToggle(wVeh, "Minicopter", "Fust_W_Heli", "minicopter")
	worldToggle(wVeh, "Patrol heli", "Fust_W_Patrol", "patrol_heli")

	----------------------------------------------------------------------
	-- Tab: Misc (farm / combat / movement / guns)
	----------------------------------------------------------------------
	local miscTab = Window:Tab({ Name = "Misc", Icon = "wrench" })

	local farmSec = miscTab:Section({ Name = "Farm aura", Icon = "axe", Side = "Left" })
	farmSec:Toggle({
		Name = "Enabled",
		Default = false,
		Risky = true,
		Flag = "Fust_FarmOn",
		Callback = function(v)
			if Misc then
				Misc.farmEnabled = v
				Misc:syncFarm()
			end
		end,
	})
	farmSec:Toggle({
		Name = "Aim weakspot",
		Default = true,
		Flag = "Fust_FarmWeak",
		DependsOn = "Fust_FarmOn",
		Callback = function(v)
			if Misc then
				Misc.farmAimWeakspot = v
			end
		end,
	})
	farmSec:Toggle({
		Name = "Skip cactus",
		Default = true,
		Flag = "Fust_FarmSkipCactus",
		DependsOn = "Fust_FarmOn",
		Callback = function(v)
			if Misc then
				Misc.farmSkipCactus = v
			end
		end,
	})
	farmSec:Slider({
		Name = "Range",
		Min = 1,
		Max = 8,
		Default = 2,
		Increment = 0.1,
		Flag = "Fust_FarmRange",
		Callback = function(v)
			if Misc then
				Misc.farmRange = v
			end
		end,
	})
	farmSec:Slider({
		Name = "Cooldown",
		Min = 0.05,
		Max = 1,
		Default = 0.2,
		Increment = 0.01,
		Flag = "Fust_FarmCd",
		Callback = function(v)
			if Misc then
				Misc.farmCooldown = v
			end
		end,
	})

	local combatSec = miscTab:Section({ Name = "Combat", Icon = "swords", Side = "Left" })
	combatSec:Toggle({
		Name = "Kill aura",
		Default = false,
		Risky = true,
		Flag = "Fust_KillOn",
		Callback = function(v)
			if Misc then
				Misc.killEnabled = v
				Misc:syncFarm()
			end
		end,
	})
	combatSec:Slider({
		Name = "Kill range",
		Min = 2,
		Max = 15,
		Default = 7,
		Increment = 0.5,
		Flag = "Fust_KillRange",
		Callback = function(v)
			if Misc then
				Misc.killRange = v
			end
		end,
	})
	combatSec:Slider({
		Name = "Kill cooldown",
		Min = 0.05,
		Max = 1,
		Default = 0.35,
		Increment = 0.01,
		Flag = "Fust_KillCd",
		Callback = function(v)
			if Misc then
				Misc.killCooldown = v
			end
		end,
	})
	combatSec:Toggle({
		Name = "Hitbox expand",
		Default = false,
		Risky = true,
		Flag = "Fust_Hitbox",
		Callback = function(v)
			if Misc then
				Misc.hitboxEnabled = v
				Misc:syncHitbox()
			end
		end,
	})
	combatSec:Slider({
		Name = "Hitbox scale",
		Min = 1,
		Max = 12,
		Default = 5,
		Increment = 0.5,
		Flag = "Fust_HitScale",
		Callback = function(v)
			if Misc then
				Misc.hitboxScale = v
			end
		end,
	})

	local gunSec = miscTab:Section({ Name = "Gun mods", Icon = "crosshair", Side = "Right" })
	gunSec:Toggle({
		Name = "Auto fire",
		Default = false,
		Risky = true,
		Flag = "Fust_GunAuto",
		Callback = function(v)
			if Misc then
				Misc.gunAuto = v
				Misc:syncGunMods()
			end
		end,
	})
	gunSec:Toggle({
		Name = "Rapid fire",
		Default = false,
		Risky = true,
		Flag = "Fust_GunRapid",
		Callback = function(v)
			if Misc then
				Misc.gunRapid = v
				Misc:syncGunMods()
			end
		end,
	})
	gunSec:Slider({
		Name = "Rapid rate",
		Min = 0.03,
		Max = 0.25,
		Default = 0.08,
		Increment = 0.01,
		Flag = "Fust_GunRate",
		Callback = function(v)
			if Misc then
				Misc.gunRapidRate = v
			end
		end,
	})

	local bowModSec = miscTab:Section({ Name = "Bow mods", Icon = "target", Side = "Right" })
	bowModSec:Toggle({
		Name = "Enabled",
		Default = false,
		Risky = true,
		Flag = "Fust_BowMods",
		Callback = function(v)
			if Misc then
				Misc.bowEnabled = v
				Misc:syncBowMods()
			end
		end,
	})
	bowModSec:Toggle({
		Name = "Instant charge",
		Default = true,
		Flag = "Fust_BowInstant",
		DependsOn = "Fust_BowMods",
		Callback = function(v)
			if Misc then
				Misc.bowInstantCharge = v
			end
		end,
	})
	bowModSec:Toggle({
		Name = "Fast shot",
		Default = false,
		Flag = "Fust_BowFast",
		DependsOn = "Fust_BowMods",
		Callback = function(v)
			if Misc then
				Misc.bowFastShot = v
			end
		end,
	})
	bowModSec:Slider({
		Name = "Charge time",
		Min = 0.02,
		Max = 0.5,
		Default = 0.05,
		Increment = 0.01,
		Flag = "Fust_BowCharge",
		DependsOn = "Fust_BowInstant",
		Callback = function(v)
			if Misc then
				Misc.bowChargeTime = v
			end
		end,
	})
	bowModSec:Slider({
		Name = "Fast gap",
		Min = 0.05,
		Max = 0.5,
		Default = 0.12,
		Increment = 0.01,
		Flag = "Fust_BowFastGap",
		DependsOn = "Fust_BowFast",
		Callback = function(v)
			if Misc then
				Misc.bowFastGap = v
			end
		end,
	})

	local moveSec = miscTab:Section({ Name = "Movement", Icon = "gauge", Side = "Right" })
	moveSec:Toggle({
		Name = "Speed boost",
		Default = false,
		Risky = true,
		Flag = "Fust_SpeedOn",
		Callback = function(v)
			if Misc then
				Misc.speedEnabled = v
				Misc:syncSpeed()
			end
		end,
	})
	moveSec:Slider({
		Name = "Speed",
		Min = 8,
		Max = 40,
		Default = 22,
		Increment = 1,
		Flag = "Fust_SpeedVal",
		Callback = function(v)
			if Misc then
				Misc.speedValue = v
				if Misc.speedEnabled then
					Misc:syncSpeed()
				end
			end
		end,
	})
	moveSec:Dropdown({
		Name = "Speed mode",
		Options = { "cframe", "walk" },
		Default = "cframe",
		Flag = "Fust_SpeedMode",
		Callback = function(v)
			if Misc then
				Misc.speedMode = v
				if Misc.speedEnabled then
					Misc:syncSpeed()
				end
			end
		end,
	})
	moveSec:Toggle({
		Name = "Wall climb",
		Default = false,
		Risky = true,
		Flag = "Fust_WallClimb",
		Callback = function(v)
			if Misc then
				Misc.wallClimbEnabled = v
				Misc:syncWallClimb()
			end
		end,
	})
	moveSec:Slider({
		Name = "Climb speed",
		Min = 10,
		Max = 80,
		Default = 40,
		Increment = 1,
		Flag = "Fust_WallSpeed",
		Callback = function(v)
			if Misc then
				Misc.wallClimbSpeed = v
			end
		end,
	})

	----------------------------------------------------------------------
	-- Tab: Camera
	----------------------------------------------------------------------
	local camTab = Window:Tab({ Name = "Camera", Icon = "camera" })
	local camSec = camTab:Section({ Name = "Camera", Icon = "camera", Side = "Left" })
	camSec:Toggle({
		Name = "Zoom (hold)",
		Default = false,
		Flag = "Fust_Zoom",
		Mode = "Hold",
		Keybind = Enum.KeyCode.Z,
		Callback = function(v)
			World.zoomHeld = v
			World:syncZoom()
		end,
	})
	camSec:Slider({
		Name = "Zoom FOV",
		Min = 10,
		Max = 50,
		Default = 20,
		Increment = 1,
		Flag = "Fust_ZoomFov",
		Callback = function(v)
			World.zoomFov = v
			if World.zoomHeld then
				World:syncZoom()
			end
		end,
	})
	camSec:Toggle({
		Name = "Freecam",
		Default = false,
		Risky = true,
		Flag = "Fust_Freecam",
		Mode = "Toggle",
		Keybind = Enum.KeyCode.F,
		Callback = function(v)
			World.freecamOn = v
			World:syncFreecam()
		end,
	})
	camSec:Slider({
		Name = "Freecam speed",
		Min = 0.3,
		Max = 4,
		Default = 1.2,
		Increment = 0.1,
		Flag = "Fust_FcSpeed",
		Callback = function(v)
			World.freecamSpeed = v
		end,
	})
	camSec:Toggle({
		Name = "Third person",
		Default = false,
		Risky = true,
		Flag = "Fust_Tp3",
		Mode = "Toggle",
		Keybind = Enum.KeyCode.T,
		Callback = function(v)
			World.tp3On = v
			World:syncTp3()
		end,
	})
	camSec:Slider({
		Name = "TP distance",
		Min = 4,
		Max = 20,
		Default = 10,
		Increment = 0.5,
		Flag = "Fust_Tp3Dist",
		Callback = function(v)
			World.tp3Dist = v
		end,
	})
	camSec:Slider({
		Name = "TP height",
		Min = 0,
		Max = 6,
		Default = 2.5,
		Increment = 0.1,
		Flag = "Fust_Tp3Height",
		Callback = function(v)
			World.tp3Height = v
		end,
	})

	----------------------------------------------------------------------
	-- Tab: Settings
	----------------------------------------------------------------------
	local setTab = Window:Tab({ Name = "Settings", Icon = "settings" })

	Aim.requireHoldKey = false
	Aim.requireAds = false
	Aim.useMouseDrive = true
	Aim.lockAssist = true
	Aim.battleMode = true
	Aim.maxMousePx = 120
	Aim.smoothing = 2
	Aim.weaponFovPx = 220
	Aim.silentFovPx = 220
	Aim.prediction = true
	Aim.bulletSpeed = 900
	Aim.instantAim = false
	Aim.bowPrediction = false
	Aim.bowSpeed = 280
	Aim.bowGravity = true

	local RISKY_FLAGS = {
		"Fust_AimOn",
		"Fust_SilentOn",
		"Fust_TrigOn",
		"Fust_Battle",
		"Fust_AimKey1",
		"Fust_AimKey2",
		"Fust_TrigKey",
		"Fust_FarmOn",
		"Fust_KillOn",
		"Fust_Hitbox",
		"Fust_SpeedOn",
		"Fust_WallClimb",
		"Fust_GunAuto",
		"Fust_GunRapid",
		"Fust_BowMods",
		"Fust_Freecam",
		"Fust_Tp3",
	}

	local function panic()
		for _, flag in ipairs(RISKY_FLAGS) do
			local el = Prism.Flags[flag]
			if el and el.Set then
				pcall(function()
					el:Set(false)
				end)
			end
		end
		Aim.aimbotEnabled = false
		Aim.lockAssist = false
		Aim.silentOn = false
		Aim.triggerEnabled = false
		Aim.battleMode = false
		Aim.aimKey1Held = false
		Aim.aimKey2Held = false
		Aim.triggerKeyHeld = false
		Aim.firingSilent = false
		Aim:syncBind()
		if Misc then
			Misc.farmEnabled = false
			Misc.killEnabled = false
			Misc.speedEnabled = false
			Misc.hitboxEnabled = false
			Misc.wallClimbEnabled = false
			Misc.gunAuto = false
			Misc.gunRapid = false
			Misc.bowEnabled = false
			Misc:syncBind()
		end
		if World then
			World.freecamOn = false
			World.tp3On = false
			World.zoomHeld = false
			World:sync()
		end
		pcall(function()
			Prism:Notify({
				Title = "Panic",
				Content = "Off",
				Type = "Warning",
				Duration = 2,
			})
		end)
	end

	local safeSec = setTab:Section({ Name = "Safety", Icon = "shield", Side = "Left" })
	safeSec:Button({
		Name = "Panic",
		Icon = "shield-off",
		Callback = panic,
	})
	safeSec:Toggle({
		Name = "Panic key",
		Default = false,
		Flag = "Fust_PanicKey",
		Mode = "Toggle",
		Keybind = Enum.KeyCode.Delete,
		Callback = function(v)
			if v then
				panic()
				local el = Prism.Flags.Fust_PanicKey
				if el and el.Set then
					el:Set(false, true)
				end
			end
		end,
	})

	local sysSec = setTab:Section({ Name = "Script", Icon = "power", Side = "Right" })
	sysSec:Button({
		Name = "Refresh",
		Icon = "refresh-cw",
		Callback = function()
			local url = "https://raw.githubusercontent.com/ImWozzie/gangstanigletshit/main/loader/bootstrap.luau?v=" .. bundleVersion
			local ok, err = pcall(function()
				loadstring(game:HttpGet(url))()
			end)
			if not ok then
				warn("[FustBundle] refresh failed: " .. tostring(err))
			end
		end,
	})
	sysSec:Button({
		Name = "Unload",
		Icon = "trash-2",
		Hold = 1.2,
		HoldText = "Hold...",
		Callback = function()
			Window:Unload()
		end,
	})

	local bundle = {}
	function bundle.destroy()
		Aim:destroy()
		Esp:destroy()
		if Misc then
			Misc:destroy()
		end
		if World then
			World:destroy()
		end
	end

	Window:OnUnload(function()
		bundle.destroy()
	end)

	Esp:ensureGui()
	Aim:syncBind()

	bundle.Window = Window
	bundle.Esp = Esp
	bundle.Aim = Aim
	bundle.World = World
	bundle.Misc = Misc
	bundle.panic = panic
	return bundle
end
