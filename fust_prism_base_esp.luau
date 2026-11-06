-- Prism + Fust-safe ESP (PlayerGui only: box, skeleton, health, names). No Drawing, no char edits.
local PRISM_URL = "https://raw.githubusercontent.com/VortexHubScripts/TEST/refs/heads/main/TEST"

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LOCAL = Players.LocalPlayer

local MAX_TARGETS = 12
local TICK = 0.18
local SKEL_MAX_DIST = 400
local HP_MIN_DIST = 35
local HP_MAX_DIST = 2500
local OVERLAY_NAME = "FustBaseEsp"

-- Subset of bones for medium range (cheaper, still reads as skeleton)
local BONES_FULL = {
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

local BONES_LITE = {
	{ "Head", "UpperTorso" },
	{ "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftHand" },
	{ "UpperTorso", "RightHand" },
	{ "LowerTorso", "LeftFoot" },
	{ "LowerTorso", "RightFoot" },
}

local MAX_BONES = #BONES_FULL
local LINES_PER_TARGET = 4 + MAX_BONES

local function httpGet(url)
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(body) == "string" then
		return body
	end
	return nil
end

local function loadPrism()
	local env = (getgenv and getgenv()) or _G
	if env.__PrismLibrary and env.__PrismLibrary.CreateWindow then
		return env.__PrismLibrary
	end
	local body = httpGet(PRISM_URL)
	if not body then
		error("Prism download failed (HttpGet)")
	end
	local fn = loadstring(body)
	if not fn then
		error("Prism loadstring failed")
	end
	return fn()
end

local Esp = {
	master = false,
	maxDist = 2500,
	box = true,
	skeleton = true,
	name = true,
	distance = true,
	healthBar = true,
	healthText = false,
	color = Color3.fromRGB(235, 235, 235),
}

local overlay
local linePool = {}
local textPool = {}
local barBgPool = {}
local barFillPool = {}
local heartbeatConn
local acc = 0
local targetBuf = {}
local targetCount = 0

local function hideAll()
	for _, f in ipairs(linePool) do
		f.Visible = false
	end
	for _, t in ipairs(textPool) do
		t.Visible = false
	end
	for _, f in ipairs(barBgPool) do
		f.Visible = false
	end
	for _, f in ipairs(barFillPool) do
		f.Visible = false
	end
end

local function stopLoop()
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
end

local function destroyOverlay()
	stopLoop()
	hideAll()
	if overlay then
		overlay:Destroy()
		overlay = nil
	end
	table.clear(linePool)
	table.clear(textPool)
	table.clear(barBgPool)
	table.clear(barFillPool)
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

local function makeLine(parent)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BorderSizePixel = 0
	f.BackgroundTransparency = 0.15
	f.Visible = false
	f.ZIndex = 2
	f.Parent = parent
	return f
end

local function makeText(parent)
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.TextStrokeTransparency = 0.45
	t.Font = Enum.Font.GothamMedium
	t.TextSize = 13
	t.TextXAlignment = Enum.TextXAlignment.Center
	t.Visible = false
	t.ZIndex = 3
	t.Parent = parent
	return t
end

local function makeBar(parent, z)
	local f = Instance.new("Frame")
	f.BorderSizePixel = 0
	f.Visible = false
	f.ZIndex = z
	f.Parent = parent
	return f
end

local function drawSeg(frame, a, b, color, thickness)
	local dir = b - a
	local dist = dir.Magnitude
	if dist < 1.5 then
		frame.Visible = false
		return
	end
	frame.BackgroundColor3 = color
	frame.Visible = true
	frame.Size = UDim2.fromOffset(dist, thickness or 1)
	frame.Position = UDim2.fromOffset((a.X + b.X) * 0.5, (a.Y + b.Y) * 0.5)
	frame.Rotation = math.deg(math.atan2(dir.Y, dir.X))
end

local function partPos(char, name)
	local p = char:FindFirstChild(name)
	if p and p:IsA("BasePart") then
		return p.Position
	end
	return nil
end

-- Head + root screen box: stable at range, no 8-corner bbox spam
local function screenBox(char, camera)
	local head = char:FindFirstChild("Head")
	local root = char:FindFirstChild("HumanoidRootPart")
	if not head or not root then
		return nil
	end
	local top = camera:WorldToViewportPoint(head.Position + Vector3.new(0, 0.45, 0))
	local bottom = camera:WorldToViewportPoint(root.Position - Vector3.new(0, 2.8, 0))
	if top.Z <= 0 and bottom.Z <= 0 then
		return nil
	end
	local minY = math.min(top.Y, bottom.Y)
	local maxY = math.max(top.Y, bottom.Y)
	local height = math.max(maxY - minY, 14)
	local centerX = (top.X + bottom.X) * 0.5
	local width = math.clamp(height * 0.42, 10, 220)
	local minX = centerX - width * 0.5
	local maxX = centerX + width * 0.5
	return minX, minY, maxX, maxY, height
end

local function skipBoneLines(pool, fromIdx, count)
	for i = fromIdx, fromIdx + count - 1 do
		pool[i].Visible = false
	end
	return fromIdx + count
end

local function drawSkeleton(char, camera, color, pool, startIdx, boneList, thickness)
	local idx = startIdx
	for _, pair in ipairs(boneList) do
		local frame = pool[idx]
		idx += 1
		local pa = partPos(char, pair[1])
		local pb = partPos(char, pair[2])
		if not pa or not pb then
			frame.Visible = false
		else
			local sa = camera:WorldToViewportPoint(pa)
			local sb = camera:WorldToViewportPoint(pb)
			if sa.Z <= 0 or sb.Z <= 0 then
				frame.Visible = false
			else
				drawSeg(frame, Vector2.new(sa.X, sa.Y), Vector2.new(sb.X, sb.Y), color, thickness)
			end
		end
	end
	for i = idx, startIdx + MAX_BONES - 1 do
		pool[i].Visible = false
	end
	return startIdx + MAX_BONES
end

local function pickTargets(origin, maxDist)
	targetCount = 0
	if not origin then
		return 0
	end
	local maxD2 = maxDist * maxDist
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LOCAL then
			local char = plr.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				local delta = root.Position - origin
				local d2 = delta.X * delta.X + delta.Y * delta.Y + delta.Z * delta.Z
				if d2 <= maxD2 then
					targetCount += 1
					local slot = targetBuf[targetCount]
					if not slot then
						slot = {}
						targetBuf[targetCount] = slot
					end
					slot.plr = plr
					slot.dist = math.sqrt(d2)
					slot.hum = hum
					slot.char = char
				end
			end
		end
	end
	if targetCount > 1 then
		table.sort(targetBuf, function(a, b)
			return a.dist < b.dist
		end)
	end
	if targetCount > MAX_TARGETS then
		targetCount = MAX_TARGETS
	end
	return targetCount
end

local function shouldShowHealth(dist, boxHeightPx)
	if not Esp.healthBar then
		return false
	end
	if dist < HP_MIN_DIST or dist > HP_MAX_DIST then
		return false
	end
	if boxHeightPx and boxHeightPx < 12 then
		return false
	end
	return true
end

local function shouldRun()
	if not Esp.master then
		return false
	end
	return Esp.box or Esp.skeleton or Esp.name or Esp.distance or Esp.healthBar or Esp.healthText
end

function Esp:bootLoop()
	if heartbeatConn then
		return
	end
	acc = 0
	heartbeatConn = RunService.Heartbeat:Connect(function(dt)
		if not shouldRun() then
			hideAll()
			stopLoop()
			return
		end
		acc += dt
		if acc < TICK then
			return
		end
		acc = 0

		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		local myRoot = LOCAL.Character and LOCAL.Character:FindFirstChild("HumanoidRootPart")
		local origin = myRoot and myRoot.Position
		local limit = pickTargets(origin, Esp.maxDist)

		local lineIdx = 1
		local textIdx = 1
		local barIdx = 1
		local lineThick = 1

		for ti = 1, limit do
			local entry = targetBuf[ti]
			local char = entry.char
			local minX, minY, maxX, maxY, boxH = screenBox(char, camera)
			local dist = entry.dist

			if dist < 120 then
				lineThick = 2
			else
				lineThick = 1
			end

			if Esp.box and minX then
				local tl = Vector2.new(minX, minY)
				local tr = Vector2.new(maxX, minY)
				local bl = Vector2.new(minX, maxY)
				local br = Vector2.new(maxX, maxY)
				drawSeg(linePool[lineIdx], tl, tr, Esp.color, lineThick)
				lineIdx += 1
				drawSeg(linePool[lineIdx], tr, br, Esp.color, lineThick)
				lineIdx += 1
				drawSeg(linePool[lineIdx], br, bl, Esp.color, lineThick)
				lineIdx += 1
				drawSeg(linePool[lineIdx], bl, tl, Esp.color, lineThick)
				lineIdx += 1
			else
				lineIdx = skipBoneLines(linePool, lineIdx, 4)
			end

			if Esp.skeleton and dist <= SKEL_MAX_DIST then
				local bones = dist <= 180 and BONES_FULL or BONES_LITE
				lineIdx = drawSkeleton(char, camera, Esp.color, linePool, lineIdx, bones, lineThick)
			elseif Esp.skeleton then
				lineIdx = skipBoneLines(linePool, lineIdx, MAX_BONES)
			else
				lineIdx = skipBoneLines(linePool, lineIdx, MAX_BONES)
			end

			if minX and shouldShowHealth(dist, boxH or (maxY - minY)) then
				local bg = barBgPool[barIdx]
				local fill = barFillPool[barIdx]
				barIdx += 1
				local h = maxY - minY
				local barH = math.clamp(h * 0.85, 36, 72)
				local barW = 3
				local x = minX - 12
				local y = minY + (h - barH) * 0.5
				local pct = math.clamp(entry.hum.Health / math.max(entry.hum.MaxHealth, 1), 0, 1)
				bg.Visible = true
				bg.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
				bg.BackgroundTransparency = 0.35
				bg.Position = UDim2.fromOffset(x, y)
				bg.Size = UDim2.fromOffset(barW, barH)
				fill.Visible = true
				fill.BackgroundColor3 = Color3.fromRGB(90, 210, 110)
				fill.BackgroundTransparency = 0.1
				fill.AnchorPoint = Vector2.new(0, 1)
				fill.Position = UDim2.fromOffset(x, y + barH)
				fill.Size = UDim2.fromOffset(barW, barH * pct)
			end

			local label = textPool[textIdx]
			textIdx += 1
			if minX and (Esp.name or Esp.distance or Esp.healthText) then
				local chunks = {}
				if Esp.name then
					table.insert(chunks, entry.plr.DisplayName)
				end
				if Esp.distance and origin then
					table.insert(chunks, string.format("%dm", math.floor(dist + 0.5)))
				end
				if Esp.healthText then
					table.insert(chunks, string.format("%.0f/%.0f", entry.hum.Health, entry.hum.MaxHealth))
				end
				label.Text = table.concat(chunks, " · ")
				label.TextColor3 = Esp.color
				label.Visible = true
				label.TextSize = dist > 600 and 12 or 13
				label.Position = UDim2.fromOffset((minX + maxX) * 0.5, minY - 18)
				label.Size = UDim2.fromOffset(math.max(90, (maxX - minX) + 10), 16)
			else
				label.Visible = false
			end
		end

		for i = lineIdx, #linePool do
			linePool[i].Visible = false
		end
		for i = textIdx, #textPool do
			textPool[i].Visible = false
		end
		for i = barIdx, #barBgPool do
			barBgPool[i].Visible = false
			barFillPool[i].Visible = false
		end
	end)
end

function Esp:ensureGui()
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

	local totalLines = MAX_TARGETS * LINES_PER_TARGET
	for i = 1, totalLines do
		linePool[i] = makeLine(overlay)
	end
	for i = 1, MAX_TARGETS do
		textPool[i] = makeText(overlay)
		barBgPool[i] = makeBar(overlay, 1)
		barFillPool[i] = makeBar(overlay, 2)
	end

	overlay.Destroying:Connect(function()
		if heartbeatConn then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
	end)

	self:bootLoop()
end

function Esp:setMaster(on)
	self.master = on
	self:ensureGui()
	if not on then
		hideAll()
	end
end

function Esp:destroy()
	self.master = false
	stopLoop()
	destroyOverlay()
	cleanupOverlayGui()
end

-- ---------- UI ----------
cleanupOverlayGui()

local Prism = loadPrism()
Prism.ReduceMotion = true
Prism.Sounds = false
if Prism._unloadAll then
	Prism:_unloadAll()
end

local Window = Prism:CreateWindow({
	Title = "Fust",
	Subtitle = "visuals",
	Intro = false,
	ToggleKey = Enum.KeyCode.RightControl,
	Size = Vector2.new(580, 460),
})

local espTab = Window:Tab({ Name = "ESP", Icon = "eye", Description = "Player overlays" })

local mainSec = espTab:Section({ Name = "Master", Icon = "toggle-right", Side = "Left" })

local holdOn = false
local toggleOn = false

local function syncMaster()
	Esp:setMaster(holdOn or toggleOn)
end

mainSec:Toggle({
	Name = "ESP (toggle)",
	Description = "Always on while enabled",
	Default = false,
	Flag = "Fust_EspToggle",
	Callback = function(v)
		toggleOn = v
		syncMaster()
	end,
})

mainSec:Toggle({
	Name = "ESP (hold)",
	Description = "Hold key — right-click row to rebind",
	Default = false,
	Flag = "Fust_EspHold",
	Mode = "Hold",
	Keybind = Enum.KeyCode.X,
	Callback = function(v)
		holdOn = v
		syncMaster()
	end,
})

local featSec = espTab:Section({ Name = "Features", Icon = "users", Side = "Left" })

featSec:Slider({
	Name = "Max distance",
	Description = "How far away (studs) players can be",
	Min = 100,
	Max = 5000,
	Default = 2500,
	Increment = 50,
	Suffix = " st",
	Flag = "Fust_EspRange",
	Callback = function(v)
		Esp.maxDist = v
	end,
})

featSec:Toggle({ Name = "Box ESP", Default = true, Flag = "Fust_EspBox", Callback = function(v)
	Esp.box = v
end })
featSec:Toggle({ Name = "Skeleton ESP", Default = true, Flag = "Fust_EspSkel", Callback = function(v)
	Esp.skeleton = v
end })
featSec:Toggle({ Name = "Name", Default = true, Flag = "Fust_EspName", Callback = function(v)
	Esp.name = v
end })
featSec:Toggle({ Name = "Distance", Default = true, Flag = "Fust_EspDist", Callback = function(v)
	Esp.distance = v
end })
featSec:Toggle({ Name = "Health bar", Description = "Side bar; hidden only inside 35 studs", Default = true, Flag = "Fust_EspHpBar", Callback = function(v)
	Esp.healthBar = v
end })
featSec:Toggle({ Name = "Health text", Default = false, Flag = "Fust_EspHpTxt", Callback = function(v)
	Esp.healthText = v
end })

featSec:ColorPicker({
	Name = "ESP colour",
	Default = Color3.fromRGB(235, 235, 235),
	Flag = "Fust_EspCol",
	Callback = function(c)
		Esp.color = c
	end,
})

local sysSec = espTab:Section({ Name = "Script", Icon = "power", Side = "Right" })

sysSec:Button({
	Name = "Unload",
	Description = "Removes UI + ESP completely",
	Icon = "trash-2",
	Hold = 1.2,
	HoldText = "Hold to unload...",
	Callback = function()
		Window:Unload()
	end,
})

Window:OnUnload(function()
	Esp:destroy()
end)

Esp:ensureGui()

local env = (getgenv and getgenv()) or _G
env.__FustEsp = Esp
