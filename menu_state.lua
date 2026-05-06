-- menu_state.lua - Handles main menu, victory, and game over screens

local MenuState = {}
local menu_type = "main" -- "main", "victory", "gameover"

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
end

function MenuState.draw_main_menu()
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("DARK SOULS DEMAKE", 0, 200, 800, "center", 0, 3)
    love.graphics.printf("Press SPACE to start", 0, 300, 800, "center")
    love.graphics.printf("Press ESC to quit", 0, 330, 800, "center")
end

function MenuState.draw_victory()
    love.graphics.setColor(1, 0.8, 0)
    love.graphics.printf("VICTORY!", 0, 260, 800, "center", 0, 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press R to restart", 0, 330, 800, "center")
    love.graphics.printf("Press ESC for main menu", 0, 360, 800, "center")
end

function MenuState.draw_gameover()
    love.graphics.setColor(1, 0, 0)
    love.graphics.printf("YOU DIED", 0, 260, 800, "center", 0, 3)
    love.graphics.setColor(1, 1, 1)
    love.graphics.printf("Press R to restart", 0, 330, 800, "center")
    love.graphics.printf("Press ESC for main menu", 0, 360, 800, "center")
end

function MenuState.keypressed(key)
    if menu_type == "main" then
        if key == "space" then
            -- Start game - go to world state
            local StateManager = require("state_manager")
            love.load() -- Reset game
            StateManager.set_state("world")
        elseif key == "escape" then
            love.event.quit()
        end
    elseif menu_type == "victory" or menu_type == "gameover" then
        if key == "r" then
            love.load()
            local StateManager = require("state_manager")
            StateManager.set_state("world")
        elseif key == "escape" then
            MenuState.set_menu_type("main")
            local StateManager = require("state_manager")
            StateManager.set_state("menu")
        end
    end
end

return MenuState