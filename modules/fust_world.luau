-- Client lighting / time (local Lighting tweaks). factory(deps) -> World
return function(deps)
	local Lighting = game:GetService("Lighting")
	local RunService = deps.RunService

	local World = {
		fullbrightOn = false,
		timeControlOn = false,
		clockTime = 14,
		brightness = 2,
		saved = nil,
		loopConn = nil,
	}

	local function capture()
		if World.saved then
			return
		end
		World.saved = {
			Ambient = Lighting.Ambient,
			OutdoorAmbient = Lighting.OutdoorAmbient,
			Brightness = Lighting.Brightness,
			GlobalShadows = Lighting.GlobalShadows,
			ClockTime = Lighting.ClockTime,
			GeographicLatitude = Lighting.GeographicLatitude,
		}
	end

	function World:restore()
		local s = self.saved
		if not s then
			return
		end
		Lighting.Ambient = s.Ambient
		Lighting.OutdoorAmbient = s.OutdoorAmbient
		Lighting.Brightness = s.Brightness
		Lighting.GlobalShadows = s.GlobalShadows
		Lighting.ClockTime = s.ClockTime
		Lighting.GeographicLatitude = s.GeographicLatitude
		self.saved = nil
	end

	function World:applyFullbright()
		if not self.fullbrightOn then
			if not self.timeControlOn then
				self:restore()
			else
				Lighting.GlobalShadows = true
				Lighting.Brightness = 1
			end
			return
		end
		capture()
		Lighting.Ambient = Color3.fromRGB(255, 255, 255)
		Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
		Lighting.Brightness = self.brightness
		Lighting.GlobalShadows = false
	end

	function World:applyTime()
		if not self.timeControlOn then
			if not self.fullbrightOn then
				self:restore()
			end
			return
		end
		capture()
		Lighting.ClockTime = self.clockTime
	end

	function World:sync()
		self:applyFullbright()
		self:applyTime()
		if self.fullbrightOn or self.timeControlOn then
			self:ensureLoop()
		else
			self:stopLoop()
		end
	end

	function World:ensureLoop()
		if self.loopConn then
			return
		end
		self.loopConn = RunService.Heartbeat:Connect(function()
			if self.fullbrightOn then
				Lighting.Ambient = Color3.fromRGB(255, 255, 255)
				Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
				Lighting.Brightness = self.brightness
				Lighting.GlobalShadows = false
			end
			if self.timeControlOn then
				Lighting.ClockTime = self.clockTime
			end
		end)
	end

	function World:stopLoop()
		if self.loopConn then
			self.loopConn:Disconnect()
			self.loopConn = nil
		end
	end

	function World:destroy()
		self.fullbrightOn = false
		self.timeControlOn = false
		self:stopLoop()
		self:restore()
	end

	return World
end
