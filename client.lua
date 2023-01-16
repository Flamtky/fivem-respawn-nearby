NODE_TYPE_RESPAWN = 1 -- 0 asphalt, 1 any road
RESPAWN_RADIUS = 75 -- default 200
RESPAWN_DELAY = 5 -- seconds (def. 5)
BACKUP_RESPAWN_POINTS = {
	{x = 0, y = 0, z = 70}
}

DEBUG_PRINT = false
-- https://docs.fivem.net/docs/resources/baseevents/events/onPlayerDied/
AddEventHandler('baseevents:onPlayerDied', function(killerType, deathCoords)
	exports.spawnmanager:setAutoSpawn(false)
	Wait(RESPAWN_DELAY * 1000)
	RespawnNear(deathCoords, RESPAWN_RADIUS)
	ClearPedBloodDamage(GetPlayerPed(-1))
end)

-- https://docs.fivem.net/docs/resources/baseevents/events/onPlayerKilled/
AddEventHandler('baseevents:onPlayerKilled', function(killerId, deathData)
	exports.spawnmanager:setAutoSpawn(false)
	Wait(RESPAWN_DELAY * 1000)
	RespawnNear(deathData.killerpos, RESPAWN_RADIUS)
	ClearPedBloodDamage(GetPlayerPed(-1))
end)

function RespawnNear(deathCoords, radius)
	local death_x, death_y, death_z = table.unpack(deathCoords)
	local newPos = BACKUP_RESPAWN_POINTS[math.random(1, #BACKUP_RESPAWN_POINTS)]
	local lowerOffset = radius
	local higherOffset = radius*3

	local maxIterations = 20
	local maxIterationsBackup = 500
	local node = GetNthClosestVehicleNodeId(death_x,death_y,death_z, math.random(lowerOffset, higherOffset), NODE_TYPE_RESPAWN, 300.0, 300.0)
	local counter = 0
	
	local colors = {0,1,2,3,7,8,25,27,29,40,5,17} -- for debug blips https://docs.fivem.net/docs/game-references/hud-colors/

	local lowerOffTemp = lowerOffset
	local heigherOffTemp = higherOffset
	local x, y, z = death_x, death_y, death_z
	while node == 0 do -- should only happen far in the water or some mountains/beaches
		if counter == maxIterations then
			break
		end
		local absX = math.abs(death_x)
		local absY = math.abs(death_y)
		if absX >= absY then -- slowly get closer back to the island/back to the roads/paths
			death_x = death_x * 0.9
		elseif absY > absX then
			death_y = death_y * 0.9
		end
		lowerOffTemp = math.floor(lowerOffTemp/4)
		heigherOffTemp = math.floor(heigherOffTemp/4)
		node = GetNthClosestVehicleNodeId(death_x,death_y,death_z, math.random(lowerOffTemp, heigherOffTemp), NODE_TYPE_RESPAWN, 300.0, 300.0)
		counter = counter + 1
	end

	counter = 0
	local found, sidewalk
	local bestPoint = {den=15, pos=newPos}
	
	repeat
		if node == 0 then
			break
		end
		newPos = GetVehicleNodePosition(node)
		if (counter > 0) then
			if (counter % 10 == 0) then
				node = GetNthClosestVehicleNodeId(death_x,death_y,death_z, math.random(lowerOffset, higherOffset), NODE_TYPE_RESPAWN, 300.0, 300.0)
			else
				node = GetNthClosestVehicleNodeId(newPos.x, newPos.y, newPos.z, counter % 10 + 1, 1, 300.0, 300.0)
			end
			if (DEBUG_PRINT) then
				lastBlip = AddBlipForCoord(newPos.x, newPos.y, newPos.z)
				SetBlipSprite(lastBlip, 1)
			end
			local ret, den, flags = GetVehicleNodeProperties(newPos.x, newPos.y, newPos.z)
			if (flags & (1 << (4 - 1)) ~= 0) then
				bestPoint.den = 0
				bestPoint.pos = newPos
				if (DEBUG_PRINT) then
					SetBlipColour(lastBlip, colors[11]) -- yellow/gold == best
				end
			elseif bestPoint.den > den or (bestPoint.den == den and math.random(1,2) == 1) then
				bestPoint.den = den
				bestPoint.pos = newPos
				if (DEBUG_PRINT) then
					-- maybe for later priority system? The lower the den the better the road (less cars)?
					if den <= 1 then
						SetBlipColour(lastBlip, colors[3]) -- green == good
					elseif den < 3 then
						SetBlipColour(lastBlip, colors[4]) -- blue == ok
					else
						SetBlipColour(lastBlip, colors[12]) -- orange == meh
					end
				end
			else
				if (DEBUG_PRINT) then
					SetBlipColour(lastBlip, colors[2]) -- red == bad (Highways, Main roads)
				end
			end	
		end
		found, sidewalk = GetSafeCoordForPed(newPos.x, newPos.y, newPos.z, true, 16) -- walkway (best possible spawn)
		
		counter = counter+1
	until (found  or counter >= maxIterationsBackup)
	
	if not found then -- if not SafeCoordForPed(walkway (only in city?))) found, set best backup point
		sidewalk = bestPoint.pos
	end
	-- Check if North Yankton area, if so respawn at backup point to prevent respawn in water
	-- TODO: maybe add check to see if north yankton is loaded
	if sidewalk.x > 5000 and sidewalk.y < -5000 then
		sidewalk = vector3(1285.0, -3339.0, 6.0) -- Port (nearest Point)
	end
	
	-- check if sidewalk is too close to deathCoords, if so call Respawn with higherRadius
	local distance = (death_x - sidewalk.x)^2 + (death_y - sidewalk.y)^2
	if #(deathCoords - sidewalk) < 10000 then
		Respawn(sidewalk, radius*2)
		return
	end

	Respawn(sidewalk)
end

function Respawn(coords)
	exports.spawnmanager:setAutoSpawnCallback(function()
        exports.spawnmanager:spawnPlayer({
            x = coords.x,
            y = coords.y,
            z = coords.z
        })
    end)
    exports.spawnmanager:setAutoSpawn(true)
    exports.spawnmanager:forceRespawn()
end

-- Commands to change the respawnType
-- expects 1 or 2 ("main", "any")
-- 0 = Backups only on big roads with asphalt
-- 2 = Any path or road (recommended)

RegisterCommand("respawnType", function(source, args, rawCommand)
	ChangeRespawnType(args[1])
end, false)

RegisterCommand("rt", function(source, args, rawCommand)
	ChangeRespawnType(args[1])
end, false)

function ChangeRespawnType(type)
	if type == "main" then
		NODE_TYPE_RESPAWN = 0
	elseif type == "any" then
		NODE_TYPE_RESPAWN = 1
	else
		-- if number set directly
		if tonumber(type) then
			NODE_TYPE_RESPAWN = tonumber(type)
		end
	end
end

exports("ChangeRespawnType", ChangeRespawnType)
exports("Respawn", Respawn)
exports("RespawnNear", RespawnNear)
