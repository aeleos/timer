#pragma semicolon 1
#include <sdktools>
#include <sdktools_sound>
#define VERSION "1.0"
#define AUTHOR "myk modified by tonic"
#define MAX_FILE_LEN 80

// CVAR Handles
new Handle:cvarnven = INVALID_HANDLE;
new Handle:cvarnvonoff = INVALID_HANDLE;

// Basic Information
public Plugin:myinfo =
{
	name = "[alpha] Night Vision Goggles",
	author = AUTHOR,
	description = "CS:GO Night Vision",
	version = VERSION,
	url = ""
};

// Command
public OnPluginStart()
{
	// Default
	RegConsoleCmd("sm_nvg", Command_nightvision);
	RegConsoleCmd("sm_nv", Command_nightvision);

	//Cvars
	cvarnvonoff = CreateConVar("nv_onoff", "1", "Disable Enable / Disable Messages");
	cvarnven = CreateConVar("nv_command", "1", "Enable or Disable !NVG");
	
	// Version
	CreateConVar("sm_nightvision_version", VERSION, "Plugin info", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	
	//Generate
	AutoExecConfig(true, "plugin.nightvision");
	 	
}

// Enable
public Action:Command_nightvision(client, args)
{
 	if (GetConVarInt(cvarnven) == 1)
	{
		if (IsPlayerAlive(client)) 
    	{
			if(GetEntProp(client, Prop_Send, "m_bNightVisionOn") == 0)
			{
    			SetEntProp(client, Prop_Send, "m_bNightVisionOn", 1);
    			if (GetConVarInt(cvarnvonoff) == 1)
    			{
    			PrintToChat(client,"\x01 [alpha] Night Vision \x03enabled\x01.");
    			}
			}
			else
			{
    			SetEntProp(client, Prop_Send, "m_bNightVisionOn", 0);
    			if (GetConVarInt(cvarnvonoff) == 1)
    			{
    			PrintToChat(client,"\x01 [alpha] Night Vision \x03disabled\x01.");
    			}
    		}
    	}
	}
	return Plugin_Handled;
}
