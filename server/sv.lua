local blipFile = Config.BlipFile or "data/blips.json"
local QBCore = nil
local ESX = nil
local resourceName = GetCurrentResourceName()
local CURRENT_VERSION = "1.0.1"
local GITHUB_RAW_URL = "https://raw.githubusercontent.com/Alph0xDev/xBlipCreator/main/version.txt"

CreateThread(function()
    PerformHttpRequest(GITHUB_RAW_URL, function(err, text, headers)
        if err ~= 200 or not text then
            print("["..resourceName.."] Could not check for updates.")
            return
        end

        local latestVersion = text:match("^%s*(.-)%s*$")
        if latestVersion == CURRENT_VERSION then
            print("["..resourceName.."] You are running the latest version: "..CURRENT_VERSION)
        else
            print("["..resourceName.."] Update available!")
            print("["..resourceName.."] Current version: "..CURRENT_VERSION.." - Latest: "..latestVersion)
            print("["..resourceName.."] Download here: https://github.com/Alph0xDev/xBlipCreator")
        end
    end, "GET")
end)
Citizen.CreateThread(function()
    if GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
    elseif GetResourceState('qbx_core') == 'started' then
        QBCore = exports['qbx_core']:GetCoreObject()
    elseif GetResourceState('es_extended') == 'started' then
        ESX = exports['es_extended']:getSharedObject()
    end
end)

RegisterNetEvent('xblipcreator:checkAdmin', function()
    local src = source
    local allowed = false

    -- ACE permission
    if IsPlayerAceAllowed(src, "xblipcreator.admin") then
        allowed = true
    end

    -- QBCore/QBX permission
    if QBCore then
        local player = QBCore.Functions.GetPlayer(src)
        if player and QBCore.Functions.HasPermission(player, "admin") then
            allowed = true
        end
    end

    -- ESX permission
    if ESX then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer and xPlayer.getGroup() == "admin" then
            allowed = true
        end
    end

    TriggerClientEvent('xblipcreator:checkAdminResult', src, allowed)
end)

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

local function SaveBlips(blips)
    local encoded = json.encode(blips, { indent = true })
    SaveResourceFile(GetCurrentResourceName(), blipFile, encoded, -1)
    DebugPrint("debug_blip_loop", "(" .. #blips .. ")")
end

local serverBlips = LoadBlips()
if #serverBlips == 0 then
end


lib.callback.register('blipmanager:getBlips', function(source)
    return serverBlips or {}
end)


local function BroadcastBlipsUpdate()
    TriggerClientEvent('blipmanager:refreshBlips', -1)
end

RegisterNetEvent('blipmanager:addBlip', function(blip)
    if type(blip.coords) == "vector3" then
        blip.coords = { x = blip.coords.x, y = blip.coords.y, z = blip.coords.z }
    end
    table.insert(serverBlips, blip)
    SaveBlips(serverBlips)
    BroadcastBlipsUpdate()
end)

RegisterNetEvent('blipmanager:updateBlip', function(index, blip)
    if serverBlips[index] then
        serverBlips[index] = blip
        SaveBlips(serverBlips)
        BroadcastBlipsUpdate()
    end
end)

RegisterNetEvent('blipmanager:removeBlip', function(index)
    if serverBlips[index] then
        table.remove(serverBlips, index)
        SaveBlips(serverBlips)
        BroadcastBlipsUpdate()
    end
end)

RegisterNetEvent('blipmanager:removeAllBlips', function()
    serverBlips = {}
    SaveBlips(serverBlips)
    BroadcastBlipsUpdate()
end)
