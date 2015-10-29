#include <sourcemod>
#include <sdktools>
#include <timer>
#include <timer-mapzones>
#include <timer-logging>
#include <timer-scripter_db>
#include <timer-config_loader>


public Plugin:myinfo = 
{
	name = "[Timer] NoScript - Anti Cheat", 
	author = "Oliver, Aexi0n", 
	description = "", 
	version = "1.0", 
	url = ""
}


//Bhop Script Protection - Credits: Inami(Macrodox) - Bhop Protection Method
new aiJumps[MAXPLAYERS + 1] =  { 0, ... };
new Float:afAvgJumps[MAXPLAYERS + 1] =  { 1.0, ... };
new Float:afAvgSpeed[MAXPLAYERS + 1] =  { 250.0, ... };
new Float:avVEL[MAXPLAYERS + 1][3];
new aiPattern[MAXPLAYERS + 1] =  { 0, ... };
new aiPatternhits[MAXPLAYERS + 1] =  { 0, ... };
new Float:avLastPos[MAXPLAYERS + 1][3];
new aiAutojumps[MAXPLAYERS + 1] =  { 0, ... };
new aaiLastJumps[MAXPLAYERS + 1][30];
new Float:afAvgPerfJumps[MAXPLAYERS + 1] =  { 0.3333, ... };
new iTickCount = 1;
new aiIgnoreCount[MAXPLAYERS + 1];
new String:path[PLATFORM_MAX_PATH];
new String:pathdat[PLATFORM_MAX_PATH];
new bool:bBanFlagged[MAXPLAYERS + 1];
new bool:bSurfCheck[MAXPLAYERS + 1];
new aiLastPos[MAXPLAYERS + 1] =  { 0, ... };

//Command Spam Protection - Credits: Forlix(FloodCheck) - Prevents AutoHotKey Scripts
static Float:p_time_lasthardfld[MAXPLAYERS + 1];
static p_cmdcnt_hard[MAXPLAYERS + 1];
static bool:p_hard_banned[MAXPLAYERS + 1];
new Float:hard_interval = 2.0;
new hard_num = 15;


public OnPluginStart()
{
	HookEvent("player_jump", PB_JumpCheck, EventHookMode_Post);
	BuildPath(Path_SM, path, sizeof(path), "logs/PBSecure.log");
	BuildPath(Path_SM, pathdat, sizeof(pathdat), "data/PBSecure.dat");
	RegAdminCmd("pb_check", Command_Stats, ADMFLAG_ROOT, "pb_check <userid/name>");

	//Commands to Spam Block
}


public OnMapStart()
{
	
}

public OnClientConnected(client)
{
	//Reset Spam Count
	p_time_lasthardfld[client] = 0.0;
	p_cmdcnt_hard[client] = 0;
	p_hard_banned[client] = false;
}

public OnClientDisconnect(client)
{
	aiJumps[client] = 0;
	afAvgJumps[client] = 5.0;
	afAvgSpeed[client] = 250.0;
	afAvgPerfJumps[client] = 0.3333;
	aiPattern[client] = 0;
	aiPatternhits[client] = 0;
	aiAutojumps[client] = 0;
	aiIgnoreCount[client] = 0;
	bBanFlagged[client] = false;
	avVEL[client][2] = 0.0;
	new i;
	while (i < 30)
	{
		aaiLastJumps[client][i] = 0;
		i++;
	}
}





// --- Command Spam Detection ---

public Action:OnClientCommand(client, args)
{
	decl String:cmd[64];
	GetCmdArg(0, cmd, sizeof(cmd));
	
	if (StrContains(cmd, "+", false) == 0)
	{
		return (Plugin_Continue);
	}
	if (StrContains(cmd, "-", false) == 0)
	{
		return (Plugin_Continue);
	}
	if (StrContains(cmd, "drop", false) == 0)
	{
		return (Plugin_Continue);
	}
	else
	{
		PB_SpamCheck(client);
		return (Plugin_Continue);
	}
}

public PB_SpamCheck(client)
{
	if (!client || !hard_interval || ++p_cmdcnt_hard[client] <= hard_num)
		return;
	
	new Float:time_c = GetTickedTime();
	
	if (time_c >= p_time_lasthardfld[client] + hard_interval || IsFakeClient(client) || IsClientInKickQueue(client)) // If Client is NOT Command Spamming..
	{
		p_time_lasthardfld[client] = time_c;
		p_cmdcnt_hard[client] = 0;
		return;
	}
	
	return;
}

public Action:Command_Block(client, args)
{
	return Plugin_Stop;
}
// ----------------------------------------------------------------------------------



// --- Bhop Script Detection ---

public Action:PB_JumpCheck(Handle:EventID, const String:Name[], bool:Broadcast)
{
	new client = GetClientOfUserId(GetEventInt(EventID, "userid"));
	afAvgJumps[client] = (afAvgJumps[client] * 9.0 + float(aiJumps[client])) / 10.0;
	
	decl Float:vec_vel[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", vec_vel);
	vec_vel[2] = 0.0;
	new Float:speed = GetVectorLength(vec_vel);
	afAvgSpeed[client] = (afAvgSpeed[client] * 9.0 + speed) / 10.0;
	
	aaiLastJumps[client][aiLastPos[client]] = aiJumps[client];
	aiLastPos[client]++;
	
	if (aiLastPos[client] == 30)
	{
		aiLastPos[client] = 0;
	}
	new style = Timer_GetStyle(client);
	
	/*if(afAvgJumps[client] > 14.0)
	{
		//HYPERSCROLLING:  http://hmxgaming.com/index.php?/topic/1459-cheating-isnt-cool-hyperscrolling-for-bhop-is-an-example/
		//disabled because it does not give you more speed than usual scrolling
		//check if more than 8 of the last 30 jumps were above 12
		g_NumberJumpsAbove[client] = 0;
			
		for (new i = 0; i < 29; i++)	//count
		{
			if((g_aaiLastJumps[client][i]) > (14 - 1))	//threshhold for # jump commands
			{
				g_NumberJumpsAbove[client]++;
			}
		}
		if((g_NumberJumpsAbove[client] > (14 - 1)) && (g_fafAvgPerfJumps[client] >= 0.4))	//if more than #
		{
			if (g_bAntiCheat && !g_bHyperscroll[client])
			{
				g_bHyperscroll[client] = true;
				new String:banstats[256];
				GetClientStatsLog(client, banstats, sizeof(banstats));		
				decl String:sPath[512];
				BuildPath(Path_SM, sPath, sizeof(sPath), "%s", ANTICHEAT_LOG_PATH);
				LogToFile(sPath, "%s reason: hyperscrolling" banstats);
				if(Timer_IsStyleRanked(style) && !g_Physics[style][StyleAuto] && !Timer_IsPlayerTouchingZoneType(client, ZtAuto))
				{
					AddScripter(client, "hax2");
				}
			}
		}
	}*/
	
	if (aiJumps[client] > 1)
	{
		aiAutojumps[client] = 0;
	}
	
	aiJumps[client] = 0;
	new Float:tempvec[3];
	tempvec = avLastPos[client];
	GetEntPropVector(client, Prop_Send, "m_vecOrigin", avLastPos[client]);
	
	new Float:len = GetVectorDistance(avLastPos[client], tempvec, true);
	if (len < 30.0)
	{
		aiIgnoreCount[client] = 2;
	}
	
	if (afAvgPerfJumps[client] >= 0.9)
	{
		new StyleCheck = Timer_GetStyle(client);
		if (StyleCheck == 0)
		{
			
			new String:banstats[255];
			GetClientStats(client, banstats, sizeof(banstats));

			decl String:nme[MAX_NAME_LENGTH];
			
			GetClientName(client, nme, MAX_NAME_LENGTH);
			if (Timer_IsStyleRanked(style) && !g_Physics[style][StyleAuto] && !Timer_IsPlayerTouchingZoneType(client, ZtAuto))
			{
				AddScripter(client, "hax2");
			}
			
		}
	}
	/*
	if (afAvgJumps[client] > 25)
	{
		new StyleCheck = Timer_GetStyle(client);
		if (StyleCheck == 0)
		{
			new String:banstats[255];
			GetClientStats(client, banstats, sizeof(banstats));
			LogToFile(path, "%s, *ALERT* Paradise Security has detected a cheater!", banstats);
			
			decl String:AlertSound[128];
			Format(AlertSound, 128, "sourcemod/paradise/alert.mp3");
			decl String:nme[MAX_NAME_LENGTH];
			
			GetClientName(client, nme, MAX_NAME_LENGTH);
			if (Timer_IsStyleRanked(style) && !g_Physics[style][StyleAuto] && !Timer_IsPlayerTouchingZoneType(client, ZtAuto))
			{
				AddScripter(client, "hax2");
			}
		}
	}
	*/
}


public OnGameFrame()
{
	if (iTickCount > 1 * MaxClients)
	{
		iTickCount = 1;
	}
	else
	{
		if (iTickCount % 1 == 0)
		{
			new index = iTickCount / 1;
			if (bSurfCheck[index] && IsClientInGame(index) && IsPlayerAlive(index))
			{
				GetEntPropVector(index, Prop_Data, "m_vecVelocity", avVEL[index]);
				if (avVEL[index][2] < -290)
				{
					aiIgnoreCount[index] = 2;
				}
				
			}
		}
		iTickCount++;
	}
}


AddScripter(client, const String:type[])
{
	new style = Timer_GetStyle(client);
	if (Timer_IsStyleRanked(style) && !g_Physics[style][StyleAuto])
	{
		new String:banstats[256];
		GetClientStats(client, banstats, sizeof(banstats));
		Timer_LogInfo("[scripter_macrodox] %N banned by macrodox module (code: %s). %s", client, type, banstats);
		Timer_AddScripter(client);
		bBanFlagged[client] = true;
	}
}



public Action:Command_Stats(client, args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: pb_check <#userid|name|@all>");
		return Plugin_Handled;
	}
	
	decl String:arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if ((target_count = ProcessTargetString(
				arg, 
				client, 
				target_list, 
				MAXPLAYERS, 
				COMMAND_FILTER_NO_IMMUNITY, 
				target_name, 
				sizeof(target_name), 
				tn_is_ml)) <= 0)
	{
		PrintToConsole(client, "Not found or invalid parameter.");
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		PerformStats(client, target_list[i]);
	}
	
	
	return Plugin_Handled;
}


PerformStats(client, target)
{
	new String:banstats[256];
	GetClientStats(target, banstats, sizeof(banstats));
	
	PrintToConsole(client, "%s", banstats);
}

public GetClientStats(client, String:string[], length)
{
	new Float:perf = afAvgPerfJumps[client] * 100;
	
	Format(string, length, "%L Scroll pattern: %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i %i, Avg scroll pattern: %f, Avg speed: %f, Perfect jump ratio: %.2f", 
		client, 
		aaiLastJumps[client][0], 
		aaiLastJumps[client][1], 
		aaiLastJumps[client][2], 
		aaiLastJumps[client][3], 
		aaiLastJumps[client][4], 
		aaiLastJumps[client][5], 
		aaiLastJumps[client][6], 
		aaiLastJumps[client][7], 
		aaiLastJumps[client][8], 
		aaiLastJumps[client][9], 
		aaiLastJumps[client][10], 
		aaiLastJumps[client][11], 
		aaiLastJumps[client][12], 
		aaiLastJumps[client][13], 
		aaiLastJumps[client][14], 
		aaiLastJumps[client][15], 
		aaiLastJumps[client][16], 
		aaiLastJumps[client][17], 
		aaiLastJumps[client][18], 
		aaiLastJumps[client][19], 
		aaiLastJumps[client][20], 
		aaiLastJumps[client][21], 
		aaiLastJumps[client][22], 
		aaiLastJumps[client][23], 
		aaiLastJumps[client][24], 
		aaiLastJumps[client][25], 
		aaiLastJumps[client][26], 
		aaiLastJumps[client][27], 
		aaiLastJumps[client][28], 
		aaiLastJumps[client][29], 
		afAvgJumps[client], 
		afAvgSpeed[client], 
		perf);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	if (IsFakeClient(client))
		return Plugin_Continue;
	
	new StyleCheck = Timer_GetStyle(client);
	if (StyleCheck == 0)
	{
		if (IsPlayerAlive(client))
		{
			static bool:bHoldingJump[MAXPLAYERS + 1];
			static bLastOnGround[MAXPLAYERS + 1];
			
			if (buttons & IN_JUMP)
			{
				if (!bHoldingJump[client])
				{
					bHoldingJump[client] = true; //started pressing +jump
					aiJumps[client]++;
					
					if (bLastOnGround[client] && (GetEntityFlags(client) & FL_ONGROUND))
					{
						afAvgPerfJumps[client] = (afAvgPerfJumps[client] * 9.0 + 0) / 10.0;
						
					}
					else if (!bLastOnGround[client] && (GetEntityFlags(client) & FL_ONGROUND))
					{
						afAvgPerfJumps[client] = (afAvgPerfJumps[client] * 9.0 + 1) / 10.0;
					}
				}
			}
			else if (bHoldingJump[client])
			{
				bHoldingJump[client] = false; //released (-jump)
			}
			
			bLastOnGround[client] = GetEntityFlags(client) & FL_ONGROUND;
		}
	}

    
    // We must return Plugin_Continue to let the changes be processed.
    // Otherwise, we can return Plugin_Handled to block the commands
	return Plugin_Continue;
} 