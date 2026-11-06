-- Farming helpers (camera + VirtualInput only). factory(deps) -> Misc
-- Auto weak-spot: aim at Node WeakSpot Vector3 and click so FustGather's own
-- Swing path registers a weak hit (Magnitude <= 2). Does not FireServer Swing.
return function(deps)
	local Players = deps.Players
	local RunService = deps.RunService
	local CollectionService = game:GetService("CollectionService")
	local LOCAL = deps.LocalPlayer
	local workspace = workspace

	local Misc = {
		autoWeak = false,
		primeFresh = false, -- one swing at undamaged nodes to spawn a WeakSpot
		maxDist = 8.5,
		aimDeadzonePx = 18,
		aimCapDeg = 4.5, -- never instant lookAt — FustLook→LookPitch samples pitch ~10Hz
		swingCdMs = 420,
		requireTool = true,
		nodeTypes = { "tree", "stone", "metal", "sulfur" }, -- empty = all
		bound = false,
		lastSwing = 0,
		stickyNode = nil,
		mouseRemX = 0,
		mouseRemY = 0,
	}

	local typeSet = {}
	local heartbeatConn

	local function rebuildTypeSet()
		table.clear(typeSet)
		local list = Misc.nodeTypes
		if type(list) ~= "table" or #list == 0 then
			return
		end
		for i = 1, #list do
			typeSet[list[i]] = true
		end
	end
	rebuildTypeSet()

	local function hasGatherTool()
		local char = LOCAL.Character
		if not char then
			return false
		end
		local tool = char:FindFirstChildOfClass("Tool")
		return tool ~= nil
	end

	local function typeAllowed(node)
		if not next(typeSet) then
			return true
		end
		local nt = node:GetAttribute("NodeType")
		return type(nt) == "string" and typeSet[nt] == true
	end

	local function nodeAlive(node)
		if not node or not node.Parent then
			return false
		end
		local hp = node:GetAttribute("Hp")
		if type(hp) == "number" and hp <= 0 then
			return false
		end
		return CollectionService:HasTag(node, "FustNode") or node:GetAttribute("NodeType") ~= nil
	end

	local function nodeAnchor(node)
		return node.PrimaryPart or node:FindFirstChildWhichIsA("BasePart", true)
	end

	local function screenPx(cam, worldPos)
		local sp, on = cam:WorldToViewportPoint(worldPos)
		if not on or sp.Z <= 0 then
			return math.huge
		end
		local vs = cam.ViewportSize
		local dx, dy = sp.X - vs.X * 0.5, sp.Y - vs.Y * 0.5
		return math.sqrt(dx * dx + dy * dy)
	end

	local function clickOnce(cam)
		local vs = cam.ViewportSize
		local cx, cy = vs.X * 0.5, vs.Y * 0.5
		pcall(function()
			local vim = game:GetService("VirtualInputManager")
			vim:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
			task.defer(function()
				vim:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
			end)
		end)
	end

	-- Gradual aim only. Instant CFrame.lookAt jumps LookVector.Y between FustLook
	-- samples (LookPitch every ≥0.1s) and is the likely Multihack path for gather.
	local function aimAt(cam, worldPos)
		local px = screenPx(cam, worldPos)
		if px <= Misc.aimDeadzonePx then
			return true
		end
		local sp, on = cam:WorldToViewportPoint(worldPos)
		if not on or sp.Z <= 0 then
			return false
		end
		local vs = cam.ViewportSize
		local cx, cy = vs.X * 0.5, vs.Y * 0.5
		local dx, dy = sp.X - cx, sp.Y - cy
		-- Prefer mouse deltas so FustPad/Look see human input; fall back to capped CFrame.
		if type(mousemoverel) == "function" then
			local factor = 0.28
			local mx = dx * factor + Misc.mouseRemX
			local my = dy * factor + Misc.mouseRemY
			local sx = mx >= 0 and math.floor(mx) or math.ceil(mx)
			local sy = my >= 0 and math.floor(my) or math.ceil(my)
			if sx == 0 and math.abs(dx) > Misc.aimDeadzonePx * 0.4 then
				sx = dx > 0 and 1 or -1
			end
			if sy == 0 and math.abs(dy) > Misc.aimDeadzonePx * 0.4 then
				sy = dy > 0 and 1 or -1
			end
			Misc.mouseRemX = math.clamp(mx - sx, -1, 1)
			Misc.mouseRemY = math.clamp(my - sy, -1, 1)
			if sx ~= 0 or sy ~= 0 then
				mousemoverel(sx, sy)
			end
		else
			local pos = cam.CFrame.Position
			local look = cam.CFrame.LookVector
			local want = (worldPos - pos)
			if want.Magnitude < 0.05 then
				return true
			end
			want = want.Unit
			local ang = math.deg(math.acos(math.clamp(look:Dot(want), -1, 1)))
			local cap = Misc.aimCapDeg
			local t = math.min(cap, ang) / math.max(ang, 0.001)
			cam.CFrame = CFrame.lookAt(pos, pos + look:Lerp(want, t).Unit)
		end
		return screenPx(cam, worldPos) <= Misc.aimDeadzonePx
	end

	local function pickTarget(origin)
		local maxD = Misc.maxDist
		local maxD2 = maxD * maxD
		local bestWeak, bestWeakD2 = nil, maxD2
		local bestFresh, bestFreshD2 = nil, maxD2
		local sticky = Misc.stickyNode
		if sticky and nodeAlive(sticky) and typeAllowed(sticky) then
			local ws = sticky:GetAttribute("WeakSpot")
			if typeof(ws) == "Vector3" then
				local d2 = (ws - origin).Magnitude
				d2 = d2 * d2
				if d2 <= maxD2 then
					return sticky, ws, "weak"
				end
			end
		end

		-- Prefer tagged nodes; fall back to folder scan.
		local list = CollectionService:GetTagged("FustNode")
		if #list == 0 then
			local folder = workspace:FindFirstChild("Nodes")
			list = folder and folder:GetChildren() or {}
		end

		for i = 1, #list do
			local node = list[i]
			if nodeAlive(node) and typeAllowed(node) then
				local ws = node:GetAttribute("WeakSpot")
				if typeof(ws) == "Vector3" then
					local delta = ws - origin
					local d2 = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
					if d2 < bestWeakD2 then
						bestWeakD2 = d2
						bestWeak = node
					end
				elseif Misc.primeFresh then
					local part = nodeAnchor(node)
					if part then
						local delta = part.Position - origin
						local d2 = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
						if d2 < bestFreshD2 then
							bestFreshD2 = d2
							bestFresh = node
						end
					end
				end
			end
		end

		if bestWeak then
			return bestWeak, bestWeak:GetAttribute("WeakSpot"), "weak"
		end
		if bestFresh then
			local part = nodeAnchor(bestFresh)
			return bestFresh, part and part.Position or nil, "fresh"
		end
		return nil, nil, nil
	end

	local function step()
		if not Misc.autoWeak then
			return
		end
		if LOCAL:GetAttribute("Dead") == true then
			return
		end
		if Misc.requireTool and not hasGatherTool() then
			return
		end
		local char = LOCAL.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local cam = workspace.CurrentCamera
		if not root or not cam then
			return
		end

		local node, aimPos, kind = pickTarget(root.Position)
		if not node or not aimPos then
			Misc.stickyNode = nil
			return
		end
		Misc.stickyNode = node

		local aligned = aimAt(cam, aimPos)
		if not aligned then
			return
		end

		local now = os.clock()
		local cd = math.max(0.15, (Misc.swingCooldownMs or 420) / 1000)
		if now - Misc.lastSwing < cd then
			return
		end
		-- Fresh nodes only need one tap to spawn WeakSpot; keep cooldown same.
		Misc.lastSwing = now
		clickOnce(cam)
		if kind == "fresh" then
			-- Drop sticky so next tick prefers a WeakSpot if it appears.
			Misc.stickyNode = nil
		end
	end

	function Misc:syncBind()
		if self.autoWeak then
			self:bind()
		else
			self:unbind()
		end
	end

	function Misc:setNodeTypes(list)
		if type(list) == "table" then
			self.nodeTypes = list
			rebuildTypeSet()
		end
	end

	function Misc:bind()
		if self.bound then
			return
		end
		self.bound = true
		heartbeatConn = RunService.Heartbeat:Connect(step)
	end

	function Misc:unbind()
		if heartbeatConn then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
		self.bound = false
		self.stickyNode = nil
		self.mouseRemX = 0
		self.mouseRemY = 0
	end

	function Misc:destroy()
		self.autoWeak = false
		self:unbind()
	end

	return Misc
end
