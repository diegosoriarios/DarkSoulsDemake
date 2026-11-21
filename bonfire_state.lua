-- bonfire_state.lua - The Vigil: rest, upgrades, and fast travel
--
-- Opened from the world with E near a Vigil. Resting heals, respawns regular
-- foes, lights the Vigil (respawn point) and lets you travel to other lit
-- Vigils. Lumen buys upgrades.

local UI = require("ui")
local Progress = require("progress")
local Areas = require("areas")

local BonfireState = {}

local buttons = {}

local function current_vigil()
    local v = _G.current_vigil
    if v and v.area then return v end
    local hub = Areas.list.main
    local hv = hub.vigils[1]
    return {
        id = hv.id, x = hv.x, y = hv.y, area = "main",
        name = hv.name or hub.name,
    }
end

function BonfireState.enter()
    _G.message = "The Vigil burns. Rest or spend lumen."
end

function BonfireState.exit()
end

function BonfireState.update(dt)
end

local function leave()
    local StateManager = require("state_manager")
    StateManager.set_state("world")
end

local function rest()
    player.hp = player.maxHp
    if type(respawn_regular_enemies) == "function" then
        respawn_regular_enemies()
    end
    Progress.heal_ally()
    local v = current_vigil()
    Progress.rest(v, v.area, v.name)
    _G.message = "You keep the Vigil. HP restored; old foes stir again."
end

local function lit_vigils_except_current()
    local v = current_vigil()
    local list = {}
    for _, info in pairs(Progress.lit_vigils) do
        if info.id ~= v.id then
            list[#list + 1] = info
        end
    end
    table.sort(list, function(a, b)
        return (a.name or "") < (b.name or "")
    end)
    return list
end

local function travel(entry)
    if not entry or not entry.area then return end
    set_area(entry.area, entry.x, entry.y)
    _G.message = "You travel to the Vigil of " .. (entry.name or entry.area) .. "."
    save_game()
    local StateManager = require("state_manager")
    StateManager.set_state("world")
end

function BonfireState.draw()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setBackgroundColor(0.03, 0.03, 0.04)

    buttons = {}

    local pw, ph = 780, 660
    local px, py = (W - pw) / 2, (H - ph) / 2
    love.graphics.setColor(0.09, 0.08, 0.07)
    love.graphics.rectangle("fill", px, py, pw, ph, 6, 6)
    love.graphics.setColor(0.55, 0.42, 0.22)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px, py, pw, ph, 6, 6)
    love.graphics.setLineWidth(1)

    UI.print_centered_scaled("VIGIL", py + 20, 2.2, {1, 0.78, 0.35})

    local cv = current_vigil()
    love.graphics.setColor(0.7, 0.66, 0.58)
    love.graphics.printf(cv.name or cv.area, px, py + 66, pw, "center")

    love.graphics.setColor(0.88, 0.86, 0.8)
    love.graphics.printf(string.format(
        "HP %d/%d     ATK %d     DEF %d     STAMINA %d",
        player.hp, player.maxHp, player.attack, player.defense,
        player.maxStamina), px, py + 92, pw, "center")

    love.graphics.setColor(1, 0.85, 0.4)
    love.graphics.printf("LUMEN: " .. Progress.souls, px, py + 118, pw, "center")

    -- Upgrade buttons (2 columns)
    local bw, bh, gap = 340, 78, 20
    local x0 = px + (pw - (bw * 2 + gap)) / 2
    local y0 = py + 160
    for i, def in ipairs(Progress.UPGRADES) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local bx = x0 + col * (bw + gap)
        local by = y0 + row * (bh + gap)
        local rank = Progress.upgrade_rank(def)
        local maxed = rank >= def.max
        local cost = Progress.upgrade_cost(def)
        local affordable = Progress.can_buy(def)

        local sub
        if maxed then
            sub = "MAX"
        else
            sub = def.desc .. "  -  " .. cost .. " lumen  (rank "
                .. rank .. "/" .. def.max .. ")"
        end

        buttons[#buttons + 1] = {
            id = def.id, kind = "upgrade",
            x = bx, y = by, w = bw, h = bh,
        }
        UI.button(bx, by, bw, bh, def.name, {
            enabled = affordable,
            subtext = sub,
        })
    end

    -- Fast travel to other lit Vigils
    local ty = py + 440
    local travel = lit_vigils_except_current()
    love.graphics.setColor(0.8, 0.72, 0.55)
    love.graphics.printf("TRAVEL", px, ty - 26, pw, "center")

    if #travel == 0 then
        love.graphics.setColor(0.5, 0.47, 0.42)
        love.graphics.printf("No other Vigils lit yet.", px, ty + 16, pw,
            "center")
    else
        local tw, th, tgap = 220, 54, 16
        local total = #travel * tw + (#travel - 1) * tgap
        local tx0 = px + (pw - total) / 2
        for i, info in ipairs(travel) do
            local bx = tx0 + (i - 1) * (tw + tgap)
            buttons[#buttons + 1] = {
                id = info.id, kind = "travel", entry = info,
                x = bx, y = ty, w = tw, h = th,
            }
            UI.button(bx, ty, tw, th, info.name or info.area, {
                subtext = "travel",
            })
        end
    end

    -- Rest / Leave
    local rw, rh = 240, 60
    local ry = py + ph - 96
    local rest_x = px + pw / 2 - rw - 20
    local leave_x = px + pw / 2 + 20

    buttons[#buttons + 1] = {
        id = "rest", kind = "rest", x = rest_x, y = ry, w = rw, h = rh,
    }
    UI.button(rest_x, ry, rw, rh, "Rest", {
        subtext = "heal, respawn foes, set Vigil",
    })

    buttons[#buttons + 1] = {
        id = "leave", kind = "leave", x = leave_x, y = ry, w = rw, h = rh,
    }
    UI.button(leave_x, ry, rw, rh, "Leave", {
        subtext = "return to the Reach",
    })

    love.graphics.setColor(0.62, 0.58, 0.52)
    love.graphics.printf(_G.message, px, py + ph + 14, pw, "center")
    love.graphics.setColor(0.5, 0.47, 0.42)
    love.graphics.printf("ESC to leave", 0, H - 34, W, "center")
    love.graphics.setColor(1, 1, 1)
end

function BonfireState.mousepressed(x, y, mouse_button)
    if mouse_button ~= 1 then return end
    for _, b in ipairs(buttons) do
        if UI.hit(x, y, b.x, b.y, b.w, b.h) then
            if b.kind == "rest" then
                rest()
            elseif b.kind == "leave" then
                leave()
            elseif b.kind == "travel" then
                travel(b.entry)
            elseif b.kind == "upgrade" then
                local def = Progress.upgrade_def(b.id)
                if def and Progress.can_buy(def) then
                    Progress.buy_upgrade(b.id)
                end
            end
            return
        end
    end
end

function BonfireState.keypressed(key)
    if key == "escape" then
        leave()
    elseif key == "r" then
        rest()
    elseif key == "1" or key == "2" or key == "3" or key == "4" then
        local i = tonumber(key)
        local def = Progress.UPGRADES[i]
        if def and Progress.can_buy(def) then
            Progress.buy_upgrade(def.id)
        end
    end
end

return BonfireState
