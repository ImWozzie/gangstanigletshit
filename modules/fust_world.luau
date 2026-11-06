-- Client visuals / time. factory(deps) -> World
-- FustSky reports when Lighting Ambient / Brightness / Exposure / thin Atmosphere
-- end up brighter than it wants — so fullbright uses local PointLights on a
-- camera-follow part (real illumination) instead of writing Lighting.
return function(deps)
	local Lighting = game:GetService("Lighting")
	local RunService = deps.RunService

	local World = {
		fullbrightOn = false,
		brightness = 8,
		range = 500,
		timeControlOn = false,
		clockTime = 14,
		lightPart = nil,
		lights = {},
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
		if World.lightPart then
			World.lightPart:Destroy()
			World.lightPart = nil
		end
		table.clear(World.lights)
	end

	local function ensureLights()
		if World.lightPart and World.lightPart.Parent then
			return
		end
		destroyLights()

		local part = Instance.new("Part")
		part.Name = "FustFBAnchor"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.Size = Vector3.new(0.2, 0.2, 0.2)
		part.Parent = workspace.CurrentCamera or workspace
		World.lightPart = part

		local function addPoint(name, brightnessScale, rangeScale)
			local light = Instance.new("PointLight")
			light.Name = name
			light.Shadows = false
			light.Color = Color3.new(1, 1, 1)
			light.Brightness = World.brightness * brightnessScale
			light.Range = World.range * rangeScale
			light.Parent = part
			World.lights[#World.lights + 1] = light
			return light
		end

		-- Three overlapping lights so mid/far geometry actually gets lit.
		addPoint("Near", 1.1, 0.45)
		addPoint("Mid", 0.85, 0.85)
		addPoint("Far", 0.55, 1.25)

		World.followConn = RunService.RenderStepped:Connect(function()
			local cam = workspace.CurrentCamera
			local anchor = World.lightPart
			if not cam or not anchor then
				return
			end
			if anchor.Parent ~= cam then
				anchor.Parent = cam
			end
			anchor.CFrame = cam.CFrame
		end)

		World.camConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
			local cam = workspace.CurrentCamera
			if cam and World.lightPart then
				World.lightPart.Parent = cam
			end
		end)
	end

	local function tuneLights()
		for i, light in ipairs(World.lights) do
			local scaleB = (i == 1 and 1.1) or (i == 2 and 0.85) or 0.55
			local scaleR = (i == 1 and 0.45) or (i == 2 and 0.85) or 1.25
			light.Brightness = World.brightness * scaleB
			light.Range = World.range * scaleR
			light.Enabled = true
		end
	end

	function World:applyFullbright()
		if not self.fullbrightOn then
			destroyLights()
			return
		end
		ensureLights()
		tuneLights()
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
