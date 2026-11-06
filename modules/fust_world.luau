-- Client visuals / time. factory(deps) -> World
-- FustSky reports (Remotes.MotionSync) when Lighting / Atmosphere / ClockTime end up
-- brighter than it set them, so fullbright must not touch Lighting at all.
return function(deps)
	local Lighting = game:GetService("Lighting")
	local RunService = deps.RunService

	local World = {
		fullbrightOn = false,
		brightness = 0.25,
		timeControlOn = false,
		clockTime = 14,
		grade = nil,
		camConn = nil,
		timeConn = nil,
	}

	local function placeGrade()
		local grade = World.grade
		local cam = workspace.CurrentCamera
		if grade and cam and grade.Parent ~= cam then
			grade.Parent = cam
		end
	end

	function World:applyFullbright()
		if not self.fullbrightOn then
			if self.grade then
				self.grade:Destroy()
				self.grade = nil
			end
			if self.camConn then
				self.camConn:Disconnect()
				self.camConn = nil
			end
			return
		end
		if not self.grade then
			local grade = Instance.new("ColorCorrectionEffect")
			grade.Name = "ColorCorrection"
			self.grade = grade
		end
		self.grade.Brightness = self.brightness
		self.grade.Contrast = -self.brightness * 0.35
		self.grade.Saturation = 0
		self.grade.Enabled = true
		placeGrade()
		if not self.camConn then
			self.camConn = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(placeGrade)
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
		self:sync()
	end

	return World
end
