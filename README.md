**!! Currently no interest in active further development. !!**

# FiveM Nearby Respawn System

**This is an unstable and WIP script** for a system that will revive the player nearby to a "safe" location.
The goal is to create a respawn that works similar to GTA5 Online. Currently it should work 99% of the time.
1. At all time the script tries to spawn you nearby on a walkway.
2. If this fails it tries finding a backup point by search Nodes (Streets, paths). By comparing the traffic density, points with a lower density are preferred (the lower the density, the fewer cars),
  2.1 If several are found, it will be chosen at random
3. If no respawn node is found, it iterates with a new midpoint (10% closer to `(0,0,0)`).
4. If everything before fails (maxIterations, too far), you will be resurrected on `(0,0,70)`.

## Command(s)

### `/respawnType` | `/rt`
Expects one argument:
- type (possbile Values: `0`,`1` or `main`, `any`)
    > 0 | main -- Respawns you only near big/main roads (eg. Highways)  
    > 1 | any -- Respawns you on any road or path (eg. Footpath, on Mount Chiliad, Alleys...)
This command allows you to change the respawn type (respawn location).

## Notes:
Debug Prints are also available. Just change the bool in `client.lua`  
<img src="https://user-images.githubusercontent.com/68606032/195240510-bf30db37-d923-417c-b348-58c2435bd3d1.png" data-canonical-src="https://user-images.githubusercontent.com/68606032/195240510-bf30db37-d923-417c-b348-58c2435bd3d1.png" width="400" />  

Walkway Points are **not** shown. You just respawn instantly there.
| Color       |  Meaning |
|-------------|----------|
| Yellow/Gold | Best (Beach, Alley...)|
| Green       | Good (Offroad) |
| Blue        | Okay (Smaller roads (sometimes offroad)) |
| Orange      | Meh (Uncommon) |
| Red         | Bad (Highway) |

## Known Issues:
* (You rarely respawn too far inland from the sea)
* The radius is too small in the city while it is too big in the countryside
* Sometimes no Nodes are found. (Could be intended by the native function?)
