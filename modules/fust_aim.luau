-- Fust aim module (camera-only, no GunControl hooks). factory(deps) -> Aim
return function(deps)
	local Players = deps.Players
	local RunService = deps.RunService
	local UserInputService = deps.UserInputService
	local LOCAL = deps.LocalPlayer

	local AIM_RENDER = "FustSafeAimAssist"
	local FOV_SEGMENTS = 56
	local TRIGGER_COOLDOWN = 0.05

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
		maxDist = 450,
		deadzonePx = 3,
		visibleCheck = false,
		ignoreKnocked = true,
		ignoreTeam = true,
		drawFov = true,
		filledFov = false,
		silentOn = false,
		silentFovPx = 90,
		silentStrength = 0.92,
		silentMaxDeg = 3.5,
		triggerEnabled = false,
		triggerBones = { "Head" },
		triggerDelayMs = 10,
		triggerKeyHeld = false,
		aimKey1Held = false,
		aimKey2Held = false,
		aimKey1 = Enum.KeyCode.B,
		aimKey2 = nil,
		requireHoldKey = true,
		lockCapDeg = 6.5,
		battleMode = false,
		requireAds = true,
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
		lastTrigger = 0,
		triggerAcc = 0,
		inputBeganConn = nil,
		inputEndedConn = nil,
	}

	local crossGui
	local crossParts = {}
	local fovRing = {}
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
		return LOCAL:GetAttribute("FustAimGun") == true or LOCAL:GetAttribute("FustAimBow") == true
	end

	function Aim:canAim()
		if self.battleMode then
			return true
		end
		if not self.requireAds then
			return true
		end
		return self:isAds()
	end

	function Aim:aimKeysHeld()
		if not self.requireHoldKey then
			return true
		end
		local uis = UserInputService
		local k1 = self.aimKey1Held
		if not k1 and self.aimKey1 then
			k1 = uis:IsKeyDown(self.aimKey1)
		end
		local k2 = self.aimKey2Held
		if not k2 and self.aimKey2 then
			k2 = uis:IsKeyDown(self.aimKey2)
		end
		return k1 or k2
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
		local st = hum:GetState()
		if st == Enum.HumanoidStateType.Dead then
			return true
		end
		return false
	end

	function Aim:sameTeam(plr)
		local lt, tt = LOCAL.Team, plr.Team
		if not lt or not tt then
			return false
		end
		if lt.Neutral or tt.Neutral then
			return false
		end
		return lt == tt
	end

	function Aim:isVisible(cam, from, to, char)
		if not self.visibleCheck then
			return true
		end
		local dir = to - from
		local dist = dir.Magnitude
		if dist < 0.05 then
			return true
		end
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		local ignore = { LOCAL.Character, cam }
		if char then
			table.insert(ignore, char)
		end
		params.FilterDescendantsInstances = ignore
		local hit = workspace:Raycast(from, dir.Unit * dist, params)
		if not hit then
			return true
		end
		if char and hit.Instance and hit.Instance:IsDescendantOf(char) then
			return true
		end
		return false
	end

	function Aim:predictPos(part, root)
		if not self.prediction or not part then
			return part and part.Position or nil
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
			return math.huge
		end
		local cx, cy = cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5
		local dx, dy = sp.X - cx, sp.Y - cy
		return math.sqrt(dx * dx + dy * dy)
	end

	function Aim:angleDeg(a, b)
		return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
	end

	function Aim:pickTarget(cam, fovPx, boneList, stickyChar)
		if stickyChar and stickyChar.Parent then
			local hum = stickyChar:FindFirstChildOfClass("Humanoid")
			local root = stickyChar:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				local plr = Players:GetPlayerFromCharacter(stickyChar)
				if plr and self:passesFilters(plr, hum, stickyChar) then
					local pt, part = self:bestPointOnChar(stickyChar, boneList, cam)
					if pt and self:screenDistPx(cam, pt) <= fovPx * 1.25 then
						return pt, stickyChar, part
					end
				end
			end
		end

		local camPos = cam.CFrame.Position
		local bestPt
		local bestChar
		local bestPart
		local bestPx = fovPx
		local maxD2 = self.maxDist * self.maxDist

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LOCAL then
				local char = plr.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if hum and root and hum.Health > 0 and self:passesFilters(plr, hum, char) then
					local delta = root.Position - camPos
					if delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z <= maxD2 then
						local pt, part = self:bestPointOnChar(char, boneList, cam)
						if pt and self:isVisible(cam, camPos, pt, char) then
							local px = self:screenDistPx(cam, pt)
							if px < bestPx then
								bestPx = px
								bestPt = pt
								bestChar = char
								bestPart = part
							end
						end
					end
				end
			end
		end
		return bestPt, bestChar, bestPart
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

	function Aim:bestPointOnChar(char, boneList, cam)
		local root = char:FindFirstChild("HumanoidRootPart")
		local bestPt
		local bestPart
		local bestPx = math.huge
		for _, alias in ipairs(boneList) do
			local part = self:getBonePart(char, alias)
			if part then
				local pt = self:predictPos(part, root)
				if pt then
					pt = pt + Vector3.new(0, 0.05, 0)
					local px = self:screenDistPx(cam, pt)
					if px < bestPx then
						bestPx = px
						bestPt = pt
						bestPart = part
					end
				end
			end
		end
		return bestPt, bestPart
	end

	function Aim:smoothingStrength()
		return math.clamp(self.smoothing / 100, 0.03, 1)
	end

	function Aim:rotateToward(cam, worldPos, capDeg)
		local camPos = cam.CFrame.Position
		local look = cam.CFrame.LookVector
		local want = (worldPos - camPos).Unit
		local ang = self:angleDeg(look, want)
		if ang < 0.03 then
			return true
		end
		local px = self:screenDistPx(cam, worldPos)
		if px <= self.deadzonePx then
			return true
		end
		local strength = self:smoothingStrength()
		if self.aimbotEnabled and self:aimKeysHeld() then
			strength = math.clamp(strength * 2.2, 0.15, 1)
		end
		local step = math.min(capDeg, ang) * strength
		local t = step / math.max(ang, 0.001)
		local newLook = look:Lerp(want, t).Unit
		cam.CFrame = CFrame.lookAt(camPos, camPos + newLook)
		return ang < 0.2
	end

	function Aim:fovRadiusPx(cam, px)
		return math.clamp(px, 8, 600)
	end

	function Aim:destroyCrosshair()
		if crossGui then
			crossGui:Destroy()
			crossGui = nil
		end
		table.clear(crossParts)
		table.clear(fovRing)
		fovFill = nil
		statusLabel = nil
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
			table.insert(crossParts, f)
			return f
		end

		local thick = self.crossThick
		local size = self.crossSize
		local gap = self.crossGap
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
		table.insert(crossParts, dot)

		for i = 1, FOV_SEGMENTS do
			local seg = Instance.new("Frame")
			seg.Name = "F" .. i
			seg.BorderSizePixel = 0
			seg.BackgroundColor3 = self.fovRingColor
			seg.BackgroundTransparency = 0.2
			seg.AnchorPoint = Vector2.new(0.5, 0.5)
			seg.Size = UDim2.fromOffset(2, 2)
			seg.Visible = false
			seg.Parent = crossGui
			fovRing[i] = seg
		end

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

	function Aim:updateVisuals(cam)
		if not crossGui or not crossGui.Parent then
			if self.drawFov or self.filledFov or self.showCrosshair or self.visualCheck then
				self:ensureCrosshair()
			else
				return
			end
		end

		for _, p in ipairs(crossParts) do
			p.Visible = self.showCrosshair
			p.BackgroundColor3 = self.crossColor
		end

		local radius = self:fovRadiusPx(cam, self.weaponFovPx)
		local cx, cy = cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5
		local showRing = self.drawFov
		for i = 1, FOV_SEGMENTS do
			local seg = fovRing[i]
			if seg then
				if showRing then
					local t = (i / FOV_SEGMENTS) * math.pi * 2
					seg.Visible = true
					seg.BackgroundColor3 = self.fovRingColor
					seg.Position = UDim2.fromOffset(cx + math.cos(t) * radius, cy + math.sin(t) * radius)
				else
					seg.Visible = false
				end
			end
		end

		if fovFill then
			if self.filledFov and self.drawFov then
				fovFill.Visible = true
				fovFill.BackgroundColor3 = self.fovRingColor
				fovFill.BackgroundTransparency = self.fovFillTransparency
				fovFill.Size = UDim2.fromOffset(radius * 2, radius * 2)
			else
				fovFill.Visible = false
			end
		end

		if statusLabel then
			if self.visualCheck then
				local pt, ch = self:pickTarget(cam, self.weaponFovPx, self.targetBones, self.stickyChar)
				statusLabel.Visible = true
				statusLabel.Text = string.format(
					"Aim:%s key:%s vis:%s | tgt:%s silent:%s trig:%s",
					self.aimbotEnabled and "on" or "off",
					self:aimKeysHeld() and "hold" or "—",
					self.visibleCheck and "on" or "off",
					pt and (ch and ch.Name or "?") or "none",
					self.silentOn and "on" or "off",
					self.triggerEnabled and "on" or "off"
				)
			else
				statusLabel.Visible = false
			end
		end
	end

	function Aim:runSilentBurst(cam)
		if not self.silentOn or not self:canAim() then
			return
		end
		local pt, ch = self:pickTarget(cam, self.silentFovPx, self.targetBones, self.stickyChar)
		if pt then
			self.stickyChar = ch
			for _ = 1, 2 do
				self:rotateToward(cam, pt, self.silentMaxDeg * self.silentStrength)
			end
		end
	end

	function Aim:tryTriggerbot(cam, dt)
		if not self.triggerEnabled or not self.triggerKeyHeld or not self:canAim() then
			self.triggerAcc = 0
			return
		end
		local pt, ch = self:pickTarget(cam, math.max(8, self.deadzonePx + 2), self.triggerBones, nil)
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
			local cx = cam.ViewportSize.X * 0.5
			local cy = cam.ViewportSize.Y * 0.5
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

		RunService:BindToRenderStep(AIM_RENDER, Enum.RenderPriority.Last.Value, function(dt)
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end

			self:updateVisuals(cam)

			if self:shouldRunAimbot() then
				local pt, ch = self:pickTarget(cam, self.weaponFovPx, self.targetBones, self.stickyChar)
				if pt then
					self.stickyChar = ch
					local cap = self.lockCapDeg
					if self.smoothing >= 50 then
						cap = cap * 0.65
					else
						cap = cap * (1 + (50 - math.clamp(self.smoothing, 1, 50)) * 0.02)
					end
					self:rotateToward(cam, pt, cap)
				else
					self.stickyChar = nil
				end
			elseif not self:aimKeysHeld() then
				self.stickyChar = nil
			end

			if self.firingSilent then
				self:runSilentBurst(cam)
			end

			self:tryTriggerbot(cam, dt)
		end)

		self.inputBeganConn = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			if not self:canAim() then
				return
			end
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			if self.silentOn then
				self.firingSilent = true
				self:runSilentBurst(cam)
			end
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
		self.triggerAcc = 0
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
