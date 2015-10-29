#pragma semicolon 1



#define PLUGIN_AUTHOR "Oliver"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <timer>
#include <timer-mapzones>
enum WRCache
{
	ID,
	String:Steamid[32],
	String:Name[32],
	Level,
	Style,
	Float:Time,
}

enum RecordStats
{
	RecordStatsCount,
	RecordStatsID,
	Float:RecordStatsBestTime,
	String:RecordStatsSteamid[32],
	String:RecordStatsName[32],
}


new nCacheTemplate[WRCache];
new Handle:g_hCache[MAX_STYLES][50];
new g_cachestats[MAX_STYLES][50][RecordStats];
new Handle:g_hSQL;
new Float:g_fClientBestTimes[MAX_STYLES][50][MAXPLAYERS];
new g_iRecordID[MAX_STYLES][50][MAXPLAYERS];
new Float:fWRStageTime[MAX_STYLES][50][32];
new String:CurrentMap[32];
new String:g_sAuth[MAXPLAYERS][32];

new g_iLastZoneId[MAXPLAYERS];
new bool:ClientInStartZone[MAXPLAYERS] = false;
new Float:g_fTimeBuffer[MAXPLAYERS];
new g_iClientLastZone[MAXPLAYERS];

public Plugin:myinfo = 
{
	name = "Timer Checkpoint Ranki",
	author = PLUGIN_AUTHOR,
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

public OnPluginStart()
{
	//ConnectSQL(true);
	//CacheReset();

}
public OnMapStart()
{
	
	GetCurrentMap(CurrentMap, 32);
	for (new style = 0; style < MAX_STYLES; style++)
	{
		for (new level = 0; level < 50; level++)
		{
			for (new client = 0; client <= MAXPLAYERS; client++)
			{
				g_fClientBestTimes[style][level][client] = 0.0;
				g_iLastZoneId[client] = 0;
				g_fTimeBuffer[client] = 0.0;
				g_iClientLastZone[client] = 0;
			}
		}
				
	}		
	RefreshWRCache();
	
	
}


public OnClientConnected(client)
{
	GetClientAuthId(client, AuthId_Steam2, g_sAuth[client], 32);
	//LoadStageTimes(client);
}


LoadStageTimes(client)
{
	new String:query[255];
	Format(query, sizeof(query), "SELECT `id`,`level`,`time`,`track`,`style` FROM `timercheckpoints` WHERE `steamid` = `%s` AND `map` = `%s`", g_sAuth[client], CurrentMap);
	SQL_TQuery(g_hSQL, GetClientTimesCallback, query, client, DBPrio_High);
}

public GetClientTimesCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	while (SQL_FetchRow(hndl))
	{
		g_fClientBestTimes[SQL_FetchInt(hndl, 4)][SQL_FetchInt(hndl, 1)][data] = SQL_FetchFloat(hndl, 2);
		g_iRecordID[SQL_FetchInt(hndl, 4)][SQL_FetchInt(hndl, 1)][data] = SQL_FetchInt(hndl, 0);
	}
}

RefreshWRCache()
{
	if (g_hSQL == INVALID_HANDLE)
	{
		ConnectSQL(true);
	}
	else
	{
		new String:query[255];
		Format(query, sizeof(query), "SELECT `id`,`steamid`,`name`,`level`,`time`,`style` FROM `timercheckpoints` WHERE `map` = `%s` AND `track` = 1 ORDER BY time ASC", CurrentMap);
		SQL_TQuery(g_hSQL, RefreshWRCacheCallback, query, _, DBPrio_High);
	}
}

public RefreshWRCacheCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	while (SQL_FetchRow(hndl))
	{
		new nNewCache[WRCache];
		new level = SQL_FetchInt(hndl, 3);
		new style = SQL_FetchInt(hndl, 5);
		nNewCache[ID] = SQL_FetchInt(hndl, 0);
		SQL_FetchString(hndl, 1, nNewCache[Steamid], 32);
		SQL_FetchString(hndl, 2, nNewCache[Name], 32);
		nNewCache[Level] = level;
		nNewCache[Time] = SQL_FetchFloat(hndl, 4);
		nNewCache[Style] = style;
		
		if(g_hCache[style][level] != INVALID_HANDLE)
			ClearArray(g_hCache[style][level]);
		else g_hCache[style][level] = CreateArray(sizeof(nCacheTemplate));
		
		PushArrayArray(g_hCache[style][level], nNewCache[0]);
	}
	for (new style; style < MAX_STYLES; style++)
		for (new level; level < 50; level++)
			CollectBestCache(style, level);

}

CollectBestCache(style, level)
{
	g_cachestats[style][level][RecordStatsCount] = 0;
	g_cachestats[style][level][RecordStatsID] = 0;
	g_cachestats[style][level][RecordStatsBestTime] = 0.0;
	FormatEx(g_cachestats[style][level][RecordStatsSteamid], 32, "");
	FormatEx(g_cachestats[style][level][RecordStatsName], 32, "");
	
	for (new i = 0; i < GetArraySize(g_hCache[style][level]); i++)
	{
		new nCache[WRCache];
		GetArrayArray(g_hCache[style][level], i, nCache[0]);
		
		if(nCache[Time] <= 0.0)
			continue;
		
		g_cachestats[style][level][RecordStatsCount]++;
		
		if(g_cachestats[style][level][RecordStatsBestTime] == 0.0 || g_cachestats[style][level][RecordStatsBestTime] > nCache[Time])
		{
			g_cachestats[style][level][RecordStatsID] = nCache[ID];
			g_cachestats[style][level][RecordStatsBestTime] = nCache[Time];
			FormatEx(g_cachestats[style][level][RecordStatsSteamid], 32, "%s", nCache[Steamid]);
			FormatEx(g_cachestats[style][level][RecordStatsName], 32, "%s", nCache[Name]);
		}
	}
}



ConnectSQL(bool:refreshCache)
{
	if (g_hSQL != INVALID_HANDLE)
	{
		CloseHandle(g_hSQL);
	}
	
	g_hSQL = INVALID_HANDLE;
	
	if (SQL_CheckConfig("timer"))
	{
		SQL_TConnect(ConnectSQLCallback, "timer", refreshCache);
	}
	else
	{
		SetFailState("PLUGIN STOPPED - Reason: no config entry found for 'timer' in databases.cfg - PLUGIN STOPPED");
	}
}

public ConnectSQLCallback(Handle:owner, Handle:hndl, const String:error[], any:data)
{
	if (hndl == INVALID_HANDLE)
	{
		//Timer_LogError("Connection to SQL database has failed, Reason: %s", error);
		
		
		ConnectSQL(data);
		return;
	}

	g_hSQL = CloneHandle(hndl);
	
	decl String:driver[16];
	SQL_GetDriverIdent(owner, driver, sizeof(driver));


	if (data)
	{
		RefreshWRCache();	
	}
}

CacheReset()
{
	
	// Init world record cache
	for (new style = 0; style < MAX_STYLES; style++)
	{
		for (new level = 0; level < 50; level++)
		{
			if(g_hCache[style][level] != INVALID_HANDLE)
				ClearArray(g_hCache[style][level]);
			else g_hCache[style][level] = CreateArray(sizeof(nCacheTemplate));
			
			//g_cacheLoaded[style][level] = false;
		}
	}
}


public OnClientStartTouchZoneType(client, MapZoneType:type)
{
	if (type == ZtLevel || type == ZtCheckpoint)
	{
		new bool:Enabled;
		new Float:Time1;
		new Jumps, FPSMax;
		Timer_GetClientTimer(client, Enabled, Time1, Jumps, FPSMax);
		new style = Timer_GetStyle(client);
		new LevelID = Timer_GetClientLevelID(client);
		if (LevelID != g_iLastZoneId[client] + 1)return;
		if (g_fClientBestTimes[style][LevelID][client] < (Time1 - g_fTimeBuffer[client]))
		{
			PrintToChat(client, "+%f", (Time1 - g_fTimeBuffer[client]) - g_fClientBestTimes[style][LevelID][client]);
		}
		else
		{
			if (g_fClientBestTimes[style][LevelID][client] == 0.0)
			{
				PrintToChat(client, "+%f", g_fClientBestTimes[style][LevelID][client]);
				g_fClientBestTimes[style][LevelID][client] = Time1 - g_fTimeBuffer[client];
			}
			else
			{
				PrintToChat(client, "%f", (Time1 - g_fTimeBuffer[client]) - g_fClientBestTimes[style][LevelID][client]);
				g_fClientBestTimes[style][LevelID][client] = Time1 - g_fTimeBuffer[client];
			}
			
			new String:query[255];
			Format(query, sizeof(query), "SELECT `id`,`steamid`,`name`,`level`,`time`,`style` FROM `timercheckpoints` WHERE `map` = `%s` AND `track` = 1 ORDER BY time ASC", CurrentMap);
			SQL_TQuery(g_hSQL, RefreshWRCacheCallback, query, _, DBPrio_High);
			
		}
		
		
		
		
		
	
		g_iLastZoneId[client] = LevelID;
	}
}

public OnClientEndTouchZoneType(client, MapZoneType:type)
{
	if (type == ZtStart || (type == ZtLevel || type == ZtCheckpoint))
	{
		new bool:Enabled;
		new Float:Time1;
		new Jumps, FPSMax;
		Timer_GetClientTimer(client, Enabled, Time1, Jumps, FPSMax);
		if (Enabled)
			g_fTimeBuffer[client] = Time1;
			
		if (type == ZtStart)
		{
			g_iLastZoneId[client] = 0;
			g_fTimeBuffer[client] = 0.0;
		}
	}
}
