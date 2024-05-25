# FiveM Nearby Respawn System

This script tries to revive a player near a "safe" location.
The goal is to create a respawn that works similar to GTA5 Online. Currently it should work 99.9% of the time.
1. At all time the script tries to spawn you nearby on a walkway.
2. If this fails it tries finding a backup point by search Nodes (Streets, paths). By comparing the traffic density, points with a lower density are preferred (the lower the density, the fewer cars), also it tries to check the type of the road/path by reading the flags.
  2.1 If several are found, it will be chosen at random
3. If no respawn node is found, it iterates with a new midpoint (10% closer to `(0,0,0)`).
4. If everything before fails (maxIterations, too far), you will be resurrected on `(0,0,70)`. (Script contains a BACKUP_RESPAWN_POINTS list, feel free to add some own points)  
5. If the selected point is too close to the death point (10000 units), try again with a radius of `+100`

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
| Green       | Safe Respawn Point (Footpath, Walkway, etc.) |
| Blue         | Backup Respawn Point (High density roads, Wide streets) |
| Red         | Too close to the Death Point |


## Known Issues:
* You **rarely** respawn inside of an bunker entrance (Maybe also other dlc content, eg. facilities)
* This system only supports the main island of GTA5 (Los Santos). North Yankton, Cayo Perico, etc. are not supported. (WIP)
