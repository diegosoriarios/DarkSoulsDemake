-- menu_state.lua - Handles main menu, victory, and game over screens

local UI = require("ui")

local MenuState = {}
local menu_type = "main" -- "main", "victory", "gameover"

-- Button layout, rebuilt each frame and hit-tested by mousepressed.
local buttons = {}

local function layout_buttons(labels)
    local W = love.graphics.getWidth()
    local bw, bh, gap = 320, 64, 20
    local x = (W - bw) / 2
    local y = 420
    buttons = {}
    for i, item in ipairs(labels) do
        buttons[i] = {
            id = item.id,
            x = x,
            y = y + (i - 1) * (bh + gap),
            w = bw,
            h = bh,
            label = item.label,
        }
    end
end

function MenuState.set_menu_type(type)
    menu_type = type
end

function MenuState.enter()
    -- Initialize menu based on type
    if menu_type == "main" then
        -- Main menu initialization
    elseif menu_type == "victory" then
        -- Victory screen initialization
    elseif menu_type == "gameover" then
        -- Game over screen initialization
    end
end

function MenuState.exit()
    -- Clean up when leaving menu state
end

function MenuState.update(dt)
    -- Menu animations or timed transitions could go here
end

function MenuState.draw()
    love.graphics.setBackgroundColor(0.05, 0.05, 0.08)

    if menu_type == "main" then
        MenuState.draw_main_menu()
    elseif menu_type == "victory" then
        MenuState.draw_victory()
    elseif menu_type == "gameover" then
        MenuState.draw_gameover()
    end

    for _, b in ipairs(buttons) do
        UI.button(b.x, b.y, b.w, b.h, b.label)
    end
end

local function centered_title(text, y, color, scale)
    UI.print_centered_scaled(text, y, scale or 3, color)
end

function MenuState.draw_main_menu()
    layout_buttons({
        { id = "start", label = "Start Game" },
        { id = "quit", label = "Quit" },
    })
    centered_title("DARK SOULS DEMAKE", 240, {1, 1, 1}, 4)
    love.graphics.setColor(0.65, 0.62, 0.55)
    love.graphics.printf("A turn-based journey into the dark",
        0, 330, love.graphics.getWidth(), "center")
    love.graphics.setColor(1, 1, 1)
end

function MenuState.draw_victory()
    layout_buttons({
        { id = "restart", label = "Restart" },
        { id = "mainmenu", label = "Main Menu" },
    })
    centered_title("VICTORY!", 260, {1, 0.8, 0}, 4)
    love.graphics.setColor(0.75, 0.72, 0.65)
    love.graphics.printf("The Ashen Lord has fallen. The curse is broken.",
        0, 360, love.graphics.getWidth(), "center")
    love.graphics.setColor(1, 1, 1)
end

function MenuState.draw_gameover()
    layout_buttons({
        { id = "restart", label = "Restart" },
        { id = "mainmenu", label = "Main Menu" },
    })
    centered_title("YOU DIED", 260, {1, 0, 0}, 4)
    love.graphics.setColor(0.75, 0.72, 0.65)
    love.graphics.printf("The dark claims another soul.",
        0, 360, love.graphics.getWidth(), "center")
    love.graphics.setColor(1, 1, 1)
end

local function start_game()
    local StateManager = require("state_manager")
    love.load() -- Reset game
    StateManager.set_state("world")
end

local function go_main_menu()
    MenuState.set_menu_type("main")
    local StateManager = require("state_manager")
    StateManager.set_state("menu")
end

function MenuState.keypressed(key)
    if menu_type == "main" then
        if key == "space" then
            start_game()
        elseif key == "escape" then
            love.event.quit()
        end
    elseif menu_type == "victory" or menu_type == "gameover" then
        if key == "r" then
            start_game()
        elseif key == "escape" then
            go_main_menu()
        end
    end
end

function MenuState.mousepressed(x, y, mouse_button)
    if mouse_button ~= 1 then return end
    for _, b in ipairs(buttons) do
        if UI.hit(x, y, b.x, b.y, b.w, b.h) then
            if b.id == "start" or b.id == "restart" then
                start_game()
            elseif b.id == "quit" then
                love.event.quit()
            elseif b.id == "mainmenu" then
                go_main_menu()
            end
            return
        end
    end
end

return MenuState
