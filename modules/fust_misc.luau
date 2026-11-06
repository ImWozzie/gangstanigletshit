-- Farming helpers. factory(deps) -> Misc
-- Auto WeakSpot hit is DISABLED. Instant lookAt (v2.6.0) and mousemoverel+auto-click
-- (v2.6.2) both led to Multihack bans on clean alts (2026-11-06). Do not re-enable
-- automated gather aim/click without a confirmed safe path.
return function(deps)
	local Misc = {
		autoWeak = false,
		primeFresh = false,
		maxDist = 8.5,
		aimDeadzonePx = 18,
		aimCapDeg = 4.5,
		swingCdMs = 420,
		requireTool = true,
		nodeTypes = { "tree", "stone", "metal", "sulfur" },
		bound = false,
		disabledReason = "Auto WeakSpot banned Multihack — instant lookAt and mouse-drive+click both flagged (2026-11-06)",
	}

	function Misc:syncBind()
		self.autoWeak = false
		self.bound = false
	end

	function Misc:setNodeTypes(list)
		if type(list) == "table" then
			self.nodeTypes = list
		end
	end

	function Misc:bind()
		-- no-op
	end

	function Misc:unbind()
		self.bound = false
	end

	function Misc:destroy()
		self.autoWeak = false
		self:unbind()
	end

	return Misc
end
