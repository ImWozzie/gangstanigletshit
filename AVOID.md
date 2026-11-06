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
| `FustSky` (PlayerScripts) | Owns Lighting/Atmosphere every frame **and** runs a lighting tamper check when `ReplicatedStorage.Fust:GetAttribute("ACM")` is true (see below). |

### Telemetry remotes (observed client → server) — do not break

Blocking/spoofing these is out of scope. **Ban reason strings like `Multihack` are assigned server-side** — they do not appear in readable client scripts (only practice UI copy in `FustAcLab`).

| Signal | What the client actually sends |
|--------|--------------------------------|
| **`Remotes.LookPitch`** (Unreliable) | **`FustLook`**: every ≥**0.1 s**, `LookShared.Quantise(asin(clamp(Camera.LookVector.Y)))` (scale 90) → `FireServer(pitch[, facing])`. This is the live **look / pitch telemetry**. Instant `CFrame.lookAt` snaps create impossible pitch jumps between samples. |
| **`Remotes.MotionSync`** | **FustSky** `{ lt = "…" }` lighting mismatch; **FustSky** `{ xr, xv, xf, xl }` translucent-part / xray-ish scan near camera (RANGE 90, MIN 3); **FustFirstPerson** `{ tp, cm }` when camera type/subject/head distance is wrong for **>3.5 s**. |
| **`Remotes.FpsProbe`** | Frame-time / stall stats when certain UIs open. |
| **`Remotes.CharSync`** / AnimShield | Obfuscated integrity — not readable. |
| GunControl Verdicts | `debug.info` stack checks on fire callers. |

**Rule:** leave shield scripts running. Do not hook/block these remotes. Prefer **`mousemoverel`** over hard camera `lookAt`. Cap any CFrame assist to a few degrees/frame.

### Look / Multihack (2026-11-06) — gather assist burned

| Time | What ran | Ban |
|------|----------|-----|
| 14:17 | Misc WeakSpot **instant `CFrame.lookAt`** | Multihack 10y (clean alt) |
| 14:32 | Misc WeakSpot **`mousemoverel` + auto LMB** (v2.6.2) | Multihack 10y (clean alt again) |

`Multihack` is a **server** label (not in client scripts). Likely inputs: LookPitch discontinuities, and/or inhuman mouse+click+perfect weak-hit streaks. **Auto red-mark hit is disabled in-repo (v2.6.3)** — same policy as Lighting fullbright. Do not re-enable automated gather aim/click. Do not Swing-spoof.

### FustSky lighting check (fullbright / time changer)

Every 0.25 s it compares what it set (`want`) against live values. If any stays **brighter** than wanted for 3 s it fires `Remotes.MotionSync:FireServer({ lt = "<prop> <value>" })` (throttled to once per 300 s).

- Watched: `Lighting.ExposureCompensation` (tol 0.05), `Ambient` / `OutdoorAmbient` (luminance tol 0.03), anything else it wrote (e.g. `Brightness`, tol 0), `Atmosphere.Density` (0.02) / `Haze` (0.05), removal of effects it manages, and `ClockTime` if daylight rises by > 0.25 versus the real time.
- Darker than wanted is never flagged.
- Writing these on Heartbeat also strobes, because FustSky rewrites them every frame.

**Rule:** fullbright must not write Lighting/Atmosphere or delete their effects.

**2026-11-06:** restoring Lighting Ambient/Brightness fullbright (even with post-FustSky re-apply to stop blinking) was followed by a **permanent `Cheating` ban** on the live alpha. Client log: `You are banned from Fust Survival: Cheating (permanently)`. Likely path: ACM → `MotionSync { lt = … }` → staff/auto. **Lighting fullbright is disabled in-repo.** Do not re-enable. Time changer (brighter ClockTime) remains Risky for the same check.

Staff tooling (e.g. `FustAdminESP2`) uses **`Highlight` + `workspace.FustESPOutlines`** — do not mimic that unless you are staff.

---

## Avoid (high risk) — ESP & movement

- **Hooking or blocking remotes** (`RemoteSpy` block/ignore, spoofed shoot / MotionSync / FpsProbe payloads).
- **Breaking AC handshakes** — disable AnimShield/CharSync, patch shield LocalScripts, spoof integrity replies.
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
| **Hooking `workspace:Raycast` / `FindPartOnRay`** for hit redirection | Stack / integrity checks; obvious tamper. LOS checks for *our* aim filter are fine; redirecting the game’s gun rays is not. |
| **Hooking or wrapping `GunControl` fire functions** | `debug.info(n, "sf")` validates source paths; foreign callers fail Verdicts. |
| **Spoofing shoot `FireServer` arguments** (direction, hit part, timestamp) | Server-side sanity + AC telemetry. |
| **`hookmetamethod` on RemoteEvent** | Classic AC target; overlaps with AnimShield. |
| **Instant snap > ~10–14° per frame** every shot | Statistical aim snaps vs input / camera delta. |
| **Aim while not ADS** when the game expects ADS | Breaks expected input state machine (bundle defaults allow non-ADS; keep Require ADS on for lower profile). |
| **Fighting `FustPad` `aimStep` every frame** | Two systems rotating camera = erratic signal. |
| **Continuous `mousemoverel` aimlock** | Same Multihack class as gather mouse+click (2026-11-06 14:32). |
| **Camera silent on LMB** | Same LookPitch / mouse fingerprint. Disabled in v2.6.4. |
| **VirtualInput triggerbot** | Auto-click fingerprint. Disabled in v2.6.4. |

**We do not ship true silent aim (Shoot spoof / ray redirect) or AC handshake bypass.** Scripts that “silently” hit without looking are spoofing remotes — out of scope here. Soft lock assist is opt-in, tiny, ADS+hold, off by default.

---

## Prefer (lower profile) — ESP

- **PlayerGui-only 2D ESP** — pooled frames; default ~30 Hz (slider 30–240); stop loop when master off.
- **Distance + target caps**, skeleton LOD, health bar only within short range slider.
- Reuse scan buffers; write frame properties only on change.

See `modules/fust_esp.luau` (loaded by `loader/bootstrap.luau`).

---

## Prefer (lower profile) — aim (what this repo implements)

All in **`modules/fust_shell.luau` → Aimbot tab** (logic in `modules/fust_aim.luau`), bundle **v2.5.0+**:

| Feature | Behavior |
|---------|----------|
| **Sticky assist** | Camera / mouse pull toward target while enabled (+ hold key if required). Capped degrees/frame. |
| **Mouse drive** | Default: `mousemoverel` so FustPad sees real input. |
| **Camera silent (LMB)** | Risky: multi-step **camera CFrame** snap inside silent FOV on fire + short hold — **not** bullet redirect. Tunables: FOV, max deg, steps. |
| **Visible check** | Optional `workspace:Raycast` LOS for *target pick only* (shared RaycastParams). Does not hook gun rays. |
| **Triggerbot** | Risky: VirtualInput click when bone in deadzone. |
| **No hooks** | Does not touch GunControl, remotes, metamethods, or Raycast hooks. |
| **Panic** | Instantly clears aimbot / silent / trigger / time changer flags. |

Defaults are conservative (assist / silent / trigger off). **Test on an alt first.** After the 2026-11-06 ban, do not test Lighting writes on a main.

---

## Gather / Misc — disabled

Auto WeakSpot (red X) assist is a **no-op** after two Multihack bans (instant look + mouse drive). Keep researching only on throwaway alts; do not ship automated gather aim/click or Swing spoof.

---

## Threading

- Run **`loader/bootstrap.luau`** on **executor thread 8** (thread 2 breaks Prism `cloneref`).

---

## If you get kicked or banned

Stop scripts on that account. Do not escalate into AC bypass, remote hooks, or handshake spoofing.

Last updated **2026-11-06** (bundle v2.5.0 + permanent Cheating ban from Lighting ACM) — re-verify after game updates.
