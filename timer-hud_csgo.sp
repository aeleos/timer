#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <smlib>
#include <timer>
#include <sdkhooks>
#include <botmimic>
#include <timer-logging>
#include <timer-stocks>
#include <timer-config_loader>
#undef REQUIRE_PLUGIN
#include <timer-mapzones>
#include <timer-teams>
#include <timer-maptier>
#include <timer-rankings>
#include <timer-worldrecord>
#include <timer-physics>
#include <js_ljstats>

#define THINK_INTERVAL 			1.0
#define DEBUG
enum Hud
{
	Master, 
	Main, 
	Time, 
	Jumps, 
	Speed, 
	SpeedMax, 
	JumpAcc, 
	Side, 
	Map, 
	Mode, 
	WR, 
	Rank, 
	PB, 
	TTWR, 
	Keys, 
	Spec, 
	Steam, 
	Level, 
	Timeleft, 
	Points
}
enum
{
	STRAFE_INVALID = -1, 
	STRAFE_LEFT, 
	STRAFE_RIGHT, 
	
	NUM_STRAFES
};

/**
 * Global Variables
 */
new String:g_currentMap[64];

new Handle:g_cvarTimeLimit = INVALID_HANDLE;

//module check
new bool:g_timerPhysics = false;
new bool:g_timerMapzones = false;
new bool:g_timerRankings = false;
new bool:g_timerWorldRecord = false;

new fFlags;
new Float:flClientPrevYaw[MAXPLAYERS];
new Float:flClientLastVel[MAXPLAYERS];
new iClientLastStrafe[MAXPLAYERS] =  { STRAFE_INVALID, ... };
new iClientSync[MAXPLAYERS][NUM_STRAFES];
new iClientSync_Max[MAXPLAYERS][NUM_STRAFES];
new Float:flCurVel;
new g_iButtonsPressed[MAXPLAYERS + 1] =  { 0, ... };
new Float:g_flClientSync[MAXPLAYERS + 1][NUM_STRAFES];
new Float:g_flClientAvgCurSync[MAXPLAYERS + 1];
new Float:g_flClientAvgSync[MAXPLAYERS + 1];
new Float:g_flClientAvgSync1[MAXPLAYERS + 1];
new g_nClientStrafeCount[MAXPLAYERS + 1];
new g_iJumps[MAXPLAYERS + 1] =  { 0, ... };
new Handle:g_hDelayJump[MAXPLAYERS + 1] =  { INVALID_HANDLE, ... };
new Float:Velocity[MAXPLAYERS][3];
new Float:Angle[MAXPLAYERS][3];
new Handle:g_hThink_Map = INVALID_HANDLE;
new g_iMap_TimeLeft = 1200;


public Plugin:myinfo = 
{
	name = "[Timer] HUD", 
	author = "Zipcore, Alongub", 
	description = "[Timer] Player HUD with optional details to show and cookie support", 
	version = PL_VERSION, 
	url = "forums.alliedmods.net/showthread.php?p=2074699"
};


public OnPluginStart()
{
	if (GetEngineVersion() != Engine_CSGO)
	{
		Timer_LogError("Don't use this plugin for other games than CS:GO.");
		SetFailState("Check timer error logs.");
		return;
	}
	
	g_timerPhysics = LibraryExists("timer-physics");
	g_timerMapzones = LibraryExists("timer-mapzones");
	g_timerRankings = LibraryExists("timer-rankings");
	g_timerWorldRecord = LibraryExists("timer-worldrecord");
	
	LoadPhysics();
	LoadTimerSettings();
	
	LoadTranslations("timer.phrases");
	
	
	
	HookEvent("player_death", Event_Reset);
	HookEvent("player_team", Event_Reset);
	HookEvent("player_spawn", Event_Reset);
	HookEvent("player_disconnect", Event_Reset);
	
	
	
	g_cvarTimeLimit = FindConVar("mp_timelimit");
	
	AutoExecConfig(true, "timer/timer-hud");
	
	
	
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "timer-physics"))
	{
		g_timerPhysics = true;
	}
	else if (StrEqual(name, "timer-mapzones"))
	{
		g_timerMapzones = true;
	}
	else if (StrEqual(name, "timer-rankings"))
	{
		g_timerRankings = true;
	}
	else if (StrEqual(name, "timer-worldrecord"))
	{
		g_timerWorldRecord = true;
	}
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "timer-physics"))
	{
		g_timerPhysics = false;
	}
	else if (StrEqual(name, "timer-mapzones"))
	{
		g_timerMapzones = false;
	}
	else if (StrEqual(name, "timer-rankings"))
	{
		g_timerRankings = false;
	}
	else if (StrEqual(name, "timer-worldrecord"))
	{
		g_timerWorldRecord = false;
	}
}

public OnMapStart()
{
	for (new client = 1; client <= MaxClients; client++)
	{
		g_hDelayJump[client] = INVALID_HANDLE;
	}
	
	GetCurrentMap(g_currentMap, sizeof(g_currentMap));
	
	if (GetEngineVersion() == Engine_CSGO)
	{
		CreateTimer(0.1, HUDTimer_CSGO, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
	
	RestartMapTimer();
	
	LoadPhysics();
	LoadTimerSettings();
}

public OnMapEnd()
{
	if (g_hThink_Map != INVALID_HANDLE)
	{
		CloseHandle(g_hThink_Map);
		g_hThink_Map = INVALID_HANDLE;
	}
}

public OnClientDisconnect(client)
{
	g_iButtonsPressed[client] = 0;
	if (g_hDelayJump[client] != INVALID_HANDLE)
	{
		CloseHandle(g_hDelayJump[client]);
		g_hDelayJump[client] = INVALID_HANDLE;
	}
}









public OnConfigsExecuted()
{
	if (g_cvarTimeLimit != INVALID_HANDLE)HookConVarChange(g_cvarTimeLimit, ConVarChange_TimeLimit);
}

public ConVarChange_TimeLimit(Handle:cvar, const String:oldVal[], const String:newVal[])
{
	RestartMapTimer();
}

stock RestartMapTimer()
{
	//Map Timer
	if (g_hThink_Map != INVALID_HANDLE)
	{
		CloseHandle(g_hThink_Map);
		g_hThink_Map = INVALID_HANDLE;
	}
	
	new bool:gotTimeLeft = GetMapTimeLeft(g_iMap_TimeLeft);
	
	if (gotTimeLeft && g_iMap_TimeLeft > 0)
	{
		g_hThink_Map = CreateTimer(THINK_INTERVAL, Timer_Think_Map, INVALID_HANDLE, TIMER_REPEAT);
	}
}

public Action:Timer_Think_Map(Handle:timer)
{
	g_iMap_TimeLeft--;
	return Plugin_Continue;
}

public OnClientPutInServer(client)
{
	
	
	if (g_hThink_Map == INVALID_HANDLE && IsServerProcessing())
	{
		RestartMapTimer();
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	Velocity[client][0] = vel[0];
	Velocity[client][1] = vel[1];
	Velocity[client][2] = vel[2];
	Angle[client][0] = vel[0];
	Angle[client][1] = vel[1];
	Angle[client][1] = vel[1];
	return Plugin_Continue;
	
	
	
	
	
	/*
	fFlags = GetEntProp(client, Prop_Data, "m_fFlags");
	// We don't want ladders or water counted as jumpable space.
	if (GetEntityMoveType(client) != MOVETYPE_WALK || GetEntProp(client, Prop_Data, "m_nWaterLevel") > 1)
	{
		flClientPrevYaw[client] = Angle[client][1];
		return Plugin_Continue;
	}
	if (fFlags & FL_ONGROUND && !(g_iButtonsPressed[client] & IN_JUMP))
	{
		// If we're on the ground and not jumping, we reset our last speed.
		flClientLastVel[client] = 0.0;
		flClientPrevYaw[client] = Angle[client][1];
		
		return Plugin_Continue;
	}
	
	///////////////////////////
	// SYNC AND STRAFE COUNT //
	///////////////////////////
	// The reason why we don't just use mouse[0] to determine whether our player is strafing is because it isn't reliable.
	// If a player is using a strafe hack, the variable doesn't change.
	// If a player is using a controller, the variable doesn't change. (unless using no acceleration)
	// If a player has a controller plugged in and uses mouse instead, the variable doesn't change.
	
	
	// Not on ground, moving mouse and we're pressing at least some key.
	if (Angle[client][1] != flClientPrevYaw[client] && (g_iButtonsPressed[client] & IN_MOVELEFT || g_iButtonsPressed[client] & IN_MOVERIGHT || g_iButtonsPressed[client] & IN_FORWARD || g_iButtonsPressed[client] & IN_BACK))
	{
		
		// Thing to remember: angle is a number between 180 and -180.
		// So we give 20 degree cap where this can be registered as strafing to the left.
		new iCurStrafe = (
			!(flClientPrevYaw[client] < -170.0 && Angle[client][1] > 170.0) // Make sure we didn't do -180 -> 180 because that would mean left when it's actually right.
			 && (Angle[client][1] > flClientPrevYaw[client] // Is our current yaw bigger than last time? Strafing to the left.
				 || (flClientPrevYaw[client] > 170.0 && Angle[client][1] < -170.0))) // If that didn't pass, there might be a chance of 180 -> -180.
		 ? STRAFE_LEFT : STRAFE_RIGHT;
		
		
		if (iCurStrafe != iClientLastStrafe[client])
			// Start of a new strafe.
		{
			// Calc previous strafe's sync. This will then be shown to the player.
			if (iClientLastStrafe[client] != STRAFE_INVALID)
			{
				g_flClientSync[client][iClientLastStrafe[client]] = (g_flClientSync[client][iClientLastStrafe[client]] + iClientSync[client][iClientLastStrafe[client]] / float(iClientSync_Max[client][iClientLastStrafe[client]])) / 2.0;
			}
			
			// Reset the new strafe's variables.
			iClientSync[client][iCurStrafe] = 1;
			iClientSync_Max[client][iCurStrafe] = 1;
			iClientLastStrafe[client] = iCurStrafe;
			g_nClientStrafeCount[client]++;
			g_flClientAvgCurSync[client] = (FloatAdd(Float:g_flClientSync[client][STRAFE_LEFT], Float:g_flClientSync[client][STRAFE_RIGHT]) / 2.0);
			g_flClientAvgSync1[client] += g_flClientAvgCurSync[client];
			if(g_nClientStrafeCount[client] > 1)
				g_flClientAvgSync[client] = g_flClientAvgSync1[client] / g_nClientStrafeCount[client];
			
		}
		
		
		Timer_GetCurrentSpeed(client, flCurVel);
		
		// We're moving our mouse, but are we gaining speed?
		if (flCurVel > flClientLastVel[client])iClientSync[client][iCurStrafe]++;
		iClientSync_Max[client][iCurStrafe]++;
		
		
		flClientLastVel[client] = flCurVel;
	}
	flClientPrevYaw[client] = Angle[client][1];
	return Plugin_Continue;
	*/
}





public Action:Event_Reset(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	g_iJumps[client] = 0;
	
	if (g_hDelayJump[client] != INVALID_HANDLE)
	{
		CloseHandle(g_hDelayJump[client]);
		g_hDelayJump[client] = INVALID_HANDLE;
	}
	return Plugin_Continue;
}

public Action:HUDTimer_CSGO(Handle:timer)
{

	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
			UpdateHUD_CSGO(client);
	}
}
public BotMimic_OnPlayerMimicLoops(client)
{
	StartBotTimer(client);
}
new Float:g_fBotCurrentTime[MAXPLAYERS + 1];
new Float:g_fBotStartTime[MAXPLAYERS + 1];



StartBotTimer(client)
{
	g_fBotStartTime[client] = GetGameTime();
	g_flClientAvgSync1[client] = 0.0;
	g_flClientAvgCurSync[client] = 0.0;
	g_flClientAvgSync[client] = 0.0;
	g_nClientStrafeCount[client] = 0;
}



UpdateHUD_CSGO(client)
{
	if (!IsClientInGame(client))
	{
		return;
	}
	
	
	new iClientToShow, iObserverMode, iButtons;
	//new iButtons;
	
	// Show own buttons by default
	iClientToShow = client;
	
	// Get target he's spectating
	if (!IsPlayerAlive(client) || IsClientObserver(client))
	{
		iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		if (iObserverMode == SPECMODE_FIRSTPERSON || iObserverMode == SPECMODE_3RDPERSON)
		{
			iClientToShow = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			
			// Check client index
			if (iClientToShow <= 0 || iClientToShow > MaxClients)
				return;
		}
		else
		{
			return; // don't proceed, if in freelook..
		}
	}
	g_iButtonsPressed[iClientToShow] = GetClientButtons(iClientToShow);
	
	
	fFlags = GetEntProp(iClientToShow, Prop_Data, "m_fFlags");
	if (GetEntProp(iClientToShow, Prop_Data, "m_nWaterLevel") > 1)
	{
		flClientPrevYaw[iClientToShow] = Angle[iClientToShow][1];
	}
	else if ((fFlags & FL_ONGROUND && !(g_iButtonsPressed[iClientToShow] & IN_JUMP)) && !IsFakeClient(iClientToShow))
	{
		// If we're on the ground and not jumping, we reset our last speed.
		flClientLastVel[client] = 0.0;
		flClientPrevYaw[client] = Angle[iClientToShow][1];
		
	}
	else if (Angle[iClientToShow][1] != flClientPrevYaw[iClientToShow] && (g_iButtonsPressed[iClientToShow] & IN_MOVELEFT || g_iButtonsPressed[iClientToShow] & IN_MOVERIGHT || g_iButtonsPressed[iClientToShow] & IN_FORWARD || g_iButtonsPressed[iClientToShow] & IN_BACK))
	{
		
		// Thing to remember: angle is a number between 180 and -180.
		// So we give 20 degree cap where this can be registered as strafing to the left.
		new iCurStrafe = (
			!(flClientPrevYaw[iClientToShow] < -170.0 && Angle[iClientToShow][1] > 170.0) // Make sure we didn't do -180 -> 180 because that would mean left when it's actually right.
			 && (Angle[client][1] > flClientPrevYaw[iClientToShow] // Is our current yaw bigger than last time? Strafing to the left.
				 || (flClientPrevYaw[iClientToShow] > 170.0 && Angle[iClientToShow][1] < -170.0))) // If that didn't pass, there might be a chance of 180 -> -180.
		 ? STRAFE_LEFT : STRAFE_RIGHT;
		
		
		if (iCurStrafe != iClientLastStrafe[iClientToShow])
			// Start of a new strafe.
		{
			// Calc previous strafe's sync. This will then be shown to the player.
			if (iClientLastStrafe[iClientToShow] != STRAFE_INVALID)
			{
				g_flClientSync[iClientToShow][iClientLastStrafe[iClientToShow]] = (g_flClientSync[iClientToShow][iClientLastStrafe[iClientToShow]] + iClientSync[iClientToShow][iClientLastStrafe[iClientToShow]] / float(iClientSync_Max[iClientToShow][iClientLastStrafe[iClientToShow]])) / 2.0;
			}
			
			// Reset the new strafe's variables.
			iClientSync[iClientToShow][iCurStrafe] = 1;
			iClientSync_Max[iClientToShow][iCurStrafe] = 1;
			iClientLastStrafe[iClientToShow] = iCurStrafe;
			g_nClientStrafeCount[iClientToShow]++;
			g_flClientAvgCurSync[iClientToShow] = (FloatAdd(Float:g_flClientSync[iClientToShow][STRAFE_LEFT], Float:g_flClientSync[iClientToShow][STRAFE_RIGHT]) / 2.0);
			g_flClientAvgSync1[iClientToShow] += g_flClientAvgCurSync[iClientToShow];
			if(g_nClientStrafeCount[iClientToShow] > 1)
				g_flClientAvgSync[iClientToShow] = g_flClientAvgSync1[iClientToShow] / g_nClientStrafeCount[iClientToShow];
			
		}
		
		
		Timer_GetCurrentSpeed(iClientToShow, flCurVel);
		
		// We're moving our mouse, but are we gaining speed?
		if (flCurVel > flClientLastVel[iClientToShow])iClientSync[iClientToShow][iCurStrafe]++;
		iClientSync_Max[iClientToShow][iCurStrafe]++;
		
		
		flClientLastVel[iClientToShow] = flCurVel;
	}
	flClientPrevYaw[iClientToShow] = Angle[iClientToShow][1];
	//start building HUD
	decl String:centerText[512]; //HUD buffer	
	
	
	
	//collect player stats
	decl String:buffer[32]; //time format buffer
	decl String:bestbuffer[32]; //time format buffer
	new bool:enabled; //tier running
	new Float:bestTime; //best round time
	new bestJumps; //best round jumps
	new jumps; //current jump count
	new fpsmax; //fps settings
	new bool:bonus = false; //track timer running
	new Float:CurrentTime; //current time
	new RecordId;
	new Float:RecordTime;
	new RankTotal;
	
	if (g_timerWorldRecord)Timer_GetClientTimer(iClientToShow, enabled, CurrentTime, jumps, fpsmax);
	
	new style;
	if (g_timerPhysics)style = Timer_GetStyle(iClientToShow);
	
	//get current player level
	new currentLevel = 0;
	if (g_timerMapzones)currentLevel = Timer_GetClientLevelID(iClientToShow);
	if (currentLevel < 1)currentLevel = 1;
	
	//bonuslevel?
	if (currentLevel > 1000)
	{
		bonus = true;
	}
	new ranked;
	if (g_timerPhysics)ranked = Timer_IsStyleRanked(style);
	//get bhop mode
	if (g_timerPhysics)
	{
		Timer_GetStyleRecordWRStats(style, bonus, RecordId, RecordTime, RankTotal);
		//correct fail format
		Timer_SecondsToTime(CurrentTime, buffer, sizeof(buffer), 0);
	}
	new rank;
	
	if (ranked && g_timerWorldRecord)
	{
		//get rank
		rank = Timer_GetStyleRank(iClientToShow, bonus, style);
	}
	//get speed
	new Float:maxspeed, Float:currentspeed, Float:avgspeed;
	if (g_timerPhysics)
	{
		Timer_GetMaxSpeed(iClientToShow, maxspeed);
		Timer_GetCurrentSpeed(iClientToShow, currentspeed);
		Timer_GetAvgSpeed(iClientToShow, avgspeed);
	}
	
	
	
	new prank;
	if (g_timerRankings)prank = Timer_GetPointRank(iClientToShow);
	
	if (prank > 2000 || prank < 1)prank = 2000;
	
	
	new String:sRankTotal[32];
	Format(sRankTotal, sizeof(sRankTotal), "%d", RankTotal);
	
	
	//start format center HUD
	
	new stagecount;
	
	if (g_timerMapzones)
	{
		if (bonus)
		{
			stagecount = Timer_GetMapzoneCount(ZtBonusLevel) + Timer_GetMapzoneCount(ZtBonusCheckpoint) + 1;
		}
		else
		{
			stagecount = Timer_GetMapzoneCount(ZtLevel) + Timer_GetMapzoneCount(ZtCheckpoint) + 1;
		}
	}
	
	if (currentLevel > 1000)currentLevel -= 1000;
	if (currentLevel == 999)currentLevel = stagecount;
	
	/*
	Time: 00:01 [Stage 3/4]
	Record: 01:55:41 [Rank: 3/4]
	Speed: 455.23 [Style: Auto]
	*/
	
	decl String:timeString[64];
	Timer_SecondsToTime(CurrentTime, timeString, sizeof(timeString), 1);
	
	if (StrEqual(timeString, "00:-0.0"))Format(timeString, sizeof(timeString), "00:00.0");
	
	//First Line
	
	
	//Format(centerText, sizeof(centerText), "%s | ", centerText);
	if (stagecount <= 1)
	{
		Format(centerText, sizeof(centerText), "<font size='16'> Stage: Linear<\font>		", centerText, currentLevel, stagecount);
	}
	else
	{
		Format(centerText, sizeof(centerText), "<font size='16'> Stage: %d/%d<\font>", centerText, currentLevel, stagecount);
		if ((stagecount < 20 && stagecount >= 10) && currentLevel > 1)
			Format(centerText, sizeof(centerText), "%s		", centerText);
		else if (stagecount >= 20)
			Format(centerText, sizeof(centerText), "%s		", centerText);
		else
			Format(centerText, sizeof(centerText), "%s			", centerText);
	}
	if (IsFakeClient(iClientToShow))
	{
		Format(centerText, sizeof(centerText), "%sRank: REPLAY", centerText, sRankTotal);
	}
	else if (rank < 1)
		Format(centerText, sizeof(centerText), "%sRank: -/%s", centerText, sRankTotal);
	else
		Format(centerText, sizeof(centerText), "%sRank: %d/%s", centerText, rank, sRankTotal);
	Format(centerText, sizeof(centerText), "%s\n", centerText);
	
	if (IsFakeClient(iClientToShow))
	{
		decl String:timeString1[64];
		g_fBotCurrentTime[iClientToShow] = GetGameTime() - g_fBotStartTime[iClientToShow];
		Timer_SecondsToTime(g_fBotCurrentTime[iClientToShow], timeString1, sizeof(timeString1), 1);
		Format(centerText, sizeof(centerText), "%s Time: <font color='#6666FF'>%s</font>", centerText, timeString1);
	}
	else if (Timer_GetPauseStatus(iClientToShow))
	{
		Format(centerText, sizeof(centerText), "%s Time: <font color='FF8A00'>Paused</font>", centerText, timeString);
	}
	else if (enabled)
	{
		if (RecordTime == 0.0 || RecordTime > CurrentTime)
		{
			Format(centerText, sizeof(centerText), "%s Time: <font color='#00ff00'>%s</font>", centerText, timeString);
		}
		else
		{
			Format(centerText, sizeof(centerText), "%s Time: <font color='#ff0000'>%s</font>", centerText, timeString);
		}
	}
	else 
	{
		Format(centerText, sizeof(centerText), "%s Time: <font color='#ff0000'>Stopped</font>", centerText);
		g_nClientStrafeCount[iClientToShow] = 1;
		g_flClientAvgSync1[iClientToShow] = 1.0;
		g_flClientAvgSync[iClientToShow] = 1.0;
	}
	
	//Format(centerText, sizeof(centerText), "%s     ", centerText);
	
	

	Format(centerText, sizeof(centerText), "%s		Style: %s", centerText, g_Physics[style][StyleName]);
	
	//if (rank < 1)
	//Format(centerText, sizeof(centerText), "%sRank: -/%s", centerText, sRankTotal);
	//else
	//Format(centerText, sizeof(centerText), "%sRank: %d/%s", centerText, rank, sRankTotal);
	//Secound Line
	//player rank
	new Cacheid;
	if (IsFakeClient(iClientToShow))
	{
		Timer_GetStyleRecordWRStats(style, 0, Cacheid, bestTime, bestJumps);
	}
	else
	{
		Timer_GetBestRound(iClientToShow, style, bonus, bestTime, bestJumps);
	}
	Timer_SecondsToTime(bestTime, bestbuffer, sizeof(bestbuffer), 2);
	Format(centerText, sizeof(centerText), "%s\n", centerText);
	Format(centerText, sizeof(centerText), "%s Record: %s", centerText, bestbuffer);
	//middle divider
	//Format(centerText, sizeof(centerText), "%s | ", centerText);
	//speed
	//Format(centerText, sizeof(centerText), "%s\n", centerText);
	//Format(centerText, sizeof(centerText), "%sSpeed: %5.2f", centerText, currentspeed);
	
	iButtons = g_iButtonsPressed[iClientToShow];
	if (iButtons & IN_FORWARD)
		Format(centerText, sizeof(centerText), "%s	   W", centerText);
	else
		Format(centerText, sizeof(centerText), "%s	    _", centerText);
	
	if (g_flClientAvgSync[iClientToShow] == 0.0)
		g_flClientAvgSync[iClientToShow] = 1.0;
	Format(centerText, sizeof(centerText), "%s	Sync: %.1f", centerText, g_flClientAvgSync[iClientToShow] * 100);
	Format(centerText, sizeof(centerText), "%s\n", centerText);
	
	
	Format(centerText, sizeof(centerText), "%s LG		", centerText);
	if (iButtons & IN_DUCK)
		Format(centerText, sizeof(centerText), "%sDUCK ", centerText);
	else
		Format(centerText, sizeof(centerText), "%s _____ ", centerText);
	
	// Is he pressing "a"?
	if (iButtons & IN_MOVELEFT)
		Format(centerText, sizeof(centerText), "%sA ", centerText);
	else
		Format(centerText, sizeof(centerText), "%s_  ", centerText);
	
	// Is he pressing "s"?
	if (iButtons & IN_BACK)
		Format(centerText, sizeof(centerText), "%sS ", centerText);
	else
		Format(centerText, sizeof(centerText), "%s_  ", centerText);
	
	// Is he pressing "d"?
	if (iButtons & IN_MOVERIGHT)
		Format(centerText, sizeof(centerText), "%sD ", centerText);
	else
		Format(centerText, sizeof(centerText), "%s_  ", centerText);
	Format(centerText, sizeof(centerText), "%sSpeed: %5.2f", centerText, currentspeed);
	
	
	
	//g_flClientAvgSync[iClientToShow] = ((g_flClientSync[iClientToShow][STRAFE_LEFT] + g_flClientSync[iClientToShow][STRAFE_RIGHT]) / 2) * 100; //get the average of the left and right strafe sync
	//Format(centerText, sizeof(centerText), "%s<font size='16'>   Sync: %.1f</font>", centerText, g_flClientAvgSync[iClientToShow]);
	
	if (!IsVoteInProgress())
	{
		PrintHintText(client, centerText);
	}
	
}


public OnTimerStopped(client)
{
	g_flClientAvgSync1[client] = 0.0;
	g_flClientAvgCurSync[client] = 0.0;
	g_flClientAvgSync[client] = 0.0;
	g_nClientStrafeCount[client] = 0;
}

stock GetSpecCount(client)
{
	new count = 0;
	
	for (new j = 1; j <= MaxClients; j++)
	{
		if (!IsClientInGame(j) || !IsClientObserver(j))
			continue;
		
		if (IsClientSourceTV(j))
			continue;
		
		new iSpecMode = GetEntProp(j, Prop_Send, "m_iObserverMode");
		
		// The client isn't spectating any one person, so ignore them.
		if (iSpecMode != SPECMODE_FIRSTPERSON && iSpecMode != SPECMODE_3RDPERSON)
			continue;
		
		// Find out who the client is spectating.
		new iTarget = GetEntPropEnt(j, Prop_Send, "m_hObserverTarget");
		
		// Are they spectating the same player as User?
		if (iTarget == client && j != client)
		{
			count++;
		}
	}
	
	return count;
} 