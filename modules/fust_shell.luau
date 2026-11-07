-- Prism menu shell. factory(deps) -> bundle
return function(deps)
	local Prism = deps.Prism
	local Esp = deps.Esp
	local Aim = deps.Aim
	local World = deps.World
	local Misc = deps.Misc
	local Exploit = deps.Exploit
	local Presets = deps.Presets
	local bundleVersion = deps.BundleVersion or "2.16.2"

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
		ConfigFolder = "FustHub",
		PerGameConfigs = true,
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
		Name = "Hitscan",
		Default = false,
		Flag = "Fust_InstantAim",
		Callback = function(v)
			Aim:setHitscan(v)
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

	local manipSec = aimTab:Section({ Name = "Manipulation", Icon = "zap", Side = "Left" })
	manipSec:Label({
		Text = "Camera burst + MANIP HUD (pair with Exploit for Shoot hook).",
	})
	manipSec:Toggle({
		Name = "Enabled",
		Default = false,
		Risky = true,
		Flag = "Fust_Manip",
		DependsOn = "Fust_SilentOn",
		Callback = function(v)
			Aim.manip = v
		end,
	})
	manipSec:Slider({
		Name = "Strength",
		Min = 1,
		Max = 2,
		Default = 1.35,
		Increment = 0.05,
		Flag = "Fust_ManipStr",
		DependsOn = "Fust_Manip",
		Callback = function(v)
			Aim.manipStrength = v
		end,
	})
	manipSec:Slider({
		Name = "Burst steps",
		Min = 1,
		Max = 8,
		Default = 4,
		Increment = 1,
		Flag = "Fust_SilentBurst",
		DependsOn = "Fust_Manip",
		Callback = function(v)
			Aim.silentBurstSteps = v
		end,
	})
	manipSec:Slider({
		Name = "Hold after shot (ms)",
		Min = 0,
		Max = 250,
		Default = 100,
		Increment = 5,
		Flag = "Fust_SilentHold",
		DependsOn = "Fust_SilentOn",
		Callback = function(v)
			Aim.silentHoldMs = v
		end,
	})
	manipSec:Slider({
		Name = "Snap cap (deg)",
		Min = 6,
		Max = 45,
		Default = 22,
		Increment = 1,
		Flag = "Fust_SilentSnap",
		DependsOn = "Fust_Manip",
		Callback = function(v)
			Aim.silentSnapDeg = v
		end,
	})
	manipSec:Slider({
		Name = "Manip max dist",
		Min = 1,
		Max = 30,
		Default = 5,
		Increment = 0.5,
		Flag = "Fust_ManipDist",
		DependsOn = "Fust_Manip",
		Callback = function(v)
			Aim.manipMaxDistance = v
		end,
	})
	manipSec:Toggle({
		Name = "MANIP % HUD",
		Default = false,
		Flag = "Fust_ManipHud",
		DependsOn = "Fust_Manip",
		Callback = function(v)
			Aim.showManipHud = v
			Aim:syncBind()
		end,
	})

	local hitSec = aimTab:Section({ Name = "Hit scan", Icon = "target", Side = "Right" })
	hitSec:Toggle({
		Name = "Edge aim",
		Default = false,
		Flag = "Fust_HitEdge",
		Callback = function(v)
			Aim.hitScanEdgeAim = v
		end,
	})
	hitSec:Slider({
		Name = "Keep part %",
		Min = 0,
		Max = 100,
		Default = 45,
		Increment = 1,
		Flag = "Fust_HitKeep",
		DependsOn = "Fust_HitEdge",
		Callback = function(v)
			Aim.hitScanKeepPart = v / 100
		end,
	})
	hitSec:Toggle({
		Name = "Multi-point",
		Default = false,
		Flag = "Fust_HitMulti",
		Callback = function(v)
			Aim.hitScanMultiPoint = v
		end,
	})
	hitSec:Toggle({
		Name = "Limbs",
		Default = false,
		Flag = "Fust_HitLimbs",
		Callback = function(v)
			Aim.hitScanLimbs = v
		end,
	})

	local tracerSec = aimTab:Section({ Name = "Combat tracers", Icon = "minus", Side = "Right" })
	tracerSec:Toggle({
		Name = "Enabled",
		Default = false,
		Flag = "Fust_CombatTrace",
		Callback = function(v)
			Aim.combatTracers = v
			Aim:syncBind()
		end,
	})
	tracerSec:Slider({
		Name = "Width",
		Min = 1,
		Max = 6,
		Default = 1,
		Flag = "Fust_TraceW",
		DependsOn = "Fust_CombatTrace",
		Callback = function(v)
			Aim.tracerWidth = v
		end,
	})
	tracerSec:Slider({
		Name = "Life (ms)",
		Min = 50,
		Max = 1200,
		Default = 400,
		Increment = 10,
		Flag = "Fust_TraceLife",
		DependsOn = "Fust_CombatTrace",
		Callback = function(v)
			Aim.tracerLifeMs = v
		end,
	})
	tracerSec:ColorPicker({
		Name = "Colour",
		Default = Color3.fromRGB(255, 120, 200),
		Flag = "Fust_TraceCol",
		DependsOn = "Fust_CombatTrace",
		Callback = function(c)
			Aim.tracerColor = c
		end,
	})

	manipSec:Button({
		Name = "Load external combat preset",
		Callback = function()
			Aim:applyExternalCombatPreset()
			pcall(function()
				Prism:Notify({
					Title = "Combat",
					Content = "Silent + hitscan + manip (camera path)",
					Type = "Info",
					Duration = 3,
				})
			end)
		end,
	})

	local exploitSec = aimTab:Section({ Name = "Exploit", Icon = "alert-triangle", Side = "Right" })
	exploitSec:Label({ Text = "Shoot/Swing FireServer redirect + fullbright stack." })
	if Exploit then
		exploitSec:Toggle({
			Name = "True silent",
			Default = false,
			Risky = true,
			Flag = "Fust_TrueSilent",
			Callback = function(v)
				Exploit.trueSilent = v
				Exploit:syncHook()
			end,
		})
		exploitSec:Toggle({
			Name = "Wall manip",
			Default = false,
			Risky = true,
			Flag = "Fust_WallManip",
			Callback = function(v)
				Exploit.wallManip = v
				Exploit:syncHook()
			end,
		})
		exploitSec:Toggle({
			Name = "Swing redirect",
			Default = false,
			Risky = true,
			Flag = "Fust_SwingHook",
			Callback = function(v)
				Exploit.swingRedirect = v
				Exploit:syncHook()
			end,
		})
		exploitSec:Slider({
			Name = "Wall peek studs",
			Min = 0,
			Max = 15,
			Default = 5,
			Increment = 0.5,
			Flag = "Fust_WallPeek",
			DependsOn = "Fust_WallManip",
			Callback = function(v)
				Exploit.wallManipStuds = v
			end,
		})
		exploitSec:Button({
			Name = "Exploit + lighting only",
			Callback = function()
				Exploit:applyExternalExploitPreset()
			end,
		})
	end

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
	visSec:Toggle({
		Name = "Box fill",
		Default = false,
		Flag = "Fust_EspFill",
		DependsOn = "Fust_EspBox",
		Callback = function(v)
			Esp.boxFill = v
		end,
	})
	visSec:Slider({
		Name = "Fill opacity",
		Min = 0.05,
		Max = 0.5,
		Default = 0.14,
		Increment = 0.01,
		Flag = "Fust_EspFillA",
		DependsOn = "Fust_EspFill",
		Callback = function(v)
			Esp.boxFillAlpha = v
		end,
	})
	visSec:Slider({
		Name = "Corner scale",
		Min = 0.12,
		Max = 0.45,
		Default = 0.28,
		Increment = 0.01,
		Flag = "Fust_EspCorner",
		DependsOn = "Fust_EspBox",
		Callback = function(v)
			Esp.cornerScale = v
		end,
	})
	visSec:Slider({
		Name = "Corner px (external)",
		Min = 4,
		Max = 24,
		Default = 8,
		Increment = 1,
		Flag = "Fust_EspCornerPx",
		DependsOn = "Fust_EspBox",
		Callback = function(v)
			Esp.cornerLength = v
		end,
	})
	visSec:Toggle({
		Name = "Drawing ESP",
		Default = Esp.useDrawing == true,
		Flag = "Fust_EspDrawing",
		Callback = function(v)
			Esp.useDrawing = v
			if Esp.destroy then
				pcall(function()
					Esp:destroy()
				end)
			end
			if Esp.master then
				Esp:setMaster(true)
			end
		end,
	})
	visSec:Dropdown({
		Name = "Name style",
		Options = { "Classic", "External" },
		Default = Esp.labelStyle == "External" and "External" or "Classic",
		Flag = "Fust_EspLabelStyle",
		Callback = function(v)
			Esp.labelStyle = v
		end,
	})
	visSec:Toggle({ Name = "Tracers", Default = false, Flag = "Fust_EspTrace", Callback = function(v)
		Esp.tracers = v
	end })
	visSec:Toggle({ Name = "Team check", Default = false, Flag = "Fust_EspTeam", Callback = function(v)
		Esp.teamCheck = v
	end })
	visSec:Toggle({ Name = "Distance fade", Default = false, Flag = "Fust_EspFade", Callback = function(v)
		Esp.distanceFade = v
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
	visSec:Toggle({
		Name = "Visible colour",
		Default = false,
		Flag = "Fust_EspVis",
		Callback = function(v)
			Esp.visibleCheck = v
		end,
	})
	visSec:ColorPicker({
		Name = "When visible",
		Default = Color3.fromRGB(152, 255, 200),
		Flag = "Fust_EspVisCol",
		DependsOn = "Fust_EspVis",
		Callback = function(c)
			Esp.visibleColor = c
		end,
	})
	visSec:ColorPicker({
		Name = "When hidden",
		Default = Color3.fromRGB(255, 120, 120),
		Flag = "Fust_EspHideCol",
		DependsOn = "Fust_EspVis",
		Callback = function(c)
			Esp.hiddenColor = c
		end,
	})
	visSec:Button({
		Name = "Load external ESP preset",
		Callback = function()
			Esp:applyExternalVisualPreset()
			pcall(function()
				Prism:Notify({ Title = "ESP", Content = "Corner box + fill + weapon line", Type = "Info", Duration = 3 })
			end)
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
	wMaster:Slider({
		Name = "Node max distance",
		Min = 0,
		Max = 1200,
		Default = 0,
		Increment = 25,
		Flag = "Fust_WorldNodeDist",
		Callback = function(v)
			World.nodeMaxDist = v
		end,
	})
	wMaster:Toggle({
		Name = "Node HP %",
		Default = false,
		Flag = "Fust_WorldNodeHp",
		Callback = function(v)
			World.showNodeHp = v
		end,
	})
	wMaster:Button({
		Name = "Load external world ESP",
		Callback = function()
			World:applyExternalWorldEspPreset()
			pcall(function()
				Prism:Notify({ Title = "World ESP", Content = "Nodes, loot, furnaces, bags", Type = "Info", Duration = 3 })
			end)
		end,
	})

	local function worldToggle(sec, name, flag, key)
		sec:Toggle({
			Name = name,
			Default = false,
			Flag = flag,
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
	worldToggle(wLoot, "Loot bags", "Fust_W_LootBag", "loot_bag")
	worldToggle(wLoot, "World items", "Fust_W_Item", "world_item")
	worldToggle(wLoot, "Airdrop", "Fust_W_Air", "airdrop")
	worldToggle(wLoot, "Arrows", "Fust_W_Arrow", "arrow_pickup")

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
	worldToggle(wThreat, "Furnaces", "Fust_W_Furnace", "furnace")
	worldToggle(wThreat, "Campfires", "Fust_W_Fire", "campfire")
	worldToggle(wThreat, "Sleeping bags", "Fust_W_SleepBag", "sleeping_bag")
	worldToggle(wThreat, "Workbenches", "Fust_W_Bench", "workbench")

	local wVeh = worldTab:Section({ Name = "Vehicles", Icon = "car", Side = "Left" })
	worldToggle(wVeh, "ATV", "Fust_W_Atv", "atv")
	worldToggle(wVeh, "Minicopter", "Fust_W_Heli", "minicopter")
	worldToggle(wVeh, "Patrol heli", "Fust_W_Patrol", "patrol_heli")
	worldToggle(wVeh, "Boats", "Fust_W_Boat", "boat")

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
	gunSec:Toggle({
		Name = "No recoil",
		Default = false,
		Risky = true,
		Flag = "Fust_NoRecoil",
		Callback = function(v)
			if Misc then
				Misc.noRecoil = v
				Misc:syncRecoilMods()
			end
		end,
	})
	gunSec:Toggle({
		Name = "No spread",
		Default = false,
		Risky = true,
		Flag = "Fust_NoSpread",
		Callback = function(v)
			if Misc then
				Misc.noSpread = v
				Misc:syncRecoilMods()
			end
		end,
	})
	gunSec:Slider({
		Name = "Recoil amount",
		Min = 0,
		Max = 100,
		Default = 100,
		Increment = 5,
		Flag = "Fust_RecoilAmt",
		Callback = function(v)
			if Misc then
				Misc.recoilScale = v / 100
				Misc:syncRecoilMods()
			end
		end,
	})
	gunSec:Slider({
		Name = "Spread amount",
		Min = 0,
		Max = 100,
		Default = 100,
		Increment = 5,
		Flag = "Fust_SpreadAmt",
		Callback = function(v)
			if Misc then
				Misc.spreadScale = v / 100
				Misc:syncRecoilMods()
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
	moveSec:Toggle({
		Name = "Noclip",
		Default = false,
		Risky = true,
		Flag = "Fust_Noclip",
		Callback = function(v)
			if Misc then
				Misc.noclipEnabled = v
				Misc:syncNoclip()
			end
		end,
	})
	moveSec:Toggle({
		Name = "Noclip hold (N)",
		Default = false,
		Flag = "Fust_NoclipHold",
		DependsOn = "Fust_Noclip",
		Callback = function(v)
			if Misc then
				Misc.noclipHold = v
				Misc:syncNoclip()
			end
		end,
	})
	moveSec:Toggle({
		Name = "Noclip key",
		Default = false,
		Flag = "Fust_NoclipKey",
		Mode = "Hold",
		Keybind = Enum.KeyCode.N,
		DependsOn = "Fust_NoclipHold",
		Callback = function(v)
			if Misc then
				Misc.noclipKeyHeld = v
				Misc:syncNoclip()
			end
		end,
	})
	moveSec:Toggle({
		Name = "FustBodyBlock group",
		Default = true,
		Flag = "Fust_NoclipBodyBlock",
		DependsOn = "Fust_Noclip",
		Callback = function(v)
			if Misc then
				Misc.noclipUseBodyBlock = v
				if Misc.noclipEnabled then
					Misc:syncNoclip()
				end
			end
		end,
	})
	moveSec:Slider({
		Name = "Noclip depth",
		Min = 0.05,
		Max = 0.5,
		Default = 0.2,
		Increment = 0.01,
		Flag = "Fust_NoclipDepth",
		DependsOn = "Fust_Noclip",
		Callback = function(v)
			if Misc then
				Misc.noclipDepth = v
			end
		end,
	})
	moveSec:Label({ Text = "external: Depth 0.2, Min 0.1 — uses game FustBodyBlock + phase step" })

	local lightSec = worldTab:Section({ Name = "Custom lighting", Icon = "sun", Side = "Right" })
	lightSec:Label({ Text = "Matches external.wtf time/brightness — FustSky ACM may flag." })
	lightSec:Toggle({
		Name = "Enabled",
		Default = false,
		Risky = true,
		Flag = "Fust_CustomLight",
		Callback = function(v)
			World.customLight = v
			World:syncCustomLight()
		end,
	})
	lightSec:Slider({
		Name = "Brightness",
		Min = 0,
		Max = 5,
		Default = 2,
		Increment = 0.05,
		Flag = "Fust_LightBright",
		DependsOn = "Fust_CustomLight",
		Callback = function(v)
			World.lightBrightness = v
			if World.customLight then
				World:syncCustomLight()
			end
		end,
	})
	lightSec:Slider({
		Name = "Time of day",
		Min = 0,
		Max = 24,
		Default = 14,
		Increment = 0.25,
		Flag = "Fust_LightTime",
		DependsOn = "Fust_CustomLight",
		Callback = function(v)
			World.lightClock = v
			if World.customLight then
				World:syncCustomLight()
			end
		end,
	})
	lightSec:Slider({
		Name = "Exposure",
		Min = -1,
		Max = 2,
		Default = 0,
		Increment = 0.05,
		Flag = "Fust_LightExp",
		DependsOn = "Fust_CustomLight",
		Callback = function(v)
			World.lightExposure = v
			if World.customLight then
				World:syncCustomLight()
			end
		end,
	})
	lightSec:Slider({
		Name = "Contrast",
		Min = -1,
		Max = 1,
		Default = 0,
		Increment = 0.05,
		Flag = "Fust_LightContrast",
		DependsOn = "Fust_CustomLight",
		Callback = function(v)
			World.lightContrast = v
			if World.customLight then
				World:syncCustomLight()
			end
		end,
	})
	lightSec:Toggle({
		Name = "No fog",
		Default = false,
		Flag = "Fust_NoFog",
		DependsOn = "Fust_CustomLight",
		Callback = function(v)
			World.noFog = v
			if World.customLight then
				World:syncCustomLight()
			end
		end,
	})
	lightSec:ColorPicker({
		Name = "Ambience",
		Default = Color3.fromRGB(140, 140, 160),
		Flag = "Fust_LightAmb",
		DependsOn = "Fust_CustomLight",
		Callback = function(c)
			World.lightAmbient = c
			if World.customLight then
				World:syncCustomLight()
			end
		end,
	})
	lightSec:Button({
		Name = "external.wtf preset",
		Callback = function()
			World:applyExternalLightPreset()
			pcall(function()
				Prism:Notify({ Title = "Lighting", Content = "Brightness 2 · time 14", Type = "Warning", Duration = 3 })
			end)
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
	Aim:setHitscan(false)
	Aim.manip = false
	Aim.bowPrediction = false
	Aim.bowSpeed = 280
	Aim.bowGravity = true

	local RISKY_FLAGS = {
		"Fust_AimOn",
		"Fust_SilentOn",
		"Fust_Manip",
		"Fust_ManipHud",
		"Fust_CombatTrace",
		"Fust_HitEdge",
		"Fust_HitMulti",
		"Fust_HitLimbs",
		"Fust_TrigOn",
		"Fust_Battle",
		"Fust_AimKey1",
		"Fust_AimKey2",
		"Fust_TrigKey",
		"Fust_FarmOn",
		"Fust_KillOn",
		"Fust_Hitbox",
		"Fust_SpeedOn",
		"Fust_Noclip",
		"Fust_NoclipHold",
		"Fust_WallClimb",
		"Fust_GunAuto",
		"Fust_GunRapid",
		"Fust_NoRecoil",
		"Fust_NoSpread",
		"Fust_CustomLight",
		"Fust_TrueSilent",
		"Fust_WallManip",
		"Fust_SwingHook",
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
		Aim.manip = false
		Aim.showManipHud = false
		Aim.combatTracers = false
		Aim.hitScanEdgeAim = false
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
			Misc.noclipEnabled = false
			Misc.noclipKeyHeld = false
			Misc:syncNoclip()
			Misc.gunAuto = false
			Misc.gunRapid = false
			Misc.bowEnabled = false
			Misc:syncBind()
		end
		if World then
			World.freecamOn = false
			World.tp3On = false
			World.zoomHeld = false
			World.customLight = false
			World:sync()
		end
		if Misc then
			Misc.noRecoil = false
			Misc.noSpread = false
			Misc:syncRecoilMods()
		end
		if Exploit then
			Exploit.trueSilent = false
			Exploit.wallManip = false
			Exploit.swingRedirect = false
			Exploit:syncHook()
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

	local cfgSec = setTab:Section({ Name = "Configs", Icon = "save", Side = "Left" })
	local canFiles = type(isfile) == "function"
		and type(writefile) == "function"
		and type(readfile) == "function"
	local autoPath = Window.ConfigFolder .. "/autoload.txt"
	local autoSavePath = Window.ConfigFolder .. "/autosave.txt"
	local syncProfiles = function() end

	local function listedConfigs()
		local out = {}
		for _, name in ipairs(Window:ListConfigs()) do
			if name ~= "profiles" then
				table.insert(out, name)
			end
		end
		return out
	end

	local nameBox = cfgSec:Textbox({
		Name = "Name",
		Placeholder = "default",
		Default = "default",
		Callback = function()
			syncProfiles()
		end,
	})
	local cfgList = cfgSec:Dropdown({
		Name = "Saved",
		Options = listedConfigs(),
		Placeholder = "—",
		Callback = function(v)
			if v and nameBox and nameBox.Set then
				nameBox:Set(v, true)
				syncProfiles()
			end
		end,
	})
	local function cfgName()
		local n = nameBox and nameBox.Value
		if type(n) == "string" and n ~= "" then
			return n
		end
		return "default"
	end
	local function refreshConfigs()
		if cfgList and cfgList.Refresh then
			cfgList:Refresh(listedConfigs())
		end
	end
	cfgSec:Button({
		Name = "Save",
		Icon = "save",
		Style = "Primary",
		Callback = function()
			local ok = Window:SaveConfig(cfgName())
			refreshConfigs()
			pcall(function()
				Prism:Notify({
					Title = ok and "Saved" or "Failed",
					Content = ok and cfgName() or "No file access",
					Type = ok and "Success" or "Error",
					Duration = 3,
				})
			end)
		end,
	})
	cfgSec:ButtonRow({
		{
			Name = "Load",
			Icon = "folder-open",
			Callback = function()
				local ok = Window:LoadConfig(cfgName())
				syncProfiles()
				pcall(function()
					Prism:Notify({
						Title = ok and "Loaded" or "Missing",
						Content = cfgName(),
						Type = ok and "Success" or "Warning",
						Duration = 3,
					})
				end)
			end,
		},
		{
			Name = "Delete",
			Icon = "trash-2",
			Hold = 1,
			HoldText = "Hold...",
			Callback = function()
				if Window:DeleteConfig(cfgName()) then
					refreshConfigs()
					syncProfiles()
				end
			end,
		},
		{
			Name = "Refresh",
			Icon = "refresh-cw",
			Callback = refreshConfigs,
		},
	})
	cfgSec:ButtonRow({
		{
			Name = "Share",
			Icon = "upload",
			Callback = function()
				pcall(function()
					Prism:Notify({ Title = "Uploading…", Content = "", Duration = 2 })
				end)
				local code, err = Window:ShareConfig()
				if code then
					if setclipboard then
						setclipboard(code)
					end
					pcall(function()
						Prism:Notify({
							Title = "Share: " .. tostring(code),
							Content = "Copied",
							Type = "Success",
							Duration = 8,
						})
					end)
				else
					pcall(function()
						Prism:Notify({
							Title = "Share failed",
							Content = tostring(err or ""),
							Type = "Error",
							Duration = 4,
						})
					end)
				end
			end,
		},
		{
			Name = "Export",
			Icon = "copy",
			Callback = function()
				if setclipboard then
					setclipboard(Window:ExportConfig())
					pcall(function()
						Prism:Notify({ Title = "Exported", Content = "Clipboard", Type = "Success", Duration = 3 })
					end)
				end
			end,
		},
	})
	cfgSec:Textbox({
		Name = "Import",
		Placeholder = "Paste JSON…",
		ClearOnEnter = true,
		Callback = function(text)
			if text == "" then
				return
			end
			local ok = Window:ImportConfig(text)
			pcall(function()
				Prism:Notify({
					Title = ok and "Imported" or "Invalid",
					Content = "",
					Type = ok and "Success" or "Error",
					Duration = 3,
				})
			end)
		end,
	})
	cfgSec:Textbox({
		Name = "Import code",
		Placeholder = "Share code…",
		ClearOnEnter = true,
		Callback = function(code)
			if code == "" then
				return
			end
			local ok, err = Window:ImportShared(code)
			pcall(function()
				Prism:Notify({
					Title = ok and "Imported" or "Failed",
					Content = ok and "" or tostring(err or ""),
					Type = ok and "Success" or "Error",
					Duration = 3,
				})
			end)
		end,
	})

	local function autoloadName()
		if canFiles and isfile(autoPath) then
			return readfile(autoPath)
		end
		return nil
	end
	local autoToggle = cfgSec:Toggle({
		Name = "Autoload",
		Default = false,
		HideFromList = true,
		Callback = function(on)
			if not canFiles then
				return
			end
			pcall(function()
				if type(makefolder) == "function" then
					makefolder(Window.ConfigFolder)
				end
				if on then
					writefile(autoPath, cfgName())
				elseif isfile(autoPath) and readfile(autoPath) == cfgName() and type(delfile) == "function" then
					delfile(autoPath)
				end
			end)
		end,
	})
	local placeToggle = cfgSec:Toggle({
		Name = "Place profile",
		Default = false,
		HideFromList = true,
		Callback = function(on)
			if on then
				Window:SetProfile("Place", cfgName())
			elseif Window:GetProfile("Place") == cfgName() then
				Window:SetProfile("Place", nil)
			end
		end,
	})
	local accountToggle = cfgSec:Toggle({
		Name = "Account profile",
		Default = false,
		HideFromList = true,
		Callback = function(on)
			if on then
				Window:SetProfile("Account", cfgName())
			elseif Window:GetProfile("Account") == cfgName() then
				Window:SetProfile("Account", nil)
			end
		end,
	})
	syncProfiles = function()
		local name = cfgName()
		if autoToggle and autoToggle.Set then
			autoToggle:Set(autoloadName() == name, true)
		end
		if placeToggle and placeToggle.Set then
			placeToggle:Set(Window:GetProfile("Place") == name, true)
		end
		if accountToggle and accountToggle.Set then
			accountToggle:Set(Window:GetProfile("Account") == name, true)
		end
	end

	local saveStat = cfgSec:Stat({ Name = "Auto-save", Value = "Off", Icon = "clock" })
	local lastSnapshot, warnedOverwrite
	local function snapshot()
		return Window:ExportConfig()
	end
	local function autoSave()
		if not (Window.AutoSave and canFiles) then
			return
		end
		local snap = snapshot()
		if snap == lastSnapshot then
			return
		end
		local target = Window.ActiveConfig
		if not target then
			local name = cfgName()
			if isfile(Window.ConfigFolder .. "/" .. name .. ".json") then
				if not warnedOverwrite then
					warnedOverwrite = true
					pcall(function()
						Prism:Notify({
							Title = "Auto-save paused",
							Content = name .. " exists — load or overwrite",
							Type = "Warning",
							Duration = 10,
							Buttons = {
								{
									Name = "Load",
									Primary = true,
									Callback = function()
										Window:LoadConfig(name)
									end,
								},
								{
									Name = "Overwrite",
									Callback = function()
										Window.ActiveConfig = name
									end,
								},
							},
						})
					end)
				end
				return
			end
			target = name
		end
		lastSnapshot = snap
		local isNew = not isfile(Window.ConfigFolder .. "/" .. target .. ".json")
		if Window:SaveConfig(target) then
			if saveStat and saveStat.Set then
				saveStat:Set(target .. " · " .. os.date("%H:%M:%S"))
			end
			if isNew then
				refreshConfigs()
			end
		end
	end
	Window._autoSaveFinal = autoSave
	local autoSaveDefault = canFiles and isfile(autoSavePath) or false
	Window.AutoSave = autoSaveDefault
	if autoSaveDefault and saveStat and saveStat.Set then
		saveStat:Set("Waiting…")
	end
	cfgSec:Toggle({
		Name = "Auto-save",
		Default = autoSaveDefault,
		HideFromList = true,
		Callback = function(on)
			Window.AutoSave = on
			warnedOverwrite = false
			if saveStat and saveStat.Set then
				saveStat:Set(on and "Waiting…" or "Off")
			end
			if not canFiles then
				return
			end
			pcall(function()
				if type(makefolder) == "function" then
					makefolder(Window.ConfigFolder)
				end
				if on then
					writefile(autoSavePath, "1")
				elseif isfile(autoSavePath) and type(delfile) == "function" then
					delfile(autoSavePath)
				end
			end)
		end,
	})
	task.spawn(function()
		task.wait(3)
		lastSnapshot = snapshot()
		while Window.Gui and Window.Gui.Parent and not Window._unloaded do
			pcall(autoSave)
			task.wait(2)
		end
	end)

	-- Startup: place → account → autoload.txt
	task.defer(function()
		local startName = Window:GetProfile("Place")
		if not startName then
			startName = Window:GetProfile("Account")
		end
		if not startName and canFiles and isfile(autoPath) then
			startName = readfile(autoPath)
		end
		if type(startName) == "string" and startName ~= "" then
			if nameBox and nameBox.Set then
				nameBox:Set(startName, true)
			end
			Window:LoadConfig(startName)
			refreshConfigs()
		end
		syncProfiles()
	end)

	local safeSec = setTab:Section({ Name = "Safety", Icon = "shield", Side = "Right" })
	if Presets and Presets.applyExternalFull then
		safeSec:Button({
			Name = "external.wtf — LOAD EVERYTHING",
			Icon = "zap",
			Callback = function()
				Presets:applyExternalFull()
				pcall(function()
					Prism:Notify({
						Title = "Full stack",
						Content = "ESP + aim + world + guns + true silent + lighting",
						Type = "Warning",
						Duration = 5,
					})
				end)
			end,
		})
	end
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
		if Exploit then
			Exploit:destroy()
		end
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
	bundle.Exploit = Exploit
	bundle.Presets = Presets
	bundle.applyExternalFull = Presets and Presets.applyExternalFull
	bundle.panic = panic
	return bundle
end
