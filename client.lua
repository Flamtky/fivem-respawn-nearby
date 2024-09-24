RESPAWN_RADIUS = 75     -- default 75 (higher value = more likely to spawn further away from death point)
RESPAWN_DELAY = 5       -- seconds (def. 5)
BACKUP_RESPAWN_POINTS = {
	{ x = 0, y = 0, z = 70 } -- TODO: Expand me
}
INIT_PLAYER_MODELS = {
	"a_m_y_skater_01",
	"a_m_y_skater_02",
	"a_m_y_stbla_01",
	"a_m_y_stbla_02"
} -- TODO: Expand me

BLIPS = {}
DEBUG_PRINT = false
DEBUG_BLIPS = false

-- https://docs.fivem.net/docs/resources/baseevents/events/onPlayerDied/
AddEventHandler('baseevents:onPlayerDied', function(killerType, deathCoords)
	if (deathCoords == nil) then
		deathCoords = GetEntityCoords(PlayerPedId())
	end
	handleDeath(deathCoords)
end)

-- https://docs.fivem.net/docs/resources/baseevents/events/onPlayerKilled/
AddEventHandler('baseevents:onPlayerKilled', function(killerId, deathData)
	if (deathData.deathCoords == nil) then
		deathData.deathCoords = GetEntityCoords(PlayerPedId())
	end
	handleDeath(deathData.deathCoords)
end)

function handleDeath(deathCoords)
	clearBlips()
	Wait(RESPAWN_DELAY * 1000)
	DoScreenFadeOut(500);
	while not IsScreenFadedOut() do
		Wait(0)
	end
	local respawnCoords = GetRespawnCoords(deathCoords, RESPAWN_RADIUS, 0)
	Respawn(respawnCoords)
	ClearPedBloodDamage(GetPlayerPed(-1))
end

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

function printDebug(text)
	if (DEBUG_PRINT) then
		print("[DEBUG]: " .. text)
	end
end

function GetRespawnCoords(deathCoords, radius, _depth)
	local playerModel = GetEntityModel(PlayerPedId())
	if (_depth > 10) then
		print("[ERROR]: Max depth reached, aborting GetRespawnCoords")
		Respawn(BACKUP_RESPAWN_POINTS[math.random(1, #BACKUP_RESPAWN_POINTS)], 0, playerModel)
		return
	end

	local death_x, death_y, death_z = table.unpack(deathCoords)
	printDebug("GetRespawnCoords called with deathCoords: [" .. death_x .. ", " .. death_y .. ", " .. death_z .. "], radius: " .. radius)
	local newPos = BACKUP_RESPAWN_POINTS[math.random(1, #BACKUP_RESPAWN_POINTS)]
	local newRot = math.random(0, 360)
	local maxIterations = 50
	local counter = 0
	local footpath_found = false
	local backups = {}

	showBlipIfDebug(deathCoords, 40, "Death Point") -- dark gray

	while (not footpath_found) and counter < maxIterations do

		local possibleSpawns = {}
		local nOffset = math.random(1, radius)
		for i = 1, 20 do
			local foundNode, nodePos = GetNthClosestVehicleNode(death_x, death_y, death_z, nOffset + (i-1), 1, 3, 0)
			if foundNode then				
				-- save node and grouped by density
				local succ, density, _flags = GetVehicleNodeProperties(nodePos.x, nodePos.y, nodePos.z)
				if (succ) then
					if not possibleSpawns[density] then
						possibleSpawns[density] = {}
					end
					possibleSpawns[density][#possibleSpawns[density]+1] = nodePos
				end
			end
		end

		if (next(possibleSpawns) ~= nil) then
			print("[DEBUG]: Possible spawns found: " .. #possibleSpawns)
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

						local onGround, _ = GetGroundZFor_3dCoord(footpathPos.x, footpathPos.y, footpathPos.z, 0)
						if (succ) then
							showBlipIfDebug(footpathPos, 2, "Footpath (onGround: " .. tostring(onGround) .. ")") -- green
							if (onGround) then
								footpath_found = true
								newPos = footpathPos
								newRot = GetHeadingFromVector_2d(footpathPos.x - possibleSpawn.x, footpathPos.y - possibleSpawn.y) -- face towards road
							end
						else
							showBlipIfDebug(possibleSpawn, 3, "Backup (onGround: " .. tostring(onGround) .. ")") -- blue
							if (onGround) then
								backups[#backups+1] = possibleSpawn
							end
						end
					end
				end
			end

			if (footpath_found) then
				break
			end
		end

		if (#backups > 0) then -- if no footpath found, use backup
			newPos = backups[1]
			footpath_found = true
			showBlipIfDebug(newPos, 3, "Backup") -- blue
			printDebug("Backup used")
		end

		if (footpath_found) then
			break
		end

		-- if backups empty or no safe point found, slowly get closer to the center of the map and try again
		local newDeath_x, newDeath_y = death_x, death_y	
		if (death_x > 0) then
			newDeath_x = math.max(death_x - 250, 0)
		else
			newDeath_x = math.min(death_x + 250, 0)
		end

		if (death_y > 0) then
			newDeath_y = math.max(death_y - 250, 0)
		else
			newDeath_y = math.min(death_y + 250, 0)
		end

		local newDeath_z = death_z
		for zz = 950, 0, -25 do
			local z = zz
			
			if (z % 2 == 1) then
				z = 950 - zz -- search each 2nd iteration from the bottom instead from the top
			end
	
			SetFocusPosAndVel(newDeath_x, newDeath_y, z, 0, 0, 0)
	
			local startTime = GetGameTimer()
			if NewLoadSceneStart(newDeath_x, newDeath_y, z, 0, 0, 0, 50.0, 0) then
				while not IsNewLoadSceneLoaded() and GetGameTimer() - startTime < 3000 do
					Wait(0)
				end
				ClearFocus()
				NewLoadSceneStop()
	
				SetEntityCoords(PlayerPedId(), newDeath_x, newDeath_y, z, false, false, false, true)
	
				startTime = GetGameTimer()
				while not HasCollisionLoadedAroundEntity(PlayerPedId()) and GetGameTimer() - startTime < 1000 do
					Wait(0)
				end
	
				hasGround, _ = GetGroundZFor_3dCoord(newDeath_x, newDeath_y, z, 0)
				if (hasGround) then
					newDeath_z = z
					break
				end
			end
		end

		death_x, death_y, death_z = newDeath_x, newDeath_y, newDeath_z

		if (counter > maxIterations / 2) then
			radius = math.floor(math.max(radius * 0.9, 1))
		end

		printDebug("No nodes found, trying again with going closer to center...")
		printDebug("New Death Coords: [" .. death_x .. ", " .. death_y .. ", " .. death_z .. "]")
		printDebug("New Radius: " .. radius)
		local densString = ""
		if (#possibleSpawns > 0) then
			for k, v in pairs(possibleSpawns) do
				densString = densString .. k .. ":" .. #v .. ", "
			end
		else
			densString = "Empty"
		end
		printDebug("Densities: " .. densString)

		showBlipIfDebug(vector3(death_x, death_y, death_z), 40, "New Death Coords (going closer)") -- dark gray

		counter = counter + 1
	end

	printDebug("-----------------------------------")
	printDebug("Iterations: " .. counter)
	printDebug("Final Death Coords: [" .. death_x .. ", " .. death_y .. ", " .. death_z .. "]")

	-- check if respawn point is too close to deathCoords, if so call GetRespawnCoords with higherRadius
	local org_death_x, org_death_y, org_death_z = table.unpack(deathCoords)
	local distance = math.sqrt((org_death_x - newPos.x) ^ 2 + (org_death_y - newPos.y) ^ 2)
	printDebug("Distance to deathCoords: " .. string.format("%.2f", distance))
	counter = 1
	local onGround = false
	while distance < RESPAWN_RADIUS and counter+1 < #backups and not onGround do
		printDebug("Too close to deathCoords, trying backups...")
		showBlipIfDebug(death_x, death_y, death_z, 1, "Too Close") -- red

		counter = counter + 1
		newPos = backups[counter]
		distance = math.sqrt((org_death_x - newPos.x) ^ 2 + (org_death_y - newPos.y) ^ 2)
		onGround, _ = GetGroundZFor_3dCoord(newPos.x, newPos.y, newPos.z, 0)
	end

	if (distance < RESPAWN_RADIUS) then
		printDebug("Still too close to deathCoords, trying again with higher radius...")
		
		return GetRespawnCoords(deathCoords, math.ceil(radius * 1.1), _depth + 1)
	end

	printDebug("Respawn coords: [" .. newPos.x .. ", " .. newPos.y .. ", " .. newPos.z .. "]")
	showBlipIfDebug(newPos, 5, "Respawn Point") -- yellow

	return newPos, newRot, playerModel
end

function Respawn(coords, rot, model)
	local newPlayerModel = model or INIT_PLAYER_MODELS[math.random(1, #INIT_PLAYER_MODELS)]
	exports.spawnmanager:spawnPlayer({
		x = coords.x,
		y = coords.y,
		z = coords.z,
		heading = rot,
		model = newPlayerModel
	})
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

-- Disable auto spawn
exports.spawnmanager:setAutoSpawn(false)

-- Exports
exports("Respawn", Respawn)
exports("GetRespawnCoords", GetRespawnCoords)

Respawn(GetEntityCoords(PlayerPedId()), GetEntityHeading(PlayerPedId()), GetEntityModel(PlayerPedId()))