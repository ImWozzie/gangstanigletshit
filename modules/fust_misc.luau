-- Misc: Vault-style farmAura / killAura / speed / hitbox + info overlays.
-- Farm drives legit FustGather (mouse toward WeakSpot + click) — same path Vault uses.
return function(deps)
	local Players = deps.Players
	local RunService = deps.RunService
	local UserInputService = deps.UserInputService
	local LOCAL = deps.LocalPlayer
	local Workspace = game:GetService("Workspace")

	local Misc = {
		-- legacy gather flags
		autoWeak = false,
		primeFresh = false,
		maxDist = 8.5,
		aimDeadzonePx = 18,
		aimCapDeg = 4.5,
		swingCdMs = 420,
		requireTool = true,
		nodeTypes = { "tree", "stone", "metal", "sulfur" },
		bound = false,
		disabledReason = nil,

		-- Vault farmAura
		farmEnabled = false,
		farmRange = 2,
		farmCooldown = 0.2,
		farmAimWeakspot = true,
		farmAutoCooldown = true,
		farmSkipCactus = true,
		farmHold = false,
		farmKeyHeld = false,
		_farmLast = 0,

		-- Vault killAura
		killEnabled = false,
		killRange = 7,
		killCooldown = 0.35,
		killHold = false,
		killKeyHeld = false,
		_killLast = 0,

		-- Vault speedBoost
		speedEnabled = false,
		speedValue = 22,
		speedMode = "cframe", -- cframe | walk
		_speedConn = nil,
		_origWalk = nil,

		-- Vault hitbox
		hitboxEnabled = false,
		hitboxScale = 5,
		hitboxTarget = "Head",
		_hitOrig = {},
		_hitConn = nil,

		-- Vault wallClimb
		wallClimbEnabled = false,
		wallClimbSpeed = 40,
		wallClimbJumpCd = 0.15,
		_wallLastJump = 0,
		_wallConn = nil,

		-- external.wtf "Noclip" + **Wall Depth** slider — partial (limbs off, core collides)
		noclipEnabled = false,
		noclipHold = false,
		noclipKeyHeld = false,
		wallDepth = 0.2,
		wallDepthMin = 0.1,
		wallDepthMax = 0.2,
		noclipUseBodyBlock = false,
		noclipManaged = true,
		_noclipConn = nil,
		_noclipDescConn = nil,
		_noclipCharConn = nil,
		_noclipOrig = nil,

		-- Gun mods: input + viewmodel kick zero (filtergc), not GunControl hooks
		gunAuto = false,
		gunRapid = false,
		gunRapidRate = 0.08,
		_gunConn = nil,
		_gunLast = 0,

		noRecoil = false,
		noSpread = false,
		recoilScale = 1,
		spreadScale = 1,
		_recoilConn = nil,

		-- Vault bowMods (input-side; infAmmo/true noGravity need hooks — not spoofed)
		bowEnabled = false,
		bowInstantCharge = true,
		bowFastShot = false,
		bowChargeTime = 0.05, -- draw hold before release when instant
		bowFastGap = 0.12,
		_bowConn = nil,
		_bowState = "idle", -- idle | drawing | wait
		_bowUntil = 0,
		_bowWasDown = false,

		-- info
		invViewer = false,
		invMaxDist = 2000,
		invRate = 0.25,
		targetInfo = false,
		tiMaxDist = 2000,
		tiRate = 0.1,
	}

	local farmConn
	local invGui, invLabel, tiGui, tiLabel
	local invConn, tiConn
	local invAcc, tiAcc = 0, 0

	local function clickOnce()
		if type(mouse1click) == "function" then
			mouse1click()
			return
		end
		if type(mouse1press) == "function" then
			mouse1press()
			task.defer(function()
				if type(mouse1release) == "function" then
					mouse1release()
				end
			end)
			return
		end
		pcall(function()
			local vim = game:GetService("VirtualInputManager")
			vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
			vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end)
	end

	local function aimWorld(cam, worldPos)
		local sp, on = cam:WorldToViewportPoint(worldPos)
		if not on or sp.Z <= 0 then
			return false
		end
		local vs = cam.ViewportSize
		local dx, dy = sp.X - vs.X * 0.5, sp.Y - vs.Y * 0.5
		local dist = math.sqrt(dx * dx + dy * dy)
		if dist < 4 then
			return true
		end
		local sx = math.clamp(math.floor(dx / 2 + 0.5), -40, 40)
		local sy = math.clamp(math.floor(dy / 2 + 0.5), -40, 40)
		if type(mousemoverel) == "function" then
			mousemoverel(sx, sy)
			return dist < 18
		end
		-- fallback camera nudge
		local look = cam.CFrame.LookVector
		local want = (worldPos - cam.CFrame.Position).Unit
		cam.CFrame = CFrame.lookAt(cam.CFrame.Position, cam.CFrame.Position + look:Lerp(want, 0.35).Unit)
		return dist < 24
	end

	local function nearestWeakspot(origin, range)
		local nodes = Workspace:FindFirstChild("Nodes")
		if not nodes then
			return nil
		end
		local best, bestD
		for _, d in ipairs(nodes:GetDescendants()) do
			if d.Name == "WeakSpot" and d:IsA("BasePart") then
				local model = d:FindFirstAncestorOfClass("Model") or d.Parent
				if Misc.farmSkipCactus and model then
					local nt = string.lower(tostring(model:GetAttribute("NodeType") or model.Name))
					if string.find(nt, "cactus", 1, true) then
						continue
					end
				end
				local dist = (d.Position - origin).Magnitude
				if dist <= range and (not bestD or dist < bestD) then
					best, bestD = d, dist
				end
			end
		end
		return best, bestD
	end

	local function nearestNodePart(origin, range)
		local nodes = Workspace:FindFirstChild("Nodes")
		if not nodes then
			return nil
		end
		local best, bestD
		for _, m in ipairs(nodes:GetChildren()) do
			if Misc.farmSkipCactus then
				local nt = string.lower(tostring(m:GetAttribute("NodeType") or m.Name))
				if string.find(nt, "cactus", 1, true) then
					continue
				end
			end
			local part = m.PrimaryPart or m:FindFirstChildWhichIsA("BasePart", true)
			if part then
				local dist = (part.Position - origin).Magnitude
				if dist <= range and (not bestD or dist < bestD) then
					best, bestD = part, dist
				end
			end
		end
		return best, bestD
	end

	local function farmStep()
		if not Misc.farmEnabled then
			return
		end
		if Misc.farmHold and not Misc.farmKeyHeld then
			return
		end
		local char = LOCAL.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local cam = Workspace.CurrentCamera
		if not hrp or not cam then
			return
		end
		if Misc.requireTool and not char:FindFirstChildOfClass("Tool") then
			return
		end
		local now = os.clock()
		local cd = Misc.farmAutoCooldown and Misc.farmCooldown or Misc.farmCooldown
		if now - Misc._farmLast < cd then
			return
		end
		local target
		if Misc.farmAimWeakspot then
			target = nearestWeakspot(hrp.Position, Misc.farmRange)
		end
		if not target then
			target = nearestNodePart(hrp.Position, Misc.farmRange)
		end
		if not target then
			return
		end
		local ready = aimWorld(cam, target.Position)
		if ready then
			Misc._farmLast = now
			clickOnce()
		end
	end

	local function killStep()
		if not Misc.killEnabled then
			return
		end
		if Misc.killHold and not Misc.killKeyHeld then
			return
		end
		local char = LOCAL.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if not hrp then
			return
		end
		local now = os.clock()
		if now - Misc._killLast < Misc.killCooldown then
			return
		end
		local range = Misc.killRange
		local hit = false
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LOCAL and plr.Character then
				local root = plr.Character:FindFirstChild("HumanoidRootPart")
				local hum = plr.Character:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health > 0 and (root.Position - hrp.Position).Magnitude <= range then
					hit = true
					break
				end
			end
		end
		if not hit then
			local npcs = Workspace:FindFirstChild("Npcs")
			if npcs then
				for _, m in ipairs(npcs:GetChildren()) do
					local root = m:FindFirstChild("HumanoidRootPart")
					local hum = m:FindFirstChildOfClass("Humanoid")
					if root and hum and hum.Health > 0 and (root.Position - hrp.Position).Magnitude <= range then
						hit = true
						break
					end
				end
			end
		end
		if hit then
			Misc._killLast = now
			clickOnce()
		end
	end

	function Misc:syncFarm()
		self.autoWeak = self.farmEnabled
		if self.farmEnabled or self.killEnabled then
			if not farmConn then
				farmConn = RunService.Heartbeat:Connect(function()
					farmStep()
					killStep()
				end)
			end
		elseif farmConn then
			farmConn:Disconnect()
			farmConn = nil
		end
	end

	function Misc:syncSpeed()
		if self._speedConn then
			self._speedConn:Disconnect()
			self._speedConn = nil
		end
		local char = LOCAL.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not self.speedEnabled then
			if hum and self._origWalk then
				hum.WalkSpeed = self._origWalk
			end
			self._origWalk = nil
			return
		end
		if self.speedMode == "walk" and hum then
			if not self._origWalk then
				self._origWalk = hum.WalkSpeed
			end
			hum.WalkSpeed = self.speedValue
			return
		end
		self._speedConn = RunService.Heartbeat:Connect(function(dt)
			if not self.speedEnabled then
				return
			end
			local c = LOCAL.Character
			local root = c and c:FindFirstChild("HumanoidRootPart")
			local h = c and c:FindFirstChildOfClass("Humanoid")
			if not root or not h or h.Health <= 0 then
				return
			end
			local move = h.MoveDirection
			if move.Magnitude < 0.05 then
				return
			end
			root.CFrame = root.CFrame + move.Unit * self.speedValue * dt
		end)
	end

	local function restoreHitbox()
		for part, size in pairs(Misc._hitOrig) do
			if part and part.Parent then
				pcall(function()
					part.Size = size
				end)
			end
		end
		table.clear(Misc._hitOrig)
	end

	function Misc:syncHitbox()
		if self._hitConn then
			self._hitConn:Disconnect()
			self._hitConn = nil
		end
		restoreHitbox()
		if not self.hitboxEnabled then
			return
		end
		self._hitConn = RunService.Heartbeat:Connect(function()
			if not self.hitboxEnabled then
				return
			end
			local targetName = self.hitboxTarget or "Head"
			local scale = math.clamp(self.hitboxScale or 5, 1, 20)
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr ~= LOCAL and plr.Character then
					local part = plr.Character:FindFirstChild(targetName)
					if part and part:IsA("BasePart") then
						if not self._hitOrig[part] then
							self._hitOrig[part] = part.Size
						end
						local base = self._hitOrig[part]
						local want = Vector3.new(base.X * scale, base.Y * scale, base.Z * scale)
						if (part.Size - want).Magnitude > 0.05 then
							pcall(function()
								part.Size = want
								part.CanCollide = false
								part.Transparency = math.max(part.Transparency, 0.6)
							end)
						end
					end
				end
			end
		end)
	end

	function Misc:syncWallClimb()
		if self._wallConn then
			self._wallConn:Disconnect()
			self._wallConn = nil
		end
		if not self.wallClimbEnabled then
			return
		end
		self._wallConn = RunService.Heartbeat:Connect(function(dt)
			if not self.wallClimbEnabled then
				return
			end
			local char = LOCAL.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if not hrp or not hum or hum.Health <= 0 then
				return
			end
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { char }
			local look = hrp.CFrame.LookVector
			local hit = Workspace:Raycast(hrp.Position, look * 2.2, params)
			if not hit then
				hit = Workspace:Raycast(hrp.Position, (look + Vector3.yAxis * 0.2).Unit * 2.2, params)
			end
			if not hit then
				return
			end
			local climbing = UserInputService:IsKeyDown(Enum.KeyCode.Space)
				or UserInputService:IsKeyDown(Enum.KeyCode.W)
			if not climbing then
				return
			end
			local now = os.clock()
			if now - self._wallLastJump < self.wallClimbJumpCd then
				return
			end
			self._wallLastJump = now
			hrp.AssemblyLinearVelocity = Vector3.new(
				hrp.AssemblyLinearVelocity.X,
				self.wallClimbSpeed,
				hrp.AssemblyLinearVelocity.Z
			)
			hrp.CFrame = hrp.CFrame + Vector3.new(0, self.wallClimbSpeed * dt * 0.35, 0)
		end)
	end

	local function noclipActive(self)
		if not self.noclipEnabled then
			return false
		end
		if self.noclipHold then
			return self.noclipKeyHeld
		end
		return true
	end

	local function ensureNoclipCache(self)
		if self._noclipOrig then
			return
		end
		self._noclipOrig = setmetatable({}, { __mode = "k" })
	end

	local NOCLIP_GROUP = "FustBodyBlock"
	local NOCLIP_CORE = {
		HumanoidRootPart = true,
		Head = true,
		UpperTorso = true,
		LowerTorso = true,
		Torso = true,
	}

	local function restoreNoclip(self)
		if not self._noclipOrig then
			return
		end
		for part, was in pairs(self._noclipOrig) do
			if part and part.Parent then
				pcall(function()
					if type(was) == "table" then
						part.CanCollide = was.cc
						if was.group then
							part.CollisionGroup = was.group
						end
					else
						part.CanCollide = was
					end
				end)
			end
		end
		table.clear(self._noclipOrig)
	end

	local function applyNoclipPart(self, part)
		if not part or not part:IsA("BasePart") then
			return
		end
		ensureNoclipCache(self)
		local cache = self._noclipOrig
		if cache[part] == nil then
			cache[part] = { cc = part.CanCollide, group = part.CollisionGroup }
		end
		if self.noclipUseBodyBlock then
			pcall(function()
				part.CollisionGroup = NOCLIP_GROUP
			end)
		end
		-- Live external: HRP/Head/Torso keep CanCollide — only limbs/accessories off
		if NOCLIP_CORE[part.Name] then
			return
		end
		if part.CanCollide then
			part.CanCollide = false
		end
	end

	local function applyNoclip(self, char)
		if not char then
			return
		end
		for _, d in ipairs(char:GetDescendants()) do
			if d:IsA("BasePart") then
				applyNoclipPart(self, d)
			end
		end
	end

	local function wallDepthStep(self, char, hum, hrp)
		local move = hum.MoveDirection
		local dir = move.Magnitude >= 0.05 and move.Unit or hrp.CFrame.LookVector
		local depth = math.clamp(self.wallDepth or 0.2, self.wallDepthMin or 0.1, self.wallDepthMax or 2)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { char }
		local hit = Workspace:Raycast(hrp.Position, dir * (depth + 3), params)
		if not hit then
			return
		end
		if hit.Distance <= depth + 0.35 then
			local push = depth - hit.Distance + 0.05
			if push > 0 then
				hrp.CFrame = hrp.CFrame + dir * math.min(push, depth)
			end
		end
	end

	local function bindNoclipCharacter(self, char)
		if self._noclipDescConn then
			self._noclipDescConn:Disconnect()
			self._noclipDescConn = nil
		end
		if not char then
			return
		end
		self._noclipDescConn = char.DescendantAdded:Connect(function(inst)
			if not noclipActive(self) then
				return
			end
			if inst:IsA("BasePart") then
				applyNoclipPart(self, inst)
			end
		end)
		if noclipActive(self) then
			applyNoclip(self, char)
		end
	end

	function Misc:syncNoclip()
		if self._noclipConn then
			self._noclipConn:Disconnect()
			self._noclipConn = nil
		end
		if self._noclipCharConn then
			self._noclipCharConn:Disconnect()
			self._noclipCharConn = nil
		end
		if self._noclipDescConn then
			self._noclipDescConn:Disconnect()
			self._noclipDescConn = nil
		end
		if not self.noclipEnabled then
			restoreNoclip(self)
			return
		end
		self._noclipCharConn = LOCAL.CharacterAdded:Connect(function(char)
			bindNoclipCharacter(self, char)
		end)
		bindNoclipCharacter(self, LOCAL.Character)
		self._noclipConn = RunService.Heartbeat:Connect(function()
			if not noclipActive(self) then
				restoreNoclip(self)
				return
			end
			local char = LOCAL.Character
			if not char then
				return
			end
			local hum = char:FindFirstChildOfClass("Humanoid")
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if not hum or not hrp or hum.Health <= 0 then
				return
			end
			applyNoclip(self, char)
			if self.noclipManaged then
				wallDepthStep(self, char, hum, hrp)
			end
		end)
	end

	local function zeroGunKick(state, recoilMul, spreadMul)
		if not state or type(state) ~= "table" then
			return
		end
		if recoilMul ~= nil then
			local m = math.clamp(recoilMul, 0, 2)
			if m <= 0 then
				if state.kickV ~= nil then state.kickV = 0 end
				if state.kickRoll ~= nil then state.kickRoll = 0 end
				if state.kickPitch ~= nil then state.kickPitch = 0 end
				if state.kickBack ~= nil then state.kickBack = 0 end
				if state.kick ~= nil then state.kick = 0 end
				if state.recoil ~= nil then state.recoil = 0 end
				if state.recoilYaw ~= nil then state.recoilYaw = 0 end
				if state.RecoilPend ~= nil then state.RecoilPend = 0 end
				if state.BoltKick ~= nil then state.BoltKick = 0 end
				if state.shakeStrength ~= nil then state.shakeStrength = 0 end
			else
				if state.kickPitch ~= nil then state.kickPitch = (state.kickPitch or 0) * m end
				if state.kickBack ~= nil then state.kickBack = (state.kickBack or 0) * m end
				if state.recoil ~= nil then state.recoil = (state.recoil or 0) * m end
				if state.recoilYaw ~= nil then state.recoilYaw = (state.recoilYaw or 0) * m end
			end
		end
		if spreadMul ~= nil then
			local s = math.clamp(spreadMul, 0, 2)
			if state.SpreadPx ~= nil then
				state.SpreadPx = (state.SpreadPx or 0) * s
			end
		end
	end

	function Misc:syncRecoilMods()
		if self._recoilConn then
			self._recoilConn:Disconnect()
			self._recoilConn = nil
		end
		if not (self.noRecoil or self.noSpread or self.recoilScale < 0.99 or self.spreadScale < 0.99) then
			return
		end
		local recoilMul = self.noRecoil and 0 or math.clamp(self.recoilScale, 0, 2)
		local spreadMul = self.noSpread and 0 or math.clamp(self.spreadScale, 0, 2)
		self._recoilConn = RunService.RenderStepped:Connect(function()
			if not (self.noRecoil or self.noSpread or self.recoilScale < 0.99 or self.spreadScale < 0.99) then
				return
			end
			if filtergc then
				local gun = filtergc("table", { Keys = { "kickV", "SpreadPx" } }, true)
				if gun then
					zeroGunKick(gun, recoilMul, spreadMul)
				end
				local gather = filtergc("table", { Keys = { "kickV", "kickRoll" } }, true)
				if gather and gather ~= gun then
					zeroGunKick(gather, recoilMul, nil)
				end
			end
		end)
	end

	function Misc:syncGunMods()
		if self._gunConn then
			self._gunConn:Disconnect()
			self._gunConn = nil
		end
		if not (self.gunAuto or self.gunRapid) then
			return
		end
		self._gunConn = RunService.Heartbeat:Connect(function()
			if not (self.gunAuto or self.gunRapid) then
				return
			end
			local char = LOCAL.Character
			local tool = char and char:FindFirstChildOfClass("Tool")
			if not tool then
				return
			end
			local id = string.lower(tostring(tool:GetAttribute("ItemId") or tool.Name))
			if string.find(id, "bow", 1, true) then
				return -- bows handled by syncBowMods
			end
			local holding = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
			if self.gunAuto and not holding then
				if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
					return
				end
			elseif not holding and not self.gunAuto then
				return
			end
			local now = os.clock()
			local rate = self.gunRapid and self.gunRapidRate or 0.12
			if now - self._gunLast < rate then
				return
			end
			self._gunLast = now
			clickOnce()
		end)
	end

	local function isBowTool(tool)
		if not tool then
			return false
		end
		local id = string.lower(tostring(tool:GetAttribute("ItemId") or tool.Name))
		return string.find(id, "bow", 1, true) ~= nil or string.find(id, "crossbow", 1, true) ~= nil
	end

	local function mouseDown()
		if type(mouse1press) == "function" then
			mouse1press()
			return
		end
		pcall(function()
			game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, true, game, 0)
		end)
	end

	local function mouseUp()
		if type(mouse1release) == "function" then
			mouse1release()
			return
		end
		pcall(function()
			game:GetService("VirtualInputManager"):SendMouseButtonEvent(0, 0, 0, false, game, 0)
		end)
	end

	function Misc:syncBowMods()
		if self._bowConn then
			self._bowConn:Disconnect()
			self._bowConn = nil
		end
		self._bowState = "idle"
		self._bowWasDown = false
		if not self.bowEnabled then
			return
		end
		self._bowConn = RunService.Heartbeat:Connect(function()
			if not self.bowEnabled then
				return
			end
			local char = LOCAL.Character
			local tool = char and char:FindFirstChildOfClass("Tool")
			if not isBowTool(tool) then
				self._bowState = "idle"
				return
			end
			local now = os.clock()
			local down = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
			-- Instant charge: on fresh M1, hold briefly then release (full-send draw).
			if self.bowInstantCharge then
				if down and not self._bowWasDown and self._bowState == "idle" then
					self._bowState = "drawing"
					self._bowUntil = now + (self.bowChargeTime or 0.05)
					mouseDown()
				elseif self._bowState == "drawing" and now >= self._bowUntil then
					mouseUp()
					self._bowState = self.bowFastShot and "wait" or "idle"
					self._bowUntil = now + (self.bowFastGap or 0.12)
				elseif self._bowState == "wait" and now >= self._bowUntil then
					self._bowState = "idle"
					if self.bowFastShot then
						mouseDown()
						self._bowState = "drawing"
						self._bowUntil = now + (self.bowChargeTime or 0.05)
					end
				end
			elseif self.bowFastShot then
				-- Fast shot only: after user releases, auto start next draw.
				if self._bowWasDown and not down and self._bowState == "idle" then
					self._bowState = "wait"
					self._bowUntil = now + (self.bowFastGap or 0.12)
				elseif self._bowState == "wait" and now >= self._bowUntil then
					self._bowState = "idle"
					mouseDown()
				end
			end
			self._bowWasDown = down
		end)
	end

	-- ---- info overlays (unchanged behavior) ----
	local function ensureInv()
		local pg = LOCAL:FindFirstChildOfClass("PlayerGui")
		if not pg then
			return
		end
		if invGui and invGui.Parent then
			return
		end
		invGui = Instance.new("ScreenGui")
		invGui.Name = "FustInvViewer"
		invGui.ResetOnSpawn = false
		invGui.IgnoreGuiInset = true
		invGui.DisplayOrder = 40
		invGui:SetAttribute("FustBaseEsp", true)
		local frame = Instance.new("Frame")
		frame.AnchorPoint = Vector2.new(0, 0.5)
		frame.Position = UDim2.new(0, 12, 0.5, 0)
		frame.Size = UDim2.fromOffset(260, 220)
		frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
		frame.BackgroundTransparency = 0.25
		frame.BorderSizePixel = 0
		frame.Parent = invGui
		Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)
		invLabel = Instance.new("TextLabel")
		invLabel.BackgroundTransparency = 1
		invLabel.Size = UDim2.new(1, -12, 1, -12)
		invLabel.Position = UDim2.fromOffset(6, 6)
		invLabel.Font = Enum.Font.GothamMedium
		invLabel.TextSize = 13
		invLabel.TextXAlignment = Enum.TextXAlignment.Left
		invLabel.TextYAlignment = Enum.TextYAlignment.Top
		invLabel.TextColor3 = Color3.fromRGB(230, 230, 230)
		invLabel.TextStrokeTransparency = 0.5
		invLabel.TextWrapped = true
		invLabel.Text = ""
		invLabel.Parent = frame
		invGui.Parent = pg
	end

	local function ensureTi()
		local pg = LOCAL:FindFirstChildOfClass("PlayerGui")
		if not pg then
			return
		end
		if tiGui and tiGui.Parent then
			return
		end
		tiGui = Instance.new("ScreenGui")
		tiGui.Name = "FustTargetInfo"
		tiGui.ResetOnSpawn = false
		tiGui.IgnoreGuiInset = true
		tiGui.DisplayOrder = 41
		tiGui:SetAttribute("FustBaseEsp", true)
		tiLabel = Instance.new("TextLabel")
		tiLabel.AnchorPoint = Vector2.new(0.5, 0)
		tiLabel.Position = UDim2.new(0.5, 0, 0, 72)
		tiLabel.Size = UDim2.fromOffset(420, 64)
		tiLabel.BackgroundTransparency = 1
		tiLabel.Font = Enum.Font.GothamBold
		tiLabel.TextSize = 15
		tiLabel.TextColor3 = Color3.fromRGB(255, 230, 230)
		tiLabel.TextStrokeTransparency = 0.35
		tiLabel.Text = ""
		tiLabel.Parent = tiGui
		tiGui.Parent = pg
	end

	local function wearSummary(char)
		local wear = char and char:FindFirstChild("FustWear")
		if not wear then
			return "naked"
		end
		local seen, list = {}, {}
		for _, child in ipairs(wear:GetChildren()) do
			local id = child:GetAttribute("ItemId")
			if typeof(id) == "string" and not seen[id] then
				seen[id] = true
				list[#list + 1] = id:gsub("_", " ")
			end
		end
		return #list > 0 and table.concat(list, ", ") or "naked"
	end

	local function heldName(char)
		local tool = char and char:FindFirstChildOfClass("Tool")
		return tool and tool.Name or nil
	end

	local function refreshInv()
		ensureInv()
		if not invLabel then
			return
		end
		local origin = LOCAL.Character and LOCAL.Character:FindFirstChild("HumanoidRootPart")
		if not origin then
			invLabel.Text = "no character"
			return
		end
		local best, bestD
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LOCAL then
				local char = plr.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health > 0 then
					local d = (root.Position - origin.Position).Magnitude
					if d <= Misc.invMaxDist and (not bestD or d < bestD) then
						best, bestD = plr, d
					end
				end
			end
		end
		if not best then
			invLabel.Text = "no players in range"
			return
		end
		local char = best.Character
		local hum = char:FindFirstChildOfClass("Humanoid")
		invLabel.Text = table.concat({
			string.format("%s  [%dm]", best.DisplayName ~= "" and best.DisplayName or best.Name, math.floor(bestD + 0.5)),
			string.format("HP %.0f / %.0f", hum and hum.Health or 0, hum and hum.MaxHealth or 0),
			"Held: " .. (heldName(char) or "—"),
			"Wear: " .. wearSummary(char),
		}, "\n")
	end

	local function refreshTi()
		ensureTi()
		if not tiLabel then
			return
		end
		local cam = Workspace.CurrentCamera
		if not cam then
			tiLabel.Text = ""
			return
		end
		local origin, look = cam.CFrame.Position, cam.CFrame.LookVector
		local best, bestDot, bestD
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LOCAL and plr.Character then
				local root = plr.Character:FindFirstChild("HumanoidRootPart")
				local hum = plr.Character:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health > 0 then
					local delta = root.Position - origin
					local dist = delta.Magnitude
					if dist > 1 and dist <= Misc.tiMaxDist then
						local dot = look:Dot(delta.Unit)
						if dot > 0.92 and (not bestDot or dot > bestDot) then
							best, bestDot, bestD = plr, dot, dist
						end
					end
				end
			end
		end
		if not best then
			tiLabel.Text = ""
			return
		end
		local char = best.Character
		local hum = char:FindFirstChildOfClass("Humanoid")
		tiLabel.Text = string.format(
			"%s · %.0fhp · %s · %dm",
			best.DisplayName ~= "" and best.DisplayName or best.Name,
			hum and hum.Health or 0,
			heldName(char) or "—",
			math.floor(bestD + 0.5)
		)
	end

	function Misc:syncInv()
		if self.invViewer then
			ensureInv()
			if invGui then
				invGui.Enabled = true
			end
			if not invConn then
				invAcc = 0
				invConn = RunService.Heartbeat:Connect(function(dt)
					if not self.invViewer then
						return
					end
					invAcc += dt
					if invAcc >= self.invRate then
						invAcc = 0
						refreshInv()
					end
				end)
			end
		else
			if invConn then
				invConn:Disconnect()
				invConn = nil
			end
			if invGui then
				invGui.Enabled = false
			end
		end
	end

	function Misc:syncTargetInfo()
		if self.targetInfo then
			ensureTi()
			if tiGui then
				tiGui.Enabled = true
			end
			if not tiConn then
				tiAcc = 0
				tiConn = RunService.Heartbeat:Connect(function(dt)
					if not self.targetInfo then
						return
					end
					tiAcc += dt
					if tiAcc >= self.tiRate then
						tiAcc = 0
						refreshTi()
					end
				end)
			end
		else
			if tiConn then
				tiConn:Disconnect()
				tiConn = nil
			end
			if tiGui then
				tiGui.Enabled = false
			end
		end
	end

	function Misc:syncBind()
		self:syncFarm()
		self:syncSpeed()
		self:syncHitbox()
		self:syncWallClimb()
		self:syncNoclip()
		self:syncGunMods()
		self:syncRecoilMods()
		self:syncBowMods()
		self:syncInv()
		self:syncTargetInfo()
	end

	function Misc:setNodeTypes(list)
		if type(list) == "table" then
			self.nodeTypes = list
		end
	end

	function Misc:bind()
		self:syncFarm()
	end

	function Misc:unbind()
		self.bound = false
	end

	function Misc:destroy()
		self.farmEnabled = false
		self.killEnabled = false
		self.speedEnabled = false
		self.hitboxEnabled = false
		self.wallClimbEnabled = false
		self.noclipEnabled = false
		self.noclipKeyHeld = false
		self.gunAuto = false
		self.gunRapid = false
		self.noRecoil = false
		self.noSpread = false
		self.bowEnabled = false
		self.autoWeak = false
		self.invViewer = false
		self.targetInfo = false
		if farmConn then
			farmConn:Disconnect()
			farmConn = nil
		end
		if self._speedConn then
			self._speedConn:Disconnect()
			self._speedConn = nil
		end
		if self._hitConn then
			self._hitConn:Disconnect()
			self._hitConn = nil
		end
		if self._wallConn then
			self._wallConn:Disconnect()
			self._wallConn = nil
		end
		if self._noclipConn then
			self._noclipConn:Disconnect()
			self._noclipConn = nil
		end
		if self._noclipCharConn then
			self._noclipCharConn:Disconnect()
			self._noclipCharConn = nil
		end
		if self._noclipDescConn then
			self._noclipDescConn:Disconnect()
			self._noclipDescConn = nil
		end
		restoreNoclip(self)
		self._noclipOrig = nil
		if self._gunConn then
			self._gunConn:Disconnect()
			self._gunConn = nil
		end
		if self._recoilConn then
			self._recoilConn:Disconnect()
			self._recoilConn = nil
		end
		if self._bowConn then
			self._bowConn:Disconnect()
			self._bowConn = nil
		end
		restoreHitbox()
		if invConn then
			invConn:Disconnect()
			invConn = nil
		end
		if tiConn then
			tiConn:Disconnect()
			tiConn = nil
		end
		if invGui then
			invGui:Destroy()
			invGui = nil
		end
		if tiGui then
			tiGui:Destroy()
			tiGui = nil
		end
	end

	return Misc
end
