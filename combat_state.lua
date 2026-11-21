-- combat_state.lua - Turn-based stamina-tempo combat (1..3 enemies)
--
-- The player faces up to three enemies at once. The player targets one enemy
-- with click/TAB; the enemy side holds the initiative whenever its best
-- remaining stamina meets or beats the player's, and the freshest enemy
-- strikes. Each enemy keeps its own HP and stamina.

local Sprites = require("sprites")
local UI = require("ui")
local Progress = require("progress")

local CombatState = {}

local enemies = {}          -- current encounter (1..3)
local current_enemy = nil   -- the enemy currently attacking
local target_index = 1
local ally = nil            -- summoned Lantern-Bearer
local player_row = "front"
local defender = nil        -- who the enemy attack is aimed at

local ACTIONS = {
    { id = "light", name = "Light Attack", cost = 1, dmg = 1.0, key = "1" },
    { id = "heavy", name = "Heavy Attack", cost = 2, dmg = 1.8, key = "2" },
    { id = "special", name = "Special Attack", cost = 3, dmg = 2.5, key = "3" },
}

local YIELD_KEY = "space"
local MAX_ENEMIES = 3

local popups = {}
local POPUP_LIFE = 0.9

local function add_popup(x, y, text, color)
    popups[#popups + 1] = { x = x, y = y, text = text, color = color, t = 0 }
end

local buttons = {}
CombatState.slots = {}

-- --- Enemy helpers --------------------------------------------------------

local function is_alive(en)
    return en and not en.defeated and en.hp > 0
end

local function living_enemies()
    local list = {}
    for _, en in ipairs(enemies) do
        if is_alive(en) then list[#list + 1] = en end
    end
    return list
end

local function alive_count()
    return #living_enemies()
end

function CombatState.all_dead()
    return #enemies > 0 and alive_count() == 0
end

local function enemy_index(en)
    for i, e in ipairs(enemies) do
        if e == en then return i end
    end
    return 1
end

local function slot_for(en)
    return CombatState.slots[enemy_index(en)] or { cx = 830, top = 310, bottom = 560 }
end

local function target()
    if is_alive(enemies[target_index]) then return enemies[target_index] end
    for i, en in ipairs(enemies) do
        if is_alive(en) then
            target_index = i
            return en
        end
    end
    return nil
end

local function select_first_living()
    for i, en in ipairs(enemies) do
        if is_alive(en) then target_index = i; return end
    end
end

local function cycle_target()
    local n = #enemies
    for step = 1, n do
        local i = (target_index - 1 + step) % n + 1
        if is_alive(enemies[i]) then target_index = i; return end
    end
end

local function max_enemy_stamina()
    local m = 0
    for _, en in ipairs(enemies) do
        if is_alive(en) and (en.stamina or 0) > m then m = en.stamina end
    end
    return m
end

local function enemy_can_strike()
    for _, en in ipairs(enemies) do
        if is_alive(en) and (en.stamina or 0) >= (en.attackCost or 2) then
            return true
        end
    end
    return false
end

local function pick_attacker()
    local best, best_stam
    for _, en in ipairs(enemies) do
        if is_alive(en) and (en.stamina or 0) >= (en.attackCost or 2) then
            if not best or en.stamina > best_stam then
                best, best_stam = en, en.stamina
            end
        end
    end
    return best
end

-- --- Slots / layout -------------------------------------------------------

local function update_slots()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    local groundY = H - 250
    local n = math.max(1, math.min(#enemies, MAX_ENEMIES))
    local centers
    if n == 1 then
        centers = { W * 0.69 }
    elseif n == 2 then
        centers = { W * 0.61, W * 0.80 }
    else
        centers = { W * 0.54, W * 0.70, W * 0.86 }
    end
    CombatState.slots = {}
    for i = 1, #enemies do
        local en = enemies[i]
        local w, h = 160, 220
        if en.isBoss then w, h = 300, 380 end
        local cx = centers[math.min(i, #centers)] or W * 0.69
        CombatState.slots[i] = {
            cx = cx, bottom = groundY, w = w, h = h,
            top = groundY - h,
        }
    end
end

-- --- Setup ---------------------------------------------------------------

local function prepare_enemy(en)
    en.attackType = nil
    en.attackDir = nil
    en.maxStamina = en.maxStamina or 5
    en.attackCost = en.attackCost or 2
    en.stamina = en.maxStamina
    en.defeated = en.defeated or false
    if not en.vis then en.vis = Sprites.new_vis() end
    en.vis.faceX = -1
end

function CombatState.set_enemies(list)
    enemies = {}
    for i, en in ipairs(list or {}) do
        if i > MAX_ENEMIES then break end
        enemies[i] = en
    end
end

function CombatState.set_enemy(en)
    CombatState.set_enemies({ en })
end

function CombatState.get_enemies()
    return enemies
end

function CombatState.get_target()
    return target()
end

function CombatState.get_ally()
    return ally
end

function CombatState.get_player_row()
    return player_row
end

function CombatState.get_defender()
    return defender
end

function CombatState.enter()
    if #enemies == 0 then
        error("No enemies set for combat state")
    end

    for _, en in ipairs(enemies) do prepare_enemy(en) end
    update_slots()

    local tmpl = Progress.ALLY_TEMPLATE
    if Progress.ally and Progress.ally.active then
        ally = {
            name = tmpl.name,
            hp = math.max(1, math.min(Progress.ally.hp or tmpl.maxHp,
                tmpl.maxHp)),
            maxHp = tmpl.maxHp,
            attack = tmpl.attack,
            defense = tmpl.defense,
            maxStamina = tmpl.maxStamina,
            stamina = tmpl.maxStamina,
            row = "front",
            alive = true,
            isAlly = true,
            vis = Sprites.new_vis(),
        }
        ally.vis.faceX = 1
        player_row = "back"
    else
        ally = nil
        player_row = "front"
    end
    defender = nil

    player.vis.walking = false
    player.vis.faceX = 1
    Sprites.set_player_anim(player.vis, "idle")
    Sprites.shakeT = 0
    CombatState.pending_transition = nil
    popups = {}
    current_enemy = nil
    target_index = 1
    select_first_living()

    _G.turnPhase = "player"
    _G.message = "Combat started! Choose a target and an action."
    player.stamina = player.maxStamina
    player.unusedStamina = 0
    _G.reacted = false
end

function CombatState.exit()
    enemies = {}
    current_enemy = nil
    ally = nil
    defender = nil
    popups = {}
end

-- --- Defeat / transitions -------------------------------------------------

local function on_enemy_defeated(en)
    if en.defeated then return end
    en.defeated = true
    Sprites.kill(en.vis)

    local slot = slot_for(en)
    local lumen = en.souls or 0
    Progress.enemy_defeated(en)
    if lumen > 0 then
        add_popup(slot.cx, slot.top or 340,
            "+" .. lumen .. " lumen", {1, 0.85, 0.4})
    end
    if en.isGuardian then
        add_popup(slot.cx, (slot.top or 340) - 30, "EMBER", {1, 0.7, 0.2})
    end

    if CombatState.all_dead() then
        if en.isBoss then
            Progress.boss_slain()
            CombatState.pending_transition = {
                type = "victory", victim = en,
            }
            _G.message = "The " .. en.name .. " falls!"
        else
            CombatState.pending_transition = {
                type = "world", victim = en,
            }
            _G.message = "The last foe falls!"
        end
        return
    end

    if not CombatState.all_dead() then select_first_living() end
    if not en.isGuardian then
        _G.message = en.name .. " falls! +" .. lumen .. " lumen"
    end
end

local function finalize_ally()
    if Progress.ally and Progress.ally.active then
        local died = (ally == nil) or (not ally.alive)
        local departed = Progress.ally_encounter_done(died, ally and ally.hp)
        if departed then
            _G.message = _G.message .. " The Lantern-Bearer departs."
        end
    end
end

function CombatState.perform_transition()
    local t = CombatState.pending_transition
    CombatState.pending_transition = nil
    if t.type == "victory" then
        finalize_ally()
        victory()
    elseif t.type == "death_respawn" then
        player_died()
    else
        finalize_ally()
        local StateManager = require("state_manager")
        StateManager.set_state("world")
    end
end

-- --- Tempo ---------------------------------------------------------------

function CombatState.refill_round()
    player.stamina = player.maxStamina
    if ally and ally.alive then ally.stamina = ally.maxStamina end
    for _, en in ipairs(enemies) do
        if is_alive(en) then en.stamina = en.maxStamina end
    end
end

local function hand_to_enemy(attacker)
    player.unusedStamina = player.stamina
    current_enemy = attacker
    CombatState.start_enemy_attack()
end

function CombatState.yield_turn()
    if CombatState.pending_transition then return end
    if _G.turnPhase ~= "player" then return end
    local attacker = pick_attacker()
    if not attacker then
        CombatState.refill_round()
        attacker = pick_attacker()
    end
    if not attacker then return end
    _G.message = "You yield the initiative."
    hand_to_enemy(attacker)
end

local function ally_act()
    if not ally or not ally.alive then return end
    ally.stamina = ally.stamina - 1
    Sprites.set_player_anim(ally.vis, "attack1")
    Sprites.lunge(ally.vis, 1)
    local tgt = target()
    if not tgt then return end
    local slot = slot_for(tgt)
    local dmg = math.max(1, math.floor(ally.attack))
    tgt.hp = tgt.hp - dmg
    Sprites.recoil(tgt.vis, -1)
    Sprites.hit_flash(tgt.vis)
    Sprites.shake(2)
    add_popup(slot.cx, slot.top or 340, "-" .. dmg, {0.6, 0.85, 1})
    _G.message = "The Lantern-Bearer strikes " .. tgt.name
        .. " for " .. dmg .. "!"
    if tgt.hp <= 0 then on_enemy_defeated(tgt) end
end

function CombatState.shift_rows()
    if CombatState.pending_transition then return end
    if _G.turnPhase ~= "player" then return end
    if not (ally and ally.alive) then return end
    if player.stamina < 1 then return end
    player.stamina = player.stamina - 1
    if player_row == "front" then
        player_row = "back"
        ally.row = "front"
    else
        player_row = "front"
        ally.row = "back"
    end
    _G.message = "You shift to the " .. player_row .. " row."
    CombatState.advance_tempo()
end

-- Highest-stamina actor acts; ties favour player, then ally, then enemies.
function CombatState.advance_tempo()
    if CombatState.pending_transition then return end
    local guard = 0
    while guard < 16 do
        guard = guard + 1
        local p = (player.stamina >= 1) and player.stamina or -1
        local a = (ally and ally.alive and ally.stamina >= 1)
            and ally.stamina or -1
        local e = enemy_can_strike() and max_enemy_stamina() or -1

        if p < 0 and a < 0 and e < 0 then
            CombatState.refill_round()
            _G.message = "A new exchange begins."
        elseif p >= a and p >= e and p >= 0 then
            _G.turnPhase = "player"
            return
        elseif a >= e and a >= 0 then
            ally_act()
            if CombatState.pending_transition then return end
        else
            hand_to_enemy(pick_attacker())
            return
        end
    end
    _G.turnPhase = "player"
end

local function perform_action(a)
    if CombatState.pending_transition then return end
    if _G.turnPhase ~= "player" then return end
    if a.cost > player.stamina then return end
    local tgt = target()
    if not tgt then return end

    player.stamina = player.stamina - a.cost
    Sprites.lunge(player.vis, 1)
    local attack_anim = "attack1"
    if a.id == "heavy" then
        attack_anim = "attack2"
    elseif a.id == "special" then
        attack_anim = "attack3"
    end
    Sprites.set_player_anim(player.vis, attack_anim)

    local slot = slot_for(tgt)
    local dmg = math.floor(player.attack * a.dmg)
    tgt.hp = tgt.hp - dmg
    Sprites.recoil(tgt.vis, -1)
    Sprites.hit_flash(tgt.vis)
    Sprites.shake(3 + a.cost)
    add_popup(slot.cx, slot.top or 340, "-" .. dmg, {1, 0.85, 0.4})
    _G.message = a.name .. " hits " .. tgt.name .. " for " .. dmg .. "!"

    if tgt.hp <= 0 then
        on_enemy_defeated(tgt)
        if CombatState.pending_transition then return end
    end

    CombatState.advance_tempo()
end

local function update_popups(dt)
    for i = #popups, 1, -1 do
        local p = popups[i]
        p.t = p.t + dt
        if p.t >= POPUP_LIFE then table.remove(popups, i) end
    end
end

function CombatState.update(dt)
    Sprites.update_vis(player.vis, dt)
    if ally then Sprites.update_vis(ally.vis, dt) end
    Sprites.update_shake(dt)
    for _, en in ipairs(enemies) do
        Sprites.update_vis(en.vis, dt)
    end
    update_popups(dt)

    if CombatState.pending_transition then
        if Sprites.death_done(CombatState.pending_transition.victim.vis) then
            CombatState.perform_transition()
        end
        return
    end

    if _G.turnPhase == "enemyWarning" and current_enemy then
        if current_enemy.vis.recoilT == nil then
            Sprites.recoil(current_enemy.vis, -1)
        end
        _G.warningTimer = _G.warningTimer - dt
        _G.flashTimer = (_G.flashTimer + dt * 6) % 2

        if _G.warningTimer <= 0 then
            _G.turnPhase = "iFrameWindow"
            _G.iFrameTimer = _G.iFrames
            Sprites.lunge(current_enemy.vis, -1)
            if not _G.reacted then
                _G.message = current_enemy.name .. " strikes!"
            end
        end
    elseif _G.turnPhase == "iFrameWindow" and current_enemy then
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
    return {
        W = W,
        H = H,
        groundY = H - 250,
        player_cx = W * 0.30,
        player_bottom = H - 250,
        player_w = 170,
        player_h = 230,
    }
end

local function draw_popups()
    for _, p in ipairs(popups) do
        local k = p.t / POPUP_LIFE
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], 1 - k)
        love.graphics.print(p.text, p.x, p.y - 46 * k, 0, 1.6, 1.6)
    end
    love.graphics.setColor(1, 1, 1)
end

function CombatState.draw()
    love.graphics.setBackgroundColor(0.04, 0.04, 0.06)
    local L = layout()
    update_slots()

    local front_x = L.W * 0.34
    local back_x = L.W * 0.20
    local px, ax
    if player_row == "front" then px, ax = front_x, back_x
    else px, ax = back_x, front_x end
    CombatState.player_cx = px
    CombatState.player_top = L.player_bottom - L.player_h
    CombatState.ally_cx = ax
    CombatState.ally_top = L.player_bottom - 200

    CombatState.draw_stage(L)
    CombatState.draw_panels(L)
    CombatState.draw_turn_indicator(L)
    CombatState.draw_entities(L)
    draw_popups()
    CombatState.draw_warning(L)
    CombatState.draw_action_bar(L)

    love.graphics.setColor(1, 1, 1)
    love.graphics.printf(_G.message, 0, 96, L.W, "center")

    if CombatState.all_dead() then
        CombatState.draw_end("VICTORY", {1, 0.8, 0}, L)
    end
    if player.hp <= 0 then
        CombatState.draw_end("YOUR LIGHT FADES", {1, 0, 0}, L,
            "Your Lumen scatters where you fell...")
    end
end

function CombatState.draw_stage(L)
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
    love.graphics.setColor(0.9, 0.88, 0.82)
    love.graphics.print("WANDERER  [" .. player_row .. "]", 40, 26)
    draw_bar(40, 48, 360, 22, player.hp / player.maxHp,
        {0.25, 0.05, 0.05}, {0.75, 0.12, 0.12})
    love.graphics.setColor(0.85, 0.83, 0.78)
    love.graphics.print(player.hp .. " / " .. player.maxHp, 300, 50)

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
    if player.unusedStamina > 0 then
        love.graphics.setColor(0.35, 0.55, 0.9)
        love.graphics.print("DEFENSE " .. player.unusedStamina,
            40 + player.maxStamina * 30 + 14, 82)
    end

    if ally then
        local ay = 108
        if ally.alive then
            love.graphics.setColor(0.6, 0.82, 1)
        else
            love.graphics.setColor(0.5, 0.55, 0.6)
        end
        love.graphics.print(ally.name .. "  [" .. ally.row .. "]", 40, ay)
        if ally.alive then
            draw_bar(40, ay + 20, 300, 16, math.max(0, ally.hp) / ally.maxHp,
                {0.08, 0.12, 0.2}, {0.35, 0.62, 0.9})
            love.graphics.setColor(0.8, 0.85, 0.9)
            love.graphics.print(math.max(0, ally.hp) .. " / " .. ally.maxHp,
                252, ay + 21)
            for i = 1, ally.maxStamina do
                local bx = 40 + (i - 1) * 26
                if i <= ally.stamina then
                    love.graphics.setColor(0.55, 0.75, 1)
                else
                    love.graphics.setColor(0.16, 0.18, 0.22)
                end
                love.graphics.rectangle("fill", bx, ay + 42, 20, 10, 2, 2)
                love.graphics.setColor(0.4, 0.48, 0.55)
                love.graphics.rectangle("line", bx, ay + 42, 20, 10, 2, 2)
            end
            love.graphics.setColor(0.62, 0.68, 0.75)
            love.graphics.print("Battles left: "
                .. (Progress.ally.fights_left or 0),
                40 + ally.maxStamina * 26 + 14, ay + 40)
        else
            love.graphics.setColor(0.6, 0.55, 0.55)
            love.graphics.print("has fallen", 40, ay + 22)
        end
    end

    -- Target panel (top-right)
    local tgt = target()
    if tgt then
        local pw = 360
        local px = L.W - pw - 40
        love.graphics.setColor(0.9, 0.88, 0.82)
        love.graphics.printf("TARGET  " .. tgt.name, px, 26, pw, "right")
        draw_bar(px, 48, pw, 22, tgt.hp / tgt.maxHp,
            {0.25, 0.05, 0.05}, {0.75, 0.12, 0.12})
        love.graphics.setColor(0.85, 0.83, 0.78)
        love.graphics.printf(math.max(0, tgt.hp) .. " / " .. tgt.maxHp,
            px, 50, pw - 8, "right")

        local maxE = tgt.maxStamina or 5
        for i = 1, maxE do
            local bx = px + pw - i * 30 + 6
            if i <= (tgt.stamina or 0) then
                love.graphics.setColor(0.85, 0.6, 0.2)
            else
                love.graphics.setColor(0.18, 0.17, 0.17)
            end
            love.graphics.rectangle("fill", bx, 82, 24, 12, 2, 2)
            love.graphics.setColor(0.5, 0.45, 0.4)
            love.graphics.rectangle("line", bx, 82, 24, 12, 2, 2)
        end
        love.graphics.setColor(0.65, 0.62, 0.55)
        love.graphics.printf("Foes: " .. alive_count() .. "/" .. #enemies,
            px, 102, pw, "right")
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
        CombatState.player_cx, L.player_bottom, L.player_w, L.player_h)

    if ally and (ally.alive or not Sprites.death_done(ally.vis)) then
        Sprites.draw_character("player", ally.vis,
            CombatState.ally_cx, L.player_bottom, 150, 200, {0.55, 0.8, 1})
        love.graphics.setColor(0.55, 0.8, 1)
        love.graphics.printf(ally.name .. "  [" .. ally.row .. "]",
            CombatState.ally_cx - 90, L.player_bottom + 8, 180, "center")
    end
    love.graphics.setColor(0.85, 0.8, 0.7)
    love.graphics.printf("WANDERER  [" .. player_row .. "]",
        CombatState.player_cx - 90, L.player_bottom + 8, 180, "center")

    local tgt = target()
    for i, en in ipairs(enemies) do
        local slot = CombatState.slots[i]
        if slot and not (en.defeated and Sprites.death_done(en.vis)) then
            Sprites.draw_character("enemy", en.vis, slot.cx, slot.bottom,
                slot.w, slot.h, en.color)

            if not en.defeated then
                -- Name
                love.graphics.setColor(0.9, 0.88, 0.82)
                love.graphics.printf(en.name, slot.cx - 90,
                    slot.top - 44, 180, "center")
                -- Mini HP bar
                local bw = math.min(slot.w, 130)
                local bx = slot.cx - bw / 2
                draw_bar(bx, slot.top - 26, bw, 8,
                    en.hp / en.maxHp, {0.25, 0.05, 0.05},
                    {0.8, 0.14, 0.14})
            end

            -- Target highlight
            if en == tgt and _G.turnPhase == "player"
                and not CombatState.pending_transition then
                love.graphics.setColor(1, 0.85, 0.35, 0.9)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", slot.cx - slot.w / 2 - 8,
                    slot.top - 8, slot.w + 16, slot.h + 16, 6, 6)
                love.graphics.setLineWidth(1)
            end
        end
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
    local targeting_ally = defender == ally and ally and ally.alive
    local hint = targeting_ally and "No input needed"
        or (DIR_HINTS[current_enemy.attackDir] or "")
    local react = targeting_ally and "ALLY TARGETED - the Lantern-Bearer defends"
        or (is_red and "DODGE!" or "PARRY (P) or DODGE")

    local pulse = 0.65 + 0.35 * math.abs(math.sin(love.timer.getTime() * 8))

    UI.print_centered_scaled(headline, 128, 1.8,
        {col[1], col[2], col[3], pulse})
    love.graphics.setColor(col[1], col[2], col[3], pulse)
    love.graphics.printf(current_enemy.name .. " - " .. react, 0, 168, L.W,
        "center")
    love.graphics.setColor(0.95, 0.93, 0.88, pulse)
    love.graphics.printf(hint, 0, 190, L.W, "center")

    local slot = slot_for(current_enemy)
    love.graphics.setColor(col[1], col[2], col[3], pulse)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", slot.cx - slot.w / 2 - 10,
        slot.top - 10, slot.w + 20, slot.h + 20, 6, 6)
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1)
end

function CombatState.draw_action_bar(L)
    local can_act = _G.turnPhase == "player"
        and not CombatState.pending_transition
    local bh, bw, gap = 74, 160, 14
    local shift_w, yield_w = 150, 150
    local total = bw * 3 + gap * 2 + 20 + shift_w + 14 + yield_w
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

    local sx = x0 + 3 * (bw + gap) + 20
    buttons[#buttons + 1] = {
        id = "shift", kind = "shift",
        x = sx, y = y, w = shift_w, h = bh,
    }
    UI.button(sx, y, shift_w, bh, "Shift", {
        enabled = can_act and ally ~= nil and ally.alive
            and player.stamina >= 1,
        subtext = "swap rows (1)",
    })

    local yx = sx + shift_w + 14
    buttons[#buttons + 1] = {
        id = "yield", kind = "yield",
        x = yx, y = y, w = yield_w, h = bh,
    }
    UI.button(yx, y, yield_w, bh, "Yield", {
        enabled = can_act,
        subtext = "pass the initiative",
    })

    love.graphics.setColor(0.55, 0.52, 0.48)
    love.graphics.printf(
        "1/2/3 attack  -  4 shift rows  -  TAB target  -  SPACE yield",
        0, y + bh + 8, L.W, "center")
    love.graphics.setColor(1, 1, 1)
end

function CombatState.draw_end(text, color, L, hint)
    UI.print_centered_scaled(text, L.H / 2 - 120, 4,
        {color[1], color[2], color[3], 0.9})
    if hint then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(hint, 0, L.H / 2 - 20, L.W, "center")
    end
end

-- --- Input ----------------------------------------------------------------

function CombatState.keypressed(key)
    if CombatState.pending_transition then
        if key == "r" then love.load() end
        return
    end

    if _G.turnPhase == "player" then
        if key == "tab" then
            cycle_target()
            return
        elseif key == "4" then
            CombatState.shift_rows()
            return
        elseif key == YIELD_KEY then
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
    elseif player.hp <= 0 and key == "r" then
        love.load()
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
            elseif b.kind == "shift" then
                CombatState.shift_rows()
            elseif b.kind == "action" and b.action.cost <= player.stamina then
                perform_action(b.action)
            end
            return
        end
    end

    -- Click an enemy to target it
    for i, en in ipairs(enemies) do
        local slot = CombatState.slots[i]
        if is_alive(en) and slot then
            if UI.hit(x, y, slot.cx - slot.w / 2, slot.top,
                slot.w, slot.h) then
                target_index = i
                return
            end
        end
    end
end

function CombatState.start_enemy_attack()
    if not current_enemy then return end

    current_enemy.stamina = math.max(0,
        current_enemy.stamina - current_enemy.attackCost)

    _G.turnPhase = "enemyWarning"
    _G.reacted = false
    _G.warningTimer = current_enemy.warningTime or 1.0

    local redWeight = current_enemy.redWeight or 0.5
    current_enemy.attackType = math.random() < redWeight and "red" or "yellow"

    local dirs = {"top", "left", "right", "bottom", "around"}
    current_enemy.attackDir = dirs[math.random(#dirs)]

    if ally and ally.alive and ally.row == "front" then
        defender = ally
    else
        defender = "player"
    end
    _G.message = "The " .. current_enemy.name .. " winds up on "
        .. (defender == "player" and "you" or "the Lantern-Bearer") .. "..."
end

function CombatState.handle_reaction(key)
    if defender ~= "player" then return end
    if _G.reacted or player.unusedStamina <= 0 or not current_enemy then return end

    local evadeKey = {
        top = "w", left = "a", right = "d", bottom = "s", around = nil,
    }

    if current_enemy.attackDir == "around"
        and (key == "w" or key == "a" or key == "s" or key == "d") then
        player.unusedStamina = player.unusedStamina - 1
        _G.reacted = true
        _G.message = "EVADED"
        Sprites.set_player_anim(player.vis, "block")
        add_popup(CombatState.player_cx, CombatState.player_top, "EVADED",
            {0.6, 0.85, 1})
        return
    elseif evadeKey[current_enemy.attackDir] == key then
        player.unusedStamina = player.unusedStamina - 1
        _G.reacted = true
        _G.message = "EVADED"
        Sprites.set_player_anim(player.vis, "block")
        add_popup(CombatState.player_cx, CombatState.player_top, "EVADED",
            {0.6, 0.85, 1})
        return
    end

    if key == "p" and current_enemy.attackType == "yellow"
        and player.unusedStamina > 0 then
        local slot = slot_for(current_enemy)
        current_enemy.hp = current_enemy.hp - current_enemy.attack
        Sprites.recoil(current_enemy.vis, -1)
        Sprites.hit_flash(current_enemy.vis)
        Sprites.shake(6)
        Sprites.set_player_anim(player.vis, "block")
        Progress.parry()
        add_popup(slot.cx, slot.top or 340,
            "PARRY -" .. current_enemy.attack, {1, 0.7, 0.2})
        _G.reacted = true
        _G.message = "PARRY!"
        if current_enemy.hp <= 0 then
            on_enemy_defeated(current_enemy)
        end
    end
end

function CombatState.resolve_enemy_attack()
    if not current_enemy then return end

    if defender == ally and ally and ally.alive then
        local dmg = math.max(0, current_enemy.attack - ally.defense)
        ally.hp = ally.hp - dmg
        Sprites.set_player_anim(ally.vis, "hurt")
        Sprites.set_player_anim(player.vis, "idle")
        Sprites.shake(6)
        add_popup(CombatState.ally_cx or 240, CombatState.ally_top or 340,
            "-" .. dmg, {1, 0.45, 0.35})
        _G.message = "The Lantern-Bearer is hit! -" .. dmg
        if ally.hp <= 0 then
            ally.alive = false
            Sprites.kill(ally.vis)
            Sprites.set_player_anim(ally.vis, "death")
            player_row = "front"
            _G.message = "The Lantern-Bearer falls!"
        end
    elseif not _G.reacted then
        local dmg = math.max(0, current_enemy.attack - player.defense)
        player.hp = player.hp - dmg
        Sprites.recoil(player.vis, 1)
        Sprites.hit_flash(player.vis)
        Sprites.set_player_anim(player.vis, "hurt")
        Sprites.shake(6)
        add_popup(CombatState.player_cx, CombatState.player_top,
            "-" .. dmg, {1, 0.25, 0.2})
        _G.message = "HIT! -" .. dmg .. " HP"
    end

    player.unusedStamina = 0
    _G.turnPhase = "player"
    current_enemy = nil
    defender = nil

    if player.stamina < 1 then
        CombatState.refill_round()
        _G.message = _G.message .. " (new exchange)"
    end

    if player.hp <= 0 then
        Sprites.kill(player.vis)
        Sprites.set_player_anim(player.vis, "death")
        CombatState.pending_transition = {
            type = "death_respawn", victim = player,
        }
        _G.message = "YOUR LIGHT FADES"
    end
end

return CombatState
