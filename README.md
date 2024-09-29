# FiveM Nearby Respawn System

This script provides a system to respawn players at "safe" locations near where they die, similar to GTA5 Online. The goal is to ensure the respawn works reliably, with a success rate of 99.9%.

### How It Works:
1. **Gather Locations**: The script identifies 20 potential spawn locations near the player's death and groups them based on traffic density. Only ground-level nodes are considered.
2. **Evaluate Traffic**: It prioritizes spawn locations with lower traffic density.
3. **Check for Safe Spots**: For each location, it checks if a safe pedestrian path exists. If none is found, the location is saved as a backup.
4. **Backup Locations**: Locations without safe paths are stored for later consideration.
5. **Select Best Location**: The best location is selected based on low traffic density and the availability of a safe pedestrian path. A backup is used if no suitable location is found.
6. **Adjust Search**: If no suitable spawn point is found within a set number of attempts, the search parameters are adjusted by moving closer to the center of the map. Up to 50 attempts are made.
7. **Avoid near Death Point**: The script checks if the selected location is too close to the death point and tries backup locations if necessary.
8. **Recursive Search**: If a suitable respawn point can't be found, the script recursively calls itself with a larger search radius. This is limited to 10 recursive calls to avoid infinite loops.
9. **Final Respawn**: Once a suitable location is found, the player is respawned, oriented towards the road. If no location is found, the player respawns at (0, 0, 70). These backup locations can be expanded in `client.lua`.

Debug prints and blips are available by adjusting the booleans in `client.lua`.

### Screenshots:
<img src="https://github.com/Flamtky/fivem-respawn-nearby/assets/68606032/d2a987e1-db4d-4aed-829f-e4a2638de275" width="360" />
<img src="https://github.com/Flamtky/fivem-respawn-nearby/assets/68606032/96647d78-70d0-4ea2-ab6e-99f4c12a2099" width="240" /><br>
<img src="https://github.com/Flamtky/fivem-respawn-nearby/assets/68606032/4a1823ae-4fd3-43cb-a9e8-e6a82849879e" width="360" />
<img src="https://github.com/Flamtky/fivem-respawn-nearby/assets/68606032/e2ec91c0-d130-4cab-96e9-06951132402e" width="360" />

### Blip Colors:
| Color       | Meaning |
|-------------|----------|
| Dark gray   | Death Point or new Death Point (if no possible spawns are found nearby) |
| Yellow/Gold | Respawn Point |
| Green       | Safe Respawn Point (Footpath, Walkway, etc.) |
| Blue        | Backup Respawn Point (Roads without footpaths, high-density roads) |
| Red         | Possible Respawn Points that are **not** on ground |

## Installation:
1. **Download** the repository and extract it to your resources folder.
   > **Note:** This script requires the `spawnmanager` resource to be running.
   The folder structure should look like this:
    ```
    [resources]
        -> [fivem-respawn-nearby]
            -> [client.lua]
            ...
    ```
2. **Add to Server Config**: Add `ensure nearby-respawn` to your `server.cfg`. Ensure `spawnmanager` is listed **before** `nearby-respawn`:
    ```
    ensure spawnmanager
    ensure nearby-respawn
    ```
3. **Done**: You should now be able to respawn near your death location.

### Important Note:
- Disable resources like `mapmanager` and `basic-gamemode` as they have their own respawn logic that will interfere with this resource.
- This resource depends on `base-events`, so ensure it is running on your server.

## Known Issues:
- You may **rarely** respawn inside a bunker entrance (or other DLC content, such as facilities). This needs further testing.
- Wrong rotation on repawn (You should always head towards the road). This hard to fix and low priority.
- Currently the script is client-side only. The respawn nearby logic should be server-sided to prevent abuse.
