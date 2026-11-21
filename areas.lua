-- areas.lua - Ring-and-spokes world layout, rooms, doors, transitions
--
-- Floors are built from axis-aligned region rectangles into a tile grid used
-- for collision and rendering. Doors are stateful blockers; transitions move
-- the player between areas (the Cistern stub is playable in this phase).

local Areas = {}

Areas.TILE = 32

local function R(x, y, w, h, name, tint)
    return { x = x, y = y, w = w, h = h, name = name, tint = tint }
end

-- Palette
local C = {
    hub = {0.13, 0.11, 0.08},
    gate = {0.10, 0.10, 0.12},
    salt = {0.14, 0.13, 0.11},
    archive = {0.07, 0.10, 0.12},
    fungal = {0.11, 0.07, 0.12},
    ring = {0.10, 0.09, 0.09},
    cistern = {0.07, 0.09, 0.10},
}

Areas.list = {}

Areas.list.main = {
    id = "main",
    name = "The Guttering Reach",
    cols = 64,
    rows = 48,
    background = {0.035, 0.035, 0.045},
    start = { x = 1024, y = 820 },
    boss_spawn = { x = 1024, y = 380 },
    regions = {
        -- Hub
        R(672, 640, 704, 320, "Wayfarer's Rest", C.hub),
        -- Northlight
        R(992, 512, 96, 128, "The Northlight Gate", C.gate),
        R(832, 288, 384, 224, "The Northlight Gate", C.gate),
        -- Salt spoke
        R(480, 736, 192, 96, "The Salt Flats", C.salt),
        R(128, 576, 352, 352, "The Salt Flats", C.salt),
        -- Archive spoke
        R(1376, 736, 192, 96, "The Drowned Archive", C.archive),
        R(1568, 576, 352, 352, "The Drowned Archive", C.archive),
        -- Fungal spoke
        R(992, 960, 96, 192, "The Fungal Terrace", C.fungal),
        R(704, 1152, 640, 320, "The Fungal Terrace", C.fungal),
        -- Broken aqueduct ring (west and east loops)
        R(256, 928, 96, 384, "The Broken Aqueduct", C.ring),
        R(352, 1216, 352, 96, "The Broken Aqueduct", C.ring),
        R(1696, 928, 96, 384, "The Broken Aqueduct", C.ring),
        R(1344, 1216, 352, 96, "The Broken Aqueduct", C.ring),
    },
    doors = {
        {
            id = "northlight", x = 992, y = 560, w = 96, h = 24,
            label = "Northlight fog", requires = { embers = 3 },
            kind = "fog",
        },
        {
            id = "ring_west", x = 480, y = 1216, w = 32, h = 96,
            label = "Collapsed gate", requires = { guardian = "sentinel" },
            kind = "locked",
        },
        {
            id = "ring_east", x = 1504, y = 1216, w = 32, h = 96,
            label = "Collapsed gate", requires = { guardian = "warden" },
            kind = "locked",
        },
    },
    transitions = {
        {
            id = "cistern", x = 160, y = 592, w = 64, h = 64,
            to_area = "cistern", to_x = 300, to_y = 580,
            label = "Sunken Cistern",
        },
        {
            id = "vault", x = 1860, y = 600, w = 64, h = 64,
            to_area = "vault", to_x = 300, to_y = 580,
            label = "Drowned Vault",
        },
        {
            id = "hollow", x = 1240, y = 1400, w = 64, h = 64,
            to_area = "hollow", to_x = 300, to_y = 580,
            label = "Spore Hollow",
        },
    },
    vigils = {
        { id = "vigil_hub", name = "Wayfarer's Rest", x = 1024, y = 780 },
        { id = "vigil_fungal", name = "Fungal Terrace", x = 1250, y = 1200 },
    },
    spawns = {
        -- Salt Flats
        { id = "salt_thrall_1", archetype = "hollow", x = 350, y = 700 },
        { id = "salt_thrall_2", archetype = "hollow", x = 450, y = 850 },
        { id = "salt_acolyte_1", archetype = "knight", x = 220, y = 640 },
        { id = "guardian_warden", guardian = "warden", x = 300, y = 760 },
        -- Drowned Archive
        { id = "cat_acolyte_1", archetype = "knight", x = 1650, y = 650 },
        { id = "cat_acolyte_2", archetype = "knight", x = 1850, y = 850 },
        { id = "guardian_sentinel", guardian = "sentinel", x = 1740, y = 760 },
        -- Fungal Terrace
        { id = "dep_bloater_1", archetype = "brute", x = 850, y = 1300 },
        { id = "dep_thrall_1", archetype = "hollow", x = 1200, y = 1380 },
        { id = "guardian_caustic_brute", guardian = "caustic_brute",
          x = 1024, y = 1300 },
        -- Broken Aqueduct
        { id = "ring_thrall_1", archetype = "hollow", x = 600, y = 1250 },
        { id = "ring_acolyte_1", archetype = "knight", x = 1400, y = 1250 },
    },
    items = {
        { id = "it_hub_1", type = "health", x = 800, y = 780 },
        { id = "it_salt_1", type = "stamina", x = 200, y = 700 },
        { id = "it_salt_2", type = "health", x = 420, y = 880 },
        { id = "it_archive_1", type = "stamina", x = 1600, y = 800 },
        { id = "it_archive_2", type = "health", x = 1880, y = 700 },
        { id = "it_fungal_1", type = "health", x = 760, y = 1200 },
        { id = "it_fungal_2", type = "stamina", x = 1300, y = 1420 },
        { id = "it_ring_1", type = "health", x = 700, y = 1250 },
    },
}

-- --- Side dungeons -------------------------------------------------------
-- All three share a compact four-room layout: entry, main hall, boss
-- corridor, and a mini-boss room with a locked cache.

local function make_dungeon(opts)
    local id = opts.id
    local tint = opts.tint
    local spawns = {
        { id = id .. "_thrall_1", archetype = "hollow", x = 400, y = 220 },
        { id = id .. "_thrall_2", archetype = "hollow", x = 620, y = 280 },
        { id = id .. "_acolyte_1", archetype = "knight", x = 360, y = 320 },
        { id = id .. "_miniboss", miniboss = opts.miniboss,
          x = 1008, y = 260 },
    }
    if opts.bloater then
        spawns[#spawns + 1] = {
            id = id .. "_bloater_1", archetype = "brute", x = 700, y = 200,
        }
    end

    return {
        id = id,
        name = opts.name,
        cols = 36,
        rows = 22,
        background = {0.03, 0.035, 0.04},
        start = { x = 300, y = 580 },
        vigils = opts.vigil and { opts.vigil } or {},
        regions = {
            R(128, 512, 256, 128, opts.name, tint),
            R(320, 352, 128, 160, opts.name, tint),
            R(256, 160, 512, 192, opts.name, tint),
            R(768, 224, 128, 128, opts.name, tint),
            R(896, 128, 224, 256, opts.name, tint),
        },
        doors = {},
        transitions = {
            {
                id = id .. "_exit", x = 160, y = 536, w = 64, h = 64,
                to_area = opts.back_area, to_x = opts.back_x,
                to_y = opts.back_y, label = opts.back_label,
            },
        },
        spawns = spawns,
        cache = {
            id = id .. "_cache", x = 1040, y = 150, w = 48, h = 48,
            trinket = opts.trinket, lumens = opts.lumens,
            draughts = opts.draughts or 0, sigils = opts.sigils or 0,
            requires_miniboss = id .. "_miniboss",
        },
        items = {},
    }
end

Areas.list.cistern = make_dungeon({
    id = "cistern", name = "The Sunken Cistern",
    tint = C.cistern, miniboss = "cistern_lurker",
    vigil = { id = "vigil_cistern", name = "Sunken Cistern", x = 700, y = 200 },
    back_area = "main", back_x = 300, back_y = 700,
    back_label = "Back to the Salt Flats",
    trinket = "ember_shard", lumens = 80, draughts = 1,
})

Areas.list.vault = make_dungeon({
    id = "vault", name = "The Drowned Vault",
    tint = {0.12, 0.09, 0.06}, miniboss = "vault_warden", bloater = true,
    back_area = "main", back_x = 1780, back_y = 720,
    back_label = "Back to the Drowned Archive",
    trinket = "hone_shard", lumens = 100, draughts = 2,
})

Areas.list.hollow = make_dungeon({
    id = "hollow", name = "The Spore Hollow",
    tint = {0.12, 0.06, 0.12}, miniboss = "hollow_mother",
    back_area = "main", back_x = 1160, back_y = 1340,
    back_label = "Back to the Fungal Terrace",
    trinket = "vessel", lumens = 120, sigils = 1, draughts = 1,
})

function Areas.get(id)
    return Areas.list[id]
end

function Areas.prepare()
    for _, area in pairs(Areas.list) do
        area.tile = Areas.TILE
        area.width = area.cols * area.tile
        area.height = area.rows * area.tile
        area.floor = {}
        area.tint = {}
        area.region = {}
        for ty = 1, area.rows do
            area.floor[ty] = {}
            area.tint[ty] = {}
            area.region[ty] = {}
            for tx = 1, area.cols do
                area.floor[ty][tx] = false
            end
        end
        for _, r in ipairs(area.regions) do
            local tx1 = math.floor(r.x / area.tile) + 1
            local ty1 = math.floor(r.y / area.tile) + 1
            local tx2 = math.floor((r.x + r.w - 1) / area.tile) + 1
            local ty2 = math.floor((r.y + r.h - 1) / area.tile) + 1
            for ty = ty1, ty2 do
                for tx = tx1, tx2 do
                    if area.floor[ty] and area.floor[ty][tx] ~= nil then
                        area.floor[ty][tx] = true
                        area.tint[ty][tx] = r.tint
                        area.region[ty][tx] = r.name
                    end
                end
            end
        end
        for _, d in ipairs(area.doors or {}) do d.open = false end
        area.transitions = area.transitions or {}
        area.vigils = area.vigils or {}
        area.spawns = area.spawns or {}
        area.items = area.items or {}
        area.cache = area.cache or nil
    end
end

function Areas.region_at(area, x, y)
    local tx = math.floor(x / area.tile) + 1
    local ty = math.floor(y / area.tile) + 1
    if area.region[ty] and area.region[ty][tx] then
        return area.region[ty][tx]
    end
    return nil
end

Areas.prepare()

return Areas
