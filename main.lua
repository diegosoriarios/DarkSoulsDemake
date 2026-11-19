-- main.lua - Dark Souls Demake with State Management
-- Features:
-- 1) Open world exploration with WASD movement
-- 2) Item pickups scattered around the world
-- 3) Random enemy encounters
-- 4) Combat system integrated with world
-- 5) Organized state management system

-- Import state manager
local StateManager = require("state_manager")
local Sprites = require("sprites")

function love.load()
    love.window.setTitle("Dark Souls Demake")
    love.window.setMode(1200, 800)

    -- Load character sprites before anything draws
    Sprites.load()

    -- Initialize player (shared across states)
    player = {
        hp = 100,
        maxHp = 100,
        stamina = 5,
        maxStamina = 5,
        unusedStamina = 0,
        attack = 15,
        defense = 5,
        x = 600,
        y = 400,
        width = 20,
        height = 30,
        speed = 200,
        vis = Sprites.new_vis(),
        inventory = {}
    }

    -- Initialize world (for world state)
    world = {
        width = 2000,
        height = 1500,
        items = {},
        enemies = {},
        boss = nil
    }

    -- Initialize camera (for world state)
    camera = {
        x = 0,
        y = 0
    }

    -- Combat variables (for combat state)
    turnPhase = "player"
    message = "Welcome to Dark Souls Demake"
    warningTimer = 0
    flashTimer = 0
    iFrames = 0.3
    iFrameTimer = 0
    reacted = false

    -- Generate world content
    generateWorldItems()
    generateWorldEnemies()

    -- Import and register states
    local WorldState = require("world_state")
    local CombatState = require("combat_state")
    local MenuState = require("menu_state")

    StateManager.add_state("world", WorldState)
    StateManager.add_state("combat", CombatState)
    StateManager.add_state("menu", MenuState)

    -- Boot to the main menu (reset any stale victory/gameover screen)
    MenuState.set_menu_type("main")
    StateManager.set_state("menu")
end

function generateWorldItems()
    world.items = {}
    for i = 1, 15 do
        table.insert(world.items, {
            x = math.random(100, world.width - 100),
            y = math.random(100, world.height - 100),
            type = math.random(1, 3) == 1 and "health" or "stamina",
            collected = false
        })
    end
end

function generateWorldEnemies()
    local Enemies = require("enemies")
    world.enemies = Enemies.spawn_world_enemies(world.width, world.height)
end

function all_regular_enemies_defeated()
    for _, en in ipairs(world.enemies) do
        if not en.defeated then return false end
    end
    return true
end

function spawn_boss()
    local Enemies = require("enemies")
    world.boss = Enemies.get_boss()
    world.boss.x = math.random(300, world.width - 300)
    world.boss.y = math.random(300, world.height - 300)
    _G.message = "A great presence stirs... something approaches!"
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

-- Helper function to restart the game
function restart_game()
    love.load()
end

-- Helper function to handle game over
function game_over()
    local MenuState = require("menu_state")
    MenuState.set_menu_type("gameover")
    StateManager.set_state("menu")
end

-- Helper function to handle victory
function victory()
    local MenuState = require("menu_state")
    MenuState.set_menu_type("victory")
    StateManager.set_state("menu")
end