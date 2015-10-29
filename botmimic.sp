/**
 * Bot Mimic - Record your movments and have bots playing it back.
 * by Peace-Maker
 * visit http://wcfan.de
 * 
 * Changelog:
 * 2.0   - 22.07.2013: Released rewrite
 * 2.0.1 - 01.08.2013: Actually made DHooks an optional dependency.
 * 2.1   - 02.10.2014: Added bookmarks and pausing/resuming while recording. Fixed crashes and problems with CS:GO.
 */

#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <smlib>
#include <botmimic>


#define PLUGIN_VERSION "2.1"

#define BM_MAGIC 0xdeadbeef

// New in 0x02: bookmarkCount and bookmarks list
#define BINARY_FORMAT_VERSION 0x02

#define DEFAULT_RECORD_FOLDER "data/botmimic/"

// Flags set in FramInfo.additionalFields to inform, that there's more info afterwards.
#define ADDITIONAL_FIELD_TELEPORTED_ORIGIN (1<<0)
#define ADDITIONAL_FIELD_TELEPORTED_ANGLES (1<<1)
#define ADDITIONAL_FIELD_TELEPORTED_VELOCITY (1<<2)

enum FrameInfo {
	playerButtons = 0, 
	Float:framePosition[3], 
	Float:frameAngles[3], 
	Float:frameVelocity[3], 
	CSWeaponID:newWeapon, 
	//playerSubtype,
	//playerSeed,
	//additionalFields // see ADDITIONAL_FIELD_* defines
}

#define AT_ORIGIN 0
#define AT_ANGLES 1
#define AT_VELOCITY 2
#define AT_FLAGS 3
enum AdditionalTeleport {
	Float:atOrigin[3],
	Float:atAngles[3],
	Float:atVelocity[3],
	atFlags
}

enum FileHeader {
	FH_binaryFormatVersion = 0, 
	FH_recordEndTime, 
	String:FH_recordName[MAX_RECORD_NAME_LENGTH], 
	FH_tickCount, 
	Float:FH_initialPosition[3], 
	Float:FH_initialAngles[3], 
	Handle:FH_frames
}

// Where did he start recording. The bot is teleported to this position on replay.
new Float:g_fInitialPosition[MAXPLAYERS + 1][3];
new Float:g_fInitialAngles[MAXPLAYERS + 1][3];
// Array of frames
new Handle:g_hRecording[MAXPLAYERS + 1];
// Is the recording currently paused?
new bool:g_bRecordingPaused[MAXPLAYERS + 1];
new bool:g_bSaveFullSnapshot[MAXPLAYERS + 1];
// How many calls to OnPlayerRunCmd were recorded?
new g_iRecordedTicks[MAXPLAYERS + 1];
// What's the last active weapon
new g_iRecordPreviousWeapon[MAXPLAYERS + 1];
// Count ticks till we save the position again
new g_iOriginSnapshotInterval[MAXPLAYERS + 1];
// The name of this recording
new String:g_sRecordName[MAXPLAYERS + 1][MAX_RECORD_NAME_LENGTH];
new String:g_sRecordPath[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
new String:g_sRecordCategory[MAXPLAYERS + 1][PLATFORM_MAX_PATH];
new String:g_sRecordSubDir[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

new Handle:g_hLoadedRecords;
new Handle:g_hLoadedRecordsCategory;
new Handle:g_hSortedRecordList;
new Handle:g_hSortedCategoryList;

new Handle:g_hBotMimicsRecord[MAXPLAYERS + 1] =  { INVALID_HANDLE, ... };
new g_iBotMimicTick[MAXPLAYERS + 1] =  { 0, ... };
new g_iBotMimicRecordTickCount[MAXPLAYERS + 1] =  { 0, ... };
new g_iBotActiveWeapon[MAXPLAYERS + 1] =  { -1, ... };
new bool:g_bValidTeleportCall[MAXPLAYERS + 1];
new Handle:g_hfwdOnStartRecording;
new Handle:g_hfwdOnRecordingPauseStateChanged;
new Handle:g_hfwdOnStopRecording;
new Handle:g_hfwdOnRecordSaved;
new Handle:g_hfwdOnRecordDeleted;
new Handle:g_hfwdOnPlayerStartsMimicing;
new Handle:g_hfwdOnPlayerStopsMimicing;
new Handle:g_hfwdOnPlayerMimicLoops;

// DHooks

//new Handle:g_hCVOriginSnapshotInterval;
new Handle:g_hCVRespawnOnDeath;

public Plugin:myinfo = 
{
	name = "Bot Mimic", 
	author = "Jannik \"Peace-Maker\" Hartung, cam", 
	description = "Bots mimic your movements!", 
	version = PLUGIN_VERSION, 
	url = "http://www.wcfan.de/"
}

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	RegPluginLibrary("botmimic");
	CreateNative("BotMimic_StartRecording", StartRecording);
	CreateNative("BotMimic_PauseRecording", PauseRecording);
	CreateNative("BotMimic_ResumeRecording", ResumeRecording);
	CreateNative("BotMimic_IsRecordingPaused", IsRecordingPaused);
	CreateNative("BotMimic_StopRecording", StopRecording);
	CreateNative("BotMimic_DeleteRecord", DeleteRecord);
	CreateNative("BotMimic_IsPlayerRecording", IsPlayerRecording);
	CreateNative("BotMimic_IsPlayerMimicing", IsPlayerMimicing);
	CreateNative("BotMimic_GetRecordPlayerMimics", GetRecordPlayerMimics);
	CreateNative("BotMimic_PlayRecordFromFile", PlayRecordFromFile);
	CreateNative("BotMimic_PlayRecordByName", PlayRecordByName);
	CreateNative("BotMimic_FindRecordByName", FindRecordByName);
	CreateNative("BotMimic_ResetPlayback", ResetPlayback);
	CreateNative("BotMimic_StopPlayerMimic", StopPlayerMimic);
	CreateNative("BotMimic_GetFileHeaders", GetFileHeaders);
	CreateNative("BotMimic_ChangeRecordName", ChangeRecordName);
	CreateNative("BotMimic_GetLoadedRecordCategoryList", GetLoadedRecordCategoryList);
	CreateNative("BotMimic_GetLoadedRecordList", GetLoadedRecordList);
	CreateNative("BotMimic_GetFileCategory", GetFileCategory);
	CreateNative("BotMimic_SaveBookmark", SaveBookmark);
	
	g_hfwdOnStartRecording = CreateGlobalForward("BotMimic_OnStartRecording", ET_Hook, Param_Cell, Param_String, Param_String, Param_String, Param_String);
	g_hfwdOnRecordingPauseStateChanged = CreateGlobalForward("BotMimic_OnRecordingPauseStateChanged", ET_Ignore, Param_Cell, Param_Cell);
	g_hfwdOnStopRecording = CreateGlobalForward("BotMimic_OnStopRecording", ET_Hook, Param_Cell, Param_String, Param_String, Param_String, Param_String, Param_CellByRef);
	g_hfwdOnRecordSaved = CreateGlobalForward("BotMimic_OnRecordSaved", ET_Ignore, Param_Cell, Param_String, Param_String, Param_String, Param_String);
	g_hfwdOnRecordDeleted = CreateGlobalForward("BotMimic_OnRecordDeleted", ET_Ignore, Param_String, Param_String, Param_String);
	g_hfwdOnPlayerStartsMimicing = CreateGlobalForward("BotMimic_OnPlayerStartsMimicing", ET_Hook, Param_Cell, Param_String, Param_String, Param_String);
	g_hfwdOnPlayerStopsMimicing = CreateGlobalForward("BotMimic_OnPlayerStopsMimicing", ET_Ignore, Param_Cell, Param_String, Param_String, Param_String);
	g_hfwdOnPlayerMimicLoops = CreateGlobalForward("BotMimic_OnPlayerMimicLoops", ET_Ignore, Param_Cell);
}

public OnPluginStart()
{
	new Handle:hVersion = CreateConVar("sm_botmimic_version", PLUGIN_VERSION, "Bot Mimic version", FCVAR_PLUGIN | FCVAR_NOTIFY | FCVAR_DONTRECORD);
	if (hVersion != INVALID_HANDLE)
	{
		SetConVarString(hVersion, PLUGIN_VERSION);
		HookConVarChange(hVersion, ConVar_VersionChanged);
	}
	
	// Save the position of clients every 10000 ticks
	// This is to avoid bots getting stuck in walls due to slightly lower jumps, if they don't touch the ground.
	g_hCVRespawnOnDeath = CreateConVar("sm_botmimic_respawnondeath", "1", "Respawn the bot when he dies during playback?", _, true, 0.0, true, 1.0);
	
	AutoExecConfig();
	
	// Maps path to .rec -> record enum
	g_hLoadedRecords = CreateTrie();
	
	// Maps path to .rec -> record category
	g_hLoadedRecordsCategory = CreateTrie();
	
	// Save all paths to .rec files in the trie sorted by time
	g_hSortedRecordList = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	g_hSortedCategoryList = CreateArray(ByteCountToCells(64));
	
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath);
	
	
	
}

public ConVar_VersionChanged(Handle:convar, const String:oldValue[], const String:newValue[])
{
	SetConVarString(convar, PLUGIN_VERSION);
}

/**
 * Public forwards
 */

public OnEntityCreated(entity, const String:classname[])
{
	if(StrEqual(classname, "trigger_teleport"))
	{
		SDKHook(entity, SDKHook_Touch, OnTouch);
	}
}

public Action:OnTouch(entity, activator){
	if (activator < 65 && IsFakeClient(activator))
		return Plugin_Handled;
		
	return Plugin_Continue;
}


public OnMapStart()
{
	// Clear old records for old map
	new iSize = GetArraySize(g_hSortedRecordList);
	decl String:sPath[PLATFORM_MAX_PATH];
	new iFileHeader[FileHeader];
	ClearTrie(g_hLoadedRecords);
	ClearTrie(g_hLoadedRecordsCategory);
	ClearArray(g_hSortedRecordList);
	ClearArray(g_hSortedCategoryList);
	
	// Create our record directory
	BuildPath(Path_SM, sPath, sizeof(sPath), DEFAULT_RECORD_FOLDER);
	if (!DirExists(sPath))
		CreateDirectory(sPath, 511);
	
	// Check for categories
	new Handle:hDir = OpenDirectory(sPath);
	if (hDir == INVALID_HANDLE)
		return;
	

	
	new String:sFile[256], FileType:fileType;
	while (ReadDirEntry(hDir, sFile, sizeof(sFile), fileType))
	{
		switch (fileType)
		{
			// Check all directories for records on this map
			case FileType_Directory:
			{
				// INFINITE RECURSION ANYONE?
				if (StrEqual(sFile, ".") || StrEqual(sFile, ".."))
					continue;
				
				BuildPath(Path_SM, sPath, sizeof(sPath), "%s%s", DEFAULT_RECORD_FOLDER, sFile);
				ParseRecordsInDirectory(sPath, sFile, false);
			}
		}
		
	}
	CloseHandle(hDir);
}


public OnClientDisconnect(client)
{
	if (g_hRecording[client] != INVALID_HANDLE)
		BotMimic_StopRecording(client);
	
	if (g_hBotMimicsRecord[client] != INVALID_HANDLE)
		BotMimic_StopPlayerMimic(client);
}


public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
	// client is recording his movements
	if (g_hRecording[client] != INVALID_HANDLE && !g_bRecordingPaused[client])
	{
		decl iFrame[FrameInfo];
		iFrame[playerButtons] = buttons;
		
		decl Float:vPos[3], Float:vAng[3];
		Entity_GetAbsOrigin(client, vPos);
		GetClientEyeAngles(client, vAng);
		
		iFrame[frameVelocity] = vel;
		iFrame[framePosition] = vPos;
		iFrame[frameAngles] = vAng;
		//iFrame[newWeapon] = CSWeapon_NONE;
		//iFrame[playerSubtype] = subtype;
		//iFrame[playerSeed] = seed;
		
		// Save the origin, angles and velocity in this frame.
		
		g_iOriginSnapshotInterval[client]++;
		
		PushArrayArray(g_hRecording[client], iFrame[0], _:FrameInfo);
		
		g_iRecordedTicks[client]++;
	}
	
	new botclient = 0;
	if (IsFakeClient(client) && g_hBotMimicsRecord[client] != INVALID_HANDLE)
		botclient = client;
	
	// Bot is mimicing something
	if (botclient != 0) {
		// Is this a valid living bot?
		if (!IsPlayerAlive(botclient) || GetClientTeam(botclient) < CS_TEAM_T)
			return Plugin_Continue;
		
		if (g_iBotMimicTick[botclient] >= g_iBotMimicRecordTickCount[botclient])
		{
			g_iBotMimicTick[botclient] = 0;
		}
		
		new iFrame[FrameInfo];
		GetArrayArray(g_hBotMimicsRecord[botclient], g_iBotMimicTick[botclient], iFrame[0], _:FrameInfo);
		
		buttons = iFrame[playerButtons];
		//buttons &= ~(IN_USE|IN_ATTACK|IN_ATTACK2); // dont let bots attack
		
		decl Float:newPos[3], Float:newAng[3];
		newPos[0] = iFrame[framePosition][0];
		newPos[1] = iFrame[framePosition][1];
		newPos[2] = iFrame[framePosition][2];
		newAng[0] = iFrame[frameAngles][0];
		newAng[1] = iFrame[frameAngles][1];
		newAng[2] = iFrame[frameAngles][2];
		
		if (g_iBotMimicTick[botclient] == 0) {
			g_bValidTeleportCall[botclient] = true;
			TeleportEntity(botclient, g_fInitialPosition[botclient], g_fInitialAngles[botclient], Float: { 0.0, 0.0, 0.0 } );
			
			Call_StartForward(g_hfwdOnPlayerMimicLoops);
			Call_PushCell(botclient);
			Call_Finish();
		} else {
			decl Float:actualPos[3];
			Entity_GetAbsOrigin(client, actualPos);
			if (GetVectorDistance(newPos, actualPos) > 128.0) {
				g_bValidTeleportCall[botclient] = true;
				TeleportEntity(botclient, newPos, newAng, NULL_VECTOR);
			} else {
				decl Float:vVel[3];
				MakeVectorFromPoints(actualPos, newPos, vVel);
				ScaleVector(vVel, 100.0);
				
				g_bValidTeleportCall[botclient] = true;
				TeleportEntity(botclient, NULL_VECTOR, newAng, vVel);
			}
		}
		if (GetEntityMoveType(botclient) != MOVETYPE_NOCLIP)
			SetEntityMoveType(botclient, MOVETYPE_NOCLIP);
		
		g_iBotMimicTick[botclient]++;
		PrintToChatAll("");
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

/**
 * Event Callbacks
 */
public Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client)
		return;
	
	// Restart moving on spawn!
	if (g_hBotMimicsRecord[client] != INVALID_HANDLE)
	{
		g_iBotMimicTick[client] = 0;
	}
}

public Event_OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client)
		return;
	
	// This one has been recording currently
	if (g_hRecording[client] != INVALID_HANDLE)
	{
		BotMimic_StopRecording(client, true);
	}
	// This bot has been playing one
	else if (g_hBotMimicsRecord[client] != INVALID_HANDLE)
	{
		// Respawn the bot after death!
		g_iBotMimicTick[client] = 0;
		if (GetConVarBool(g_hCVRespawnOnDeath) && GetClientTeam(client) >= CS_TEAM_T)
			CreateTimer(1.0, Timer_DelayedRespawn, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
	}
}

/**
 * Timer Callbacks
 */
public Action:Timer_DelayedRespawn(Handle:timer, any:userid)
{
	new client = GetClientOfUserId(userid);
	if (!client)
		return Plugin_Stop;
	
	if (g_hBotMimicsRecord[client] != INVALID_HANDLE && IsClientInGame(client) && !IsPlayerAlive(client) && IsFakeClient(client) && GetClientTeam(client) >= CS_TEAM_T)
		CS_RespawnPlayer(client);
	
	return Plugin_Stop;
}


/**
 * SDKHooks Callbacks
 */
// Don't allow mimicing players any other weapon than the one recorded!!
public Action:Hook_WeaponCanSwitchTo(client, weapon)
{
	if (g_hBotMimicsRecord[client] == INVALID_HANDLE)
		return Plugin_Continue;
	
	if (g_iBotActiveWeapon[client] != weapon)
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

/**
 * Natives
 */

public SaveBookmark(Handle:plugin, numParams) {
}
public StartRecording(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return;
	}
	
	if (g_hRecording[client] != INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is already recording.");
		return;
	}
	
	if (g_hBotMimicsRecord[client] != INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is currently mimicing another record.");
		return;
	}
	
	g_hRecording[client] = CreateArray(_:FrameInfo);
	GetClientAbsOrigin(client, g_fInitialPosition[client]);
	GetClientEyeAngles(client, g_fInitialAngles[client]);
	g_iRecordedTicks[client] = 0;
	g_iOriginSnapshotInterval[client] = 0;
	
	GetNativeString(2, g_sRecordName[client], MAX_RECORD_NAME_LENGTH);
	GetNativeString(3, g_sRecordCategory[client], PLATFORM_MAX_PATH);
	GetNativeString(4, g_sRecordSubDir[client], PLATFORM_MAX_PATH);
	
	if (g_sRecordCategory[client][0] == '\0')
		strcopy(g_sRecordCategory[client], sizeof(g_sRecordCategory[]), DEFAULT_CATEGORY);
	
	// Path:
	// data/botmimic/%CATEGORY%/map_name/%SUBDIR%/record.rec
	// subdir can be omitted, default category is "default"
	
	// All demos reside in the default path (data/botmimic)
	BuildPath(Path_SM, g_sRecordPath[client], PLATFORM_MAX_PATH, "%s%s", DEFAULT_RECORD_FOLDER, g_sRecordCategory[client]);
	
	// Remove trailing slashes
	if (g_sRecordPath[client][strlen(g_sRecordPath[client]) - 1] == '\\' ||
		g_sRecordPath[client][strlen(g_sRecordPath[client])-1] == '/')
		g_sRecordPath[client][strlen(g_sRecordPath[client])-1] = '\0';
	
	new Action:result;
	Call_StartForward(g_hfwdOnStartRecording);
	Call_PushCell(client);
	Call_PushString(g_sRecordName[client]);
	Call_PushString(g_sRecordCategory[client]);
	Call_PushString(g_sRecordSubDir[client]);
	Call_PushString(g_sRecordPath[client]);
	Call_Finish(result);
	
	if(result >= Plugin_Handled)
		BotMimic_StopRecording(client, false);
}

public PauseRecording(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return;
	}
	
	if(g_hRecording[client] == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not recording.");
		return;
	}
	
	if(g_bRecordingPaused[client])
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Recording is already paused.");
		return;
	}
	
	g_bRecordingPaused[client] = true;
	
	Call_StartForward(g_hfwdOnRecordingPauseStateChanged);
	Call_PushCell(client);
	Call_PushCell(true);
	Call_Finish();
}

public ResumeRecording(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return;
	}
	
	if(g_hRecording[client] == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not recording.");
		return;
	}
	
	if(!g_bRecordingPaused[client])
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Recording is not paused.");
		return;
	}
	
	// Save the new full position, angles and velocity.
	g_bSaveFullSnapshot[client] = true;
	
	g_bRecordingPaused[client] = false;
	
	Call_StartForward(g_hfwdOnRecordingPauseStateChanged);
	Call_PushCell(client);
	Call_PushCell(false);
	Call_Finish();
}

public IsRecordingPaused(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return false;
	}
	
	if(g_hRecording[client] == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not recording.");
		return false;
	}
	
	return g_bRecordingPaused[client];
}

public StopRecording(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return;
	}
	
	// Not recording..
	if(g_hRecording[client] == INVALID_HANDLE)
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not recording.");
		return;
	}
	
	new bool:save = GetNativeCell(2);
	
	new Action:result;
	Call_StartForward(g_hfwdOnStopRecording);
	Call_PushCell(client);
	Call_PushString(g_sRecordName[client]);
	Call_PushString(g_sRecordCategory[client]);
	Call_PushString(g_sRecordSubDir[client]);
	Call_PushString(g_sRecordPath[client]);
	Call_PushCellRef(save);
	Call_Finish(result);
	
	// Don't stop recording ? 
		if (result >= Plugin_Handled)
			return;
		
		if (save)
		{
			new iEndTime = GetTime();
			
			decl String:sMapName[64], String:sPath[PLATFORM_MAX_PATH];
			GetCurrentMap(sMapName, sizeof(sMapName));
			
			// Check if the default record folder exists?
			BuildPath(Path_SM, sPath, sizeof(sPath), DEFAULT_RECORD_FOLDER);
			// Remove trailing slashes
			if (sPath[strlen(sPath) - 1] == '\\' || sPath[strlen(sPath)-1] == '/')
			sPath[strlen(sPath)-1] = '\0';
		
		if(!CheckCreateDirectory(sPath, 511))
			return;
		// Check if the category folder exists?
		BuildPath(Path_SM, sPath, sizeof(sPath), "%s%s", DEFAULT_RECORD_FOLDER, g_sRecordCategory[client]);
		if(!CheckCreateDirectory(sPath, 511))
			return;
		
		// Check, if there is a folder for this map already
		Format(sPath, sizeof(sPath), "%s/%s", g_sRecordPath[client], sMapName);
		if(!CheckCreateDirectory(sPath, 511))
			return;
		
		// Check if the subdirectory exists
		if(g_sRecordSubDir[client][0] != '\0')
		{
			Format(sPath, sizeof(sPath), "%s/%s", sPath, g_sRecordSubDir[client]);
			if(!CheckCreateDirectory(sPath, 511))
				return;
		}
		
		Format(sPath, sizeof(sPath), "%s/%d.rec", sPath, iEndTime);
		
		// Add to our loaded record list
		new iHeader[FileHeader];
		iHeader[FH_binaryFormatVersion] = BINARY_FORMAT_VERSION;
		iHeader[FH_recordEndTime] = iEndTime;
		iHeader[FH_tickCount] = GetArraySize(g_hRecording[client]);
		strcopy(iHeader[FH_recordName], MAX_RECORD_NAME_LENGTH, g_sRecordName[client]);
		Array_Copy(g_fInitialPosition[client], iHeader[FH_initialPosition], 3);
		Array_Copy(g_fInitialAngles[client], iHeader[FH_initialAngles], 3);
		iHeader[FH_frames] = g_hRecording[client];
		
		WriteRecordToDisk(sPath, iHeader);
		
		SetTrieArray(g_hLoadedRecords, sPath, iHeader[0], _:FileHeader);
		SetTrieString(g_hLoadedRecordsCategory, sPath, g_sRecordCategory[client]);
		PushArrayString(g_hSortedRecordList, sPath);
		if(FindStringInArray(g_hSortedCategoryList, g_sRecordCategory[client]) == -1)
			PushArrayString(g_hSortedCategoryList, g_sRecordCategory[client]);
		SortRecordList();
		
		Call_StartForward(g_hfwdOnRecordSaved);
		Call_PushCell(client);
		Call_PushString(g_sRecordName[client]);
		Call_PushString(g_sRecordCategory[client]);
		Call_PushString(g_sRecordSubDir[client]);
		Call_PushString(sPath);
		Call_Finish();
	}
	else
	{
		CloseHandle(g_hRecording[client]);
	}
	
	g_hRecording[client] = INVALID_HANDLE;
	g_iRecordedTicks[client] = 0;
	g_iRecordPreviousWeapon[client] = 0;
	g_sRecordName[client][0] = 0;
	g_sRecordPath[client][0] = 0;
	g_sRecordCategory[client][0] = 0;
	g_sRecordSubDir[client][0] = 0;
	g_iOriginSnapshotInterval[client] = 0;
	g_bRecordingPaused[client] = false;
	g_bSaveFullSnapshot[client] = false;
}

public DeleteRecord(Handle:plugin, numParams)
{
	new iLen;
	GetNativeStringLength(1, iLen);
	new String:sPath[iLen+1];
	GetNativeString(1, sPath, iLen+1);
	
	// Do we have this record loaded?
	new iFileHeader[FileHeader];
	if(!GetTrieArray(g_hLoadedRecords, sPath, iFileHeader[0], _:FileHeader))
	{
		if(!FileExists(sPath))
			return -1;
		
		// Try to load it to make sure it's a record file we're deleting here!
		new BMError:error = LoadRecordFromFile(sPath, DEFAULT_CATEGORY, iFileHeader, true, false);
		if(error == BM_FileNotFound || error == BM_BadFile)
			return -1;
	}
	
	new iCount;
	if(iFileHeader[FH_frames] != INVALID_HANDLE)
	{
		for(new i=1;i<=MaxClients;i++)
		{
			// Stop the bots from mimicing this one
			if(g_hBotMimicsRecord[i] == iFileHeader[FH_frames])
			{
				BotMimic_StopPlayerMimic(i);
				iCount++;
			}
		}
		
		// Discard the frames
		CloseHandle(iFileHeader[FH_frames]);
	}
	
	new String:sCategory[64];
	GetTrieString(g_hLoadedRecordsCategory, sPath, sCategory, sizeof(sCategory));
	
	RemoveFromTrie(g_hLoadedRecords, sPath);
	RemoveFromTrie(g_hLoadedRecordsCategory, sPath);
	RemoveFromArray(g_hSortedRecordList, FindStringInArray(g_hSortedRecordList, sPath));
	
	// Delete the file
	if(FileExists(sPath))
	{
		DeleteFile(sPath);
	}
	
	Call_StartForward(g_hfwdOnRecordDeleted);
	Call_PushString(iFileHeader[FH_recordName]);
	Call_PushString(sCategory);
	Call_PushString(sPath);
	Call_Finish();
	
	return iCount;
}

public IsPlayerRecording(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return false;
	}
	
	return g_hRecording[client] != INVALID_HANDLE;
}

public IsPlayerMimicing(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return false;
	}
	
	return g_hBotMimicsRecord[client] != INVALID_HANDLE;
}

public GetRecordPlayerMimics(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return;
	}
	
	if(!BotMimic_IsPlayerMimicing(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
		return;
	}
	
	new iLen = GetNativeCell(3);
	new String:sPath[iLen];
	GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, iLen);
	SetNativeString(2, sPath, iLen);
}

public StopPlayerMimic(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return;
	}
	
	if(!BotMimic_IsPlayerMimicing(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
		return;
	}
	
	new String:sPath[PLATFORM_MAX_PATH];
	GetFileFromFrameHandle(g_hBotMimicsRecord[client], sPath, sizeof(sPath));
	
	g_hBotMimicsRecord[client] = INVALID_HANDLE;
	g_iBotMimicTick[client] = 0;
	g_iBotMimicRecordTickCount[client] = 0;
	g_bValidTeleportCall[client] = false;
	
	new iFileHeader[FileHeader];
	GetTrieArray(g_hLoadedRecords, sPath, iFileHeader[0], _:FileHeader);
	
	//SDKUnhook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitchTo);
	
	new String:sCategory[64];
	GetTrieString(g_hLoadedRecordsCategory, sPath, sCategory, sizeof(sCategory));
	
	Call_StartForward(g_hfwdOnPlayerStopsMimicing);
	Call_PushCell(client);
	Call_PushString(iFileHeader[FH_recordName]);
	Call_PushString(sCategory);
	Call_PushString(sPath);
	Call_Finish();
}

public PlayRecordFromFile(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return _:BM_BadClient;
	}
	
	new iLen;
	GetNativeStringLength(2, iLen);
	decl String:sPath[iLen+1];
	GetNativeString(2, sPath, iLen+1);
	
	if(!FileExists(sPath))
		return _:BM_FileNotFound;
	
	return _:PlayRecord(client, sPath);
}

public FindRecordByName(Handle:plugin, numParams)
{
	new iLen;
	GetNativeStringLength(1, iLen);
	decl String:sName[iLen+1];
	GetNativeString(1, sName, iLen+1);
	
	decl String:sPath[PLATFORM_MAX_PATH];
	new iSize = GetArraySize(g_hSortedRecordList);
	new iFileHeader[FileHeader], iRecentTimeStamp, String:sRecentPath[PLATFORM_MAX_PATH];
	for(new i=0;i<iSize;i++)
	{
		GetArrayString(g_hSortedRecordList, i, sPath, sizeof(sPath));
		GetTrieArray(g_hLoadedRecords, sPath, iFileHeader[0], _:FileHeader);
		if(StrEqual(sName, iFileHeader[FH_recordName]))
		{
			if(iRecentTimeStamp == 0 || iRecentTimeStamp < iFileHeader[FH_recordEndTime])
			{
				iRecentTimeStamp = iFileHeader[FH_recordEndTime];
				strcopy(sRecentPath, sizeof(sRecentPath), sPath);
			}
		}
	}
	
	if(!iRecentTimeStamp || !FileExists(sRecentPath))
		return _:BM_FileNotFound;
	
	return _:BM_NoError;
}

public PlayRecordByName(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		return _:BM_BadClient;
	}
	
	new iLen;
	GetNativeStringLength(2, iLen);
	decl String:sName[iLen+1];
	GetNativeString(2, sName, iLen+1);
	
	decl String:sPath[PLATFORM_MAX_PATH];
	new iSize = GetArraySize(g_hSortedRecordList);
	new iFileHeader[FileHeader], iRecentTimeStamp, String:sRecentPath[PLATFORM_MAX_PATH];
	for(new i=0;i<iSize;i++)
	{
		GetArrayString(g_hSortedRecordList, i, sPath, sizeof(sPath));
		GetTrieArray(g_hLoadedRecords, sPath, iFileHeader[0], _:FileHeader);
		if(StrEqual(sName, iFileHeader[FH_recordName]))
		{
			if(iRecentTimeStamp == 0 || iRecentTimeStamp < iFileHeader[FH_recordEndTime])
			{
				iRecentTimeStamp = iFileHeader[FH_recordEndTime];
				strcopy(sRecentPath, sizeof(sRecentPath), sPath);
			}
		}
	}
	
	if(!iRecentTimeStamp || !FileExists(sRecentPath))
		return _:BM_FileNotFound;
	
	return _:PlayRecord(client, sRecentPath);
}

public ResetPlayback(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Bad player index %d", client);
		return;
	}
	
	if(!BotMimic_IsPlayerMimicing(client))
	{
		ThrowNativeError(SP_ERROR_NATIVE, "Player is not mimicing.");
		return;
	}
	
	g_iBotMimicTick[client] = 0;
	g_bValidTeleportCall[client] = false;
}

public GetFileHeaders(Handle:plugin, numParams)
{
	new iLen;
	GetNativeStringLength(1, iLen);
	decl String:sPath[iLen+1];
	GetNativeString(1, sPath, iLen+1);
	
	if(!FileExists(sPath))
	{
		return _:BM_FileNotFound;
	}
	
	new iFileHeader[FileHeader];
	if(!GetTrieArray(g_hLoadedRecords, sPath, iFileHeader[0], _:FileHeader))
	{
		decl String:sCategory[64];
		if(!GetTrieString(g_hLoadedRecordsCategory, sPath, sCategory, sizeof(sCategory)))
			strcopy(sCategory, sizeof(sCategory), DEFAULT_CATEGORY);
		new BMError:error = LoadRecordFromFile(sPath, sCategory, iFileHeader, true, false);
		if(error != BM_NoError)
			return _:error;
	}
	
	new iExposedFileHeader[BMFileHeader];
	iExposedFileHeader[BMFH_binaryFormatVersion] = iFileHeader[FH_binaryFormatVersion];
	iExposedFileHeader[BMFH_recordEndTime] = iFileHeader[FH_recordEndTime];
	strcopy(iExposedFileHeader[BMFH_recordName], MAX_RECORD_NAME_LENGTH, iFileHeader[FH_recordName]);
	iExposedFileHeader[BMFH_tickCount] = iFileHeader[FH_tickCount];
	Array_Copy(iFileHeader[BMFH_initialPosition], iExposedFileHeader[FH_initialPosition], 3);
	Array_Copy(iFileHeader[BMFH_initialAngles], iExposedFileHeader[FH_initialAngles], 3);
	
	
	new iSize = _:BMFileHeader;
	if(numParams > 2)
		iSize = GetNativeCell(3);
	if(iSize > _:BMFileHeader)
		iSize = _:BMFileHeader;
	
	SetNativeArray(2, iExposedFileHeader[0], iSize);
	return _:BM_NoError;
}

public ChangeRecordName(Handle:plugin, numParams)
{
	new iLen;
	GetNativeStringLength(1, iLen);
	decl String:sPath[iLen+1];
	GetNativeString(1, sPath, iLen+1);
	
	if(!FileExists(sPath))
	{
		return _:BM_FileNotFound;
	}
	
	decl String:sCategory[64];
	if(!GetTrieString(g_hLoadedRecordsCategory, sPath, sCategory, sizeof(sCategory)))
		strcopy(sCategory, sizeof(sCategory), DEFAULT_CATEGORY);
	
	new iFileHeader[FileHeader];
	if(!GetTrieArray(g_hLoadedRecords, sPath, iFileHeader[0], _:FileHeader))
	{
		new BMError:error = LoadRecordFromFile(sPath, sCategory, iFileHeader, false, false);
		if(error != BM_NoError)
			return _:error;
	}
	
	// Load the whole record first or we'd lose the frames!
				if (iFileHeader[FH_frames] == INVALID_HANDLE)
					LoadRecordFromFile(sPath, sCategory, iFileHeader, false, true);
				
				GetNativeStringLength(2, iLen);
				decl String:sName[iLen + 1];
				GetNativeString(2, sName, iLen + 1);
				
				strcopy(iFileHeader[FH_recordName], MAX_RECORD_NAME_LENGTH, sName);
				SetTrieArray(g_hLoadedRecords, sPath, iFileHeader[0], _:FileHeader);
				
				WriteRecordToDisk(sPath, iFileHeader);
				
				return _:BM_NoError;
			}
			
			public GetLoadedRecordCategoryList(Handle:plugin, numParams)
			{
				return _:g_hSortedCategoryList;
			}
			
			public GetLoadedRecordList(Handle:plugin, numParams)
			{
				return _:g_hSortedRecordList;
			}
			
			public GetFileCategory(Handle:plugin, numParams)
			{
				new iLen;
				GetNativeStringLength(1, iLen);
				decl String:sPath[iLen + 1];
				GetNativeString(1, sPath, iLen + 1);
				
				iLen = GetNativeCell(3);
				new String:sCategory[iLen];
				new bool:bFound = GetTrieString(g_hLoadedRecordsCategory, sPath, sCategory, iLen);
				
				SetNativeString(2, sCategory, iLen);
				return _:bFound;
			}
			
			
			/**
 * Helper functions
 */
			
			ParseRecordsInDirectory(const String:sPath[], const String:sCategory[], bool:subdir)
			{
				decl String:sMapFilePath[PLATFORM_MAX_PATH];
				// We already are in the map folder? Don't add it again!
				if (subdir)
				{
					strcopy(sMapFilePath, sizeof(sMapFilePath), sPath);
				}
				// We're in a category. add the mapname to load the correct records for the current map
				else
				{
					decl String:sMapName[64];
					GetCurrentMap(sMapName, sizeof(sMapName));
					Format(sMapFilePath, sizeof(sMapFilePath), "%s/%s", sPath, sMapName);
				}
				
				new Handle:hDir = OpenDirectory(sMapFilePath);
				if (hDir == INVALID_HANDLE)
					return;
				
				new String:sFile[64], FileType:fileType, String:sFilePath[PLATFORM_MAX_PATH], iFileHeader[FileHeader];
				while (ReadDirEntry(hDir, sFile, sizeof(sFile), fileType))
				{
					switch (fileType)
					{
						// This is a record for this map.
						case FileType_File:
						{
							Format(sFilePath, sizeof(sFilePath), "%s/%s", sMapFilePath, sFile);
							LoadRecordFromFile(sFilePath, sCategory, iFileHeader, true, false);
						}
						// There's a subdir containing more records.
						case FileType_Directory:
						{
							// INFINITE RECURSION ANYONE?
							if (StrEqual(sFile, ".") || StrEqual(sFile, ".."))
								continue;
							
							Format(sFilePath, sizeof(sFilePath), "%s/%s", sMapFilePath, sFile);
							ParseRecordsInDirectory(sFilePath, sCategory, true);
						}
					}
					
				}
				CloseHandle(hDir);
			}
			
			WriteRecordToDisk(const String:sPath[], iFileHeader[FileHeader])
			{
				new Handle:hFile = OpenFile(sPath, "wb");
				if (hFile == INVALID_HANDLE)
				{
					LogError("Can't open the record file for writing! (%s)", sPath);
					return;
				}
				
				WriteFileCell(hFile, BM_MAGIC, 4);
				WriteFileCell(hFile, iFileHeader[FH_binaryFormatVersion], 1);
				WriteFileCell(hFile, iFileHeader[FH_recordEndTime], 4);
				WriteFileCell(hFile, strlen(iFileHeader[FH_recordName]), 1);
				WriteFileString(hFile, iFileHeader[FH_recordName], false);
				
				WriteFile(hFile, _:iFileHeader[FH_initialPosition], 3, 4);
				WriteFile(hFile, _:iFileHeader[FH_initialAngles], 2, 4);
				
				new iTickCount = iFileHeader[FH_tickCount];
				WriteFileCell(hFile, iTickCount, 4);
				
				
				// Write all bookmarks
				
				new iFrame[FrameInfo];
				for (new i = 0; i < iTickCount; i++)
				{
					GetArrayArray(iFileHeader[FH_frames], i, iFrame[0], _:FrameInfo);
					WriteFile(hFile, iFrame[0], _:FrameInfo, 4);
				}
				
				CloseHandle(hFile);
			}
			
			BMError:LoadRecordFromFile(const String:path[], const String:sCategory[], headerInfo[FileHeader], bool:onlyHeader, bool:forceReload)
			{
				if (!FileExists(path))
					return BM_FileNotFound;
				
				// Already loaded that file?
				new bool:bAlreadyLoaded = false;
				if (GetTrieArray(g_hLoadedRecords, path, headerInfo[0], _:FileHeader))
				{
					// Header already loaded.
					if (onlyHeader && !forceReload)
						return BM_NoError;
					
					bAlreadyLoaded = true;
				}
				
				new Handle:hFile = OpenFile(path, "rb");
				if (hFile == INVALID_HANDLE)
					return BM_FileNotFound;
				
				new iMagic;
				ReadFileCell(hFile, iMagic, 4);
				if (iMagic != BM_MAGIC)
				{
					CloseHandle(hFile);
					return BM_BadFile;
				}
				
				new iBinaryFormatVersion;
				ReadFileCell(hFile, iBinaryFormatVersion, 1);
				headerInfo[FH_binaryFormatVersion] = iBinaryFormatVersion;
				
				if (iBinaryFormatVersion > BINARY_FORMAT_VERSION)
				{
					CloseHandle(hFile);
					return BM_NewerBinaryVersion;
				}
				
				new iRecordTime, iNameLength;
				ReadFileCell(hFile, iRecordTime, 4);
				ReadFileCell(hFile, iNameLength, 1);
				decl String:sRecordName[iNameLength + 1];
				ReadFileString(hFile, sRecordName, iNameLength + 1, iNameLength);
				sRecordName[iNameLength] = '\0';
				
				ReadFile(hFile, _:headerInfo[FH_initialPosition], 3, 4);
				ReadFile(hFile, _:headerInfo[FH_initialAngles], 2, 4);
				
				new iTickCount;
				ReadFileCell(hFile, iTickCount, 4);
				
				headerInfo[FH_recordEndTime] = iRecordTime;
				strcopy(headerInfo[FH_recordName], MAX_RECORD_NAME_LENGTH, sRecordName);
				headerInfo[FH_tickCount] = iTickCount;
				
				headerInfo[FH_frames] = INVALID_HANDLE;
				
				//PrintToServer("Record %s:", sRecordName);
				//PrintToServer("File %s:", path);
				//PrintToServer("EndTime: %d, BinaryVersion: 0x%x, ticks: %d, initialPosition: %f,%f,%f, initialAngles: %f,%f,%f", iRecordTime, iBinaryFormatVersion, iTickCount, headerInfo[FH_initialPosition][0], headerInfo[FH_initialPosition][1], headerInfo[FH_initialPosition][2], headerInfo[FH_initialAngles][0], headerInfo[FH_initialAngles][1], headerInfo[FH_initialAngles][2]);
				
				
				SetTrieArray(g_hLoadedRecords, path, headerInfo[0], _:FileHeader);
				SetTrieString(g_hLoadedRecordsCategory, path, sCategory);
				
				if (!bAlreadyLoaded)
					PushArrayString(g_hSortedRecordList, path);
				
				if (FindStringInArray(g_hSortedCategoryList, sCategory) == -1)
					PushArrayString(g_hSortedCategoryList, sCategory);
				
				// Sort it by record end time
				SortRecordList();
				
				if (onlyHeader)
				{
					CloseHandle(hFile);
					return BM_NoError;
				}
				
				// Read in all the saved frames
				new Handle:hRecordFrames = CreateArray(_:FrameInfo);
				
				new iFrame[FrameInfo];
				for (new i = 0; i < iTickCount; i++)
				{
					ReadFile(hFile, iFrame[0], _:FrameInfo, 4);
					PushArrayArray(hRecordFrames, iFrame[0], _:FrameInfo);
				}
				
				headerInfo[FH_frames] = hRecordFrames;
				
				CloseHandle(hFile);
				return BM_NoError;
			}
			
			SortRecordList()
			{
				SortADTArrayCustom(g_hSortedRecordList, SortFuncADT_ByEndTime);
				SortADTArray(g_hSortedCategoryList, Sort_Descending, Sort_String);
			}
			
			public SortFuncADT_ByEndTime(index1, index2, Handle:array, Handle:hndl)
			{
				new String:path1[PLATFORM_MAX_PATH], String:path2[PLATFORM_MAX_PATH];
				GetArrayString(array, index1, path1, sizeof(path1));
				GetArrayString(array, index2, path2, sizeof(path2));
				
				new header1[FileHeader], header2[FileHeader];
				GetTrieArray(g_hLoadedRecords, path1, header1[0], _:FileHeader);
				GetTrieArray(g_hLoadedRecords, path2, header2[0], _:FileHeader);
				
				return header1[FH_recordEndTime] - header2[FH_recordEndTime];
			}
			
			BMError:PlayRecord(client, const String:path[])
			{
				// He's currently recording. Don't start to play some record on him at the same time.
				if (g_hRecording[client] != INVALID_HANDLE)
				{
					return BM_BadClient;
				}
				
				new iFileHeader[FileHeader];
				GetTrieArray(g_hLoadedRecords, path, iFileHeader[0], _:FileHeader);
				
				// That record isn't fully loaded yet. Do that now.
				if (iFileHeader[FH_frames] == INVALID_HANDLE)
				{
					decl String:sCategory[64];
					if (!GetTrieString(g_hLoadedRecordsCategory, path, sCategory, sizeof(sCategory)))
						strcopy(sCategory, sizeof(sCategory), DEFAULT_CATEGORY);
					new BMError:error = LoadRecordFromFile(path, sCategory, iFileHeader, false, true);
					if (error != BM_NoError)
						return error;
				}
				
				g_hBotMimicsRecord[client] = iFileHeader[FH_frames];
				g_iBotMimicTick[client] = 0;
				g_iBotMimicRecordTickCount[client] = iFileHeader[FH_tickCount];
				
				Array_Copy(iFileHeader[FH_initialPosition], g_fInitialPosition[client], 3);
				Array_Copy(iFileHeader[FH_initialAngles], g_fInitialAngles[client], 3);
				
				//SDKHook(client, SDKHook_WeaponCanSwitchTo, Hook_WeaponCanSwitchTo);
				
				// Respawn him to get him moving!
				if (IsClientInGame(client) && !IsPlayerAlive(client) && GetClientTeam(client) >= CS_TEAM_T)
					CS_RespawnPlayer(client);
				
				new String:sCategory[64];
				GetTrieString(g_hLoadedRecordsCategory, path, sCategory, sizeof(sCategory));
				
				new Action:result;
				Call_StartForward(g_hfwdOnPlayerStartsMimicing);
				Call_PushCell(client);
				Call_PushString(iFileHeader[FH_recordName]);
				Call_PushString(sCategory);
				Call_PushString(path);
				Call_Finish(result);
				
				// Someone doesn't want this guy to play that record.
				if (result >= Plugin_Handled)
				{
					g_hBotMimicsRecord[client] = INVALID_HANDLE;
					g_iBotMimicRecordTickCount[client] = 0;
				}
				
				return BM_NoError;
			}
			
			stock bool:CheckCreateDirectory(const String:sPath[], mode)
			{
				if (!DirExists(sPath))
				{
					CreateDirectory(sPath, mode);
					if (!DirExists(sPath))
					{
						LogError("Can't create a new directory. Please create one manually! (%s)", sPath);
						return false;
					}
				}
				return true;
			}
			
			stock GetFileFromFrameHandle(Handle:frames, String:path[], maxlen)
			{
				new iSize = GetArraySize(g_hSortedRecordList);
				decl String:sPath[PLATFORM_MAX_PATH], iFileHeader[FileHeader];
				for (new i = 0; i < iSize; i++)
				{
					GetArrayString(g_hSortedRecordList, i, sPath, sizeof(sPath));
					GetTrieArray(g_hLoadedRecords, sPath, iFileHeader[0], _:FileHeader);
					if (iFileHeader[FH_frames] != frames)
						continue;
					
					strcopy(path, maxlen, sPath);
					break;
				}
			} 