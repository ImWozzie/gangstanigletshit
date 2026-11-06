-- World ESP (PlayerGui) + camera helpers. factory(deps) -> World
-- No Lighting paints (ACM MotionSync lt). No Drawing API.
return function(deps)
	local Players = deps.Players
	local RunService = deps.RunService
	local UserInputService = deps.UserInputService
	local LOCAL = deps.LocalPlayer
	local Workspace = game:GetService("Workspace")

	local OVERLAY_NAME = "FustWorldEsp"
	local MAX_LABELS = 120
	local SCAN_TICK = 0.45

	local World = {
		espEnabled = false,
		rate = 15,
		maxDist = 600,
		fontsize = 12,
		color = Color3.fromRGB(220, 220, 220),

		-- all off until configured; master alone draws nothing
		toggles = {
			trees = false,
			stone = false,
			metal = false,
			sulfur = false,
			hemp = false,
			food = false,
			mushroom = false,
			woodpile = false,
			loot_barrel = false,
			loot_crate = false,
			military_crate = false,
			elite_crate = false,
			wooden_box = false,
			large_box = false,
			airdrop = false,
			sleeper = false,
			npc = false,
			bear = false,
			boar = false,
			deer = false,
			atv = false,
			minicopter = false,
			auto_turret = false,
			shotgun_trap = false,
			landmine = false,
			backpack = false,
			world_item = false,
			patrol_heli = false,
			tool_cupboard = false,
		},

		zoomHeld = false,
		zoomFov = 20,
		_origFov = nil,

		freecamOn = false,
		freecamSpeed = 1.2,
		_fcConn = nil,
		_fcPos = nil,

		tp3On = false,
		tp3Dist = 10,
		tp3Height = 2.5,
		_tp3Conn = nil,
		_tp3Yaw = 0,
		_tp3Pitch = 0,
	}

	local overlay
	local labels = {} -- pooled TextLabels
	local index = {} -- { kind, inst, part, text }
	local indexList = {}
	local folderConns = {}
	local heartbeatConn
	local scanAcc, renderAcc = 0, 0
	local cam = Workspace.CurrentCamera

	local function ensureGui()
		local pg = LOCAL:FindFirstChildOfClass("PlayerGui")
		if not pg then
			return nil
		end
		local gui = pg:FindFirstChild(OVERLAY_NAME)
		if gui then
			overlay = gui
			return gui
		end
		gui = Instance.new("ScreenGui")
		gui.Name = OVERLAY_NAME
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 25
		gui:SetAttribute("FustBaseEsp", true)
		gui.Parent = pg
		overlay = gui
		return gui
	end

	local function getLabel(i)
		local r = labels[i]
		if r then
			return r
		end
		ensureGui()
		if not overlay then
			return nil
		end
		local t = Instance.new("TextLabel")
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.BackgroundTransparency = 1
		t.TextStrokeTransparency = 0.4
		t.TextStrokeColor3 = Color3.new(0, 0, 0)
		t.Font = Enum.Font.GothamMedium
		t.TextSize = World.fontsize
		t.Visible = false
		t.ZIndex = 5
		t.Parent = overlay
		r = { f = t, vis = false, text = "", x = 0, y = 0 }
		labels[i] = r
		return r
	end

	local function setLabel(r, x, y, text, color, size)
		if not r then
			return
		end
		if r.text ~= text then
			r.text = text
			r.f.Text = text
		end
		if r.col ~= color then
			r.col = color
			r.f.TextColor3 = color
		end
		if r.sz ~= size then
			r.sz = size
			r.f.TextSize = size
		end
		if r.x == nil or math.abs(r.x - x) > 0.5 or math.abs(r.y - y) > 0.5 then
			r.x, r.y = x, y
			r.f.Position = UDim2.fromOffset(x, y)
		end
		if not r.vis then
			r.vis = true
			r.f.Visible = true
		end
	end

	local function hideLabel(r)
		if r and r.vis then
			r.vis = false
			r.f.Visible = false
		end
	end

	local function hideAllLabels()
		for i = 1, #labels do
			hideLabel(labels[i])
		end
	end

	local function rootPart(model)
		if not model then
			return nil
		end
		if model:IsA("BasePart") then
			return model
		end
		return model:FindFirstChild("HumanoidRootPart")
			or model.PrimaryPart
			or model:FindFirstChildWhichIsA("BasePart", true)
	end

	local function addIndexed(kind, inst, labelText)
		if index[inst] then
			index[inst].text = labelText
			return
		end
		local part = rootPart(inst)
		if not part then
			return
		end
		local row = { kind = kind, inst = inst, part = part, text = labelText }
		index[inst] = row
		indexList[#indexList + 1] = row
	end

	local function removeIndexed(inst)
		local row = index[inst]
		if not row then
			return
		end
		index[inst] = nil
		for i = #indexList, 1, -1 do
			if indexList[i] == row or indexList[i].inst == inst then
				table.remove(indexList, i)
				break
			end
		end
	end

	local KIND_COLOR = {
		trees = Color3.fromRGB(90, 190, 90),
		stone = Color3.fromRGB(170, 170, 170),
		metal = Color3.fromRGB(140, 180, 220),
		sulfur = Color3.fromRGB(230, 210, 80),
		hemp = Color3.fromRGB(120, 200, 100),
		food = Color3.fromRGB(255, 160, 80),
		mushroom = Color3.fromRGB(200, 120, 220),
		woodpile = Color3.fromRGB(160, 120, 70),
		loot_barrel = Color3.fromRGB(255, 100, 80),
		loot_crate = Color3.fromRGB(220, 180, 100),
		military_crate = Color3.fromRGB(80, 200, 120),
		elite_crate = Color3.fromRGB(255, 80, 180),
		wooden_box = Color3.fromRGB(190, 150, 90),
		large_box = Color3.fromRGB(200, 160, 100),
		airdrop = Color3.fromRGB(255, 220, 60),
		sleeper = Color3.fromRGB(180, 180, 255),
		npc = Color3.fromRGB(255, 90, 90),
		bear = Color3.fromRGB(255, 60, 40),
		boar = Color3.fromRGB(200, 140, 90),
		deer = Color3.fromRGB(210, 180, 120),
		atv = Color3.fromRGB(100, 200, 255),
		minicopter = Color3.fromRGB(100, 220, 255),
		auto_turret = Color3.fromRGB(255, 50, 50),
		shotgun_trap = Color3.fromRGB(255, 120, 40),
		landmine = Color3.fromRGB(255, 40, 40),
		backpack = Color3.fromRGB(200, 200, 100),
		world_item = Color3.fromRGB(200, 200, 200),
		patrol_heli = Color3.fromRGB(255, 80, 80),
		tool_cupboard = Color3.fromRGB(160, 200, 255),
	}

	local function nodeKind(model)
		local nt = model:GetAttribute("NodeType") or model.Name
		if typeof(nt) ~= "string" then
			nt = model.Name
		end
		nt = string.lower(nt)
		if string.find(nt, "tree", 1, true) or string.find(nt, "cactus", 1, true) then
			return "trees"
		end
		if string.find(nt, "sulfur", 1, true) then
			return "sulfur"
		end
		if string.find(nt, "metal", 1, true) then
			return "metal"
		end
		if string.find(nt, "stone", 1, true) or string.find(nt, "rock", 1, true) then
			return "stone"
		end
		return nil
	end

	local function pickupKind(model)
		local pt = model:GetAttribute("PickupType") or model.Name
		if typeof(pt) ~= "string" then
			pt = model.Name
		end
		pt = string.lower(pt)
		if string.find(pt, "hemp", 1, true) then
			return "hemp"
		end
		if string.find(pt, "mushroom", 1, true) then
			return "mushroom"
		end
		if string.find(pt, "wood", 1, true) then
			return "woodpile"
		end
		if string.find(pt, "berry", 1, true)
			or string.find(pt, "corn", 1, true)
			or string.find(pt, "pumpkin", 1, true)
			or string.find(pt, "potato", 1, true)
			or string.find(pt, "carrot", 1, true)
			or string.find(pt, "apple", 1, true)
		then
			return "food"
		end
		if string.find(pt, "stone", 1, true) then
			return "stone"
		end
		if string.find(pt, "metal", 1, true) then
			return "metal"
		end
		if string.find(pt, "sulfur", 1, true) then
			return "sulfur"
		end
		return nil
	end

	local function lootKind(model)
		local n = string.lower(model.Name)
		local kind = model:GetAttribute("CrateKind")
		if typeof(kind) == "string" then
			kind = string.lower(kind)
			if kind == "military" then
				return "military_crate"
			end
			if kind == "elite" then
				return "elite_crate"
			end
			if kind == "wooden" then
				return "loot_crate"
			end
		end
		if string.find(n, "barrel", 1, true) then
			return "loot_barrel"
		end
		if string.find(n, "military", 1, true) then
			return "military_crate"
		end
		if string.find(n, "elite", 1, true) then
			return "elite_crate"
		end
		if string.find(n, "crate", 1, true) then
			return "loot_crate"
		end
		return "loot_crate"
	end

	local function animalKind(model)
		local sp = model:GetAttribute("Species") or model.Name
		if typeof(sp) ~= "string" then
			sp = model.Name
		end
		sp = string.lower(sp)
		if string.find(sp, "bear", 1, true) then
			return "bear"
		end
		if string.find(sp, "boar", 1, true) then
			return "boar"
		end
		if string.find(sp, "deer", 1, true) then
			return "deer"
		end
		return nil
	end

	local function deployKind(model)
		local kind = model:GetAttribute("Kind") or model.Name
		if typeof(kind) ~= "string" then
			kind = model.Name
		end
		kind = string.lower(kind)
		if string.find(kind, "turret", 1, true) then
			return "auto_turret"
		end
		if string.find(kind, "shotgun", 1, true) or string.find(kind, "trap", 1, true) then
			return "shotgun_trap"
		end
		if string.find(kind, "landmine", 1, true) or string.find(kind, "mine", 1, true) then
			return "landmine"
		end
		if string.find(kind, "backpack", 1, true) then
			return "backpack"
		end
		if string.find(kind, "cupboard", 1, true) or string.find(kind, "tool_cupboard", 1, true) or string.find(kind, "tc", 1, true) then
			return "tool_cupboard"
		end
		if string.find(kind, "box", 1, true) then
			if string.find(kind, "large", 1, true) then
				return "large_box"
			end
			return "wooden_box"
		end
		return nil
	end

	local function labelFor(kind, inst)
		if kind == "sleeper" then
			local name = inst:GetAttribute("SleeperName") or inst.Name
			return tostring(name)
		end
		if kind == "npc" then
			local w = inst:GetAttribute("Weapon")
			local st = inst:GetAttribute("State")
			local bits = { "NPC" }
			if w then
				bits[#bits + 1] = tostring(w)
			end
			if st then
				bits[#bits + 1] = tostring(st)
			end
			return table.concat(bits, " · ")
		end
		if kind == "auto_turret" then
			local powered = inst:GetAttribute("Powered") or inst:GetAttribute("PowerOn")
			return powered and "Turret ON" or "Turret"
		end
		if kind == "atv" or kind == "minicopter" then
			local fuel = inst:GetAttribute("Fuel")
			local hp = inst:GetAttribute("Health") or inst:GetAttribute("Hp")
			local bits = { kind == "atv" and "ATV" or "Minicopter" }
			if fuel ~= nil then
				bits[#bits + 1] = "F" .. tostring(math.floor(tonumber(fuel) or 0))
			end
			if hp ~= nil then
				bits[#bits + 1] = "HP" .. tostring(math.floor(tonumber(hp) or 0))
			end
			return table.concat(bits, " ")
		end
		local pretty = kind:gsub("_", " ")
		return pretty:gsub("^%l", string.upper)
	end

	local function watchFolder(folder, classify)
		if not folder then
			return
		end
		local function consider(child)
			local kind, text = classify(child)
			if kind and World.toggles[kind] ~= false then
				addIndexed(kind, child, text or labelFor(kind, child))
			end
		end
		for _, child in ipairs(folder:GetChildren()) do
			consider(child)
		end
		folderConns[#folderConns + 1] = folder.ChildAdded:Connect(function(child)
			task.defer(consider, child)
		end)
		folderConns[#folderConns + 1] = folder.ChildRemoved:Connect(function(child)
			removeIndexed(child)
		end)
	end

	local function rebuildIndex()
		table.clear(index)
		table.clear(indexList)
		for _, c in ipairs(folderConns) do
			c:Disconnect()
		end
		table.clear(folderConns)

		watchFolder(Workspace:FindFirstChild("Nodes"), function(m)
			local k = nodeKind(m)
			if k then
				return k, labelFor(k, m)
			end
		end)
		watchFolder(Workspace:FindFirstChild("Pickups"), function(m)
			local k = pickupKind(m)
			if k then
				return k, labelFor(k, m)
			end
		end)
		watchFolder(Workspace:FindFirstChild("Loot"), function(m)
			if m:GetAttribute("Open") == true then
				return nil
			end
			local k = lootKind(m)
			return k, labelFor(k, m)
		end)
		watchFolder(Workspace:FindFirstChild("Sleepers"), function(m)
			return "sleeper", labelFor("sleeper", m)
		end)
		watchFolder(Workspace:FindFirstChild("Npcs"), function(m)
			if m:GetAttribute("Dead") == true then
				return nil
			end
			return "npc", labelFor("npc", m)
		end)
		watchFolder(Workspace:FindFirstChild("Animals"), function(m)
			local k = animalKind(m)
			if k then
				return k, labelFor(k, m)
			end
		end)
		watchFolder(Workspace:FindFirstChild("Deployables"), function(m)
			local k = deployKind(m)
			if k then
				return k, labelFor(k, m)
			end
		end)
		watchFolder(Workspace:FindFirstChild("WorldItems"), function(m)
			return "world_item", m.Name
		end)
		watchFolder(Workspace:FindFirstChild("FustAtvs"), function(m)
			return "atv", labelFor("atv", m)
		end)
		watchFolder(Workspace:FindFirstChild("FustMinicopters"), function(m)
			return "minicopter", labelFor("minicopter", m)
		end)
		watchFolder(Workspace:FindFirstChild("Airdrops"), function(m)
			return "airdrop", "Airdrop"
		end)
		watchFolder(Workspace:FindFirstChild("FustPatrolHeli"), function(m)
			return "patrol_heli", "Patrol Heli"
		end)
	end

	local function originPos()
		local char = LOCAL.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			return hrp.Position
		end
		cam = Workspace.CurrentCamera
		return cam and cam.CFrame.Position
	end

	local function render()
		if not World.espEnabled then
			hideAllLabels()
			return
		end
		ensureGui()
		cam = Workspace.CurrentCamera
		local origin = originPos()
		if not cam or not origin then
			hideAllLabels()
			return
		end
		local maxD = World.maxDist
		local maxD2 = maxD * maxD
		local drawn = 0
		local candidates = {}

		for i = 1, #indexList do
			local row = indexList[i]
			local inst = row.inst
			if not inst or not inst.Parent then
				-- stale; skip (rebuild will clean)
			elseif World.toggles[row.kind] == false then
				-- off
			else
				local part = row.part
				if part and part.Parent then
					local pos = part.Position
					local d = pos - origin
					local d2 = d.X * d.X + d.Y * d.Y + d.Z * d.Z
					if d2 <= maxD2 then
						candidates[#candidates + 1] = { row = row, d2 = d2, pos = pos }
					end
				end
			end
		end

		table.sort(candidates, function(a, b)
			return a.d2 < b.d2
		end)

		for i = 1, math.min(#candidates, MAX_LABELS) do
			local c = candidates[i]
			local vp, on = cam:WorldToViewportPoint(c.pos)
			if on and vp.Z > 0 then
				drawn += 1
				local dist = math.sqrt(c.d2)
				local text = string.format("%s [%dm]", c.row.text, math.floor(dist + 0.5))
				local col = KIND_COLOR[c.row.kind] or World.color
				setLabel(getLabel(drawn), vp.X, vp.Y, text, col, World.fontsize)
			end
		end
		for i = drawn + 1, #labels do
			hideLabel(labels[i])
		end
	end

	local function stopLoop()
		if heartbeatConn then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
		hideAllLabels()
	end

	local function startLoop()
		if heartbeatConn then
			return
		end
		scanAcc, renderAcc = 0, 0
		heartbeatConn = RunService.Heartbeat:Connect(function(dt)
			if not World.espEnabled then
				stopLoop()
				return
			end
			scanAcc += dt
			renderAcc += dt
			if scanAcc >= SCAN_TICK then
				scanAcc = 0
				-- refresh part refs that went missing
				for i = #indexList, 1, -1 do
					local row = indexList[i]
					if not row.inst or not row.inst.Parent then
						index[row.inst] = nil
						table.remove(indexList, i)
					elseif not row.part or not row.part.Parent then
						row.part = rootPart(row.inst)
					end
				end
			end
			local hz = math.clamp(World.rate, 5, 60)
			if renderAcc >= 1 / hz then
				renderAcc = 0
				render()
			end
		end)
	end

	function World:setEsp(on)
		self.espEnabled = on and true or false
		if self.espEnabled then
			ensureGui()
			rebuildIndex()
			startLoop()
		else
			stopLoop()
		end
	end

	function World:setToggle(kind, on)
		if self.toggles[kind] ~= nil then
			self.toggles[kind] = on and true or false
		end
	end

	function World:sync()
		self:syncZoom()
		self:syncFreecam()
		self:syncTp3()
	end

	function World:syncZoom()
		cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		if self.zoomHeld then
			if not self._origFov then
				self._origFov = cam.FieldOfView
			end
			cam.FieldOfView = self.zoomFov
		elseif self._origFov then
			cam.FieldOfView = self._origFov
			self._origFov = nil
		end
	end

	function World:syncFreecam()
		if self._fcConn then
			self._fcConn:Disconnect()
			self._fcConn = nil
		end
		if not self.freecamOn then
			return
		end
		-- Risky vs MotionSync {tp,cm} — camera-only fly, no character move.
		cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		self._fcPos = cam.CFrame
		self._fcConn = RunService.RenderStepped:Connect(function(dt)
			if not self.freecamOn then
				return
			end
			cam = Workspace.CurrentCamera
			if not cam then
				return
			end
			local speed = 40 * self.freecamSpeed
			local move = Vector3.zero
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then
				move += cam.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then
				move -= cam.CFrame.LookVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then
				move -= cam.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then
				move += cam.CFrame.RightVector
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.E) then
				move += Vector3.yAxis
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
				move -= Vector3.yAxis
			end
			if move.Magnitude > 0 then
				self._fcPos = self._fcPos + move.Unit * speed * dt
			end
			local look = cam.CFrame.LookVector
			cam.CFrame = CFrame.new(self._fcPos.Position, self._fcPos.Position + look)
		end)
	end

	function World:syncTp3()
		if self._tp3Conn then
			self._tp3Conn:Disconnect()
			self._tp3Conn = nil
		end
		if not self.tp3On then
			return
		end
		-- Risky: FustFirstPerson MotionSync {tp,cm} if CameraSubject wrong >3.5s.
		self._tp3Conn = RunService.RenderStepped:Connect(function()
			if not self.tp3On then
				return
			end
			local char = LOCAL.Character
			local head = char and char:FindFirstChild("Head")
			cam = Workspace.CurrentCamera
			if not head or not cam then
				return
			end
			local look = cam.CFrame.LookVector
			local flat = Vector3.new(look.X, 0, look.Z)
			if flat.Magnitude < 0.05 then
				flat = Vector3.new(0, 0, -1)
			else
				flat = flat.Unit
			end
			local back = -flat * self.tp3Dist + Vector3.new(0, self.tp3Height, 0)
			local pos = head.Position + back
			cam.CFrame = CFrame.new(pos, head.Position)
		end)
	end

	function World:destroy()
		self.espEnabled = false
		self.freecamOn = false
		self.tp3On = false
		self.zoomHeld = false
		stopLoop()
		if self._fcConn then
			self._fcConn:Disconnect()
			self._fcConn = nil
		end
		if self._tp3Conn then
			self._tp3Conn:Disconnect()
			self._tp3Conn = nil
		end
		for _, c in ipairs(folderConns) do
			c:Disconnect()
		end
		table.clear(folderConns)
		table.clear(index)
		table.clear(indexList)
		if overlay then
			overlay:Destroy()
			overlay = nil
		end
		table.clear(labels)
		self:syncZoom()
	end

	return World
end
