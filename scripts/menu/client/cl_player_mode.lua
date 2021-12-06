-- ===============
--  This file contains functionality purely related
--  to player modes (noclip, godmode)
-- ===============
if (GetConvar('txAdmin-menuEnabled', 'false') ~= 'true') then
    return
end

local noClipEnabled = false

local function toggleGodMode(enabled)
    if enabled then
        sendPersistentAlert('godModeEnabled', 'info', 'nui_menu.page_main.player_mode.godmode.success', true)
    else
        clearPersistentAlert('godModeEnabled')
    end
    SetEntityInvincible(PlayerPedId(), enabled)
end

local freecamVeh = 0
local function toggleFreecam(enabled)
    noClipEnabled = enabled
    local ped = PlayerPedId()
    SetEntityVisible(ped, not enabled)
    SetPlayerInvincible(ped, enabled)
    FreezeEntityPosition(ped, enabled)

    if enabled then
        freecamVeh = GetVehiclePedIsIn(ped, false)
        if freecamVeh > 0 then
            NetworkSetEntityInvisibleToNetwork(freecamVeh, true)
            SetEntityCollision(freecamVeh, false, false)
        end
    end

    local function enableNoClip()
        lastTpCoords = GetEntityCoords(ped)

        SetFreecamActive(true)
        StartFreecamThread()

        Citizen.CreateThread(function()
            while IsFreecamActive() do
                SetEntityLocallyInvisible(ped)
                if freecamVeh > 0 then
                    if DoesEntityExist(freecamVeh) then
                        SetEntityLocallyInvisible(freecamVeh)
                    else
                        freecamVeh = 0
                    end
                end
                Wait(0)
            end

            if not DoesEntityExist(freecamVeh) then
                freecamVeh = 0
            end
            if freecamVeh > 0 then
                local coords = GetEntityCoords(ped)
                NetworkSetEntityInvisibleToNetwork(freecamVeh, false)
                SetEntityCollision(freecamVeh, true, true)
                SetEntityCoords(freecamVeh, coords[1], coords[2], coords[3])
                SetPedIntoVehicle(ped, freecamVeh, -1)
                freecamVeh = 0
            end
        end)
    end

    local function disableNoClip()
        SetFreecamActive(false)
        SetGameplayCamRelativeHeading(0)
    end

    if not IsFreecamActive() and enabled then
        sendPersistentAlert('noClipEnabled', 'info', 'nui_menu.page_main.player_mode.noclip.success', true)
        enableNoClip()
    end

    if IsFreecamActive() and not enabled then
        clearPersistentAlert('noClipEnabled')
        disableNoClip()
    end
end


RegisterCommand('txAdmin:menu:noClipToggle', function()
    if not DoesPlayerHavePerm(menuPermissions, 'players.playermode') then
        return sendSnackbarMessage('error', 'nui_menu.misc.general_no_perms', true)
    end

    debugPrint("NoClip toggled:" .. tostring(not noClipEnabled))

    -- Toggling behavior
    if noClipEnabled then
        TriggerServerEvent('txAdmin:menu:playerModeChanged', "none")
    else
        TriggerServerEvent('txAdmin:menu:playerModeChanged', "noclip")
    end
end)

local PTFX_ASSET = 'scr_firework_xmas_burst_rgw'
local PTFX_DICT = 'proj_xmas_firework'
local LOOP_AMOUNT = 25
local PTFX_DURATION = 1000

local IS_PTFX_DISABLED = GetConvarInt('txAdmin-menuPtfxDisable', 0) == 1

local function createPlayerModePtfxLoop(tgtPedId)
    if IS_PTFX_DISABLED then return end
    CreateThread(function()
        RequestNamedPtfxAsset(PTFX_DICT)
        local playerPed = tgtPedId or PlayerPedId()

        -- Wait until it's done loading.
        while not HasNamedPtfxAssetLoaded(PTFX_DICT) do
            Wait(0)
        end

        local particleTbl = {}

        for i=0, LOOP_AMOUNT do
            UseParticleFxAssetNextCall(PTFX_DICT)
            local partiResult = StartParticleFxLoopedOnEntity(PTFX_ASSET, playerPed, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.15, false, false, false)
            particleTbl[#particleTbl + 1] = partiResult
            Wait(0)
        end

        Wait(PTFX_DURATION)
        for _, parti in ipairs(particleTbl) do
            StopParticleFxLooped(parti, true)
        end
    end)

    -- If tgtPed isn't passed, it can be assumed that this was
    -- local execution and should be synced again. If it is passed,
    -- then we want to disregard syncing flow and just create the ptfx
    if tgtPedId then return end

    local players = GetActivePlayers()
    local playerServerIds = {}

    for _, player in ipairs(players) do
        playerServerIds[#playerServerIds + 1] = GetPlayerServerId(player)
    end

    TriggerServerEvent('txsv:syncPtfxEffect', playerServerIds)
end

-- This will trigger everytime the playerMode in the main menu is changed
-- it will send the mode
RegisterNUICallback('playerModeChanged', function(mode, cb)
    debugPrint("player mode requested: " .. (mode or 'nil'))
    TriggerServerEvent('txAdmin:menu:playerModeChanged', mode)
    createPlayerModePtfxLoop()
    cb({})
end)

RegisterNetEvent('txcl:syncPtfxEffect', function(tgtSrc)
    debugPrint('Syncing ptFX for target netId')
    local tgtPlayer = GetPlayerFromServerId(tgtSrc)
    local tgtPlayerPed = GetPlayerPed(tgtPlayer)
    if tgtSrc == 0 then return end
    createPlayerModePtfxLoop(tgtPlayerPed)
end)

-- [[ Player mode changed cb event ]]
RegisterNetEvent('txAdmin:menu:playerModeChanged', function(mode)
    if mode == 'godmode' then
        toggleFreecam(false)
        toggleGodMode(true)
    elseif mode == 'noclip' then
        toggleGodMode(false)
        toggleFreecam(true)
    elseif mode == 'none' then
        toggleFreecam(false)
        toggleGodMode(false)
    end
end)

