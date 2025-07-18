local blipFile = Config.BlipFile or "data/blips.json"

local function __xBC_check()
    if GetCurrentResourceName() ~= "xBlipCreator" then
        print("^1[ERROR] This script must be named ^3xBlipCreator^1 or it will not work!^0")
        return true
    end
    return false
end

if __xBC_check() then
    return
end

local Locale = {}

local function LoadLocale(lang)
    local path = ('locales/%s.json'):format(lang)
    local file = LoadResourceFile(GetCurrentResourceName(), path)
    if file then
        Locale = json.decode(file)
    else
        Locale = {}
    end
end

local function L(key)
    return Locale[key] or key
end

LoadLocale(Config.Locale or "en")

-- Debug-print helper
local function DebugPrint(key, ...)
    if Config.Debug then
        local msg = L(key)
        local args = {...}
        if #args > 0 then
            msg = msg .. " " .. table.concat(args, " ")
        end
        print("[BlipManager] " .. msg)
    end
end

-- Load blips from JSON
local function LoadBlips()
    local content = LoadResourceFile(GetCurrentResourceName(), blipFile)
    if not content then
        DebugPrint("debug_no_blips")
        SaveResourceFile(GetCurrentResourceName(), blipFile, "[]", -1)
        return {}
    elseif content == "" then
        DebugPrint("debug_no_blips")
        return {}
    end
    local ok, blips = pcall(function() return json.decode(content) end)
    if ok and type(blips) == "table" then
        DebugPrint("debug_received_blips", "(" .. #blips .. ")")
        return blips
    else
        DebugPrint("debug_no_blips")
        return {}
    end
end


-- Save blips to JSON
local function SaveBlips(blips)
    local encoded = json.encode(blips, { indent = true })
    SaveResourceFile(GetCurrentResourceName(), blipFile, encoded, -1)
    DebugPrint("debug_blip_loop", "(" .. #blips .. ")")
end

-- Server-side blip cache
local serverBlips = LoadBlips()
if #serverBlips == 0 then
end


lib.callback.register('blipmanager:getBlips', function(source)
    return serverBlips or {}
end)


local function BroadcastBlipsUpdate()
    TriggerClientEvent('blipmanager:refreshBlips', -1)
end

-- Add a blip
RegisterNetEvent('blipmanager:addBlip', function(blip)
    if type(blip.coords) == "vector3" then
        blip.coords = { x = blip.coords.x, y = blip.coords.y, z = blip.coords.z }
    end
    table.insert(serverBlips, blip)
    SaveBlips(serverBlips)
    BroadcastBlipsUpdate()
end)

-- Update a blip
RegisterNetEvent('blipmanager:updateBlip', function(index, blip)
    if serverBlips[index] then
        serverBlips[index] = blip
        SaveBlips(serverBlips)
        BroadcastBlipsUpdate()
    end
end)

-- Remove a blip
RegisterNetEvent('blipmanager:removeBlip', function(index)
    if serverBlips[index] then
        table.remove(serverBlips, index)
        SaveBlips(serverBlips)
        BroadcastBlipsUpdate()
    end
end)

-- Remove all blips
RegisterNetEvent('blipmanager:removeAllBlips', function()
    serverBlips = {}
    SaveBlips(serverBlips)
    BroadcastBlipsUpdate()
end)
