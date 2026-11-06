# gangstanigletshit

Fust Survival scripts — **split modules** + one bootstrap loader (lua-bundle style).

## Repo layout

| Path | Purpose |
|------|---------|
| `manifest.luau` | Lists module paths on `main` — change here when you add files |
| `loader/bootstrap.luau` | Fetches manifest + each module via HttpGet |
| `modules/prism_ui.luau` | Prism UI library |
| `modules/fust_esp.luau` | ESP logic only |
| `modules/fust_aim.luau` | Aim assist / snap only |
| `modules/fust_shell.luau` | Menu tabs wiring (ESP + Aim) |
| `AVOID.md` | Anti-cheat notes |

Push updates to **one module** on GitHub; re-run bootstrap in-game to pull fresh copies without touching the others.

## Run in-game (executor thread **8**)

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/ImWozzie/gangstanigletshit/main/loader/bootstrap.luau"))()
```

Or MCP / local file:

`loader/bootstrap.luau`

Re-running unloads the previous bundle and reloads all modules from GitHub.

## Local dev (no GitHub)

Execute in order on thread 8:

1. `modules/prism_ui.luau`
2. `modules/fust_esp.luau` → factory with deps
3. … use a local stub or temporarily point `manifest.luau` repo to raw paths

For day-to-day edits, use **`loader/bootstrap.luau`** after pushing the module you changed.

## Menu

- **Right Control** — open UI  
- **ESP** / **Aim** tabs — see `AVOID.md` before enabling aim features  

## Legacy

`fust_prism_base_esp.luau` (monolith) is deprecated — use the bundle loader instead.
