-- world_state.lua - Area-based exploration with collision, doors and a map
--
-- The player moves through tile-floored rooms; walls, doors and transitions
-- are part of the area data. The Vigil (checkpoint) and the map/journal live
-- here too.

local Sprites = require("sprites")
local Areas = require("areas")
local Progress = require("progress")
local Collision = require("collision")

local WorldState = {}

local regionToast = { name = nil, t = 0 }
local currentRegion = nil
local showMap = false

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function clamp_camera()
    local vw, vh = love.graphics.getWidth(), love.graphics.getHeight()
    if world.width <= vw then
        camera.x = (world.width - vw) / 2
    else
        camera.x = clamp(camera.x, 0, world.width - vw)
    end
    if world.height <= vh then
        camera.y = (world.height - vh) / 2
    else
        camera.y = clamp(camera.y, 0, world.height - vh)
    end
end

local function vigils()
    return world.area.vigils or {}
end

local function nearest_vigil()
    for _, v in ipairs(vigils()) do
        local d = Collision.point_rect_distance(player.x + player.width / 2,
            player.y + player.height / 2, v.x - 8, v.y - 8, 16, 16)
        if d < 80 then return v, d end
    end
    return nil
end

local function nearest_transition()
    for _, tr in ipairs(world.area.transitions or {}) do
        local d = Collision.point_rect_distance(player.x + player.width / 2,
            player.y + player.height / 2, tr.x, tr.y, tr.w, tr.h)
        if d < 70 then return tr, d end
    end
    return nil
end

local function nearest_door()
    for _, d in ipairs(world.area.doors or {}) do
        if not d.open then
            local dist = Collision.point_rect_distance(
                player.x + player.width / 2, player.y + player.height / 2,
                d.x, d.y, d.w, d.h)
            if dist < 64 then return d, dist end
        end
    end
    return nil
end

local function miniboss_defeated(id)
    for _, en in ipairs(world.enemies) do
        if en.area == world.area_id and en.id == id and en.defeated then
            return true
        end
    end
    return false
end

local function door_requirement_met(door)
    local r = door.requires
    if not r then return false end
    if r.embers and Progress.lord_soul_count() < r.embers then
        return false
    end
    if r.guardian and not Progress.lord_souls[r.guardian] then
        return false
    end
    return true
end

local function refresh_doors()
    for _, d in ipairs(world.area.doors or {}) do
        d.open = Progress.is_door_open(d.id)
        if not d.open and door_requirement_met(d) then
            d.open = true
            if Progress.open_door(d.id) then
                _G.message = d.kind == "fog"
                    and "The Northlight fog parts..." 
                    or "The collapsed gate grinds open."
            end
        end
    end
end

local function door_hint(door)
    local r = door.requires or {}
    if r.embers then
        return "Sealed. Embers: " .. Progress.lord_soul_count() .. "/"
            .. r.embers
    elseif r.guardian then
        local names = {
            warden = "Brine Warden",
            sentinel = "Tidewarden",
            caustic_brute = "Sporecaller",
        }
        return "Sealed until the " .. (names[r.guardian] or "Warden")
            .. " falls."
    end
    return "Sealed."
end

local function travel_to(area_id, x, y)
    local area = Areas.get(area_id)
    if not area then return end
    set_area(area_id, x, y)
    _G.message = "You arrive in " .. area.name .. "."
    Sprites.set_player_anim(player.vis, "idle")
    save_game()
end

local function interact()
    local v = nearest_vigil()
    if v then
        _G.current_vigil = {
            id = v.id, x = v.x, y = v.y,
            area = world.area_id, name = v.name or world.area.name,
        }
        local StateManager = require("state_manager")
        StateManager.set_state("bonfire")
        return
    end

    local cache = world.area.cache
    if cache then
        local d = Collision.point_rect_distance(
            player.x + player.width / 2, player.y + player.height / 2,
            cache.x, cache.y, cache.w, cache.h)
        if d < 70 then
            if Progress.cache_opened(cache.id) then
                _G.message = "The cache is empty."
            elseif cache.requires_miniboss
                and not miniboss_defeated(cache.requires_miniboss) then
                _G.message = "A seal holds the cache. Fell its keeper first."
            else
                local summary = Progress.open_cache(cache)
                save_game()
                if summary and #summary > 0 then
                    _G.message = "Cache opened: " .. table.concat(summary, ", ")
                else
                    _G.message = "Cache opened."
                end
            end
            return
        end
    end

    local tr = nearest_transition()
    if tr then
        if tr.sealed then
            _G.message = tr.message or "It is sealed."
        else
            travel_to(tr.to_area, tr.to_x, tr.to_y)
        end
        return
    end

    local d = nearest_door()
    if d then
        _G.message = door_hint(d)
    end
end

function WorldState.enter()
    _G.message = "Explore the Reach. Wardens hold the Embers."
    Sprites.set_player_anim(player.vis, "idle")
    showMap = false
    currentRegion = nil
    regionToast = { name = nil, t = 0 }
    refresh_doors()
    clamp_camera()
end

function WorldState.exit()
    showMap = false
end

function WorldState.update(dt)
    Sprites.update_vis(player.vis, dt)
    Sprites.update_shake(dt)
    for _, en in ipairs(world.enemies) do
        if en.area == world.area_id and not en.defeated then
            Sprites.update_vis(en.vis, dt)
        end
    end
    if world.boss and not world.boss.defeated then
        Sprites.update_vis(world.boss.vis, dt)
    end

    if regionToast.t > 0 then regionToast.t = regionToast.t - dt end
    if showMap then return end

    refresh_doors()

    -- Movement with collision
    local x, y = player.x, player.y
    local dx, dy = 0, 0
    player.vis.walking = false
    if love.keyboard.isDown("w") then dy = dy - player.speed * dt end
    if love.keyboard.isDown("s") then dy = dy + player.speed * dt end
    if love.keyboard.isDown("a") then
        dx = dx - player.speed * dt
        player.vis.faceX = -1
    end
    if love.keyboard.isDown("d") then
        dx = dx + player.speed * dt
        player.vis.faceX = 1
    end
    if dx ~= 0 or dy ~= 0 then player.vis.walking = true end
    x, y = Collision.move(world.area, x, y, player.width, player.height, dx, dy)
    player.x, player.y = x, y
    Sprites.set_player_anim(player.vis, player.vis.walking and "run" or "idle")

    camera.x = player.x - 600
    camera.y = player.y - 400
    clamp_camera()

    -- Region toast
    local region = Areas.region_at(world.area, player.x + player.width / 2,
        player.y + player.height / 2)
    if region and region ~= currentRegion then
        currentRegion = region
        regionToast = { name = region, t = 2.5 }
    end

    -- Item pickups
    for _, item in ipairs(world.items) do
        if not item.collected and item.area == world.area_id then
            local dist = math.sqrt((player.x - item.x)^2 + (player.y - item.y)^2)
            if dist < 30 then
                item.collected = true
                if item.type == "health" then
                    player.hp = math.min(player.maxHp, player.hp + 30)
                    _G.message = "Vital Draught: +30 HP"
                else
                    player.stamina = math.min(player.maxStamina,
                        player.stamina + 2)
                    _G.message = "Breath Draught: +2 Stamina"
                end
            end
        end
    end

    -- Recover the Lost Lantern dropped on death
    local lantern = Progress.lost_lantern
    if lantern and lantern.area == world.area_id then
        local pcx = player.x + player.width / 2
        local pcy = player.y + player.height / 2
        local d = math.sqrt((pcx - lantern.x)^2 + (pcy - lantern.y)^2)
        if d < 40 then
            local amount = Progress.recover_lantern()
            _G.message = "You recover " .. amount .. " lumen from the Lost Lantern."
            save_game()
        end
    end

    -- Boss appears in the Reach once the gate is open
    if world.area_id == "main" and Progress.boss_unlocked
        and not Progress.boss_defeated and not world.boss then
        spawn_boss()
    end

    -- Encounters in this area
    for _, en in ipairs(world.enemies) do
        if en.area == world.area_id and not en.defeated then
            local dist = math.sqrt((player.x - en.x)^2 + (player.y - en.y)^2)
            if dist < 150 then
                en.vis.faceX = (player.x >= en.x) and 1 or -1
            end
            if dist < 50 then
                local group = { en }
                if not en.isGuardian and not en.isBoss
                    and not en.isMiniboss then
                    for _, other in ipairs(world.enemies) do
                        if #group >= 3 then break end
                        if other ~= en and other.area == world.area_id
                            and not other.defeated
                            and not other.isGuardian and not other.isBoss then
                            local d = math.sqrt((en.x - other.x)^2
                                + (en.y - other.y)^2)
                            if d < 190 then group[#group + 1] = other end
                        end
                    end
                end
                local StateManager = require("state_manager")
                local CombatState = require("combat_state")
                CombatState.set_enemies(group)
                StateManager.set_state("combat")
                return
            end
        end
    end

    local boss = world.boss
    if boss and boss.area == world.area_id and not boss.defeated then
        local dist = math.sqrt((player.x - boss.x)^2 + (player.y - boss.y)^2)
        if dist < 70 then
            local StateManager = require("state_manager")
            local CombatState = require("combat_state")
            CombatState.set_enemies({ boss })
            StateManager.set_state("combat")
        end
    end
end

-- --- Drawing --------------------------------------------------------------

local WALL_COLOR = {0.045, 0.045, 0.055}

local function draw_tiles()
    local area = world.area
    local t = area.tile
    local tx1 = math.max(1, math.floor(camera.x / t) + 1)
    local ty1 = math.max(1, math.floor(camera.y / t) + 1)
    local tx2 = math.min(area.cols,
        math.floor((camera.x + love.graphics.getWidth()) / t) + 1)
    local ty2 = math.min(area.rows,
        math.floor((camera.y + love.graphics.getHeight()) / t) + 1)

    for ty = ty1, ty2 do
        for tx = tx1, tx2 do
            local sx = (tx - 1) * t - camera.x
            local sy = (ty - 1) * t - camera.y
            if area.floor[ty][tx] then
                local tint = area.tint[ty][tx] or {0.1, 0.1, 0.1}
                love.graphics.setColor(tint[1], tint[2], tint[3])
            else
                love.graphics.setColor(WALL_COLOR[1], WALL_COLOR[2],
                    WALL_COLOR[3])
            end
            love.graphics.rectangle("fill", sx, sy, t, t)
        end
    end
    love.graphics.setColor(1, 1, 1)
end

local function draw_doors()
    for _, d in ipairs(world.area.doors or {}) do
        if not d.open then
            local sx, sy = d.x - camera.x, d.y - camera.y
            if d.kind == "fog" then
                love.graphics.setColor(1, 0.55, 0.15, 0.35)
                love.graphics.rectangle("fill", sx, sy, d.w, d.h, 4, 4)
                love.graphics.setColor(1, 0.7, 0.3, 0.9)
                love.graphics.rectangle("line", sx, sy, d.w, d.h, 4, 4)
            else
                love.graphics.setColor(0.08, 0.07, 0.06)
                love.graphics.rectangle("fill", sx, sy, d.w, d.h, 3, 3)
                love.graphics.setColor(0.65, 0.45, 0.2)
                love.graphics.rectangle("line", sx, sy, d.w, d.h, 3, 3)
            end
        end
    end
    love.graphics.setColor(1, 1, 1)
end

local function draw_transitions()
    for _, tr in ipairs(world.area.transitions or {}) do
        local sx, sy = tr.x - camera.x, tr.y - camera.y
        if tr.sealed then
            love.graphics.setColor(0.06, 0.05, 0.05)
            love.graphics.rectangle("fill", sx, sy, tr.w, tr.h, 4, 4)
            love.graphics.setColor(0.5, 0.18, 0.15)
        else
            love.graphics.setColor(0.10, 0.12, 0.16)
            love.graphics.rectangle("fill", sx, sy, tr.w, tr.h, 4, 4)
            love.graphics.setColor(0.4, 0.7, 0.9)
        end
        love.graphics.rectangle("line", sx, sy, tr.w, tr.h, 4, 4)
        local near = Collision.point_rect_distance(
            player.x + player.width / 2, player.y + player.height / 2,
            tr.x, tr.y, tr.w, tr.h) < 70
        if near then
            love.graphics.setColor(1, 1, 1)
            love.graphics.printf((tr.sealed and "SEALED - " or "") .. tr.label
                .. " (E)", sx - 100, sy - 28, tr.w + 200, "center")
        end
    end
    love.graphics.setColor(1, 1, 1)
end

local function draw_vigils()
    for _, v in ipairs(vigils()) do
        local sx, sy = v.x - camera.x, v.y - camera.y
        local lit = Progress.vigil_lit(v.id)
        if lit then
            love.graphics.setColor(1, 0.55, 0.12, 0.12)
            love.graphics.circle("fill", sx, sy, 64)
            love.graphics.setColor(1, 0.6, 0.15, 0.18)
            love.graphics.circle("fill", sx, sy, 40)
            love.graphics.setColor(0.95, 0.45, 0.08)
            love.graphics.rectangle("fill", sx - 12, sy - 26, 24, 30, 4, 4)
            love.graphics.setColor(1, 0.8, 0.3)
            love.graphics.rectangle("fill", sx - 6, sy - 18, 12, 20, 3, 3)
        else
            love.graphics.setColor(0.25, 0.22, 0.20)
            love.graphics.rectangle("fill", sx - 10, sy - 20, 20, 24, 4, 4)
            love.graphics.setColor(0.45, 0.34, 0.20)
            love.graphics.rectangle("line", sx - 10, sy - 20, 20, 24, 4, 4)
        end
        love.graphics.setColor(0.35, 0.22, 0.12)
        love.graphics.rectangle("fill", sx - 24, sy + 2, 48, 8, 2, 2)
        if nearest_vigil() then
            love.graphics.setColor(1, 0.85, 0.5)
            love.graphics.printf("VIGIL  -  press E", sx - 120, sy - 74, 240,
                "center")
        end
    end
    love.graphics.setColor(1, 1, 1)
end

local function draw_cache()
    local cache = world.area.cache
    if not cache then return end
    local sx, sy = cache.x - camera.x, cache.y - camera.y
    local opened = Progress.cache_opened(cache.id)
    local locked = cache.requires_miniboss
        and not miniboss_defeated(cache.requires_miniboss)

    love.graphics.setColor(0.08, 0.06, 0.04)
    love.graphics.rectangle("fill", sx - 4, sy - 4, cache.w + 8, cache.h + 8,
        4, 4)
    if opened then
        love.graphics.setColor(0.28, 0.24, 0.20)
    else
        love.graphics.setColor(0.55, 0.38, 0.16)
    end
    love.graphics.rectangle("fill", sx, sy + 12, cache.w, cache.h - 12, 3, 3)
    love.graphics.setColor(opened and {0.3, 0.27, 0.22} or {0.7, 0.5, 0.2})
    if opened then
        love.graphics.rectangle("fill", sx - 2, sy - 4, cache.w + 4, 10, 3, 3)
    else
        love.graphics.rectangle("fill", sx, sy, cache.w, 16, 3, 3)
        love.graphics.setColor(0.95, 0.78, 0.35)
        love.graphics.rectangle("fill", sx + cache.w / 2 - 4, sy + 6, 8, 8,
            2, 2)
    end

    if locked then
        love.graphics.setColor(0.9, 0.35, 0.3, 0.85)
        love.graphics.rectangle("line", sx - 6, sy - 6, cache.w + 12,
            cache.h + 12, 4, 4)
    end

    local d = Collision.point_rect_distance(
        player.x + player.width / 2, player.y + player.height / 2,
        cache.x, cache.y, cache.w, cache.h)
    if d < 70 and not opened then
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf(locked and "SEALED CACHE" or "CACHE  -  press E",
            sx - 100, sy - 30, cache.w + 200, "center")
    end
    love.graphics.setColor(1, 1, 1)
end

local function draw_lantern()
    local lantern = Progress.lost_lantern
    if not lantern or lantern.area ~= world.area_id then return end
    local sx, sy = lantern.x - camera.x, lantern.y - camera.y
    local pulse = 0.6 + 0.4 * math.abs(math.sin(love.timer.getTime() * 3))
    love.graphics.setColor(0.35, 0.55, 1, 0.18 * pulse)
    love.graphics.circle("fill", sx, sy, 46)
    love.graphics.setColor(0.5, 0.75, 1, 0.9)
    love.graphics.rectangle("fill", sx - 6, sy - 16, 12, 16, 3, 3)
    love.graphics.setColor(0.85, 0.95, 1)
    love.graphics.circle("fill", sx, sy - 20, 5)
    love.graphics.setColor(1, 1, 1)
end

local function draw_enemy(en)
    local sx = en.x + en.width / 2 - camera.x
    local sy = en.y + en.height - camera.y
    if en.isGuardian or en.isMiniboss then
        local pulse = 0.55 + 0.45 * math.abs(math.sin(love.timer.getTime() * 3))
        local gcx = en.x + en.width / 2 - camera.x
        local gcy = en.y + en.height / 2 - camera.y
        if en.isMiniboss then
            love.graphics.setColor(0.8, 0.45, 0.95, 0.10 * pulse)
        else
            love.graphics.setColor(1, 0.7, 0.2, 0.10 * pulse)
        end
        love.graphics.circle("fill", gcx, gcy, en.height * 0.95)
        if en.isMiniboss then
            love.graphics.setColor(0.8, 0.45, 0.95, 0.14 * pulse)
        else
            love.graphics.setColor(1, 0.7, 0.2, 0.14 * pulse)
        end
        love.graphics.circle("fill", gcx, gcy, en.height * 0.6)
    end
    Sprites.draw_character("enemy", en.vis, sx, sy, en.width, en.height,
        en.color)
    if en.isGuardian or en.isMiniboss then
        if en.isMiniboss then
            love.graphics.setColor(0.85, 0.6, 1)
        else
            love.graphics.setColor(1, 0.78, 0.35)
        end
        love.graphics.printf(en.name, sx - 90, en.y - camera.y - 36, 180,
            "center")
    end
    love.graphics.setColor(0.3, 0, 0)
    love.graphics.rectangle("fill", en.x - camera.x, en.y - camera.y - 15,
        en.width, 5)
    love.graphics.setColor(0.8, 0.1, 0.1)
    love.graphics.rectangle("fill", en.x - camera.x, en.y - camera.y - 15,
        en.width * (en.hp / en.maxHp), 5)
end

function WorldState.draw()
    love.graphics.setBackgroundColor(world.area.background[1],
        world.area.background[2], world.area.background[3])
    draw_tiles()
    draw_transitions()
    draw_doors()

    for _, item in ipairs(world.items) do
        if not item.collected and item.area == world.area_id then
            if item.type == "health" then
                love.graphics.setColor(1, 0.2, 0.2)
            else
                love.graphics.setColor(0.2, 0.8, 1)
            end
            love.graphics.circle("fill", item.x - camera.x,
                item.y - camera.y, 8)
        end
    end

    draw_vigils()
    draw_cache()
    draw_lantern()

    for _, en in ipairs(world.enemies) do
        if en.area == world.area_id and not en.defeated then draw_enemy(en) end
    end

    local boss = world.boss
    if boss and boss.area == world.area_id and not boss.defeated then
        Sprites.draw_character("enemy", boss.vis,
            boss.x + boss.width / 2 - camera.x,
            boss.y + boss.height - camera.y,
            boss.width, boss.height, boss.color)
        love.graphics.setColor(1, 0.45, 0.1)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", boss.x - camera.x - 4,
            boss.y - camera.y - 4, boss.width + 8, boss.height + 8)
        love.graphics.setLineWidth(1)
        love.graphics.setColor(0.3, 0, 0)
        love.graphics.rectangle("fill", boss.x - camera.x,
            boss.y - camera.y - 15, boss.width, 5)
        love.graphics.setColor(1, 0.2, 0.1)
        love.graphics.rectangle("fill", boss.x - camera.x,
            boss.y - camera.y - 15, boss.width * (boss.hp / boss.maxHp), 5)
    end

    Sprites.draw_character("player", player.vis,
        player.x + player.width / 2 - camera.x,
        player.y + player.height - camera.y,
        player.width, player.height)

    WorldState.draw_hud()
    WorldState.draw_region_toast()

    if showMap then WorldState.draw_map() end
end

function WorldState.draw_hud()
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("HP: " .. player.hp .. " / " .. player.maxHp, 20, 20)
    love.graphics.print("STAMINA: " .. math.floor(player.stamina), 20, 46)

    local W = love.graphics.getWidth()
    local pw = 380
    local px = W - pw - 20
    love.graphics.setColor(0.07, 0.06, 0.06, 0.92)
    love.graphics.rectangle("fill", px, 16, pw, 126, 6, 6)
    love.graphics.setColor(0.5, 0.42, 0.28)
    love.graphics.rectangle("line", px, 16, pw, 126, 6, 6)

    local obj = Progress.current_objective()
    love.graphics.setColor(0.8, 0.72, 0.55)
    love.graphics.print("OBJECTIVE", px + 14, 26)
    love.graphics.setColor(1, 0.88, 0.55)
    love.graphics.printf(obj and obj.title or "The pilgrimage is complete",
        px + 14, 46, pw - 28, "left")
    love.graphics.setColor(0.8, 0.78, 0.72)
    if obj then
        love.graphics.printf(obj.desc, px + 14, 68, pw - 28, "left")
    end
    love.graphics.setColor(1, 0.85, 0.4)
    love.graphics.printf("Lumen: " .. Progress.souls, px + 14, 100,
        pw - 28, "left")
    love.graphics.setColor(0.95, 0.72, 0.4)
    love.graphics.printf("Embers: " .. Progress.lord_soul_count() .. "/3",
        px + 14, 118, pw - 28, "left")

    love.graphics.setColor(1, 1, 1)
    love.graphics.print(world.area.name, 20, 76)
    love.graphics.setColor(0.8, 0.76, 0.68)
    love.graphics.print("Draughts: " .. (Progress.items.draught or 0)
        .. "   Sigils: " .. (Progress.items.sigil or 0), 20, 98)
    if Progress.ally and Progress.ally.active then
        love.graphics.setColor(0.55, 0.8, 1)
        love.graphics.print("Ally: Lantern-Bearer (" .. Progress.ally.fights_left
            .. " battles)", 20, 120)
    end
    if Progress.lost_lantern then
        local la = Areas.get(Progress.lost_lantern.area)
        love.graphics.setColor(0.55, 0.75, 1)
        love.graphics.print("Lost Lantern: " .. Progress.lost_lantern.amount
            .. " lumen (" .. (la and la.name or "elsewhere") .. ")", 20, 142)
    end
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(_G.message, 20, love.graphics.getHeight() - 46)

    love.graphics.setColor(0.55, 0.52, 0.46)
    love.graphics.print(
        "TAB: map   E: interact   F: summon   H: draught   R: restart run", 20,
        love.graphics.getHeight() - 24)
    love.graphics.setColor(1, 1, 1)
end

function WorldState.draw_region_toast()
    if regionToast.t <= 0 or not regionToast.name then return end
    local alpha = math.min(1, regionToast.t)
    love.graphics.setColor(1, 0.92, 0.75, alpha)
    love.graphics.printf(regionToast.name, 0, 60,
        love.graphics.getWidth(), "center")
    love.graphics.setColor(1, 1, 1)
end

local function map_scale(area, map_w, map_h)
    return math.min(map_w / area.width, map_h / area.height)
end

function WorldState.draw_map()
    local W, H = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 0.75)
    love.graphics.rectangle("fill", 0, 0, W, H)

    local pw, ph = 1020, 700
    local px, py = (W - pw) / 2, (H - ph) / 2
    love.graphics.setColor(0.07, 0.065, 0.06)
    love.graphics.rectangle("fill", px, py, pw, ph, 6, 6)
    love.graphics.setColor(0.5, 0.42, 0.28)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", px, py, pw, ph, 6, 6)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(1, 0.86, 0.5)
    love.graphics.printf("MAP & JOURNAL", px, py + 14, pw, "center")

    -- Map
    local area = world.area
    local mx, my = px + 24, py + 54
    local mw, mh = 600, 590
    local s = map_scale(area, mw, mh)
    local ox = mx + (mw - area.width * s) / 2
    local oy = my + (mh - area.height * s) / 2
    local ts = area.tile * s

    for ty = 1, area.rows do
        for tx = 1, area.cols do
            if area.floor[ty][tx] then
                local tint = area.tint[ty][tx] or {0.1, 0.1, 0.1}
                love.graphics.setColor(tint[1] + 0.05, tint[2] + 0.05,
                    tint[3] + 0.05)
                love.graphics.rectangle("fill", ox + (tx - 1) * ts,
                    oy + (ty - 1) * ts, ts + 0.5, ts + 0.5)
            end
        end
    end

    for _, d in ipairs(area.doors or {}) do
        if d.open then
            love.graphics.setColor(0.4, 0.8, 0.45)
        elseif d.kind == "fog" then
            love.graphics.setColor(1, 0.6, 0.2)
        else
            love.graphics.setColor(0.85, 0.3, 0.2)
        end
        love.graphics.rectangle("fill", ox + d.x * s, oy + d.y * s,
            math.max(3, d.w * s), math.max(3, d.h * s))
    end

    for _, tr in ipairs(area.transitions or {}) do
        love.graphics.setColor(tr.sealed and 0.6 or 0.4, 0.45,
            tr.sealed and 0.35 or 0.9)
        love.graphics.rectangle("fill", ox + tr.x * s, oy + tr.y * s,
            math.max(4, tr.w * s), math.max(4, tr.h * s))
    end

    for _, v in ipairs(area.vigils or {}) do
        if Progress.vigil_lit(v.id) then
            love.graphics.setColor(1, 0.8, 0.35)
        else
            love.graphics.setColor(0.5, 0.45, 0.35)
        end
        love.graphics.circle("fill", ox + v.x * s, oy + v.y * s,
            math.max(4, ts * 0.9))
    end

    if area.cache then
        local c = area.cache
        if Progress.cache_opened(c.id) then
            love.graphics.setColor(0.4, 0.35, 0.3)
        else
            love.graphics.setColor(1, 0.8, 0.3)
        end
        love.graphics.rectangle("fill", ox + c.x * s, oy + c.y * s,
            math.max(4, c.w * s), math.max(4, c.h * s))
    end

    local lantern = Progress.lost_lantern
    if lantern and lantern.area == area.id then
        love.graphics.setColor(0.5, 0.75, 1)
        love.graphics.circle("fill", ox + lantern.x * s, oy + lantern.y * s,
            math.max(4, ts * 0.8))
    end

    for _, en in ipairs(world.enemies) do
        if en.area == area.id and not en.defeated then
            if en.isGuardian then
                love.graphics.setColor(1, 0.35, 0.2)
            else
                love.graphics.setColor(0.7, 0.25, 0.25)
            end
            love.graphics.circle("fill", ox + en.x * s, oy + en.y * s,
                en.isGuardian and math.max(4, ts * 0.8) or math.max(2, ts * 0.5))
        end
    end

    if world.boss and world.boss.area == area.id and not world.boss.defeated then
        love.graphics.setColor(1, 0.55, 0.1)
        love.graphics.circle("fill", ox + world.boss.x * s,
            oy + world.boss.y * s, math.max(5, ts))
    end

    love.graphics.setColor(1, 1, 1)
    love.graphics.circle("fill", ox + player.x * s, oy + player.y * s,
        math.max(4, ts * 0.75))

    -- Journal column
    local jx = px + 650
    local jy = py + 58
    love.graphics.setColor(1, 0.86, 0.5)
    love.graphics.print(area.name, jx, jy)
    jy = jy + 30
    for _, obj in ipairs(Progress.objectives()) do
        local mark = obj.complete and "[x]" or "[ ]"
        if obj.complete then
            love.graphics.setColor(0.55, 0.8, 0.45)
        else
            love.graphics.setColor(0.92, 0.9, 0.84)
        end
        love.graphics.print(mark .. " " .. obj.title, jx, jy)
        jy = jy + 30
    end

    jy = jy + 10
    love.graphics.setColor(0.85, 0.72, 0.4)
    love.graphics.print("Lumen: " .. Progress.souls, jx, jy)
    jy = jy + 22
    love.graphics.print("Embers: " .. Progress.lord_soul_count() .. "/3",
        jx, jy)
    jy = jy + 22
    love.graphics.setColor(0.8, 0.76, 0.68)
    love.graphics.print("Draughts: " .. (Progress.items.draught or 0)
        .. "   Sigils: " .. (Progress.items.sigil or 0), jx, jy)
    jy = jy + 22
    if Progress.ally and Progress.ally.active then
        love.graphics.setColor(0.6, 0.82, 1)
        love.graphics.print("Ally: Lantern-Bearer ("
            .. Progress.ally.fights_left .. " battles)", jx, jy)
    else
        love.graphics.setColor(0.55, 0.55, 0.52)
        love.graphics.print("Ally: none (F to summon)", jx, jy)
    end
    jy = jy + 30
    love.graphics.setColor(0.75, 0.68, 0.55)
    love.graphics.print("Trinkets:", jx, jy)
    jy = jy + 20
    local any = false
    for id, def in pairs(Progress.TRINKETS) do
        if Progress.has_trinket(id) then
            any = true
            love.graphics.setColor(0.7, 0.7, 0.62)
            love.graphics.print("- " .. def.name .. " (" .. def.desc .. ")",
                jx, jy)
            jy = jy + 18
        end
    end
    if not any then
        love.graphics.setColor(0.5, 0.48, 0.44)
        love.graphics.print("- none yet", jx, jy)
        jy = jy + 18
    end
    jy = jy + 10
    love.graphics.setColor(0.8, 0.78, 0.7)
    love.graphics.print("Areas discovered:", jx, jy)
    jy = jy + 24
    for id, a in pairs(Areas.list) do
        if Progress.discovered_areas[id] then
            love.graphics.setColor(0.65, 0.62, 0.56)
            love.graphics.print("- " .. a.name, jx, jy)
            jy = jy + 22
        end
    end

    love.graphics.setColor(0.6, 0.57, 0.5)
    love.graphics.printf("TAB to close", px, py + ph - 34, pw, "center")
    love.graphics.setColor(1, 1, 1)
end

function WorldState.keypressed(key)
    if showMap then
        if key == "tab" or key == "escape" then showMap = false end
        return
    end

    if key == "tab" then
        showMap = true
    elseif key == "e" then
        interact()
    elseif key == "f" then
        local ok, why = Progress.summon_ally()
        if ok then
            _G.message = "You invoke a Beacon Sigil. The Lantern-Bearer joins you!"
        else
            _G.message = why or "You cannot summon now."
        end
    elseif key == "h" then
        local healed = Progress.use_draught()
        if healed > 0 then
            _G.message = "Lantern Draught: +" .. healed .. " HP"
        elseif (Progress.items.draught or 0) < 1 then
            _G.message = "You have no Lantern Draughts."
        else
            _G.message = "You are already unharmed."
        end
    elseif key == "r" then
        if type(new_game) == "function" then
            new_game()
        else
            love.load()
        end
    end
end

return WorldState
