--[[
  Fust bundle loader — pulls separate modules from GitHub (lua-bundle style).
  Run once in executor (thread 8 recommended):

  loadstring(game:HttpGet("https://raw.githubusercontent.com/ImWozzie/gangstanigletshit/main/loader/bootstrap.luau"))()

  Re-run to refresh all modules from GitHub. Update only esp/aim/shell/prism on GitHub independently.
]]

local BUNDLE_VERSION = "2.6.2"
local CACHE_BUST = tostring(os.clock()):gsub("%.", "")

local MANIFEST_URL = "https://raw.githubusercontent.com/ImWozzie/gangstanigletshit/main/manifest.luau"

local DEFAULT_MANIFEST = {
	repo = "ImWozzie/gangstanigletshit",
	branch = "main",
	modules = {
		prism = "modules/prism_ui.luau",
		esp = "modules/fust_esp.luau",
		aim = "modules/fust_aim.luau",
		world = "modules/fust_world.luau",
		misc = "modules/fust_misc.luau",
		shell = "modules/fust_shell.luau",
	},
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local function httpGet(url)
	local ok, body = pcall(function()
		return game:HttpGet(url)
	end)
	if ok and type(body) == "string" then
		return body
	end
	return nil
end

local function rawUrl(repo, branch, path)
	return string.format("https://raw.githubusercontent.com/%s/%s/%s", repo, branch, path)
end

local function loadChunk(source, label)
	local fn, err = loadstring(source)
	if not fn then
		error(string.format("[FustBundle] loadstring failed (%s): %s", label, tostring(err)))
	end
	local ok, result = pcall(fn)
	if not ok then
		error(string.format("[FustBundle] run failed (%s): %s", label, tostring(result)))
	end
	return result
end

local function loadModule(repo, branch, path, label)
	local url = rawUrl(repo, branch, path) .. "?v=" .. BUNDLE_VERSION .. "&r=" .. CACHE_BUST
	local body = httpGet(url)
	if not body then
		error("[FustBundle] HttpGet failed: " .. url)
	end
	return loadChunk(body, label or path)
end

local manifest = DEFAULT_MANIFEST
local manifestSource = httpGet(MANIFEST_URL .. "?v=" .. BUNDLE_VERSION)
if manifestSource and not string.find(manifestSource, "404", 1, true) and string.find(manifestSource, "return", 1, true) then
	manifest = loadChunk(manifestSource, "manifest")
end

local repo = manifest.repo
local branch = manifest.branch
local paths = manifest.modules

local env = (getgenv and getgenv()) or _G
if env.__FustBundle and env.__FustBundle.destroy then
	pcall(env.__FustBundle.destroy)
end

local deps = {
	Players = Players,
	RunService = RunService,
	UserInputService = UserInputService,
	LocalPlayer = Players.LocalPlayer,
	BundleVersion = BUNDLE_VERSION,
}

local prismExport = loadModule(repo, branch, paths.prism, "prism")
local Prism = prismExport
if type(prismExport) == "table" and prismExport.CreateWindow then
	Prism = prismExport
elseif type(prismExport) == "function" then
	Prism = prismExport()
end
deps.Prism = Prism

local espFactory = loadModule(repo, branch, paths.esp, "esp")
local aimFactory = loadModule(repo, branch, paths.aim, "aim")
local worldFactory = paths.world and loadModule(repo, branch, paths.world, "world") or nil
local miscFactory = paths.misc and loadModule(repo, branch, paths.misc, "misc") or nil
local shellFactory = loadModule(repo, branch, paths.shell, "shell")

local Esp = espFactory(deps)
local Aim = aimFactory(deps)
local World = worldFactory and worldFactory(deps) or { destroy = function() end, sync = function() end }
local Misc = miscFactory and miscFactory(deps)
	or {
		autoWeak = false,
		destroy = function() end,
		syncBind = function() end,
		setNodeTypes = function() end,
	}
deps.Esp = Esp
deps.Aim = Aim
deps.World = World
deps.Misc = Misc

local bundle = shellFactory(deps)

env.__PrismLibrary = Prism
env.__FustEsp = Esp
env.__FustAim = Aim
env.__FustWorld = World
env.__FustMisc = Misc
env.__FustBundle = bundle
env.__FustManifest = manifest
env.__FustBundleVersion = BUNDLE_VERSION

print("[FustBundle] loaded aimbot " .. BUNDLE_VERSION .. " (GitHub " .. branch .. ")")

return bundle
