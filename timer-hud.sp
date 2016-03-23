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
#include <timer-worldrecord>
#undef REQUIRE_PLUGIN
#include <timer-mapzones>
#include <timer-teams>
#include <timer-maptier>
#include <timer-rankings>
#include <timer-worldrecord>
#include <timer-physics>
#include <js_ljstats>


#define DEBUG

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
new Float:flClientPrevYaw[MAXPLAYERS];
new Float:flClientLastVel[MAXPLAYERS];
new iClientLastStrafe[MAXPLAYERS] =  { STRAFE_INVALID, ... };
new iClientSync[MAXPLAYERS][NUM_STRAFES];
new iClientSync_Max[MAXPLAYERS][NUM_STRAFES];
new g_iButtonsPressed[MAXPLAYERS + 1] =  { 0, ... };
new Float:g_flClientSync[MAXPLAYERS + 1][NUM_STRAFES];
new Float:g_flClientAvgCurSync[MAXPLAYERS + 1];
new Float:g_flClientAvgSync[MAXPLAYERS + 1];
new Float:g_flClientAvgSync1[MAXPLAYERS + 1];
new g_nClientStrafeCount[MAXPLAYERS + 1];
new Float:fClientCurrentSpeed[MAXPLAYERS];
new Bool:g_bHudSwitch;
public Plugin:myinfo = 
{
	name = "[Timer] HUD", 
	author = "Oliver", 
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
	
	
	
	LoadPhysics();
	LoadTimerSettings();
	
	LoadTranslations("timer.phrases");
	
	
	
	
	
	
	AutoExecConfig(true, "timer/timer-hud");
	
	
	
}

public OnMapStart()
{
	
	
	GetCurrentMap(g_currentMap, sizeof(g_currentMap));
	
	if (GetEngineVersion() == Engine_CSGO)
	{
		CreateTimer(0.1, HUDTimer_CSGO, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
		CreateTimer(2.0, HudSwitch, _, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
	}
	
	
	LoadPhysics();
	LoadTimerSettings();
}


public Action:HudSwitch(Handle:timer)
{
	if(g_bHudSwitch == true){
		g_bHudSwitch = false;
	} else {
		g_bHudSwitch = true;
	}
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
	ResetBot(client);
}
new Float:g_fBotStartTime[MAXPLAYERS + 1];



ResetBot(client)
{
	g_fBotStartTime[client] = GetGameTime();
	g_flClientAvgSync1[client] = 0.0;
	g_flClientAvgCurSync[client] = 0.0;
	g_flClientAvgSync[client] = 0.0;
	g_nClientStrafeCount[client] = 0;
}

CalculateSync(client)
{
	new Float:Angle[3];
	GetClientEyeAngles(client, Angle);
	new fFlags = GetEntProp(client, Prop_Data, "m_fFlags");
	
	if (GetEntProp(client, Prop_Data, "m_nWaterLevel") > 1)
	{
		flClientPrevYaw[client] = Angle[1];
	}
	
	if (fFlags & FL_ONGROUND && !(g_iButtonsPressed[client] & IN_JUMP))
	{
		// If we're on the ground and not jumping, we reset our last speed.
		flClientLastVel[client] = 0.0;
		flClientPrevYaw[client] = Angle[1];
		
	}
	else if (Angle[1] != flClientPrevYaw[client] && (g_iButtonsPressed[client] & IN_MOVELEFT || g_iButtonsPressed[client] & IN_MOVERIGHT || g_iButtonsPressed[client] & IN_FORWARD || g_iButtonsPressed[client] & IN_BACK))
	{
		
		// Thing to remember: angle is a number between 180 and -180.
		// So we give 20 degree cap where this can be registered as strafing to the left.
		new iCurStrafe = (
			!(flClientPrevYaw[client] < -170.0 && Angle[1] > 170.0) // Make sure we didn't do -180 -> 180 because that would mean left when it's actually right.
			 && (Angle[1] > flClientPrevYaw[client] // Is our current yaw bigger than last time? Strafing to the left.
				 || (flClientPrevYaw[client] > 179.0 && Angle[1] < -170.0))) // If that didn't pass, there might be a chance of 180 -> -180.
		 ? STRAFE_LEFT : STRAFE_RIGHT;
		
		
		if (iCurStrafe != iClientLastStrafe[client])
			// Start of a new strafe.
		{
			// Calc previous strafe's sync. This will then be shown to the player.
			if (iClientLastStrafe[client] != STRAFE_INVALID)
			{
				g_flClientSync[client][iClientLastStrafe[client]] = (g_flClientSync[client][iClientLastStrafe[client]] + iClientSync[client][iClientLastStrafe[client]] / float(iClientSync_Max[client][iClientLastStrafe[client]])) / 2.0;
				if (g_nClientStrafeCount[client] > 1)
				{
					g_flClientAvgCurSync[client] = FloatMul((FloatAdd(Float:g_flClientSync[client][STRAFE_LEFT], Float:g_flClientSync[client][STRAFE_RIGHT]) / 2.0), 0.95);
					g_flClientAvgSync1[client] += g_flClientAvgCurSync[client];
					g_flClientAvgSync[client] = g_flClientAvgSync1[client] / g_nClientStrafeCount[client];
				}
			}
			
			// Reset the new strafe's variables.
			iClientSync[client][iCurStrafe] = 1;
			iClientSync_Max[client][iCurStrafe] = 1;
			iClientLastStrafe[client] = iCurStrafe;
			g_nClientStrafeCount[client]++;
		}
		
		
		
		
		// We're moving our mouse, but are we gaining speed?
		if (fClientCurrentSpeed[client] > flClientLastVel[client])iClientSync[client][iCurStrafe]++;
		iClientSync_Max[client][iCurStrafe]++;
		
		
		flClientLastVel[client] = fClientCurrentSpeed[client];
	}
	flClientPrevYaw[client] = Angle[1];
}


map( x, in_min, in_max, out_min, out_max)
{
  if (x > in_max){
  	return out_max;
 }
  return (x - in_min) * (out_max - out_min) / (in_max - in_min) + out_min;
}

UpdateHUD_CSGO(client)
{
	if (!IsClientInGame(client))
	{
		return;
	}
	
	new iClientToShow = client;
	if (!IsPlayerAlive(client) || IsClientObserver(client))
	{
		new iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		if (iObserverMode == SPECMODE_FIRSTPERSON || iObserverMode == SPECMODE_3RDPERSON)
		{
			iClientToShow = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
			if (iClientToShow <= 0 || iClientToShow > MaxClients)
				return;
		}
		else
		{
			return;
		}
	}
	
	decl String:sWRTime[32]; //time format buffer
	decl String:sClientRecordTime[32];
	decl String:sClientCurrentTime[32];
	new bool:bEnabled;
	new Float:fWRTime;
	new Float:fClientRecordTime;
	new Float:fClientCurrentTime;
	new iStyle;
	new iTrack;
	new iTotalRanks;
	new iClientRank;
	new iClientJumps;
	new iFPSMax;
	new iRecordID;
	new iCurrentLevel;
	new iStageCount;
	
	
	
	iStyle = Timer_GetStyle(iClientToShow);
	if (iStyle == 8)
		return;
	iTrack = Timer_GetTrack(iClientToShow);
	g_iButtonsPressed[iClientToShow] = GetClientButtons(iClientToShow);
	Timer_GetCurrentSpeed(iClientToShow, fClientCurrentSpeed[iClientToShow]);
	Timer_GetStyleRecordWRStats(iStyle, iTrack, iRecordID, fWRTime, iTotalRanks);
	Timer_SecondsToTime(fWRTime, sWRTime, 32, 2);
	CalculateSync(iClientToShow);
	iCurrentLevel = Timer_GetClientLevelID(iClientToShow);
	iStageCount = Timer_GetMapzoneCount(ZtLevel) + Timer_GetMapzoneCount(ZtCheckpoint) + 1;
	if (iCurrentLevel < 1)
		iCurrentLevel = 1;
	if (iCurrentLevel > 1000)
		iCurrentLevel -= 1000;
	if (iCurrentLevel == 999)
		iCurrentLevel = iStageCount;
	
	if (!IsFakeClient(iClientToShow))
	{
		Timer_GetClientTimer(iClientToShow, bEnabled, fClientCurrentTime, iClientJumps, iFPSMax);
		Timer_SecondsToTime(fClientCurrentTime, sClientCurrentTime, 32, 1);
		if (!Timer_GetBestRound(iClientToShow, iStyle, iTrack, fClientRecordTime, iClientJumps))
			fClientRecordTime = 0.0;
		Timer_SecondsToTime(fClientRecordTime, sClientRecordTime, 32, 2);
		iClientRank = Timer_GetStyleRank(iClientToShow, iTrack, iStyle);
	}
	else
	{
		fClientCurrentTime = GetGameTime() - g_fBotStartTime[iClientToShow];
		Timer_SecondsToTime(fClientCurrentTime, sClientCurrentTime, 32, 1);
	}
	
	decl String:centerText[512];
	
	
	if (iTrack >= 1)
		Format(centerText, sizeof(centerText), "<font size='16'> Stage: Bonus %d<\font>		", iTrack);
	else if (Timer_IsPlayerTouchingZoneType(iClientToShow, ZtStart))
		Format(centerText, sizeof(centerText), "<font size='16'> Stage: Start<\font>		");
	else if (Timer_IsPlayerTouchingZoneType(iClientToShow, ZtEnd))
		Format(centerText, sizeof(centerText), "<font size='16'> Stage: End<\font>			");
	else if (iStageCount <= 1)
	{
		Format(centerText, sizeof(centerText), "<font size='16'> Stage: Linear<\font>		");
	}
	else
	{
		Format(centerText, sizeof(centerText), "<font size='16'> Stage: %d/%d<\font>", iCurrentLevel, iStageCount);
		if ((iStageCount < 20 && iStageCount >= 10) && iCurrentLevel > 1)
			Format(centerText, sizeof(centerText), "%s		", centerText);
		else if (iStageCount >= 20)
			Format(centerText, sizeof(centerText), "%s		", centerText);
		else
			Format(centerText, sizeof(centerText), "%s			", centerText);
	}
	
	if (IsFakeClient(iClientToShow))
	{
		Format(centerText, sizeof(centerText), "%sRank: REPLAY", centerText);
	}
	else if (iClientRank < 1)
		Format(centerText, sizeof(centerText), "%sRank: -/%d", centerText, iTotalRanks);
	else
		Format(centerText, sizeof(centerText), "%sRank: %d/%d", centerText, iClientRank, iTotalRanks);
	Format(centerText, sizeof(centerText), "%s\n", centerText);
	
	
	
	if (IsFakeClient(iClientToShow))
	{
		Format(centerText, sizeof(centerText), "%s Time:      <font color='#6666FF'>%s</font>		Style: %s", centerText, sClientCurrentTime, g_Physics[iStyle][StyleName]);
	}
	else if (Timer_GetPauseStatus(iClientToShow))
	{
		Format(centerText, sizeof(centerText), "%s Time:      <font color='#FFA700'>Paused</font>		Style: %s", centerText, g_Physics[iStyle][StyleName]);
	}
	else if (bEnabled)
	{
		if (fWRTime == 0.0){
			Format(centerText, sizeof(centerText), "%s Time:      <font color='#008744'>%s</font>		Style: %s", centerText, sClientCurrentTime, g_Physics[iStyle][StyleName]);
		} 
		else if (fWRTime > fClientCurrentTime)
		{
			//Format(centerText, sizeof(centerText), "%s Time:      <font color='#008744'>%s</font>		Style: %s", centerText, sClientCurrentTime, g_Physics[iStyle][StyleName]);
			new GreenR, GreenG, GreenB, RedR, RedG, RedB, NewR, NewG, NewB;
			GreenR = 0;
			GreenG = 135;
			GreenB = 68;
			RedR = 214;
			RedG = 45;
			RedB = 32;
			NewB = map(RoundFloat(fClientCurrentTime), 0, RoundFloat(fWRTime), GreenB, RedB);
		
			NewR = map(RoundFloat(fClientCurrentTime), 0, RoundFloat(fWRTime / 2), GreenR, RedR);
			//Format(centerText, sizeof(centerText), "%s Time:      <font color='#%02X%02X%02X'>%s</font>		Style: %s", centerText, NewR, GreenG, NewB, sClientCurrentTime, g_Physics[iStyle][StyleName]);
			if ((fWRTime / 2) < fClientCurrentTime){
				NewG = map(RoundFloat(fClientCurrentTime), RoundFloat(fWRTime / 2), RoundFloat(fWRTime), GreenG, RedG);
				//Format(centerText, sizeof(centerText), "%s Time:      <font color='#%02X%02X%02X'>%s</font>		Style: %s", centerText, NewR, NewG, NewB, sClientCurrentTime, g_Physics[iStyle][StyleName]);
			}
			else {
				NewG = GreenG;
			}
			//PrintToChatAll("%02X%02X%02X", NewR, NewG, NewB);
			//NewR = map(RoundFloat(fClientCurrentTime), 0, RoundFloat(fWRTime), GreenR, RedR);
			//NewG = map(RoundFloat(fClientCurrentTime), 0, RoundFloat(fWRTime), GreenG, RedG);
			//NewB = map(RoundFloat(fClientCurrentTime), 0, RoundFloat(fWRTime), GreenB, RedB);
			Format(centerText, sizeof(centerText), "%s Time:      <font color='#%02X%02X%02X'>%s</font>		Style: %s", centerText, NewR, NewG, NewB, sClientCurrentTime, g_Physics[iStyle][StyleName]);
		}
		else
		{
			Format(centerText, sizeof(centerText), "%s Time:      <font color='#d62d20'>%s</font>		Style: %s", centerText, sClientCurrentTime, g_Physics[iStyle][StyleName]);
		}
	}
	else
	{
		//Format(centerText, sizeof(centerText), "%s Time: <font color='#ff0000'>Stopped</font>", centerText);
		g_nClientStrafeCount[iClientToShow] = 1;
		g_flClientAvgSync1[iClientToShow] = 1.0;
		g_flClientAvgSync[iClientToShow] = 1.0;
		if(g_bHudSwitch){
			Format(centerText, sizeof(centerText), "%s Record: <font color='#0057e7'>%s</font>		Style: %s", centerText, sWRTime, g_Physics[iStyle][StyleName]);
		} else {
			if (fClientRecordTime == 0.0){
				Format(centerText, sizeof(centerText), "%s PB:          <font color='#4C89EE'>%s</font>	Style: %s", centerText, sClientRecordTime, g_Physics[iStyle][StyleName]);
			} else {
				Format(centerText, sizeof(centerText), "%s PB:          <font color='#4C89EE'>%s</font>		Style: %s", centerText, sClientRecordTime, g_Physics[iStyle][StyleName]);
			}
		}
	}
	
	//Format(centerText, sizeof(centerText), "%s		Style: %s", centerText, g_Physics[iStyle][StyleName]);
	
	Format(centerText, sizeof(centerText), "%s\n", centerText);
	/*
	if (IsFakeClient(iClientToShow))
	{
		Format(centerText, sizeof(centerText), "%s Record: %s", centerText, sWRTime);
	}
	else
	{
		Format(centerText, sizeof(centerText), "%s Record: %s", centerText, sClientRecordTime);
	}
	*/
	
	if (g_iButtonsPressed[iClientToShow] & IN_FORWARD)
		Format(centerText, sizeof(centerText), "%s		         W", centerText);
	else
		Format(centerText, sizeof(centerText), "%s		          _", centerText);
	
	if (g_flClientAvgSync[iClientToShow] == 0.0)
		g_flClientAvgSync[iClientToShow] = 1.0;
	Format(centerText, sizeof(centerText), "%s	Sync: %.1f%", centerText, g_flClientAvgSync[iClientToShow] * 100);
	Format(centerText, sizeof(centerText), "%s\n", centerText);
	
	
	
	Format(centerText, sizeof(centerText), "%s Alpha      ", centerText);
	if (g_iButtonsPressed[iClientToShow] & IN_DUCK)
		Format(centerText, sizeof(centerText), "%sDuck ", centerText);
	else
		Format(centerText, sizeof(centerText), "%s _____ ", centerText);
	
	// Is he pressing "a"?
	if (g_iButtonsPressed[iClientToShow] & IN_MOVELEFT)
		Format(centerText, sizeof(centerText), "%sA ", centerText);
	else
		Format(centerText, sizeof(centerText), "%s_  ", centerText);
	
	// Is he pressing "s"?
	if (g_iButtonsPressed[iClientToShow] & IN_BACK)
		Format(centerText, sizeof(centerText), "%sS ", centerText);
	else
		Format(centerText, sizeof(centerText), "%s_  ", centerText);
	
	// Is he pressing "d"?
	if (g_iButtonsPressed[iClientToShow] & IN_MOVERIGHT)
		Format(centerText, sizeof(centerText), "%sD ", centerText);
	else
		Format(centerText, sizeof(centerText), "%s_  ", centerText);
	
	
	
	
	
	
	Format(centerText, sizeof(centerText), "%s	Speed: %5.2f", centerText, fClientCurrentSpeed[iClientToShow]);
	

	PrintHintText(client, centerText);
}


public OnTimerStopped(client)
{
	g_flClientAvgSync1[client] = 0.0;
	g_flClientAvgCurSync[client] = 0.0;
	g_flClientAvgSync[client] = 0.0;
	g_nClientStrafeCount[client] = 0;
}
