-- main.lua - Dark Souls Demake with Open World
-- Features:
-- 1) Open world exploration with WASD movement
-- 2) Item pickups scattered around the world
-- 3) Random enemy encounters
-- 4) Combat system integrated with world

function love.load()
    love.window.setTitle("Dark Souls Demake")
    love.window.setMode(1200, 800)

    gameState = "world" -- world, combat

    -- Player
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
        inventory = {}
    }

    -- World
    world = {
        width = 2000,
        height = 1500,
        items = {},
        enemies = {}
    }

    -- Camera
    camera = {
        x = 0,
        y = 0
    }

    -- Combat variables
    enemy = nil
    turnPhase = "player"
    message = "Your turn"
    warningTimer = 0
    flashTimer = 0
    iFrames = 0.1
    iFrameTimer = 0
    reacted = false

    actions = {
        {name = "Light Attack", cost = 1, dmg = 1.0, key = "1"},
        {name = "Heavy Attack", cost = 2, dmg = 1.8, key = "2"},
        {name = "Special Attack", cost = 3, dmg = 2.5, key = "3"},
        {name = "Pass", cost = 0, dmg = 0, key = "space"}
    }

    -- Generate world items
    generateWorldItems()
    generateWorldEnemies()
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
    world.enemies = {}
    for i = 1, 5 do
        table.insert(world.enemies, {
            hp = 80,
            maxHp = 80,
            attack = 15,
            x = math.random(200, world.width - 200),
            y = math.random(200, world.height - 200),
            width = 25,
            height = 35,
            active = false,
            defeated = false
        })
    end
end

function love.update(dt)
    if gameState == "world" then
        updateWorld(dt)
    elseif gameState == "combat" then
        updateCombat(dt)
    end
end

function updateWorld(dt)
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
                    message = "Picked up Health Potion! +30 HP"
                else
                    player.stamina = math.min(player.maxStamina, player.stamina + 2)
                    message = "Picked up Stamina Flask! +2 Stamina"
                end
            end
        end
    end

    -- Check enemy encounters
    for _, en in ipairs(world.enemies) do
        if not en.defeated then
            local dist = math.sqrt((player.x - en.x)^2 + (player.y - en.y)^2)
            if dist < 50 then
                startCombat(en)
            end
        end
    end
end

function updateCombat(dt)
    if turnPhase == "enemyWarning" then
        warningTimer = warningTimer - dt
        flashTimer = (flashTimer + dt * 10) % 2

        if warningTimer <= 0 then
            turnPhase = "iFrameWindow"
            iFrameTimer = iFrames
        end
    elseif turnPhase == "iFrameWindow" then
        iFrameTimer = iFrameTimer - dt
        flashTimer = (flashTimer + dt * 10) % 2

        if iFrameTimer <= 0 then
            resolveEnemyAttack()
        end
    end
end

function love.draw()
    if gameState == "world" then
        drawWorld()
    elseif gameState == "combat" then
        drawCombat()
    end
end

function drawWorld()
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
            love.graphics.setColor(0.7, 0.2, 0.2)
            love.graphics.rectangle("fill", en.x - camera.x, en.y - camera.y, en.width, en.height)
            -- Draw HP bar above enemy
            love.graphics.setColor(0.3, 0, 0)
            love.graphics.rectangle("fill", en.x - camera.x, en.y - camera.y - 15, en.width, 5)
            love.graphics.setColor(0.8, 0.1, 0.1)
            love.graphics.rectangle("fill", en.x - camera.x, en.y - camera.y - 15, en.width * (en.hp / en.maxHp), 5)
        end
    end

    -- Draw player
    love.graphics.setColor(0.3, 0.6, 0.9)
    love.graphics.rectangle("fill", player.x - camera.x, player.y - camera.y, player.width, player.height)

    -- Draw HUD
    drawWorldHUD()
end

function drawWorldHUD()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. player.hp .. " / " .. player.maxHp, 20, 20)
    love.graphics.print("STAMINA: " .. player.stamina, 20, 50)
    love.graphics.print("Position: " .. math.floor(player.x) .. ", " .. math.floor(player.y), 20, 80)
    love.graphics.print("Use WASD to move, approach enemies to fight", 20, 110)
end

function drawCombat()
    love.graphics.setBackgroundColor(0.05, 0.05, 0.08)

    drawCombatHUD()
    drawCombatEntities()
    drawCombatWarning()

    if gameState == "victory" then drawEnd("VICTORY", {1, 0.8, 0}) end
    if gameState == "defeat" then drawEnd("YOU DIED", {1, 0, 0}) end
end

function drawCombatHUD()
    -- Player HP
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP", 40, 30)
    love.graphics.setColor(0.3, 0, 0)
    love.graphics.rectangle("fill", 40, 50, 250, 20)
    love.graphics.setColor(0.8, 0.1, 0.1)
    love.graphics.rectangle("fill", 40, 50, 250 * (player.hp / player.maxHp), 20)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 40, 50, 250, 20)

    -- Stamina
    love.graphics.print("STAMINA: " .. player.stamina, 40, 80)
    love.graphics.print("DEFENSE POOL: " .. player.unusedStamina, 40, 100)

    -- Message
    love.graphics.print(message, 40, 140)

    -- Player actions
    if turnPhase == "player" then
        for i, a in ipairs(actions) do
            local c = a.cost <= player.stamina and {1,1,1} or {0.4,0.4,0.4}
            love.graphics.setColor(c)
            love.graphics.print("["..a.key.."] "..a.name.." ("..a.cost..")", 40, 180 + i*20)
        end
    end
end

function drawCombatEntities()
    love.graphics.setColor(0.3, 0.6, 0.9)
    love.graphics.rectangle("fill", 200, 300, 60, 80)

    love.graphics.setColor(0.7, 0.2, 0.2)
    love.graphics.rectangle("fill", 550, 300, 80, 100)
end

function drawCombatWarning()
    if (turnPhase ~= "enemyWarning" and turnPhase ~= "iFrameWindow") or flashTimer < 1 then return end

    local col = enemy.attackType == "red" and {1,0,0} or {1,1,0}
    love.graphics.setColor(col)

    local text = enemy.attackType == "red" and "RED ATTACK" or "YELLOW ATTACK"

    if enemy.attackDir == "around" then
        love.graphics.rectangle("line", 550 - 10, 300 - 10, 100, 120)
        love.graphics.printf(text, 550 - 40, 300 - 60, 160, "center")
    elseif enemy.attackDir == "top" then
        love.graphics.printf(text.." (W)", 550 - 40, 300 - 80, 160, "center")
    elseif enemy.attackDir == "left" then
        love.graphics.printf(text.." (A)", 550 - 200, 300 + 40, 160, "center")
    elseif enemy.attackDir == "right" then
        love.graphics.printf(text.." (D)", 550 + 120, 300 + 40, 160, "center")
    elseif enemy.attackDir == "bottom" then
        love.graphics.printf(text.." (S)", 550 - 40, 300 + 140, 160, "center")
    end
end

function love.keypressed(key)
    if gameState == "world" then
        if key == "r" then love.load() end
    elseif gameState == "combat" then
        if turnPhase == "player" then
            for _, a in ipairs(actions) do
                if key == a.key and a.cost <= player.stamina then
                    player.stamina = player.stamina - a.cost
                    if a.dmg > 0 then
                        enemy.hp = enemy.hp - math.floor(player.attack * a.dmg)
                        message = "You attack!"
                        if enemy.hp <= 0 then
                            enemy.defeated = true
                            gameState = "world"
                            message = "Enemy defeated!"
                            return
                        end
                    end
                    if player.stamina <= 0 or a.name == "Pass" then
                        player.unusedStamina = player.stamina
                        player.stamina = 0
                        startEnemyAttack()
                    end
                end
            end
        elseif turnPhase == "enemyWarning" or turnPhase == "iFrameWindow" then
            handleReaction(key)
        elseif gameState == "victory" or gameState == "defeat" then
            if key == "r" then love.load() end
        end
    end
end

function startCombat(en)
    gameState = "combat"
    enemy = en
    enemy.attackType = nil
    enemy.attackDir = nil
    turnPhase = "player"
    message = "Combat started!"
    player.stamina = player.maxStamina
    player.unusedStamina = 0
    reacted = false
end

function startEnemyAttack()
    turnPhase = "enemyWarning"
    reacted = false
    warningTimer = 1.0

    enemy.attackType = math.random() < 0.5 and "red" or "yellow"

    local dirs = {"top", "left", "right", "bottom", "around"}
    enemy.attackDir = dirs[math.random(#dirs)]

    message = "INCOMING ATTACK!"
end

function handleReaction(key)
    if reacted or player.unusedStamina <= 0 then return end

    local evadeKey = {
        top = "w",
        left = "a",
        right = "d",
        bottom = "s",
        around = nil
    }

    -- Evade
    if enemy.attackDir == "around" and (key == "w" or key == "a" or key == "s" or key == "d") then
        player.unusedStamina = player.unusedStamina - 1
        reacted = true
        message = "EVADED"
        return
    elseif evadeKey[enemy.attackDir] == key then
        player.unusedStamina = player.unusedStamina - 1
        reacted = true
        message = "EVADED"
        return
    end

    -- Parry (yellow only)
    if key == "p" and enemy.attackType == "yellow" and player.unusedStamina > 0 then
        enemy.hp = enemy.hp - enemy.attack
        reacted = true
        message = "PARRY!"
        if enemy.hp <= 0 then
            enemy.defeated = true
            gameState = "world"
        end
    end
end

function resolveEnemyAttack()
    if not reacted then
        local dmg = math.max(0, enemy.attack - player.defense)
        player.hp = player.hp - dmg
        message = "HIT! -"..dmg.." HP"
        if player.hp <= 0 then gameState = "defeat" end
    end

    player.stamina = player.maxStamina
    player.unusedStamina = 0
    turnPhase = "player"
end

function drawEnd(text, color)
    love.graphics.setColor(color)
    love.graphics.printf(text, 0, 260, 800, "center", 0, 3)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Press R to restart", 0, 330, 800, "center")
end