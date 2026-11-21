-- collision.lua - Tile-based AABB movement with axis sliding
--
-- Areas own a floor grid (area.floor[ty][tx]) plus door rectangles. Movement
-- is resolved one axis at a time so the player slides along walls.

local Collision = {}

local SAMPLE_STEP = 12

local function overlap(ax, ay, aw, ah, bx, by, bw, bh)
    return ax < bx + bw and bx < ax + aw
        and ay < by + bh and by < ay + ah
end

Collision.overlap = overlap

-- True when the box (x, y, w, h) sits entirely on floor tiles and does not
-- intersect any closed door.
function Collision.can_place(area, x, y, w, h)
    local tile = area.tile or 32

    local function point_ok(px, py)
        local tx = math.floor(px / tile) + 1
        local ty = math.floor(py / tile) + 1
        if tx < 1 or ty < 1 or tx > area.cols or ty > area.rows then
            return false
        end
        return area.floor[ty][tx] == true
    end

    -- Sample the box edges and interior on a small grid.
    local xs = {}
    local i = 0
    while i <= w do xs[#xs + 1] = x + i; i = i + SAMPLE_STEP end
    xs[#xs + 1] = x + w

    local ys = {}
    i = 0
    while i <= h do ys[#ys + 1] = y + i; i = i + SAMPLE_STEP end
    ys[#ys + 1] = y + h

    for _, px in ipairs(xs) do
        for _, py in ipairs(ys) do
            if not point_ok(px, py) then return false end
        end
    end

    for _, d in ipairs(area.doors or {}) do
        if not d.open and overlap(x, y, w, h, d.x, d.y, d.w, d.h) then
            return false
        end
    end

    return true
end

-- Move the box by (dx, dy), sliding along blocked axes.
function Collision.move(area, x, y, w, h, dx, dy)
    local nx = x + dx
    if Collision.can_place(area, nx, y, w, h) then
        x = nx
    end
    local ny = y + dy
    if Collision.can_place(area, x, ny, w, h) then
        y = ny
    end
    return x, y
end

-- Distance from a point to a rectangle (0 when inside).
function Collision.point_rect_distance(px, py, rx, ry, rw, rh)
    local cx = math.max(rx, math.min(px, rx + rw))
    local cy = math.max(ry, math.min(py, ry + rh))
    local dx, dy = px - cx, py - cy
    return math.sqrt(dx * dx + dy * dy)
end

return Collision
