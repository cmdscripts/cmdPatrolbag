# 🧰 cmdPatrolbag

Multi-bag system for FiveM. Take bags from a dispensing point, carry them as an
item, open them for a personal stash. Built on **ox_lib** and **ox_inventory**,
runs on **ESX** and **QBox**.

[Preview](https://streamable.com/eknoax) · [Support](https://discord.gg/Evd7gvpTyW)

---

## Install

1. Folder must be named `cmdPatrolbag`
2. Copy the entries from `items.lua` into `ox_inventory/data/items.lua`
3. `ensure cmdPatrolbag`

> ox_inventory already has an item called `firstaid`, so the first aid **bag**
> is named `firstaid_bag`.

---

## Config

```lua
return {
    framework = 'auto',        -- 'auto' | 'esx' | 'qbx'
    interaction = 'ox_target', -- 'ox_target' | 'marker'

    bags = { ... },
    points = { ... },
}
```

### Bags

`items` is the starting inventory, added once when the bag is first opened.

```lua
evidence = {
    label = 'Evidence Bag',
    item = 'evidence_bag',   -- must exist in ox_inventory
    slots = 15,
    weight = 15000,
    carry = 'prop_cs_heist_bag_01',
    items = { evidence_marker = 5 },
},
```

`carry` is the prop the player visibly holds while the bag is in their
inventory — it disappears when the bag is stored in a trunk or stash, and
everyone nearby can see it. Omit the field for no prop.

By default the bag hangs from the left hand with a carrying animation, so the
right hand stays free for a weapon. Pass a table to override any of it:

```lua
carry = {
    model = 'bkr_prop_duffel_bag_01a',
    bone = 28422,                        -- default: left hand
    offset = vec3(0.26, 0.04, 0.0),
    rotation = vec3(90.0, 0.0, -78.99),
    dict = 'move_weapon@jerrycan@generic', -- dict = false disables the anim
    anim = 'idle',
},
```

The animation is restarted automatically after it gets interrupted (drawing a
weapon, emotes) and is suspended in vehicles, while swimming and in ragdoll.

Every bag item needs a matching entry in `ox_inventory/data/items.lua`:

```lua
['evidence_bag'] = {
    label = 'Evidence Bag',
    weight = 900,
    stack = false,
    close = true,
    client = { export = 'cmdPatrolbag.useBag' }
},
```

### Points

```lua
{
    label = 'Police Dispatch',
    coords = vec4(441.2, -981.9, 30.7, 90.0),
    jobs = { police = 0 },   -- omit for everyone
    bags = { 'patrolbag', 'evidence' },
    ped = 's_m_y_cop_01',    -- or prop = '...', or neither
},
```

- `jobs` — `{ job = minimumGrade }`, omit the field for public access
- `ped` / `prop` — model at the point; omit both to get a floor marker
- `radius` — interaction range, defaults to `1.8`

Points without a `ped` or `prop` always use `[E]`, even with `ox_target` set —
there is nothing to aim at.

### Language

Set it in `config.lua` — this is independent of ox_lib and does not affect
any other resource:

```lua
locale = 'de',   -- filename in locales/ without .json
```

`en` and `de` are included. To add a language, drop a new file into `locales/`
(e.g. `fr.json`) and point `locale` at it.

`en.json` is always loaded as the base, so any key you leave out of a
translation falls back to English instead of showing a raw key.

---

## Notes

Bags are opened by **using the item**, not from the point menu — the menu only
hands out and takes back bags.

Framework access is isolated in `server/bridge.lua`; supporting another one
means adding a single table there.

```
config.lua          user config
locale.lua          translations
shared.lua          defaults + validation
server/bridge.lua   ESX / QBox abstraction
server/main.lua     bags, stashes, callbacks
server/hooks.lua    ox_inventory exploit guards
client/main.lua     points, menus
client/carry.lua    carried bag props
```
