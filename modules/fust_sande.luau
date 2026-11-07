-- Sandevistan window: keybind + duration, free move, frozen hit-origin, Shoot magic bullet.
-- No desync. Origin is snapshotted at activate; Shoot dir/origin rewritten via Exploit.
-- FX: Camera ColorCorrection + Blur and a ScreenGui (vignette, colour split, streaks, timer HUD) only.
-- Never touches Lighting Ambient / Brightness / Exposure.
return function(deps)
	local Players = deps.Players
	local RunService = deps.RunService
	local LOCAL = deps.LocalPlayer
	local Aim = deps.Aim
	local Exploit = deps.Exploit

	local Sande = {
		enabled = false,
		duration = 3,
		key = Enum.KeyCode.Q,
		active = false,
		endsAt = 0,
		frozenPos = nil,
		fxStrength = 1,
		autoSilent = true,
		_conn = nil,
		_fx = nil,
		_gui = nil,
		_status = nil,
		_vignette = nil,
		_streaks = nil,
		_fxConn = nil,
	}

	local function hrp()
		local char = LOCAL.Character
		return char and char:FindFirstChild("HumanoidRootPart")
	end

	local TweenService = game:GetService("TweenService")
	local CYAN = Color3.fromRGB(90, 225, 255)
	local MAGENTA = Color3.fromRGB(255, 70, 190)
	local WARN = Color3.fromRGB(255, 80, 80)
	local STREAKS = 26

	local function tween(inst, t, props, style, dir)
		local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
		tw:Play()
		return tw
	end

	local function new(class, props, parent)
		local inst = Instance.new(class)
		for k, v in pairs(props) do
			inst[k] = v
		end
		inst.Parent = parent
		return inst
	end

	-- Fade the current effects out, then remove them. A new activation can build its own set straight away.
	local function clearFx()
		if Sande._fxConn then
			Sande._fxConn:Disconnect()
			Sande._fxConn = nil
		end
		local fxList, gui = Sande._fx, Sande._gui
		Sande._fx, Sande._gui = nil, nil
		Sande._status, Sande._vignette, Sande._streaks = nil, nil, nil
		local OUT = 0.35
		for _, fx in ipairs(fxList or {}) do
			pcall(function()
				if fx:IsA("ColorCorrectionEffect") then
					tween(fx, OUT, { TintColor = Color3.new(1, 1, 1), Contrast = 0, Saturation = 0, Brightness = 0 })
				elseif fx:IsA("BlurEffect") then
					tween(fx, OUT, { Size = 0 })
				end
			end)
		end
		if gui then
			pcall(function()
				local flash = gui:FindFirstChild("Flash")
				if flash then
					flash.BackgroundColor3 = Color3.new(1, 1, 1)
					flash.BackgroundTransparency = 0.55
					tween(flash, OUT, { BackgroundTransparency = 1 })
				end
				for _, d in ipairs(gui:GetDescendants()) do
					if d.Name ~= "Flash" then
						if d:IsA("Frame") then
							tween(d, OUT, { BackgroundTransparency = 1 })
						elseif d:IsA("TextLabel") then
							tween(d, OUT, { TextTransparency = 1, TextStrokeTransparency = 1 })
						elseif d:IsA("UIStroke") then
							tween(d, OUT, { Transparency = 1 })
						end
					end
				end
			end)
		end
		task.delay(OUT + 0.05, function()
			for _, fx in ipairs(fxList or {}) do
				pcall(function()
					fx:Destroy()
				end)
			end
			if gui then
				pcall(function()
					gui:Destroy()
				end)
			end
		end)
	end

	local function buildFx(strength)
		clearFx()
		strength = math.clamp(strength or 1, 0.2, 2)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end

		local fx = {}
		local cc = new("ColorCorrectionEffect", {
			Name = "FustSandeCC",
			TintColor = Color3.new(1, 1, 1),
			Contrast = 0,
			Saturation = 0,
			Brightness = 0,
		}, cam)
		fx[#fx + 1] = cc
		local blur = new("BlurEffect", { Name = "FustSandeBlur", Size = 0 }, cam)
		fx[#fx + 1] = blur
		Sande._fx = fx

		-- engage: a hard blur + tint punch that settles into the steady look
		local tintOn = Color3.fromRGB(150, 225, 255):Lerp(Color3.new(1, 1, 1), math.clamp(1 - strength * 0.6, 0, 0.8))
		tween(cc, 0.12, { TintColor = CYAN, Contrast = 0.6 * strength, Saturation = -0.5 * strength, Brightness = 0.08 * strength })
		tween(blur, 0.1, { Size = 14 * strength })
		task.delay(0.12, function()
			if Sande._fx == fx then
				tween(cc, 0.45, { TintColor = tintOn, Contrast = 0.3 * strength, Saturation = -0.3 * strength, Brightness = 0.03 * strength })
				tween(blur, 0.45, { Size = 3 * strength })
			end
		end)

		local pg = LOCAL:FindFirstChildOfClass("PlayerGui")
		if not pg then
			return
		end
		local gui = new("ScreenGui", {
			Name = "FustSandeFx",
			IgnoreGuiInset = true,
			DisplayOrder = 80,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, pg)
		Sande._gui = gui

		-- edge vignette: four dark-teal gradients that close in from the screen edges
		local vig = new("Frame", { Name = "Vignette", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
		local edges = {
			{ UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 0), 90 },
			{ UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 0.68), -90 },
			{ UDim2.fromScale(0.26, 1), UDim2.fromScale(0, 0), 0 },
			{ UDim2.fromScale(0.26, 1), UDim2.fromScale(0.74, 0), 180 },
		}
		for _, e in ipairs(edges) do
			local f = new("Frame", {
				BackgroundColor3 = Color3.fromRGB(0, 30, 55),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Size = e[1],
				Position = e[2],
			}, vig)
			new("UIGradient", {
				Rotation = e[3],
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
			}, f)
			tween(f, 0.3, { BackgroundTransparency = math.clamp(0.55 - 0.15 * strength, 0.2, 0.7) })
		end
		Sande._vignette = vig

		-- colour split: magenta on the left edge, cyan on the right, drifting slightly (afterimage feel)
		local splitL = new("Frame", {
			Name = "SplitL", BackgroundColor3 = MAGENTA, BackgroundTransparency = 1, BorderSizePixel = 0,
			Size = UDim2.fromScale(0.12, 1), Position = UDim2.fromScale(0, 0),
		}, gui)
		new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }) }, splitL)
		local splitR = new("Frame", {
			Name = "SplitR", BackgroundColor3 = CYAN, BackgroundTransparency = 1, BorderSizePixel = 0,
			Size = UDim2.fromScale(0.12, 1), Position = UDim2.fromScale(0.88, 0),
		}, gui)
		new("UIGradient", { Rotation = 180, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }) }, splitR)

		-- speed streaks: thin lines rushing outward from the centre, with fading tails
		local streakFolder = new("Frame", { Name = "Streaks", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, gui)
		local streaks = {}
		local function respawn(st)
			st.angle = math.random() * math.pi * 2
			st.r = 0.08 + math.random() * 0.2
			st.speed = (0.9 + math.random() * 1.4) * (0.6 + strength * 0.4)
			st.len = 40 + math.random() * 120
			st.width = math.random() < 0.3 and 2 or 1
		end
		for i = 1, STREAKS do
			local line = new("Frame", {
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = (i % 4 == 0) and MAGENTA or CYAN,
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(60, 1),
			}, streakFolder)
			new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.7, 0.15), NumberSequenceKeypoint.new(1, 0) }) }, line)
			local st = { f = line }
			respawn(st)
			st.r = math.random() * 0.6
			streaks[i] = st
		end
		Sande._streaks = streakFolder

		-- engage flash
		local flash = new("Frame", {
			Name = "Flash", BackgroundColor3 = CYAN, BackgroundTransparency = 0.25, BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1), ZIndex = 10,
		}, gui)
		tween(flash, 0.35, { BackgroundTransparency = 1 })

		-- HUD: title, time left, draining segmented bar
		local hud = new("Frame", {
			Name = "Hud", AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1,
			Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(320, 56), ZIndex = 20,
		}, gui)
		local title = new("TextLabel", {
			Name = "Title", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
			Font = Enum.Font.GothamBlack, TextSize = 18, Text = "SANDEVISTAN",
			TextColor3 = CYAN, TextStrokeColor3 = Color3.fromRGB(0, 20, 35), TextStrokeTransparency = 0.2,
			TextXAlignment = Enum.TextXAlignment.Left, TextTransparency = 1, ZIndex = 21,
		}, hud)
		local timeLbl = new("TextLabel", {
			Name = "Time", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20),
			Font = Enum.Font.Code, TextSize = 18, Text = "",
			TextColor3 = Color3.new(1, 1, 1), TextStrokeColor3 = Color3.fromRGB(0, 20, 35), TextStrokeTransparency = 0.2,
			TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 1, ZIndex = 21,
		}, hud)
		local track = new("Frame", {
			Name = "Track", BackgroundColor3 = Color3.fromRGB(8, 22, 34), BackgroundTransparency = 1, BorderSizePixel = 0,
			Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 8), ZIndex = 21,
		}, hud)
		new("UICorner", { CornerRadius = UDim.new(0, 2) }, track)
		local trackStroke = new("UIStroke", { Color = CYAN, Thickness = 1, Transparency = 1 }, track)
		local fill = new("Frame", {
			Name = "Fill", BackgroundColor3 = CYAN, BackgroundTransparency = 1, BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1), ZIndex = 22,
		}, track)
		new("UICorner", { CornerRadius = UDim.new(0, 2) }, fill)
		local fillGrad = new("UIGradient", {
			Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 170, 170)) }),
			Rotation = 90,
		}, fill)
		for k = 1, 9 do
			new("Frame", {
				BackgroundColor3 = Color3.fromRGB(8, 22, 34), BackgroundTransparency = 1, BorderSizePixel = 0,
				Position = UDim2.new(k / 10, -1, 0, 0), Size = UDim2.new(0, 2, 1, 0), ZIndex = 23, Name = "Tick",
			}, track)
		end
		local sub = new("TextLabel", {
			Name = "Sub", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 14),
			Font = Enum.Font.Code, TextSize = 12, Text = "TIME DILATION ENGAGED",
			TextColor3 = Color3.fromRGB(150, 210, 230), TextTransparency = 1, TextStrokeTransparency = 1,
			TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21,
		}, hud)
		tween(title, 0.2, { TextTransparency = 0 })
		tween(timeLbl, 0.2, { TextTransparency = 0 })
		tween(sub, 0.25, { TextTransparency = 0.25 })
		tween(track, 0.2, { BackgroundTransparency = 0.25 })
		tween(trackStroke, 0.2, { Transparency = 0.4 })
		tween(fill, 0.2, { BackgroundTransparency = 0 })
		for _, t in ipairs(track:GetChildren()) do
			if t.Name == "Tick" then
				tween(t, 0.2, { BackgroundTransparency = 0 })
			end
		end
		hud.Position = UDim2.new(0.5, 0, 0, 52)
		tween(hud, 0.3, { Position = UDim2.new(0.5, 0, 0, 70) }, Enum.EasingStyle.Back)

		-- the module writes its own countdown into _status; point it at a hidden label so it never fights the HUD
		Sande._status = new("TextLabel", { Name = "Compat", Visible = false, Text = "" }, gui)

		local total = math.max(Sande.endsAt - tick(), 0.25)
		local clock = 0
		Sande._fxConn = RunService.RenderStepped:Connect(function(dt)
			if Sande._gui ~= gui then
				return
			end
			clock += dt
			local left = math.max(Sande.endsAt - tick(), 0)
			local frac = math.clamp(left / total, 0, 1)
			local vp = cam.ViewportSize
			local cx, cy = vp.X * 0.5, vp.Y * 0.5
			local diag = math.sqrt(cx * cx + cy * cy)

			-- timer
			fill.Size = UDim2.fromScale(frac, 1)
			local barColor
			if frac > 0.5 then
				barColor = CYAN:Lerp(MAGENTA, (1 - frac) * 2)
			else
				barColor = MAGENTA:Lerp(WARN, 1 - frac * 2)
			end
			fill.BackgroundColor3 = barColor
			trackStroke.Color = barColor
			title.TextColor3 = barColor
			timeLbl.Text = string.format("%05.2f", left)
			if left <= 0.75 then
				local blink = (math.sin(clock * 30) > 0) and 0 or 0.6
				timeLbl.TextTransparency = blink
				timeLbl.TextColor3 = WARN
				sub.Text = "WINDOW CLOSING"
			else
				timeLbl.TextTransparency = 0
				timeLbl.TextColor3 = Color3.new(1, 1, 1)
			end

			-- pulse (about 1.6 per second) on the grade and vignette
			local pulse = (math.sin(clock * 10) + 1) * 0.5
			cc.Contrast = (0.26 + 0.1 * pulse) * strength
			blur.Size = (2.5 + 1.5 * pulse) * strength
			for _, e in ipairs(vig:GetChildren()) do
				e.BackgroundTransparency = math.clamp(0.5 - 0.15 * strength - 0.08 * pulse, 0.15, 0.75)
			end

			-- colour split drift
			local drift = math.sin(clock * 3.1) * 0.012 * strength
			splitL.Position = UDim2.fromScale(drift, 0)
			splitR.Position = UDim2.fromScale(0.88 - drift, 0)
			splitL.BackgroundTransparency = math.clamp(0.82 - 0.12 * strength + 0.06 * pulse, 0.4, 0.95)
			splitR.BackgroundTransparency = splitL.BackgroundTransparency

			-- streaks
			for _, st in ipairs(streaks) do
				st.r += st.speed * dt
				if st.r > 1.05 then
					respawn(st)
				end
				local dist = st.r * diag
				local x = cx + math.cos(st.angle) * dist
				local y = cy + math.sin(st.angle) * dist
				local f = st.f
				f.Position = UDim2.fromOffset(x, y)
				f.Size = UDim2.fromOffset(st.len * (0.4 + st.r), st.width)
				f.Rotation = math.deg(st.angle)
				f.BackgroundTransparency = math.clamp(1 - st.r * 1.6 * (0.5 + strength * 0.5), 0.15, 1)
			end
		end)
	end

	local function pushExploit(active)
		if not Exploit then
			return
		end
		Exploit.sandeActive = active
		Exploit.sandeOrigin = active and Sande.frozenPos or nil
		if active and Sande.autoSilent then
			Exploit.trueSilent = true
		end
		if Exploit.syncHook then
			Exploit:syncHook()
		end
	end

	function Sande:stop()
		self.active = false
		self.endsAt = 0
		self.frozenPos = nil
		clearFx()
		pushExploit(false)
		if self._conn then
			self._conn:Disconnect()
			self._conn = nil
		end
	end

	function Sande:activate()
		if not self.enabled then
			return false
		end
		local root = hrp()
		if not root then
			return false
		end
		if self.active then
			self:stop()
		end

		self.frozenPos = root.Position
		self.active = true
		self.endsAt = tick() + math.clamp(self.duration or 3, 0.25, 30)
		buildFx(self.fxStrength)
		pushExploit(true)

		if Aim and self.autoSilent then
			Aim.silentOn = true
			if Aim.syncBind then
				Aim:syncBind()
			end
		end

		if self._conn then
			self._conn:Disconnect()
		end
		self._conn = RunService.Heartbeat:Connect(function()
			if not self.active then
				return
			end
			local left = self.endsAt - tick()
			if left <= 0 then
				self:stop()
				return
			end
			if self._status then
				self._status.Text = string.format("SANDEVISTAN  %.1fs", left)
			end
			-- Origin stays frozen. Player HRP moves freely — magic bullet uses frozenPos.
			if Exploit then
				Exploit.sandeOrigin = self.frozenPos
			end
		end)
		return true
	end

	function Sande:toggle()
		if self.active then
			self:stop()
			return false
		end
		return self:activate()
	end

	function Sande:destroy()
		self.enabled = false
		self:stop()
	end

	return Sande
end
