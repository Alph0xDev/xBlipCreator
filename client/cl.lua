local activeBlips = {}
local currentBlips = currentBlips or {}
local PlayerJob = nil
local adminCache = false
local checkedAdmin = false
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

local blipCache = {}
local function CreateBlips()
    RefreshBlips()
end

if Config.Framework == "esx" then
    RegisterNetEvent('esx:setJob', function(job)
        PlayerJob = job.name
        CreateBlips()
    end)
    function GetPlayerJob()
        return PlayerJob
    end
elseif Config.Framework == "qbcore" then
    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
        PlayerJob = job.name
        CreateBlips()
    end)
    function GetPlayerJob()
        return PlayerJob
    end
elseif Config.Framework == "qbox" then
    RegisterNetEvent('QBX:Client:OnJobUpdate', function(job)
        PlayerJob = job.name
        CreateBlips()
    end)
    function GetPlayerJob()
        return PlayerJob
    end
else
    function GetPlayerJob()
        return nil
    end
end

local function HasAdminPermission(cb)
    if Config.Framework == "esx" then
        if checkedAdmin then
            cb(adminCache)
        else
            -- chiedo al server se sono admin
            TriggerServerEvent('xblipcreator:checkAdmin')
            -- callback dall'evento
            RegisterNetEvent('xblipcreator:checkAdminResult', function(result)
                adminCache = result
                checkedAdmin = true
                cb(result)
            end)
        end
    elseif Config.Framework == "qbcore" or Config.Framework == "qbox" then
        if not QBCore then cb(false) return end
        local playerData = QBCore.Functions.GetPlayerData()
        cb(playerData and QBCore.Functions.HasPermission(playerData, "admin"))
    else
        cb(false)
    end
end

Citizen.CreateThread(function()
    if GetResourceState('es_extended') == 'started' then
        local ESX = exports['es_extended']:getSharedObject()
        while not ESX.IsPlayerLoaded() do Wait(1000) end
        PlayerJob = ESX.GetPlayerData().job.name
        RegisterNetEvent('esx:setJob', function(job)
            PlayerJob = job.name
            RefreshBlips()
        end)
    elseif GetResourceState('qb-core') == 'started' then
        QBCore = exports['qb-core']:GetCoreObject()
        PlayerJob = QBCore.Functions.GetPlayerData().job.name
        RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
            PlayerJob = job.name
            RefreshBlips()
        end)
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
            PlayerJob = QBCore.Functions.GetPlayerData().job.name
            RefreshBlips()
        end)
    elseif GetResourceState('qbx_core') == 'started' then
        QBCore = exports['qbx_core']:GetCoreObject()
        PlayerJob = QBCore.Functions.GetPlayerData().job.name
        RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
            PlayerJob = job.name
            RefreshBlips()
        end)
        RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
            PlayerJob = QBCore.Functions.GetPlayerData().job.name
            RefreshBlips()
        end)
    end
    if not PlayerJob then
        PlayerJob = GetPlayerJob()
    end
    RefreshBlips()
end)

local function CanSeeBlip(blip)
    if not blip.job or type(blip.job) ~= "table" or #blip.job == 0 then
        return true
    end
    for _, job in pairs(blip.job) do
        if job == PlayerJob then
            return true
        end
    end
    return false
end

local function CreateBlip(blipData)
    local blip = AddBlipForCoord(blipData.coords.x, blipData.coords.y, blipData.coords.z)
    SetBlipSprite(blip, blipData.sprite or 1)
    SetBlipDisplay(blip, blipData.display or 4)
    SetBlipScale(blip, blipData.scale or 0.8)
    SetBlipColour(blip, blipData.color or 0)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(blipData.label or L("unknown"))
    EndTextCommandSetBlipName(blip)
    table.insert(currentBlips, blip)
end

local function ClearBlips()
    if type(currentBlips) ~= "table" then
        currentBlips = {}
        return
    end
    for _, blip in pairs(currentBlips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    currentBlips = {}
end

local function DebugPrint(...)
    if Config.Debug then
        print(...)
    end
end

function RefreshBlips()
    ClearBlips()
    lib.callback('blipmanager:getBlips', false, function(blips)
        DebugPrint(L("debug_received_blips")..": "..json.encode(blips))
        if type(blips) ~= "table" then
            DebugPrint(L("debug_no_blips"))
            blips = {}
        end
        blipCache = blips
        for _, blip in ipairs(blips) do
            DebugPrint(L("debug_blip_loop")..": "..json.encode(blip))
            if CanSeeBlip(blip) then
                DebugPrint(L("debug_create_blip").." "..blip.label)
                CreateBlip(blip)
            else
                DebugPrint(L("debug_cant_see_blip").." "..blip.label)
            end
        end
    end)
end

RegisterNetEvent('blipmanager:refreshBlips', RefreshBlips)

RegisterCommand(Config.AdminCommand, function()
    HasAdminPermission(function(isAdmin)
        if isAdmin then
            OpenBlipMenu()
        else
            lib.notify({
                title = L("blip_manager_title"),
                description = L("no_permission"),
                type = "error"
            })
        end
    end)
end, false)



function OpenBlipMenu()
    if type(blipCache) ~= "table" then blipCache = {} end
    lib.registerContext({
        id = 'blip_manager',
        title = L('blip_manager_title'),
        options = {
            {
                title = L('add_blip'),
                onSelect = function()
                    local coords = GetEntityCoords(PlayerPedId())
                    local input = lib.inputDialog(L('new_blip'), {
                        {label = L('label'), type = 'input'},
                        {label = L('sprite_id'), type = 'number', min = 0, step = 1, required = true},
                        {label = L('color_id'), type = 'number', min = 0, step = 1, required = true},
                        {label = L('scale'), type = 'input', min = 0.1, max = 100, required = true},
                        {label = L('display'), type = 'number', min = 0, max = 4, step = 1, required = true},
                        {label = L('jobs'), type = 'input'}
                    })
                    if not input then return end
                    local newBlip = {
                        label = input[1],
                        coords = vector3(tonumber(coords.x), tonumber(coords.y), tonumber(coords.z)),
                        sprite = tonumber(input[2]),
                        color = tonumber(input[3]),
                        scale = tonumber(input[4]),
                        display = tonumber(input[5]),
                        job = {}
                    }
                    if input[6] and input[6] ~= "" then
                        for job in string.gmatch(input[6], '([^,]+)') do
                            local cleanJob = tostring(job):lower():gsub('^%s*(.-)%s*$', '%1')
                            table.insert(newBlip.job, cleanJob)
                        end
                    end
                    TriggerServerEvent('blipmanager:addBlip', newBlip)
                    lib.notify({title = L("blip_manager_title"), description = L("blip_created_success"), type = "success"})
                end
            },
            {
                title = L('edit_blip'),
                onSelect = function()
                    local options = {}
                    for i, b in pairs(blipCache) do
                        if b and b.label then
                            table.insert(options, {
                                title = b.label,
                                description = L('sprite_id')..": "..b.sprite.." | "..L('color_id')..": "..b.color,
                                icon = "📝",
                                onSelect = function()
                                    OpenSingleBlipMenu(i)
                                end
                            })
                        end
                    end
                    if #options == 0 then
                        lib.notify({
                            title = L("blip_manager_title"),
                            description = L("no_blips_edit"),
                            type = "error"
                        })
                        return
                    end
                    lib.registerContext({
                        id = 'edit_blip',
                        title = L('edit_blip'),
                        options = options
                    })
                    lib.showContext('edit_blip')
                end
            },
            {
                title = L('remove_all_blips'),
                onSelect = function()
                    lib.registerContext({
                        id = 'confirm_remove_all',
                        title = L('confirm_remove_all'),
                        options = {
                            {
                                title = L('yes_remove_all'),
                                onSelect = function()
                                    TriggerServerEvent('blipmanager:removeAllBlips')
                                    lib.notify({
                                        title = L("blip_manager_title"),
                                        description = L("all_blips_removed"),
                                        type = "error"
                                    })
                                end
                            },
                            {
                                title = L('cancel'),
                                onSelect = function()
                                    lib.showContext('blip_manager')
                                end
                            }
                        }
                    })
                    lib.showContext('confirm_remove_all')
                end
            }
        }
    })
    lib.showContext('blip_manager')
end



function OpenSingleBlipMenu(index)
    if type(blipCache) ~= "table" then blipCache = {} end
    local b = blipCache[index]
    if not b then
        lib.notify({title = L("blip_manager_title"), description = L("blip_not_found"), type = "error"})
        return
    end
    lib.registerContext({
        id = 'single_blip_menu',
        title = L('edit_blip')..": "..b.label,
        options = {
            {
                title = L('edit_label'),
                onSelect = function()
                    local input = lib.inputDialog(L('edit_label'), {L('new_label')}, {default = {b.label}})
                    if not input then return end
                    b.label = input[1]
                    TriggerServerEvent('blipmanager:updateBlip', index, b)
                    blipCache[index] = b
                    lib.notify({title = L("blip_manager_title"), description = L("label_updated"), type = "success"})
                    OpenSingleBlipMenu(index)
                end
            },
            {
                title = L('edit_sprite'),
                onSelect = function()
                    local input = lib.inputDialog(L('edit_sprite'), {
                        {label = L('sprite_id'), type = 'number', min = 0, step = 1, required = true}
                    }, {default = {tostring(b.sprite)}})
                    if not input then return end
                    local val = tonumber(input[1])
                    if val then
                        b.sprite = val
                        TriggerServerEvent('blipmanager:updateBlip', index, b)
                        blipCache[index] = b
                        RefreshBlips()
                        lib.notify({title = L("blip_manager_title"), description = L("sprite_updated"), type = "success"})
                    else
                        lib.notify({title = L("blip_manager_title"), description = L("enter_valid_number"), type = "error"})
                    end
                    OpenSingleBlipMenu(index)
                end
            },
            {
                title = L('edit_color'),
                onSelect = function()
                    local input = lib.inputDialog(L('edit_color'), {
                        {label = L('color_id'), type = 'number', min = 0, step = 1, required = true}
                    }, {default = {tostring(b.color)}})
                    if not input then return end
                    local val = tonumber(input[1])
                    if val then
                        b.color = val
                        TriggerServerEvent('blipmanager:updateBlip', index, b)
                        blipCache[index] = b
                        RefreshBlips()  
                        lib.notify({title = L("blip_manager_title"), description = L("color_updated"), type = "success"})
                    else
                        lib.notify({title = L("blip_manager_title"), description = L("enter_valid_number"), type = "error"})
                    end
                    OpenSingleBlipMenu(index)
                end
            },
            {
                title = L('edit_scale'),
                onSelect = function()
                    local input = lib.inputDialog(L('edit_scale'), {
                        {label = L('scale'), type = 'input', min = 0.1, max = 100, required = true},
                    }, {default = {tostring(b.scale)}})
                    if not input then return end
                    local val = tonumber(input[1])
                    if val then
                        b.scale = val
                        TriggerServerEvent('blipmanager:updateBlip', index, b)
                        blipCache[index] = b
                        RefreshBlips()
                        lib.notify({title = L("blip_manager_title"), description = L("scale_updated"), type = "success"})
                    else
                        lib.notify({title = L("blip_manager_title"), description = L("enter_valid_number"), type = "error"})
                    end
                    OpenSingleBlipMenu(index)
                end
            },
            {
                title = L('edit_display'),
                onSelect = function()
                    local input = lib.inputDialog(L('edit_display'), {
                        {label = L('display'), type = 'number', min = 0, max = 4, step = 1, required = true}
                    }, {default = {tostring(b.display)}})
                    if not input then return end
                    local val = tonumber(input[1])
                    if val and val >= 0 and val <= 4 then
                        b.display = val
                        TriggerServerEvent('blipmanager:updateBlip', index, b)
                        blipCache[index] = b
                        RefreshBlips()    
                        lib.notify({title = L("blip_manager_title"), description = L("display_updated"), type = "success"})
                    else
                        lib.notify({title = L("blip_manager_title"), description = L("enter_number_0_4"), type = "error"})
                    end
                    OpenSingleBlipMenu(index)
                end
            },
            {
                title = L('edit_jobs'),
                onSelect = function()
                    local input = lib.inputDialog(L('edit_jobs'), {L('jobs_hint')}, {default = {table.concat(b.job, ',')}})
                    if not input then return end
                    local jobs = {}
                    if input[1] ~= "" then
                        for job in string.gmatch(input[1], '([^,]+)') do
                            local cleanJob = tostring(job):lower():gsub('^%s*(.-)%s*$', '%1')
                            table.insert(jobs, cleanJob)
                        end
                        b.job = jobs
                    else
                        b.job = {}
                    end
                    TriggerServerEvent('blipmanager:updateBlip', index, b)
                    blipCache[index] = b
                    RefreshBlips()   
                    lib.notify({title = L("blip_manager_title"), description = L("jobs_updated"), type = "success"})
                    OpenSingleBlipMenu(index)
                end
            },
            {
                title = L('change_position'),
                onSelect = function()
                    local coords = GetEntityCoords(PlayerPedId())
                    b.coords = vector3(coords.x, coords.y, coords.z)
                    TriggerServerEvent('blipmanager:updateBlip', index, b)
                    blipCache[index] = b
                    RefreshBlips()   
                    lib.notify({title = L("blip_manager_title"), description = L("position_updated"), type = "success"})
                    OpenSingleBlipMenu(index)
                end
            },
            {
                title = L('delete_blip'),
                onSelect = function()
                    TriggerServerEvent('blipmanager:removeBlip', index)
                    lib.notify({title = L("blip_manager_title"), description = L("blip_deleted"), type = "error"})
                    lib.showContext('blip_manager')
                end
            },
            {
                title = L('back'),
                onSelect = function()
                    lib.showContext('edit_blip')
                end
            }
        }
    })
    lib.showContext('single_blip_menu')
end

