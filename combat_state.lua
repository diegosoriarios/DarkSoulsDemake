-- combat_state.lua - Handles turn-based combat system

local CombatState = {}
local current_enemy = nil

function CombatState.set_enemy(en)
    current_enemy = en
end

function CombatState.enter()
    if not current_enemy then
        error("No enemy set for combat state")
    end
    
    -- Initialize combat
    current_enemy.attackType = nil
    current_enemy.attackDir = nil
    _G.turnPhase = "player"
    _G.message = "Combat started!"
    player.stamina = player.maxStamina
    player.unusedStamina = 0
    _G.reacted = false
    
    _G.actions = {
        {name = "Light Attack", cost = 1, dmg = 1.0, key = "1"},
        {name = "Heavy Attack", cost = 2, dmg = 1.8, key = "2"},
        {name = "Special Attack", cost = 3, dmg = 2.5, key = "3"},
        {name = "Pass", cost = 0, dmg = 0, key = "space"}
    }
end

function CombatState.exit()
    current_enemy = nil
end

-- Shared victory handling for both kill paths (attack and parry).
local function on_enemy_defeated()
    current_enemy.defeated = true
    if current_enemy.isBoss then
        victory()
        return
    end
    local StateManager = require("state_manager")
    StateManager.set_state("world")
    if all_regular_enemies_defeated() then
        spawn_boss()
    else
        _G.message = "Enemy defeated!"
    end
end

function CombatState.update(dt)
    if _G.turnPhase == "enemyWarning" then
        _G.warningTimer = _G.warningTimer - dt
        _G.flashTimer = (_G.flashTimer + dt * 10) % 2

        if _G.warningTimer <= 0 then
            _G.turnPhase = "iFrameWindow"
            _G.iFrameTimer = _G.iFrames
        end
    elseif _G.turnPhase == "iFrameWindow" then
        _G.iFrameTimer = _G.iFrameTimer - dt
        _G.flashTimer = (_G.flashTimer + dt * 10) % 2

        if _G.iFrameTimer <= 0 then
            CombatState.resolve_enemy_attack()
        end
    end
end

function CombatState.draw()
    love.graphics.setBackgroundColor(0.05, 0.05, 0.08)

    CombatState.draw_combat_hud()
    CombatState.draw_entities()
    CombatState.draw_warning()

    -- Check for victory/defeat conditions
    if current_enemy and current_enemy.hp <= 0 then 
        CombatState.draw_end("VICTORY", {1, 0.8, 0})
    end
    if player.hp <= 0 then 
        CombatState.draw_end("YOU DIED", {1, 0, 0})
    end
end

function CombatState.draw_combat_hud()
    -- Player HP
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP", 40, 30)
    love.graphics.setColor(0.3, 0, 0)
    love.graphics.rectangle("fill", 40, 50, 250, 20)
    love.graphics.setColor(0.8, 0.1, 0.1)
    love.graphics.rectangle("fill", 40, 50, 250 * (player.hp / player.maxHp), 20)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", 40, 50, 250, 20)

    -- Enemy HP
    if current_enemy then
        love.graphics.setColor(1, 1, 1)
        love.graphics.print((current_enemy.name or "ENEMY") .. " HP", 500, 30)
        love.graphics.setColor(0.3, 0, 0)
        love.graphics.rectangle("fill", 500, 50, 250, 20)
        love.graphics.setColor(0.8, 0.1, 0.1)
        love.graphics.rectangle("fill", 500, 50, 250 * (current_enemy.hp / current_enemy.maxHp), 20)
        love.graphics.setColor(1, 1, 1)
        love.graphics.rectangle("line", 500, 50, 250, 20)
    end

    -- Stamina
    love.graphics.print("STAMINA: " .. player.stamina, 40, 80)
    love.graphics.print("DEFENSE POOL: " .. player.unusedStamina, 40, 100)

    -- Message
    love.graphics.print(_G.message, 40, 140)

    -- Player actions
    if _G.turnPhase == "player" then
        for i, a in ipairs(_G.actions) do
            local c = a.cost <= player.stamina and {1,1,1} or {0.4,0.4,0.4}
            love.graphics.setColor(c)
            love.graphics.print("["..a.key.."] "..a.name.." ("..a.cost..")", 40, 180 + i*20)
        end
    end
end

function CombatState.draw_entities()
    love.graphics.setColor(0.3, 0.6, 0.9)
    love.graphics.rectangle("fill", 200, 300, 60, 80)

    if current_enemy then
        local c = current_enemy.color or {0.7, 0.2, 0.2}
        local w, h = 80, 100
        if current_enemy.isBoss then
            w, h = 130, 160
        end
        love.graphics.setColor(c[1], c[2], c[3])
        love.graphics.rectangle("fill", 550, 300 - (h - 100) / 2, w, h)
    end
end

function CombatState.draw_warning()
    if not current_enemy then return end
    if (_G.turnPhase ~= "enemyWarning" and _G.turnPhase ~= "iFrameWindow") or _G.flashTimer < 1 then return end

    local col = current_enemy.attackType == "red" and {1,0,0} or {1,1,0}
    love.graphics.setColor(col)

    local text = current_enemy.attackType == "red" and "RED ATTACK" or "YELLOW ATTACK"

    if current_enemy.attackDir == "around" then
        love.graphics.rectangle("line", 550 - 10, 300 - 10, 100, 120)
        love.graphics.printf(text, 550 - 40, 300 - 60, 160, "center")
    elseif current_enemy.attackDir == "top" then
        love.graphics.printf(text.." (W)", 550 - 40, 300 - 80, 160, "center")
    elseif current_enemy.attackDir == "left" then
        love.graphics.printf(text.." (A)", 550 - 200, 300 + 40, 160, "center")
    elseif current_enemy.attackDir == "right" then
        love.graphics.printf(text.." (D)", 550 + 120, 300 + 40, 160, "center")
    elseif current_enemy.attackDir == "bottom" then
        love.graphics.printf(text.." (S)", 550 - 40, 300 + 140, 160, "center")
    end
end

function CombatState.draw_end(text, color)
    love.graphics.setColor(color)
    love.graphics.printf(text, 0, 260, 800, "center", 0, 3)
    love.graphics.setColor(1,1,1)
    love.graphics.printf("Press R to restart", 0, 330, 800, "center")
end

function CombatState.keypressed(key)
    if _G.turnPhase == "player" then
        for _, a in ipairs(_G.actions) do
            if key == a.key and a.cost <= player.stamina then
                player.stamina = player.stamina - a.cost
                if a.dmg > 0 and current_enemy then
                    current_enemy.hp = current_enemy.hp - math.floor(player.attack * a.dmg)
                    _G.message = "You attack!"
                    if current_enemy.hp <= 0 then
                        on_enemy_defeated()
                        return
                    end
                end
                if player.stamina <= 0 or a.name == "Pass" then
                    player.unusedStamina = player.stamina
                    player.stamina = 0
                    CombatState.start_enemy_attack()
                end
            end
        end
    elseif _G.turnPhase == "enemyWarning" or _G.turnPhase == "iFrameWindow" then
        CombatState.handle_reaction(key)
    elseif (current_enemy and current_enemy.hp <= 0) or player.hp <= 0 then
        if key == "r" then love.load() end
    end
end

function CombatState.start_enemy_attack()
    if not current_enemy then return end
    
    _G.turnPhase = "enemyWarning"
    _G.reacted = false
    _G.warningTimer = current_enemy.warningTime or 1.0

    local redWeight = current_enemy.redWeight or 0.5
    current_enemy.attackType = math.random() < redWeight and "red" or "yellow"

    local dirs = {"top", "left", "right", "bottom", "around"}
    current_enemy.attackDir = dirs[math.random(#dirs)]

    _G.message = "INCOMING ATTACK!"
end

function CombatState.handle_reaction(key)
    if _G.reacted or player.unusedStamina <= 0 or not current_enemy then return end

    local evadeKey = {
        top = "w",
        left = "a",
        right = "d",
        bottom = "s",
        around = nil
    }

    -- Evade
    if current_enemy.attackDir == "around" and (key == "w" or key == "a" or key == "s" or key == "d") then
        player.unusedStamina = player.unusedStamina - 1
        _G.reacted = true
        _G.message = "EVADED"
        return
    elseif evadeKey[current_enemy.attackDir] == key then
        player.unusedStamina = player.unusedStamina - 1
        _G.reacted = true
        _G.message = "EVADED"
        return
    end

    -- Parry (yellow only)
    if key == "p" and current_enemy.attackType == "yellow" and player.unusedStamina > 0 then
        current_enemy.hp = current_enemy.hp - current_enemy.attack
        _G.reacted = true
        _G.message = "PARRY!"
        if current_enemy.hp <= 0 then
            on_enemy_defeated()
        end
    end
end

function CombatState.resolve_enemy_attack()
    if not current_enemy then return end

    if not _G.reacted then
        local dmg = math.max(0, current_enemy.attack - player.defense)
        player.hp = player.hp - dmg
        _G.message = "HIT! -"..dmg.." HP"
    end

    player.stamina = player.maxStamina
    player.unusedStamina = 0
    _G.turnPhase = "player"

    if player.hp <= 0 then
        game_over()
    end
end

return CombatState