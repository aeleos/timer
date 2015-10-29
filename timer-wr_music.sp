#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR ""
#define PLUGIN_VERSION "0.00"

#include <sourcemod>
#include <sdktools>
#include <timer>
#include <emitsoundany>
#include <clientprefs>

bool g_bClientPreference[MAXPLAYERS + 1] = true;
Handle g_hClientCookie = INVALID_HANDLE;


#pragma newdecls required

public Plugin myinfo = 
{
	name = "", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = ""
};

public void OnPluginStart()
{
	g_hClientCookie = RegClientCookie("MusicWRPref", "Cookie to store WR Music Preference", CookieAccess_Private);
	SetCookiePrefabMenu(g_hClientCookie, CookieMenu_OnOff_Int, "Enable or Disable WR Music;", TestCookieHandler);
	for (int i = MaxClients; i > 0; --i)
	{
		if (!AreClientCookiesCached(i))
		{
			continue;
		}
		OnClientCookiesCached(i);
	}
}

public void TestCookieHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_DisplayOption:
		{
		}
		
		case CookieMenuAction_SelectOption:
		{
			OnClientCookiesCached(client);
		}
	}
}

public void OnClientCookiesCached(int client)
{
	char sValue[8];
	GetClientCookie(client, g_hClientCookie, sValue, sizeof(sValue));
	
	g_bClientPreference[client] = (sValue[0] != '\0' && StringToInt(sValue));
}



public void OnConfigsExecuted()
{
	PrecacheSoundAny("lg_wr.mp3");
	AddFileToDownloadsTable("sound/lg_wr.mp3");
	PrecacheSoundAny("lg_wr.mp3");
	AddFileToDownloadsTable("sound/lg_wr.mp3");
}

public int OnTimerWorldRecord()
{
	EmitSoundToAllAny("lg_wr.mp3", _, _, _, SND_STOPLOOPING);
	EmitSoundToAllAny("lg_wr.mp3");
	for (int i = 0; i < MaxClients; i++)
	{
		if (g_bClientPreference[i])
		{
			EmitSoundToClientAny(i, "lg_wr.mp3", _, _, _, SND_STOPLOOPING);
			EmitSoundToClientAny(i, "lg_wr.mp3", _, _, _, _, 0.5);
		}
	}
} 