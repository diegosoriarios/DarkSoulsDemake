-- combat_state.lua - Darkest Dungeon-style turn-based combat
--
-- Layout: player on the left, enemy on the right, status panels on top,
-- a clickable action bar at the bottom. Each round the player spends
-- stamina on actions, then ends the turn (or runs out) and the enemy
-- telegraphs and visibly lunges before the hit lands.

local Sprites = require("sprites")
local UI = require("ui")

local CombatState = {}
local current_enemy = nil

local ACTIONS = {
    { id = "light", name = "Light Attack", cost = 1, dmg = 1.0, key = "1" },
    { id = "heavy", name = "Heavy Attack", cost = 2, dmg = 1.8, key = "2" },
    { id = "special", name = "Special Attack", cost = 3, dmg = 2.5, key = "3" },
}

local YIELD_KEY = "space"

-- Floating damage numbers
local popups = {}
local POPUP_LIFE = 0.9

-- Button rects rebuilt every draw and hit-tested by mousepressed.
local buttons = {}

local function add_popup(x, y, text, color)
    popups[#popups + 1] = {
        x = x, y = y, text = text, color = color, t = 0,
    }
end

local function update_popups(dt)
    for i = #popups, 1, -1 do
        local p = popups[i]
        p.t = p.t + dt
        if p.t >= POPUP_LIFE then table.remove(popups, i) end
    end
end

local function draw_popups()
    for _, p in ipairs(popups) do
        local k = p.t / POPUP_LIFE
        local y = p.y - 46 * k
        local alpha = 1 - k
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.print(p.text, p.x, y, 0, 1.6, 1.6)
    end
    love.graphics.setColor(1, 1, 1)
end

function CombatState.set_enemy(en)
    current_enemy = en
end

function CombatState.enter()
    if not current_enemy then
        error("No enemy set for combat state")
    end

    -- Visual fx state
    if not current_enemy.vis then current_enemy.vis = Sprites.new_vis() end
    player.vis.walking = false
    player.vis.faceX = 1
    current_enemy.vis.faceX = -1
    Sprites.shakeT = 0
    CombatState.pending_transition = nil
    popups = {}

    -- Initialize combat
    current_enemy.attackType = nil
    current_enemy.attackDir = nil
    current_enemy.maxStamina = current_enemy.maxStamina or 5
    current_enemy.attackCost = current_enemy.attackCost or 2
    current_enemy.stamina = current_enemy.maxStamina
    _G.turnPhase = "player"
    _G.message = "Combat started! Choose an action."
    player.stamina = player.maxStamina
    player.unusedStamina = 0
    _G.reacted = false
end

function CombatState.exit()
    current_enemy = nil
    popups = {}
end

-- Shared victory handling for both kill paths (attack and parry).
-- Deferral: play the death collapse before changing state.
local function on_enemy_defeated()
    if CombatState.pending_transition then return end
    current_enemy.defeated = true
    Sprites.kill(current_enemy.vis)
    if current_enemy.isBoss then
        CombatState.pending_transition = { type = "victory", victim = current_enemy }
        _G.message = "The " .. current_enemy.name .. " falls!"
        return
    end
    local spawn_boss_next = all_regular_enemies_defeated()
    CombatState.pending_transition = {
        type = "world",
        spawn_boss = spawn_boss_next,
        victim = current_enemy,
    }
    _G.message = spawn_boss_next and "The last enemy falls... something stirs!"
        or "Enemy defeated!"
end

-- Execute the transition deferred by a death animation.
function CombatState.perform_transition()
    local t = CombatState.pending_transition
    CombatState.pending_transition = nil
    if t.type == "victory" then
        victory()
    elseif t.type == "gameover" then
        game_over()
    else
        local StateManager = require("state_manager")
        StateManager.set_state("world")
        if t.spawn_boss then spawn_boss() end
    end
end

-- --- Combat actions -------------------------------------------------------

-- Tempo model: both sides spend their own stamina. After each player action
-- the enemy cuts in whenever it has at least as much stamina left as the
-- player; otherwise the player keeps acting. An "exchange" ends when a side
-- cannot afford its cheapest action, at which point both pools refill.

function CombatState.refill_round()
    player.stamina = player.maxStamina
    if current_enemy then
        current_enemy.stamina = current_enemy.maxStamina
    end
end

local function hand_to_enemy()
    -- Bank the player's remaining stamina as the defense pool, then strike.
    player.unusedStamina = player.stamina
    CombatState.start_enemy_attack()
end

-- Yield: cede the initiative now, even with stamina to spare.
function CombatState.yield_turn()
    if CombatState.pending_transition then return end
    if _G.turnPhase ~= "player" then return end
    if current_enemy.stamina < current_enemy.attackCost then
        CombatState.refill_round()
    end
    _G.message = "You yield the initiative."
    hand_to_enemy()
end

local function perform_action(a)
    if CombatState.pending_transition then return end
    if _G.turnPhase ~= "player" then return end
    if a.cost > player.stamina then return end

    player.stamina = player.stamina - a.cost
    Sprites.lunge(player.vis, 1)

    local dmg = math.floor(player.attack * a.dmg)
    current_enemy.hp = current_enemy.hp - dmg
    Sprites.recoil(current_enemy.vis, -1)
    Sprites.hit_flash(current_enemy.vis)
    Sprites.shake(3 + a.cost)
    add_popup(CombatState.enemy_cx, CombatState.enemy_top,
        "-" .. dmg, {1, 0.85, 0.4})
    _G.message = a.name .. " hits for " .. dmg .. "!"

    if current_enemy.hp <= 0 then
        on_enemy_defeated()
        return
    end

    -- Tempo check: does the enemy cut in?
    local enemy_can_strike = current_enemy.stamina >= current_enemy.attackCost
    if player.stamina < 1 or player.stamina <= current_enemy.stamina then
        if enemy_can_strike then
            hand_to_enemy()
        else
            -- Enemy is spent; the exchange resets and the player keeps going.
            CombatState.refill_round()
            _G.message = _G.message .. " The enemy falters - new exchange!"
        end
    else
        _G.message = _G.message .. " You keep the initiative."
    end
end

function CombatState.update(dt)
    -- Advance visual fx
    Sprites.update_vis(player.vis, dt)
    Sprites.update_shake(dt)
    if current_enemy then Sprites.update_vis(current_enemy.vis, dt) end
    update_popups(dt)

    -- While a death animation plays, freeze combat logic
    if CombatState.pending_transition then
        if Sprites.death_done(CombatState.pending_transition.victim.vis) then
            CombatState.perform_transition()
        end
        return
    end

    if _G.turnPhase == "enemyWarning" then
        -- Telegraph wobble: lean back repeatedly while winding up
        if current_enemy.vis.recoilT == nil then
            Sprites.recoil(current_enemy.vis, -1)
        end
        _G.warningTimer = _G.warningTimer - dt
        _G.flashTimer = (_G.flashTimer + dt * 6) % 2

        if _G.warningTimer <= 0 then
            _G.turnPhase = "iFrameWindow"
            _G.iFrameTimer = _G.iFrames
            -- Visible attack: the enemy lunges while the reaction window is open
            Sprites.lunge(current_enemy.vis, -1)
            if not _G.reacted then _G.message = "The enemy strikes!" end
        end
    elseif _G.turnPhase == "iFrameWindow" then
        _G.iFrameTimer = _G.iFrameTimer - dt
        _G.flashTimer = (_G.flashTimer + dt * 10) % 2

        if _G.iFrameTimer <= 0 then
            CombatState.resolve_enemy_attack()
        end
    end
end

-- --- Drawing --------------------------------------------------------------

local function layout()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local groundY = H - 250
    return {
        W = W,
        H = H,
        groundY = groundY,
        player_cx = W * 0.30,
        player_bottom = groundY,
        player_w = 170,
        player_h = 230,
        enemy_cx = W * 0.68,
        enemy_bottom = groundY,
        enemy_w = 190,
        enemy_h = 250,
        boss_w = 300,
        boss_h = 380,
    }
end

function CombatState.draw()
    love.graphics.setBackgroundColor(0.04, 0.04, 0.06)
    local L = layout()

    local ew, eh = L.enemy_w, L.enemy_h
    if current_enemy and current_enemy.isBoss then
        ew, eh = L.boss_w, L.boss_h
    end
    CombatState.player_cx = L.player_cx
    CombatState.player_top = L.player_bottom - L.player_h
    CombatState.enemy_cx = L.enemy_cx
    CombatState.enemy_top = L.enemy_bottom - eh

    CombatState.draw_stage(L)
    CombatState.draw_panels(L)
    CombatState.draw_turn_indicator(L)
    CombatState.draw_entities(L)
    draw_popups()
    CombatState.draw_warning(L)
    CombatState.draw_action_bar(L)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(_G.message, 0, 96, L.W, "center")

    if current_enemy and current_enemy.hp <= 0 then
        CombatState.draw_end("VICTORY", {1, 0.8, 0}, L)
    end
    if player.hp <= 0 then
        CombatState.draw_end("YOU DIED", {1, 0, 0}, L)
    end
end

function CombatState.draw_stage(L)
    -- Ground strip
    love.graphics.setColor(0.10, 0.09, 0.08)
    love.graphics.rectangle("fill", 0, L.groundY, L.W, L.H - L.groundY)
    love.graphics.setColor(0.28, 0.24, 0.18)
    love.graphics.setLineWidth(2)
    love.graphics.line(0, L.groundY, L.W, L.groundY)
    love.graphics.setLineWidth(1)
end

local function draw_bar(x, y, w, h, frac, back, fill)
    love.graphics.setColor(back)
    love.graphics.rectangle("fill", x, y, w, h, 3, 3)
    love.graphics.setColor(fill)
    love.graphics.rectangle("fill", x, y, w * math.max(0, frac), h, 3, 3)
    love.graphics.setColor(0.75, 0.7, 0.6)
    love.graphics.rectangle("line", x, y, w, h, 3, 3)
end

function CombatState.draw_panels(L)
    -- Player panel (top-left)
    love.graphics.setColor(0.9, 0.88, 0.82)
    love.graphics.print("WANDERER", 40, 26)
    draw_bar(40, 48, 360, 22, player.hp / player.maxHp,
        {0.25, 0.05, 0.05}, {0.75, 0.12, 0.12})
    love.graphics.setColor(0.85, 0.83, 0.78)
    love.graphics.print(player.hp .. " / " .. player.maxHp, 300, 50)

    -- Stamina pips (gold = current tempo stamina)
    for i = 1, player.maxStamina do
        local px = 40 + (i - 1) * 30
        if i <= player.stamina then
            love.graphics.setColor(0.85, 0.7, 0.25)
        else
            love.graphics.setColor(0.18, 0.17, 0.17)
        end
        love.graphics.rectangle("fill", px, 82, 24, 12, 2, 2)
        love.graphics.setColor(0.5, 0.45, 0.4)
        love.graphics.rectangle("line", px, 82, 24, 12, 2, 2)
    end

    -- Banked defense pool for the current enemy attack
    if player.unusedStamina > 0 then
        love.graphics.setColor(0.35, 0.55, 0.9)
        love.graphics.print("DEFENSE " .. player.unusedStamina,
            40 + player.maxStamina * 30 + 14, 82)
    end

    -- Enemy panel (top-right)
    if current_enemy then
        local pw = 360
        local px = L.W - pw - 40
        love.graphics.setColor(0.9, 0.88, 0.82)
        love.graphics.printf(current_enemy.name, px, 26, pw, "right")
        draw_bar(px, 48, pw, 22,
            current_enemy.hp / current_enemy.maxHp,
            {0.25, 0.05, 0.05}, {0.75, 0.12, 0.12})
        love.graphics.setColor(0.85, 0.83, 0.78)
        love.graphics.printf(math.max(0, current_enemy.hp) .. " / "
            .. current_enemy.maxHp, px, 50, pw - 8, "right")

        -- Enemy stamina pips, right-aligned, gold = remaining tempo
        local maxE = current_enemy.maxStamina or 5
        local eStam = current_enemy.stamina or 0
        for i = 1, maxE do
            local bx = px + pw - i * 30 + 6
            if i <= eStam then
                love.graphics.setColor(0.85, 0.6, 0.2)
            else
                love.graphics.setColor(0.18, 0.17, 0.17)
            end
            love.graphics.rectangle("fill", bx, 82, 24, 12, 2, 2)
            love.graphics.setColor(0.5, 0.45, 0.4)
            love.graphics.rectangle("line", bx, 82, 24, 12, 2, 2)
        end
    end
end

function CombatState.draw_turn_indicator(L)
    if CombatState.pending_transition then return end
    local label, col
    if _G.turnPhase == "player" then
        label, col = "YOUR TURN", {0.95, 0.85, 0.45}
    else
        label, col = "ENEMY TURN", {0.95, 0.3, 0.2}
    end
    love.graphics.setColor(col)
    love.graphics.printf(label, 0, 70, L.W, "center")
    love.graphics.setColor(1, 1, 1)
end

function CombatState.draw_entities(L)
    local sx, sy = Sprites.shake_offset()
    love.graphics.push()
    love.graphics.translate(sx, sy)

    Sprites.draw_character("player", player.vis,
        L.player_cx, L.player_bottom, L.player_w, L.player_h)

    if current_enemy then
        local w, h = L.enemy_w, L.enemy_h
        if current_enemy.isBoss then w, h = L.boss_w, L.boss_h end
        Sprites.draw_character("enemy", current_enemy.vis,
            L.enemy_cx, L.enemy_bottom, w, h, current_enemy.color)
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

local DIR_HINTS = {
    top = "FROM ABOVE  -  press W",
    bottom = "FROM BELOW  -  press S",
    left = "FROM THE LEFT  -  press A",
    right = "FROM THE RIGHT  -  press D",
    around = "ALL AROUND  -  press any direction",
}

function CombatState.draw_warning(L)
    if not current_enemy then return end
    if _G.turnPhase ~= "enemyWarning" and _G.turnPhase ~= "iFrameWindow" then
        return
    end

    local is_red = current_enemy.attackType == "red"
    local col = is_red and {1, 0.15, 0.1} or {1, 0.9, 0.2}
    local headline = is_red and "RED ATTACK" or "YELLOW ATTACK"
    local hint = DIR_HINTS[current_enemy.attackDir] or ""
    local react = is_red and "DODGE!" or "PARRY (P) or DODGE"

    -- Pulsing brightness for urgency
    local pulse = 0.65 + 0.35 * math.abs(math.sin(love.timer.getTime() * 8))

    love.graphics.setColor(col[1], col[2], col[3], pulse)
    UI.print_centered_scaled(headline, 128, 1.8,
        {col[1], col[2], col[3], pulse})
    love.graphics.setColor(col[1], col[2], col[3], pulse)
    love.graphics.printf(react, 0, 168, L.W, "center")
    love.graphics.setColor(0.95, 0.93, 0.88, pulse)
    love.graphics.printf(hint, 0, 190, L.W, "center")

    -- Directional frame around the enemy
    local w, h = L.enemy_w, L.enemy_h
    if current_enemy.isBoss then w, h = L.boss_w, L.boss_h end
    local x = L.enemy_cx - w / 2
    local y = L.enemy_bottom - h
    love.graphics.setColor(col[1], col[2], col[3], pulse)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x - 10, y - 10, w + 20, h + 20, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
end

function CombatState.draw_action_bar(L)
    local can_act = _G.turnPhase == "player" and not CombatState.pending_transition
    local bh, bw, gap = 74, 190, 18
    local total = bw * 3 + gap * 2 + 40 + 190
    local x0 = (L.W - total) / 2
    local y = L.H - 110

    buttons = {}

    for i, a in ipairs(ACTIONS) do
        local bx = x0 + (i - 1) * (bw + gap)
        buttons[#buttons + 1] = {
            id = a.id, action = a, kind = "action",
            x = bx, y = y, w = bw, h = bh,
        }
        UI.button(bx, y, bw, bh, a.name, {
            enabled = can_act and a.cost <= player.stamina,
            subtext = a.cost .. " stamina",
        })
    end

    local ex = x0 + 3 * (bw + gap) + 22
    buttons[#buttons + 1] = {
        id = "yield", kind = "yield",
        x = ex, y = y, w = 190, h = bh,
    }
    UI.button(ex, y, 190, bh, "Yield", {
        enabled = can_act,
        subtext = "pass the initiative",
    })

    love.graphics.setColor(0.55, 0.52, 0.48)
    love.graphics.printf(
        "Click an action  -  1/2/3 or SPACE to yield", 0, y + bh + 8, L.W, "center")
    love.graphics.setColor(1, 1, 1)
end

function CombatState.draw_end(text, color, L)
    UI.print_centered_scaled(text, L.H / 2 - 120, 4,
        {color[1], color[2], color[3], 0.9})
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press R to restart", 0, L.H / 2 - 20, L.W, "center")
end

-- --- Input ----------------------------------------------------------------

function CombatState.keypressed(key)
    -- During a death collapse, combat input is frozen (restart still works).
    if CombatState.pending_transition then
        if key == "r" then love.load() end
        return
    end

    if _G.turnPhase == "player" then
        if key == YIELD_KEY then
            CombatState.yield_turn()
            return
        end
        for _, a in ipairs(ACTIONS) do
            if key == a.key then
                perform_action(a)
                return
            end
        end
    elseif _G.turnPhase == "enemyWarning" or _G.turnPhase == "iFrameWindow" then
        CombatState.handle_reaction(key)
    elseif (current_enemy and current_enemy.hp <= 0) or player.hp <= 0 then
        if key == "r" then love.load() end
    end
end

function CombatState.mousepressed(x, y, mouse_button)
    if mouse_button ~= 1 then return end
    if CombatState.pending_transition then return end
    if _G.turnPhase ~= "player" then return end

    for _, b in ipairs(buttons) do
        if UI.hit(x, y, b.x, b.y, b.w, b.h) then
            if b.kind == "yield" then
                CombatState.yield_turn()
            elseif b.kind == "action" and b.action.cost <= player.stamina then
                perform_action(b.action)
            end
            return
        end
    end
end

function CombatState.start_enemy_attack()
    if not current_enemy then return end

    -- The strike costs the enemy its own stamina.
    current_enemy.stamina = math.max(0,
        current_enemy.stamina - current_enemy.attackCost)

    _G.turnPhase = "enemyWarning"
    _G.reacted = false
    _G.warningTimer = current_enemy.warningTime or 1.0

    local redWeight = current_enemy.redWeight or 0.5
    current_enemy.attackType = math.random() < redWeight and "red" or "yellow"

    local dirs = {"top", "left", "right", "bottom", "around"}
    current_enemy.attackDir = dirs[math.random(#dirs)]

    _G.message = "The enemy winds up..."
end

function CombatState.handle_reaction(key)
    if _G.reacted or player.unusedStamina <= 0 or not current_enemy then return end

    local evadeKey = {
        top = "w",
        left = "a",
        right = "d",
        bottom = "s",
        around = nil,
    }

    -- Evade
    if current_enemy.attackDir == "around"
        and (key == "w" or key == "a" or key == "s" or key == "d") then
        player.unusedStamina = player.unusedStamina - 1
        _G.reacted = true
        _G.message = "EVADED"
        add_popup(CombatState.player_cx or 380, CombatState.player_top or 340, "EVADED", {0.6, 0.85, 1})
        return
    elseif evadeKey[current_enemy.attackDir] == key then
        player.unusedStamina = player.unusedStamina - 1
        _G.reacted = true
        _G.message = "EVADED"
        add_popup(CombatState.player_cx or 380, CombatState.player_top or 340, "EVADED", {0.6, 0.85, 1})
        return
    end

    -- Parry (yellow only)
    if key == "p" and current_enemy.attackType == "yellow"
        and player.unusedStamina > 0 then
        current_enemy.hp = current_enemy.hp - current_enemy.attack
        Sprites.recoil(current_enemy.vis, -1)
        Sprites.hit_flash(current_enemy.vis)
        Sprites.shake(6)
        add_popup(CombatState.enemy_cx, CombatState.enemy_top,
            "PARRY -" .. current_enemy.attack, {1, 0.7, 0.2})
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
        Sprites.recoil(player.vis, 1)
        Sprites.hit_flash(player.vis)
        Sprites.shake(6)
        add_popup(CombatState.player_cx or 380, CombatState.player_top or 340, "-" .. dmg, {1, 0.25, 0.2})
        _G.message = "HIT! -" .. dmg .. " HP"
    end

    player.unusedStamina = 0
    _G.turnPhase = "player"

    -- If the player spent everything, the exchange resets before their turn.
    if player.stamina < 1 then
        CombatState.refill_round()
        _G.message = _G.message .. " (new exchange)"
    end

    if player.hp <= 0 then
        Sprites.kill(player.vis)
        CombatState.pending_transition = { type = "gameover", victim = player }
        _G.message = "YOU DIED"
    end
end

return CombatState
