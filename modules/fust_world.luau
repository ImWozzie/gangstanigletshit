-- Client visuals / time. factory(deps) -> World
-- Lighting fullbright is DISABLED. Writing Ambient/Brightness while ACM is on
-- got a permanent "Cheating" ban (2026-11-06, MotionSync lt report → staff/auto).
-- Do not re-enable Lighting paints without a confirmed safe path.
return function(deps)
	local Lighting = game:GetService("Lighting")
	local RunService = deps.RunService

	local World = {
		fullbrightOn = false,
		brightness = 2,
		timeControlOn = false,
		clockTime = 14,
		timeConn = nil,
		disabledReason = "Lighting fullbright banned — FustSky ACM reports brighter Ambient/Brightness via MotionSync",
	}

	function World:applyFullbright()
		-- Intentionally a no-op. See knowledge.md incident 2026-11-06 14:01.
		self.fullbrightOn = false
	end

	function World:applyTime()
		if not self.timeControlOn then
			if self.timeConn then
				self.timeConn:Disconnect()
				self.timeConn = nil
			end
			return
		end
		-- Time changer still risky (daylight rise is reported). Keep off by default in UI.
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
		if self.timeConn then
			self.timeConn:Disconnect()
			self.timeConn = nil
		end
	end

	return World
end
