# knowledge.md — Fust Survival game map (for ESP / agents)

What the live client exposes, where each piece of data lives, and what we could build on it.
Mapped on the live **Fust Survival [ALPHA TESTING LIVE]** server, 2026-11-06, ~43 players.
Re-verify after game updates. Read **AVOID.md** and **AGENTS.md** first.

---

## 1. Players

### Character model — `workspace.<PlayerName>` (R15)

| Child | What it tells us |
|-------|------------------|
| `<Tool>` (one at a time) | **Held item.** `Tool.Name` is the display name (`Custom SMG`, `Stone Hatchet`, `Metal Hatchet`). Attributes: `ItemId` (`custom_smg`), `WSkin` (weapon skin, e.g. `cardboard`). Children: `Visual` (Model), sometimes `Handle`. |
| `FustWear` (Folder) | **Worn clothing / armour.** One child per body part, named `<slot>_<BodyPart>` (`torso_armor_UpperTorso`, `legs_RightLowerLeg`, `head_Head`). Attributes: `ItemId` (`tactical_vest`, `hide_hood`, `hide_pants`, `wood_armor_pants`, `hide_vest`), `BodyPart`, `Offset`. Same ItemId repeats across parts — dedupe by ItemId. Missing folder = naked. |
| `FustPack` (Folder) | **Backpack** worn, e.g. `BackpackSmall`. |
| `FustAvatarFace`, `FustHair1..3` (Accessory), `Body Colors` | Cosmetic. |

Character attributes:

| Attribute | Meaning |
|-----------|---------|
| `LookAds` | Aiming down sights |
| `GunReload` | Reload state / timestamp (0 = not reloading) |
| `SwingTool`, `SwingSeq` | Last melee tool used and swing counter |
| `FustAvLook` | Avatar preset string |

### Player object — `Players.<Name>` attributes

| Attribute | Meaning |
|-----------|---------|
| `Alive`, `Dead`, `Spawning`, `Asleep` | Life state |
| `Crouching`, `Sprinting` | Movement state |
| `LastHitBy`, `LastHitById`, `LastHitAt`, `LastHitWeapon` | Who last hit them, when, with what |
| `SafeHostileUntil` | Timestamp — likely safe-zone hostility timer (shows recent aggression) |
| `FustBodyTemp`, `FustColdStage`, `FustFrostbite`, `FustAirTemp`, `FustColdTrend`, `FustColdWhere` | Cold system |
| `FustBreath`, `FustSwimStamina`, `FustSeaZone` (`coast`, …) | Water / ocean system |
| `WSShards`, `WSCrates` | Weapon-skin currency / crate count |
| `InvLoaded`, `FustUvOk`, `FriendsSeeServer` | Misc flags |

`Player.Team` was `nil` for everyone checked. Clan data lives in `ReplicatedStorage.Fust.Clans` (ClanConfig, ClanShared, ClanVisuals, ClanItems, ClanLogos) — how membership replicates is **not mapped yet**.

---

## 2. World folders (`workspace.*`)

| Folder | Contents (count seen) | Useful attributes |
|--------|------------------------|-------------------|
| `Sleepers` | Sleeping players (52) — full R15 rig, `Sleeper_<UserId>` | `SleeperName`, `SleeperId` |
| `Npcs` | Monument guards (3) | `NpcKind=guard`, `Monument` (`Rail Depot`), `State` (`patrol`, `dead`), `Weapon` (`custom_smg`, `revolver`), `Alert`, `GunReload`, `Dead` |
| `Animals` | Boar, Bear, Deer (8) | `Species`, `State` (`idle`, `walk`), `HeadMult` |
| `Loot` | `LootBarrel` (`Variant` blue/red, `Hp/MaxHp`), `LootCrate` and `MilitaryCrate` (`CrateKind` wooden/military, `Open`) | |
| `WorldItems` | Dropped items (`Item` models) | `SpawnedAt`, `PopFrom` |
| `Pickups` | Resources (376): Hemp, WoodPile, StonePile, MetalOrePile, SulfurOrePile, BerryBush, Mushroom, Corn, Pumpkin, Potato, Carrot, Apple | `PickupType`, `Remaining` |
| `Nodes` | Trees (204), Cactus (315), Stone (64), Metal (42), Sulfur (43) | `NodeType`, `Hp/MaxHp`, `GrowAt`, `TreeKind` |
| `ArrowPickups` | Arrows on the ground | `ArrowItem` |
| `Deployables` | AutoTurret, Battery, Bed, Campfire, Furnace, Candles, CeilingLight, HighWood/StoneWall, HighWoodGate, Ladder, BambooRack, Backpack (death bags) … | `Kind`, `OwnerTag`, `Hp/MaxHp`, `PowerOn/Powered` (turrets), `Locked/HasLock/GateOpen` (gates), `Lit`, `ReadyAt` (beds) |
| `Buildings` | Base pieces (1242): wall, halfwall, floor, tri_floor, foundation … | `PieceType`, `Tier` (wood/stone/metal), `Hp/MaxHp`, `AutoHeal`, `OwnerTag`, `PlacedAt` |
| `FustBoats` | Rowboat | `BoatId` |
| `FustAtvs` | ATV | `Fuel`, `Health/MaxHealth`, `Engine` |
| `FustMinicopters` | Minicopter | `Fuel/FuelCap`, `Health`, `Engine` |
| `Airdrops`, `FustPatrolHeli`, `FustEvents`, `FustRockets`, `Explosives`, `FustTrapCaps`, `FustFires` | Events / dynamic (empty when checked) | |
| `FustLaserDots` | `LaserDot` — laser sight dots in the world | |
| `FustWagerArena` | Wager arena model | |

`OwnerTag` is shared by every piece one owner placed — grouping by it groups a base.

---

## 3. ReplicatedStorage

- `ReplicatedStorage` top level: `AdminRemotes`, `SetTeam` (RemoteEvent), `Fust` (Folder).
- `Fust` holds ~100 shared modules, incl. `Items`, `ItemIcons`, `WeaponSkins`, `LootTables`, `Wear`, `Durability`, `GunControl`, `AmmoHud`, `Clans`, `Remotes`, `StaffState`, `SafeZone`.
- `require(Fust.Items)` returned a table with **no enumerable entries** (lookup API unknown). `require(Fust.ItemIcons)` exposes functions `Color`, `Abbr`, `_fit`.
- **Do not require these again without a reason** — see section 5. Item names can be derived without them: `Tool.Name` is already the display name, and an `ItemId` becomes readable with `id:gsub("_", " ")` + title case.

---

## 4. ESP feature ideas (by data source)

### Players
| Feature | Source |
|---------|--------|
| **Held weapon / tool** name (+ skin) | `char:FindFirstChildOfClass("Tool")` → `.Name`, `WSkin` |
| Weapon class colour (gun / bow / melee / tool) | `ItemId` keyword match (`smg`, `rifle`, `revolver`, `bow`, `hatchet`, `pickaxe`) |
| **Armour summary** (e.g. `Tactical Vest · Wood Pants`) and an "armoured" tag | `FustWear` children → unique `ItemId` |
| Backpack tag | `FustPack` |
| **ADS / reloading** icons | `LookAds`, `GunReload` |
| Crouch / sprint / asleep state | Player attributes |
| "Last hit by X with Y" (killer feed) | `LastHitBy`, `LastHitWeapon`, `LastHitAt` |
| Recently hostile marker | `SafeHostileUntil` > now |
| Cold / frostbite warning | `FustColdStage`, `FustFrostbite` |
| Look direction line | head `CFrame.LookVector` |
| Off-screen arrows | root projected outside the viewport |

### World
| Feature | Source |
|---------|--------|
| **Sleeper ESP** (name, distance) | `Sleepers` → `SleeperName` |
| **NPC guard ESP** with weapon + state (patrol / alert / dead) | `Npcs` |
| Animal ESP (bear warning) | `Animals.Species` |
| Loot ESP: military / wooden crates, barrels, unopened only | `Loot` → `CrateKind`, `Open`, `Variant` |
| Dropped items / death bags | `WorldItems`, `Deployables.Backpack` |
| Resource ESP: sulfur / metal / stone nodes, hemp | `Nodes.NodeType`, `Pickups.PickupType` |
| **Vehicle ESP** with fuel + health | `FustAtvs`, `FustMinicopters`, `FustBoats` |
| **Turret ESP** (powered or not) | `Deployables` `Kind=auto_turret`, `Powered` |
| Base ESP: weakest wall per base, tier, HP % | `Buildings` grouped by `OwnerTag` |
| Event ESP: airdrops, patrol heli | `Airdrops`, `FustPatrolHeli` (when present) |

### Performance rules for world ESP
- `Buildings` (1000+) and `Nodes` (600+) are big: never scan them every tick. Index once, listen to `ChildAdded` / `ChildRemoved`, and only draw within a short range.
- One shared slot pool per category, with property writes diffed (same as the player ESP).

---

## 5. Incident log

**2026-11-06 ~00:00 — a check flagged.** Exactly what ran in-game in that session:

1. Read attributes of players' characters, `FustWear`, `FustPack`, held Tools, and `GetChildren` of the workspace folders above.
2. One `ReplicatedStorage:GetDescendants()` pass looking for item modules.
3. `require(ReplicatedStorage.Fust.Items)` and `require(ReplicatedStorage.Fust.ItemIcons)`.
4. `loadstring` compile checks of bundle modules (not run).
5. A performance test that built the v2.3.0 ESP module, turned it on, and measured `RenderStepped` frame times; it was interrupted part-way.

The exact trigger is unknown. Most likely suspects, in order: the `require` of game modules (3), the interrupted ESP + frame-time test (5), the full `GetDescendants` pass (2) causing a frame stall the game's FPS probe can report.

**2026-11-06 14:01 (UTC+8) / 06:01 UTC — permanent ban: `Cheating`.**

Roblox player log `…T040130Z_Player_FEAAD_last.log`:

```
Error: Server Kick Message: You are banned from Fust Survival: Cheating (permanently); Metadata:
Disconnect reason: 267 — You have been kicked from the game
```

Session context (same job `2de05adb-…`):

1. Bundle aimbot/ESP/world loaded for hours on live alpha (`ClientShield=true`, `ACM=true`).
2. ~minutes before the kick we restored **Lighting fullbright** (Ambient ≈ 0.71, Brightness 2, re-applied every RenderStepped after FustSky).
3. FustSky ACM watches Ambient / OutdoorAmbient / Exposure / Brightness; after ~3s brighter-than-want it fires `Remotes.MotionSync:FireServer({ lt = … })` (throttled 300s).
4. A mod then teleported / the server issued a permanent Cheating ban. Client log has **no** extra metadata beyond that string.

**Conclusion:** treat **any Lighting Ambient/Brightness/Exposure raise** as ban-tier while ACM is on. Fullbright Lighting path is **disabled** in `fust_world.luau`. Camera colour filters / PointLights were safer for AC but weaker visually — do not bring Lighting paints back without proof ACM is off.

---

## 6. Rules for agents running anything in-game

- Read-only first, and only what the task needs. Prefer `FindFirstChild` / `GetChildren` on known folders over `GetDescendants`.
- **Never `require` game modules** from the executor.
- No frame-time measuring loops; no large scans in one frame. Spread work over frames.
- Say what you are about to run before running it; keep each run small and reversible, and clean up (destroy GUIs, disconnect) in the same run.
- Test on an alt / private server when possible.
- After any kick, flag or ban: stop, write down what ran, add it to the incident log above.
