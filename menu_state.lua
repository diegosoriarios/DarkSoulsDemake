-- menu_state.lua - Main menu, victory, and game over screens

local UI = require("ui")
local Save = require("save")

local MenuState = {}
local menu_type = "main" -- "main", "victory", "gameover"

-- Button layout, rebuilt each frame and hit-tested by mousepressed.
local buttons = {}

local function layout_buttons(items)
    local W = love.graphics.getWidth()
    local bw, bh, gap = 320, 64, 20
    local x = (W - bw) / 2
    local y = 420
    buttons = {}
    for i, item in ipairs(items) do
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
end

function MenuState.exit()
end

function MenuState.update(dt)
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
    local hasSave = Save.exists()
    local items = {}
    if hasSave then
        items[#items + 1] = { id = "continue", label = "Continue" }
    end
    items[#items + 1] = {
        id = "newgame",
        label = hasSave and "New Game" or "Start Game",
    }
    items[#items + 1] = { id = "quit", label = "Quit" }
    layout_buttons(items)

    centered_title("LANTERNFALL", 230, {1, 1, 1}, 4)
    love.graphics.setColor(0.65, 0.62, 0.55)
    love.graphics.printf("A pilgrimage through the Guttering Reach",
        0, 330, love.graphics.getWidth(), "center")
    love.graphics.setColor(0.5, 0.47, 0.42)
    love.graphics.printf(
        hasSave and "Continue your journey, or start anew."
            or "Gather the Embers. Part the Northlight fog.",
        0, 360, love.graphics.getWidth(), "center")
    love.graphics.setColor(1, 1, 1)
end

function MenuState.draw_victory()
    layout_buttons({
        { id = "restart", label = "Restart" },
        { id = "mainmenu", label = "Main Menu" },
    })
    centered_title("VICTORY!", 250, {1, 0.8, 0}, 4)
    love.graphics.setColor(0.75, 0.72, 0.65)
    love.graphics.printf("The Guttering King falls. The Rust recedes.",
        0, 350, love.graphics.getWidth(), "center")
    love.graphics.setColor(1, 1, 1)
end

function MenuState.draw_gameover()
    layout_buttons({
        { id = "restart", label = "Restart" },
        { id = "mainmenu", label = "Main Menu" },
    })
    centered_title("YOU DIED", 250, {1, 0, 0}, 4)
    love.graphics.setColor(0.75, 0.72, 0.65)
    love.graphics.printf("Your light fades. The Vigil waits.",
        0, 350, love.graphics.getWidth(), "center")
    love.graphics.setColor(1, 1, 1)
end

local function do_continue()
    if type(continue_game) == "function" and continue_game() then return end
    if type(new_game) == "function" then new_game() end
end

local function do_new_game()
    if type(new_game) == "function" then new_game() end
end

local function go_main_menu()
    MenuState.set_menu_type("main")
    local StateManager = require("state_manager")
    StateManager.set_state("menu")
end

function MenuState.keypressed(key)
    if menu_type == "main" then
        if key == "space" then
            if Save.exists() then
                do_continue()
            else
                do_new_game()
            end
        elseif key == "escape" then
            love.event.quit()
        end
    elseif menu_type == "victory" or menu_type == "gameover" then
        if key == "r" then
            do_new_game()
        elseif key == "escape" then
            go_main_menu()
        end
    end
end

function MenuState.mousepressed(x, y, mouse_button)
    if mouse_button ~= 1 then return end
    for _, b in ipairs(buttons) do
        if UI.hit(x, y, b.x, b.y, b.w, b.h) then
            if b.id == "continue" then
                do_continue()
            elseif b.id == "newgame" or b.id == "restart" then
                do_new_game()
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
