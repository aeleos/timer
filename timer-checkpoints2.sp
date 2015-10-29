#pragma semicolon 1



#define PLUGIN_AUTHOR "Oliver"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <timer>
#include <timer-mapzones>
#include <dynamic>
#pragma newdecls required

enum WRCache
{
	ID, 
	String:Steamid[32], 
	String:Name[32], 
	Level, 
	Style, 
	Float:Time, 
}
char g_sAuth[MAXPLAYERS][32];
int nCacheTemplate[WRCache];
Handle g_hCache[MAX_STYLES][50];
Dynamic ClientBestTime[MAXPLAYERS][MAX_STYLES][50];
Dynamic BestWRCache[MAX_STYLES][50];
char g_sCurrentMap[32];
Handle g_hSQL;
int g_iLastZoneId[MAXPLAYERS];
float g_fTimeBuffer[MAXPLAYERS];
int g_iClientLastZone[MAXPLAYERS];


public void OnMapStart() {
	for (int style = 0; style < MAX_STYLES; style++)
	{
		for (int level = 0; level < 50; level++)
		{
			for (int client = 0; client <= MAXPLAYERS; client++)
			{
				ClientBestTime[client][style][level].SetFloat("m_fTime", 0.0);
				ClientBestTime[client][style][level].SetInt("m_iID", 0);
				g_iLastZoneId[client] = 0;
				g_fTimeBuffer[client] = 0.0;
				g_iClientLastZone[client] = 0;
			}
		}
		
	}
	GetCurrentMap(g_sCurrentMap, 32);
	CacheReset();
	RefreshWRCache();
}

public void OnClientConnected(int client)
{
	for (int style = 0; style < MAX_STYLES; style++)
	{
		for (int level = 0; level < 50; level++)
		{
			ClientBestTime[client][style][level].SetFloat("m_fTime", 0.0);
			ClientBestTime[client][style][level].SetInt("m_iID", 0);
			g_iLastZoneId[client] = 0;
			g_fTimeBuffer[client] = 0.0;
			g_iClientLastZone[client] = 0;
		}
		
	}
	LoadStageTimes(client);
	GetClientAuthId(client, AuthId_Steam2, g_sAuth[client], 32);
}

public void OnClientDisconnected(int client)
{
	for (int style = 0; style < MAX_STYLES; style++)
	{
		for (int level = 0; level < 50; level++)
		{
			ClientBestTime[client][style][level].SetFloat("m_fTime", 0.0);
			ClientBestTime[client][style][level].SetInt("m_iID", 0);
			g_iLastZoneId[client] = 0;
			g_fTimeBuffer[client] = 0.0;
			g_iClientLastZone[client] = 0;
		}
		
	}
}



void ConnectSQL(bool refreshCache)
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

public void ConnectSQLCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	if (hndl == INVALID_HANDLE)
	{
		//Timer_LogError("Connection to SQL database has failed, Reason: %s", error);
		
		
		ConnectSQL(data);
		return;
	}
	
	g_hSQL = CloneHandle(hndl);
	
	char driver[16];
	SQL_GetDriverIdent(owner, driver, sizeof(driver));
	
	
	if (data)
	{
		RefreshWRCache();
	}
}







void LoadStageTimes(int client)
{
	char query[255];
	Format(query, sizeof(query), "SELECT `id`,`style,`level`,`time` FROM `timercheckpoints` WHERE `steamid` = `%s` AND `map` = `%s`", g_sAuth[client], g_sCurrentMap);
	SQL_TQuery(g_hSQL, GetClientTimesCallback, query, client, DBPrio_High);
}

public void GetClientTimesCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	while (SQL_FetchRow(hndl))
	{
		int style = SQL_FetchInt(hndl, 1);
		int level = SQL_FetchInt(hndl, 2);
		ClientBestTime[data][style][level] = Dynamic();
		ClientBestTime[data][style][level].SetFloat("m_fTime", SQL_FetchFloat(hndl, 3));
		ClientBestTime[data][style][level].SetInt("m_iID", SQL_FetchInt(hndl, 0));
	}
}



void RefreshWRCache()
{
	if (g_hSQL == INVALID_HANDLE)
	{
		ConnectSQL(true);
	}
	else
	{
		char query[255];
		Format(query, sizeof(query), "SELECT `id`,`steamid`,`name`,`level`,`time`,`style` FROM `timercheckpoints` WHERE `map` = `%s` AND `track` = 1 ORDER BY time ASC", g_sCurrentMap);
		SQL_TQuery(g_hSQL, RefreshWRCacheCallback, query, _, DBPrio_High);
	}
}


public void RefreshWRCacheCallback(Handle owner, Handle hndl, const char[] error, any data)
{
	while (SQL_FetchRow(hndl))
	{
		int nNewCache[WRCache];
		int level = SQL_FetchInt(hndl, 3);
		int style = SQL_FetchInt(hndl, 5);
		nNewCache[ID] = SQL_FetchInt(hndl, 0);
		SQL_FetchString(hndl, 1, nNewCache[Steamid], 32);
		SQL_FetchString(hndl, 2, nNewCache[Name], 32);
		nNewCache[Level] = level;
		nNewCache[Time] = SQL_FetchFloat(hndl, 4);
		nNewCache[Style] = style;
		
		if (g_hCache[style][level] != INVALID_HANDLE)
			ClearArray(g_hCache[style][level]);
		else g_hCache[style][level] = CreateArray(sizeof(nCacheTemplate));
		
		PushArrayArray(g_hCache[style][level], nNewCache[0]);
	}
	for (int style; style < MAX_STYLES; style++)
	for (int level; level < 50; level++)
	CollectBestCache(style, level);
	
}

void CollectBestCache(int style, int level)
{
	BestWRCache[style][level].Dispose();
	BestWRCache[style][level] = Dynamic();
	BestWRCache[style][level].SetInt("RecordStatsCount", 0);
	BestWRCache[style][level].SetInt("RecordStatsID", 0);
	BestWRCache[style][level].SetFloat("RecordStatsBestTime", 0.0);
	BestWRCache[style][level].SetString("RecordStatsSteamid", "");
	BestWRCache[style][level].SetString("RecordStatsName", "");
	
	for (int i = 0; i < GetArraySize(g_hCache[style][level]); i++)
	{
		int nCache[WRCache];
		GetArrayArray(g_hCache[style][level], i, nCache[0]);
		
		if (nCache[Time] <= 0.0)
			continue;
		
		BestWRCache[style][level].SetInt("RecordStatsCount", BestWRCache[style][level].GetInt("RecordStatsCount") + 1);
		
		if (BestWRCache[style][level].GetFloat("RecordStatsBestTime") == 0.0 || BestWRCache[style][level].GetFloat("RecordStatsBestTime") > nCache[Time])
		{
			BestWRCache[style][level].SetInt("RecordStatsID", nCache[ID]);
			BestWRCache[style][level].SetFloat("RecordStatsBestTime", nCache[Time]);
			BestWRCache[style][level].SetString("RecordStatsSteamid", nCache[Steamid]);
			BestWRCache[style][level].SetString("RecordStatsName", nCache[Name]);
		}
	}
}

void CacheReset()
{
	
	// Init world record cache
	for (int style = 0; style < MAX_STYLES; style++)
	{
		for (int level = 0; level < 50; level++)
		{
			if (g_hCache[style][level] != INVALID_HANDLE)
				ClearArray(g_hCache[style][level]);
			else g_hCache[style][level] = CreateArray(sizeof(nCacheTemplate));
			
			//g_cacheLoaded[style][level] = false;
		}
	}
}


public int OnClientStartTouchZoneType(int client, MapZoneType type)
{
	if (type == ZtLevel || type == ZtCheckpoint)
	{
		bool Enabled;
		float Time1;
		int Jumps, FPSMax;
		Timer_GetClientTimer(client, Enabled, Time1, Jumps, FPSMax);
		int style = Timer_GetStyle(client);
		int level = Timer_GetClientLevelID(client);
		float BestTime = ClientBestTime[client][style][level].GetFloat("m_fTime");
		if (level != g_iLastZoneId[client] + 1)return;
		if (BestTime < (Time1 - g_fTimeBuffer[client]))
		{
			PrintToChat(client, "+%f", (Time1 - g_fTimeBuffer[client]) - BestTime);
		}
		else
		{
			if (BestTime == 0.0)
			{
				PrintToChat(client, "+%f", BestTime);
				ClientBestTime[client][style][level].SetFloat("m_fTime", (Time1 - g_fTimeBuffer[client]));
			}
			else
			{
				PrintToChat(client, "%f", (Time1 - g_fTimeBuffer[client]) - BestTime);
				ClientBestTime[client][style][level].SetFloat("m_fTime", (Time1 - g_fTimeBuffer[client]));
			}
			
			char query[255];
			Format(query, sizeof(query), "SELECT `id`,`steamid`,`name`,`level`,`time`,`style` FROM `timercheckpoints` WHERE `map` = `%s` AND `track` = 1 ORDER BY time ASC", g_sCurrentMap);
			SQL_TQuery(g_hSQL, RefreshWRCacheCallback, query, _, DBPrio_High);
			
		}
		
		
		
		
		
		
		g_iLastZoneId[client] = level;
	}
}

public int OnClientEndTouchZoneType(int client, MapZoneType type)
{
	if (type == ZtStart || (type == ZtLevel || type == ZtCheckpoint))
	{
		bool Enabled;
		float Time1;
		int Jumps, FPSMax;
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
