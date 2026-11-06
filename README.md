# gangstanigletshit

Fust Survival client scripts and anti-cheat notes.

## Anti-cheat

Read **[AVOID.md](./AVOID.md)** before running anything in-game.

## ESP + Prism UI

1. Load Prism UI (`prism_ui.luau` from this repo if present, or `loadstring(game:HttpGet("https://raw.githubusercontent.com/VortexHubScripts/TEST/refs/heads/main/TEST"))()`).
2. Execute `fust_prism_base_esp.luau` on **executor thread 8** (not thread 2 — Prism breaks on identity 2).
3. **Right Control** — menu; enable ESP toggle or hold **X**.

Unload via the menu **Script → Unload** (hold).
