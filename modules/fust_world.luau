-- Client visuals / time. factory(deps) -> World
-- FustSky reports Lighting Ambient/Brightness/Exposure rises, so fullbright does
-- not write Lighting. Roblox clamps PointLight.Range to 120 — a ring of lights
-- around the camera covers a much larger volume with real illumination.
return function(deps)
	local Lighting = game:GetService("Lighting")
	local RunService = deps.RunService

	local RING = {
		Vector3.new(0, 0, 0),
		Vector3.new(90, 0, 0),
		Vector3.new(-90, 0, 0),
		Vector3.new(0, 0, 90),
		Vector3.new(0, 0, -90),
		Vector3.new(0, 50, 0),
		Vector3.new(0, -20, 0),
		Vector3.new(70, 30, 70),
		Vector3.new(-70, 30, -70),
		Vector3.new(70, 30, -70),
		Vector3.new(-70, 30, 70),
	}

	local World = {
		fullbrightOn = false,
		brightness = 12,
		timeControlOn = false,
		clockTime = 14,
		folder = nil,
		anchors = {},
		followConn = nil,
		camConn = nil,
		timeConn = nil,
	}

	local function destroyLights()
		if World.followConn then
			World.followConn:Disconnect()
			World.followConn = nil
		end
		if World.camConn then
			World.camConn:Disconnect()
			World.camConn = nil
		end
		if World.folder then
			World.folder:Destroy()
			World.folder = nil
		end
		table.clear(World.anchors)
	end

	local function ensureLights()
		if World.folder and World.folder.Parent then
			return
		end
		destroyLights()

		local folder = Instance.new("Folder")
		folder.Name = "FustFBLights"
		folder.Parent = workspace.CurrentCamera or workspace
		World.folder = folder

		for i, offset in ipairs(RING) do
			local part = Instance.new("Part")
			part.Name = "FB" .. i
			part.Anchored = true
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = 1
			part.Size = Vector3.new(0.2, 0.2, 0.2)
			part.Parent = folder

			local light = Instance.new("PointLight")
			light.Name = "Light"
			light.Shadows = false
			light.Color = Color3.new(1, 1, 1)
			light.Brightness = World.brightness
			light.Range = 120
			light.Parent = part

			World.anchors[#World.anchors + 1] = { part = part, light = light, offset = offset }
		end

		World.followConn = RunService.RenderStepped:Connect(function()
			local cam = workspace.CurrentCamera
			local fold = World.folder
			if not cam or not fold then
				return
			end
			if fold.Parent ~= cam then
				fold.Parent = cam
			end
			local cf = cam.CFrame
			for _, a in ipairs(World.anchors) do
				a.part.CFrame = cf * CFrame.new(a.offset)
			end
		end)

		World.camConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			local cam = workspace.CurrentCamera
			if cam and World.folder then
				World.folder.Parent = cam
			end
		end)
	end

	function World:applyFullbright()
		if not self.fullbrightOn then
			destroyLights()
			return
		end
		ensureLights()
		local b = math.clamp(self.brightness, 0.5, 40)
		for _, a in ipairs(self.anchors) do
			a.light.Brightness = b
			a.light.Range = 120
			a.light.Enabled = true
		end
	end

	function World:applyTime()
		if not self.timeControlOn then
			if self.timeConn then
				self.timeConn:Disconnect()
				self.timeConn = nil
			end
			return
		end
		Lighting.ClockTime = self.clockTime
		if not self.timeConn then
			self.timeConn = RunService.Heartbeat:Connect(function()
				if Lighting.ClockTime ~= self.clockTime then
					Lighting.ClockTime = self.clockTime
				end
			end)
		end
	end

	function World:sync()
		self:applyFullbright()
		self:applyTime()
	end

	function World:destroy()
		self.fullbrightOn = false
		self.timeControlOn = false
		self:applyTime()
		destroyLights()
	end

	return World
end
