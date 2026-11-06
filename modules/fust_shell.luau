-- Prism menu shell: ESP + Aim tabs. Returns factory(deps) -> bundle
return function(deps)
	local Prism = deps.Prism
	local Esp = deps.Esp
	local Aim = deps.Aim

	Prism.ReduceMotion = true
	Prism.Sounds = false
	if Prism._unloadAll then
		Prism:_unloadAll()
	end

	Esp:cleanupBeforeLoad()

	local Window = Prism:CreateWindow({
		Title = "Fust",
		Subtitle = "visuals + aim",
		Intro = false,
		ToggleKey = Enum.KeyCode.RightControl,
		Size = Vector2.new(580, 520),
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
		Description = "Hold key — right-click row to rebind",
		Default = false,
		Flag = "Fust_EspHold",
		Mode = "Hold",
		Keybind = Enum.KeyCode.X,
		Callback = function(v)
			holdOn = v
			syncMaster()
		end,
	})

	local featSec = espTab:Section({ Name = "Features", Icon = "users", Side = "Left" })

	featSec:Slider({
		Name = "Max distance",
		Description = "How far away (studs) players can be",
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

	featSec:Toggle({ Name = "Box ESP", Default = true, Flag = "Fust_EspBox", Callback = function(v)
		Esp.box = v
	end })
	featSec:Toggle({ Name = "Skeleton ESP", Default = true, Flag = "Fust_EspSkel", Callback = function(v)
		Esp.skeleton = v
	end })
	featSec:Toggle({ Name = "Name", Default = true, Flag = "Fust_EspName", Callback = function(v)
		Esp.name = v
	end })
	featSec:Toggle({ Name = "Distance", Default = true, Flag = "Fust_EspDist", Callback = function(v)
		Esp.distance = v
	end })
	featSec:Toggle({ Name = "Health bar", Description = "Only within HP range below", Default = true, Flag = "Fust_EspHpBar", Callback = function(v)
		Esp.healthBar = v
	end })

	featSec:Slider({
		Name = "Health bar range",
		Description = "Max studs to draw HP bar (not full ESP range)",
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

	featSec:Toggle({ Name = "Health text", Default = false, Flag = "Fust_EspHpTxt", Callback = function(v)
		Esp.healthText = v
	end })

	featSec:ColorPicker({
		Name = "ESP colour",
		Default = Color3.fromRGB(235, 235, 235),
		Flag = "Fust_EspCol",
		Callback = function(c)
			Esp.color = c
		end,
	})

	local aimTab = Window:Tab({ Name = "Aim", Icon = "crosshair", Description = "Camera-only (no hooks)" })
	local aimWarn = aimTab:Section({ Name = "Read first", Icon = "alert-triangle", Side = "Left" })
	aimWarn:Label("True silent aim (hooking GunControl / shoot remotes) is <b>not</b> included. Fust validates call stacks via debug.info. Snap-on-shot only nudges your camera on LMB inside a tight FOV.")

	local aimMain = aimTab:Section({ Name = "Aim assist", Icon = "target", Side = "Left" })
	aimMain:Toggle({
		Name = "Sticky assist",
		Description = "Soft pull while ADS (FustAimGun / Bow)",
		Default = false,
		Flag = "Fust_AimAssist",
		Callback = function(v)
			Aim.assistOn = v
			Aim:syncBind()
		end,
	})
	aimMain:Slider({
		Name = "Assist FOV",
		Min = 1,
		Max = 12,
		Default = 5,
		Increment = 0.5,
		Suffix = "°",
		Flag = "Fust_AimFov",
		Callback = function(v)
			Aim.fov = v
		end,
	})
	aimMain:Slider({
		Name = "Assist strength",
		Min = 0.05,
		Max = 0.35,
		Default = 0.12,
		Increment = 0.01,
		Flag = "Fust_AimStr",
		Callback = function(v)
			Aim.strength = v
		end,
	})

	local snapSec = aimTab:Section({ Name = "Snap on shot", Icon = "zap", Side = "Left" })
	snapSec:Toggle({
		Name = "Snap on LMB",
		Description = "Riskier: tiny camera snap when firing inside tight FOV — not true silent",
		Default = false,
		Risky = true,
		Flag = "Fust_AimSnap",
		Callback = function(v)
			Aim.snapOn = v
			Aim:syncBind()
		end,
	})
	snapSec:Slider({
		Name = "Snap FOV",
		Min = 0.5,
		Max = 6,
		Default = 2.5,
		Increment = 0.25,
		Suffix = "°",
		Flag = "Fust_SnapFov",
		Callback = function(v)
			Aim.snapFov = v
		end,
	})

	local aimTune = aimTab:Section({ Name = "Targeting", Icon = "settings", Side = "Right" })
	aimTune:Slider({
		Name = "Max target distance",
		Min = 50,
		Max = 1200,
		Default = 450,
		Increment = 25,
		Suffix = " st",
		Flag = "Fust_AimDist",
		Callback = function(v)
			Aim.maxDist = v
		end,
	})
	aimTune:Dropdown({
		Name = "Aim bone",
		Default = "Head",
		Flag = "Fust_AimBone",
		Options = { "Head", "UpperTorso", "HumanoidRootPart" },
		Callback = function(v)
			Aim.bone = v
		end,
	})

	local sysSec = espTab:Section({ Name = "Script", Icon = "power", Side = "Right" })
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
	end

	Window:OnUnload(function()
		bundle.destroy()
	end)

	Esp:ensureGui()

	bundle.Window = Window
	bundle.Esp = Esp
	bundle.Aim = Aim

	return bundle
end
