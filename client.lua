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
DEBUG_PRINT = false
DEBUG_BLIPS = false

-- https://docs.fivem.net/docs/resources/baseevents/events/onPlayerDied/
AddEventHandler('baseevents:onPlayerDied', function(killerType, deathCoords)
	clearBlips()
	exports.spawnmanager:setAutoSpawn(false)
	Wait(RESPAWN_DELAY * 1000)
	RespawnNear(deathCoords, RESPAWN_RADIUS, 0)
	ClearPedBloodDamage(GetPlayerPed(-1))
end)

-- https://docs.fivem.net/docs/resources/baseevents/events/onPlayerKilled/
AddEventHandler('baseevents:onPlayerKilled', function(killerId, deathData)
	clearBlips()
	exports.spawnmanager:setAutoSpawn(false)
	Wait(RESPAWN_DELAY * 1000)
	RespawnNear(deathData.deathCoords, RESPAWN_RADIUS, 0)
	ClearPedBloodDamage(GetPlayerPed(-1))
end)

function clearBlips()
	for i, blip in ipairs(BLIPS) do
		RemoveBlip(blip)
	end
end

function showBlipIfDebug(coords, color, text)
	if (not DEBUG_BLIPS) then
		return
	end

	local coord_x, coord_y, coord_z = table.unpack(coords)
	local blip = AddBlipForCoord(coord_x, coord_y, coord_z)
	BLIPS[#BLIPS+1] = blip
	SetBlipSprite(blip, 1)
	SetBlipColour(blip, color)
	BeginTextCommandSetBlipName("STRING")
	AddTextComponentString(tostring(text))
	EndTextCommandSetBlipName(blip)
end

function RespawnNear(deathCoords, radius, _depth)
	local playerModel = GetEntityModel(PlayerPedId())
	if (_depth > 10) then
		print("[ERROR]: Max depth reached, aborting RespawnNear")
		Respawn(BACKUP_RESPAWN_POINTS[math.random(1, #BACKUP_RESPAWN_POINTS)], 0, playerModel)
		return
	end

	local death_x, death_y, death_z = table.unpack(deathCoords)
	if (DEBUG_PRINT) then
		print("[DEBUG]: RespawnNear called with deathCoords: [" .. death_x .. ", " .. death_y .. ", " .. death_z .. "], radius: " .. radius)
	end
	local newPos = BACKUP_RESPAWN_POINTS[math.random(1, #BACKUP_RESPAWN_POINTS)]
	local newRot = math.random(0, 360)
	local maxIterations = 50
	local counter = 0
	local footpath_found = false
	local backups = {}

	showBlipIfDebug(deathCoords, 40, "Death Point") -- dark gray

	while (not footpath_found) and counter < maxIterations do

		local possibleSpawns = {}
		for _i = 1, 20 do
			local closeNode = GetNthClosestVehicleNodeId(death_x, death_y, death_z, math.random(0, radius), 1, 300.0, 300.0)
			if closeNode ~= 0 then
				local roadNodePos = GetVehicleNodePosition(closeNode)

				-- save node and grouped by density
				local succ, density, _flags = GetVehicleNodeProperties(roadNodePos.x, roadNodePos.y, roadNodePos.z)
				if (succ) then
					if not possibleSpawns[density] then
						possibleSpawns[density] = {}
					end
					possibleSpawns[density][#possibleSpawns[density]+1] = roadNodePos
				end
			end
		end

		if (#possibleSpawns > 0) then
			-- if any possibleSpawns found, choose the one with lowest density but only if a safe coord was found (footpath)
			local densities = {}
			for k, v in pairs(possibleSpawns) do
				densities[#densities+1] = k
			end

			table.sort(densities)

			for i = 1, #densities do
				local density = densities[i]
				local spawns = possibleSpawns[density]
				if (#spawns > 0) then
					for j = 1, #spawns do
						local possibleSpawn = spawns[j]
						local succ, footpathPos = GetSafeCoordForPed(possibleSpawn.x, possibleSpawn.y, possibleSpawn.z, false, 1)
						if (not succ) then
							succ, footpathPos = GetSafeCoordForPed(possibleSpawn.x, possibleSpawn.y, possibleSpawn.z, false, 16)
						end

						if (succ) then
							footpath_found = true
							newPos = footpathPos
							newRot = GetHeadingFromVector_2d(footpathPos.x - possibleSpawn.x, footpathPos.y - possibleSpawn.y) -- face towards road
							showBlipIfDebug(footpathPos, 2, "Footpath") -- green
						else
							backups[#backups+1] = possibleSpawn
							showBlipIfDebug(possibleSpawn, 3, "Backup") -- blue
						end
					end
				end
			end

			if (footpath_found) then
				break
			end
		end

		if (#backups > 0) then -- if no footpath found, use backup
			newPos = backups[1] -- take first (lowest density) backup
			footpath_found = true
			if (DEBUG_PRINT) then
				print("[DEBUG]: Backup used")
			end
			break
		else 
			-- if backups empty, slowly get closer to the center of the map and try again
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

			if (DEBUG_PRINT) then
				print("[DEBUG]: No nodes found, trying again with goint closer to center...")
				print("[DEBUG]: New Death Coords: [" .. death_x .. ", " .. death_y .. ", " .. death_z .. "]")
				print("[DEBUG]: New Radius: " .. radius)
			end
		end
		counter = counter + 1
	end
	if (DEBUG_PRINT) then
		print("[DEBUG]: Iterations: " .. counter)
		print("[DEBUG]: Final Death Coords: [" .. death_x .. ", " .. death_y .. ", " .. death_z .. "]")
	end

	-- North Yankton check (TODO: Check if north yankton is loaded)
	if newPos.x > 2750 and newPos.y < -4500 then
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
	counter = 1
	while distance < RESPAWN_RADIUS and counter+1 < #backups do
		if (DEBUG_PRINT) then
			print("[DEBUG]: Too close to deathCoords, trying backups...")
		end
		showBlipIfDebug(newPos, 1, "Too Close") -- red

		counter = counter + 1
		newPos = backups[counter]
		distance = math.sqrt((org_death_x - newPos.x) ^ 2 + (org_death_y - newPos.y) ^ 2)
	end

	if (distance < RESPAWN_RADIUS) then
		if (DEBUG_PRINT) then
			print("[DEBUG]: Still too close to deathCoords, trying again with higher radius...")
		end
		RespawnNear(deathCoords, math.ceil(radius * 1.1), _depth + 1)
		return
	end
	if (DEBUG_PRINT) then
		print("[DEBUG]: Respawn coords: [" .. newPos.x .. ", " .. newPos.y .. ", " .. newPos.z .. "]")
	end

	showBlipIfDebug(newPos, 5, "Respawn Point") -- yellow
	Respawn(newPos, newRot, playerModel)
end

function Respawn(coords, rot, model)
	local newPlayerModel = model or INIT_PLAYER_MODELS[math.random(1, #INIT_PLAYER_MODELS)]
	exports.spawnmanager:setAutoSpawnCallback(function()
		exports.spawnmanager:spawnPlayer({
			x = coords.x,
			y = coords.y,
			z = coords.z,
			heading = rot,
			model = newPlayerModel
		})
	end)
	exports.spawnmanager:forceRespawn()
end

-- Awaiting scripts workaround
if not NetworkIsPlayerActive(PlayerId()) then -- If the player is not active, respawn them at a random backup point (initial spawn)
	local randomBackupPoint = BACKUP_RESPAWN_POINTS[math.random(1, #BACKUP_RESPAWN_POINTS)]
	randomBackupPoint = vector3(randomBackupPoint['x'], randomBackupPoint['y'], randomBackupPoint['z'])
	Respawn(randomBackupPoint)
end

-- Exports
exports("Respawn", Respawn)
exports("RespawnNear", RespawnNear)
