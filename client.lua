local threshold = Config.brakeLightThreshold
local trackedVehicles = {}
local isLoopActive = false
local activeParkTimers = {}
local MPH_PER_MS = 2.236936

local function debugLog(message)
  if not Config.debug then return end
  print(('[RBL][CLIENT] %s'):format(message))
end

local function setParkTimerToken(vehicle, token)
  activeParkTimers[vehicle] = token
end

local function clearParkTimerToken(vehicle)
  activeParkTimers[vehicle] = nil
end

local function brakeLightLoop()
  CreateThread(function()
    isLoopActive = true
    debugLog('Brake light loop started')

    while next(trackedVehicles) do
      for vehicle, data in pairs(trackedVehicles) do
        if DoesEntityExist(vehicle) then
          SetVehicleBrakeLights(vehicle, not data.parked)
        else
          trackedVehicles[vehicle] = nil
          clearParkTimerToken(vehicle)
          debugLog(('Removed missing tracked vehicle %s'):format(vehicle))
        end
      end

      Wait(0)
    end

    isLoopActive = false
    debugLog('Brake light loop stopped')
  end)
end

AddStateBagChangeHandler('rbl_brakelights', nil, function(bagName, _, value)
  Wait(0)

  local vehicle = GetEntityFromStateBagName(bagName)
  if vehicle == 0 then
    debugLog(('Ignored brake light state change for unresolved bag %s'):format(bagName))
    return
  end

  if value then
    if not trackedVehicles[vehicle] then
      local entity = Entity(vehicle)
      trackedVehicles[vehicle] = {
        parked = entity.state.rbl_parked == true
      }
      debugLog(('Tracking vehicle %s for forced brake lights'):format(vehicle))
    end

    if not isLoopActive then
      brakeLightLoop()
    end
  else
    trackedVehicles[vehicle] = nil
    clearParkTimerToken(vehicle)
    debugLog(('Stopped tracking vehicle %s for forced brake lights'):format(vehicle))
  end
end)

local function startParkTimer(vehicle)
  if not Config.enableParkEffect then return end
  if Config.parkTimerMax < Config.parkTimerMin then
    debugLog('Park timer skipped because parkTimerMax is lower than parkTimerMin')
    return
  end

  local token = GetGameTimer()
  local duration = math.random((Config.parkTimerMin * 1000), (Config.parkTimerMax * 1000))
  local expiresAt = GetGameTimer() + duration

  setParkTimerToken(vehicle, token)
  debugLog(('Started park timer for vehicle %s (%sms)'):format(vehicle, duration))

  CreateThread(function()
    while activeParkTimers[vehicle] == token do
      if vehicle == 0 or not DoesEntityExist(vehicle) then
        clearParkTimerToken(vehicle)
        debugLog(('Cancelled park timer for missing vehicle %s'):format(vehicle))
        return
      end

      local ped = PlayerPedId()
      if GetVehiclePedIsIn(ped, false) ~= vehicle then
        clearParkTimerToken(vehicle)
        debugLog(('Cancelled park timer because player left vehicle %s'):format(vehicle))
        return
      end

      if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        clearParkTimerToken(vehicle)
        debugLog(('Cancelled park timer because player left driver seat in vehicle %s'):format(vehicle))
        return
      end

      if (GetEntitySpeed(vehicle) * MPH_PER_MS) > 0 then
        clearParkTimerToken(vehicle)
        debugLog(('Cancelled park timer because vehicle %s started moving'):format(vehicle))
        return
      end

      if GetGameTimer() >= expiresAt then
        clearParkTimerToken(vehicle)
        debugLog(('Park timer expired for vehicle %s'):format(vehicle))
        TriggerServerEvent('rbl:setParked', VehToNet(vehicle), true)
        return
      end

      Wait(500)
    end
  end)
end

local function onEnteredVehicle(vehicle)
  CreateThread(function()
    local entity = Entity(vehicle)
    local vehicleNet = VehToNet(vehicle)
    local brakeLightsEnabled = false

    debugLog(('Entered vehicle %s (class %s, netId %s)'):format(vehicle, GetVehicleClass(vehicle), vehicleNet))

    while true do
      local ped = PlayerPedId()

      if vehicle == 0 or not DoesEntityExist(vehicle) then
        clearParkTimerToken(vehicle)
        debugLog('Stopped vehicle monitor because the entity no longer exists')
        return
      end

      if GetVehiclePedIsIn(ped, false) ~= vehicle then
        if brakeLightsEnabled then
          TriggerServerEvent('rbl:setBrakeLights', vehicleNet, false)
        end
        clearParkTimerToken(vehicle)
        TriggerServerEvent('rbl:setParked', vehicleNet, true)
        debugLog(('Exited vehicle %s'):format(vehicle))
        return
      end

      if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        if brakeLightsEnabled then
          TriggerServerEvent('rbl:setBrakeLights', vehicleNet, false)
        end
        clearParkTimerToken(vehicle)
        debugLog(('Lost driver seat in vehicle %s'):format(vehicle))
        return
      end

      local speed = GetEntitySpeed(vehicle) * MPH_PER_MS
      local accelerating = IsControlPressed(0, 32)

      if speed <= threshold and not accelerating then
        if not brakeLightsEnabled then
          brakeLightsEnabled = true
          debugLog(('Brake lights enabled for vehicle %s at %.2f MPH'):format(vehicle, speed))
          TriggerServerEvent('rbl:setBrakeLights', vehicleNet, true)
          startParkTimer(vehicle)
        end
      else
        if brakeLightsEnabled then
          brakeLightsEnabled = false
          debugLog(('Brake lights disabled for vehicle %s at %.2f MPH'):format(vehicle, speed))
          TriggerServerEvent('rbl:setBrakeLights', vehicleNet, false)
        end

        clearParkTimerToken(vehicle)

        if entity.state.rbl_parked then
          debugLog(('Vehicle %s is moving again, clearing parked state'):format(vehicle))
          TriggerServerEvent('rbl:setParked', vehicleNet, false)
        end
      end

      Wait(250)
    end
  end)
end

AddEventHandler('gameEventTriggered', function(eventName, args)
  if eventName ~= 'CEventNetworkPlayerEnteredVehicle' then return end
  if args[1] ~= PlayerId() then return end

  local vehicle = args[2]
  if GetPedInVehicleSeat(vehicle, -1) ~= PlayerPedId() then return end

  onEnteredVehicle(vehicle)
end)

AddStateBagChangeHandler('rbl_parked', nil, function(bagName, _, value)
  Wait(0)

  local vehicle = GetEntityFromStateBagName(bagName)
  if vehicle == 0 then
    debugLog(('Ignored parked state change for unresolved bag %s'):format(bagName))
    return
  end

  if trackedVehicles[vehicle] then
    trackedVehicles[vehicle].parked = value == true
  end

  debugLog(('State bag parked changed for vehicle %s to %s'):format(vehicle, tostring(value)))
end)

CreateThread(function()
  Wait(1000)

  local ped = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(ped, false)
  if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then return end

  debugLog(('Resource started while already in vehicle %s'):format(vehicle))
  TriggerServerEvent('rbl:setBrakeLights', VehToNet(vehicle), false)
  onEnteredVehicle(vehicle)
end)

AddEventHandler('onResourceStop', function(resourceName)
  if resourceName ~= GetCurrentResourceName() then return end

  local ped = PlayerPedId()
  local vehicle = GetVehiclePedIsIn(ped, false)
  if vehicle == 0 or not DoesEntityExist(vehicle) then return end
  if GetPedInVehicleSeat(vehicle, -1) ~= ped then return end

  local netId = VehToNet(vehicle)
  if netId == 0 then return end

  clearParkTimerToken(vehicle)
  debugLog(('Resource stopping, resetting vehicle %s'):format(vehicle))
  TriggerServerEvent('rbl:setBrakeLights', netId, false)
  TriggerServerEvent('rbl:setParked', netId, true)
end)
