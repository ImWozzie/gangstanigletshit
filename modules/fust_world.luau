-- Client visuals / time. factory(deps) -> World
-- Fullbright writes Lighting (real brightness). FustSky rewrites Ambient/etc on
-- Heartbeat, so we re-apply on RenderStepped Last each frame to stop strobing.
-- FustSky still detects brighter-than-wanted values and may report via MotionSync
-- after ~3s while ACM is on — marked Risky in the UI.
return function(deps)
	local Lighting = game:GetService("Lighting")
	local RunService = deps.RunService

	local FB_STEP = "FustFullbright"

	local World = {
		fullbrightOn = false,
		brightness = 2,
		timeControlOn = false,
		clockTime = 14,
		saved = nil,
		fbBound = false,
		timeConn = nil,
	}

	local function capture()
		if World.saved then
			return
		end
		World.saved = {
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			Brightness = Lighting.Brightness,
			ExposureCompensation = Lighting.ExposureCompensation,
			GlobalShadows = Lighting.GlobalShadows,
			ClockTime = Lighting.ClockTime,
		}
	end

	local function restoreLighting()
		local s = World.saved
		if not s then
			return
		end
		Lighting.Ambient = s.Ambient
		Lighting.OutdoorAmbient = s.OutdoorAmbient
		Lighting.Brightness = s.Brightness
		Lighting.ExposureCompensation = s.ExposureCompensation
		Lighting.GlobalShadows = s.GlobalShadows
		World.saved = nil
	end

	local function paintFullbright()
		local b = math.clamp(World.brightness, 0.5, 8)
		-- Flat ambient so night geometry actually lights up (not a post filter).
		Lighting.Ambient = Color3.fromRGB(180, 180, 190)
		Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 210)
		Lighting.Brightness = b
		Lighting.ExposureCompensation = math.clamp((b - 1) * 0.35, 0, 1.2)
		Lighting.GlobalShadows = false
	end

	local function unbindFullbright()
		if World.fbBound then
			pcall(function()
				RunService:UnbindFromRenderStep(FB_STEP)
			end)
			World.fbBound = false
		end
	end

	local function bindFullbright()
		if World.fbBound then
			return
		end
		World.fbBound = true
		-- After Heartbeat (where FustSky writes) so the rendered frame stays bright.
		RunService:BindToRenderStep(FB_STEP, Enum.RenderPriority.Last.Value, function()
			if not World.fullbrightOn then
				return
			end
			paintFullbright()
		end)
	end

	function World:applyFullbright()
		if not self.fullbrightOn then
			unbindFullbright()
			restoreLighting()
			return
		end
		capture()
		paintFullbright()
		bindFullbright()
	end

	function World:applyTime()
		if not self.timeControlOn then
			if self.timeConn then
				self.timeConn:Disconnect()
				self.timeConn = nil
			end
			return
		end
		capture()
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
		unbindFullbright()
		if self.timeConn then
			self.timeConn:Disconnect()
			self.timeConn = nil
		end
		restoreLighting()
	end

	return World
end
