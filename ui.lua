-- ui.lua - Minimal button helpers shared by the menu and combat screens
--
-- Buttons are drawn every frame from a rect (x, y, w, h) and hit-tested by
-- the owning state's mousepressed using UI.hit. No retained widget objects.

local UI = {}

UI.COLORS = {
    fill = {0.10, 0.09, 0.11},
    fillHover = {0.20, 0.18, 0.22},
    border = {0.55, 0.45, 0.30},
    borderHover = {0.95, 0.78, 0.40},
    text = {0.92, 0.90, 0.86},
    textDisabled = {0.42, 0.40, 0.40},
    fillDisabled = {0.07, 0.07, 0.08},
    borderDisabled = {0.25, 0.24, 0.24},
}

function UI.mouse_over(x, y, bx, by, bw, bh)
    return x >= bx and x <= bx + bw and y >= by and y <= by + bh
end

function UI.hit(mx, my, bx, by, bw, bh)
    return UI.mouse_over(mx, my, bx, by, bw, bh)
end

-- Draw horizontally centered text scaled about the center of the screen
-- (printf's built-in scale would scale about the left origin and drift).
-- color is an optional {r, g, b, a} table.
function UI.print_centered_scaled(text, y, scale, color)
    local W = love.graphics.getWidth()
    local c = color or {1, 1, 1, 1}
    love.graphics.setColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
    love.graphics.push()
    love.graphics.translate(W / 2, y)
    love.graphics.scale(scale, scale)
    love.graphics.printf(text, -W / 2, 0, W, "center")
    love.graphics.pop()
    love.graphics.setColor(1, 1, 1)
end

-- Draw one button. Returns true when hovered (useful for cursor feedback).
-- opts: { enabled = bool, subtext = string, font = Font, subfont = Font }
function UI.button(x, y, w, h, label, opts)
    opts = opts or {}
    local enabled = opts.enabled ~= false
    local mx, my = love.mouse.getPosition()
    local hovered = enabled and UI.mouse_over(mx, my, x, y, w, h)
    local c = UI.COLORS

    local fill = enabled and (hovered and c.fillHover or c.fill) or c.fillDisabled
    local border = enabled and (hovered and c.borderHover or c.border)
        or c.borderDisabled
    local text = enabled and c.text or c.textDisabled

    love.graphics.setColor(fill)
    love.graphics.rectangle("fill", x, y, w, h, 4, 4)
    love.graphics.setColor(border)
    love.graphics.setLineWidth(hovered and 3 or 2)
    love.graphics.rectangle("line", x, y, w, h, 4, 4)
    love.graphics.setLineWidth(1)

    love.graphics.setColor(text)
    local prevFont = love.graphics.getFont()
    local font = opts.font
    if font then love.graphics.setFont(font) end
    local labelY = y + h / 2 - (opts.subtext and 12 or 0)
    love.graphics.printf(label, x, labelY, w, "center")

    if opts.subtext then
        love.graphics.setColor(enabled and {0.75, 0.70, 0.60}
            or {0.35, 0.33, 0.33})
        if opts.subfont then love.graphics.setFont(opts.subfont) end
        love.graphics.printf(opts.subtext, x, y + h / 2 + 6, w, "center")
    end

    love.graphics.setFont(prevFont)
    love.graphics.setColor(1, 1, 1)
    return hovered
end

return UI
