-- enemies.lua - Enemy archetype definitions and spawning
--
-- Replaces the old dead boss_fight.lua prototype. Every enemy carries its
-- own combat personality: stats, telegraph time (warningTime, in seconds),
-- and how often it throws red (dodge-only) vs yellow (parryable) attacks
-- (redWeight, 0..1).

local Enemies = {}

local ARCHETYPES = {
    hollow = {
        name = "Hollow",
        hp = 60,
        attack = 12,
        warningTime = 1.2,   -- slow telegraph, forgiving
        redWeight = 0.3,     -- mostly yellow: parry practice
        color = {0.55, 0.5, 0.45},
        width = 22,
        height = 32,
    },
    knight = {
        name = "Knight",
        hp = 80,
        attack = 15,
        warningTime = 1.0,   -- the old baseline timing
        redWeight = 0.5,
        color = {0.7, 0.2, 0.2},
        width = 25,
        height = 35,
    },
    brute = {
        name = "Brute",
        hp = 130,
        attack = 22,
        warningTime = 0.85,  -- short telegraph, hits hard
        redWeight = 0.75,    -- mostly red: dodge or die
        color = {0.6, 0.1, 0.5},
        width = 34,
        height = 44,
    },
}

local BOSS = {
    name = "Ashen Lord",
    hp = 300,
    maxHp = 300,
    attack = 25,
    warningTime = 0.65,    -- true reaction check
    redWeight = 0.5,
    color = {1.0, 0.45, 0.1},
    width = 55,
    height = 75,
    isBoss = true,
}

function Enemies.get_boss()
    local boss = {}
    for k, v in pairs(BOSS) do
        boss[k] = v
    end
    return boss
end

-- World composition: 2 hollows, 2 knights, 1 brute.
function Enemies.spawn_world_enemies(world_width, world_height)
    local order = { "hollow", "hollow", "knight", "knight", "brute" }
    local list = {}
    for _, key in ipairs(order) do
        local a = ARCHETYPES[key]
        list[#list + 1] = {
            name = a.name,
            archetype = key,
            hp = a.hp,
            maxHp = a.hp,
            attack = a.attack,
            warningTime = a.warningTime,
            redWeight = a.redWeight,
            color = a.color,
            x = math.random(200, world_width - 200),
            y = math.random(200, world_height - 200),
            width = a.width,
            height = a.height,
            active = false,
            defeated = false,
            isBoss = false,
        }
    end
    return list
end

return Enemies
