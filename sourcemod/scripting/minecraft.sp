#include <sourcemod>
#include <sdktools>
#include <menus>
#include <tf2>
#include <tf2_stocks>

#define PLUGIN_AUTHOR "Moonly Days"
#define PLUGIN_VERSION "1.01"

#define MAXBLOCKS 129

new String:g_BaseMaterialVMT[] = "materials/mcmod/%s.vmt";
new String:g_BaseMaterialVTF[] = "materials/mcmod/%s.vtf";

enum BlocksEnum{
	iIndex,
	String:sName[32],
	String:sTarget[32],
	String:sModelPath[128],
	iSkin,
	iLimit,
	bool:bEmitsLight,
	bool:bRotateToPlayer,
	bool:bHidden,
}

new g_Blocks[MAXBLOCKS][BlocksEnum];

int g_Selected[MAXPLAYERS + 1] =  { 1, ... };
int g_Limit = 256;
bool g_CursorEnabled[MAXPLAYERS + 1];

new Handle:g_hLimit;

public Plugin myinfo =
{
	name = "Minecraft Plugin",
	description = "Adds blocks to build with",
	author = PLUGIN_AUTHOR,
	version = PLUGIN_VERSION,
	url = "rcatf2.ru"
};
public void OnClientPostAdminCheck(int client)
{
	g_Selected[client] = 1;
	g_CursorEnabled[client] = false;
}

public void OnPluginStart()
{
	g_hLimit = CreateConVar("sm_minecraft_block_limit", "256", "Define Minecraft Block limit")
	
	if (g_hLimit != INVALID_HANDLE)
	{
		g_Limit = GetConVarInt(g_hLimit);
		HookConVarChange(g_hLimit, OnLimitChange)
	}
	AddNormalSoundHook(NormalSHook:Hook_EntitySound);
	
	RegConsoleCmd("sm_build", cBuildBlock, "Builds a block", 0);
	RegConsoleCmd("sm_block", cSelBlock, "Selects a block", 0);
	RegConsoleCmd("sm_break", cDestroyBlock, "Destroys a block", 0);
	RegConsoleCmd("sm_limit", cCurrentLimit, "Displays Block limit", 0);
	RegAdminCmd("sm_clearblocks", cKillBlocks, ADMFLAG_BAN, "Clears all Minecraft Blocks");
	
}

public void OnMapStart()
{
	AddFileToDownloadsTable("sound/minecraft/stone1.mp3");
	AddFileToDownloadsTable("sound/minecraft/stone2.mp3");
	LoadConfig();
}

public Action Hook_EntitySound(int clients[64],  int &numClients,  char sample[PLATFORM_MAX_PATH],  int &client,  int &channel,  float &volume,  int &level,  int &pitch,  int &flags,  char soundEntry[PLATFORM_MAX_PATH],  int &seed) //Yes, a sound hook is literally the best way to hook this event.
{
	if(!(1<=client<=MaxClients) || !IsClientInGame(client))return Plugin_Continue;
	if(StrContains(sample, "hit", false) != -1) 
	{
		Block_TryBreak(client);
	}
	return Plugin_Continue;
}

public Action cCurrentLimit(int client, int args)
{
	PrintToChat(client, "[Minecraft] Current block limit: %d", Block_GetGlobalLimit());
	return Plugin_Handled;
}

public Action cKillBlocks(int client, int args)
{
	if(args >= 1)
	{
		char sIndex[11];
		GetCmdArg(1, sIndex, 11);
		Block_Kill(client, StringToInt(sIndex));
	}else{
		new block;
		while((block=FindEntityByClassname(block, "prop_dynamic"))!=INVALID_ENT_REFERENCE)
		{
			if (IsValidBlock(block))
			{
				AcceptEntityInput(block, "Kill", -1, -1);
			}
		}
		PrintToChatAll("[Minecraft] All blocks were removed. Map is now clean!");
	}
	return Plugin_Handled;
}

public OnLimitChange(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	g_Limit = StringToInt(newVal);
}

public Action cSelBlock(int client, int args)
{
	Menu menu = new Menu(mBlocks);
	menu.SetTitle("Select a block");
	
	if(args >= 1)
	{
		char sIndex[11];
		GetCmdArg(1, sIndex, 11);
		Blocks_Select(client, StringToInt(sIndex));
	}else{
		PrintToChat(client, "\x07f49d41[Minecraft Plugin] \x07eeeeeeMade by \x07729e42Moonly Days");
		for (new i = 0; i < MAXBLOCKS; i++)
		{
			if (g_Blocks[i][iIndex] <= 0 || g_Blocks[i][bHidden])continue;
			new String:sIndex[3];
			IntToString(i, sIndex, 3);
			menu.AddItem(sIndex, g_Blocks[i][sName]);
		}
	}
	menu.ExitButton = true;
	menu.Display(client, 20);
	return Plugin_Handled;
}

public void Block_TryBreak(int client)
{
	int iTarget = GetClientAimTarget(client, false);
	if (IsValidBlock(iTarget))
	{
		float flClientPos[3];
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", flClientPos);
		float flTargetPos[3];
		GetEntPropVector(iTarget, Prop_Send, "m_vecOrigin", flTargetPos);
		if (GetVectorDistance(flClientPos, flTargetPos) > 300)
		{
			return;
		}
		ClientCommand(client, "playgamesound minecraft/stone2.mp3");
		
		AcceptEntityInput(iTarget, "Kill");
		
	}
}

public Action cDestroyBlock(int client, int args)
{
	if (IsPlayerAlive(client))
	{
		Block_TryBreak(client);
	}
	return Plugin_Handled;
}

public void Block_Kill(int client, int block)
{
	if(block <= 0 || block >= MAXBLOCKS)
	{
		PrintToChat(client, "[Minecraft] Block ID out of bounds (1..128)");
		return;
	}
	if(g_Blocks[block][iIndex] != block)
	{
		PrintToChat(client, "[Minecraft] Undefined block ID");
		return;
	}
	
	new iBlock;
	while((iBlock=FindEntityByClassname(iBlock, "prop_dynamic"))!=INVALID_ENT_REFERENCE)
	{
		if (IsValidBlockType(iBlock,block))
		{
			AcceptEntityInput(iBlock, "Kill", -1, -1);
		}
	}
	
	PrintToChatAll("[Minecraft] All %s were removed.", g_Blocks[block][sName]);
}

public void Blocks_Select(int client, int block)
{
	if(block <= 0 || block >= MAXBLOCKS)
	{
		PrintToChat(client, "[Minecraft] Block ID out of bounds (1..128)");
		return;
	}
	if(g_Blocks[block][iIndex] != block)
	{
		PrintToChat(client, "[Minecraft] Undefined block ID");
		return;
	}
	g_Selected[client] = block;
	PrintToChat(client, "[Minecraft] Selected block: %s", g_Blocks[block][sName]);
}

public int mBlocks(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char info[11];
		menu.GetItem(param2, info, sizeof(info));
		new iBlock = StringToInt(info);
		Blocks_Select(param1, iBlock);
	}else if (action == MenuAction_End)
	{
			delete menu;
	}
	return 0;
}

public Action cBuildBlock(int client, int args)
{
	// NOTE: We don't check if this id exists since we already made a check in /block
	
	// Check if player is valid 
	if(!(0 < client <= MaxClients)) return Plugin_Handled;
	
	// Check if player is alive and in-game
	if (!IsClientInGame(client))return Plugin_Handled;
	if (!IsPlayerAlive(client)){
		PrintToChat(client, "[Minecraft] You must be alive to do this.");
		return Plugin_Handled;
	}
	
	// Clamping g_Selected
	if (g_Selected[client] < 1)g_Selected[client] = 1;
	if (g_Selected[client] > 128)g_Selected[client] = 128;
	
	// Checking for global limit
	if (Block_GetGlobalLimit() > g_Limit){
		PrintToChat(client, "[Overall Limit] Overall amount of blocks exceeded the limit of %d blocks per map. Destory some to build.",g_Limit);
		return Plugin_Handled;
	}
	
	// Checking for local per block limit
	new iSelected = g_Selected[client];
	
	if(g_Blocks[iSelected][iLimit] != -1){
		if (Block_GetBlockLimit(iSelected) >= g_Blocks[iSelected][iLimit]){
			PrintToChat(client, "[Block Limit] Amount of blocks of this type exceeded the limit of %d %s per map. Destroy some to build.",g_Blocks[iSelected][iLimit],g_Blocks[iSelected][sName]);
			return Plugin_Handled;
		}
	}
	
	// Getting snapped block's coords
	float flStart[3], flAngle[3], flPos[3];
	GetClientEyePosition(client, flStart);
	GetClientEyeAngles(client, flAngle);
	
	TR_TraceRayFilter(flStart, flAngle, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer, client); 
	
	if (TR_DidHit(INVALID_HANDLE))
	{
		TR_GetEndPosition(flPos, INVALID_HANDLE);
	}
	
	int i = 0;
	while (i < 3)
	{
		flPos[i] = RoundToNearest(flPos[i] / 50) * 50.0;
		i++;
	}
	
	// Check if no blocks at this coords
	if (Block_CheckBlocksAtCoords(flPos))return Plugin_Handled;
	
	// Check if no players around
	if (Block_CheckPlayersInRange(flPos, 60.0))return Plugin_Handled;
	
	// Check if distance is < 300 units
	if (GetVectorDistance(flStart, flPos) > 300)return Plugin_Handled;
	
	// Create and setup entity
	int iEnt = CreateEntityByName("prop_dynamic_override");
	if (IsValidEdict(iEnt))
	{
		float flAng[3];
		// Teleport to place
		if(g_Blocks[iSelected][bRotateToPlayer])
		{
			flAng[1] = (RoundToNearest(flAngle[1] / 90.0) * 90.0) + 90.0;
		}
		TeleportEntity(iEnt, flPos, flAng, NULL_VECTOR);
		
		SetEntProp(iEnt, Prop_Send, "m_nSkin", g_Blocks[iSelected][iSkin]);
		SetEntProp(iEnt, Prop_Send, "m_nSolidType", 6);
		
		// Supply target name
		char sTName[64];
		Format(sTName, 32, "tf_block_%s", g_Blocks[iSelected][sTarget]);
		DispatchKeyValue(iEnt, "targetname", sTName);
		SetEntityModel(iEnt, g_Blocks[iSelected][sModelPath]);
		
		// Activation
		DispatchSpawn(iEnt);
		ActivateEntity(iEnt);
		
		if(g_Blocks[iSelected][bEmitsLight])
		{
			new iEntLight = CreateEntityByName("light_dynamic");  
			if (IsValidEdict(iEntLight))    
		    {     
		        DispatchKeyValue(iEntLight, "_light", "250 250 200");  
		        DispatchKeyValue(iEntLight, "brightness", "5");  
		        DispatchKeyValueFloat(iEntLight, "spotlight_radius", 280.0);  
		        DispatchKeyValueFloat(iEntLight, "distance", 180.0);
		        DispatchKeyValue(iEntLight, "targetname", "tf_block_light");
		        DispatchKeyValue(iEntLight, "style", "0");   
		        DispatchSpawn(iEntLight);
		        ActivateEntity(iEntLight);
				
		        float flLightPos[3];
		        flLightPos[0] = flPos[0];
		        flLightPos[1] = flPos[1];
		        flLightPos[2] = flPos[2] + 25.0;
		        
		        TeleportEntity(iEntLight, flLightPos, NULL_VECTOR, NULL_VECTOR); 
		        
		        SetVariantString("!activator");
		        AcceptEntityInput(iEntLight, "SetParent", iEnt, iEntLight);
		        AcceptEntityInput(iEntLight, "TurnOn");
		
		    }  
		}
		
		// Play Sound
		ClientCommand(client, "playgamesound minecraft/stone1.mp3");
	}
	return Plugin_Handled;
}

public bool Block_CheckBlocksAtCoords(float coords[3])
{
	new iBlock;
	while((iBlock=FindEntityByClassname(iBlock, "prop_dynamic"))!=INVALID_ENT_REFERENCE)
	{
		if (IsValidBlock(iBlock))
		{
			float flPos[3];
			GetEntPropVector(iBlock, Prop_Send, "m_vecOrigin", flPos);
			if(coords[0] == flPos[0] && coords[1] == flPos[1] && coords[2] == flPos[2])
			{
				return true;
			}
		}
	}
	return false;
}

public bool Block_CheckPlayersInRange(float pos[3], float range)
{
	for (new i = 1; i < MaxClients;i++){
		if (IsClientInGame(i))
		{
			if (IsPlayerAlive(i))
			{
				float flPos[3];
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", flPos, 0);
				if (GetVectorDistance(pos, flPos) < range)
				{
					return true;
				}
			}
		}
	}
	return false;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask, any data)
{
	return entity > MaxClients;
}

public int Block_GetBlockLimit(int block)
{
	new tLimit;
	new iBlock;
	
	while((iBlock=FindEntityByClassname(iBlock, "prop_dynamic"))!=INVALID_ENT_REFERENCE)
	{
		if (IsValidBlockType(iBlock, block))
		{
			tLimit++;
		}
	}
	return tLimit;
}

public int Block_GetGlobalLimit()
{
	new tLimit;
	new iBlock;
	while((iBlock=FindEntityByClassname(iBlock, "prop_dynamic"))!=INVALID_ENT_REFERENCE)
	{
		if (IsValidBlock(iBlock))
		{
			tLimit++;
		}
	}
	iBlock = 0;
	while((iBlock=FindEntityByClassname(iBlock, "light_dynamic"))!=INVALID_ENT_REFERENCE)
	{
		if (IsValidBlock(iBlock))
		{
			tLimit++;
		}
	}
	return tLimit;
}

public bool IsValidBlockType(int entity, int block)
{
	char sTarName[32];
	Format(sTarName, 32, "tf_block_%s", g_Blocks[block][sTarget]);
	
	if (entity > 0)
	{
		char tName[16];
		GetEntPropString(entity, Prop_Data, "m_iName", tName, 16);
		if (StrEqual(tName, sTarName))
		{
			return true;
		}
	}
	return false;
}

public bool IsValidBlock(int entity)
{
	if (entity > 0)
	{
		char tName[16];
		GetEntPropString(entity, Prop_Data, "m_iName", tName, 16);
		if (StrContains(tName, "tf_block") != -1)
		{
			return true;
		}
	}
	return false;
}

stock LoadConfig()
{
	new String:loc[96];
	BuildPath(Path_SM, loc, 96, "configs/blocks.cfg");
	new Handle:kv = CreateKeyValues("Blocks");
	FileToKeyValues(kv,loc);
	
	for(new i = 1;i<MAXBLOCKS;i++){
		new String:Index[11];
		IntToString(i,Index,sizeof(Index));
		if(KvJumpToKey(kv,Index,false)){
			g_Blocks[i][iIndex] = i;
			KvGetString(kv, "name", g_Blocks[i][sName], 32);
			KvGetString(kv, "targetname", g_Blocks[i][sTarget], 32);
			KvGetString(kv, "model", g_Blocks[i][sModelPath], 128);
			AddFileToDownloadsTable(g_Blocks[i][sModelPath]);
			
			char sModelBase[2][128],sModel[128];
			ExplodeString(g_Blocks[i][sModelPath], ".", sModelBase, 2, 128);
			
			//
			Format(sModel, 128, "%s.dx80.vtx", sModelBase[0]);
			AddFileToDownloadsTable(sModel);
			Format(sModel, 128, "%s.dx90.vtx", sModelBase[0]);
			AddFileToDownloadsTable(sModel);
			Format(sModel, 128, "%s.phy", sModelBase[0]);
			AddFileToDownloadsTable(sModel);
			Format(sModel, 128, "%s.sw.vtx", sModelBase[0]);
			AddFileToDownloadsTable(sModel);
			Format(sModel, 128, "%s.vvd", sModelBase[0]);
			AddFileToDownloadsTable(sModel);
			
			PrecacheModel(g_Blocks[i][sModelPath]);
			new String:sMaterialBase[32], String:sMaterial[128];
			KvGetString(kv, "material", sMaterialBase, 32,"--");
			if(!StrEqual(sMaterialBase,"--"))
			{
				Format(sMaterial, 128, g_BaseMaterialVMT, sMaterialBase);
				AddFileToDownloadsTable(sMaterial);
				Format(sMaterial, 128, g_BaseMaterialVTF, sMaterialBase);
				AddFileToDownloadsTable(sMaterial);
			}
			g_Blocks[i][iSkin] = KvGetNum(kv, "skin", 0);
			g_Blocks[i][iLimit] = KvGetNum(kv, "limit", -1);
			g_Blocks[i][bEmitsLight] = KvGetNum(kv, "light", 0) == 0 ? false : true;
			g_Blocks[i][bRotateToPlayer] = KvGetNum(kv, "toplayer", 0) == 0 ? false : true;
			g_Blocks[i][bHidden] = KvGetNum(kv, "hidden", 0) == 0 ? false : true;
			KvGoBack(kv);
		}
	}
}