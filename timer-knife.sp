#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Oliver"
#define PLUGIN_VERSION "1.0"

#include <sourcemod>
#include <sdktools>
#include <multicolors>
public Plugin myinfo = 
{
	name = "[Timer] Weapons", 
	author = PLUGIN_AUTHOR, 
	description = "Allows players to spawn weapons with commands like !usp etc.", 
	version = PLUGIN_VERSION, 
	url = ""
};

public void OnPluginStart()
{

	RegConsoleCmd("sm_donate", command_donate, "Donate Command");
	RegConsoleCmd("sm_vip", command_donate, "Donate Command");

}


public Action command_donate(client, args)
{
	CPrintToChat(client, "{green}[{lime}LifesGood{green}]{olive} Please visit lgservers.org/donate/ in order to donate");
}


public Action usp_callback(client, args)
{
	if (CheckCommandAccess(client, "sm_say", ADMFLAG_CUSTOM3))
	{
		if (IsClientInGame(client) && !IsClientObserver(client))
		{
			int weapon = -1;
			if ((weapon = GetPlayerWeaponSlot(client, 1)) != -1)
			{
				RemovePlayerItem(client, weapon);
			}
			GivePlayerItem(client, "weapon_hkp2000");
		}
	}
	else
	{
		CPrintToChat(client, "{green}[{lime}LifesGood{green}]{olive} Sorry this command is only available players with VIP.");
	}
}
public Action glock_callback(client, args)
{
	if (CheckCommandAccess(client, "sm_say", ADMFLAG_CUSTOM3))
	{
		if (IsClientInGame(client) && !IsClientObserver(client))
		{
			int weapon = -1;
			if ((weapon = GetPlayerWeaponSlot(client, 1)) != -1)
			{
				RemovePlayerItem(client, weapon);
			}
			GivePlayerItem(client, "weapon_glock");
		}
	}
	else
	{
		CPrintToChat(client, "{green}[{lime}LifesGood{green}]{olive} Sorry this command is only available players with VIP.");
	}
}



public Action knife_callback(client, args) {
	if (IsClientInGame(client) && !IsClientObserver(client))
	{
		int weapon = -1;
		if ((weapon = GetPlayerWeaponSlot(client, 2)) != -1)
		{
			RemovePlayerItem(client, weapon);
		}
		GivePlayerItem(client, "weapon_knife");
	}
}
