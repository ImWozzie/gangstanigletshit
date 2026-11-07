-- Fust aim — Vault-style camera/mouse lock (no Shoot/Swing spoof, no GunControl hooks).
-- Live Vault capture: FOV 220px, smoothing 2 (error/smooth mousemoverel), prediction via
-- bulletSpeed, silent = same lock (Shoot dir matched camera). Not remote silent.
return function(deps)
	local Players = deps.Players
	local RunService = deps.RunService
	local UserInputService = deps.UserInputService
	local LOCAL = deps.LocalPlayer
	local workspace = workspace

	local AIM_RENDER = "FustSafeAimAssist"
	local VISUAL_HUD_TICK = 0.25

	local BONE_ALIASES = {
		Head = "Head",
		Neck = "Neck",
		Chest = "UpperTorso",
		Pelvis = "LowerTorso",
		["HumanoidRootPart"] = "HumanoidRootPart",
	}

	local Aim = {
		-- Vault defaults mirrored
		aimbotEnabled = false,
		prediction = true,
		predictionTime = 0.12,
		bulletSpeed = 900,
		-- Aim as if projectile is hitscan (no travel lead). Does not change server bullets.
		instantAim = false,
		-- Bow ballistic — separate from gun prediction
		bowPrediction = false,
		bowSpeed = 280,
		bowGravity = true,
		bowGravityScale = 1,
		autoBallistics = true,
		bulletGravity = 50,
		assumeFullDraw = false,
		velSmooth = 0.35,
		pingComp = false,
		targetBones = { "Head" },
		smoothing = 2, -- Vault: divide screen error by this each frame
		weaponFovPx = 220,
		maxDist = 1500,
		deadzonePx = 1,
		visibleCheck = false,
		ignoreKnocked = true,
		ignoreTeam = false,
		drawFov = true,
		filledFov = false,
		silentOn = false,
		silentFovPx = 220,
		silentShotOnly = false,
		silentMaxDist = 525,
		targetNpcs = true,
		lockAssist = true, -- Vault always locks when enabled
		maxMousePx = 120, -- Vault-scale; was soft-capped at 2
		assistHz = 60, -- every render frame effectively
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
		requireHoldKey = false, -- Vault always-on when toggle on
		lockCapDeg = 12,
		battleMode = true,
		requireAds = false,
		useMouseDrive = true,
		useCameraAssist = false, -- Vault matched mouse/look; mouse preferred for FustPad
		mouseDriveStrength = 1,
		assistAcc = 0,
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
	}

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	local rayIgnore = {}

	local crossGui
	local crossParts = {}
	local fovRing, fovStroke, fovFill, statusLabel

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
		if typeof(key) == "EnumItem" and key.EnumType == Enum.UserInputType then
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
		if not self.lockAssist then
			return false
		end
		return self.aimbotEnabled and self:aimKeysHeld() and self:canAim()
	end

	function Aim:shouldRunSilent()
		if not self.silentOn then
			return false
		end
		if self.silentShotOnly then
			return UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		end
		return true
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
		if plr and (plr:GetAttribute("Knocked") == true or plr:GetAttribute("Dead") == true) then
			return true
		end
		if char:GetAttribute("Knocked") == true or char:GetAttribute("Downed") == true then
			return true
		end
		return false
	end

	function Aim:sameTeam(plr)
		if not plr then
			return false
		end
		local lt, tt = LOCAL.Team, plr.Team
		if not lt or not tt or lt.Neutral or tt.Neutral then
			return false
		end
		return lt == tt
	end

	function Aim:passesFilters(plr, hum, char)
		if plr and self.ignoreTeam and self:sameTeam(plr) then
			return false
		end
		if self.ignoreKnocked and self:isKnocked(plr, hum, char) then
			return false
		end
		return true
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
			if char and hit.Instance:IsDescendantOf(char) then
				return true
			end
			local inst = hit.Instance
			local seeThrough = inst:IsA("BasePart") and (inst.Transparency > 0.4 or not inst.CanCollide)
			if not seeThrough then
				return false
			end
			rayIgnore[#rayIgnore + 1] = inst
			rayParams.FilterDescendantsInstances = rayIgnore
			remaining -= (hit.Position - origin).Magnitude
			origin = hit.Position + unit * 0.05
			if remaining <= 0.05 then
				return true
			end
		end
		return false
	end

	function Aim:holdingBow()
		if LOCAL:GetAttribute("FustAimBow") == true then
			return true
		end
		local char = LOCAL.Character
		local tool = char and char:FindFirstChildOfClass("Tool")
		if not tool then
			return false
		end
		local id = string.lower(tostring(tool:GetAttribute("ItemId") or tool.Name))
		return string.find(id, "bow", 1, true) ~= nil or string.find(id, "crossbow", 1, true) ~= nil
	end

	-- Game ballistics (ReplicatedStorage.Fust.Items + FustCombat, read 2026-11-06).
	-- Guns: { speed studs/s, gravity studs/s^2 } - no gravity entry = game default 50.
	-- Bows: speed = full * (charge * 125 + 95) / 220, charge 0.15..1 over drawTime; crossbow is always loaded.
	local GAME_GRAVITY = 50
	local GUNS = {
		assault_rifle = { 1350 }, bolt_action_rifle = { 2600, 5 }, custom_smg = { 900, 8 },
		double_barrel = { 520 }, drum_smg = { 880, 8 }, high_caliber_revolver = { 1100 },
		hunt_smg = { 900, 8 }, lever_carbine = { 1250 }, lr_sniper = { 3000, 4 }, m249 = { 1400 },
		pipe_shotgun = { 560 }, pump_shotgun = { 560 }, revolver = { 950 }, rocket_launcher = { 80 },
		scar = { 1450 }, semi_auto_pistol = { 900 }, semi_auto_rifle = { 1425 },
		service_pistol = { 950 }, tactical_smg = { 950, 8 },
	}
	local BOWS = {
		hunting_bow = { full = 220, gravity = 50, draw = 0.8 },
		compound_bow = { full = 290, gravity = 40, draw = 1.1 },
		crossbow = { full = 320, gravity = 28, draw = 0 },
	}
	local MIN_CHARGE = 0.15
	Aim.GUNS, Aim.BOWS = GUNS, BOWS

	local velTrack = setmetatable({}, { __mode = "k" })
	local drawStart = nil

	function Aim:heldItemId()
		local char = LOCAL.Character
		local tool = char and char:FindFirstChildOfClass("Tool")
		if not tool then
			return nil, nil
		end
		local id = tool:GetAttribute("ItemId")
		if type(id) ~= "string" or id == "" then
			id = string.lower((tool.Name:gsub("[%s%-]+", "_")))
		end
		return id, tool.Name
	end

	-- Bow draw charge from how long aim has been held with a bow out (the game's own timer is local).
	function Aim:bowCharge(spec)
		if not spec or spec.draw <= 0 or self.assumeFullDraw then
			return 1
		end
		local held = UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
			or LOCAL:GetAttribute("FustAimBow") == true
		if not held then
			drawStart = nil
			return 1
		end
		drawStart = drawStart or os.clock()
		return math.clamp((os.clock() - drawStart) / spec.draw, MIN_CHARGE, 1)
	end

	-- speed, gravity, label for what is in hand (nil when prediction is off for it).
	function Aim:ballistics()
		local id, name = self:heldItemId()
		local bow = id and BOWS[id]
		if not bow and self:holdingBow() then
			bow = BOWS.hunting_bow
		end
		if bow then
			if not self.bowPrediction then
				return nil
			end
			if self.autoBallistics == false then
				local g = self.bowGravity and GAME_GRAVITY * math.clamp(self.bowGravityScale or 1, 0, 2) or 0
				return math.max(self.bowSpeed or 220, 40), g, (name or "Bow") .. " (manual)"
			end
			local c = self:bowCharge(bow)
			local speed = bow.full * (c * 125 + 95) / 220
			local g = self.bowGravity == false and 0 or bow.gravity * math.clamp(self.bowGravityScale or 1, 0, 2)
			return speed, g, string.format("%s %d%%", name or "Bow", math.floor(c * 100 + 0.5))
		end
		if not self.prediction then
			return nil
		end
		local gun = id and GUNS[id]
		if gun and self.autoBallistics ~= false then
			return gun[1], gun[2] or GAME_GRAVITY, name
		end
		if not gun and not (id and self:looksLikeGun(id)) then
			return nil
		end
		return math.max(self.bulletSpeed or 900, 50), self.bulletGravity or GAME_GRAVITY, (name or "Unknown") .. " (manual)"
	end

	local GUN_WORDS = { "rifle", "smg", "pistol", "shotgun", "revolver", "sniper", "launcher", "carbine", "m249", "scar", "barrel" }
	function Aim:looksLikeGun(id)
		for _, w in ipairs(GUN_WORDS) do
			if string.find(id, w, 1, true) then
				return true
			end
		end
		return false
	end

	function Aim:ballisticsText()
		local speed, g, label = self:ballistics()
		if not speed then
			return "Not a gun or bow - aiming at the bone"
		end
		return string.format("%s  ·  %d st/s  ·  drop %d", tostring(label), math.floor(speed + 0.5), math.floor(g + 0.5))
	end

	-- Velocity as the target is seen moving on this client, smoothed (raw part velocity of other
	-- players is noisy and spikes on replication steps). Teleports and stale samples reset it.
	function Aim:targetVelocity(root)
		local now = os.clock()
		local pos = root.Position
		local st = velTrack[root]
		if not st then
			st = { pos = pos, t = now, vel = root.AssemblyLinearVelocity }
			velTrack[root] = st
			return st.vel, st
		end
		local dt = now - st.t
		if dt >= 1 / 240 then
			local meas = (pos - st.pos) / dt
			if dt > 0.4 or meas.Magnitude > 160 then
				meas = root.AssemblyLinearVelocity
				st.vel = meas
			else
				st.vel = st.vel:Lerp(meas, math.clamp(self.velSmooth or 0.35, 0.05, 1))
			end
			st.pos, st.t = pos, now
		end
		return st.vel, st
	end

	function Aim:predictPos(part, root, camPos)
		if not part then
			return nil
		end
		local pos = part.Position
		if self.instantAim then
			return pos
		end
		local speed, g = self:ballistics()
		if not speed then
			return pos
		end
		local vel, st = Vector3.zero, nil
		local mover = (root and root:IsA("BasePart")) and root or (part:IsA("BasePart") and part or nil)
		if mover then
			vel, st = self:targetVelocity(mover)
		end
		local airborne, grounded = false, false
		if st then
			st.hum = st.hum or (mover.Parent and mover.Parent:FindFirstChildOfClass("Humanoid"))
			if st.hum then
				local state = st.hum:GetState()
				airborne = state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
				grounded = not airborne and st.hum.FloorMaterial ~= Enum.Material.Air
			end
		end
		if grounded then
			vel = Vector3.new(vel.X, 0, vel.Z)
		end
		local lead = 0
		if self.pingComp then
			lead = math.clamp(LOCAL:GetNetworkPing() * 0.5, 0, 0.25)
		end
		local origin = camPos or pos
		local worldG = workspace.Gravity
		local t = (pos - origin).Magnitude / speed
		local aim = pos
		for _ = 1, 5 do
			local tt = t + lead
			aim = pos + vel * tt
			if airborne then
				aim -= Vector3.new(0, 0.5 * worldG * tt * tt, 0)
			end
			t = (aim - origin).Magnitude / speed
		end
		if g > 0 then
			aim += Vector3.new(0, 0.5 * g * t * t, 0)
		end
		return aim
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
		local camPos = cam.CFrame.Position
		local bestPt, bestPart, bestPx = nil, nil, math.huge
		for i = 1, #boneList do
			local part = self:getBonePart(char, boneList[i])
			if part then
				local pt = self:predictPos(part, root, camPos)
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

	function Aim:tryModel(char, cam, fovPx, boneList, maxD2, camPos, look)
		local hum = char:FindFirstChildOfClass("Humanoid")
		local root = char:FindFirstChild("HumanoidRootPart")
		if not hum or not root or hum.Health <= 0 then
			return nil
		end
		local plr = Players:GetPlayerFromCharacter(char)
		if plr == LOCAL then
			return nil
		end
		if not self:passesFilters(plr, hum, char) then
			return nil
		end
		local delta = root.Position - camPos
		local d2 = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
		if d2 > maxD2 then
			return nil
		end
		if delta:Dot(look) < -2 then
			return nil
		end
		local pt, part = self:bestPointOnChar(char, boneList, cam)
		if not pt or not self:isVisible(cam, camPos, pt, char) then
			return nil
		end
		local px = self:screenDistPx(cam, pt)
		if px > fovPx then
			return nil
		end
		return pt, char, part, px
	end

	function Aim:pickTarget(cam, fovPx, boneList, stickyChar, maxDistOverride)
		local camCF = cam.CFrame
		local camPos = camCF.Position
		local look = camCF.LookVector
		local maxD = maxDistOverride or self.maxDist
		local maxD2 = maxD * maxD

		if stickyChar and stickyChar.Parent then
			local pt, ch, part, px = self:tryModel(stickyChar, cam, fovPx * 1.35, boneList, maxD2, camPos, look)
			if pt then
				return pt, ch, part
			end
		end

		local bestPt, bestChar, bestPart, bestPx = nil, nil, nil, fovPx
		local players = Players:GetPlayers()
		for i = 1, #players do
			local char = players[i].Character
			if char then
				local pt, ch, part, px = self:tryModel(char, cam, fovPx, boneList, maxD2, camPos, look)
				if pt and px < bestPx then
					bestPx, bestPt, bestChar, bestPart = px, pt, ch, part
				end
			end
		end

		if self.targetNpcs then
			local npcs = workspace:FindFirstChild("Npcs")
			if npcs then
				for _, model in ipairs(npcs:GetChildren()) do
					if model:GetAttribute("Dead") ~= true then
						local pt, ch, part, px = self:tryModel(model, cam, fovPx, boneList, maxD2, camPos, look)
						if pt and px < bestPx then
							bestPx, bestPt, bestChar, bestPart = px, pt, ch, part
						end
					end
				end
			end
		end

		return bestPt, bestChar, bestPart
	end

	function Aim:cameraSnapToward(cam, worldPos, capDeg)
		local camPos = cam.CFrame.Position
		local look = cam.CFrame.LookVector
		local want = worldPos - camPos
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
		local hardCap = math.min(capDeg or 8, 25)
		local step = math.min(hardCap, ang)
		local t = step / math.max(ang, 0.001)
		cam.CFrame = CFrame.lookAt(camPos, camPos + look:Lerp(want, t).Unit)
		return ang < 0.15
	end

	-- Vault-style: mousemoverel(error / smoothing) each frame.
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
		if type(mousemoverel) ~= "function" then
			return false
		end
		local smooth = math.max(self.smoothing or 2, 1)
		local str = math.clamp(self.mouseDriveStrength or 1, 0.1, 2)
		local mx = (dx / smooth) * str + self.mouseRemX
		local my = (dy / smooth) * str + self.mouseRemY
		local sx = mx >= 0 and math.floor(mx + 0.5) or math.ceil(mx - 0.5)
		local sy = my >= 0 and math.floor(my + 0.5) or math.ceil(my - 0.5)
		local cap = math.max(1, math.floor(self.maxMousePx or 120))
		sx = math.clamp(sx, -cap, cap)
		sy = math.clamp(sy, -cap, cap)
		self.mouseRemX = mx - sx
		self.mouseRemY = my - sy
		if sx == 0 and sy == 0 then
			return dist <= self.deadzonePx * 2
		end
		mousemoverel(sx, sy)
		return true
	end

	function Aim:rotateToward(cam, worldPos, _capDeg)
		if self.useMouseDrive then
			return self:mouseDriveToward(cam, worldPos)
		end
		return self:cameraSnapToward(cam, worldPos, self.lockCapDeg)
	end

	function Aim:fovRadiusPx(_, px)
		return math.clamp(px, 8, 800)
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
		end
		local thick, size, gap = self.crossThick, self.crossSize, self.crossGap
		bar("L", UDim2.fromOffset(size, thick), UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(-(gap + size * 0.5), 0))
		bar("R", UDim2.fromOffset(size, thick), UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(gap + size * 0.5, 0))
		bar("U", UDim2.fromOffset(thick, size), UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(0, -(gap + size * 0.5)))
		bar("D", UDim2.fromOffset(thick, size), UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(0, gap + size * 0.5))

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
				crossParts[i].Visible = showCross
				crossParts[i].BackgroundColor3 = self.crossColor
			end
		end

		local fovShow = self.weaponFovPx
		if self.silentOn and self.silentFovPx > fovShow then
			fovShow = self.silentFovPx
		end
		local diam = math.floor(self:fovRadiusPx(cam, fovShow) * 2 + 0.5)
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

		if not statusLabel or not self.visualCheck then
			if statusLabel and statusLabel.Visible then
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
			"Aim:%s silent:%s tgt:%s",
			self.aimbotEnabled and "on" or "off",
			self.silentOn and "on" or "off",
			pt and (ch and ch.Name or "?") or "none"
		)
		if self.lastHudText ~= text then
			self.lastHudText = text
			statusLabel.Text = text
		end
		statusLabel.Visible = true
	end

	function Aim:runSilentBurst(cam)
		if not self:shouldRunSilent() then
			return
		end
		local bones = self.targetBones
		local maxD = (self.silentMaxDist and self.silentMaxDist > 0) and self.silentMaxDist or self.maxDist
		local pt, ch = self:pickTarget(cam, self.silentFovPx, bones, self.stickyChar, maxD)
		if not pt then
			return
		end
		self.stickyChar = ch
		-- Always drive hard: mouse first, camera fallback so silent works without mousemoverel.
		local ok = false
		if self.useMouseDrive then
			ok = self:mouseDriveToward(cam, pt)
		end
		if not ok then
			self:cameraSnapToward(cam, pt, math.max(self.lockCapDeg or 12, 18))
		end
	end

	function Aim:tryTriggerbot(cam, dt)
		if not self.triggerEnabled or not self:triggerHeld() then
			self.triggerAcc = 0
			return
		end
		self.triggerAcc += dt
		if self.triggerAcc < (self.triggerDelayMs or 10) / 1000 then
			return
		end
		local pt = self:pickTarget(cam, self.deadzonePx + 4, self.triggerBones, self.stickyChar)
		if not pt then
			return
		end
		local now = os.clock()
		if now - self.lastTrigger < 0.05 then
			return
		end
		self.lastTrigger = now
		self.triggerAcc = 0
		if type(mouse1click) == "function" then
			mouse1click()
		elseif type(mouse1press) == "function" then
			mouse1press()
			task.defer(function()
				if type(mouse1release) == "function" then
					mouse1release()
				end
			end)
		else
			pcall(function()
				local vim = game:GetService("VirtualInputManager")
				vim:SendMouseButtonEvent(0, 0, 0, true, game, 0)
				vim:SendMouseButtonEvent(0, 0, 0, false, game, 0)
			end)
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
		if self.drawFov or self.filledFov or self.showCrosshair or self.visualCheck then
			self:ensureCrosshair()
		end

		RunService:BindToRenderStep(AIM_RENDER, Enum.RenderPriority.Camera.Value + 5, function(dt)
			local cam = workspace.CurrentCamera
			if not cam then
				return
			end
			self:updateVisuals(cam, dt)

			local ran = false
			-- Silent first so it wins the frame when both are on.
			if self:shouldRunSilent() then
				self:runSilentBurst(cam)
				ran = true
			elseif self:shouldRunAimbot() then
				local pt, ch = self:pickTarget(cam, self.weaponFovPx, self.targetBones, self.stickyChar)
				if pt then
					self.stickyChar = ch
					local ok = self:rotateToward(cam, pt, self.lockCapDeg)
					if not ok then
						self:cameraSnapToward(cam, pt, self.lockCapDeg)
					end
					ran = true
				end
			end
			if not ran and not self:aimKeysHeld() and not self:shouldRunSilent() then
				self.stickyChar = nil
			end
			self:tryTriggerbot(cam, dt)
		end)
	end

	function Aim:unbind()
		pcall(function()
			RunService:UnbindFromRenderStep(AIM_RENDER)
		end)
		self.bound = false
		self.stickyChar = nil
		self.firingSilent = false
		self.silentUntil = 0
		self.triggerAcc = 0
		self.assistAcc = 0
		self.mouseRemX = 0
		self.mouseRemY = 0
	end

	function Aim:destroy()
		self.aimbotEnabled = false
		self.silentOn = false
		self.triggerEnabled = false
		self.lockAssist = false
		self.aimKey1Held = false
		self.aimKey2Held = false
		self.triggerKeyHeld = false
		self:unbind()
		self:destroyCrosshair()
	end

	return Aim
end
