-- sprites.lua - Character sprites and Darkest Dungeon-style fx engine
--
-- The player is the FREE_Knight asset: 112x96 frames across per-animation
-- sheets (idle/walk/run/attacks/hurt/block/death). The knight itself is
-- ~36px tall with feet at frame y=84, so drawing scales by character height
-- and anchors at the feet. Enemies remain the static demon sheet animated
-- purely with transforms (bob, recoil, flash, collapse).

local Sprites = {}

local ENEMY_FRAME_W, ENEMY_FRAME_H = 64, 96

-- FREE_Knight geometry
local KNIGHT_DIR = "Player/FREE_Knight 2D Pixel Art v1.2/Sprites/"
local KNIGHT_FRAME_W, KNIGHT_FRAME_H = 112, 96
local KNIGHT_CHAR_H = 36     -- nominal visible character height
local KNIGHT_ANCHOR_X = 56   -- frame center
local KNIGHT_ANCHOR_Y = 84   -- feet line

local PLAYER_ANIM_DEFS = {
    idle = { file = "IDLE.png", frames = 14, fps = 8, loop = true },
    walk = { file = "WALK.png", frames = 8, fps = 10, loop = true },
    run = { file = "RUN.png", frames = 8, fps = 12, loop = true },
    attack1 = { file = "ATTACK 1.png", frames = 8, fps = 16, loop = false,
        return_to = "idle" },
    attack2 = { file = "ATTACK 2.png", frames = 9, fps = 16, loop = false,
        return_to = "idle" },
    attack3 = { file = "ATTACK 3.png", frames = 11, fps = 14, loop = false,
        return_to = "idle" },
    hurt = { file = "HURT.png", frames = 8, fps = 12, loop = false,
        return_to = "idle" },
    block = { file = "BLOCK.png", frames = 6, fps = 12, loop = false,
        return_to = "idle" },
    death = { file = "DEATH.png", frames = 15, fps = 20, loop = false,
        hold = true },
}

local DURATION_LUNGE = 0.3
local DURATION_RECOIL = 0.2
local DURATION_FLASH = 0.2
local DURATION_DEATH = 0.75  -- long enough for the 15-frame death animation

-- Enemy idle breathing (the player animates via frames instead).
local IDLE_SPEED, IDLE_AMPLITUDE, IDLE_SQUASH = 2.2, 2, 0.04

Sprites.shakeT = 0
Sprites.shakeAmount = 0

function Sprites.load()
    -- Load the player animation sheets and prebuild their frame quads.
    Sprites.playerAnims = {}
    for name, def in pairs(PLAYER_ANIM_DEFS) do
        local image = love.graphics.newImage(KNIGHT_DIR .. def.file)
        image:setFilter("nearest", "nearest")
        local quads = {}
        for i = 0, def.frames - 1 do
            quads[i + 1] = love.graphics.newQuad(
                i * KNIGHT_FRAME_W, 0, KNIGHT_FRAME_W, KNIGHT_FRAME_H,
                image:getWidth(), image:getHeight())
        end
        Sprites.playerAnims[name] = {
            image = image,
            quads = quads,
            frames = def.frames,
            fps = def.fps,
            loop = def.loop,
            return_to = def.return_to,
            hold = def.hold,
        }
    end

    Sprites.enemySheet = love.graphics.newImage(
        "Enemies/Caustic Demons/Sprites/Caustic Demons 2x.png")
    Sprites.enemySheet:setFilter("nearest", "nearest")
    Sprites.enemyQuad = love.graphics.newQuad(0, 0,
        ENEMY_FRAME_W, ENEMY_FRAME_H,
        Sprites.enemySheet:getWidth(), Sprites.enemySheet:getHeight())
end

function Sprites.new_vis()
    return {
        phase = math.random() * 10,  -- desync enemy bobbing
        t = 0,
        walking = false,
        faceX = 1,
        lungeT = nil,
        lungeDir = 1,
        recoilT = nil,
        flash = 0,
        deathT = nil,
        -- Player frame animation
        anim = "idle",
        animFrame = 1,
        animTime = 0,
        animDone = false,
    }
end

-- Switch the player's animation. Looping animations only restart when a
-- different animation is requested; one-shots always restart and auto-return.
function Sprites.set_player_anim(vis, name)
    local def = Sprites.playerAnims and Sprites.playerAnims[name]
    if not def then return end
    if vis.anim == name and def.loop then return end
    vis.anim = name
    vis.animFrame = 1
    vis.animTime = 0
    vis.animDone = false
end

function Sprites.lunge(vis, dir)
    vis.lungeT = 0
    vis.lungeDir = dir >= 0 and 1 or -1
end

function Sprites.recoil(vis, dir)
    vis.recoilT = 0
    vis.lungeDir = dir >= 0 and 1 or -1
end

function Sprites.hit_flash(vis)
    vis.flash = DURATION_FLASH
end

function Sprites.kill(vis)
    vis.deathT = 0
    vis.lungeT = nil
    vis.recoilT = nil
    vis.flash = 0
end

function Sprites.is_dying(vis)
    return vis.deathT ~= nil
end

function Sprites.death_done(vis)
    return vis.deathT ~= nil and vis.deathT >= DURATION_DEATH
end

function Sprites.shake(amount)
    Sprites.shakeT = 0.25
    Sprites.shakeAmount = amount
end

local function advance_player_anim(vis, dt)
    if not vis.anim or not Sprites.playerAnims then return end
    local def = Sprites.playerAnims[vis.anim]
    if not def then return end

    vis.animTime = vis.animTime + dt
    local step = 1 / def.fps
    while vis.animTime >= step do
        vis.animTime = vis.animTime - step
        if vis.animFrame < def.frames then
            vis.animFrame = vis.animFrame + 1
        elseif def.loop then
            vis.animFrame = 1
        else
            vis.animDone = true
            if def.return_to and not def.hold then
                vis.anim = def.return_to
                vis.animFrame = 1
                vis.animTime = 0
                vis.animDone = false
            end
            break
        end
    end
end

-- Advance one entity's fx timers.
function Sprites.update_vis(vis, dt)
    vis.t = vis.t + dt
    advance_player_anim(vis, dt)
    if vis.lungeT ~= nil then
        vis.lungeT = vis.lungeT + dt
        if vis.lungeT >= DURATION_LUNGE then vis.lungeT = nil end
    end
    if vis.recoilT ~= nil then
        vis.recoilT = vis.recoilT + dt
        if vis.recoilT >= DURATION_RECOIL then vis.recoilT = nil end
    end
    if vis.flash > 0 then
        vis.flash = vis.flash - dt
        if vis.flash < 0 then vis.flash = 0 end
    end
    if vis.deathT ~= nil then
        vis.deathT = vis.deathT + dt
    end
end

-- Decay the screen shake timer.
function Sprites.update_shake(dt)
    if Sprites.shakeT > 0 then
        Sprites.shakeT = Sprites.shakeT - dt
        if Sprites.shakeT < 0 then Sprites.shakeT = 0 end
    end
end

-- Current shake offset pair (0, 0 when idle).
function Sprites.shake_offset()
    if Sprites.shakeT <= 0 then return 0, 0 end
    local falloff = Sprites.shakeT / 0.25
    local amount = Sprites.shakeAmount * falloff
    return (math.random() * 2 - 1) * amount, (math.random() * 2 - 1) * amount
end

-- Attack lunge: dash out fast, ease back (30% out / 70% back).
local function lunge_offset(vis)
    if vis.lungeT == nil then return 0 end
    local p = vis.lungeT / DURATION_LUNGE
    if p < 0.3 then
        local q = p / 0.3
        return vis.lungeDir * (1 - (1 - q) ^ 2)
    end
    local q = (p - 0.3) / 0.7
    return vis.lungeDir * (1 - q * q)
end

-- Hit recoil: snap back, decay.
local function recoil_offset(vis)
    if vis.recoilT == nil then return 0 end
    local p = vis.recoilT / DURATION_RECOIL
    return -vis.lungeDir * (1 - p)
end

-- Draw the animated knight. No sine bob: the frames carry the motion.
local function draw_player(vis, cx, bottom, w, look_h, tint)
    local def = Sprites.playerAnims and Sprites.playerAnims[vis.anim or "idle"]
    if not def then return end
    local frame = math.max(1, math.min(def.frames, vis.animFrame or 1))
    local quad = def.quads[frame]

    local scale = look_h / KNIGHT_CHAR_H
    local alpha = 1
    local ox = 0
    if vis.deathT == nil then
        ox = lunge_offset(vis) * 40 + recoil_offset(vis) * 30
    else
        local p = math.min(vis.deathT / DURATION_DEATH, 1)
        if p > 0.7 then alpha = 1 - (p - 0.7) / 0.3 end
    end

    local faceX = vis.faceX or 1

    love.graphics.push()
    love.graphics.translate(cx + ox, bottom)
    love.graphics.scale(scale * faceX, scale)

    love.graphics.setColor(1, 1, 1, alpha)
    if tint then
        local mx = math.max(tint[1], tint[2], tint[3], 0.001)
        local k = 1.5 / mx
        love.graphics.setColor(tint[1] * k, tint[2] * k, tint[3] * k, alpha)
    end
    love.graphics.draw(def.image, quad, 0, 0, 0, 1, 1,
        KNIGHT_ANCHOR_X, KNIGHT_ANCHOR_Y)

    if vis.flash > 0 and alpha > 0 then
        local f = vis.flash / DURATION_FLASH
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 0.6, 0.3, f)
        love.graphics.draw(def.image, quad, 0, 0, 0, 1, 1,
            KNIGHT_ANCHOR_X, KNIGHT_ANCHOR_Y)
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

local function draw_enemy(vis, cx, bottom, w, h, tint)
    local scale = h / ENEMY_FRAME_H
    local ox, oy, sx, sy, rot, alpha = 0, 0, 1, 1, 0, 1

    if vis.deathT ~= nil then
        -- Death collapse: fade out, sink, squash, tip over.
        local p = math.min(vis.deathT / DURATION_DEATH, 1)
        alpha = 1 - p
        oy = p * h * 0.35
        sy = 1 - 0.8 * p
        sx = 1 + 0.25 * p
        rot = vis.faceX * 0.5 * p
    else
        local wave = math.sin(vis.t * IDLE_SPEED + vis.phase)
        oy = -math.abs(wave) * IDLE_AMPLITUDE
        sy = 1 + wave * IDLE_SQUASH
        ox = lunge_offset(vis) * 40 + recoil_offset(vis) * 30
    end

    local faceX = vis.faceX or 1

    love.graphics.push()
    love.graphics.translate(cx + ox, bottom + oy)
    love.graphics.rotate(rot)
    love.graphics.scale(scale * sx * faceX, scale * sy)

    love.graphics.setColor(1, 1, 1, alpha)
    if tint then
        local mx = math.max(tint[1], tint[2], tint[3], 0.001)
        local k = 1.5 / mx
        love.graphics.setColor(tint[1] * k, tint[2] * k, tint[3] * k, alpha)
    end
    love.graphics.draw(Sprites.enemySheet, Sprites.enemyQuad, 0, 0, 0, 1, 1,
        ENEMY_FRAME_W / 2, ENEMY_FRAME_H)

    if vis.flash > 0 and alpha > 0 then
        local f = vis.flash / DURATION_FLASH
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 0.6, 0.3, f)
        love.graphics.draw(Sprites.enemySheet, Sprites.enemyQuad, 0, 0, 0, 1, 1,
            ENEMY_FRAME_W / 2, ENEMY_FRAME_H)
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

function Sprites.draw_character(kind, vis, cx, bottom, w, h, tint)
    if kind == "player" then
        draw_player(vis, cx, bottom, w, h, tint)
    else
        draw_enemy(vis, cx, bottom, w, h, tint)
    end
end

return Sprites
