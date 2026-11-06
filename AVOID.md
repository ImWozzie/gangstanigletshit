# Fust Survival — client anti-cheat avoidance notes

Use this as a checklist when writing or running executor scripts against **Fust Survival** (FUST client shield). Nothing here guarantees you will not be banned; the heavy logic lives in obfuscated client code.

## What the game runs (observed)

| Component | Role |
|-----------|------|
| `ReplicatedStorage.Fust.ClientShield` | When `true`, enables client shield scripts. |
| `FustShieldGate` | Enables `FustAnimShield` + `FustCharSync`. |
| `FustAnimShield` / `FustCharSync` | Large obfuscated VM — primary integrity / cheat detection (exact rules not readable). |
| `FustFpsProbe` | Measures frame time when certain UIs open; can fire `Remotes.FpsProbe` with FPS/stall stats. |
| Character `LocalScript` (workspace rig) | Bytecode AC hook; console may show errors when injecting — treat as high risk. |

Staff tooling (e.g. `FustAdminESP2`) uses **`Highlight` + `workspace.FustESPOutlines`** — do not mimic that unless you are staff; foreign highlights/outlines may still flag.

---

## Avoid (high risk)

- **Hooking or blocking remotes** (`RemoteSpy` block/ignore, firing remotes for dupes/exploits).
- **`Drawing` / `Drawing.new` ESP** — common exploit fingerprint; heavy per-frame line updates.
- **Editing other players’ characters** — extra `Attachment` / `Beam` / `Highlight` parented to their rig (`CharSync` risk).
- **Aggressive globals** — obvious names on `_G`, loud `print`/`warn` in loop.
- **RenderStepped spam** — updating dozens of players every frame (triggers lag probes and looks like cheats).
- **Thread identity 2 for big UI libs** — some libs (`cloneref` / `GetService`) fail on identity 2; use executor default (e.g. 8) for Prism-style UI, accept injection risk tradeoff.
- **CoreGui / `gethui` spam** — extra ScreenGuis are expected for hub UI; do not pile on unrelated overlays every frame.
- **Disabling or patching** `FustAnimShield`, `FustCharSync`, or the character AC `LocalScript`.
- **Memory scans / `getgc` / `hookfunction` / `getconnections`** near game code — typical AC targets.

---

## Prefer (lower profile, not safe)

- **PlayerGui-only 2D ESP** — pooled `Frame` lines / labels; no Drawing API.
- **Low update rate** — ~5–8 Hz Heartbeat, not every frame; **stop the loop when ESP is off**.
- **Distance cap + target cap** — e.g. 12 closest players, configurable max studs.
- **LOD** — skeleton only at medium range; box + name at long range.
- **No prints** in hot paths; cleanup on unload (`Destroy` overlay, disconnect connections).
- **Unload hook** — one button to remove UI + ESP completely.
- **Test on alt / private** before main.

---

## ESP settings used in this project

See `fust_prism_base_esp.luau`:

- Box from head + root projection (stable at distance).
- Health bar: on by default; hidden only **inside ~35 studs** (too close on screen).
- Max distance slider (100–5000 studs).
- Prism UI from VortexHub TEST URL; bootstrap: `prism_ui.luau` then `fust_prism_base_esp.luau` on **thread 8**.

---

## If you get kicked or banned

Stop running scripts on that account, note what you enabled (ESP, hooks, etc.), and do not escalate (no remote hooks, no AC bypass attempts).

Last updated from MCP inspection of live Fust Survival client — re-verify after game updates.
