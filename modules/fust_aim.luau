-- Fust aim module (camera-only). Returns factory(deps) -> Aim
return function(deps)
	local Players = deps.Players
	local RunService = deps.RunService
	local UserInputService = deps.UserInputService
	local LOCAL = deps.LocalPlayer

	local AIM_RENDER = "FustSafeAimAssist"

	local Aim = {
		assistOn = false,
		snapOn = false,
		maxDist = 450,
		fov = 5,
		snapFov = 2.5,
		strength = 0.12,
		maxDegPerFrame = 0.65,
		snapMaxDeg = 2.2,
		bone = "Head",
		bound = false,
		inputConn = nil,
	}

	function Aim:isAds()
		if LOCAL:GetAttribute("Dead") == true then
			return false
		end
		return LOCAL:GetAttribute("FustAimGun") == true or LOCAL:GetAttribute("FustAimBow") == true
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

	function Aim:pickTarget(cam, fovDeg)
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
		if ang < 0.05 then
			return
		end
		local step = math.min(capDeg, ang) * math.clamp(strength, 0.02, 1)
		local t = step / math.max(ang, 0.001)
		local newLook = look:Lerp(want, t).Unit
		cam.CFrame = CFrame.lookAt(camPos, camPos + newLook)
	end

	function Aim:syncBind()
		if self.assistOn or self.snapOn then
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
		RunService:BindToRenderStep(AIM_RENDER, Enum.RenderPriority.Camera.Value + 1, function()
			if not self.assistOn or not self:isAds() then
				return
			end
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			local pt = self:pickTarget(cam, self.fov)
			if pt then
				self:rotateToward(cam, pt, self.strength, self.maxDegPerFrame)
			end
		end)
		self.inputConn = UserInputService.InputBegan:Connect(function(input, processed)
			if processed or not self.snapOn or not self:isAds() then
				return
			end
			if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
				return
			end
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			local pt = self:pickTarget(cam, self.snapFov)
			if pt then
				self:rotateToward(cam, pt, 0.85, self.snapMaxDeg)
			end
		end)
	end

	function Aim:unbind()
		pcall(function()
			RunService:UnbindFromRenderStep(AIM_RENDER)
		end)
		if self.inputConn then
			self.inputConn:Disconnect()
			self.inputConn = nil
		end
		self.bound = false
	end

	function Aim:destroy()
		self.assistOn = false
		self.snapOn = false
		self:unbind()
	end

	return Aim
end
