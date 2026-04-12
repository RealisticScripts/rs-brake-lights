local currentVersion = 'v1.0.0'

local function fetchLatestVersion(callback)
    PerformHttpRequest('https://api.github.com/repos/RealisticScripts/rs-brake-lights/releases/latest', function(statusCode, response)
        if statusCode == 200 then
            local data = json.decode(response)
            if data and data.tag_name then
                callback(data.tag_name)
            else
                print('[rs-brake-lights] Failed to fetch the latest version')
            end
        else
            print(('[rs-brake-lights] HTTP request failed with status code: %s'):format(statusCode))
        end
    end, 'GET')
end

local function checkForUpdates()
    fetchLatestVersion(function(latestVersion)
        if currentVersion ~= latestVersion then
            print('[rs-brake-lights] A new version of the script is available!')
            print(('[rs-brake-lights] Current version: %s'):format(currentVersion))
            print(('[rs-brake-lights] Latest version: %s'):format(latestVersion))
            print('[rs-brake-lights] Please update the script from: https://github.com/RealisticScripts/rs-brake-lights')
        else
            print('[rs-brake-lights] Your script is up to date!')
        end
    end)
end


checkForUpdates()



RegisterNetEvent('rbl:setBrakeLights', function(netId, state)
  local vehicle = NetworkGetEntityFromNetworkId(netId)
  if vehicle == 0 or not DoesEntityExist(vehicle) then
    debugLog(('Ignored brake light update for invalid netId %s'):format(tostring(netId)))
    return
  end

  debugLog(('Setting brake lights for netId %s to %s'):format(netId, tostring(state)))
  Entity(vehicle).state.rbl_brakelights = state == true
end)

RegisterNetEvent('rbl:setParked', function(netId, state)
  local vehicle = NetworkGetEntityFromNetworkId(netId)
  if vehicle == 0 or not DoesEntityExist(vehicle) then
    debugLog(('Ignored parked update for invalid netId %s'):format(tostring(netId)))
    return
  end

  debugLog(('Setting parked for netId %s to %s'):format(netId, tostring(state)))
  Entity(vehicle).state.rbl_parked = state == true
end)


