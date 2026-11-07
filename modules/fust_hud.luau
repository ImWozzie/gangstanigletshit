-- HUD module: radar + staff detector. factory(deps) -> Hud
-- PlayerGui frames only (no Drawing), nothing on other characters, no camera / Lighting writes.
return function(deps)
	local Players = deps.Players
	local RunService = deps.RunService
	local LOCAL = deps.LocalPlayer

	local OVERLAY_NAME = "FustHud"
	local MAX_DOTS = 48
	local RADAR_TICK = 0.1

	local Hud = {
		radar = false,
		radarSize = 140,
		radarRange = 300,
		radarOffsetX = 0,
		radarOffsetY = 125,
		radarRotate = true,
		radarEdge = true,
		radarNpcs = false,
		enemyColor = Color3.fromRGB(255, 90, 90),
		allyColor = Color3.fromRGB(110, 180, 255),
		npcColor = Color3.fromRGB(255, 170, 60),

		staff = false,
		staffMinRank = 200,
		staffExtra = "",
		onStaff = nil, -- function(player, why) set by the shell
	}

	local overlay, radarFrame, centerDot, ring
	local dots = {}
	local heartbeatConn
	local acc = 0
	local friendCache = {}
	local staffConn
	local staffSeen = {}
	Hud.staffFound = {}

	local function newRec(f)
		return { f = f, vis = false }
	end

	local function setVis(r, v)
		if r.vis ~= v then
			r.vis = v
			r.f.Visible = v
		end
	end

	local function setPos(r, x, y)
		if r.x == nil or math.abs(r.x - x) > 0.3 or math.abs(r.y - y) > 0.3 then
			r.x, r.y = x, y
			r.f.Position = UDim2.fromOffset(x, y)
		end
	end

	local function setColor(r, c)
		if r.col ~= c then
			r.col = c
			r.f.BackgroundColor3 = c
		end
	end

	local function round(f, radius)
		local c = Instance.new("UICorner")
		c.CornerRadius = radius or UDim.new(1, 0)
		c.Parent = f
	end

	local function ensureGui()
		if overlay and overlay.Parent then
			return
		end
		local pg = LOCAL:FindFirstChild("PlayerGui")
		if not pg then
			return
		end
		overlay = Instance.new("ScreenGui")
		overlay.Name = OVERLAY_NAME
		overlay.ResetOnSpawn = false
		overlay.IgnoreGuiInset = true
		overlay.DisplayOrder = 210
		overlay:SetAttribute("FustBaseEsp", true)
		overlay.Parent = pg

		radarFrame = Instance.new("Frame")
		radarFrame.AnchorPoint = Vector2.new(1, 0)
		radarFrame.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
		radarFrame.BackgroundTransparency = 0.35
		radarFrame.BorderSizePixel = 0
		radarFrame.ClipsDescendants = false
		radarFrame.Visible = false
		radarFrame.Parent = overlay
		round(radarFrame)
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Transparency = 0.8
		stroke.Thickness = 1
		stroke.Parent = radarFrame

		ring = Instance.new("Frame")
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.5)
		ring.Size = UDim2.fromScale(0.5, 0.5)
		ring.BackgroundTransparency = 1
		ring.Parent = radarFrame
		round(ring)
		local rs = Instance.new("UIStroke")
		rs.Color = Color3.fromRGB(255, 255, 255)
		rs.Transparency = 0.9
		rs.Parent = ring

		centerDot = Instance.new("Frame")
		centerDot.AnchorPoint = Vector2.new(0.5, 0.5)
		centerDot.Position = UDim2.fromScale(0.5, 0.5)
		centerDot.Size = UDim2.fromOffset(6, 6)
		centerDot.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		centerDot.BorderSizePixel = 0
		centerDot.ZIndex = 3
		centerDot.Parent = radarFrame
		round(centerDot)
	end

	local function getDot(i)
		local r = dots[i]
		if r then
			return r
		end
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Size = UDim2.fromOffset(5, 5)
		f.BorderSizePixel = 0
		f.Visible = false
		f.ZIndex = 2
		f.Parent = radarFrame
		round(f)
		r = newRec(f)
		dots[i] = r
		return r
	end

	local function hideDots(from)
		for i = from or 1, #dots do
			setVis(dots[i], false)
		end
	end

	local function isAlly(plr)
		local v = friendCache[plr.UserId]
		if v == nil then
			friendCache[plr.UserId] = false
			task.spawn(function()
				local ok, res = pcall(LOCAL.IsFriendsWith, LOCAL, plr.UserId)
				friendCache[plr.UserId] = ok and res == true
			end)
			return false
		end
		return v
	end

	local function layoutRadar()
		local size = Hud.radarSize
		radarFrame.Size = UDim2.fromOffset(size, size)
		radarFrame.Position = UDim2.new(1, -12 - Hud.radarOffsetX, 0, Hud.radarOffsetY)
	end

	local function drawRadar()
		ensureGui()
		if not radarFrame then
			return
		end
		if radarFrame.Size.X.Offset ~= Hud.radarSize
			or radarFrame.Position.Y.Offset ~= Hud.radarOffsetY
			or radarFrame.Position.X.Offset ~= -12 - Hud.radarOffsetX then
			layoutRadar()
		end
		radarFrame.Visible = true
		local myRoot = LOCAL.Character and LOCAL.Character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		if not (myRoot and camera) then
			hideDots()
			return
		end
		local me = myRoot.Position
		local half = Hud.radarSize * 0.5
		local scale = (half - 4) / math.max(Hud.radarRange, 1)
		local yaw = 0
		if Hud.radarRotate then
			local look = camera.CFrame.LookVector
			yaw = math.atan2(look.X, look.Z)
		end
		local cosY, sinY = math.cos(yaw), math.sin(yaw)
		local used = 0

		local function plot(pos, color)
			if used >= MAX_DOTS then
				return
			end
			local dx, dz = pos.X - me.X, pos.Z - me.Z
			-- rotate so the camera's facing direction points up
			local rx = dx * cosY - dz * sinY
			local rz = dx * sinY + dz * cosY
			local px, py = -rx * scale, -rz * scale
			local len = math.sqrt(px * px + py * py)
			local limit = half - 4
			if len > limit then
				if not Hud.radarEdge then
					return
				end
				px, py = px / len * limit, py / len * limit
			end
			used += 1
			local r = getDot(used)
			setColor(r, color)
			setPos(r, half + px, half + py)
			setVis(r, true)
		end

		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LOCAL then
				local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if root then
					plot(root.Position, isAlly(plr) and Hud.allyColor or Hud.enemyColor)
				end
			end
		end
		if Hud.radarNpcs then
			local folder = workspace:FindFirstChild("Npcs")
			for _, m in ipairs(folder and folder:GetChildren() or {}) do
				local root = m:IsA("Model") and m:GetAttribute("Dead") ~= true and m:FindFirstChild("HumanoidRootPart")
				if root then
					plot(root.Position, Hud.npcColor)
				end
			end
		end
		hideDots(used + 1)
	end

	local function stopLoop()
		if heartbeatConn then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
	end

	local function startLoop()
		if heartbeatConn then
			return
		end
		acc = RADAR_TICK
		heartbeatConn = RunService.Heartbeat:Connect(function(dt)
			if not Hud.radar then
				if radarFrame then
					radarFrame.Visible = false
				end
				stopLoop()
				return
			end
			acc += dt
			if acc >= RADAR_TICK then
				acc = 0
				drawRadar()
			end
		end)
	end

	function Hud:setRadar(on)
		self.radar = on and true or false
		if self.radar then
			ensureGui()
			startLoop()
		elseif radarFrame then
			radarFrame.Visible = false
		end
	end

	-- Staff detector ----------------------------------------------------------------
	local STAFF_WORDS = { "admin", "mod", "staff", "dev", "owner", "manager", "founder", "helper" }

	local function extraNames()
		local set = {}
		for name in tostring(Hud.staffExtra or ""):gmatch("[^,%s]+") do
			set[name:lower()] = true
		end
		return set
	end

	local function report(plr, why)
		if Hud.staffFound[plr.Name] then
			return
		end
		Hud.staffFound[plr.Name] = why
		if Hud.onStaff then
			pcall(Hud.onStaff, plr, why)
		end
	end

	local function checkPlayer(plr)
		if plr == LOCAL or not Hud.staff then
			return
		end
		if extraNames()[plr.Name:lower()] then
			report(plr, "on your extra names list")
			return
		end
		if staffSeen[plr.UserId] then
			return
		end
		staffSeen[plr.UserId] = true
		if game.CreatorType ~= Enum.CreatorType.Group then
			return
		end
		task.spawn(function()
			local okR, rank = pcall(plr.GetRankInGroup, plr, game.CreatorId)
			if not okR or type(rank) ~= "number" or rank <= 0 then
				return
			end
			local okN, role = pcall(plr.GetRoleInGroup, plr, game.CreatorId)
			role = okN and tostring(role) or ""
			local lower = role:lower()
			local wordHit = false
			for _, w in ipairs(STAFF_WORDS) do
				if lower:find(w, 1, true) then
					wordHit = true
					break
				end
			end
			if (rank >= Hud.staffMinRank or wordHit) and Hud.staff and plr.Parent then
				report(plr, string.format("%s (rank %d)", role ~= "" and role or "group member", rank))
			end
		end)
	end

	function Hud:scanStaff()
		table.clear(staffSeen)
		table.clear(self.staffFound)
		for _, plr in ipairs(Players:GetPlayers()) do
			checkPlayer(plr)
		end
	end

	function Hud:setStaff(on)
		self.staff = on and true or false
		if self.staff then
			if not staffConn then
				staffConn = Players.PlayerAdded:Connect(checkPlayer)
			end
			self:scanStaff()
		elseif staffConn then
			staffConn:Disconnect()
			staffConn = nil
		end
	end

	function Hud:cleanupBeforeLoad()
		local pg = LOCAL:FindFirstChild("PlayerGui")
		local old = pg and pg:FindFirstChild(OVERLAY_NAME)
		if old then
			old:Destroy()
		end
	end

	function Hud:destroy()
		self.radar = false
		self.staff = false
		stopLoop()
		if staffConn then
			staffConn:Disconnect()
			staffConn = nil
		end
		if overlay then
			overlay:Destroy()
		end
		overlay, radarFrame, centerDot, ring = nil, nil, nil, nil
		table.clear(dots)
	end

	return Hud
end
