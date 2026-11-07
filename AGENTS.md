# AGENTS.md — Fust Hub bundle (Cursor / agents)

Executor **lua-bundle** for **Fust Survival** live alpha. Loaded at runtime via `game:HttpGet` → `loader/bootstrap.luau`. This is **not** a Roblox Studio game repo.

**GitHub:** `ImWozzie/gangstanigletshit` · `main`  
**Local edit:** `C:\Users\Elliot\Desktop\islands de`  
**Push clone:** `C:\Users\Elliot\Desktop\gangstanigletshit-push` (mirror paths, commit, push)

Design goal: **feature parity with external.wtf-class menus** (Drawing ESP/FOV, Shoot redirect, gun VM edits, custom lighting, full world ESP). High ban risk — user opts in.

---

## Directory layout

| Path | Role |
|------|------|
| `manifest.luau` | `{ repo, branch, modules = { … } }` |
| `loader/bootstrap.luau` | HttpGet manifest + modules, wire factories, globals |
| `modules/prism_ui.luau` | Vendored Prism UI |
| `modules/fust_esp.luau` | Player ESP — **Drawing** primary, PlayerGui fallback |
| `modules/fust_aim.luau` | Aimbot, hitscan/manip HUD, combat tracers, **Drawing FOV** |
| `modules/fust_world.luau` | World ESP (PlayerGui), custom lighting, freecam/tp3/zoom |
| `modules/fust_misc.luau` | No recoil/spread (filtergc gun table), gun auto/rapid, hitbox, speed, farm/kill |
| `modules/fust_exploit.luau` | **True silent** (`Shoot` dir/origin), wall manip, `Swing` redirect (`__namecall`) |
| `modules/fust_presets.luau` | `Presets:applyExternalFull()` — one-shot external stack |
| `modules/fust_shell.luau` | **UI only** — wires modules, panic, configs |
| `knowledge.md` | Game folders, FustWear, world paths |
| `README.md` | User load instructions |

**Deprecated:** `fust_prism_base_esp.luau` monolith.  
**Legacy:** `simple_skeleton_esp*`, `islands_*` — do not merge unless asked.

---

## Bootstrap load order

```text
Prism → Esp → Aim → World → Misc → Exploit → Presets → Shell
```

Each feature module: `return function(deps) … return Module end`.

**Shell rule:** gameplay logic only in feature modules; `fust_shell.luau` creates Prism controls and assigns fields + `syncBind()` / `syncHook()` / `setMaster()`.

---

## Globals (`getgenv()`)

| Global | Purpose |
|--------|---------|
| `__FustBundle` | `{ Window, Esp, Aim, World, Misc, Exploit, Presets, destroy(), panic() }` |
| `__FustEsp` / `__FustAim` / `__FustWorld` / `__FustMisc` / `__FustExploit` / `__FustPresets` | Module instances |
| `__FustBundleVersion` | e.g. `2.16.0` |
| `__PrismLibrary` / `__FustManifest` | Prism table, parsed manifest |

Re-run bootstrap calls `__FustBundle.destroy()` first (Exploit hook removed).

---

## external.wtf parity map

| Their stack | Our module |
|-------------|------------|
| Drawing corner ESP + fill + skeleton + weapon line labels | `fust_esp` — `useDrawing`, `labelStyle = "External"`, `applyExternalVisualPreset()` |
| Pink FOV ring (240px) | `fust_aim` — `fovUseDrawing`, `fovRingColor` |
| Hit scan, edge aim, keep part 45%, manip 5, MANIP % HUD, combat tracers | `fust_aim` — `applyExternalCombatPreset()` |
| True silent + wall peek origin | `fust_exploit` |
| No recoil/spread, gun auto/rapid | `fust_misc` |
| World loot ESP + brightness/time lighting | `fust_world` |
| Full load button | Settings → **external.wtf — LOAD EVERYTHING** → `Presets:applyExternalFull()` |

Still not cloned: their HiddenUI chrome, cloud configs, staff panel, exact watermark string. Prism has its own watermark.

---

## DO NOT TOUCH (game client — never sabotage shield)

These are **off limits** when scripting against the live game. Violating them breaks integrity handshakes or impersonates staff — not “more features.”

- **Do not disable, destroy, or patch** `FustAnimShield`, `FustCharSync`, `FustShieldGate`, or the workspace character AC `LocalScript`.
- **Do not block, ignore, or spoof** telemetry remotes to hide cheats: `LookPitch`, `MotionSync`, `FpsProbe`, `CharSync` payloads.
- **Do not parent** Highlights, beams, or attachments to **other players’ characters** (staff pipeline uses `Highlight` + `workspace.FustESPOutlines` — do not mimic).

**Not forbidden (external.wtf uses these — shipped in this bundle):**

- `Drawing.new` ESP / FOV / world overlays  
- `hookmetamethod` / `__namecall` on `ReplicatedStorage.Fust.Remotes.Shoot` / `Swing`  
- `filtergc` edits on gun VM tables (recoil/spread)  
- Custom `Lighting` / time / fog (ACM `{lt}` risk — user accepts)  
- Triggerbot / VirtualInput, hitbox expand, speed, wall manip studs  

---

## Module notes

### ESP (`fust_esp.luau`)

- Default **`useDrawing`** when executor provides Drawing API.  
- **`labelStyle "External"`**: `80MC (@user) - W [114.2m]` style (money from leaderstats/attributes).  
- Corner length **8px**, fill **0.14**, pink default color.  
- PlayerGui fallback if no Drawing. No highlights on enemy rigs.

### Aim (`fust_aim.luau`)

- Camera + mouse lock; hitscan skips lead.  
- **`fust_exploit`** owns bullet redirect — aim module picks targets only.

### Exploit (`fust_exploit.luau`)

- Requires `hookmetamethod`, `newcclosure`, `getnamecallmethod`.  
- `destroy()` / panic clears hook.

---

## Versioning (every GitHub push)

1. Bump `BUNDLE_VERSION` in `loader/bootstrap.luau`  
2. Match `deps.BundleVersion or "x.y.z"` in `fust_shell.luau`  
3. Bootstrap appends `?v=BUNDLE_VERSION` to manifest + module URLs  

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ImWozzie/gangstanigletshit/main/loader/bootstrap.luau?v=2.16.0"))()
```

Console: `[FustBundle] loaded aimbot X.Y.Z (GitHub main)`.

---

## Git workflow

```powershell
Copy-Item -Force "C:\Users\Elliot\Desktop\islands de\loader\bootstrap.luau" "C:\Users\Elliot\Desktop\gangstanigletshit-push\loader\"
Copy-Item -Force "C:\Users\Elliot\Desktop\islands de\modules\*.luau" "C:\Users\Elliot\Desktop\gangstanigletshit-push\modules\"
Copy-Item -Force "C:\Users\Elliot\Desktop\islands de\manifest.luau" "C:\Users\Elliot\Desktop\gangstanigletshit-push\"
Copy-Item -Force "C:\Users\Elliot\Desktop\islands de\AGENTS.md" "C:\Users\Elliot\Desktop\gangstanigletshit-push\"
```

Commit only when user asks. Use per-commit `-c user.name=ImWozzie -c user.email=ImWozzie@users.noreply.github.com`.

---

## MCP testing

- **Thread 8** for bootstrap (thread 2 breaks Prism `cloneref`).  
- `list-clients` → `clientId` on roblox-mcp calls.

---

## Ship checklist

- [ ] Logic in correct module; shell wires UI only  
- [ ] `destroy()` cleans hooks, Drawing objects, GUIs  
- [ ] `BUNDLE_VERSION` bumped  
- [ ] Copy to push repo + push when requested  

Last aligned: **v2.16.0** — Drawing ESP/FOV, external presets, exploit stack.
