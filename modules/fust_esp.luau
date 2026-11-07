-- Fust ESP — external.wtf-style Drawing when available; PlayerGui fallback.
return function(deps)
	local Players = deps.Players
	local RunService = deps.RunService
	local LOCAL = deps.LocalPlayer

	local OVERLAY_NAME = "FustBaseEsp"
	local MAX_SLOTS = 20
	local SCAN_TICK = 0.25
	local HP_MIN_DIST = 35

	local R15_BONES = {
		{ "Head", "UpperTorso" },
		{ "UpperTorso", "LowerTorso" },
		{ "UpperTorso", "LeftUpperArm" },
		{ "LeftUpperArm", "LeftLowerArm" },
		{ "LeftLowerArm", "LeftHand" },
		{ "UpperTorso", "RightUpperArm" },
		{ "RightUpperArm", "RightLowerArm" },
		{ "RightLowerArm", "RightHand" },
		{ "LowerTorso", "LeftUpperLeg" },
		{ "LeftUpperLeg", "LeftLowerLeg" },
		{ "LeftLowerLeg", "LeftFoot" },
		{ "LowerTorso", "RightUpperLeg" },
		{ "RightUpperLeg", "RightLowerLeg" },
		{ "RightLowerLeg", "RightFoot" },
	}
	local R15_LITE_BONES = {
		{ "Head", "UpperTorso" },
		{ "UpperTorso", "LowerTorso" },
		{ "UpperTorso", "LeftHand" },
		{ "UpperTorso", "RightHand" },
		{ "LowerTorso", "LeftFoot" },
		{ "LowerTorso", "RightFoot" },
	}
	local R15_PARTS = {
		"Head", "UpperTorso", "LowerTorso",
		"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
		"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
	}

	-- R6: single-part limbs, so joints come from each part's CFrame (shoulder / hip on top, hand / foot below)
	local R6_POINTS = {
		head = { "Head", Vector3.new(0, 0, 0) },
		neck = { "Torso", Vector3.new(0, 1, 0) },
		pelvis = { "Torso", Vector3.new(0, -1, 0) },
		lShoulder = { "Left Arm", Vector3.new(0, 0.8, 0) },
		lHand = { "Left Arm", Vector3.new(0, -1, 0) },
		rShoulder = { "Right Arm", Vector3.new(0, 0.8, 0) },
		rHand = { "Right Arm", Vector3.new(0, -1, 0) },
		lHip = { "Left Leg", Vector3.new(0, 0.8, 0) },
		lFoot = { "Left Leg", Vector3.new(0, -1, 0) },
		rHip = { "Right Leg", Vector3.new(0, 0.8, 0) },
		rFoot = { "Right Leg", Vector3.new(0, -1, 0) },
	}
	local R6_BONES = {
		{ "head", "neck" }, { "neck", "pelvis" },
		{ "neck", "lShoulder" }, { "lShoulder", "lHand" },
		{ "neck", "rShoulder" }, { "rShoulder", "rHand" },
		{ "pelvis", "lHip" }, { "lHip", "lFoot" },
		{ "pelvis", "rHip" }, { "rHip", "rFoot" },
	}
	local R6_PARTS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }

	local MAX_BONES = #R15_BONES
	local MAX_JOINTS = 16

	local function drawingOk()
		return type(Drawing) == "table" and type(Drawing.new) == "function"
	end

	local Esp = {
		master = false,
		maxDist = 2500,
		maxTargets = 12,
		rate = 30,
		useDrawing = drawingOk(),
		labelStyle = "External",
		cornerLength = 8,
		box = true,
		boxStyle = "Corners",
		boxFill = false,
		boxFillAlpha = 0.14,
		cornerScale = 0.28,
		tracers = false,
		distanceFade = false,
		teamCheck = false,
		hiddenColor = Color3.fromRGB(255, 120, 120),
		outline = true,
		skeleton = true,
		joints = true,
		skelDist = 400,
		name = true,
		distance = true,
		held = true,
		armor = false,
		healthBar = true,
		healthBarMaxDist = 50,
		healthText = false,
		color = Color3.fromRGB(255, 120, 200),
		visibleCheck = false,
		visibleColor = Color3.fromRGB(152, 255, 200), -- mint
		thickness = 1.5,
	}

	local overlay
	local slots = {}
	local targets = {}
	local pickBuf = {} -- reused by pickTargets to avoid alloc every scan
	local partCache = setmetatable({}, { __mode = "k" })
	local heartbeatConn
	local scanAcc, renderAcc = 0, 0
	local OUTLINE_COLOR = Color3.fromRGB(10, 10, 10)
	local BAR_BG = Color3.fromRGB(18, 18, 18)
	local HP_LOW = Color3.fromRGB(230, 70, 60)
	local HP_HIGH = Color3.fromRGB(90, 210, 110)
	local HELD_COLOR = Color3.fromRGB(255, 210, 120)
	local HEAD_UP = Vector3.new(0, 0.6, 0)
	local FEET_DOWN = Vector3.new(0, 2.9, 0)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.IgnoreWater = true
	local rayIgnore = {}

	-- A pooled frame plus the last values written to it.
	local function newRec(frame)
		return { f = frame, vis = false }
	end

	local function setVis(r, v)
		if not r then
			return
		end
		if r.dline then
			if r.vis ~= v then
				r.vis = v
				r.dline.Visible = v
			end
			return
		end
		if r.dsquare then
			if r.vis ~= v then
				r.vis = v
				r.dsquare.Visible = v
			end
			return
		end
		if r.dtext then
			if r.vis ~= v then
				r.vis = v
				r.dtext.Visible = v
			end
			return
		end
		if r.dcircle then
			if r.vis ~= v then
				r.vis = v
				r.dcircle.Visible = v
			end
			return
		end
		if r.vis ~= v then
			r.vis = v
			r.f.Visible = v
		end
	end

	local function setColor(r, c)
		if not r then
			return
		end
		if r.dline then
			if r.col ~= c then
				r.col = c
				r.dline.Color = c
			end
			return
		end
		if r.dsquare then
			if r.col ~= c then
				r.col = c
				r.dsquare.Color = c
			end
			return
		end
		if r.dtext then
			if r.col ~= c then
				r.col = c
				r.dtext.Color = c
			end
			return
		end
		if r.dcircle then
			if r.col ~= c then
				r.col = c
				r.dcircle.Color = c
			end
			return
		end
		if r.col ~= c then
			r.col = c
			r.f.BackgroundColor3 = c
		end
	end

	local function setRect(r, x, y, w, h)
		if r.x == nil or math.abs(r.x - x) > 0.3 or math.abs(r.y - y) > 0.3 then
			r.x, r.y = x, y
			r.f.Position = UDim2.fromOffset(x, y)
		end
		if r.w == nil or math.abs(r.w - w) > 0.3 or math.abs(r.h - h) > 0.3 then
			r.w, r.h = w, h
			r.f.Size = UDim2.fromOffset(w, h)
		end
	end

	local function setRot(r, deg)
		if r.rot == nil or math.abs(r.rot - deg) > 0.2 then
			r.rot = deg
			r.f.Rotation = deg
		end
	end

	local function makeFrame(z, rounded)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BorderSizePixel = 0
		f.Visible = false
		f.ZIndex = z
		if rounded then
			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(1, 0)
			c.Parent = f
		end
		f.Parent = overlay
		return newRec(f)
	end

	local function makeDrawLine()
		local l = Drawing.new("Line")
		l.Visible = false
		l.Thickness = 1
		return { dline = l, vis = false }
	end

	local function makeDrawSquare()
		local s = Drawing.new("Square")
		s.Visible = false
		s.Filled = true
		s.Thickness = 0
		return { dsquare = s, vis = false }
	end

	local function makeDrawText()
		local t = Drawing.new("Text")
		t.Visible = false
		t.Center = true
		t.Outline = true
		t.Size = 14
		t.Font = Drawing.Fonts and Drawing.Fonts.UI or 2
		return { dtext = t, vis = false }
	end

	local function makeDrawDot()
		local c = Drawing.new("Circle")
		c.Visible = false
		c.Filled = true
		c.NumSides = 12
		return { dcircle = c, vis = false }
	end

	local function makeSeg(z)
		if Esp.useDrawing and drawingOk() then
			return makeDrawLine()
		end
		return makeFrame(z)
	end

	local function makeText()
		if Esp.useDrawing and drawingOk() then
			return makeDrawText()
		end
		local t = Instance.new("TextLabel")
		t.AnchorPoint = Vector2.new(0.5, 1)
		t.BackgroundTransparency = 1
		t.TextStrokeTransparency = 0.35
		t.TextStrokeColor3 = Color3.new(0, 0, 0)
		t.Font = Enum.Font.GothamMedium
		t.TextSize = 13
		t.TextXAlignment = Enum.TextXAlignment.Center
		t.TextYAlignment = Enum.TextYAlignment.Bottom
		t.Visible = false
		t.ZIndex = 6
		t.Parent = overlay
		return newRec(t)
	end

	-- Frames for one target, made the first time that slot is used.
	local function getSlot(i)
		local s = slots[i]
		if s then
			return s
		end
		s = { box = {}, boxOut = {}, boxFill = nil, tracer = nil, tracerOut = nil, bones = {}, boneOut = {}, joints = {}, pts = {}, jdone = {}, segs = {} }
		for k = 1, 8 do
			s.segs[k] = { 0, 0, 0, 0 }
		end
		if Esp.useDrawing and drawingOk() then
			s.boxFill = makeDrawSquare()
			s.boxFill.dsquare.Transparency = 1 - Esp.boxFillAlpha
		else
			s.boxFill = makeFrame(2)
			s.boxFill.f.BackgroundTransparency = 1 - Esp.boxFillAlpha
			s.boxFill.f.AnchorPoint = Vector2.new(0.5, 0.5)
			s.boxFill.f.ZIndex = 2
		end
		s.tracer = makeSeg(3)
		s.tracerOut = makeSeg(1)
		if s.tracerOut.f then
			s.tracerOut.f.BackgroundTransparency = 0.5
		end
		for k = 1, 8 do
			s.boxOut[k] = makeSeg(1)
			s.box[k] = makeSeg(3)
			if s.boxOut[k].f then
				s.boxOut[k].f.BackgroundTransparency = 0.45
			end
		end
		for k = 1, MAX_BONES do
			s.boneOut[k] = makeSeg(1)
			if s.boneOut[k].f then
				s.boneOut[k].f.BackgroundTransparency = 0.55
			end
			s.bones[k] = makeSeg(3)
		end
		for k = 1, MAX_JOINTS do
			s.joints[k] = Esp.useDrawing and drawingOk() and makeDrawDot() or makeFrame(4, true)
		end
		s.barBg = makeFrame(2)
		s.barBg.f.AnchorPoint = Vector2.new(0, 0)
		s.barBg.f.BackgroundTransparency = 0.25
		s.barFill = makeFrame(3)
		s.barFill.f.AnchorPoint = Vector2.new(0, 1)
		s.label = makeText()
		s.heldLabel = makeText()
		if s.heldLabel.f then
			s.heldLabel.f.TextSize = 11
		elseif s.heldLabel.dtext then
			s.heldLabel.dtext.Size = 11
		end
		slots[i] = s
		return s
	end

	local function hideList(list, from)
		for k = from or 1, #list do
			setVis(list[k], false)
		end
	end

	local function hideSlot(s)
		hideList(s.box)
		hideList(s.boxOut)
		hideList(s.bones)
		hideList(s.boneOut)
		hideList(s.joints)
		setVis(s.barBg, false)
		setVis(s.barFill, false)
		setVis(s.label, false)
		setVis(s.heldLabel, false)
		if s.boxFill then
			setVis(s.boxFill, false)
		end
		if s.tracer then
			setVis(s.tracer, false)
		end
		if s.tracerOut then
			setVis(s.tracerOut, false)
		end
	end

	local function hideAll()
		for _, s in pairs(slots) do
			hideSlot(s)
		end
	end

	-- Segment from a to b; stretched by `thick` so neighbouring segments overlap at the joints.
	local function seg(r, ax, ay, bx, by, color, thick)
		local dx, dy = bx - ax, by - ay
		local len = math.sqrt(dx * dx + dy * dy)
		if len < 1 then
			setVis(r, false)
			return
		end
		if r.dline then
			r.dline.From = Vector2.new(ax, ay)
			r.dline.To = Vector2.new(bx, by)
			r.dline.Thickness = thick
			setColor(r, color)
			setVis(r, true)
			return
		end
		setColor(r, color)
		setRect(r, (ax + bx) * 0.5, (ay + by) * 0.5, len + thick, thick)
		setRot(r, math.deg(math.atan2(dy, dx)))
		setVis(r, true)
	end

	local function dot(r, x, y, size, color)
		if r.dcircle then
			r.dcircle.Position = Vector2.new(x, y)
			r.dcircle.Radius = math.max(size * 0.5, 1.5)
			setColor(r, color)
			setVis(r, true)
			return
		end
		setColor(r, color)
		setRect(r, x, y, size, size)
		setVis(r, true)
	end

	local function playerMoneyLabel(plr)
		local ls = plr:FindFirstChild("leaderstats")
		if ls then
			for _, ch in ipairs(ls:GetChildren()) do
				if ch:IsA("NumberValue") or ch:IsA("IntValue") then
					local tag = ch.Name:gsub("%s+", "")
					if #tag > 3 then
						tag = tag:sub(1, 3)
					end
					return string.format("%d%s", math.floor(ch.Value + 0.5), tag)
				end
			end
		end
		for _, key in ipairs({ "Money", "MC", "Balance", "Credits" }) do
			local v = plr:GetAttribute(key)
			if v ~= nil then
				return tostring(v) .. (key == "MC" and "MC" or "MC")
			end
		end
		return "?"
	end

	local function formatEspLabel(t)
		if Esp.labelStyle == "External" then
			local plr = t.plr
			local mc = playerMoneyLabel(plr)
			local w = "-"
			if t.held and #t.held > 0 then
				w = t.held:sub(1, 1):upper()
			end
			local line = string.format("%s (@%s) - %s [%.1fm]", mc, plr.Name, w, t.dist)
			if Esp.healthText then
				line = line .. string.format("  %.0fHP", t.hum.Health)
			end
			return line
		end
		local chunks = {}
		if Esp.name then
			chunks[#chunks + 1] = t.plr.DisplayName
		end
		if Esp.distance then
			chunks[#chunks + 1] = string.format("%dm", math.floor(t.dist + 0.5))
		end
		if Esp.healthText then
			chunks[#chunks + 1] = string.format("%.0f/%.0f", t.hum.Health, t.hum.MaxHealth)
		end
		return table.concat(chunks, "  ·  ")
	end

	-- Resolve character: Player.Character, else workspace.<Name> (Fust places rigs there).
	local function charOf(plr)
		local char = plr.Character
		if char and char.Parent then
			return char
		end
		local byName = workspace:FindFirstChild(plr.Name)
		if byName and byName:IsA("Model") and byName:FindFirstChildOfClass("Humanoid") then
			return byName
		end
		return nil
	end

	-- Parts for a character, kept until incomplete/stale (joiners often cache before Head streams).
	local function partsFor(char)
		local c = partCache[char]
		if c then
			local ok = c.head and c.head.Parent and c.root and c.root.Parent
			if ok then
				for _, p in pairs(c.parts) do
					if not p.Parent then
						ok = false
						break
					end
				end
			end
			-- First scan may miss UpperTorso and lock an empty "R6" cache.
			if ok and not c.r15 and char:FindFirstChild("UpperTorso") then
				ok = false
			end
			if ok then
				return c
			end
			partCache[char] = nil
		end
		local parts = {}
		local r15 = char:FindFirstChild("UpperTorso") ~= nil
		for _, n in ipairs(r15 and R15_PARTS or R6_PARTS) do
			local p = char:FindFirstChild(n)
			if p and p:IsA("BasePart") then
				parts[n] = p
			end
		end
		local head = char:FindFirstChild("Head")
		local root = char:FindFirstChild("HumanoidRootPart")
		-- Don't freeze a headless cache — rebuild next scan until Head exists.
		if not head or not root then
			return { parts = parts, r15 = r15, head = head, root = root }
		end
		c = { parts = parts, r15 = r15, head = head, root = root }
		partCache[char] = c
		return c
	end

	local function sameTeam(plr)
		local lt, tt = LOCAL.Team, plr.Team
		if not lt or not tt or lt.Neutral or tt.Neutral then
			return false
		end
		return lt == tt
	end

	local function pickTargets(origin)
		local count = 0
		if origin then
			local maxD2 = Esp.maxDist * Esp.maxDist
			local players = Players:GetPlayers()
			for i = 1, #players do
				local plr = players[i]
				if plr ~= LOCAL and not (Esp.teamCheck and sameTeam(plr)) then
					local char = charOf(plr)
					local hum = char and char:FindFirstChildOfClass("Humanoid")
					local root = char and char:FindFirstChild("HumanoidRootPart")
					if hum and root and hum.Health > 0 then
						local d = root.Position - origin
						local d2 = d.X * d.X + d.Y * d.Y + d.Z * d.Z
						if d2 <= maxD2 then
							count += 1
							local row = pickBuf[count]
							if row then
								row.plr, row.char, row.hum, row.d2 = plr, char, hum, d2
								row.cache, row.held, row.armor, row.dist = nil, nil, nil, nil
							else
								pickBuf[count] = { plr = plr, char = char, hum = hum, d2 = d2 }
							end
						end
					end
				end
			end
		end
		for i = #pickBuf, count + 1, -1 do
			pickBuf[i] = nil
		end
		table.sort(pickBuf, function(a, b)
			return a.d2 < b.d2
		end)
		local keep = math.min(Esp.maxTargets, MAX_SLOTS, count)
		for i = #pickBuf, keep + 1, -1 do
			pickBuf[i] = nil
		end
		return pickBuf
	end

	local function shouldRun()
		return Esp.master
			and (
				Esp.box
				or Esp.skeleton
				or Esp.name
				or Esp.distance
				or Esp.held
				or Esp.armor
				or Esp.healthBar
				or Esp.healthText
				or Esp.tracers
			)
	end

	-- Tool.Name is already the display name (knowledge.md). Optional WSkin suffix.
	local function heldText(char)
		local tool = char:FindFirstChildOfClass("Tool")
		if not tool then
			return nil
		end
		local skin = tool:GetAttribute("WSkin")
		if type(skin) == "string" and skin ~= "" and skin ~= "none" then
			return tool.Name .. " · " .. skin
		end
		return tool.Name
	end

	-- Unique FustWear ItemIds → short readable list (no require of Fust.Items).
	local function armorText(char)
		local wear = char:FindFirstChild("FustWear")
		if not wear then
			return nil
		end
		local seen, parts = {}, {}
		for _, child in ipairs(wear:GetChildren()) do
			local id = child:GetAttribute("ItemId")
			if type(id) == "string" and id ~= "" and not seen[id] then
				seen[id] = true
				parts[#parts + 1] = id:gsub("_", " ")
			end
		end
		if #parts == 0 then
			return nil
		end
		table.sort(parts)
		if #parts > 2 then
			return parts[1] .. " · " .. parts[2] .. " +" .. (#parts - 2)
		end
		return table.concat(parts, " · ")
	end

	local function hpColor(pct)
		return HP_LOW:Lerp(HP_HIGH, pct)
	end

	-- Camera → head LOS; transparent / non-collide parts are stepped through (same idea as aim).
	local function isVisible(camPos, to, char)
		local dir = to - camPos
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
		local origin = camPos
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
			if not (inst:IsA("BasePart") and (inst.Transparency > 0.4 or not inst.CanCollide)) then
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

	local function scan()
		local myRoot = LOCAL.Character and LOCAL.Character:FindFirstChild("HumanoidRootPart")
		targets = pickTargets(myRoot and myRoot.Position)
		for i = 1, #targets do
			local t = targets[i]
			t.cache = partsFor(t.char)
			t.dist = math.sqrt(t.d2)
			t.held = Esp.held and heldText(t.char) or nil
			t.armor = Esp.armor and armorText(t.char) or nil
		end
	end

	local function setSeg(q, ax, ay, bx, by)
		q[1], q[2], q[3], q[4] = ax, ay, bx, by
	end

	local function drawBox(s, x0, y0, x1, y1, color, thick)
		local q = s.segs
		local n
		if Esp.boxStyle == "Corners" then
			local cw, ch
			if Esp.cornerLength and Esp.cornerLength > 0 then
				cw = math.min(Esp.cornerLength, (x1 - x0) * 0.5)
				ch = math.min(Esp.cornerLength, (y1 - y0) * 0.5)
			else
				local scale = math.clamp(Esp.cornerScale or 0.28, 0.12, 0.45)
				cw, ch = (x1 - x0) * scale, (y1 - y0) * (scale * 0.78)
			end
			setSeg(q[1], x0, y0, x0 + cw, y0)
			setSeg(q[2], x0, y0, x0, y0 + ch)
			setSeg(q[3], x1, y0, x1 - cw, y0)
			setSeg(q[4], x1, y0, x1, y0 + ch)
			setSeg(q[5], x0, y1, x0 + cw, y1)
			setSeg(q[6], x0, y1, x0, y1 - ch)
			setSeg(q[7], x1, y1, x1 - cw, y1)
			setSeg(q[8], x1, y1, x1, y1 - ch)
			n = 8
		else
			setSeg(q[1], x0, y0, x1, y0)
			setSeg(q[2], x1, y0, x1, y1)
			setSeg(q[3], x1, y1, x0, y1)
			setSeg(q[4], x0, y1, x0, y0)
			n = 4
		end
		for k = 1, n do
			local e = q[k]
			seg(s.box[k], e[1], e[2], e[3], e[4], color, thick)
			if Esp.outline then
				seg(s.boxOut[k], e[1], e[2], e[3], e[4], OUTLINE_COLOR, thick + 2)
			else
				setVis(s.boxOut[k], false)
			end
		end
		hideList(s.box, n + 1)
		hideList(s.boxOut, n + 1)
	end

	-- Screen point for a skeleton key, projected once per render (false = behind the camera).
	local function project(pts, camera, key, part, offset)
		local v = pts[key]
		if v ~= nil then
			return v
		end
		if not part then
			pts[key] = false
			return false
		end
		local world = offset and part.CFrame:PointToWorldSpace(offset) or part.Position
		local p = camera:WorldToViewportPoint(world)
		v = p.Z > 0 and Vector2.new(p.X, p.Y) or false
		pts[key] = v
		return v
	end

	local function joint(s, key, v, size, color, state)
		if s.jdone[key] or state.used >= MAX_JOINTS then
			return
		end
		s.jdone[key] = true
		state.used += 1
		dot(s.joints[state.used], v.X, v.Y, size, color)
	end

	local jointState = { used = 0 }

	local function drawSkeleton(s, t, camera, color, thick)
		local c = t.cache
		local pts = s.pts
		table.clear(pts)
		table.clear(s.jdone)
		jointState.used = 0
		local withJoints = Esp.joints and t.dist <= 180
		local jsize = thick + 2
		local n
		local list
		if c.r15 then
			list = t.dist <= 180 and R15_BONES or R15_LITE_BONES
		else
			list = R6_BONES
		end
		n = #list
		for k = 1, n do
			local b = list[k]
			local a, z
			if c.r15 then
				a = project(pts, camera, b[1], c.parts[b[1]])
				z = project(pts, camera, b[2], c.parts[b[2]])
			else
				local da, db = R6_POINTS[b[1]], R6_POINTS[b[2]]
				a = project(pts, camera, b[1], c.parts[da[1]], da[2])
				z = project(pts, camera, b[2], c.parts[db[1]], db[2])
			end
			if a and z then
				seg(s.bones[k], a.X, a.Y, z.X, z.Y, color, thick)
				if Esp.outline then
					seg(s.boneOut[k], a.X, a.Y, z.X, z.Y, OUTLINE_COLOR, thick + 2)
				else
					setVis(s.boneOut[k], false)
				end
				if withJoints then
					joint(s, b[1], a, jsize, color, jointState)
					joint(s, b[2], z, jsize, color, jointState)
				end
			else
				setVis(s.bones[k], false)
				setVis(s.boneOut[k], false)
			end
		end
		hideList(s.bones, n + 1)
		hideList(s.boneOut, n + 1)
		hideList(s.joints, jointState.used + 1)
	end

	local function render()
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end
		local vp = camera.ViewportSize
		local baseColor = Esp.color
		local visColor = Esp.visibleColor
		local checkVis = Esp.visibleCheck
		local camPos = camera.CFrame.Position
		local used = 0
		for i, t in ipairs(targets) do
			local c = t.cache
			local s = getSlot(i)
			used = i
			local head, root = c.head, c.root
			local ok = head and root and head.Parent and root.Parent and t.hum.Health > 0
			local top, bottom
			if ok then
				top = camera:WorldToViewportPoint(head.Position + HEAD_UP)
				bottom = camera:WorldToViewportPoint(root.Position - FEET_DOWN)
				ok = top.Z > 0 and bottom.Z > 0
					and math.max(top.X, bottom.X) > -50 and math.min(top.X, bottom.X) < vp.X + 50
					and math.max(top.Y, bottom.Y) > -50 and math.min(top.Y, bottom.Y) < vp.Y + 50
			end
			if not ok then
				hideSlot(s)
			else
				local color = baseColor
				local visible = not checkVis or isVisible(camPos, head.Position, t.char)
				if checkVis then
					color = visible and visColor or Esp.hiddenColor
				end
				local fade = 1
				if Esp.distanceFade and Esp.maxDist > 120 then
					fade = math.clamp(1 - (t.dist - 80) / (Esp.maxDist - 80), 0.35, 1)
				end
				local y0, y1 = math.min(top.Y, bottom.Y), math.max(top.Y, bottom.Y)
				local h = math.max(y1 - y0, 14)
				y1 = y0 + h
				local cx = (top.X + bottom.X) * 0.5
				local w = math.clamp(h * 0.5, 10, 240)
				local x0, x1 = cx - w * 0.5, cx + w * 0.5
				local thick = Esp.thickness * (t.dist < 120 and 1.35 or 1)

				if Esp.box then
					if Esp.boxFill and s.boxFill then
						setColor(s.boxFill, color)
						local fillA = 1 - (Esp.boxFillAlpha or 0.14) * fade
						if s.boxFill.dsquare then
							s.boxFill.dsquare.Position = Vector2.new(x0, y0)
							s.boxFill.dsquare.Size = Vector2.new(x1 - x0, y1 - y0)
							s.boxFill.dsquare.Transparency = fillA
							setVis(s.boxFill, true)
						else
							s.boxFill.f.BackgroundTransparency = fillA
							setRect(s.boxFill, (x0 + x1) * 0.5, (y0 + y1) * 0.5, x1 - x0, y1 - y0)
							setVis(s.boxFill, true)
						end
					elseif s.boxFill then
						setVis(s.boxFill, false)
					end
					drawBox(s, x0, y0, x1, y1, color, thick)
				else
					hideList(s.box)
					hideList(s.boxOut)
					if s.boxFill then
						setVis(s.boxFill, false)
					end
				end

				if Esp.tracers and s.tracer then
					local fromX, fromY = vp.X * 0.5, vp.Y
					local tthick = math.max(Esp.thickness, 1)
					seg(s.tracer, fromX, fromY, cx, y1, color, tthick)
					if Esp.outline then
						seg(s.tracerOut, fromX, fromY, cx, y1, OUTLINE_COLOR, tthick + 1)
					else
						setVis(s.tracerOut, false)
					end
				elseif s.tracer then
					setVis(s.tracer, false)
					setVis(s.tracerOut, false)
				end

				if Esp.skeleton and t.dist <= Esp.skelDist then
					drawSkeleton(s, t, camera, color, thick)
				else
					hideList(s.bones)
					hideList(s.boneOut)
					hideList(s.joints)
				end

				local hp = t.hum.Health / math.max(t.hum.MaxHealth, 1)
				hp = math.clamp(hp, 0, 1)
				if Esp.healthBar and t.dist >= HP_MIN_DIST and t.dist <= Esp.healthBarMaxDist and h >= 12 then
					local barW = 3
					local bx = x0 - barW - 5
					setColor(s.barBg, BAR_BG)
					setRect(s.barBg, bx - 1, y0 - 1, barW + 2, h + 2)
					setVis(s.barBg, true)
					setColor(s.barFill, hpColor(hp))
					setRect(s.barFill, bx, y1, barW, math.max(h * hp, 1))
					setVis(s.barFill, true)
				else
					setVis(s.barBg, false)
					setVis(s.barFill, false)
				end

				if Esp.name or Esp.distance or Esp.healthText or Esp.held then
					local text = formatEspLabel(t)
					local key = text .. "|" .. tostring(fade)
					local lab = s.label
					if lab.key ~= key then
						lab.key = key
						if lab.dtext then
							lab.dtext.Text = text
						elseif lab.f then
							lab.f.Text = text
						end
					end
					setColor(lab, color)
					if lab.dtext then
						lab.dtext.Position = Vector2.new(cx, y0 - 6)
						lab.dtext.Size = t.dist > 600 and 12 or 14
						lab.dtext.Transparency = 0.35 + (1 - fade) * 0.45
						setVis(lab, true)
					elseif lab.f then
						local tTrans = 0.35 + (1 - fade) * 0.45
						if lab.tt ~= tTrans then
							lab.tt = tTrans
							lab.f.TextTransparency = tTrans
						end
						local size = t.dist > 600 and 12 or 13
						if lab.ts ~= size then
							lab.ts = size
							lab.f.TextSize = size
						end
						setRect(lab, cx, y0 - 4, 220, 16)
						setVis(lab, true)
					end
				else
					setVis(s.label, false)
				end

				if Esp.labelStyle ~= "External" then
					local subChunks = {}
					if Esp.held and t.held then
						subChunks[#subChunks + 1] = t.held
					end
					if Esp.armor and t.armor then
						subChunks[#subChunks + 1] = t.armor
					end
					if #subChunks > 0 then
						local sub = s.heldLabel
						local subKey = table.concat(subChunks, "|")
						if sub.key ~= subKey then
							sub.key = subKey
							if sub.dtext then
								sub.dtext.Text = table.concat(subChunks, "  ·  ")
							elseif sub.f then
								sub.f.Text = table.concat(subChunks, "  ·  ")
							end
						end
						local subCol = (Esp.held and t.held) and HELD_COLOR or color
						setColor(sub, subCol)
						if sub.dtext then
							sub.dtext.Position = Vector2.new(cx, y1 + 10)
							sub.dtext.Size = 11
							setVis(sub, true)
						elseif sub.f then
							setRect(sub, cx, y1 + 2, 240, 14)
							setVis(sub, true)
						end
					else
						setVis(s.heldLabel, false)
					end
				else
					setVis(s.heldLabel, false)
				end
			end
		end
		for i = used + 1, MAX_SLOTS do
			if slots[i] then
				hideSlot(slots[i])
			end
		end
	end

	local function stopLoop()
		if heartbeatConn then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
	end

	function Esp:bootLoop()
		if heartbeatConn then
			return
		end
		scanAcc, renderAcc = SCAN_TICK, 1
		heartbeatConn = RunService.Heartbeat:Connect(function(dt)
			if not shouldRun() then
				hideAll()
				stopLoop()
				return
			end
			scanAcc += dt
			renderAcc += dt
			if scanAcc >= SCAN_TICK then
				scanAcc -= SCAN_TICK
				scan()
			end
			local interval = 1 / math.clamp(Esp.rate, 5, 240)
			if renderAcc >= interval then
				-- Subtract (don't zero) so high FPS doesn't hitch when Heartbeat stalls.
				renderAcc -= interval
				if renderAcc > interval then
					renderAcc = 0
				end
				render()
			end
		end)
	end

	local function cleanupOverlayGui()
		local pg = LOCAL:FindFirstChild("PlayerGui")
		if not pg then
			return
		end
		for _, g in ipairs(pg:GetChildren()) do
			if g:IsA("ScreenGui") and g:GetAttribute("FustBaseEsp") == true then
				g:Destroy()
			end
		end
	end

	local function removeDrawRec(r)
		if not r then
			return
		end
		pcall(function()
			if r.dline then
				r.dline:Remove()
			elseif r.dsquare then
				r.dsquare:Remove()
			elseif r.dtext then
				r.dtext:Remove()
			elseif r.dcircle then
				r.dcircle:Remove()
			end
		end)
	end

	local function destroySlotDraw(s)
		if not s then
			return
		end
		for _, list in ipairs({ s.box, s.boxOut, s.bones, s.boneOut, s.joints }) do
			for _, r in ipairs(list) do
				removeDrawRec(r)
			end
		end
		removeDrawRec(s.boxFill)
		removeDrawRec(s.tracer)
		removeDrawRec(s.tracerOut)
		removeDrawRec(s.label)
		removeDrawRec(s.heldLabel)
	end

	local function destroyOverlay()
		stopLoop()
		for _, s in pairs(slots) do
			destroySlotDraw(s)
		end
		if overlay then
			overlay:Destroy()
			overlay = nil
		end
		table.clear(slots)
		targets = {}
	end

	function Esp:ensureGui()
		if Esp.useDrawing and drawingOk() then
			if not heartbeatConn then
				self:bootLoop()
			end
			return
		end
		if overlay and overlay.Parent then
			self:bootLoop()
			return
		end
		cleanupOverlayGui()
		destroyOverlay()
		overlay = Instance.new("ScreenGui")
		overlay.Name = OVERLAY_NAME
		overlay.ResetOnSpawn = false
		overlay.IgnoreGuiInset = true
		overlay.DisplayOrder = 200
		overlay.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		overlay:SetAttribute("FustBaseEsp", true)
		overlay.Parent = LOCAL:WaitForChild("PlayerGui")
		overlay.Destroying:Connect(stopLoop)
		self:bootLoop()
	end

	function Esp:setMaster(on)
		self.master = on
		if on then
			self:ensureGui()
		else
			hideAll()
		end
	end

	function Esp:destroy()
		self.master = false
		destroyOverlay()
		cleanupOverlayGui()
	end


	function Esp:cleanupBeforeLoad()
		cleanupOverlayGui()
	end

	function Esp:applyExternalVisualPreset()
		self.useDrawing = drawingOk()
		self.labelStyle = "External"
		self.cornerLength = 8
		self.color = Color3.fromRGB(255, 120, 200)
		self.visibleColor = Color3.fromRGB(120, 255, 180)
		self.master = true
		self.box = true
		self.boxStyle = "Corners"
		self.boxFill = true
		self.boxFillAlpha = 0.14
		self.cornerScale = 0.28
		self.skeleton = true
		self.name = true
		self.distance = true
		self.held = true
		self.healthBar = false
		self.healthText = true
		self.teamCheck = true
		self.visibleCheck = true
		self.tracers = false
		self.distanceFade = true
		self.maxDist = 5000
		destroyOverlay()
		self:setMaster(true)
	end

	Esp.MAX_SLOTS = MAX_SLOTS

	return Esp
end
