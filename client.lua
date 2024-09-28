RESPAWN_RADIUS = 75     -- default 75 (higher value = further away + its the min distance from death point)
RESPAWN_DELAY = 5       -- seconds (default 5)
BACKUP_RESPAWN_POINTS = { -- only if no nodes found at all or initial spawn
	{ x = 0, y = 0, z = 70 } -- TODO: Expand me
}
INIT_PLAYER_MODELS = {
	"a_m_y_skater_01",
	"a_m_y_skater_02",
	"a_m_y_stbla_01",
	"a_m_y_stbla_02"
} -- TODO: Expand me

CLOSER_STEPS = 200 -- how much closer to go if no nodes found (default 200)
BATCH_SIZE = 30 -- how many nodes to check per death (default 30) (higher value = higher chance of finding a node but slower)
BLIPS = {}
DEBUG_PRINT = false
DEBUG_BLIPS = false

LastDeathCoords = vector3(0, 0, 0)

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

-- UTILITY METHODS --

function handleDeath(deathCoords)
	clearBlips()
	Wait(RESPAWN_DELAY * 1000)
	DoScreenFadeOut(500);
	while not IsScreenFadedOut() do
		Wait(0)
	end

	if type(deathCoords) == 'table' then
		if #deathCoords == 3 then
			deathCoords = vector3(deathCoords[1], deathCoords[2], deathCoords[3])
		elseif deathCoords.x and deathCoords.y and deathCoords.z then
			deathCoords = vector3(deathCoords.x, deathCoords.y, deathCoords.z)
		else
			printDebug("[ERROR]: Invalid coords. Expected table with keys x, y, z or a list with 3 elements.")
			printDebug("-- Got: " .. json.encode(deathCoords) .. " (type: " .. type(deathCoords) .. ")")
			return
		end
	elseif type(deathCoords) ~= 'vector3' then
		printDebug("[ERROR]: Invalid coords. Expected table or vector3.")
		printDebug("-- Got: " .. json.encode(deathCoords) .. " (type: " .. type(deathCoords) .. ")")
		return
	end

	local respawnCoords, respawnHeading, playerModel = GetRespawnCoords(deathCoords, RESPAWN_RADIUS, 0)
	Respawn(respawnCoords, respawnHeading, playerModel)
	ClearPedBloodDamage(GetPlayerPed(-1))
end

function getFallBack()
	return BACKUP_RESPAWN_POINTS[math.random(1, #BACKUP_RESPAWN_POINTS)], math.random(0, 360)
end

function getSafeCoordForPed(x, y, z)
	local succ, footpathPos = GetSafeCoordForPed(x, y, z, false, 1)
	if (not succ) then
		succ, footpathPos = GetSafeCoordForPed(x, y, z, false, 16)
	end
	if (not succ) then
		return false, vector3(0, 0, 0)
	end
	local onGround, _ = GetGroundZFor_3dCoord(footpathPos.x, footpathPos.y, footpathPos.z, 0)
	if (not onGround) then
		return false, vector3(0, 0, 0)
	end
	local succ, _dens, flags = GetVehicleNodeProperties(x, y, z)
	if (flags == 66) then -- 66 = freeway (dont spawn on freeway)
		return false, vector3(0, 0, 0)
	end
	return true, footpathPos
end

function useBackup(backups)
	if (not backups or #backups == 0) then
		return false, {}
	end

	local newSpawn = { pos = backups[1], heading = 0 }
	local succ, _, heading = GetClosestVehicleNodeWithHeading(newSpawn.pos.x, newSpawn.pos.y, newSpawn.pos.z, 1, 3, 0)
	if (not succ) then
		return false, {}
	end
	-- offset player 90 degrees by 20 units
	newSpawn.heading = heading + math.pi / 2
	newSpawn.pos = vector3(newSpawn.pos.x + math.cos(newSpawn.heading) * 20, newSpawn.pos.y + math.sin(newSpawn.heading) * 20, newSpawn.pos.z)

	showBlipIfDebug(newSpawn.pos, 3, "Backup") -- blue
	printDebug("Backup used")

	return true, newSpawn
end

function isValidCoords(coords)
	if (type(coords) == 'vector3') then
		return true
	end
	printDebug("[ERROR]: Invalid coords. Expected vector3.")
	printDebug("-- Got: " .. json.encode(coords) .. " (type: " .. type(coords) .. ")")
	return false
end

function getPossibleSpawns(deathCoords, radius)
	if (not isValidCoords(deathCoords)) then
		return false, {}
	end

	local deathX, deathY, deathZ = table.unpack(deathCoords)
	local possibleSpawns = {}
	local nOffset = math.random(1, radius)
	for i = 1, BATCH_SIZE do
		local foundNode, nodePos = GetNthClosestVehicleNode(deathX, deathY, deathZ, nOffset + (i-1), 1, 3, 0)
		if not foundNode then
			goto continue
		end
		local succ, density, _ = GetVehicleNodeProperties(nodePos.x, nodePos.y, nodePos.z)
		if (not succ) then
			goto continue
		end
		if (not possibleSpawns[density]) then
			possibleSpawns[density] = {}
		end
		possibleSpawns[density][#possibleSpawns[density]+1] = nodePos
		::continue::
	end
	return true, possibleSpawns
end

function moveCloser(deathCoords)
	if (not isValidCoords(deathCoords)) then
		return false, vector3(0, 0, 0)
	end

	local death_x, death_y, death_z = table.unpack(deathCoords)
	local newDeath_x, newDeath_y = death_x, death_y
	if (death_x > 0) then
		newDeath_x = math.max(death_x - CLOSER_STEPS, 0)
	else
		newDeath_x = math.min(death_x + CLOSER_STEPS, 0)
	end

	if (death_y > 0) then
		newDeath_y = math.max(death_y - CLOSER_STEPS, 0)
	else
		newDeath_y = math.min(death_y + CLOSER_STEPS, 0)
	end

	local newDeath_z = death_z
	local UPPER_BOUND = 750
	local STEP = 35
	for zz = UPPER_BOUND, 0, -STEP do
		local z = zz
		
		if (z % 2 == 1) then
			z = UPPER_BOUND - zz -- search each 2nd iteration from the bottom instead from the top
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

			local hasGround, _ = GetGroundZFor_3dCoord(newDeath_x, newDeath_y, z, 0)
			if (hasGround) then
				newDeath_z = z
				break
			end
		end
	end
	return true, vector3(newDeath_x, newDeath_y, newDeath_z)
end

function getBestPossibleSpawnOrGoCloser(possibleSpawns, densities, deathCoords)
	if (LastDeathCoords == vector3(0, 0, 0)) then
		LastDeathCoords = deathCoords
	end

	local newSpawn = { pos = deathCoords, heading = math.random(0, 360) }
	local needToGoCloser, closerDeathCoords = false, deathCoords
	local backups = {}
	local found = false
	for i = 1, #densities do
		local density = densities[i]
		local spawns = possibleSpawns[density]
		if (#spawns == 0) then
			goto continue
		end

		for j = 1, #spawns do
			local possibleSpawn = spawns[j]
			local succ, footpathPos = getSafeCoordForPed(possibleSpawn.x, possibleSpawn.y, possibleSpawn.z)
			local distance = math.sqrt((LastDeathCoords.x - possibleSpawn.x) ^ 2 + (LastDeathCoords.y - possibleSpawn.y) ^ 2)
			if (distance < RESPAWN_RADIUS) then
				goto continue
			end
			local onGround, _ = GetGroundZFor_3dCoord(footpathPos.x, footpathPos.y, footpathPos.z, 0)
			if (not onGround) then
				showBlipIfDebug(possibleSpawn, 1, "Not on Ground") -- red
				goto continue
			end
			if (succ) then
				showBlipIfDebug(footpathPos, 2, "Footpath")
				newSpawn.pos = footpathPos
				newSpawn.heading = GetHeadingFromVector_2d(footpathPos.x - possibleSpawn.x, footpathPos.y - possibleSpawn.y) -- face towards road
				found = true
				if (math.random() < 0.05) then -- 5% chance to use the current spawn
					goto continue
				end
			else
				showBlipIfDebug(possibleSpawn, 3, "Backup")
				backups[#backups+1] = possibleSpawn
			end
		end
		::continue::
	end

	if (not found) then -- if no footpath found, use backup
		local succ, backup = useBackup(backups)
		if (not succ) then
			local succ, coords = moveCloser(deathCoords)
			if (succ) then
				needToGoCloser = true
				closerDeathCoords = coords
			end
			newSpawn = backup
		end
	end
	return needToGoCloser, closerDeathCoords, newSpawn
end

-- END UTILITY METHODS --
-- DEBUGGING METHODS --

function clearBlips()
	for i, blip in ipairs(BLIPS) do
		RemoveBlip(blip)
	end
end

function showBlipIfDebug(coords, color, text)
	if (not DEBUG_BLIPS) then
		return
	end

	if type(coords) ~= 'vector3' and type(coords) ~= 'table' then
		printDebug("[ERROR]: Bad argument for unpack. Expected vector3 or table.")
		printDebug("Coords: " .. json.encode(coords) .. " (type: " .. type(coords) .. ")")
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
	if type(text) == 'table' then
		text = json.encode(text)
	end
	if (DEBUG_PRINT) then
		print("[DEBUG]: " .. text)
	end
end

-- END DEBUGGING METHODS --

-- MAIN METHODS --

function GetRespawnCoords(deathCoords, radius, _depth)
	local playerModel = GetEntityModel(PlayerPedId())
	if (_depth > 10) then
		print("[ERROR]: Max depth reached, aborting GetRespawnCoords")
		local backupCoords, backupHeading = getFallBack()
		return backupCoords, backupHeading, playerModel
	end
	printDebug("GetRespawnCoords called with deathCoords: "..json.encode(deathCoords)..", radius: " .. radius)
	local MAX_ITERATIONS = 50
	local counter = 0
	local newSpawn = nil
	showBlipIfDebug(deathCoords, 40, "Death Point") -- dark gray

	while (newSpawn == nil and counter < MAX_ITERATIONS) do
		local succ, possibleSpawns = getPossibleSpawns(deathCoords, radius)
		if (not succ) then
			break
		end

		-- sort densities ascending
		local densities = {}
		for k, _ in pairs(possibleSpawns) do
			densities[#densities+1] = k
		end
		table.sort(densities)

		-- try each density to find a safe coord or backup
		-- bestSpawn {x, y, z, heading}
		local needToGoCloser, closerDeathCoords, bestSpawn = getBestPossibleSpawnOrGoCloser(possibleSpawns, densities, deathCoords, deathCoords)
		if (not needToGoCloser) then
			newSpawn = bestSpawn -- not going closer, found a spawn
			break
		else
			if (counter % 2 == 1) then
				deathCoords = closerDeathCoords
				printDebug("No nodes found, trying again with going closer to center...")
				showBlipIfDebug(deathCoords, 40, "New Death Coords (going closer)") -- dark gray
			else
				radius = RESPAWN_RADIUS * 2
				printDebug("No nodes found, trying again with bigger radius...")
			end
		end

		counter = counter + 1
	end
	if (newSpawn == nil) then
		printDebug("No spawn found at all, using random fallback")
		local backupCoords, backupHeading = getFallBack()
		newSpawn = { pos = backupCoords, heading = backupHeading }
	end

	printDebug("-----------------------------------")
	printDebug("Iterations: " .. counter)

	printDebug("Respawn coords: [" .. newSpawn.pos.x .. ", " .. newSpawn.pos.y .. ", " .. newSpawn.pos.z .. "]")
	printDebug("Respawn heading: " .. newSpawn.heading)
	showBlipIfDebug(newSpawn.pos, 5, "Respawn Point") -- yellow

	return newSpawn.pos, newSpawn.heading, playerModel
end

function Respawn(coords, rot, model)
	local newPlayerModel = model or INIT_PLAYER_MODELS[math.random(1, #INIT_PLAYER_MODELS)]
	printDebug("Respawn called with coords: " .. json.encode(coords) .. ", rot: " .. rot .. ", model: " .. newPlayerModel)
	exports.spawnmanager:spawnPlayer({
		x = coords.x,
		y = coords.y,
		z = coords.z,
		heading = rot,
		model = newPlayerModel
	})
	LastDeathCoords = vector3(0, 0, 0)
end

-- END MAIN METHODS --

-- Awaiting scripts workaround
local player = PlayerPedId()
local playerCoords = GetEntityCoords(player)
local playerHeading = GetEntityHeading(player)
local isFalling = IsPedFalling(player)
if playerCoords.x == 0 and playerCoords.y == 0 and playerCoords.z == 1 and playerHeading == 0 and not isFalling then
	local randomBackupPoint = BACKUP_RESPAWN_POINTS[math.random(1, #BACKUP_RESPAWN_POINTS)]
	randomBackupPoint = vector3(randomBackupPoint['x'], randomBackupPoint['y'], randomBackupPoint['z'])
	Respawn(randomBackupPoint, 0, false)
elseif GetEntityHealth(player) <= 0 then
	handleDeath(playerCoords)
end
	
-- Disable auto spawn
exports.spawnmanager:setAutoSpawn(false)

-- Exports
exports("Respawn", Respawn)
exports("GetRespawnCoords", GetRespawnCoords)
