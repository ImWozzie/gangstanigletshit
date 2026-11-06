# Vault (`getgenv().vaultFust`) — steal dump

Live reverse on **stealagoonrot**, job `2de05adb-…`, 2026-11-06.
Source is **Luraph-obfuscated** (`[string "Luraph"]` Heartbeat hooks). Function bodies / string constants are not readable; `decompile(fn)` rejected; `debug.getupvalue` on Luraph closures can crash the VM (`readu8`). Steal is **config surface + behavioral telemetry**, not source.

UI: custom library under `vaultFust.library` (HiddenUI dock), CoreGui `VaultInvViewer` / `VaultTargetInfo`. Drawing API for world dots/labels + silent/aim FOV circles.

---

## Top-level modules (`vaultFust` keys)

| Key | Live defaults (while farming) | Notes |
|-----|-------------------------------|-------|
| `farmAura` | **on** — `range=2`, `cooldown=0.2`, `aimWeakspot=true`, `autoCooldown=true`, `skipCactus=true`, `hold=false` | See behavior |
| `silentAim` | off — FOV 220, `shotOnly=true`, bone Head, hitChance 100 | True silent class |
| `aiming` | off — FOV 220, prediction, bulletSpeed 900, smoothing 2 | Soft/lock aim |
| `gunMods` | off — noSpread/noKick/noSway/rapid/auto/instantAds/fastReload… | GunControl-tier |
| `bowMods` | off — `instantCharge=true` default in table | Bow hooks |
| `killAura` | off — range 7, cd 0.35 | Melee aura |
| `hitbox` | off — scale 5, target Head | Expands parts |
| `speedBoost` | off — speed 22, mode `cframe` | MotionSync risk |
| `wallClimb` | off — speed 40 | |
| `freecam` | off — speed 1 | keybind F |
| `thirdPerson` | off — dist 10, height 2.5 | keybind T |
| `zoomHack` | off — FOV 20, hold Z | Camera FOV |
| `fullbright` | off | **Do not port** (our ban) |
| `ambience` | off — fog/brightness/clock | Lighting-adjacent |
| `xray` | off — transparency 0.7 | MotionSync `{xr…}` risk |
| `world` | Drawing ESP — 30+ entity toggles, maxlabels 300 | |
| `npcEsp` | off | Guards |
| `invViewer` | off — rate 0.2, maxDist 2000 | CoreGui |
| `targetInfo` | off — rate 0.1, maxDist 2000 | CoreGui |
| `library` / `flags` | 253 UI flags | persistence |

---

## `farmAura` behavior (confirmed while you used it)

- **Swing is not executor-spoofed.** Spy: `Swing:FireServer({target, pos})` Origin = `PlayerScripts.FustGather` line ~2394, `IsExecutor=false` (24 calls sampled on StoneNode).
- Vault drives the **legit gather pipeline** (camera/mouse toward node/WeakSpot + auto click / input), not a fake remote.
- With `aimWeakspot=true` this is the same class as our Multihack bans (look/mouse + auto hit). **Do not port aim-weakspot farm.**

Flag map: `farm_enabled`, `farm_aimweakspot`, `farm_autocooldown`, `farm_cooldown` (UI shows 20; runtime table `cooldown=0.2` — likely seconds vs display), `farm_range`, `farm_hold`, `farm_skipcactus`.

---

## Silent / aim flag map

| Flag prefix | Feature |
|-------------|---------|
| `sa_*` | silentAim — enabled, fov, bone, hitchance, shotonly, showfov, wallcheck, teamcheck, targetnpcs, distance |
| `aim_*` | aiming — enabled, fov, bone, prediction, smoothing, bulletspeed, wallcheck, teamcheck, targetnpcs, distance, lock |
| `Aim_FOV_Circle` | shared FOV draw |

Staff `FustAdmin2.Suspects` already counts kinds `silentaim` / `aimlock` / `aimflick` — another reason not to ship true silent.

---

## Combat / movement flags (steal surface only)

- **Gun:** `gunmod_enabled`, `_nospread`, `_nokick`, `_nosway`, `_nomovespread`, `_rapid`, `_rate`, `_recoil`, `_auto`, `_fastreload`, `_instantads`, `_reloadmult`
- **Bow:** `bm_enabled`, `_instant`, `_fastshot`, `_infammo`, `_nograv`
- **Kill aura:** `kill_enabled`, `_hold`, `_range`, `_cooldown`
- **Hitbox:** `hb_enabled`, `_scale`, `_target`
- **Speed:** `sb_enabled`, `_speed`, `_mode` (`cframe`), `_keybind`
- **Wall climb:** `wc_enabled`, `_speed`
- **TP3 / freecam / zoom / FB / xray / ambience:** `tp3_*`, `fc_*`, `zh_*` (if present), `fb_enabled`, `xray_*`, `amb_*`

---

## World ESP toggles (`world.toggles` + `world_*` flags)

Each entity typically has `world_<name>` + `world_<name>_dist`:

airdrop, atv, auto_turret, backpack (+ small/large), bear, boar, deer, elite_crate, food, hemp, landmine, large_box, loot_barrel, loot_crate, metal, military_crate, minicopter, mushroom, patrol_heli, shotgun_trap, sleeper, stone, sulfur, tool_cupboard, trees, wooden_box, woodpile, world_item, …

Plus: `world_esp_enabled`, `world_esp_fontsize`, `world_esp_keybind`, `maxlabels=300`.

Uses **Drawing.new** pools (`world.dots` / `world.labels`) — our AVOID forbids Drawing; port as **PlayerGui** overlays like existing ESP.

---

## Player / NPC ESP flags (Drawing + chams)

Player: `Enabled`, `Boxes`, `Box_Type`, `Filled_Box`, `Names`, `Display_Names`, `Distance`, `Healthbar`, `Health_Text`, `Weapon`, `Chams` (+ fill/outline/vis), colors/rainbows, `Max_Distance`, `Font_Size`, glow/outline/inline theme colors.

NPC: `Npc_*` mirror of boxes/chams/name/distance/weapon/health.

---

## Port vs AVOID

| Steal | Port into Fust bundle? |
|-------|-------------------------|
| World loot/node/animal ESP (PlayerGui) | **Yes** — high value, matches `knowledge.md` folders |
| NPC ESP / sleeper labels | **Yes** |
| Inv viewer / target info (local GUIs) | **Yes** — read attributes only |
| Third person / freecam / zoom FOV | Maybe — camera-only, test on alt |
| Wall climb / cframe speed | Risky — MotionSync / move AC |
| Xray / fullbright / ambience Lighting | **No** |
| farmAura (+ aimWeakspot) | **No** — Multihack vector |
| silentAim / gunMods / bowMods / hitbox | **No** — AVOID hard |
| killAura | **No** unless proven input-only + still likely ban |
| Drawing ESP / chams on others | **No** Drawing; no foreign Highlights |

---

## Live session notes

- Active while dumped: `farmAura` only (silent/aim/gun/kill off).
- Swing targets seen: `Workspace.Nodes.Tree.Trunk`, `Workspace.Nodes.StoneNode.Rock` with impact `pos`.
- LookPitch still streaming normally during farm.
- Luraph Heartbeat connections present (`R`, nups=37); do not poke upvalues (executor crash).

---

## AC “bypass” scan (2026-11-06, Vault running)

**Vault does not disable client AC.**

| Check | Result |
|-------|--------|
| `ClientShield` / `ACM` / `AAEnabled` | all still `true` |
| `FustAnimShield`, `FustCharSync`, `FustLook`, `FustSky`, `FustGather`, `FustCombat`, `FustShieldGate` | all `Enabled=true` |
| Heartbeat connections disabled | **0** (108 total; 7 Luraph) |
| LookPitch / MotionSync `OnClientEvent` disabled | **0** |
| UI flags named bypass/spoof/shield | **none** |
| `workspace.Raycast` hooked | **no** (`isexecutorclosure=false`) |

**What looks like a bypass (and is not ported):**

1. **Silent ≠ Shoot spoof in live capture.** With `silentAim` + `aiming` on, Shoot `dir` matched camera LookVector within float noise (`0.42074…` both ways). Origin `FustCombat`, `IsExecutor=false`. So their “silent” here is **camera aimlock / snap-to-bone**, not `dir` rewrite. Still LookPitch-visible → Multihack class; we do not re-enable hard camera silent.
2. **farmAura** = drive legit `FustGather` (look/click) — same Multihack class we already burned; not a shield bypass.
3. **No handshake spoof / AnimShield kill** observed. They survive by not touching shield scripts, not by turning them off.
4. GunMods not exercised this session — still treat as GunControl hook risk; do not port.

**Conclusion:** no stealable shield bypass. Vault rides legit combat/gather remotes after moving the camera/mouse.

### Ported into bundle **v2.8.0** (Vault-method mirror)

| Vault | Ours |
|-------|------|
| aiming FOV 220 / smooth 2 / pred 900 | `fust_aim` same |
| silent = mouse lock (not Shoot spoof) | silent aim restored |
| farmAura weakspot+click → FustGather | Misc farm aura |
| killAura / speed cframe / hitbox | Misc combat extras |
| world ESP / inv / target / zoom / fc / tp3 | World + Misc (PlayerGui, not Drawing) |
| gunMods / bowMods hooks | **not ported** — Luraph; needs GunControl hooks we refuse without source |
| fullbright / xray | **still dead** (confirmed Cheating ban) |
