-- progress.lua - Run state: objectives, souls, Lord Souls, upgrades
--
-- Single source of truth for the pilgrimage. Combat and the bonfire report
-- events here; the world HUD/journal and the save file read from here.

local Progress = {}

local GUARDIAN_KEYS = { "warden", "sentinel", "caustic_brute" }

local OBJECTIVES = {
    {
        id = "rest",
        title = "Keep the Vigil",
        desc = "Rest at the Vigil in Wayfarer's Rest.",
    },
    {
        id = "warden",
        title = "Fell the Brine Warden",
        desc = "The Brine Warden stalks the Salt Flats.",
    },
    {
        id = "sentinel",
        title = "Fell the Tidewarden",
        desc = "The Tidewarden holds the Drowned Archive.",
    },
    {
        id = "caustic_brute",
        title = "Fell the Sporecaller",
        desc = "The Sporecaller festers in the Fungal Terrace.",
    },
    {
        id = "souls",
        title = "Gather the Embers",
        desc = "Claim all three Embers to part the Northlight fog.",
    },
    {
        id = "boss",
        title = "Defeat the Guttering King",
        desc = "End the Rust at the Northlight Gate.",
    },
}

-- The summoned Lantern-Bearer ally.
Progress.ALLY_TEMPLATE = {
    name = "Lantern-Bearer",
    maxHp = 80,
    attack = 12,
    defense = 4,
    maxStamina = 5,
}
Progress.ALLY_FIGHTS = 3

-- Permanent trinkets found in dungeon caches.
Progress.TRINKETS = {
    ember_shard = {
        name = "Ember Shard", desc = "+1 Max Stamina",
        apply = function(p)
            p.maxStamina = p.maxStamina + 1
            p.stamina = p.maxStamina
        end,
    },
    hone_shard = {
        name = "Hone Shard", desc = "+3 Attack",
        apply = function(p) p.attack = p.attack + 3 end,
    },
    warden_seal = {
        name = "Warden's Seal", desc = "+2 Defense",
        apply = function(p) p.defense = p.defense + 2 end,
    },
    vessel = {
        name = "Vessel", desc = "+20 Max HP",
        apply = function(p)
            p.maxHp = p.maxHp + 20
            p.hp = p.hp + 20
        end,
    },
}

Progress.UPGRADES = {
    { id = "hp", name = "Vitality", desc = "+20 Max HP", max = 3, base_cost = 40 },
    { id = "atk", name = "Might", desc = "+3 Attack", max = 3, base_cost = 50 },
    { id = "sta", name = "Breath", desc = "+1 Max Stamina", max = 2, base_cost = 60 },
    { id = "def", name = "Ward", desc = "+2 Defense", max = 2, base_cost = 40 },
}

function Progress.reset()
    Progress.souls = 0
    Progress.lord_souls = {}
    Progress.upgrades = { hp = 0, atk = 0, sta = 0, def = 0 }
    Progress.boss_unlocked = false
    Progress.boss_defeated = false
    Progress.rested = false
    Progress.parries = 0
    Progress.parry_bounty_claimed = false
    Progress.opened_doors = {}
    Progress.discovered_areas = {}
    Progress.last_vigil = nil
    Progress.lit_vigils = {}
    Progress.lost_lantern = nil
    Progress.trinkets = {}
    Progress.items = { draught = 0, sigil = 0 }
    Progress.caches = {}
    Progress.ally = { active = false, fights_left = 0, hp = 0, maxHp = 0 }
end

Progress.reset()

function Progress.lord_soul_count()
    local n = 0
    for _, key in ipairs(GUARDIAN_KEYS) do
        if Progress.lord_souls[key] then n = n + 1 end
    end
    return n
end

function Progress.is_complete(id)
    if id == "rest" then return Progress.rested end
    if id == "souls" then return Progress.lord_soul_count() >= 3 end
    if id == "boss" then return Progress.boss_defeated end
    -- guardian objectives use the guardian key as their id
    return Progress.lord_souls[id] == true
end

function Progress.objectives()
    local list = {}
    for _, obj in ipairs(OBJECTIVES) do
        list[#list + 1] = {
            id = obj.id,
            title = obj.title,
            desc = obj.desc,
            complete = Progress.is_complete(obj.id),
        }
    end
    return list
end

-- The first unfinished objective, for the HUD tracker.
function Progress.current_objective()
    for _, obj in ipairs(OBJECTIVES) do
        if not Progress.is_complete(obj.id) then
            return { id = obj.id, title = obj.title, desc = obj.desc }
        end
    end
    return nil
end

function Progress.upgrade_def(id)
    for _, def in ipairs(Progress.UPGRADES) do
        if def.id == id then return def end
    end
    return nil
end

function Progress.upgrade_cost(def)
    return def.base_cost * (Progress.upgrades[def.id] + 1)
end

function Progress.upgrade_rank(def)
    return Progress.upgrades[def.id] or 0
end

function Progress.can_buy(def)
    return Progress.upgrade_rank(def) < def.max
        and Progress.souls >= Progress.upgrade_cost(def)
end

local function autosave()
    if type(save_game) == "function" then save_game() end
end

function Progress.buy_upgrade(id)
    local def = Progress.upgrade_def(id)
    if not def or not Progress.can_buy(def) then return false end

    Progress.souls = Progress.souls - Progress.upgrade_cost(def)
    Progress.upgrades[def.id] = Progress.upgrade_rank(def) + 1

    if def.id == "hp" then
        player.maxHp = player.maxHp + 20
        player.hp = player.hp + 20
    elseif def.id == "atk" then
        player.attack = player.attack + 3
    elseif def.id == "sta" then
        player.maxStamina = player.maxStamina + 1
        player.stamina = player.maxStamina
    elseif def.id == "def" then
        player.defense = player.defense + 2
    end

    _G.message = def.name .. " increased!"
    autosave()
    return true
end

function Progress.reward_souls(amount)
    Progress.souls = Progress.souls + (amount or 0)
end

function Progress.enemy_defeated(en)
    if not en then return end
    Progress.reward_souls(en.souls or 0)

    if en.isGuardian and en.guardian_key
        and not Progress.lord_souls[en.guardian_key] then
        Progress.lord_souls[en.guardian_key] = true
        _G.message = "Ember claimed: " .. en.name .. "!"
        if Progress.lord_soul_count() >= 3 and not Progress.boss_unlocked then
            Progress.boss_unlocked = true
            _G.message = "The Northlight fog parts..."
        end
    end

    autosave()
end

function Progress.boss_slain()
    Progress.boss_defeated = true
    autosave()
end

function Progress.rest(v, area_id, area_name)
    Progress.rested = true
    if v then
        Progress.rest_at_vigil(v, area_id, area_name)
    end
    autosave()
end

function Progress.parry()
    Progress.parries = Progress.parries + 1
    if not Progress.parry_bounty_claimed and Progress.parries >= 3 then
        Progress.parry_bounty_claimed = true
        Progress.reward_souls(30)
    end
end

function Progress.summon_ally()
    if Progress.ally.active then
        return false, "An ally already fights beside you."
    end
    if (Progress.items.sigil or 0) < 1 then
        return false, "You have no Beacon Sigils."
    end
    Progress.items.sigil = Progress.items.sigil - 1
    local t = Progress.ALLY_TEMPLATE
    Progress.ally = {
        active = true,
        fights_left = Progress.ALLY_FIGHTS,
        hp = t.maxHp,
        maxHp = t.maxHp,
    }
    autosave()
    return true
end

function Progress.heal_ally()
    if Progress.ally and Progress.ally.active then
        Progress.ally.hp = Progress.ally.maxHp
    end
end

function Progress.clear_ally()
    if Progress.ally then
        Progress.ally.active = false
        Progress.ally.fights_left = 0
        Progress.ally.hp = 0
    end
end

-- Called when an encounter ends. Returns true when the ally departs.
function Progress.ally_encounter_done(died, hp)
    if not Progress.ally or not Progress.ally.active then return false end
    Progress.ally.hp = math.max(0, math.floor(tonumber(hp) or Progress.ally.hp))
    Progress.ally.fights_left = math.max(0,
        (Progress.ally.fights_left or 0) - 1)
    local departed = died or Progress.ally.hp <= 0
        or Progress.ally.fights_left <= 0
    if departed then
        Progress.ally.active = false
        Progress.ally.fights_left = 0
        Progress.ally.hp = 0
    end
    autosave()
    return departed
end

function Progress.has_trinket(id)
    return Progress.trinkets[id] == true
end

function Progress.grant_trinket(id)
    local def = Progress.TRINKETS[id]
    if not def or Progress.trinkets[id] then return nil end
    Progress.trinkets[id] = true
    def.apply(player)
    return def
end

function Progress.cache_opened(id)
    return Progress.caches[id] == true
end

-- Grant a dungeon cache's contents. Returns a summary or nil if already open.
function Progress.open_cache(cache)
    if not cache or Progress.caches[cache.id] then return nil end
    Progress.caches[cache.id] = true

    local summary = {}
    if cache.trinket then
        local def = Progress.grant_trinket(cache.trinket)
        if def then summary[#summary + 1] = def.name end
    end
    if (cache.lumens or 0) > 0 then
        Progress.reward_souls(cache.lumens)
        summary[#summary + 1] = cache.lumens .. " Lumen"
    end
    if (cache.draughts or 0) > 0 then
        Progress.items.draught = (Progress.items.draught or 0) + cache.draughts
        summary[#summary + 1] = cache.draughts .. " Lantern Draught(s)"
    end
    if (cache.sigils or 0) > 0 then
        Progress.items.sigil = (Progress.items.sigil or 0) + cache.sigils
        summary[#summary + 1] = cache.sigils .. " Beacon Sigil(s)"
    end
    autosave()
    return summary
end

function Progress.use_draught()
    if (Progress.items.draught or 0) < 1 then return 0 end
    if player.hp >= player.maxHp then return 0 end
    Progress.items.draught = Progress.items.draught - 1
    local healed = math.min(40, player.maxHp - player.hp)
    player.hp = player.hp + healed
    autosave()
    return healed
end

function Progress.is_door_open(id)
    return Progress.opened_doors[id] == true
end

function Progress.open_door(id)
    if Progress.opened_doors[id] then return false end
    Progress.opened_doors[id] = true
    return true
end

function Progress.vigil_lit(id)
    return Progress.lit_vigils[id] ~= nil
end

-- Resting lights the Vigil and makes it the respawn point.
function Progress.rest_at_vigil(v, area_id, area_name)
    local info = {
        id = v.id, area = area_id, x = v.x, y = v.y,
        name = area_name or area_id,
    }
    Progress.lit_vigils[v.id] = info
    Progress.last_vigil = info
end

function Progress.drop_lantern(area, x, y)
    local amount = Progress.souls
    Progress.souls = 0
    if amount > 0 then
        Progress.lost_lantern = {
            area = area, x = x, y = y, amount = amount,
        }
    end
    return amount
end

function Progress.recover_lantern()
    local lantern = Progress.lost_lantern
    if not lantern then return 0 end
    Progress.lost_lantern = nil
    Progress.reward_souls(lantern.amount)
    return lantern.amount
end

function Progress.discover_area(id)
    if Progress.discovered_areas[id] then return false end
    Progress.discovered_areas[id] = true
    return true
end

-- --- Persistence helpers --------------------------------------------------

function Progress.to_table()
    local lord = {}
    for key, v in pairs(Progress.lord_souls) do
        if v then lord[key] = true end
    end
    return {
        souls = Progress.souls,
        lord_souls = lord,
        upgrades = {
            hp = Progress.upgrades.hp,
            atk = Progress.upgrades.atk,
            sta = Progress.upgrades.sta,
            def = Progress.upgrades.def,
        },
        boss_unlocked = Progress.boss_unlocked,
        boss_defeated = Progress.boss_defeated,
        rested = Progress.rested,
        parries = Progress.parries,
        parry_bounty_claimed = Progress.parry_bounty_claimed,
        opened_doors = Progress.opened_doors,
        discovered_areas = Progress.discovered_areas,
        last_vigil = Progress.last_vigil,
        lit_vigils = Progress.lit_vigils,
        lost_lantern = Progress.lost_lantern,
        trinkets = Progress.trinkets,
        items = Progress.items,
        caches = Progress.caches,
        ally = Progress.ally,
    }
end

function Progress.from_table(t)
    Progress.reset()
    if type(t) ~= "table" then return end

    Progress.souls = math.max(0, math.floor(tonumber(t.souls) or 0))
    if type(t.lord_souls) == "table" then
        for _, key in ipairs(GUARDIAN_KEYS) do
            if t.lord_souls[key] == true then Progress.lord_souls[key] = true end
        end
    end
    if type(t.upgrades) == "table" then
        for _, def in ipairs(Progress.UPGRADES) do
            local rank = math.floor(tonumber(t.upgrades[def.id]) or 0)
            Progress.upgrades[def.id] = math.max(0, math.min(def.max, rank))
        end
    end
    Progress.boss_unlocked = t.boss_unlocked == true
    Progress.boss_defeated = t.boss_defeated == true
    Progress.rested = t.rested == true
    Progress.parries = math.max(0, math.floor(tonumber(t.parries) or 0))
    Progress.parry_bounty_claimed = t.parry_bounty_claimed == true
    if type(t.opened_doors) == "table" then
        for id, v in pairs(t.opened_doors) do
            if v == true and type(id) == "string" then
                Progress.opened_doors[id] = true
            end
        end
    end
    if type(t.discovered_areas) == "table" then
        for id, v in pairs(t.discovered_areas) do
            if v == true and type(id) == "string" then
                Progress.discovered_areas[id] = true
            end
        end
    end
    if type(t.lit_vigils) == "table" then
        for id, v in pairs(t.lit_vigils) do
            if type(id) == "string" and type(v) == "table" then
                Progress.lit_vigils[id] = {
                    id = id,
                    area = type(v.area) == "string" and v.area or nil,
                    x = tonumber(v.x),
                    y = tonumber(v.y),
                    name = type(v.name) == "string" and v.name or id,
                }
            end
        end
    end
    if type(t.last_vigil) == "table" then
        local lv = t.last_vigil
        Progress.last_vigil = {
            id = type(lv.id) == "string" and lv.id or nil,
            area = type(lv.area) == "string" and lv.area or nil,
            x = tonumber(lv.x),
            y = tonumber(lv.y),
            name = type(lv.name) == "string" and lv.name or nil,
        }
    end
    if type(t.trinkets) == "table" then
        for id, v in pairs(t.trinkets) do
            if v == true and Progress.TRINKETS[id] then
                Progress.trinkets[id] = true
            end
        end
    end
    if type(t.items) == "table" then
        Progress.items.draught =
            math.max(0, math.floor(tonumber(t.items.draught) or 0))
        Progress.items.sigil =
            math.max(0, math.floor(tonumber(t.items.sigil) or 0))
    end
    if type(t.caches) == "table" then
        for id, v in pairs(t.caches) do
            if v == true and type(id) == "string" then
                Progress.caches[id] = true
            end
        end
    end
    if type(t.ally) == "table" then
        Progress.ally = {
            active = t.ally.active == true,
            fights_left = math.max(0, math.floor(tonumber(t.ally.fights_left)
                or 0)),
            hp = math.max(0, math.floor(tonumber(t.ally.hp) or 0)),
            maxHp = math.max(0, math.floor(tonumber(t.ally.maxHp) or 0)),
        }
        if Progress.ally.maxHp <= 0 then
            Progress.ally.maxHp = Progress.ALLY_TEMPLATE.maxHp
        end
        if Progress.ally.hp <= 0 and Progress.ally.active then
            Progress.ally.hp = Progress.ally.maxHp
        end
    end
    if type(t.lost_lantern) == "table" then
        local ll = t.lost_lantern
        local amount = math.max(0, math.floor(tonumber(ll.amount) or 0))
        if amount > 0 and type(ll.area) == "string" then
            Progress.lost_lantern = {
                area = ll.area,
                x = tonumber(ll.x) or 0,
                y = tonumber(ll.y) or 0,
                amount = amount,
            }
        end
    end
end

return Progress
