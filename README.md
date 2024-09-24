# FiveM Nearby Respawn System

This script tries to revive a player near a "safe" location. The goal is to create a respawn that works similar to GTA5 Online. Currently it should work 99.9% of the time.
1. The script gathers 20 potential spawn locations near the player's death coordinates and groups them by traffic density, it only considers nodes that are on the ground (for the client side)
2. The script evaluates the traffic density of each potential spawn location and prioritizes those with lower traffic density.
3. For each potential spawn location, the script checks if it can find a safe spot for the player to respawn, looking for safe coordinates for pedestrians.
4. If a safe pedestrian path is not found, the script saves the location as a backup option for later consideration.
5. The script selects the best spawn location based on the lowest traffic density and availability of a safe pedestrian path, defaulting to a backup if necessary.
6. If no suitable spawn point is found within a certain number of attempts, the script adjusts the search parameters by moving closer to the center of the map. Up to 50 attempts are made to find a suitable spawn point.
7. The script checks if the selected location is too close to the player's death coordinates and tries all other backup locations if necessary.
8. If the script can't find a suitable respawn point after all attempts, it recursively calls itself with a larger search radius and increased depth control to avoid infinite loops (up to 10 recursive calls).
10. Once a suitable location is found, the script respawns the player at this location with the appropriate orientation, ensuring the player faces towards the road. If no suitable location is found, the player respawns at (0, 0, 70) (This list of backup locations can be expanded in `client.lua`).

Debug Prints and Blips are also available, by changing the bools in `client.lua`.

## Screenshots:
<img src="https://github.com/Flamtky/fivem-respawn-nearby/assets/68606032/d2a987e1-db4d-4aed-829f-e4a2638de275" width="360" />
<img src="https://github.com/Flamtky/fivem-respawn-nearby/assets/68606032/96647d78-70d0-4ea2-ab6e-99f4c12a2099" width="240" /><br>
<img src="https://github.com/Flamtky/fivem-respawn-nearby/assets/68606032/4a1823ae-4fd3-43cb-a9e8-e6a82849879e" width="360" />
<img src="https://github.com/Flamtky/fivem-respawn-nearby/assets/68606032/e2ec91c0-d130-4cab-96e9-06951132402e" width="360" />

| Color       |  Meaning |
|-------------|----------|
| Dark gray   | Death Point or new Death Point(s) (if the player died outside of the map) |
| Yellow/Gold | Respawn Point |
| Green       | Safe Respawn Point (Footpath, Walkway, etc.) |
| Blue        | Backup Respawn Point (Roads with no footpaths, high density roads) |
| Red         | Too close to the Death Point |

## Installation:
1. Download this repository and extract it to your resources folder. **NOTE:** This script requires the `spawnmanager` resource to be running. E.g. the folder structure should look like this:
    ```
    [resources]
        -> [fivem-respawn-nearby]
            -> [client.lua]
            ...
    ```
2. Add `ensure nearby-respawn` to your server.cfg. Make sure that `spawnmanager` is ensured **before** `nearby-respawn`.
    ```
    ensure spawnmanager
    ensure nearby-respawn
    ```
3. Done. You should now be able to respawn nearby your death location.

## Known Issues:
* You **rarely** respawn inside of an bunker entrance (Maybe also other dlc content, eg. facilities) (Needs Testing)
