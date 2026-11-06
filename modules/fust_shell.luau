-- Prism menu shell: ESP + Aimbot tabs. Returns factory(deps) -> bundle
return function(deps)
	local Prism = deps.Prism
	local Esp = deps.Esp
	local Aim = deps.Aim
	local World = deps.World
	local bundleVersion = deps.BundleVersion or "2.4.4"

	Prism.ReduceMotion = true
	Prism.Sounds = false
	if Prism._unloadAll then
		Prism:_unloadAll()
	end

	Esp:cleanupBeforeLoad()

	local Window = Prism:CreateWindow({
		Title = "Fust Hub",
		Subtitle = "esp + combat v2",
		Footer = bundleVersion,
		Intro = false,
		ToggleKey = Enum.KeyCode.RightControl,
		Size = Vector2.new(620, 620),
	})

	local espTab = Window:Tab({ Name = "ESP", Icon = "eye", Description = "Player overlays" })
	local mainSec = espTab:Section({ Name = "Master", Icon = "toggle-right", Side = "Left" })

	local holdOn = false
	local toggleOn = false

	local function syncMaster()
		Esp:setMaster(holdOn or toggleOn)
	end

	mainSec:Toggle({
		Name = "ESP (toggle)",
		Description = "Always on while enabled",
		Default = false,
		Flag = "Fust_EspToggle",
		Callback = function(v)
			toggleOn = v
			syncMaster()
		end,
	})

	mainSec:Toggle({
		Name = "ESP (hold)",
		Description = "Hold key — click the key chip to rebind",
		Default = false,
		Flag = "Fust_EspHold",
		Mode = "Hold",
		Keybind = Enum.KeyCode.X,
		Callback = function(v)
			holdOn = v
			syncMaster()
		end,
	})

	local visSec = espTab:Section({ Name = "Visuals", Icon = "users", Side = "Left" })

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
	visSec:Toggle({
		Name = "Rounded joints",
		Description = "Smooth dots where bones meet (close range)",
		Default = true,
		Flag = "Fust_EspJoints",
		DependsOn = "Fust_EspSkel",
		Callback = function(v)
			Esp.joints = v
		end,
	})
	visSec:Toggle({
		Name = "Outline",
		Description = "Dark edge behind lines so they read on any background",
		Default = true,
		Flag = "Fust_EspOutline",
		Callback = function(v)
			Esp.outline = v
		end,
	})
	visSec:Toggle({ Name = "Name", Default = true, Flag = "Fust_EspName", Callback = function(v)
		Esp.name = v
	end })
	visSec:Toggle({ Name = "Distance", Default = true, Flag = "Fust_EspDist", Callback = function(v)
		Esp.distance = v
	end })
	visSec:Toggle({
		Name = "Held weapon",
		Description = "Tool.Name (+ skin) under the box — no Items require",
		Default = true,
		Flag = "Fust_EspHeld",
		Callback = function(v)
			Esp.held = v
		end,
	})
	visSec:Toggle({
		Name = "Armour",
		Description = "Unique FustWear ItemIds under the box",
		Default = false,
		Flag = "Fust_EspArmor",
		Callback = function(v)
			Esp.armor = v
		end,
	})
	visSec:Toggle({ Name = "Health bar", Description = "Colour shifts green to red", Default = true, Flag = "Fust_EspHpBar", Callback = function(v)
		Esp.healthBar = v
	end })
	visSec:Toggle({ Name = "Health text", Default = false, Flag = "Fust_EspHpTxt", Callback = function(v)
		Esp.healthText = v
	end })
	visSec:ColorPicker({
		Name = "ESP colour",
		Default = Color3.fromRGB(235, 235, 235),
		Flag = "Fust_EspCol",
		Callback = function(c)
			Esp.color = c
		end,
	})
	visSec:Slider({
		Name = "Line thickness",
		Min = 1,
		Max = 4,
		Default = 1.5,
		Increment = 0.5,
		Suffix = " px",
		Flag = "Fust_EspThick",
		Callback = function(v)
			Esp.thickness = v
		end,
	})

	local rangeSec = espTab:Section({ Name = "Range & performance", Icon = "gauge", Side = "Right" })

	rangeSec:Slider({
		Name = "Max distance",
		Description = "How far away players are shown",
		Min = 100,
		Max = 5000,
		Default = 2500,
		Increment = 50,
		Suffix = " st",
		Flag = "Fust_EspRange",
		Callback = function(v)
			Esp.maxDist = v
		end,
	})
	rangeSec:Slider({
		Name = "Skeleton range",
		Description = "Beyond this: box + name only",
		Min = 50,
		Max = 1000,
		Default = 400,
		Increment = 25,
		Suffix = " st",
		Flag = "Fust_EspSkelRange",
		Callback = function(v)
			Esp.skelDist = v
		end,
	})
	rangeSec:Slider({
		Name = "Health bar range",
		Description = "Max studs to draw the HP bar",
		Min = 25,
		Max = 400,
		Default = 50,
		Increment = 5,
		Suffix = " st",
		Flag = "Fust_EspHpRange",
		Callback = function(v)
			Esp.healthBarMaxDist = v
		end,
	})
	rangeSec:Slider({
		Name = "Max players",
		Description = "Closest players drawn",
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
		Description = "How often ESP redraws (30 light → 240 smooth)",
		Min = 30,
		Max = 240,
		Default = 30,
		Increment = 5,
		Suffix = " fps",
		Flag = "Fust_EspRate",
		Callback = function(v)
			Esp.rate = v
		end,
	})

	local aimTab = Window:Tab({ Name = "Aimbot", Icon = "crosshair", Description = "Full combat tab · v" .. bundleVersion })

	local aimSec = aimTab:Section({ Name = "Aimbot", Icon = "target", Side = "Left" })
	aimSec:Toggle({
		Name = "Aimbot enabled",
		Default = false,
		Flag = "Fust_AimOn",
		Callback = function(v)
			Aim.aimbotEnabled = v
			Aim:syncBind()
		end,
	})
	aimSec:Toggle({
		Name = "Aimbot prediction",
		Default = false,
		Flag = "Fust_AimPred",
		Callback = function(v)
			Aim.prediction = v
		end,
	})
	aimSec:Dropdown({
		Name = "Target bone selection",
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
		Name = "Aimbot smoothing",
		Min = 1,
		Max = 100,
		Default = 36,
		Increment = 0.1,
		Flag = "Fust_AimSmooth",
		Callback = function(v)
			Aim.smoothing = v
		end,
	})
	aimSec:Slider({
		Name = "Weapon aim FOV",
		Description = "Screen radius (px) for target pick",
		Min = 20,
		Max = 400,
		Default = 120,
		Increment = 0.1,
		Flag = "Fust_WeaponFov",
		Callback = function(v)
			Aim.weaponFovPx = v
		end,
	})
	aimSec:Slider({
		Name = "Aimbot max distance",
		Min = 25,
		Max = 3000,
		Default = 1500,
		Increment = 5,
		Suffix = " st",
		Flag = "Fust_AimRange",
		Callback = function(v)
			Aim.maxDist = v
		end,
	})
	aimSec:Toggle({
		Name = "Silent aim (camera)",
		Description = "Snap camera on LMB — not bullet redirect",
		Default = false,
		Risky = true,
		Flag = "Fust_SilentOn",
		Callback = function(v)
			Aim.silentOn = v
			Aim:syncBind()
		end,
	})
	aimSec:Slider({
		Name = "Silent aim FOV",
		Min = 15,
		Max = 250,
		Default = 90,
		Increment = 1,
		Flag = "Fust_SilentFovPx",
		Callback = function(v)
			Aim.silentFovPx = v
		end,
	})

	aimSec:Slider({
		Name = "Lock strength",
		Description = "Max degrees per frame toward target",
		Min = 2,
		Max = 12,
		Default = 6.5,
		Increment = 0.25,
		Flag = "Fust_LockCap",
		Callback = function(v)
			Aim.lockCapDeg = v
		end,
	})

	local miscSec = aimTab:Section({ Name = "Misc options", Icon = "sliders", Side = "Right" })
	miscSec:Toggle({
		Name = "Draw FOV",
		Default = true,
		Flag = "Fust_DrawFov",
		Callback = function(v)
			Aim.drawFov = v
			Aim:syncBind()
		end,
	})
	miscSec:Toggle({
		Name = "Filled FOV",
		Default = false,
		Flag = "Fust_FillFov",
		Callback = function(v)
			Aim.filledFov = v
			Aim:syncBind()
		end,
	})
	miscSec:Toggle({
		Name = "Visible check",
		Description = "Raycast LOS — only aim at targets you can see",
		Default = false,
		Flag = "Fust_VisCheck",
		Callback = function(v)
			Aim.visibleCheck = v
		end,
	})
	miscSec:Toggle({
		Name = "Visual check HUD",
		Description = "Status line — throttled; leave off for less CPU",
		Default = false,
		Flag = "Fust_VisualHud",
		Callback = function(v)
			Aim.visualCheck = v
			Aim:syncBind()
		end,
	})
	miscSec:Toggle({
		Name = "Mouse aim (Fust)",
		Description = "Moves mouse for FustPad — required for lock",
		Default = true,
		Flag = "Fust_MouseAim",
		Callback = function(v)
			Aim.useMouseDrive = v
		end,
	})
	miscSec:Slider({
		Name = "Mouse aim strength",
		Min = 0.05,
		Max = 0.6,
		Default = 0.22,
		Increment = 0.01,
		Flag = "Fust_MouseStr",
		Callback = function(v)
			Aim.mouseDriveStrength = v
		end,
	})
	miscSec:Toggle({
		Name = "Ignore knocked",
		Default = true,
		Flag = "Fust_IgnKnock",
		Callback = function(v)
			Aim.ignoreKnocked = v
		end,
	})
	miscSec:Toggle({
		Name = "Ignore team",
		Default = true,
		Flag = "Fust_IgnTeam",
		Callback = function(v)
			Aim.ignoreTeam = v
		end,
	})
	miscSec:Slider({
		Name = "Aimbot deadzone",
		Description = "Pixels from crosshair — no micro aim inside",
		Min = 0,
		Max = 40,
		Default = 3,
		Increment = 0.1,
		Flag = "Fust_Deadzone",
		Callback = function(v)
			Aim.deadzonePx = v
		end,
	})
	miscSec:Toggle({
		Name = "Crosshair",
		Default = true,
		Flag = "Fust_CrossOn",
		Callback = function(v)
			Aim.showCrosshair = v
			Aim:syncBind()
		end,
	})
	miscSec:ColorPicker({
		Name = "FOV / cross colour",
		Default = Color3.fromRGB(235, 70, 70),
		Flag = "Fust_AimCol",
		Callback = function(c)
			Aim.crossColor = c
			Aim.fovRingColor = c
			Aim:destroyCrosshair()
			if Aim.drawFov or Aim.showCrosshair or Aim.visualCheck then
				Aim:ensureCrosshair()
				Aim:syncBind()
			end
		end,
	})
	miscSec:Toggle({
		Name = "Require ADS",
		Description = "Gun/bow aim or RMB — off = always allow aim",
		Default = false,
		Flag = "Fust_AimAds",
		Callback = function(v)
			Aim.requireAds = v
		end,
	})

	local trigSec = aimTab:Section({ Name = "Triggerbot", Icon = "mouse-pointer-click", Side = "Left" })
	trigSec:Toggle({
		Name = "Triggerbot enabled",
		Default = false,
		Risky = true,
		Flag = "Fust_TrigOn",
		Callback = function(v)
			Aim.triggerEnabled = v
			Aim:syncBind()
		end,
	})
	trigSec:Dropdown({
		Name = "Triggerbot bone selection",
		Multi = true,
		Default = { "Head" },
		Options = { "Head", "Neck", "Chest", "Pelvis" },
		Flag = "Fust_TrigBones",
		Callback = function(v)
			if type(v) == "table" and #v > 0 then
				Aim.triggerBones = v
			end
		end,
	})
	trigSec:Slider({
		Name = "Triggerbot delay",
		Min = 0,
		Max = 200,
		Default = 10,
		Increment = 1,
		Suffix = " ms",
		Flag = "Fust_TrigDelay",
		Callback = function(v)
			Aim.triggerDelayMs = v
		end,
	})

	local keySec = aimTab:Section({ Name = "Keybinds", Icon = "keyboard", Side = "Right" })
	keySec:Toggle({
		Name = "Require hold key",
		Description = "Off = locks whenever aimbot enabled",
		Default = false,
		Flag = "Fust_ReqHold",
		Callback = function(v)
			Aim.requireHoldKey = v
		end,
	})
	keySec:Label("Click a key chip, then press a key or MB1/MB2/MB3. Esc clears.")
	keySec:Toggle({
		Name = "Aimbot key",
		Description = "Hold to aim — click the key chip to rebind",
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
	keySec:Toggle({
		Name = "Aimbot key 2",
		Description = "Click the key chip to rebind (e.g. MB2)",
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
	keySec:Toggle({
		Name = "Triggerbot key",
		Description = "Click the key chip to rebind",
		Default = false,
		Flag = "Fust_TrigKey",
		Mode = "Hold",
		Keybind = Enum.KeyCode.B,
		Callback = function(v)
			Aim.triggerKeyHeld = v
		end,
		KeyChanged = function(key)
			Aim.triggerKey = key
		end,
	})
	keySec:Toggle({
		Name = "Battlemode toggle",
		Description = "Ignores ADS requirement — click the key chip to rebind",
		Default = false,
		Flag = "Fust_Battle",
		Mode = "Toggle",
		Keybind = Enum.KeyCode.P,
		Callback = function(v)
			Aim.battleMode = v
		end,
	})

	Aim.requireHoldKey = false
	Aim.requireAds = false
	Aim.useMouseDrive = true

	local worldTab = Window:Tab({ Name = "World", Icon = "sun", Description = "Lighting & time" })
	local lightSec = worldTab:Section({ Name = "Lighting", Icon = "sun", Side = "Left" })
	lightSec:Toggle({
		Name = "Fullbright",
		Description = "Camera colour lift — does not touch Lighting (FustSky checks that)",
		Default = false,
		Flag = "Fust_Fullbright",
		Callback = function(v)
			World.fullbrightOn = v
			World:sync()
		end,
	})
	lightSec:Slider({
		Name = "Fullbright strength",
		Min = 0.05,
		Max = 0.6,
		Default = 0.25,
		Increment = 0.01,
		Flag = "Fust_FbStrength",
		Callback = function(v)
			World.brightness = v
			if World.fullbrightOn then
				World:sync()
			end
		end,
	})
	local timeSec = worldTab:Section({ Name = "Time", Icon = "clock", Side = "Right" })
	timeSec:Label("Making night into day gets reported by FustSky after ~3s. Darker times are not flagged.")
	timeSec:Toggle({
		Name = "Time changer",
		Description = "Locks ClockTime — brighter than real time is reported",
		Default = false,
		Risky = true,
		Flag = "Fust_TimeOn",
		Callback = function(v)
			World.timeControlOn = v
			World:sync()
		end,
	})
	timeSec:Slider({
		Name = "Time of day",
		Description = "0 = midnight, 12 = noon, 24 = midnight",
		Min = 0,
		Max = 24,
		Default = 14,
		Increment = 0.05,
		Flag = "Fust_Clock",
		Callback = function(v)
			World.clockTime = v
			if World.timeControlOn then
				World:sync()
			end
		end,
	})

	-- Panic: flip every active/reportable feature off at once. Flips the Prism
	-- flags (not just the Aim fields) so the UI reflects it. Passive ESP and the
	-- camera-grade fullbright stay on — they do not touch the AC.
	local RISKY_FLAGS = {
		"Fust_AimOn",
		"Fust_SilentOn",
		"Fust_TrigOn",
		"Fust_TimeOn",
		"Fust_Battle",
		"Fust_AimKey1",
		"Fust_AimKey2",
		"Fust_TrigKey",
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
		-- Belt and braces: force the module off even if a flag is missing.
		Aim.aimbotEnabled = false
		Aim.silentOn = false
		Aim.triggerEnabled = false
		Aim.battleMode = false
		Aim.aimKey1Held = false
		Aim.aimKey2Held = false
		Aim.triggerKeyHeld = false
		Aim.firingSilent = false
		Aim:syncBind()
		if World then
			World.timeControlOn = false
			World:sync()
		end
		pcall(function()
			Prism:Notify({
				Title = "Panic",
				Content = "Aimbot, silent, triggerbot and time changer are off.",
				Type = "Warning",
				Duration = 4,
			})
		end)
	end

	local safeSec = aimTab:Section({ Name = "Safety", Icon = "shield", Side = "Right" })
	safeSec:Label("Panic kills aimbot, silent, trigger and time changer instantly. ESP + camera fullbright stay on (they don't touch the AC).")
	safeSec:Button({
		Name = "Panic now",
		Description = "Disable everything risky",
		Icon = "shield-off",
		Callback = panic,
	})
	safeSec:Toggle({
		Name = "Panic key",
		Description = "Click the key chip to bind — tap to kill risky features",
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

	local sysSec = espTab:Section({ Name = "Script", Icon = "power", Side = "Right" })
	sysSec:Label("Version: " .. bundleVersion .. " — use Refresh if Aimbot tab looks old")
	sysSec:Button({
		Name = "Refresh from GitHub",
		Description = "Re-download all modules",
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
		Description = "Removes UI + ESP + aim",
		Icon = "trash-2",
		Hold = 1.2,
		HoldText = "Hold to unload...",
		Callback = function()
			Window:Unload()
		end,
	})

	local bundle = {}

	function bundle.destroy()
		Aim:destroy()
		Esp:destroy()
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
	bundle.panic = panic

	return bundle
end
