#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR ""
#define PLUGIN_VERSION "0.00"

#include <sourcemod>
#include <sdktools>
#include <timer-rankings>
#include <timer>
#include <basecomm>
#include <csgocolors>


#include <voiceannounce_ex>


#pragma newdecls required


bool g_bIsFirstTime[MAXPLAYERS] =  { true, ... };
char g_sClientTag[MAXPLAYERS][64];

public Plugin myinfo = 
{
	name = "", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = ""
};

public void OnMapStart()
{
	CreateTimer(60.0, Thing, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public bool OnClientSpeakingEx(int client)
{
	if (g_bIsFirstTime[client])
	{
		Timer_GetTag(g_sClientTag[client], 64, client);
		if (Timer_GetLevel(client) == 0)
		{
			BaseComm_SetClientMute(client, true);
			CPrintToChat(client, "{blue}[{lightgreen}LifesGood{blue}]{olive} Sorry, you must be atleast level 1 in order to use voice chat.");
		}
		{
			BaseComm_SetClientMute(client, false);
		}
		g_bIsFirstTime[client] = false;
	}
	

}

public Action Thing(Handle timer, any data)
{
	for (int i = 0; i < MAXPLAYERS; i++)
	{
		if (!g_bIsFirstTime[i])
			g_bIsFirstTime[i] = true;
	}
}

public void OnClientConnected(int client)
{
	g_bIsFirstTime[client] = true;
}
public void OnClientDisconnect(int client)
{
	g_bIsFirstTime[client] = true;
}
