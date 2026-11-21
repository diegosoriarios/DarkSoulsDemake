-- save.lua - Single-slot autosave to the LÖVE save directory
--
-- The save is a tiny Lua literal table, read back inside an empty
-- environment (no globals) so a hand-edited save cannot execute code.

local Save = {}

Save.FILE = "demake_save.lua"
Save.VERSION = 5

local function serialize(v)
    local t = type(v)
    if t == "nil" then
        return "nil"
    elseif t == "boolean" or t == "number" then
        return tostring(v)
    elseif t == "string" then
        return string.format("%q", v)
    elseif t == "table" then
        local parts = {}
        for k, val in pairs(v) do
            local key
            if type(k) == "string" then
                key = string.format("[%q]", k)
            elseif type(k) == "number" then
                key = "[" .. tostring(k) .. "]"
            end
            if key then
                parts[#parts + 1] = key .. " = " .. serialize(val)
            end
        end
        return "{ " .. table.concat(parts, ", ") .. " }"
    end
    return "nil"
end

function Save.exists()
    return love.filesystem.getInfo(Save.FILE) ~= nil
end

function Save.erase()
    if Save.exists() then love.filesystem.remove(Save.FILE) end
end

function Save.write(data)
    if type(data) ~= "table" then return false end
    data.version = Save.VERSION
    return love.filesystem.write(Save.FILE, "return " .. serialize(data))
end

function Save.read()
    if not Save.exists() then return nil end
    local chunk, err = love.filesystem.load(Save.FILE)
    if not chunk then return nil, err end
    if setfenv then setfenv(chunk, {}) end
    local ok, data = pcall(chunk)
    if not ok or type(data) ~= "table" then return nil end
    if data.version ~= Save.VERSION then return nil end
    return data
end

return Save
