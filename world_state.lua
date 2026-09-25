-- world_state.lua - Handles world exploration and movement

local WorldState = {}

function WorldState.enter()
    -- Reset or initialize world-specific variables
    _G.message = "Explore the world with WASD"
end

function WorldState.exit()
    -- Clean up when leaving world state
end

function WorldState.update(dt)
    -- Player movement
    if love.keyboard.isDown("w") then
        player.y = math.max(0, player.y - player.speed * dt)
    end
    if love.keyboard.isDown("s") then
        player.y = math.min(world.height, player.y + player.speed * dt)
    end
    if love.keyboard.isDown("a") then
        player.x = math.max(0, player.x - player.speed * dt)
    end
    if love.keyboard.isDown("d") then
        player.x = math.min(world.width, player.x + player.speed * dt)
    end

    -- Update camera to follow player
    camera.x = player.x - 600
    camera.y = player.y - 400

    -- Check item pickups
    for _, item in ipairs(world.items) do
        if not item.collected then
            local dist = math.sqrt((player.x - item.x)^2 + (player.y - item.y)^2)
            if dist < 30 then
                item.collected = true
                if item.type == "health" then
                    player.hp = math.min(player.maxHp, player.hp + 30)
                    _G.message = "Picked up Health Potion! +30 HP"
                else
                    player.stamina = math.min(player.maxStamina, player.stamina + 2)
                    _G.message = "Picked up Stamina Flask! +2 Stamina"
                end
            end
        end
    end

    -- Check enemy encounters
    for _, en in ipairs(world.enemies) do
        if not en.defeated then
            local dist = math.sqrt((player.x - en.x)^2 + (player.y - en.y)^2)
            if dist < 50 then
                -- Transition to combat state
                local StateManager = require("state_manager")
                local CombatState = require("combat_state")
                CombatState.set_enemy(en)
                StateManager.set_state("combat")
                return
            end
        end
    end

    -- Check boss encounter
    local boss = world.boss
    if boss and not boss.defeated then
        local dist = math.sqrt((player.x - boss.x)^2 + (player.y - boss.y)^2)
        if dist < 60 then
            local StateManager = require("state_manager")
            local CombatState = require("combat_state")
            CombatState.set_enemy(boss)
            StateManager.set_state("combat")
        end
    end
end

function WorldState.draw()
    love.graphics.setBackgroundColor(0.05, 0.05, 0.08)

    -- Draw world bounds
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("line", -camera.x, -camera.y, world.width, world.height)

    -- Draw items
    for _, item in ipairs(world.items) do
        if not item.collected then
            if item.type == "health" then
                love.graphics.setColor(1, 0.2, 0.2)
            else
                love.graphics.setColor(0.2, 0.8, 1)
            end
            love.graphics.circle("fill", item.x - camera.x, item.y - camera.y, 8)
        end
    end

    -- Draw enemies
    for _, en in ipairs(world.enemies) do
        if not en.defeated then
            local c = en.color or {0.7, 0.2, 0.2}
            love.graphics.setColor(c[1], c[2], c[3])
            love.graphics.rectangle("fill", en.x - camera.x, en.y - camera.y, en.width, en.height)
            -- Draw HP bar above enemy
            love.graphics.setColor(0.3, 0, 0)
            love.graphics.rectangle("fill", en.x - camera.x, en.y - camera.y - 15, en.width, 5)
            love.graphics.setColor(0.8, 0.1, 0.1)
            love.graphics.rectangle("fill", en.x - camera.x, en.y - camera.y - 15, en.width * (en.hp / en.maxHp), 5)
        end
    end

    -- Draw boss
    local boss = world.boss
    if boss and not boss.defeated then
        love.graphics.setColor(boss.color[1], boss.color[2], boss.color[3])
        love.graphics.rectangle("fill", boss.x - camera.x, boss.y - camera.y, boss.width, boss.height)
        -- Glowing outline so it reads as something special
        love.graphics.setColor(1, 0.45, 0.1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", boss.x - camera.x - 4, boss.y - camera.y - 4, boss.width + 8, boss.height + 8)
        love.graphics.setLineWidth(1)
        -- Boss HP bar
        love.graphics.setColor(0.3, 0, 0)
        love.graphics.rectangle("fill", boss.x - camera.x, boss.y - camera.y - 15, boss.width, 5)
        love.graphics.setColor(1, 0.2, 0.1)
        love.graphics.rectangle("fill", boss.x - camera.x, boss.y - camera.y - 15, boss.width * (boss.hp / boss.maxHp), 5)
    end

    -- Draw player
    love.graphics.setColor(0.3, 0.6, 0.9)
    love.graphics.rectangle("fill", player.x - camera.x, player.y - camera.y, player.width, player.height)

    -- Draw HUD
    WorldState.draw_hud()
end

function WorldState.draw_hud()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. player.hp .. " / " .. player.maxHp, 20, 20)
    love.graphics.print("STAMINA: " .. player.stamina, 20, 50)

    local remaining = 0
    for _, en in ipairs(world.enemies) do
        if not en.defeated then remaining = remaining + 1 end
    end
    love.graphics.print("Enemies remaining: " .. remaining, 20, 80)

    if world.boss and not world.boss.defeated then
        love.graphics.setColor(1, 0.45, 0.1)
        love.graphics.print("!!! " .. world.boss.name .. " AWAITS !!!", 20, 110)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Slay it to break the curse", 20, 140)
    else
        love.graphics.print("Use WASD to move, approach enemies to fight", 20, 140)
    end
    love.graphics.print(_G.message, 20, 170)
end

function WorldState.keypressed(key)
    if key == "r" then
        love.load()
    end
end

return WorldState