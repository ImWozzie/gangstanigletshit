-- Fust aim module (camera-only, no GunControl / Raycast hooks). factory(deps) -> Aim
-- "Silent" = multi-frame camera snap on LMB inside FOV. LOS uses workspace:Raycast for
-- visibility only — never redirects bullets or wraps GunControl.
return function(deps)
	local Players = deps.Players
	local RunService = deps.RunService
	local UserInputService = deps.UserInputService
	local LOCAL = deps.LocalPlayer
	local workspace = workspace

	local AIM_RENDER = "FustSafeAimAssist"
	local TRIGGER_COOLDOWN = 0.05
	local VISUAL_HUD_TICK = 0.25
	local SILENT_HOLD = 0.08 -- keep snapping briefly after M1 so the shot lands on-cam

	local BONE_ALIASES = {
		Head = "Head",
		Neck = "Neck",
		Chest = "UpperTorso",
		Pelvis = "LowerTorso",
		["HumanoidRootPart"] = "HumanoidRootPart",
	}

	local Aim = {
		aimbotEnabled = false,
		prediction = false,
		predictionTime = 0.12,
		targetBones = { "Head" },
		smoothing = 36,
		weaponFovPx = 120,
		maxDist = 1500,
		deadzonePx = 3,
		visibleCheck = false,
		ignoreKnocked = true,
		ignoreTeam = true,
		drawFov = true,
		filledFov = false,
		silentOn = false,
		silentFovPx = 90,
		silentStrength = 1,
		silentMaxDeg = 3.5, -- keep low: FustLook LookPitch samples camera pitch ~10Hz
		silentSteps = 2,
		triggerEnabled = false,
		triggerBones = { "Head" },
		triggerDelayMs = 10,
		triggerKeyHeld = false,
		aimKey1Held = false,
		aimKey2Held = false,
		aimKey1 = Enum.KeyCode.B,
		aimKey2 = Enum.KeyCode.V,
		triggerKey = Enum.KeyCode.B,
		mouseRemX = 0,
		mouseRemY = 0,
		requireHoldKey = false,
		lockCapDeg = 6.5,
		battleMode = false,
		requireAds = false,
		useMouseDrive = true,
		mouseDriveStrength = 0.22,
		showCrosshair = true,
		visualCheck = false,
		crossSize = 10,
		crossGap = 4,
		crossThick = 2,
		crossColor = Color3.fromRGB(235, 70, 70),
		fovRingColor = Color3.fromRGB(235, 70, 70),
		fovFillTransparency = 0.82,
		bound = false,
		stickyChar = nil,
		firingSilent = false,
		silentUntil = 0,
		lastTrigger = 0,
		triggerAcc = 0,
		visualHudAcc = 0,
		lastHudText = "",
		lastFovRadius = -1,
		lastShowCross = nil,
		lastShowRing = nil,
		lastShowFill = nil,
		inputBeganConn = nil,
		inputEndedConn = nil,
	}

	-- Reused raycast state (avoid alloc every LOS check).
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local rayIgnore = {}

	local crossGui
	local crossParts = {}
	local fovRing
	local fovStroke
	local fovFill
	local statusLabel

	local function isActive()
		return Aim.drawFov
			or Aim.filledFov
			or Aim.showCrosshair
			or Aim.visualCheck
			or Aim.aimbotEnabled
			or Aim.silentOn
			or Aim.triggerEnabled
	end

	function Aim:isAds()
		if LOCAL:GetAttribute("Dead") == true then
			return false
		end
		if LOCAL:GetAttribute("FustAimGun") == true or LOCAL:GetAttribute("FustAimBow") == true then
			return true
		end
		local char = LOCAL.Character
		if char then
			local tool = char:FindFirstChildOfClass("Tool")
			if tool and (tool:GetAttribute("FustGun") == true or tool:GetAttribute("Gun") == true) then
				return true
			end
		end
		return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
	end

	function Aim:canAim()
		if self.battleMode or not self.requireAds then
			return true
		end
		return self:isAds()
	end

	local function isBindDown(key)
		if not key then
			return false
		end
		if key.EnumType == Enum.UserInputType then
			return UserInputService:IsMouseButtonPressed(key)
		end
		return UserInputService:IsKeyDown(key)
	end

	function Aim:aimKeysHeld()
		if not self.requireHoldKey then
			return true
		end
		return self.aimKey1Held or self.aimKey2Held or isBindDown(self.aimKey1) or isBindDown(self.aimKey2)
	end

	function Aim:triggerHeld()
		return self.triggerKeyHeld or isBindDown(self.triggerKey)
	end

	function Aim:shouldRunAimbot()
		return self.aimbotEnabled and self:aimKeysHeld() and self:canAim()
	end

	function Aim:resolveBoneName(alias)
		return BONE_ALIASES[alias] or alias
	end

	function Aim:getBonePart(char, alias)
		local name = self:resolveBoneName(alias)
		local p = char:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			return p
		end
		if name == "Neck" then
			p = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
			if p then
				return p
			end
		end
		return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	end

	function Aim:isKnocked(plr, hum, char)
		if hum.Health <= 0 then
			return true
		end
		if plr:GetAttribute("Knocked") == true or char:GetAttribute("Knocked") == true then
			return true
		end
		if hum:GetAttribute("Downed") == true or char:GetAttribute("Downed") == true then
			return true
		end
		return false
	end

	function Aim:sameTeam(plr)
		local lt, tt = LOCAL.Team, plr.Team
		if not lt or not tt or lt.Neutral or tt.Neutral then
			return false
		end
		return lt == tt
	end

	function Aim:passesFilters(plr, hum, char)
		if self.ignoreTeam and self:sameTeam(plr) then
			return false
		end
		if self.ignoreKnocked and self:isKnocked(plr, hum, char) then
			return false
		end
		return true
	end

	-- LOS raycast only (never used to spoof gun hits).
	function Aim:isVisible(cam, from, to, char)
		if not self.visibleCheck then
			return true
		end
		local dir = to - from
		local dist = dir.Magnitude
		if dist < 0.05 then
			return true
		end
		table.clear(rayIgnore)
		local myChar = LOCAL.Character
		if myChar then
			rayIgnore[1] = myChar
		end
		rayParams.FilterDescendantsInstances = rayIgnore
		local unit = dir.Unit
		local origin = from
		local remaining = dist
		for _ = 1, 6 do
			local hit = workspace:Raycast(origin, unit * remaining, rayParams)
			if not hit then
				return true
			end
			local inst = hit.Instance
			if char and inst:IsDescendantOf(char) then
				return true
			end
			local seeThrough = inst:IsA("BasePart") and (inst.Transparency > 0.4 or not inst.CanCollide)
			if not seeThrough then
				return false
			end
			rayIgnore[#rayIgnore + 1] = inst
			rayParams.FilterDescendantsInstances = rayIgnore
			local advanced = (hit.Position - origin).Magnitude
			remaining -= advanced
			origin = hit.Position + unit * 0.05
			if remaining <= 0.05 then
				return true
			end
		end
		return false
	end

	function Aim:predictPos(part, root)
		if not part then
			return nil
		end
		if not self.prediction then
			return part.Position
		end
		local vel = Vector3.zero
		if root and root:IsA("BasePart") then
			vel = root.AssemblyLinearVelocity
		elseif part:IsA("BasePart") then
			vel = part.AssemblyLinearVelocity
		end
		return part.Position + vel * self.predictionTime
	end

	function Aim:screenDistPx(cam, worldPos)
		local sp, on = cam:WorldToViewportPoint(worldPos)
		if not on or sp.Z <= 0 then
			return math.huge, nil
		end
		local vs = cam.ViewportSize
		local dx, dy = sp.X - vs.X * 0.5, sp.Y - vs.Y * 0.5
		return math.sqrt(dx * dx + dy * dy), sp
	end

	function Aim:angleDeg(a, b)
		return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
	end

	function Aim:bestPointOnChar(char, boneList, cam)
		local root = char:FindFirstChild("HumanoidRootPart")
		local bestPt, bestPart, bestPx = nil, nil, math.huge
		for i = 1, #boneList do
			local part = self:getBonePart(char, boneList[i])
			if part then
				local pt = self:predictPos(part, root)
				if pt then
					pt += Vector3.new(0, 0.05, 0)
					local px = self:screenDistPx(cam, pt)
					if px < bestPx then
						bestPx, bestPt, bestPart = px, pt, part
					end
				end
			end
		end
		return bestPt, bestPart
	end

	function Aim:pickTarget(cam, fovPx, boneList, stickyChar)
		local camCF = cam.CFrame
		local camPos = camCF.Position
		local look = camCF.LookVector
		local maxD2 = self.maxDist * self.maxDist

		local function tryChar(char)
			local hum = char:FindFirstChildOfClass("Humanoid")
			local root = char:FindFirstChild("HumanoidRootPart")
			if not hum or not root or hum.Health <= 0 then
				return nil
			end
			local plr = Players:GetPlayerFromCharacter(char)
			if not plr or not self:passesFilters(plr, hum, char) then
				return nil
			end
			local delta = root.Position - camPos
			local d2 = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
			if d2 > maxD2 then
				return nil
			end
			-- Skip clearly behind camera before bone project.
			if delta:Dot(look) < -2 then
				return nil
			end
			local pt, part = self:bestPointOnChar(char, boneList, cam)
			if not pt or not self:isVisible(cam, camPos, pt, char) then
				return nil
			end
			local px = self:screenDistPx(cam, pt)
			return pt, char, part, px
		end

		if stickyChar and stickyChar.Parent then
			local pt, ch, part, px = tryChar(stickyChar)
			if pt and px <= fovPx * 1.35 then
				return pt, ch, part
			end
		end

		local bestPt, bestChar, bestPart, bestPx = nil, nil, nil, fovPx
		local players = Players:GetPlayers()
		for i = 1, #players do
			local plr = players[i]
			if plr ~= LOCAL then
				local char = plr.Character
				if char then
					local pt, ch, part, px = tryChar(char)
					if pt and px < bestPx then
						bestPx, bestPt, bestChar, bestPart = px, pt, ch, part
					end
				end
			end
		end
		return bestPt, bestChar, bestPart
	end

	function Aim:smoothingStrength()
		return math.clamp(self.smoothing / 100, 0.03, 1)
	end

	-- Capped camera rotate. Never hard lookAt — LookPitch telemeters asin(LookVector.Y).
	function Aim:cameraSnapToward(cam, worldPos, capDeg)
		local camPos = cam.CFrame.Position
		local look = cam.CFrame.LookVector
		local want = (worldPos - camPos)
		if want.Magnitude < 1e-4 then
			return true
		end
		want = want.Unit
		local ang = self:angleDeg(look, want)
		if ang < 0.02 then
			return true
		end
		local px = self:screenDistPx(cam, worldPos)
		if px <= self.deadzonePx then
			return true
		end
		local hardCap = math.min(capDeg or 3.5, 5)
		local step = math.min(hardCap, ang)
		local t = step / math.max(ang, 0.001)
		cam.CFrame = CFrame.lookAt(camPos, camPos + look:Lerp(want, t).Unit)
		return ang < 0.15
	end

	function Aim:rotateToward(cam, worldPos, capDeg)
		if self.useMouseDrive then
			return self:mouseDriveToward(cam, worldPos)
		end
		return self:cameraSnapToward(cam, worldPos, capDeg)
	end

	function Aim:mouseDriveToward(cam, worldPos)
		local sp, on = cam:WorldToViewportPoint(worldPos)
		if not on or sp.Z <= 0 then
			return false
		end
		local vs = cam.ViewportSize
		local cx, cy = vs.X * 0.5, vs.Y * 0.5
		local dx, dy = sp.X - cx, sp.Y - cy
		local dist = math.sqrt(dx * dx + dy * dy)
		if dist <= self.deadzonePx then
			return true
		end
		local factor = self.mouseDriveStrength * self:smoothingStrength()
		if self.aimbotEnabled and self:aimKeysHeld() then
			factor = math.clamp(factor * 2.5, 0.08, 0.55)
		end
		local mx = dx * factor + self.mouseRemX
		local my = dy * factor + self.mouseRemY
		local sx = mx >= 0 and math.floor(mx) or math.ceil(mx)
		local sy = my >= 0 and math.floor(my) or math.ceil(my)
		local halfDead = self.deadzonePx * 0.5
		if sx == 0 and math.abs(dx) > halfDead then
			sx = dx > 0 and 1 or -1
		end
		if sy == 0 and math.abs(dy) > halfDead then
			sy = dy > 0 and 1 or -1
		end
		self.mouseRemX = math.clamp(mx - sx, -1, 1)
		self.mouseRemY = math.clamp(my - sy, -1, 1)
		if sx == 0 and sy == 0 then
			return true
		end
		if type(mousemoverel) == "function" then
			mousemoverel(sx, sy)
			return true
		end
		local ok = pcall(function()
			game:GetService("VirtualInputManager"):SendMouseMoveEvent(cx + sx, cy + sy, game)
		end)
		return ok
	end

	function Aim:fovRadiusPx(_, px)
		return math.clamp(px, 8, 600)
	end

	function Aim:destroyCrosshair()
		if crossGui then
			crossGui:Destroy()
			crossGui = nil
		end
		table.clear(crossParts)
		fovRing, fovStroke, fovFill, statusLabel = nil, nil, nil, nil
		self.lastFovRadius = -1
		self.lastShowCross = nil
		self.lastShowRing = nil
		self.lastShowFill = nil
		self.lastHudText = ""
	end

	function Aim:ensureCrosshair()
		if crossGui and crossGui.Parent then
			return
		end
		self:destroyCrosshair()
		crossGui = Instance.new("ScreenGui")
		crossGui.Name = "FustCrosshair"
		crossGui.ResetOnSpawn = false
		crossGui.IgnoreGuiInset = true
		crossGui.DisplayOrder = 210
		crossGui:SetAttribute("FustBundle", true)
		crossGui.Parent = LOCAL:WaitForChild("PlayerGui")

		fovRing = Instance.new("Frame")
		fovRing.Name = "FovRing"
		fovRing.BackgroundTransparency = 1
		fovRing.BorderSizePixel = 0
		fovRing.AnchorPoint = Vector2.new(0.5, 0.5)
		fovRing.Position = UDim2.fromScale(0.5, 0.5)
		fovRing.Visible = false
		fovRing.Parent = crossGui
		local ringCorner = Instance.new("UICorner")
		ringCorner.CornerRadius = UDim.new(1, 0)
		ringCorner.Parent = fovRing
		fovStroke = Instance.new("UIStroke")
		fovStroke.Thickness = 1.5
		fovStroke.Transparency = 0.25
		fovStroke.Color = self.fovRingColor
		fovStroke.Parent = fovRing

		fovFill = Instance.new("Frame")
		fovFill.Name = "FovFill"
		fovFill.BorderSizePixel = 0
		fovFill.BackgroundColor3 = self.fovRingColor
		fovFill.BackgroundTransparency = self.fovFillTransparency
		fovFill.AnchorPoint = Vector2.new(0.5, 0.5)
		fovFill.Position = UDim2.fromScale(0.5, 0.5)
		fovFill.Visible = false
		fovFill.Parent = crossGui
		local fillCorner = Instance.new("UICorner")
		fillCorner.CornerRadius = UDim.new(1, 0)
		fillCorner.Parent = fovFill

		local function bar(name, size, pos)
			local f = Instance.new("Frame")
			f.Name = name
			f.BorderSizePixel = 0
			f.BackgroundColor3 = self.crossColor
			f.AnchorPoint = Vector2.new(0.5, 0.5)
			f.Size = size
			f.Position = pos
			f.Parent = crossGui
			crossParts[#crossParts + 1] = f
			return f
		end

		local thick, size, gap = self.crossThick, self.crossSize, self.crossGap
		bar("L", UDim2.fromOffset(size, thick), UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(-(gap + size * 0.5), 0))
		bar("R", UDim2.fromOffset(size, thick), UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(gap + size * 0.5, 0))
		bar("U", UDim2.fromOffset(thick, size), UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(0, -(gap + size * 0.5)))
		bar("D", UDim2.fromOffset(thick, size), UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(0, gap + size * 0.5))
		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = self.crossColor
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.5, 0.5)
		dot.Size = UDim2.fromOffset(math.max(2, thick), math.max(2, thick))
		dot.Parent = crossGui
		crossParts[#crossParts + 1] = dot

		statusLabel = Instance.new("TextLabel")
		statusLabel.Name = "VisualCheck"
		statusLabel.BackgroundTransparency = 1
		statusLabel.Font = Enum.Font.GothamMedium
		statusLabel.TextSize = 13
		statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
		statusLabel.TextXAlignment = Enum.TextXAlignment.Center
		statusLabel.AnchorPoint = Vector2.new(0.5, 0)
		statusLabel.Position = UDim2.new(0.5, 0, 0, 6)
		statusLabel.Size = UDim2.new(1, -20, 0, 36)
		statusLabel.TextWrapped = true
		statusLabel.Visible = false
		statusLabel.Parent = crossGui
	end

	function Aim:updateVisuals(cam, dt)
		local needGui = self.drawFov or self.filledFov or self.showCrosshair or self.visualCheck
		if not needGui then
			if crossGui then
				self:destroyCrosshair()
			end
			return
		end
		if not crossGui or not crossGui.Parent then
			self:ensureCrosshair()
		end

		local showCross = self.showCrosshair
		if self.lastShowCross ~= showCross then
			self.lastShowCross = showCross
			for i = 1, #crossParts do
				local p = crossParts[i]
				p.Visible = showCross
				p.BackgroundColor3 = self.crossColor
			end
		end

		local diam = math.floor(self:fovRadiusPx(cam, self.weaponFovPx) * 2 + 0.5)
		local showRing = self.drawFov
		local showFill = self.filledFov and self.drawFov

		if fovRing and (self.lastShowRing ~= showRing or self.lastFovRadius ~= diam) then
			self.lastShowRing = showRing
			fovRing.Visible = showRing
			if showRing then
				fovRing.Size = UDim2.fromOffset(diam, diam)
				if fovStroke then
					fovStroke.Color = self.fovRingColor
				end
			end
		end

		if fovFill and (self.lastShowFill ~= showFill or (showFill and self.lastFovRadius ~= diam)) then
			self.lastShowFill = showFill
			fovFill.Visible = showFill
			if showFill then
				fovFill.BackgroundColor3 = self.fovRingColor
				fovFill.BackgroundTransparency = self.fovFillTransparency
				fovFill.Size = UDim2.fromOffset(diam, diam)
			end
		end
		self.lastFovRadius = diam

		if not statusLabel then
			return
		end
		if not self.visualCheck then
			if statusLabel.Visible then
				statusLabel.Visible = false
			end
			return
		end

		self.visualHudAcc += dt or 0
		if self.visualHudAcc < VISUAL_HUD_TICK then
			return
		end
		self.visualHudAcc = 0
		local pt, ch = self:pickTarget(cam, self.weaponFovPx, self.targetBones, self.stickyChar)
		local text = string.format(
			"Aim:%s key:%s vis:%s | tgt:%s ads:%s silent:%s",
			self.aimbotEnabled and "on" or "off",
			self:aimKeysHeld() and "hold" or "—",
			self.visibleCheck and "on" or "off",
			pt and (ch and ch.Name or "?") or "none",
			self:canAim() and "yes" or "no",
			self.silentOn and "on" or "off"
		)
		if self.lastHudText ~= text then
			self.lastHudText = text
			statusLabel.Text = text
		end
		if not statusLabel.Visible then
			statusLabel.Visible = true
		end
	end

	-- Camera silent: short capped pull on fire. Prefer mouse drive when enabled (LookPitch-safe).
	function Aim:runSilentBurst(cam)
		if not self.silentOn or not self:canAim() then
			return
		end
		local pt, ch = self:pickTarget(cam, self.silentFovPx, self.targetBones, self.stickyChar)
		if not pt then
			return
		end
		self.stickyChar = ch
		local cap = math.min(self.silentMaxDeg * self.silentStrength, 5)
		local steps = math.clamp(math.floor(self.silentSteps + 0.5), 1, 4)
		for _ = 1, steps do
			if self.useMouseDrive then
				self:mouseDriveToward(cam, pt)
			else
				self:cameraSnapToward(cam, pt, cap)
			end
			pt = select(1, self:bestPointOnChar(ch, self.targetBones, cam)) or pt
		end
	end

	function Aim:tryTriggerbot(cam, dt)
		if not self.triggerEnabled or not self:triggerHeld() or not self:canAim() then
			self.triggerAcc = 0
			return
		end
		local pt = self:pickTarget(cam, math.max(8, self.deadzonePx + 2), self.triggerBones, nil)
		if not pt then
			self.triggerAcc = 0
			return
		end
		local px = self:screenDistPx(cam, pt)
		if px > self.deadzonePx + 1.5 then
			self.triggerAcc = 0
			return
		end
		self.triggerAcc += dt * 1000
		if self.triggerAcc < self.triggerDelayMs then
			return
		end
		local now = os.clock()
		if now - self.lastTrigger < TRIGGER_COOLDOWN then
			return
		end
		self.lastTrigger = now
		self.triggerAcc = 0
		pcall(function()
			local vim = game:GetService("VirtualInputManager")
			local vs = cam.ViewportSize
			local cx, cy = vs.X * 0.5, vs.Y * 0.5
			vim:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
			task.defer(function()
				vim:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
			end)
		end)
	end

	function Aim:syncBind()
		if isActive() then
			self:bind()
		else
			self:unbind()
		end
	end

	function Aim:bind()
		if self.bound then
			return
		end
		self.bound = true
		if self.drawFov or self.filledFov or self.showCrosshair or self.visualCheck then
			self:ensureCrosshair()
		end

		RunService:BindToRenderStep(AIM_RENDER, Enum.RenderPriority.Camera.Value + 5, function(dt)
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end

			self:updateVisuals(cam, dt)

			local runningAim = self:shouldRunAimbot()
			local silentLive = self.silentOn and (self.firingSilent or os.clock() < self.silentUntil) and self:canAim()

			if runningAim then
				local pt, ch = self:pickTarget(cam, self.weaponFovPx, self.targetBones, self.stickyChar)
				if pt then
					self.stickyChar = ch
					local cap = self.lockCapDeg
					local sm = self.smoothing
					if sm >= 50 then
						cap *= 0.65
					else
						cap *= 1 + (50 - math.clamp(sm, 1, 50)) * 0.02
					end
					self:rotateToward(cam, pt, cap)
				else
					self.stickyChar = nil
				end
			elseif not self:aimKeysHeld() and not silentLive then
				self.stickyChar = nil
			end

			if silentLive then
				self:runSilentBurst(cam)
			end

			if self.triggerEnabled then
				self:tryTriggerbot(cam, dt)
			end
		end)

		self.inputBeganConn = UserInputService.InputBegan:Connect(function(input, processed)
			if processed or input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			if not self.silentOn or not self:canAim() then
				return
			end
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			self.firingSilent = true
			self.silentUntil = os.clock() + SILENT_HOLD
			self:runSilentBurst(cam)
		end)

		self.inputEndedConn = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				self.firingSilent = false
			end
		end)
	end

	function Aim:unbind()
		pcall(function()
			RunService:UnbindFromRenderStep(AIM_RENDER)
		end)
		if self.inputBeganConn then
			self.inputBeganConn:Disconnect()
			self.inputBeganConn = nil
		end
		if self.inputEndedConn then
			self.inputEndedConn:Disconnect()
			self.inputEndedConn = nil
		end
		self.bound = false
		self.stickyChar = nil
		self.firingSilent = false
		self.silentUntil = 0
		self.triggerAcc = 0
		self.mouseRemX = 0
		self.mouseRemY = 0
	end

	function Aim:destroy()
		self.aimbotEnabled = false
		self.silentOn = false
		self.triggerEnabled = false
		self.aimKey1Held = false
		self.aimKey2Held = false
		self.triggerKeyHeld = false
		self:unbind()
		self:destroyCrosshair()
	end

	return Aim
end
