-- enemies.lua - Enemy archetypes, guardians, and spawning
--
-- Every enemy carries its own combat personality: stats, telegraph time
-- (warningTime, in seconds), how often it throws red (dodge-only) vs yellow
-- (parryable) attacks (redWeight), and its stamina tempo budget.

local Enemies = {}

local Sprites = require("sprites")

local SOULS_REWARD = {
    hollow = 12,
    knight = 18,
    brute = 25,
}

local ARCHETYPES = {
    hollow = {
        name = "Thrall",
        hp = 60,
        attack = 12,
        warningTime = 1.2,   -- slow telegraph, forgiving
        redWeight = 0.3,     -- mostly yellow: parry practice
        maxStamina = 4,      -- tempo budget per round
        attackCost = 2,      -- stamina spent per attack
        color = {0.55, 0.5, 0.45},
        width = 22,
        height = 32,
    },
    knight = {
        name = "Shard Acolyte",
        hp = 80,
        attack = 15,
        warningTime = 1.0,   -- the old baseline timing
        redWeight = 0.5,
        maxStamina = 5,
        attackCost = 2,
        color = {0.7, 0.2, 0.2},
        width = 25,
        height = 35,
    },
    brute = {
        name = "Bloater",
        hp = 130,
        attack = 22,
        warningTime = 0.85,  -- short telegraph, hits hard
        redWeight = 0.75,    -- mostly red: dodge or die
        maxStamina = 6,
        attackCost = 3,
        color = {0.6, 0.1, 0.5},
        width = 34,
        height = 44,
    },
}

-- Zone guardians: stronger versions that drop a Lord Soul.
local GUARDIANS = {
    warden = {
        name = "Brine Warden",
        hp = 90,
        attack = 14,
        warningTime = 1.05,
        redWeight = 0.4,
        maxStamina = 4,
        attackCost = 2,
        color = {0.85, 0.72, 0.42},
        width = 30,
        height = 42,
        souls = 100,
    },
    sentinel = {
        name = "Tidewarden",
        hp = 120,
        attack = 18,
        warningTime = 0.95,
        redWeight = 0.5,
        maxStamina = 5,
        attackCost = 2,
        color = {0.95, 0.35, 0.25},
        width = 34,
        height = 48,
        souls = 100,
    },
    caustic_brute = {
        name = "Sporecaller",
        hp = 170,
        attack = 24,
        warningTime = 0.80,
        redWeight = 0.7,
        maxStamina = 6,
        attackCost = 3,
        color = {0.75, 0.18, 0.62},
        width = 44,
        height = 56,
        souls = 100,
    },
}

-- Side-dungeon mini-bosses: tough single foes that guard a cache.
local MINIBOSSES = {
    cistern_lurker = {
        name = "Cistern Lurker", hp = 150, attack = 20,
        warningTime = 0.95, redWeight = 0.6, maxStamina = 5, attackCost = 2,
        color = {0.35, 0.70, 0.85}, width = 42, height = 54, souls = 60,
    },
    vault_warden = {
        name = "Vault Warden", hp = 180, attack = 22,
        warningTime = 0.85, redWeight = 0.6, maxStamina = 6, attackCost = 3,
        color = {0.85, 0.55, 0.20}, width = 44, height = 56, souls = 70,
    },
    hollow_mother = {
        name = "Hollow Mother", hp = 200, attack = 23,
        warningTime = 0.80, redWeight = 0.7, maxStamina = 6, attackCost = 3,
        color = {0.70, 0.30, 0.70}, width = 46, height = 58, souls = 80,
    },
}

local BOSS = {
    name = "The Guttering King",
    hp = 300,
    maxHp = 300,
    attack = 25,
    warningTime = 0.65,    -- true reaction check
    redWeight = 0.5,
    maxStamina = 8,
    attackCost = 3,
    color = {1.0, 0.45, 0.1},
    width = 55,
    height = 75,
    isBoss = true,
    souls = 0,
}

local function base_from_archetype(a, id)
    return {
        id = id,
        name = a.name,
        hp = a.hp,
        maxHp = a.hp,
        attack = a.attack,
        warningTime = a.warningTime,
        redWeight = a.redWeight,
        maxStamina = a.maxStamina,
        stamina = a.maxStamina,
        attackCost = a.attackCost,
        color = a.color,
        width = a.width,
        height = a.height,
        souls = 0,
        vis = Sprites.new_vis(),
        active = false,
        defeated = false,
        isBoss = false,
        isGuardian = false,
        isMiniboss = false,
    }
end

-- Build a regular enemy from a zone spawn definition.
function Enemies.spawn_from_def(def)
    local a = ARCHETYPES[def.archetype]
    local en = base_from_archetype(a, def.id)
    en.archetype = def.archetype
    en.zone = def.zone
    en.souls = SOULS_REWARD[def.archetype] or 0
    en.x = def.x
    en.y = def.y
    return en
end

-- Build a guardian from one of the guardian definitions.
function Enemies.spawn_guardian(key, id, x, y, zone)
    local g = GUARDIANS[key]
    local en = base_from_archetype(g, id)
    en.name = g.name
    en.guardian_key = key
    en.zone = zone
    en.isGuardian = true
    en.gives_lord_soul = true
    en.souls = g.souls or 100
    en.x = x
    en.y = y
    return en
end

function Enemies.spawn_miniboss(key, id, x, y, area)
    local m = MINIBOSSES[key]
    local en = base_from_archetype(m, id)
    en.name = m.name
    en.miniboss_key = key
    en.isMiniboss = true
    en.souls = m.souls or 60
    en.x = x
    en.y = y
    en.area = area
    return en
end

function Enemies.get_boss()
    local boss = {}
    for k, v in pairs(BOSS) do
        boss[k] = v
    end
    boss.id = "boss_ashen_lord"
    boss.vis = Sprites.new_vis()
    boss.stamina = boss.maxStamina
    boss.isGuardian = false
    return boss
end

return Enemies
