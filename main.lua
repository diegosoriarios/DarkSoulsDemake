-- main.lua - Lanternfall: a pilgrimage through the Guttering Reach
--
-- Areas are connected rooms (hub + spokes + ring) with tile collision,
-- doors and transitions. Lumen buys upgrades at the Vigil; Embers from the
-- Wardens open the Northlight Gate.

local StateManager = require("state_manager")
local Sprites = require("sprites")
local Enemies = require("enemies")
local Areas = require("areas")
local Progress = require("progress")
local Save = require("save")

local function make_player()
    local start = Areas.list.main.start
    return {
        hp = 100,
        maxHp = 100,
        stamina = 5,
        maxStamina = 5,
        unusedStamina = 0,
        attack = 15,
        defense = 5,
        x = start.x,
        y = start.y,
        width = 20,
        height = 30,
        speed = 200,
        vis = Sprites.new_vis(),
        inventory = {},
    }
end

-- Build every area's enemies and items into flat lists tagged by area.
function build_world()
    local area = Areas.get("main")
    world = {
        area_id = area.id,
        area = area,
        width = area.width,
        height = area.height,
        items = {},
        enemies = {},
        boss = nil,
    }

    for id, a in pairs(Areas.list) do
        for _, def in ipairs(a.spawns) do
            local en
            if def.guardian then
                en = Enemies.spawn_guardian(def.guardian, def.id, def.x,
                    def.y, id)
            elseif def.miniboss then
                en = Enemies.spawn_miniboss(def.miniboss, def.id, def.x,
                    def.y, id)
            else
                en = Enemies.spawn_from_def(def)
            end
            en.area = id
            world.enemies[#world.enemies + 1] = en
        end
        for _, item in ipairs(a.items) do
            world.items[#world.items + 1] = {
                id = item.id, area = id, type = item.type,
                x = item.x, y = item.y, collected = false,
            }
        end
    end
end

function sync_area_size()
    world.width = world.area.width
    world.height = world.area.height
end

-- Move the player to an area without saving (callers decide on autosave).
function set_area(area_id, x, y)
    local area = Areas.get(area_id) or Areas.get("main")
    world.area_id = area.id
    world.area = area
    sync_area_size()
    player.x = x or area.start.x
    player.y = y or area.start.y
    camera.x = player.x - 600
    camera.y = player.y - 400
    Progress.discover_area(area.id)
end

function spawn_boss()
    world.boss = Enemies.get_boss()
    local spawn = Areas.list.main.boss_spawn
    world.boss.x = spawn.x
    world.boss.y = spawn.y
    world.boss.area = "main"
    _G.message = "The Guttering King stirs at the Northlight Gate!"
end

function player_died()
    -- Scatter lumen as a Lost Lantern at the death spot.
    Progress.drop_lantern(world.area_id, player.x, player.y)
    Progress.clear_ally()

    local v = Progress.last_vigil
    if not v or not v.area then
        local hub = Areas.list.main
        local hv = hub.vigils[1]
        v = {
            id = hv.id, area = "main", x = hv.x, y = hv.y,
            name = hub.name,
        }
    end

    player.hp = player.maxHp
    player.stamina = player.maxStamina
    player.unusedStamina = 0
    player.vis = Sprites.new_vis()

    set_area(v.area, v.x, v.y)

    -- A boss you were fighting resets to full.
    if world.boss and not world.boss.defeated then
        world.boss.hp = world.boss.maxHp
        world.boss.stamina = world.boss.maxStamina
        world.boss.vis = Sprites.new_vis()
    end
    respawn_regular_enemies()

    save_game()

    local StateManager = require("state_manager")
    StateManager.set_state("world")
    _G.message = "Your light fades... you wake at the Vigil of "
        .. (v.name or v.area) .. "."
end

function respawn_regular_enemies()
    for _, en in ipairs(world.enemies) do
        if not en.isGuardian and not en.isMiniboss and not en.isBoss then
            en.defeated = false
            en.hp = en.maxHp
            en.stamina = en.maxStamina
            en.vis = Sprites.new_vis()
        end
    end
end

-- --- Save / load ----------------------------------------------------------

function save_game()
    if not player or not world then return end
    local defeated = {}
    for _, en in ipairs(world.enemies) do
        if en.defeated then defeated[en.id] = true end
    end
    Save.write({
        player = {
            x = player.x,
            y = player.y,
            hp = player.hp,
            maxHp = player.maxHp,
            attack = player.attack,
            defense = player.defense,
            maxStamina = player.maxStamina,
        },
        progress = Progress.to_table(),
        area = world.area_id,
        defeated = defeated,
    })
end

function load_game()
    local data = Save.read()
    if not data then return false end

    Progress.from_table(data.progress)
    player.vis = Sprites.new_vis()

    local p = type(data.player) == "table" and data.player or {}
    player.maxHp = tonumber(p.maxHp) or 100
    player.attack = tonumber(p.attack) or 15
    player.defense = tonumber(p.defense) or 5
    player.maxStamina = tonumber(p.maxStamina) or 5
    player.hp = math.min(tonumber(p.hp) or player.maxHp, player.maxHp)
    if player.hp < 1 then player.hp = 1 end
    player.stamina = player.maxStamina
    player.unusedStamina = 0

    build_world()
    if type(data.defeated) == "table" then
        for _, en in ipairs(world.enemies) do
            if data.defeated[en.id] then
                en.defeated = true
                en.hp = 0
            end
        end
    end
    if Progress.boss_unlocked and not Progress.boss_defeated then
        spawn_boss()
    end

    set_area(data.area or "main", tonumber(p.x), tonumber(p.y))
    return true
end

function new_game()
    Save.erase()
    love.load()
    StateManager.set_state("world")
    save_game()
end

function continue_game()
    if load_game() then
        StateManager.set_state("world")
        return true
    end
    return false
end

-- --- LÖVE callbacks -------------------------------------------------------

function love.load()
    love.window.setTitle("Lanternfall")
    love.window.setMode(1200, 800)

    Sprites.load()

    player = make_player()
    Progress.reset()
    build_world()
    camera = { x = 0, y = 0 }
    set_area("main")

    -- Combat globals
    turnPhase = "player"
    message = "Welcome to the Guttering Reach"
    warningTimer = 0
    flashTimer = 0
    iFrames = 0.3
    iFrameTimer = 0
    reacted = false

    local WorldState = require("world_state")
    local CombatState = require("combat_state")
    local MenuState = require("menu_state")
    local VigilState = require("bonfire_state")

    StateManager.add_state("world", WorldState)
    StateManager.add_state("combat", CombatState)
    StateManager.add_state("menu", MenuState)
    StateManager.add_state("bonfire", VigilState)

    MenuState.set_menu_type("main")
    StateManager.set_state("menu")
end

function love.update(dt)
    StateManager.update(dt)
end

function love.draw()
    StateManager.draw()
end

function love.keypressed(key)
    StateManager.keypressed(key)
end

function love.mousepressed(x, y, button)
    StateManager.mousepressed(x, y, button)
end

function restart_game()
    new_game()
end

function game_over()
    local MenuState = require("menu_state")
    MenuState.set_menu_type("gameover")
    StateManager.set_state("menu")
end

function victory()
    Progress.boss_slain()
    save_game()
    local MenuState = require("menu_state")
    MenuState.set_menu_type("victory")
    StateManager.set_state("menu")
end
