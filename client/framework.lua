Framework = nil

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

if Config.Framework == "esx" then
    Citizen.CreateThread(function()
        while Framework == nil do
            local ESX = exports['es_extended']:getSharedObject()
            Wait(100)
        end
    end)
elseif Config.Framework == "qbcore" then
    Framework = exports['qb-core']:GetCoreObject()
elseif Config.Framework == "qbox" then
    Framework = exports['qbx-core']:GetCoreObject()
else
    print("[BlipManager] Framework non riconosciuto: " .. Config.Framework)
end

function GetPlayerJob()
    if Config.Framework == "esx" then
        local playerData = Framework.GetPlayerData()
        return playerData and playerData.job and playerData.job.name or "unknown"
    elseif Config.Framework == "qbcore" or Config.Framework == "qbox" then
        local playerData = Framework.Functions.GetPlayerData()
        return playerData and playerData.job and playerData.job.name or "unknown"
    else
        return "unknown"
    end
end
