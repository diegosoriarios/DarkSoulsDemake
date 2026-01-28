-- main.lua - Dark Souls Demake (Directional Reaction System)
-- Changes:
-- 1) Directional evasion keys (W/A/S/D) based on attack direction
-- 2) No defense menu: player must react during the warning window
-- 3) If no correct input is given before timer ends, player takes damage

function love.load()
    love.window.setTitle("Dark Souls Demake")
    love.window.setMode(800, 600)

    gameState = "combat"

    player = {
        hp = 100,
        maxHp = 100,
        stamina = 5,
        maxStamina = 5,
        unusedStamina = 0,
        attack = 15,
        defense = 5,
        x = 200,
        y = 300
    }

    enemy = {
        hp = 150,
        maxHp = 150,
        attack = 20,
        x = 550,
        y = 300,
        attackType = nil,   -- "red" or "yellow"
        attackDir = nil    -- "top", "left", "right", "bottom", "around"
    }

    turnPhase = "player" -- player, enemyWarning, iFrameWindow
    message = "Your turn"

    warningTimer = 0
    flashTimer = 0
    iFrames = 0.1  -- Reaction leniency (seconds) before AND after the impact moment
    iFrameTimer = 0

    reacted = false

    actions = {
        {name = "Light Attack", cost = 1, dmg = 1.0, key = "1"},
        {name = "Heavy Attack", cost = 2, dmg = 1.8, key = "2"},
        {name = "Special Attack", cost = 3, dmg = 2.5, key = "3"},
        {name = "Pass", cost = 0, dmg = 0, key = "space"}
    }
end

function love.update(dt)
    if turnPhase == "enemyWarning" then
        warningTimer = warningTimer - dt
        flashTimer = (flashTimer + dt * 10) % 2

        if warningTimer <= 0 then
            -- Enter iFrame window instead of immediately resolving
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
    love.graphics.setBackgroundColor(0.05, 0.05, 0.08)

    drawHUD()
    drawEntities()
    drawWarning()

    if gameState == "victory" then drawEnd("VICTORY", {1, 0.8, 0}) end
    if gameState == "defeat" then drawEnd("YOU DIED", {1, 0, 0}) end
end

function drawHUD()
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

function drawEntities()
    love.graphics.setColor(0.3, 0.6, 0.9)
    love.graphics.rectangle("fill", player.x, player.y, 60, 80)

    love.graphics.setColor(0.7, 0.2, 0.2)
    love.graphics.rectangle("fill", enemy.x, enemy.y, 80, 100)
end

function drawWarning()
    if (turnPhase ~= "enemyWarning" and turnPhase ~= "iFrameWindow") or flashTimer < 1 then return end

    local col = enemy.attackType == "red" and {1,0,0} or {1,1,0}
    love.graphics.setColor(col)

    local text = enemy.attackType == "red" and "RED ATTACK" or "YELLOW ATTACK"

    if enemy.attackDir == "around" then
        love.graphics.rectangle("line", enemy.x - 10, enemy.y - 10, 100, 120)
        love.graphics.printf(text, enemy.x - 40, enemy.y - 60, 160, "center")
    elseif enemy.attackDir == "top" then
        love.graphics.printf(text.." (W)", enemy.x - 40, enemy.y - 80, 160, "center")
    elseif enemy.attackDir == "left" then
        love.graphics.printf(text.." (A)", enemy.x - 200, enemy.y + 40, 160, "center")
    elseif enemy.attackDir == "right" then
        love.graphics.printf(text.." (D)", enemy.x + 120, enemy.y + 40, 160, "center")
    elseif enemy.attackDir == "bottom" then
        love.graphics.printf(text.." (S)", enemy.x - 40, enemy.y + 140, 160, "center")
    end
end

function love.keypressed(key)
    if gameState ~= "combat" then
        if key == "r" then love.load() end
        return
    end

    if turnPhase == "player" then
        for _, a in ipairs(actions) do
            if key == a.key and a.cost <= player.stamina then
                player.stamina = player.stamina - a.cost
                if a.dmg > 0 then
                    enemy.hp = enemy.hp - math.floor(player.attack * a.dmg)
                    message = "You attack!"
                    if enemy.hp <= 0 then gameState = "victory" return end
                end
                if player.stamina <= 0 or a.name == "Pass" then
                    -- Bank any remaining stamina as defense pool for the incoming attack
                    player.unusedStamina = player.stamina
                    player.stamina = 0
                    startEnemyAttack()
                end
            end
        end
    elseif turnPhase == "enemyWarning" or turnPhase == "iFrameWindow" then
        handleReaction(key)
    end
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
        if enemy.hp <= 0 then gameState = "victory" end
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