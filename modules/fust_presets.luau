-- One-shot external.wtf parity — enables every shipped feature (no conservative caps).
return function(deps)
	local Aim = deps.Aim
	local Esp = deps.Esp
	local World = deps.World
	local Misc = deps.Misc
	local Exploit = deps.Exploit

	local Presets = {}

	local function allWorldToggles(on)
		if not World or not World.toggles then
			return
		end
		for k in pairs(World.toggles) do
			World.toggles[k] = on
		end
	end

	function Presets:applyExternalFull()
		if Esp then
			if Esp.applyExternalVisualPreset then
				Esp:applyExternalVisualPreset()
			end
			Esp.master = true
			Esp.tracers = true
			Esp.boxFill = true
			Esp.teamCheck = true
			Esp.distanceFade = true
			Esp.visibleCheck = true
			Esp.healthText = true
			Esp.maxDist = 5000
			Esp.rate = 30
			Esp:setMaster(true)
		end

		if Aim then
			if Aim.applyExternalCombatPreset then
				Aim:applyExternalCombatPreset()
			end
			Aim.aimbotEnabled = true
			Aim.lockAssist = true
			Aim.hitScanEdgeAim = true
			Aim.hitScanKeepPart = 0.45
			Aim.hitScanMultiPoint = true
			Aim.hitScanLimbs = true
			Aim.showManipHud = true
			Aim.visibleCheck = true
			Aim.triggerEnabled = true
			Aim:syncBind()
		end

		if World then
			World.maxDist = 1200
			World.nodeMaxDist = 500
			World.showNodeHp = true
			World.rate = 20
			allWorldToggles(true)
			if World.applyExternalWorldEspPreset then
				World:applyExternalWorldEspPreset()
			else
				World:setEsp(true)
			end
			World.customLight = true
			World.lightBrightness = 2
			World.lightClock = 14
			World.lightExposure = 0.35
			World.lightContrast = 0.15
			World.noFog = true
			World.lightAmbient = Color3.fromRGB(180, 175, 200)
			if World.syncCustomLight then
				World:syncCustomLight()
			end
		end

		if Misc then
			Misc.noRecoil = true
			Misc.noSpread = true
			Misc.recoilScale = 0
			Misc.spreadScale = 0
			Misc.gunAuto = true
			Misc.gunRapid = true
			Misc.hitboxEnabled = true
			Misc.speedEnabled = true
			Misc.farmEnabled = false
			Misc.killEnabled = false
			Misc:syncRecoilMods()
			Misc:syncGunMods()
			Misc:syncHitbox()
			Misc:syncSpeed()
		end

		if Exploit then
			Exploit.trueSilent = true
			Exploit.wallManip = true
			Exploit.wallManipStuds = 5
			Exploit.swingRedirect = true
			if Exploit.syncHook then
				Exploit:syncHook()
			end
		end
	end

	return Presets
end
