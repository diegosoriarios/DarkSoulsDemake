-- state_manager.lua - Central state management system

local StateManager = {}
StateManager.states = {}
StateManager.current_state = nil

function StateManager.add_state(name, state)
    StateManager.states[name] = state
end

function StateManager.set_state(name)
    if StateManager.states[name] then
        if StateManager.current_state and StateManager.current_state.exit then
            StateManager.current_state.exit()
        end
        
        StateManager.current_state = StateManager.states[name]
        
        if StateManager.current_state.enter then
            StateManager.current_state.enter()
        end
    else
        error("State '" .. name .. "' not found")
    end
end

function StateManager.update(dt)
    if StateManager.current_state and StateManager.current_state.update then
        StateManager.current_state.update(dt)
    end
end

function StateManager.draw()
    if StateManager.current_state and StateManager.current_state.draw then
        StateManager.current_state.draw()
    end
end

function StateManager.keypressed(key)
    if StateManager.current_state and StateManager.current_state.keypressed then
        StateManager.current_state.keypressed(key)
    end
end

function StateManager.mousepressed(x, y, button)
    if StateManager.current_state and StateManager.current_state.mousepressed then
        StateManager.current_state.mousepressed(x, y, button)
    end
end

function StateManager.get_state()
    return StateManager.current_state
end

return StateManager