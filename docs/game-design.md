# Bus Simulator — Game Design Document

> Offline 3D bus-driving simulator for Android. Earn money driving passengers safely, spend it on bigger buses, cosmetics, and performance. Built in Godot.

---

## 1. Concept

A relaxing bus-driving **simulator** (not arcade). The player drives a bus along fixed metro-style routes, picking up and dropping off passengers, earning a fixed fare per passenger. Money is the whole engine of progression: it buys new bus models, cosmetics, and performance upgrades. Careful driving keeps more of that money; careless driving leaks it into repairs. No schedule, no clock — the skill is driving well and arriving safely.

- **Platform:** Android (native, exported from Godot).
- **Engine:** Godot 4.x. Bus physics via the built-in `VehicleBody3D` node.
- **Connectivity:** 100% offline. No accounts, no ads server, no cloud, no leaderboards. Everything (maps, buses, scenery) ships inside the APK; all progress saves locally to `user://`.
- **Target feel:** immersive, low-tension sim. "I'm really driving a bus."

---

## 2. Core gameplay loop

1. Pick a map (all maps open from the start).
2. Pick a bus you own.
3. Drive the route: pull up at each stop → passengers board/alight → continue.
4. Reach the end terminal → run completes → get paid.
5. Spend earnings on new buses, cosmetics, and upgrades.
6. Repeat on harder / prettier maps with better buses.

---

## 3. Economy

**Payout formula (paid once, at run's end):**

```
payout = passengers_carried × fixed_fare_per_passenger
```

- Bigger buses hold more passengers → earn more per run. This is the main reason to buy up.
- Fare is a fixed amount per passenger (tunable, can vary per map so harder/prettier maps pay more).

**Costs:**
- **Repairs** — the only running cost. Crashing lowers bus health; repairing costs money. **Repairing is optional** (see §6). This turns "arrive safely" into the real skill: careful drivers keep more profit.

**Explicitly cut** (do not build): fuel/petrol system, safe-driving bonuses, schedule/time pressure, map-purchase unlocks. These were considered and deliberately dropped to keep the loop clean.

> ⚠️ **Design watch:** because maps are all free and there's no fuel, *all* long-term pull rests on the bus + upgrade ladder. That ladder must be deep enough to chase for hours — price buses/upgrades so there's always a next goal.

---

## 4. Progression

- Start with one cheap, small bus. All maps already accessible.
- Earn → unlock bigger/better/cooler buses and upgrades.
- Progression is entirely economic (no XP, no levels).

---

## 5. Buses & upgrades

**Buses** (bought outright): differ in **passenger capacity** (income), base stats, and look. Capacity comes from *buying a bigger bus*, not from upgrading.

**Upgrades** (applied to an owned bus):
- **Top speed** — kept purely because fast is fun. No time reward exists; speed justifies itself as a thrill, and creates self-chosen risk (go fast → more likely to crash → repair bills).
- **Acceleration** — recover speed faster after each stop.
- **Brakes** — fewer crashes → less repair spend.
- **Handling** — easier to place the bus precisely.
- **Cosmetics** — paint / liveries. Pure personalization + money sink.

> Capacity and fuel-capacity are **not** upgrades (capacity = buy bigger bus; fuel cut entirely).

---

## 6. Damage model

Bus has health. Damage is more than cosmetic:

- **0 health → undrivable.** Bus is dead; run fails / player must repair before using it again.
- **Above 0 → degraded performance.** As health drops, **top speed drops** proportionally.
- **Localized damage:** specific parts take specific hits. Hitting a **mirror** shatters *that* mirror → reduced visibility on that side (cracked/blacked-out mirror render). This means the bus is not a single health bar — it needs **hittable sub-parts** (e.g. mirror L, mirror R, body panels), each tracking its own state, feeding into overall health.
- **Repair is the player's choice.** A dented bus stays drivable (until 0) but performs worse and looks beat-up — a standing reminder of money being saved vs. spent. Repair = pay to restore health/parts.

---

## 7. Mirrors

- **Rear + side mirrors, functional** — they render the actual scene (core to the bus fantasy).
- **Always rendering**, but at **low resolution** to protect mobile performance. Can further reduce update frequency if a device struggles.
- Shatter effect (from §6) overlays cracked/obscured visuals and degrades their usefulness.

> ⚠️ **Performance note:** each functional mirror is effectively an extra camera re-rendering the world every frame. Three mirrors = the single most GPU-hungry feature in the game. Budget for it: low mirror resolution, controlled map detail, optional reduced mirror refresh rate.

---

## 8. Passengers

Metro-style:
- Each passenger has a **predefined boarding stop** and a **predefined destination stop** along the route.
- Board at their stop, alight at their destination. Fare counts per passenger carried.
- Simple interaction: pull up at a stop → relevant passengers board/exit → drive on.

---

## 9. Traffic & road AI

Traffic is **core, not polish** — safety only matters if there's something to hit, and the economy collapses without it.

- AI vehicles drive the roads; the player must avoid them.
- **Indicators → give-way:** when the player signals a lane change, vehicles behind should yield and let the bus in.

> ⚠️ **Hardest system in the project.** Traffic that brakes sensibly, doesn't pile up, and reacts to the player (especially the give-way behavior) needs real tuning. Build a dumb version first (cars on fixed paths), then layer intelligence.

---

## 10. Cameras

Multiple angles, cycled with an on-screen button:
- **Chase cam** (behind the bus).
- **Driver / interior** (first-person from the seat; mirrors matter most here).
- **Top-down.**
- (Optional later: free/orbit cam.)

---

## 11. Controls (touch)

To be finalized at build time. Default plan: on-screen **steering wheel + pedals** (accelerate/brake), indicator buttons (left/right), camera-cycle button, horn. Alternative considered: **tilt-to-steer** (gyro) with on-screen pedals. Pick during Slice 1 by feel.

---

## 12. Maps

- Several **fixed, hand-crafted** maps, each with **distinct scenery** (e.g. coastal town, desert highway town, dense downtown).
- **Quality over quantity:** a handful of characterful maps (~4–6) that each play differently, not dozens of samey ones. Keeps the APK reasonable (all maps bundled) and each map polished.
- All maps open from the start.

---

## 13. Assets

No 3D modeling required. Use free **CC0 asset kits** (e.g. Kenney, Quaternius) for buses, cars, roads, buildings, props. Assemble rather than author.

---

## 14. Save system

- Local only (`user://` in Godot). Survives app close. No login.
- Persists: money, owned buses, applied upgrades/cosmetics, per-bus health & part damage, current/selected map & bus.

---

## 15. Build order (milestones)

Build in slices so there's something playable fast and the hard/heavy systems come last.

| # | Slice | Contents | Cost / risk |
|---|-------|----------|-------------|
| 1 | **Core driving + cameras** | Drivable bus (`VehicleBody3D`), one looping road, touch controls, camera cycle. *If this feels good, the game works.* | Low |
| 2 | **Passengers + economy** | Stops as `Area3D` triggers, metro-style board/alight, fare payout at terminal, money, buy buses/upgrades, local save | Medium |
| 3 | **Traffic (basic)** | AI cars on fixed paths, collisions → damage | Medium-hard |
| 4 | **Indicators + give-way** | Blinking indicators (cheap), traffic yields to signaled lane change (hard, tuning-heavy) | Hard |
| 5 | **Localized damage + mirrors** | Sub-part damage, mirror shatter → visibility, functional low-res always-on mirrors | Hardest (perf) |
| 6+ | **Content + polish** | More maps, more buses, cosmetics, day/night, door/indicator animations | Additive |

Cheap wins available any time: indicator lights, top-speed-scales-with-health (≈one line).

---

## 16. Technical risk flags (read before building)

1. **Mirrors = performance boss.** See §7. The thing most likely to tank framerate on a phone.
2. **Traffic AI = hardest logic.** See §9. Especially indicator give-way. Build dumb first.
3. **Localized damage needs structure.** The bus can't be one health number — model hittable sub-parts from the start if you know mirror-shatter is coming, so you don't retrofit it later.

---

## 17. One-time setup (Godot → Android)

1. Download Godot 4.x (single executable, no installer).
2. `Project → Setup Android Build…` (Godot 4.8+ auto-fetches the Android & Java SDKs).
3. On the phone: enable Developer Options → USB debugging; plug in.
4. Press the Android run button in Godot → builds & launches on the device.

(All game code — driving controller, touch input, cameras, passengers, economy, damage — can be written with AI assistance. The one-time engine/SDK install and the APK build run on your machine.)
