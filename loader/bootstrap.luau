--[[
  Fust bundle loader — pulls separate modules from GitHub (lua-bundle style).
  Run once in executor (thread 8 recommended):

  loadstring(game:HttpGet("https://raw.githubusercontent.com/ImWozzie/gangstanigletshit/main/loader/bootstrap.luau"))()

  Re-run to refresh all modules from GitHub. Update only esp/aim/shell/prism on GitHub independently.
]]

local MANIFEST_URL = "https://raw.githubusercontent.com/ImWozzie/gangstanigletshit/main/manifest.luau"

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
	local url = rawUrl(repo, branch, path)
	local body = httpGet(url)
	if not body then
		error("[FustBundle] HttpGet failed: " .. url)
	end
	return loadChunk(body, label or path)
end

local manifestSource = httpGet(MANIFEST_URL)
if not manifestSource then
	error("[FustBundle] Could not fetch manifest: " .. MANIFEST_URL)
end
local manifest = loadChunk(manifestSource, "manifest")

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
local shellFactory = loadModule(repo, branch, paths.shell, "shell")

local Esp = espFactory(deps)
local Aim = aimFactory(deps)
deps.Esp = Esp
deps.Aim = Aim

local bundle = shellFactory(deps)

env.__PrismLibrary = Prism
env.__FustEsp = Esp
env.__FustAim = Aim
env.__FustBundle = bundle
env.__FustManifest = manifest

return bundle
