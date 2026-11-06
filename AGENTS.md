# AGENTS.md — Fust bundle (for Cursor / other coding agents)

This repo is a **Roblox executor script bundle** for **Fust Survival** (`placeId` live alpha). It is **not** a normal Roblox Studio game project. Agents should treat **`AVOID.md`** as hard constraints and this file as architecture + workflow.

---

## What we are building

A **modular lua-bundle** loaded at runtime via `HttpGet`:

- **Prism UI** menu (`RightControl`)
- **ESP** — PlayerGui 2D overlays (no `Drawing` API)
- **Aimbot tab** — camera-only aim, optional camera “silent” on LMB, triggerbot (higher risk), FOV visuals

GitHub source of truth: **`ImWozzie/gangstanigletshit`** branch **`main`**.

Local edit copy: **`C:\Users\Elliot\Desktop\islands de`**  
Git push clone: **`C:\Users\Elliot\Desktop\gangstanigletshit-push`** (mirror paths, then commit/push)

---

## Directory layout

| Path | Role |
|------|------|
| `manifest.luau` | Returns `{ repo, branch, modules = { prism, esp, aim, shell } }` |
| `loader/bootstrap.luau` | Single entry: HttpGet manifest + modules, wire factories, set globals |
| `modules/prism_ui.luau` | Vendored Prism library (`Prism:CreateWindow`, sections, toggles) |
| `modules/fust_esp.luau` | `return function(deps) → Esp` — ESP only |
| `modules/fust_aim.luau` | `return function(deps) → Aim` — aim/trigger/silent/crosshair only |
| `modules/fust_shell.luau` | `return function(deps) → bundle` — **UI wiring only** (no game logic) |
| `AVOID.md` | Anti-cheat notes — read before aim/ESP changes |
| `README.md` | User-facing run instructions |

**Deprecated:** `fust_prism_base_esp.luau` (monolith). Do not extend; point users to bootstrap.

**Legacy / out of bundle:** `simple_skeleton_esp*.luau`, `islands_*.luau` — do not mix into GitHub modules unless asked.

---

## Module pattern (required)

Every feature module exports a **factory**:

```lua
-- modules/example.luau
return function(deps)
	local Players = deps.Players
	local LOCAL = deps.LocalPlayer

	local Example = { enabled = false }

	function Example:destroy()
		-- disconnect, destroy GUIs
	end

	return Example
end
```

**Bootstrap** builds `deps`, calls factories in order, then shell:

```text
prism → espFactory(deps) → aimFactory(deps) → shellFactory(deps)
```

Shell receives `deps.Esp`, `deps.Aim`, `deps.Prism`, `deps.BundleVersion`.

**Rule:** New gameplay logic goes in **`fust_esp.luau`** or **`fust_aim.luau`**. **`fust_shell.luau`** only creates Prism controls and assigns `Aim.*` / `Esp.*` fields + calls like `Aim:syncBind()`, `Esp:setMaster()`.

---

## Globals after load (executor `getgenv()`)

| Global | Purpose |
|--------|---------|
| `__FustBundle` | `{ Window, Esp, Aim, destroy() }` |
| `__FustEsp` / `__FustAim` | Module instances |
| `__FustBundleVersion` | String, e.g. `2.2.2` |
| `__PrismLibrary` | Prism table |
| `__FustManifest` | Parsed manifest table |

Re-running bootstrap calls `__FustBundle.destroy()` first.

---

## Aim module (`fust_aim.luau`) — current design

**Camera-only.** No hooks on GunControl, remotes, `Raycast`, or metamethods.

| UI section (shell) | Aim fields / behavior |
|--------------------|------------------------|
| Aimbot | `aimbotEnabled`, `prediction`, `targetBones[]`, `smoothing`, `weaponFovPx`, `maxDist` |
| Silent | `silentOn`, `silentFovPx` — multi-step camera snap on **LMB**, not bullet redirect |
| Misc | `drawFov`, `filledFov`, `visibleCheck` (raycast), `visualCheck` (HUD text), `ignoreKnocked`, `ignoreTeam`, `deadzonePx`, `showCrosshair`, `requireAds` |
| Triggerbot | `triggerEnabled`, `triggerBones[]`, `triggerDelayMs` — uses `VirtualInputManager` (mark **Risky** in UI) |
| Keybinds | `aimKey1Held`, `aimKey2Held` (Prism **Hold** toggles), `triggerKeyHeld`, `battleMode` (skips ADS gate) |

**Aimbot runs when:** `aimbotEnabled` **and** (`aimKey1Held` or `aimKey2Held`) **and** `canAim()` (ADS unless `battleMode` or `requireAds` off).

**Sticky target:** `stickyChar` while keys held.

**Render:** `RunService:BindToRenderStep("FustSafeAimAssist", ...)`. Call `Aim:syncBind()` whenever toggles change what needs the loop (shell already does this on most controls).

**Crosshair GUI:** `PlayerGui.FustCrosshair` — frames + FOV ring segments (no Drawing).

When adding features, extend the `Aim` table defaults, implement behavior in `fust_aim.luau`, expose one control per field in `fust_shell.luau`, and bump bundle version (below).

---

## ESP module (`fust_esp.luau`) — constraints

- Overlays live under **local PlayerGui** with attribute `FustBaseEsp = true`
- Heartbeat ~5.5 Hz, capped targets, loop stops when master off
- No highlights on other players’ characters, no Drawing library
- Tunables: box, skeleton LOD, name, distance, health bar + **health bar range slider**

---

## Prism UI (`fust_shell.luau`)

- `Window:Tab`, `Section:Toggle|Slider|Dropdown|ColorPicker|Keybind|Button|Label`
- Toggles: `Flag = "Fust_..."` for persistence; `Mode = "Hold"` + `Keybind = Enum.KeyCode.X` for hold keys
- Multi bone: `Dropdown({ Multi = true, Options = { "Head", "Neck", ... } })`
- Risky features: `Risky = true` on toggle
- Unload: `Window:OnUnload` → `bundle.destroy()`
- In-menu refresh: **ESP → Script → Refresh from GitHub** (re-HttpGet bootstrap)

Match existing naming: section titles like **Aimbot**, **Misc options**, **Triggerbot**, **Keybinds**.

---

## Versioning & cache bust (mandatory on every GitHub push)

Roblox **`game:HttpGet`** caches raw GitHub URLs.

1. Bump **`BUNDLE_VERSION`** in `loader/bootstrap.luau`
2. Match default in `modules/fust_shell.luau` (`deps.BundleVersion or "x.y.z"`)
3. Bootstrap already appends `?v=BUNDLE_VERSION` to **manifest** and **each module** URL

Tell users to load with bootstrap cache bust when needed:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ImWozzie/gangstanigletshit/main/loader/bootstrap.luau?v=2.2.2"))()
```

Console should print: `[FustBundle] loaded aimbot X.Y.Z (GitHub main)`.

---

## Git workflow for agents

1. Edit files under **`islands de`**
2. Copy changed files into **`gangstanigletshit-push`** (same relative paths):

   ```powershell
   Copy-Item -Force "C:\Users\Elliot\Desktop\islands de\loader\bootstrap.luau" "C:\Users\Elliot\Desktop\gangstanigletshit-push\loader\"
   Copy-Item -Force "C:\Users\Elliot\Desktop\islands de\modules\*.luau" "C:\Users\Elliot\Desktop\gangstanigletshit-push\modules\"
   Copy-Item -Force "C:\Users\Elliot\Desktop\islands de\manifest.luau" "C:\Users\Elliot\Desktop\gangstanigletshit-push\"
   ```

3. Commit with `-c user.name=ImWozzie -c user.email=ImWozzie@users.noreply.github.com` (do **not** `git config` globally)
4. `git push origin main`
5. User reloads in-game (bootstrap or Refresh button)

**Only commit when the user asks** (per project rules).

If adding a new module file: update **`manifest.luau`**, **`DEFAULT_MANIFEST`** in bootstrap, and load order in bootstrap.

---

## In-game testing (MCP)

Use **roblox-mcp** / **roblox-executor-mcp**:

- **`list-clients`** → pass `clientId` on calls
- Run bootstrap on **thread context 8** (thread 2 breaks Prism `cloneref`)
- Prefer `execute-file` with local `loader/bootstrap.luau` for dev; verify GitHub with HttpGet + version query
- After unload test: destroy `__FustBundle`, optional `_unloadAll()` on Prism, then re-run bootstrap

Verify: `__FustBundleVersion`, Aim fields (e.g. `weaponFovPx`), menu tab **Aimbot** (not legacy **Aim** layout).

---

## Hard “do not” list (see `AVOID.md` for detail)

- True silent aim / spoofed shoot remotes / GunControl hooks
- `Drawing.new` ESP, RenderStepped spam, editing other players’ rigs
- Disabling FustAnimShield / CharSync / character AC scripts
- Mimicking staff `Highlight` / `FustESPOutlines` pipeline

**Allowed “silent” in this repo:** temporary **camera** alignment on fire inside FOV — still visible to server-side aim checks; keep strength/FOV conservative.

---

## Common agent mistakes

| Mistake | Fix |
|---------|-----|
| UI in aim/ esp logic files | Move controls to `fust_shell.luau` only |
| Push without version bump | User keeps stale HttpGet cache |
| Forgot `Aim:syncBind()` on toggle | Render step never runs |
| Aimbot “does nothing” | Need **enabled** + **hold aim key** + ADS (or battlemode / require ADS off) |
| Edit only local folder, no push | User runs GitHub loader — changes invisible |
| `AVOID.md` aim table outdated | Trust this AGENTS.md + `fust_aim.luau` for current features |

---

## Checklist: ship a aim/ESP change

- [ ] Logic in correct module; shell wires flags/sliders
- [ ] `destroy()` / `unbind()` cleans connections and GUIs
- [ ] AC notes considered (`AVOID.md`)
- [ ] `BUNDLE_VERSION` bumped in bootstrap + shell footer default
- [ ] Files copied to `gangstanigletshit-push` and pushed to `main`
- [ ] User told bootstrap URL with `?v=` or in-menu Refresh

---

Last aligned with bundle **v2.2.2** — update this file when architecture or entrypoints change.
