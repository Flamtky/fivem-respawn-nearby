RESPAWN_RADIUS = 75     -- default 75
RESPAWN_DELAY = 5       -- seconds (def. 5)
BACKUP_RESPAWN_POINTS = {
	{ x = 0, y = 0, z = 70 } --TODO: Add more backup respawn points (only in or near city)
}
INIT_PLAYER_MODELS = {
	"a_m_y_skater_01",
	"a_m_y_skater_02",
	"a_m_y_stbla_01",
	"a_m_y_stbla_02"
}

BLIPS = {}
DEBUG_PRINT = true
DEBUG_BLIPS = true

-- https://docs.fivem.net/docs/resources/baseevents/events/onPlayerDied/
AddEventHandler('baseevents:onPlayerDied', function(killerType, deathCoords)
	clearBlips()
	exports.spawnmanager:setAutoSpawn(false)
	Wait(RESPAWN_DELAY * 1000)
	RespawnNear(deathCoords, RESPAWN_RADIUS)
	ClearPedBloodDamage(GetPlayerPed(-1))
end)

-- https://docs.fivem.net/docs/resources/baseevents/events/onPlayerKilled/
AddEventHandler('baseevents:onPlayerKilled', function(killerId, deathData)
	clearBlips()
	exports.spawnmanager:setAutoSpawn(false)
	Wait(RESPAWN_DELAY * 1000)
	RespawnNear(deathData.killerpos, RESPAWN_RADIUS)
	ClearPedBloodDamage(GetPlayerPed(-1))
end)

function clearBlips()
	for i, blip in ipairs(BLIPS) do
		RemoveBlip(blip)
	end
end

function RespawnNear(deathCoords, radius)
	local death_x, death_y, death_z = table.unpack(deathCoords)
	if (DEBUG_PRINT) then
		print("[DEBUG]: RespawnNear called with deathCoords: [" .. death_x .. ", " .. death_y .. ", " .. death_z .. "], radius: " .. radius)
	end
	local newPos = BACKUP_RESPAWN_POINTS[math.random(1, #BACKUP_RESPAWN_POINTS)]
	local maxIterations = 50
	local counter = 0
	local found = false
	local backups = {}

	if (DEBUG_BLIPS) then
		local blip = AddBlipForCoord(death_x,death_y,death_z)
		BLIPS[#BLIPS+1] = blip
		SetBlipSprite(blip, 1)
		SetBlipColour(blip, 40) -- dark gray
		BeginTextCommandSetBlipName("STRING")
		AddTextComponentString("Death Point")
		EndTextCommandSetBlipName(blip)
	end

	while (not found) and counter < maxIterations do
		for i = 1, 5 do
			local node = GetNthClosestVehicleNodeId(death_x, death_y, death_z, math.random(radius, radius * 3), 1, 300.0, 300.0)
			if node ~= 0 then
				local p = GetVehicleNodePosition(node)
				local newP
				found, newP = GetSafeCoordForPed(p.x, p.y, p.z, false, 16)

				if (DEBUG_BLIPS) then
					local blip = AddBlipForCoord(p.x,p.y,p.z)
					BLIPS[#BLIPS+1] = blip
					SetBlipSprite(blip, 1)
					BeginTextCommandSetBlipName("STRING")
					AddTextComponentString(tostring(counter))
					EndTextCommandSetBlipName(blip)
					if (found) then
						SetBlipColour(blip, 2) -- green
					else
						SetBlipColour(blip, 1) -- red
					end
				end

				if found then
					newPos = newP
					break
				else
					backups[#backups+1] = p
				end
			end
		end

		-- if nothing is found
		if not found then
			if (#backups > 0) then -- try random backups, if any
				newPos = backups[math.random(1, #backups)]
				found = true
				break
			end
		
			-- if backups empty, slowly get closer to the center of the map
			local absX = math.abs(death_x)
			local absY = math.abs(death_y)
			if absX >= absY then 
				death_x = death_x * 0.75
			elseif absY > absX then
				death_y = death_y * 0.75
			end
			if (counter > maxIterations / 2) then
				radius = math.floor(math.max(radius * 0.9, 1))
			end
		end
		counter = counter + 1
	end
	if (DEBUG_PRINT) then
		print("[DEBUG]: Iterations: " .. counter)
		print("[DEBUG]: Final Death Coords: [" .. death_x .. ", " .. death_y .. ", " .. death_z .. "]")
	end

	-- North Yankton check
	if newPos.x > 5000 and newPos.y < -5000 then
		newPos = vector3(1285.0, -3339.0, 6.0) -- Port (nearest Point)
		if (DEBUG_PRINT) then
			print("[DEBUG]: North Yankton detected, teleporting to port...")
		end
	end

	-- check if respawn point is too close to deathCoords, if so call Respawn with higherRadius
	local org_death_x, org_death_y, org_death_z = table.unpack(deathCoords)
	local distance = math.sqrt((org_death_x - newPos.x) ^ 2 + (org_death_y - newPos.y) ^ 2)
	if (DEBUG_PRINT) then
		print("[DEBUG]: Distance to deathCoords: " .. string.format("%.2f", distance))
	end
	if distance < radius then
		RespawnNear(deathCoords, math.ceil(radius * 1.1))
		if (DEBUG_PRINT) then
			print("[DEBUG]: Too close to deathCoords, trying again...")
		end
		return
	end

	if (DEBUG_PRINT) then
		print("[DEBUG]: Respawn coords: [" .. newPos.x .. ", " .. newPos.y .. ", " .. newPos.z .. "]")
	end
	if (DEBUG_BLIPS) then
		local blip = AddBlipForCoord(newPos.x,newPos.y,newPos.z)
		BLIPS[#BLIPS+1] = blip
		SetBlipSprite(blip, 1)
		SetBlipColour(blip, 5) --p
	end
	local playerModel = GetEntityModel(PlayerPedId())
	Respawn(newPos, playerModel)
end

function Respawn(coords, model)
	local newPlayerModel = model or INIT_PLAYER_MODELS[math.random(1, #INIT_PLAYER_MODELS)]
	exports.spawnmanager:setAutoSpawnCallback(function()
		exports.spawnmanager:spawnPlayer({
			x = coords.x,
			y = coords.y,
			z = coords.z,
			model = newPlayerModel
		})
	end)
	exports.spawnmanager:forceRespawn()
end

-- Awaiting scripts workaround
local player = PlayerPedId()
local playerCoords = GetEntityCoords(player)
local playerHeading = GetEntityHeading(player)
local isFalling = IsPedFalling(player)
if playerCoords.x == 0 and playerCoords.y == 0 and playerCoords.z == 1 and playerHeading == 0 and not isFalling then
	local randomBackupPoint = BACKUP_RESPAWN_POINTS[math.random(1, #BACKUP_RESPAWN_POINTS)]
	randomBackupPoint = vector3(randomBackupPoint['x'], randomBackupPoint['y'], randomBackupPoint['z'])
	Respawn(randomBackupPoint)
end

-- Exports
exports("ChangeRespawnType", ChangeRespawnType)
exports("Respawn", Respawn)
exports("RespawnNear", RespawnNear)

-- Debug DELETE BEFORE RELEASE
RegisterCommand("respawn", function(source, args, rawCommand)
	clearBlips()
	RespawnNear(GetEntityCoords(PlayerPedId()), 100)
end, false)
