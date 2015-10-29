#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR ""
#define PLUGIN_VERSION "0.00"

#include <sourcemod>
#include <sdktools>
#include <csgocolors>
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
	RegConsoleCmd("sm_shit", Cmd_Shit);
}
public Action:Cmd_Shit(client, args)
{
	CPrintToChat(client, "\x01,x01 \x02,x02 \x03, x03\x04,x04 \x05, x05\x06,x06 \x07,x07 \x08, x08\x09, x09\x0A, x0A\x0B,x0B \x0C,x0C \x0D,x0D \x0E,x0E \x0F,x0F");
}