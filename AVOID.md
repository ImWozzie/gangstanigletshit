# Fust Survival — client anti-cheat avoidance notes

Use this as a checklist when writing or running executor scripts against **Fust Survival** (FUST client shield). Nothing here guarantees you will not be banned; the heavy logic lives in obfuscated client code.

## What the game runs (observed)

| Component | Role |
|-----------|------|
| `ReplicatedStorage.Fust.ClientShield` | When `true`, enables client shield scripts. |
| `FustShieldGate` | Enables `FustAnimShield` + `FustCharSync`. |
| `FustAnimShield` / `FustCharSync` | Large obfuscated VM — primary integrity / cheat detection (exact rules not readable). |
| `ReplicatedStorage.Fust.GunControl` | Obfuscated gun logic; includes **`debug.info` stack walking** to judge whether callers are allowed (Verdicts table). |
| `FustPad` + `FustLock` | Legit **ADS camera** pipeline (`aimStep`, `FustAimGun` / `FustAimBow`, `targetUnderCrosshair`, raycast visibility). |
| `FustFpsProbe` | Measures frame time when certain UIs open; can fire `Remotes.FpsProbe` with FPS/stall stats. |
| Character `LocalScript` (workspace rig) | Bytecode AC hook; console may show errors when injecting — treat as high risk. |

Staff tooling (e.g. `FustAdminESP2`) uses **`Highlight` + `workspace.FustESPOutlines`** — do not mimic that unless you are staff.

---

## Avoid (high risk) — ESP & movement

- **Hooking or blocking remotes** (`RemoteSpy` block/ignore, spoofed shoot payloads).
- **`Drawing` / `Drawing.new` ESP** — common exploit fingerprint; heavy per-frame line updates.
- **Editing other players’ characters** — attachments / beams / highlights on their rig (`CharSync` risk).
- **RenderStepped spam** on many players (lag probes + obvious cheat pattern).
- **Disabling / patching** `FustAnimShield`, `FustCharSync`, or the character AC `LocalScript`.
- **`getgc` / `hookfunction` / `getconnections` / `__namecall` hooks** on game or GunControl paths.

---

## Avoid (high risk) — aim & silent aim

These are **especially** likely to trip Fust after GunControl / server validation:

| Technique | Why |
|-----------|-----|
| **True silent aim** — bullets hit without camera matching | Server/client compare aim origin, direction, and timing; mismatch flags. |
| **Hooking `workspace:Raycast` / `FindPartOnRay`** for hit redirection | Stack / integrity checks; obvious tamper. |
| **Hooking or wrapping `GunControl` fire functions** | `debug.info(n, "sf")` validates source paths; foreign callers fail Verdicts. |
| **Spoofing shoot `FireServer` arguments** (direction, hit part, timestamp) | Server-side sanity + AC telemetry. |
| **`hookmetamethod` on RemoteEvent** | Classic AC target; overlaps with AnimShield. |
| **Instant snap > few degrees per frame** every shot | Statistical aim snaps vs input / camera delta. |
| **Aim while not ADS** (`FustAimGun` / `FustAimBow` false) | Breaks expected input state machine. |
| **Fighting `FustPad` `aimStep` every frame** | Two systems rotating camera = erratic signal. |

**We do not ship true silent aim in this repo** for those reasons.

---

## Prefer (lower profile) — ESP

- **PlayerGui-only 2D ESP** — pooled frames; ~5 Hz; stop loop when off.
- **Distance + target caps**, skeleton LOD, health bar only within short range slider.

See `modules/fust_esp.luau` (loaded by `loader/bootstrap.luau`).

---

## Prefer (lower profile) — aim (what this repo implements)

All in **`modules/fust_shell.luau` → Aim tab** (logic in `modules/fust_aim.luau`):

| Feature | Behavior |
|---------|----------|
| **Sticky assist** | Small camera pull toward target **only while ADS** (game aim attributes set). Capped degrees/frame. |
| **Snap on LMB** | Optional, marked risky: one small camera nudge on fire if target already inside **tight FOV** — **not** bullet redirection. |
| **No hooks** | Does not touch GunControl, remotes, or Raycast. |
| **Tunables** | Assist FOV, strength, snap FOV, max distance, bone (Head / UpperTorso / HRP). |

Defaults are conservative (assist off, snap off). **Test on an alt first.**

---

## Threading

- Run **`loader/bootstrap.luau`** on **executor thread 8** (thread 2 breaks Prism `cloneref`).

---

## If you get kicked or banned

Stop scripts on that account. Do not escalate into AC bypass or remote hooks.

Last updated from MCP inspection of live Fust Survival client — re-verify after game updates.
