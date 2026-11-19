-- sprites.lua - Character sprite assets and Darkest Dungeon-style fx engine
--
-- Static single-frame sprites animated purely with transforms: idle
-- breathing bob, walk bounce, attack lunges, hit recoil + additive flash,
-- death collapse, and a decaying screen shake.

local Sprites = {}

-- Sheet layout facts (2x assets):
--   Player sheet is 5x3 tiles of 36x36; tile (0,0) is a standing figure.
--   Enemy sheet is 10 frames of 64x96; frame 1 is the full standing demon.
local PLAYER_FRAME_W, PLAYER_FRAME_H = 36, 36
local ENEMY_FRAME_W, ENEMY_FRAME_H = 64, 96

local DURATION_LUNGE = 0.3
local DURATION_RECOIL = 0.2
local DURATION_FLASH = 0.2
local DURATION_DEATH = 0.5

-- Idle breathing: slow sine bob + subtle vertical squash.
local IDLE_SPEED, IDLE_AMPLITUDE, IDLE_SQUASH = 2.2, 2, 0.04
-- Walking: faster, bouncier.
local WALK_SPEED, WALK_AMPLITUDE, WALK_SQUASH = 9, 4, 0.07

Sprites.shakeT = 0
Sprites.shakeAmount = 0

function Sprites.load()
    Sprites.playerSheet = love.graphics.newImage(
        "Player/Basic Humanoid II Sprites/Basic Humanoid II 2x.png")
    -- Pixel art: nearest filtering keeps upscaled sprites sharp.
    Sprites.playerSheet:setFilter("nearest", "nearest")
    Sprites.playerQuad = love.graphics.newQuad(0, 0,
        PLAYER_FRAME_W, PLAYER_FRAME_H,
        Sprites.playerSheet:getWidth(), Sprites.playerSheet:getHeight())

    Sprites.enemySheet = love.graphics.newImage(
        "Enemies/Caustic Demons/Sprites/Caustic Demons 2x.png")
    Sprites.enemySheet:setFilter("nearest", "nearest")
    Sprites.enemyQuad = love.graphics.newQuad(0, 0,
        ENEMY_FRAME_W, ENEMY_FRAME_H,
        Sprites.enemySheet:getWidth(), Sprites.enemySheet:getHeight())
end

function Sprites.new_vis()
    return {
        phase = math.random() * 10,  -- desync idle bobbing between entities
        t = 0,
        walking = false,
        faceX = 1,
        lungeT = nil,   -- counts up while lunging
        lungeDir = 1,   -- +1 toward the right, -1 toward the left
        recoilT = nil,
        flash = 0,
        deathT = nil,   -- counts up while dying; nil means alive
    }
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

-- Advance one entity's fx timers.
function Sprites.update_vis(vis, dt)
    vis.t = vis.t + dt
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
        -- ease-out dash
        local q = p / 0.3
        return vis.lungeDir * (1 - (1 - q) ^ 2)
    end
    -- ease-in return
    local q = (p - 0.3) / 0.7
    return vis.lungeDir * (1 - q * q)
end

-- Hit recoil: snap back, decay.
local function recoil_offset(vis)
    if vis.recoilT == nil then return 0 end
    local p = vis.recoilT / DURATION_RECOIL
    return -vis.lungeDir * (1 - p)
end

function Sprites.draw_character(kind, vis, cx, bottom, w, h, tint)
    local sheet, quad, fw, fh
    if kind == "player" then
        sheet, quad, fw, fh = Sprites.playerSheet, Sprites.playerQuad,
            PLAYER_FRAME_W, PLAYER_FRAME_H
    else
        sheet, quad, fw, fh = Sprites.enemySheet, Sprites.enemyQuad,
            ENEMY_FRAME_W, ENEMY_FRAME_H
    end

    -- Fit the frame into the entity's logical box, scale driven by height.
    local scale = h / fh

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
        -- Breathing / walk bounce.
        local speed, amp, squash = IDLE_SPEED, IDLE_AMPLITUDE, IDLE_SQUASH
        if kind == "player" and vis.walking then
            speed, amp, squash = WALK_SPEED, WALK_AMPLITUDE, WALK_SQUASH
        end
        local wave = math.sin(vis.t * speed + vis.phase)
        oy = -math.abs(wave) * amp
        sy = 1 + wave * squash

        -- Horizontal combat motion.
        ox = lunge_offset(vis) * 40 + recoil_offset(vis) * 30
    end

    local faceX = vis.faceX or 1

    love.graphics.push()
    love.graphics.translate(cx + ox, bottom + oy)
    love.graphics.rotate(rot)
    love.graphics.scale(scale * sx * faceX, scale * sy)

    -- Re-anchor: draw quad centered horizontally, feet on the anchor point.
    love.graphics.setColor(1, 1, 1, alpha)
    if tint then
        -- Normalize the archetype color so multiplying never crushes the
        -- (already dark) sprite to black; keep the hue, lift brightness.
        local mx = math.max(tint[1], tint[2], tint[3], 0.001)
        local k = 1.5 / mx
        love.graphics.setColor(tint[1] * k, tint[2] * k, tint[3] * k, alpha)
    end
    love.graphics.draw(sheet, quad, 0, 0, 0, 1, 1, fw / 2, fh)

    -- Hit flash: additive overdraw makes the sprite glow.
    if vis.flash > 0 and alpha > 0 then
        local f = vis.flash / DURATION_FLASH
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 0.6, 0.3, f)
        love.graphics.draw(sheet, quad, 0, 0, 0, 1, 1, fw / 2, fh)
        love.graphics.setBlendMode("alpha")
    end

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

return Sprites
