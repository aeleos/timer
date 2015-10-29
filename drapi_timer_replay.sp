/*   <DR.API TIMER REPLAY> (c) by <De Battista Clint - (http://doyou.watch)  */
/*                                                                           */
/*                  <DR.API TIMER REPLAY> is licensed under a                */
/*                        GNU General Public License                         */
/*																			 */
/*      You should have received a copy of the license along with this       */
/*            work.  If not, see <http://www.gnu.org/licenses/>.             */
//***************************************************************************//
//***************************************************************************//
//****************************DR.API TIMER REPLAY****************************//
//***************************************************************************//
//***************************************************************************//

#pragma semicolon 1

//***********************************//
//*************DEFINE****************//
//***********************************//
#define CVARS 							FCVAR_PLUGIN|FCVAR_SPONLY|FCVAR_NOTIFY
#define DEFAULT_FLAGS 					FCVAR_PLUGIN|FCVAR_NOTIFY
#define TAG_CHAT						"[TIMER REPLAY] -"
#define MAX_BOTS						4
#define MAX_WAYS						10000

//***********************************//
//*************INCLUDE***************//
//***********************************//

#undef REQUIRE_PLUGIN
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#include <cstrike>
#include <autoexec>
#include <timer>
#include <timer-mysql>
#include <timer-stocks>
#include <timer-physics>
#include <timer-mapzones>
#include <timer-worldrecord>
#include <botmimic>

#pragma newdecls required

//***********************************//
//***********PARAMETERS**************//
//***********************************//

//Handle
Handle cvar_active_timer_replay_dev;

Handle g_hSQL = INVALID_HANDLE;
//Handle H_TimerShowTheWay						= INVALID_HANDLE;

//Bool
bool B_active_timer_replay_dev = false;
bool B_IsJump[MAXPLAYERS + 1];
//bool B_TimerStarted[MAXPLAYERS + 1];

//Strings
char Sql_UpdateReplayPath[] = "UPDATE round SET replaypath = '%s' WHERE auth LIKE \"%%%s%%\" AND map = '%s' AND style = '%d' AND track = '0' AND rank = '1'";
char Sql_SelectWrReplay[] = "SELECT replaypath, style, time, name, jumps, avgspeed, maxspeed FROM round WHERE map = '%s' AND style = '%d' AND track = '0' ORDER BY time ASC LIMIT %d";

char S_FileReplay[MAX_STYLES][PLATFORM_MAX_PATH];
char S_FileReplayTime[MAX_STYLES][16];
char S_FileReplayName[MAX_STYLES][64];
char S_FileReplayJump[MAX_STYLES][16];
char S_FileReplayAvgspeed[MAX_STYLES][16];
char S_FileReplayMaxspeed[MAX_STYLES][16];
char S_ReplayName[MAX_STYLES][MAX_NAME_LENGTH];
//Floats
float F_Timer[MAXPLAYERS + 1];

//float F_ShowTheWayPos[MAX_BOTS][MAX_WAYS][3];

//Customs
int C_FileReplayStyle;
int C_StyleTarget[MAXPLAYERS + 1];


//int C_ShowTheWayCount;
//int C_ShowThePath[MAXPLAYERS + 1];
//int BeamSpriteFollow;

//Informations plugin
public Plugin myinfo = 
{
	name = "[TIMER] DR.API TIMER REPLAY", 
	author = "Dr. Api", 
	description = "DR.API TIMER REPLAY by Dr. Api", 
	version = PL_VERSION, 
	url = "http://zombie4ever.eu"
}
/***********************************************************/
/*********************** PLUGIN START **********************/
/***********************************************************/
public void OnPluginStart()
{
	LoadTranslations("drapi/drapi_timer_replay.phrases");
	AutoExecConfig_SetFile("drapi_timer_replay", "sourcemod/drapi");
	
	AutoExecConfig_CreateConVar("drapi_timer_replay_version", PL_VERSION, "Version", CVARS);
	
	cvar_active_timer_replay_dev = AutoExecConfig_CreateConVar("drapi_active_timer_replay_dev", "0", "Enable/Disable Dev Mod", DEFAULT_FLAGS, true, 0.0, true, 1.0);
	
	HookEventsCvars();
	
	AutoExecConfig_ExecuteFile();
	
	//RegConsoleCmd("sm_way", Command_Way, "trun off/on way");
}

/***********************************************************/
/************************ PLUGIN END ***********************/
/***********************************************************/
public void OnPluginEnd()
{
	int i = 1;
	while (i <= MaxClients)
	{
		if (IsClientInGame(i))
		{
			if (BotMimic_IsPlayerRecording(i))
			{
				BotMimic_StopRecording(i, false);
			}
		}
		i++;
	}
}

/***********************************************************/
/******************** ON TERMINATE ROUND *******************/
/***********************************************************/
public Action CS_OnTerminateRound(float &delay, CSRoundEndReason &reason)
{
	return Plugin_Handled;
}

/***********************************************************/
/**************** WHEN CLIENT PUT IN SERVER ****************/
/***********************************************************/
public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
	{
		char ClientName[32], TBuffer[100], NameBuffer[32];
		int Cacheid, total;
		float time;
		//int style = -1;
		if (C_FileReplayStyle == 1)
		{
			Timer_GetRecordHolderName(1, 0, 1, ClientName, 32);
			Timer_GetStyleRecordWRStats(1, 0, Cacheid, time, total);
			Timer_SecondsToTime(time, TBuffer, sizeof(TBuffer), 2);
			Format(NameBuffer, 32, "%s - %s", TBuffer, ClientName);
			SetClientName(client, NameBuffer);
			strcopy(S_ReplayName[C_FileReplayStyle], MAX_NAME_LENGTH, NameBuffer);
			CS_SetClientClanTag(client, "Auto");
			CS_SetClientContributionScore(client, 100 - C_FileReplayStyle);
			Timer_SetStyle(client, 1);
			//style = 0;
		}
		/*
		else if (C_FileReplayStyle == 3)
		{
			Timer_GetRecordHolderName(3, 0, 1, ClientName, 32);
			Timer_GetStyleRecordWRStats(3, 0, Cacheid, time, total);
			Timer_SecondsToTime(time, TBuffer, sizeof(TBuffer), 2);
			Format(NameBuffer, 32, "%s - %s", TBuffer, ClientName);
			SetClientName(client, NameBuffer);
			strcopy(S_ReplayName[C_FileReplayStyle], MAX_NAME_LENGTH, NameBuffer);
			CS_SetClientClanTag(client, "W-only");
			CS_SetClientContributionScore(client, 100 - C_FileReplayStyle);
			Timer_SetStyle(client, 3);
		}
		*/
		Handle dataPackHandle;
		CreateDataTimer(2.0, TimerData_OnBotJoin, dataPackHandle);
		WritePackCell(dataPackHandle, GetClientUserId(client));
		WritePackString(dataPackHandle, S_FileReplay[C_FileReplayStyle]);
		//WritePackCell(dataPackHandle, style);
		if (B_active_timer_replay_dev)
		{
			LogMessage("%N: %s", client, S_FileReplay[C_FileReplayStyle]);
		}
	}
	else
	{
		if (IsClientInGame(client) && BotMimic_IsPlayerRecording(client))
		{
			BotMimic_StopRecording(client, false);
		}
	}
	
}


void StripWeapons(int client) 
{
    int wp;
    for (int i = 0; i < 6; i++) {
        wp = GetPlayerWeaponSlot(client, i);
        if(IsValidEntity(wp)) {
            RemovePlayerItem(client, wp);
        }
    }
}  
/***********************************************************/
/******************** CMD PLAYER CHAT CP *******************/
/***********************************************************/
/*
public Action Command_Way(int client, int args)
{
	C_ShowThePath[client] 		= !C_ShowThePath[client];
	CPrintToChat(client, "[{GREEN}TIMER{NORMAL}] Show the way %s {NORMAL}[{RED}%i{NORMAL} positions]", (C_ShowThePath[client]) ? "{GREEN}On" : "{RED}Off", C_ShowTheWayCount);
	return Plugin_Handled;
}
*/
/***********************************************************/
/***************** TIMER DATA ON BOT JOIN ******************/
/***********************************************************/
public Action TimerData_OnBotJoin(Handle timer, Handle dataPackHandle)
{
	ResetPack(dataPackHandle);
	int client = GetClientOfUserId(ReadPackCell(dataPackHandle));
	char S_file[PLATFORM_MAX_PATH];
	ReadPackString(dataPackHandle, S_file, PLATFORM_MAX_PATH);
	//int style 		= ReadPackCell(dataPackHandle);
	
	if (client > 0 && IsClientInGame(client) && !IsPlayerAlive(client))
	{
		CS_SwitchTeam(client, CS_TEAM_T);
		CS_SwitchTeam(client, CS_TEAM_CT);
		CS_RespawnPlayer(client);
	}
	
	if (FileExists(S_file))
	{
		BotMimic_PlayRecordFromFile(client, S_file);
		//ShowTheWay(client);
		StripWeapons(client);
	}
}

/***********************************************************/
/********************** SHOW THE WAY ***********************/
/***********************************************************/
/*
void ShowTheWay(int client)
{
	if(IsFakeClient(client))
	{
		char S_botname[64];
		GetClientName(client, S_botname, 64);
		if(StrEqual(S_botname, "Auto[normal]", false))
		{
			B_TimerStarted[client] 	= true;
			C_ShowTheWayCount		= 0;
			H_TimerShowTheWay = CreateTimer(0.1, Timer_ShowTheWay, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}
*/
/***********************************************************/
/******************* TIMER SHOW THE WAY ********************/
/***********************************************************/
/*
public Action Timer_ShowTheWay(Handle timer, any client)
{
	if(IsClientInGame(client) && IsPlayerAlive(client) && IsFakeClient(client) && B_TimerStarted[client])
	{
		float pos[3];
		GetClientAbsOrigin(client, pos);

		if(C_ShowTheWayCount < MAX_WAYS)
		{
			F_ShowTheWayPos[0][C_ShowTheWayCount] = pos;
		}

		if(C_ShowTheWayCount >= MAX_WAYS || B_TimerStarted[client] == false)
		{
			ClearTimer(H_TimerShowTheWay);
		}

		//LogMessage("[%i] - %N : %f", count, client, F_ShowTheWayPos[0][count]);
		C_ShowTheWayCount++;
	}
}
*/
/***********************************************************/
/***************** WHEN CLIENT DISCONNECT ******************/
/***********************************************************/
public void OnClientDisconnect(int client)
{
	if (IsClientInGame(client))
	{
		if (BotMimic_IsPlayerRecording(client))
		{
			BotMimic_StopRecording(client, false);
		}
	}
}

/***********************************************************/
/******************** WHEN CVAR CHANGED ********************/
/***********************************************************/
void HookEventsCvars()
{
	HookConVarChange(cvar_active_timer_replay_dev, Event_CvarChange);
}

/***********************************************************/
/******************** WHEN CVARS CHANGE ********************/
/***********************************************************/
public void Event_CvarChange(Handle cvar, const char[] oldValue, const char[] newValue)
{
	UpdateState();
}

/***********************************************************/
/*********************** UPDATE STATE **********************/
/***********************************************************/
void UpdateState()
{
	B_active_timer_replay_dev = GetConVarBool(cvar_active_timer_replay_dev);
}

/***********************************************************/
/********************* WHEN MAP START **********************/
/***********************************************************/
public void OnMapStart()
{
	ServerCommand("bot_knives_only");
	SetConVarInt(FindConVar("bot_join_after_player"), 0);
	SetConVarString(FindConVar("bot_quota_mode"), "normal");
	
	//SetConVarInt(FindConVar("sm_reserved_slots"), 4);
	//SetConVarInt(FindConVar("sm_hide_slots"), 1);
	//SetConVarInt(FindConVar("sm_reserve_type"), 2);
	//SetConVarInt(FindConVar("sm_reserve_maxadmins"), 0);
	
	char S_pathsm[PLATFORM_MAX_PATH], S_pathsmbackup[PLATFORM_MAX_PATH], S_pathsmbackupmap[PLATFORM_MAX_PATH], S_mapname[64];
	
	GetCurrentMap(S_mapname, sizeof(S_mapname));
	BuildPath(Path_SM, S_pathsm, sizeof(S_pathsm), "data/botmimic/bhop/wr/%s", S_mapname);
	
	if (!DirExists(S_pathsm))
	{
		CreateDirectory(S_pathsm, 511);
	}
	
	BuildPath(Path_SM, S_pathsmbackup, sizeof(S_pathsmbackup), "data/botmimic/bhop/wr/backup");
	if (!DirExists(S_pathsmbackup))
	{
		CreateDirectory(S_pathsmbackup, 511);
	}
	
	BuildPath(Path_SM, S_pathsmbackupmap, sizeof(S_pathsmbackupmap), "data/botmimic/bhop/wr/backup/%s", S_mapname);
	if (!DirExists(S_pathsmbackupmap))
	{
		CreateDirectory(S_pathsmbackupmap, 511);
	}
	
	if (g_hSQL == INVALID_HANDLE)
	{
		ConnectSQL();
	}
	
	//C_ShowTheWayCount = 0;
	//CreateTimer(0.1, Timer_HUDTimer_CSGO, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	//CreateTimer(1.0, Timer_ShowPathColor, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	//CreateTimer(60.0, Timer_ShowPathColorAdvert, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	CreateTimer(10.0, Timer_ReplayWR, 1, TIMER_FLAG_NO_MAPCHANGE);
	//CreateTimer(12.0, Timer_ReplayWR, 3, TIMER_FLAG_NO_MAPCHANGE);
	//CreateTimer(14.0, Timer_ReplayWR, 6, TIMER_FLAG_NO_MAPCHANGE);
	//CreateTimer(16.0, Timer_ReplayWR, 18, TIMER_FLAG_NO_MAPCHANGE);
	
	UpdateState();
	
	//BeamSpriteFollow 		= PrecacheModel("materials/sprites/laserbeam.vmt");
}

/***********************************************************/
/**************** WHEN MAP START REPLAY WR *****************/
/***********************************************************/
public Action Timer_ReplayWR(Handle timer, any style)
{
	ReplayWR(style);
}

/***********************************************************/
/********************** WHEN MAP END ***********************/
/***********************************************************/
public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (BotMimic_IsPlayerRecording(i))
			{
				BotMimic_StopRecording(i, false);
			}
		}
	}
}
/***********************************************************/
/***************** ON TIMER SQL CONNECTED ******************/
/***********************************************************/
public int OnTimerSqlConnected(Handle sql)
{
	g_hSQL = sql;
	g_hSQL = INVALID_HANDLE;
	CreateTimer(0.1, Timer_SQLReconnect, _, TIMER_FLAG_NO_MAPCHANGE);
}

/***********************************************************/
/******************** ON TIMER SQL STOP ********************/
/***********************************************************/
public int OnTimerSqlStop()
{
	g_hSQL = INVALID_HANDLE;
	CreateTimer(0.1, Timer_SQLReconnect, _, TIMER_FLAG_NO_MAPCHANGE);
}

/***********************************************************/
/*********************** SQL CONNECT ***********************/
/***********************************************************/
void ConnectSQL()
{
	g_hSQL = view_as<Handle>(Timer_SqlGetConnection());
	
	if (g_hSQL == INVALID_HANDLE)
	{
		CreateTimer(0.1, Timer_SQLReconnect, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

/***********************************************************/
/****************** TIMER SQL RECONNECTED ******************/
/***********************************************************/
public Action Timer_SQLReconnect(Handle timer, any data)
{
	ConnectSQL();
	return Plugin_Stop;
}

/***********************************************************/
/********************** TIMER STARTED **********************/
/***********************************************************/
public int OnTimerStarted(int client)
{
	if (IsClientInGame(client) && !IsFakeClient(client) && IsPlayerAlive(client) && !BotMimic_IsPlayerMimicing(client))
	{
		
		if (BotMimic_IsPlayerRecording(client))
		{
			BotMimic_StopRecording(client, false);
		}
		
		if (Timer_GetTrack(client) == 0)
		{
			char S_name[MAX_RECORD_NAME_LENGTH];
			Format(S_name, MAX_RECORD_NAME_LENGTH, "%N_%d", client, GetTime());
			
			BotMimic_StartRecording(client, S_name, "bhop/wr");
		}
		
		if (B_active_timer_replay_dev)
		{
			PrintToChat(client, "OnTimerStarted: %i", Timer_GetStyle(client));
		}
	}
}

/***********************************************************/
/*************** CLIENT START TOUCH ZONE TYPE **************/
/***********************************************************/
/*
public int OnClientStartTouchZoneType(int client, MapZoneType type)
{
	if(IsFakeClient(client))
	{
		char S_botname[64];
		GetClientName(client, S_botname, 64);
		if(StrEqual(S_botname, "Auto[normal]", false))
		{
			if(type == ZtEnd)
			{
				B_TimerStarted[client] = false;
			}
		}
	}
}
*/
/***********************************************************/
/*************** CLIENT START TOUCH ZONE TYPE **************/
/***********************************************************/
/*
public int OnClientEndTouchZoneType(int client, MapZoneType type)
{
	if(IsFakeClient(client))
	{
		char S_botname[64];
		GetClientName(client, S_botname, 64);
		if(StrEqual(S_botname, "Auto[normal]", false))
		{
			if(type == ZtStart)
			{
				B_TimerStarted[client] = true;
			}
		}
	}
}
*/
/***********************************************************/
/******************* TIMER WORLD RECORD ********************/
/***********************************************************/
public int OnTimerWorldRecord(int client, int track, int style, float time, float lasttime, int currentrank, int newrank)
{
	if (BotMimic_IsPlayerRecording(client))
	{
		char Query[2048], S_mapname[64];
		
		GetCurrentMap(S_mapname, 64);
		Format(Query, sizeof(Query), Sql_SelectWrReplay, S_mapname, style, 1);
		SQL_TQuery(g_hSQL, Sql_BackupWrReplayCallback, Query, _, DBPrio_High);
		
		Handle dataPackHandle;
		CreateDataTimer(0.1, TimerData_OnTimerWorldRecord, dataPackHandle);
		WritePackCell(dataPackHandle, GetClientUserId(client));
		WritePackCell(dataPackHandle, Timer_GetStyle(client));
		
		if (B_active_timer_replay_dev)
		{
			PrintToChat(client, "OnTimerWorldRecord");
		}
	}
}

/***********************************************************/
/************ TIMER DATA ON POST WEAPON EQUIP **************/
/***********************************************************/
public Action TimerData_OnTimerWorldRecord(Handle timer, Handle dataPackHandle)
{
	ResetPack(dataPackHandle);
	int client = GetClientOfUserId(ReadPackCell(dataPackHandle));
	int style = ReadPackCell(dataPackHandle);
	
	BotMimic_StopRecording(client, true);
	if (Timer_GetStyle(client) == 1)
		ReplayWR(style);
}

/***********************************************************/
/************** TIMER WORLD RECORD SAVE REPLAY *************/
/***********************************************************/
public int BotMimic_OnRecordSaved(int client, char[] name, char[] category, char[] subdir, char[] file)
{
	char Query[2048], S_mapname[64], S_steamid[64];
	GetCurrentMap(S_mapname, 64);
	
	GetClientAuthId(client, AuthId_Steam2, S_steamid, sizeof(S_steamid));
	ReplaceString(file, PLATFORM_MAX_PATH, "addons/sourcemod/data/botmimic/bhop/wr/", "");
	Format(Query, sizeof(Query), Sql_UpdateReplayPath, file, S_steamid[8], S_mapname, Timer_GetStyle(client));
	SQL_TQuery(g_hSQL, SQL_UpdateReplayPathCallback, Query, _, DBPrio_Low);
}

/***********************************************************/
/********************** BOT START MIMIC ********************/
/***********************************************************/
public Action BotMimic_OnPlayerStartsMimicing(int client, char[] name, char[] category, char[] path)
{
	F_Timer[client] = GetGameTime();
	
}

/***********************************************************/
/********************** BOT LOOP MIMIC *********************/
/***********************************************************/
public int BotMimic_OnPlayerMimicLoops(int client)
{
	F_Timer[client] = GetGameTime();
}

/***********************************************************/
/***************** TIMER SHOW PATH COLOR *******************/
/***********************************************************/
/*
public Action Timer_ShowPathColor(Handle timer)
{
	for(int path = 0; path < C_ShowTheWayCount; path++)
	{
		if(path > 0 && path < C_ShowTheWayCount - 1)
		{
			//LogMessage("[%i] : %f", path, F_ShowTheWayPos[0][path]);

			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && C_ShowThePath[i])
				{
					float pos[3];
					GetClientAbsOrigin(i, pos);
					float distance = GetVectorDistance(pos, F_ShowTheWayPos[0][path]);

					if(distance < 2000)
					{
						float firstpoint[3], secondpoint[3];

						firstpoint = F_ShowTheWayPos[0][path - 1];
						secondpoint = F_ShowTheWayPos[0][path];

						float distance2 = GetVectorDistance(firstpoint, secondpoint);

						if(distance2 < 1000)
						{
							TE_SetupBeamPoints(firstpoint, secondpoint, BeamSpriteFollow, 0, 0, 0, 0.99, 0.2, 0.2, 0, 0.0, {0,255,255,150}, 0);
							TE_SendToClient(i, 0.0);
						}
					}
				}
			}
		}
	}
}
*/
/***********************************************************/
/***************** TIMER SHOW PATH COLOR *******************/
/***********************************************************/
/*
public Action Timer_ShowPathColorAdvert(Handle timer)
{
	if(C_ShowTheWayCount > 0)
	{
		CPrintToChatAll("[{GREEN}TIMER{NORMAL}] type {RED}!way{NORMAL} to see the way, currently {RED}%i{NORMAL} positions.", C_ShowTheWayCount);
	}
}
*/
/***********************************************************/
/******************* SQL QUERY BACKUP **********************/
/***********************************************************/
public void Sql_BackupWrReplayCallback(Handle hOwner, Handle hQuery, const char[] strError, any data)
{
	if (hQuery == INVALID_HANDLE)
	{
		LogError("%s SQL Error: %s", TAG_CHAT, strError);
	}
	
	char S_file[PLATFORM_MAX_PATH], S_path[PLATFORM_MAX_PATH], S_newpath[PLATFORM_MAX_PATH];
	
	if (SQL_HasResultSet(hQuery))
	{
		while (SQL_FetchRow(hQuery))
		{
			SQL_FetchString(hQuery, 0, S_file, PLATFORM_MAX_PATH);
			
			if (!S_file[0])return;
			
			Format(S_path, PLATFORM_MAX_PATH, "addons/sourcemod/data/botmimic/bhop/wr/%s", S_file);
			Format(S_newpath, PLATFORM_MAX_PATH, "addons/sourcemod/data/botmimic/bhop/wr/backup/%s", S_file);
			
			RenameFile(S_newpath, S_path);
			
			if (B_active_timer_replay_dev)
			{
				PrintToChatAll("Sql_BackupWrReplayCallback: %s", S_path);
				PrintToChatAll("Sql_BackupWrReplayCallback: %s", S_newpath);
			}
		}
	}
}

/***********************************************************/
/******************* SQL QUERY UPDATE **********************/
/***********************************************************/
public void SQL_UpdateReplayPathCallback(Handle hOwner, Handle hQuery, const char[] strError, any data)
{
	if (hQuery == INVALID_HANDLE)
	{
		LogError("%s SQL Error: %s", TAG_CHAT, strError);
	}
}

/***********************************************************/
/*********************** REPLAY WR *************************/
/***********************************************************/
void ReplayWR(int style)
{
	char Query[2048], S_mapname[64];
	
	GetCurrentMap(S_mapname, 64);
	Format(Query, sizeof(Query), Sql_SelectWrReplay, S_mapname, style, 1);
	SQL_TQuery(g_hSQL, Sql_SelectWrReplayCallback, Query, _, DBPrio_Low);
}

/***********************************************************/
/******************* SQL QUERY SELECT **********************/
/***********************************************************/
public void Sql_SelectWrReplayCallback(Handle hOwner, Handle hQuery, const char[] strError, any data)
{
	if (hQuery == INVALID_HANDLE)
	{
		LogError("%s SQL Error: %s", TAG_CHAT, strError);
	}
	char S_file[PLATFORM_MAX_PATH], S_path[PLATFORM_MAX_PATH], S_time[16], S_name[64], S_jump[16], S_avgspeed[16], S_maxspeed[16];
	int style;
	
	if (SQL_HasResultSet(hQuery))
	{
		while (SQL_FetchRow(hQuery))
		{
			SQL_FetchString(hQuery, 0, S_file, PLATFORM_MAX_PATH);
			style = SQL_FetchInt(hQuery, 1);
			SQL_FetchString(hQuery, 2, S_time, 16);
			SQL_FetchString(hQuery, 3, S_name, 64);
			SQL_FetchString(hQuery, 4, S_jump, 16);
			SQL_FetchString(hQuery, 5, S_avgspeed, 16);
			SQL_FetchString(hQuery, 6, S_maxspeed, 16);
			
			if (!S_file[0])return;
			Format(S_path, PLATFORM_MAX_PATH, "addons/sourcemod/data/botmimic/bhop/wr/%s", S_file);
			strcopy(S_FileReplay[style], PLATFORM_MAX_PATH, S_path);
			
			if (!FileExists(S_FileReplay[style]))return;
			strcopy(S_FileReplayTime[style], 16, S_time);
			strcopy(S_FileReplayName[style], 64, S_name);
			strcopy(S_FileReplayJump[style], 16, S_jump);
			strcopy(S_FileReplayAvgspeed[style], 16, S_avgspeed);
			strcopy(S_FileReplayMaxspeed[style], 16, S_maxspeed);
			
			if (GetBotReplayed(style) == 0)
			{
				ServerCommand("bot_add");
				C_FileReplayStyle = -1;
				
				if (style == 1)C_FileReplayStyle = 1;
				//else if (style == 3)C_FileReplayStyle = 3;
			}
			else
			{
				int bot = GetBotReplayed(style);
				if (BotMimic_IsPlayerMimicing(bot))
				{
					BotMimic_StopPlayerMimic(bot);
				}
				if (!IsPlayerAlive(bot))
				{
					CS_SwitchTeam(bot, CS_TEAM_T);
					CS_SwitchTeam(bot, CS_TEAM_CT);
					CS_RespawnPlayer(bot);
				}
				
				BotMimic_PlayRecordFromFile(bot, S_FileReplay[style]);
				//ShowTheWay(bot);
				
			}
			
			if (B_active_timer_replay_dev)
			{
				LogMessage("%s", S_path);
			}
			
		}
	}
}

/***********************************************************/
/******************** TIMER HUD BOT MIMIC ******************/
/***********************************************************/

public Action Timer_HUDTimer_CSGO(Handle timer)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			UpdateHUD_CSGO(client);
		}
	}
	
	return Plugin_Continue;
}
public int OnTimerPaused(int client)
{
	BotMimic_PauseRecording(client);
}
public int OnTimerResumed(int client)
{
	BotMimic_ResumeRecording(client);
}
/***********************************************************/
/*********************** HUD BOT MIMIC *********************/
/***********************************************************/

void UpdateHUD_CSGO(int client)
{
	if (!IsClientInGame(client))
	{
		return;
	}
	
	int iClientToShow;
	int iObserverMode;
	
	iClientToShow = client;
	
	if (!IsPlayerAlive(client) || IsClientObserver(client))
	{
		iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		if (iObserverMode == SPECMODE_FIRSTPERSON || iObserverMode == SPECMODE_3RDPERSON)
		{
			iClientToShow = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			
			if (iClientToShow <= 0 || iClientToShow > MaxClients || !IsFakeClient(iClientToShow))
			{
				return;
			}
		}
		else
		{
			return;
		}
		
		char S_botname[64];
		GetClientName(iClientToShow, S_botname, 64);
		
		if (StrEqual(S_botname, "Auto[normal]", false))
		{
			C_StyleTarget[client] = 0;
		}
		else if (StrEqual(S_botname, "Legit", false))
		{
			C_StyleTarget[client] = 3;
		}
		else if (StrEqual(S_botname, "Auto[no boost]", false))
		{
			C_StyleTarget[client] = 6;
		}
		else if (StrEqual(S_botname, "3rdPerson", false))
		{
			C_StyleTarget[client] = 18;
		}
		
		char centerText[1024], S_record[48];
		
		Timer_SecondsToTime(StringToFloat(S_FileReplayTime[C_StyleTarget[client]]), S_record, sizeof(S_record), 2);
		
		Format(S_record, 48, "%s", S_record);
		
		//1ST LINE
		Format(centerText, sizeof(centerText), "%T", "WR", client, S_record);
		Format(centerText, sizeof(centerText), "%T", "Botname", client, centerText, iClientToShow);
		
		Format(centerText, sizeof(centerText), "%T", "Jumps", client, centerText, S_FileReplayJump[C_StyleTarget[client]]);
		
		//2ND LINE
		float currentspeed;
		Timer_GetCurrentSpeed(iClientToShow, currentspeed);
		
		float currenttime;
		
		char S_currenttime[48];
		currenttime = GetGameTime() - F_Timer[iClientToShow];
		Timer_SecondsToTime(currenttime, S_currenttime, sizeof(S_currenttime), 2);
		
		if (currenttime > StringToFloat(S_FileReplayTime[C_StyleTarget[client]]))
		{
			Format(centerText, sizeof(centerText), "%T", "Time", client, centerText, S_record, currentspeed);
		}
		else
		{
			Format(centerText, sizeof(centerText), "%T", "Time", client, centerText, S_currenttime, currentspeed);
		}
		
		
		//3RD LINE KEYBOARD
		char S_IN_FORWARD[32], S_IN_BACK[32], S_IN_MOVERIGHT[32], S_IN_MOVELEFT[32], S_IN_JUMP[32], S_IN_DUCK[32];
		int  iButtons = GetClientButtons(iClientToShow);
		if (iButtons & IN_FORWARD)
		{
			strcopy(S_IN_FORWARD, 16, "↑");
		}
		else
		{
			strcopy(S_IN_FORWARD, 16, "_");
		}
		
		if (iButtons & IN_BACK)
		{
			strcopy(S_IN_BACK, 16, "↓");
		}
		else
		{
			strcopy(S_IN_BACK, 16, "_");
		}
		
		if (iButtons & IN_MOVERIGHT)
		{
			strcopy(S_IN_MOVERIGHT, 16, "→");
		}
		else
		{
			strcopy(S_IN_MOVERIGHT, 16, "_");
		}
		
		if (iButtons & IN_MOVELEFT)
		{
			strcopy(S_IN_MOVELEFT, 16, "←");
		}
		else
		{
			strcopy(S_IN_MOVELEFT, 16, "_");
		}
		
		if (iButtons & IN_JUMP || B_IsJump[iClientToShow])
		{
			strcopy(S_IN_JUMP, 16, "&#x021D7;");
		}
		else
		{
			strcopy(S_IN_JUMP, 16, "_");
		}
		
		B_IsJump[iClientToShow] = false;
		
		if (iButtons & IN_DUCK)
		{
			strcopy(S_IN_DUCK, 16, "&#x021D8;");
		}
		else
		{
			strcopy(S_IN_DUCK, 16, "_");
		}
		
		Format(centerText, sizeof(centerText), "%s\n<font size='29'>%s%s%s%s | %s%s</font>", centerText, S_IN_MOVELEFT, S_IN_FORWARD, S_IN_MOVERIGHT, S_IN_BACK, S_IN_JUMP, S_IN_DUCK);
		
		PrintHintText(client, "<font size='16'>%s</font>", centerText);
	}
}


/***********************************************************/
/******************** GET PLAYER ALIVE *********************/
/***********************************************************/

stock int GetBotReplayed(int style)
{
	char S_botname[64], S_style[64];
	
	if (style == 1)strcopy(S_style, 64, "Auto");
	//else if (style == 3)strcopy(S_style, 64, "W-only");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsFakeClient(i))
		{
			CS_GetClientClanTag(i, S_botname, 64);
			if (StrEqual(S_botname, S_style, false))
			{
				if (B_active_timer_replay_dev)
				{
					PrintToChatAll("GetBotReplayed: %N: replayed", i);
				}
				return i;
			}
		}
	}
	return 0;
} 