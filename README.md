# gangstanigletshit

Fust Survival **Fust Hub** — modular executor bundle (external.wtf-style stack).

## Run (thread **8**)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ImWozzie/gangstanigletshit/main/loader/bootstrap.luau?v=2.16.0"))()
```

Re-run to reload. Use **ESP → Script → Refresh from GitHub** in-menu.

**Right Control** — menu. **Settings → external.wtf — LOAD EVERYTHING** for full preset.

## Modules

| File | Purpose |
|------|---------|
| `loader/bootstrap.luau` | Entry loader |
| `manifest.luau` | Module paths |
| `modules/fust_esp.luau` | Drawing ESP (+ GUI fallback) |
| `modules/fust_aim.luau` | Combat aim, Drawing FOV, tracers |
| `modules/fust_world.luau` | World ESP, lighting |
| `modules/fust_misc.luau` | Gun mods, movement, farm/kill |
| `modules/fust_exploit.luau` | True silent / wall manip hooks |
| `modules/fust_presets.luau` | Full external preset |
| `modules/fust_shell.luau` | Prism UI wiring |
| `modules/prism_ui.luau` | Prism library |

Agent architecture: **`AGENTS.md`**.

## Legacy

`fust_prism_base_esp.luau` is deprecated — use bootstrap.
