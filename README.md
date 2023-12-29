# FiveM Nearby Respawn System

This script tries to revive a player near a "safe" location.
The goal is to create a respawn that works similar to GTA5 Online. Currently it should work 99.9% of the time.
1. At all time the script tries to spawn you nearby on a walkway.
2. If this fails it tries finding a backup point by search Nodes (Streets, paths). By comparing the traffic density, points with a lower density are preferred (the lower the density, the fewer cars), also it tries to check the type of the road/path by reading the flags.
  2.1 If several are found, it will be chosen at random
3. If no respawn node is found, it iterates with a new midpoint (10% closer to `(0,0,0)`).
4. If everything before fails (maxIterations, too far), you will be resurrected on `(0,0,70)`. (Script contains a BACKUP_RESPAWN_POINTS list, feel free to add some own points)  
5. If the selected point is too close to the death point (10000 units), try again with a radius of `+100`

## Command(s)

### `/respawnType` | `/rt`
This command allows you to change the respawn type (respawn location). 

Arguments:
- type (possbile Values: `0`,`1` or `main`, `any`)
    > 0 | main -- Respawns you only near big/main roads (eg. Highways)  
    > 1 | any -- Respawns you on any road or path (eg. Footpath, on Mount Chiliad, Alleys...)


## Screenshots:
Debug Prints are also available. Just change the bool in `client.lua`  
<img src="https://user-images.githubusercontent.com/68606032/212586570-e95f61da-2cbe-4b91-a6fb-0f65bdaa16ca.jpg" width="400" />
<img src="https://user-images.githubusercontent.com/68606032/212586563-49f0ee0e-a748-4320-9c24-d8f265b0668f.jpg" width="210" />  
<img src="https://user-images.githubusercontent.com/68606032/212586454-48e977d7-46a6-4d2d-9135-ecb2d539bbb7.jpg" width="400" />
<img src="https://user-images.githubusercontent.com/68606032/212586567-e50a3d2b-be00-4d44-9c6c-926425dc2263.jpg" width="240" />

| Color       |  Meaning |
|-------------|----------|
| Dark gray | Death Point |
| Yellow/Gold | Respawn Point |
| Green       | Nearst Node for the final Respawn Point (safe point found) |
| Red         | Nearest Node for failed Respawn Point (no safe point found) |


## Known Issues:
* You **rarely** respawn too far inland from the sea **Needs more testing**
* You **rarely** respawn inside of an bunker entrance (Maybe also other dlc content, eg. facilities)
