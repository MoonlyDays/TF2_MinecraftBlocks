# Minecraft Blocks in Team Fortress 2
### Commands
- sm_block [id] - Selects a block to build with
- sm_build - Builds selected block
- sm_break - Break a block under the crosshair
- sm_limit - Displays current block amount on map
- sm_clearblocks (Ban Flag) - Clears all blocks on map

### ConVars
- sm_minecraft_block_limit (256 default) - Maximum amount of blocks per map

### Features
- You can build with variety of blocks
- Break blocks with melees
- Due to the edict limit maximum amount of concurrent build blocks is 256

### Installation
- minecraft.smx in addons/sourcemod/plugins
- minecraft.sp in addons/sourcemod/scripting
- blocks.cfg in addons/sourcemod/configs
- upload models, materials and sound to your fastdl and server root tf folders
- sm plugins load minecraft or restart the server

### About limiting
Source engine can handle a maximum amount of 2048 blocks in total. If entities will overflow this limit the server will crash.

Every block is a single prop, but every prop itself is an entity. This plugin allows you to freely spawn any amount of entities so its really easy to crash your server.

That's why limit exists. It prevents crashing your server due to edict/entity overflow. 
