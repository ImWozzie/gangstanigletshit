-- Fust aim module (camera-only). Returns factory(deps) -> Aim
return function(deps)
	local Players = deps.Players
	local RunService = deps.RunService
	local UserInputService = deps.UserInputService
	local LOCAL = deps.LocalPlayer

	local AIM_RENDER = "FustSafeAimAssist"
	local FOV_SEGMENTS = 48

	local Aim = {
		assistOn = false,
		snapOn = false,
		silentOn = false,
		lockEnabled = false,
		lockHeld = false,
		requireAds = true,
		maxDist = 450,
		fov = 5,
		lockFov = 8,
		snapFov = 2.5,
		silentFov = 3.5,
		strength = 0.12,
		lockStrength = 0.55,
		silentStrength = 0.92,
		maxDegPerFrame = 0.65,
		lockMaxDeg = 2.8,
		snapMaxDeg = 2.2,
		silentMaxDeg = 3.5,
		bone = "Head",
		showFov = true,
		showCrosshair = true,
		crossSize = 10,
		crossGap = 4,
		crossThick = 2,
		crossColor = Color3.fromRGB(240, 240, 245),
		fovRingColor = Color3.fromRGB(240, 240, 245),
		fovVisualDeg = 8,
		bound = false,
		inputBeganConn = nil,
		inputEndedConn = nil,
		lockedPt = nil,
		firingSilent = false,
	}

	local crossGui
	local crossParts = {}
	local fovRing = {}

	local function isActive()
		return Aim.lockEnabled
			or Aim.assistOn
			or Aim.snapOn
			or Aim.silentOn
			or Aim.showCrosshair
			or Aim.showFov
	end

	function Aim:isAds()
		if LOCAL:GetAttribute("Dead") == true then
			return false
		end
		return LOCAL:GetAttribute("FustAimGun") == true or LOCAL:GetAttribute("FustAimBow") == true
	end

	function Aim:canAim()
		if not self.requireAds then
			return true
		end
		return self:isAds()
	end

	function Aim:aimPoint(char)
		local p = char:FindFirstChild(self.bone) or char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso")
		if p and p:IsA("BasePart") then
			return p.Position + Vector3.new(0, 0.08, 0)
		end
		return nil
	end

	function Aim:angleDeg(a, b)
		return math.deg(math.acos(math.clamp(a:Dot(b), -1, 1)))
	end

	function Aim:pickTarget(cam, fovDeg, stickyPt)
		if stickyPt then
			local camPos = cam.CFrame.Position
			local look = cam.CFrame.LookVector
			local dir = (stickyPt - camPos).Unit
			if self:angleDeg(look, dir) <= fovDeg * 1.35 then
				return stickyPt
			end
		end

		local camPos = cam.CFrame.Position
		local look = cam.CFrame.LookVector
		local best
		local bestAng = fovDeg
		local maxD2 = self.maxDist * self.maxDist

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LOCAL then
				local char = plr.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if hum and root and hum.Health > 0 then
					local delta = root.Position - camPos
					if delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z <= maxD2 then
						local pt = self:aimPoint(char)
						if pt then
							local dir = (pt - camPos).Unit
							local ang = self:angleDeg(look, dir)
							if ang < bestAng then
								bestAng = ang
								best = pt
							end
						end
					end
				end
			end
		end
		return best
	end

	function Aim:rotateToward(cam, worldPos, strength, capDeg)
		local camPos = cam.CFrame.Position
		local look = cam.CFrame.LookVector
		local want = (worldPos - camPos).Unit
		local ang = self:angleDeg(look, want)
		if ang < 0.04 then
			return true
		end
		local step = math.min(capDeg, ang) * math.clamp(strength, 0.02, 1)
		local t = step / math.max(ang, 0.001)
		local newLook = look:Lerp(want, t).Unit
		cam.CFrame = CFrame.lookAt(camPos, camPos + newLook)
		return ang < 0.25
	end

	function Aim:fovRadiusPx(cam, fovDeg)
		local camFov = math.rad(cam.FieldOfView)
		local half = math.rad(math.clamp(fovDeg, 0.5, 45) * 0.5)
		local vy = cam.ViewportSize.Y * 0.5
		if camFov < 0.01 then
			return 40
		end
		return (math.tan(half) / math.tan(camFov * 0.5)) * vy
	end

	function Aim:destroyCrosshair()
		if crossGui then
			crossGui:Destroy()
			crossGui = nil
		end
		table.clear(crossParts)
		table.clear(fovRing)
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
			seg.BackgroundTransparency = 0.35
			seg.AnchorPoint = Vector2.new(0.5, 0.5)
			seg.Size = UDim2.fromOffset(2, 2)
			seg.Visible = false
			seg.Parent = crossGui
			fovRing[i] = seg
		end
	end

	function Aim:updateVisuals(cam)
		if not crossGui or not crossGui.Parent then
			if self.showCrosshair or self.showFov then
				self:ensureCrosshair()
			else
				return
			end
		end

		local showCross = self.showCrosshair and (self:canAim() or not self.requireAds)
		for _, p in ipairs(crossParts) do
			p.Visible = showCross
			p.BackgroundColor3 = self.crossColor
		end

		local showRing = self.showFov and showCross
		local radius = self:fovRadiusPx(cam, self.fovVisualDeg)
		local cx, cy = cam.ViewportSize.X * 0.5, cam.ViewportSize.Y * 0.5
		for i = 1, FOV_SEGMENTS do
			local seg = fovRing[i]
			if seg then
				if showRing then
					local t = (i / FOV_SEGMENTS) * math.pi * 2
					local x = cx + math.cos(t) * radius
					local y = cy + math.sin(t) * radius
					seg.Visible = true
					seg.BackgroundColor3 = self.fovRingColor
					seg.Position = UDim2.fromOffset(x, y)
				else
					seg.Visible = false
				end
			end
		end
	end

	function Aim:runSilentBurst(cam)
		if not self.silentOn or not self:canAim() then
			return
		end
		local pt = self:pickTarget(cam, self.silentFov, self.lockedPt)
		if pt then
			self.lockedPt = pt
			for _ = 1, 2 do
				self:rotateToward(cam, pt, self.silentStrength, self.silentMaxDeg)
			end
		end
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
		if self.showCrosshair or self.showFov then
			self:ensureCrosshair()
		end

		RunService:BindToRenderStep(AIM_RENDER, Enum.RenderPriority.Camera.Value + 1, function()
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end

			self:updateVisuals(cam)

			if not self:canAim() and self.requireAds then
				return
			end

			local pt

			if self.lockEnabled and self.lockHeld then
				pt = self:pickTarget(cam, self.lockFov, self.lockedPt)
				if pt then
					self.lockedPt = pt
					self:rotateToward(cam, pt, self.lockStrength, self.lockMaxDeg)
				else
					self.lockedPt = nil
				end
			elseif self.assistOn then
				pt = self:pickTarget(cam, self.fov, nil)
				if pt then
					self:rotateToward(cam, pt, self.strength, self.maxDegPerFrame)
				end
			elseif self.firingSilent then
				self:runSilentBurst(cam)
			end
		end)

		self.inputBeganConn = UserInputService.InputBegan:Connect(function(input, processed)
			if processed then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			if not self:canAim() and self.requireAds then
				return
			end
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			if self.snapOn then
				local pt = self:pickTarget(cam, self.snapFov, self.lockedPt)
				if pt then
					self:rotateToward(cam, pt, 0.85, self.snapMaxDeg)
				end
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
		self.lockedPt = nil
		self.firingSilent = false
	end

	function Aim:destroy()
		self.assistOn = false
		self.snapOn = false
		self.silentOn = false
		self.lockEnabled = false
		self.lockHeld = false
		self:unbind()
		self:destroyCrosshair()
	end

	return Aim
end
