Config = {}

-- ============================================================
--  PERFORMANCE
--  Settings for server performance and caching
-- ============================================================
Config.Performance = {
    -- Debug mode: prints extra info to the server console (for testing only, keep false in production)
    debugMode = false,

    -- How long a player's job cache stays valid (in ms). Reduces unnecessary database calls.
    -- Recommended: 30000 (30 seconds)
    cacheExpiry = 30000,

    -- Timeout for loading ped/prop models on the client (in ms)
    modelRequestTimeout = 10000,

    -- How often the bag ownership status is refreshed in the background (in ms)
    bagStatusInterval = 20000,

    -- Tick rate for drawing markers (in ms). Lower = smoother, but more CPU usage
    markerTick = 250,

    -- Maximum number of simultaneously registered stashes. 5000 is sufficient for most servers.
    maxStashes = 5000,
}

-- ============================================================
--  SECURITY
--  Protection against spam and abuse
-- ============================================================
Config.Security = {
    -- Minimum time between two actions from the same player (in ms)
    -- Prevents rapid double-clicking / spam
    actionCooldown = 750,

    -- Maximum actions per player per minute before they get blocked
    maxAttemptsPerMinute = 30,

    -- Random range for bag IDs (e.g. PBG-47382)
    -- Larger range = fewer collisions when many bags exist
    maxIdentifierRange = { min = 10000, max = 99999 },
}

-- ============================================================
--  MENU MODE
--  How the bag menu is opened
--  'points' = player walks to a dispensing point (recommended)
-- ============================================================
Config.Menu = 'points'

-- ============================================================
--  INTERACTION
--  How players interact with dispensing points
-- ============================================================
Config.Interaction = {
    -- Interaction mode:
    --   'marker' = player presses a key when near the marker
    --   'target' = player aims at an object/ped with ox_target (requires ox_target)
    mode = 'marker',

    -- Key to open the menu in marker mode
    -- 38 = E key (GTA default interaction key)
    key = 38,

    -- Distance at which the marker becomes visible (in meters)
    drawDistance = 25.0,

    -- Marker settings (only relevant when mode = 'marker')
    marker = {
        type      = 2,                                     -- Marker type (2 = cylinder/ring, 1 = arrow, etc.)
        width     = 0.35,                                  -- Width of the marker
        height    = 0.35,                                  -- Height of the marker
        color     = { r = 0, g = 153, b = 255, a = 180 }, -- Color: blue, slightly transparent
        direction = vec3(0.0, 0.0, 0.0),
        rotation  = vec3(0.0, 0.0, 0.0),
    },

    -- ox_target settings (only relevant when mode = 'target')
    target = {
        enabled  = false,  -- true = ox_target active, false = disabled
        distance = 2.0,    -- Maximum aiming distance (in meters)
    },
}

-- ============================================================
--  NOTIFICATIONS (UI)
--  Customize the notification system here.
--  Default: native GTA notification system (no framework needed).
--  For ox_lib:  lib.notify({ title=title, description=desc, type=kind })
--  For ESX:     ESX.ShowNotification(desc)
-- ============================================================
Config.UI = {}

Config.UI.Notify = function(title, desc, kind)
    -- Native GTA system (no framework required)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(('%s\n%s'):format(title or '', desc or ''))
    EndTextCommandThefeedPostTicker(false, false)
end

Config.UI.HelpNotify = function(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text or '')
    EndTextCommandDisplayHelp(0, false, true, -1)
end

Config.UI.HideHelpNotify = function()
    ClearAllHelpMessages()
end

-- ============================================================
--  TEXTS
--  All displayed messages — edit or translate here
-- ============================================================
Config.Text = {
    noAccess         = 'No access',
    rateLimited      = 'Please slow down',
    alreadyHave      = 'You already have this bag',
    noSpace          = 'No space in inventory',
    issued           = 'Issued',
    returned         = 'Returned',
    notFound         = 'Not found',
    removeFailed     = 'Could not be removed',
    bagInBag         = 'Bag-in-bag not allowed',
    onlyOneBag       = 'Only one bag allowed',
    openError        = 'Error opening bag',
    fillError        = 'Error filling bag',
    updateError      = 'Error updating bag',
    createError      = 'Error creating bag',
    notAvailable     = 'Not available',
    nothingAvailable = 'Nothing available',
}

-- ============================================================
--  JOB WHITELIST
--  Which jobs generally have access to the bag menu.
--  Fine-grained control per dispensing point is available under Config.Points.
-- ============================================================
Config.JobWhitelist = {
    'police',
    'ambulance',
}

-- ============================================================
--  BAG DEFINITIONS
--  Each bag needs a unique key (e.g. 'patrolbag').
--
--  Fields:
--    label           - Display name in menus and notifications
--    item            - Item name in ox_inventory (must match items.lua!)
--    stashPrefix     - Prefix for the internal stash ID (must be unique)
--    onePerInventory - true = player can only carry one of this bag
--    stash.slots     - Number of inventory slots in the bag
--    stash.weight    - Maximum weight of the bag (in grams)
--    seedOnFirstOpen - true = bag is filled with items on first open
--    seedItems       - List of items on first open: { name, count }
-- ============================================================
Config.Bags = {

    patrolbag = {
        label           = 'Patrol Bag',
        item            = 'patrolbag',    -- must match items.lua
        stashPrefix     = 'pbg_patrol_',
        onePerInventory = true,
        stash           = { slots = 25, weight = 25000 },
        seedOnFirstOpen = true,
        seedItems = {
            { name = 'radio',     count = 1 },
            { name = 'handcuffs', count = 2 },
            { name = 'bandage',   count = 5 },
        },
    },

    firstaid = {
        label           = 'First Aid Kit',
        item            = 'firstaid',
        stashPrefix     = 'pbg_aid_',
        onePerInventory = true,
        stash           = { slots = 20, weight = 20000 },
        seedOnFirstOpen = true,
        seedItems = {
            { name = 'bandage', count = 10 },
            { name = 'medikit', count = 2  },
        },
    },

    manv = {
        label           = 'MANV Bag',
        item            = 'manv',         -- must match items.lua
        stashPrefix     = 'pbg_manv_',
        onePerInventory = true,
        stash           = { slots = 40, weight = 40000 },
        seedOnFirstOpen = true,
        seedItems = {
            { name = 'bandage',     count = 20 },
            { name = 'medikit',     count = 6  },
            { name = 'painkillers', count = 10 },
        },
    },

    kfz_kit = {
        label           = 'Vehicle First Aid Kit',
        item            = 'kfz_kit',
        stashPrefix     = 'pbg_kfz_',
        onePerInventory = true,
        stash           = { slots = 10, weight = 8000 },
        seedOnFirstOpen = true,
        seedItems = {
            { name = 'bandage', count = 2 },
        },
    },

    --[[
    -- EXAMPLE: Add a custom bag
    mybag = {
        label           = 'My Bag',
        item            = 'mybag',        -- don't forget to register the item in ox_inventory!
        stashPrefix     = 'pbg_my_',
        onePerInventory = true,
        stash           = { slots = 15, weight = 15000 },
        seedOnFirstOpen = true,
        seedItems = {
            { name = 'water', count = 2 },
        },
    },
    --]]
}

-- ============================================================
--  DISPENSING POINTS
--  World locations where players can pick up and return bags.
--
--  Fields:
--    id      - Unique internal ID (no spaces)
--    label   - Display name in the menu
--    coords  - Position: vec4(x, y, z, heading)
--    radius  - Interaction radius (in meters)
--    jobs    - Which jobs + minimum grade have access: { jobname = minGrade }
--              Empty table {} = all players have access
--    bags    - List of bag keys available at this point
--    entity  - What is displayed at the point:
--                kind = 'ped'    → an NPC character
--                kind = 'prop'   → an object/prop
--                kind = 'marker' → only the blue marker, no object
--    target  - ox_target settings for this point (when mode = 'target')
-- ============================================================
Config.Points = {

    {
        id     = 'pol_hq',
        label  = 'Police Dispatch',
        coords = vec4(441.2, -981.9, 30.7, 90.0),
        radius = 1.8,
        jobs   = { police = 0 },              -- All police officers (grade 0+)
        bags   = { 'patrolbag', 'firstaid' },
        entity = { kind = 'ped', model = 's_m_y_cop_01', offsetZ = -1.0, freeze = true, invincible = true },
        target = { enabled = false, model = 'prop_cs_cardbox_01', offsetZ = -1.0, invisible = true },
    },

    {
        id     = 'ems_station',
        label  = 'EMS Dispatch',
        coords = vec4(306.4, -601.3, 43.3, 70.0),
        radius = 1.8,
        jobs   = { ambulance = 0 },           -- All paramedics (grade 0+)
        bags   = { 'manv', 'firstaid' },
        entity = { kind = 'prop', model = 'v_med_cor_emergencybox', offsetZ = -1.0, freeze = true, invincible = true },
        target = { enabled = false, model = 'prop_cs_cardbox_01', offsetZ = -1.0, invisible = true },
    },

    {
        id     = 'shop_vehicle',
        label  = 'Vehicle First Aid Kit',
        coords = vec4(-48.2, -1757.8, 29.4, 50.0),
        radius = 1.8,
        jobs   = {},                           -- All players have access
        bags   = { 'kfz_kit' },
        entity = { kind = 'marker' },
        target = { enabled = false, model = 'prop_cs_cardbox_01', offsetZ = -1.0, invisible = true },
    },

    --[[
    -- EXAMPLE: Add a new dispensing point
    {
        id     = 'my_point',
        label  = 'My Dispatch Point',
        coords = vec4(0.0, 0.0, 0.0, 0.0),   -- set your coordinates here
        radius = 1.8,
        jobs   = { police = 2 },              -- Only police officers with grade 2+
        bags   = { 'patrolbag' },
        entity = { kind = 'marker' },
        target = { enabled = false, model = 'prop_cs_cardbox_01', offsetZ = -1.0, invisible = true },
    },
    --]]
}
