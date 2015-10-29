/*
 * SourceMod Hosties Project
 * by: databomb & dataviruset
 *
 * This file is part of the SM Hosties project.
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 */

// Double include protection
#if defined _LastRequest_Included_
	#endinput
#endif
#define _LastRequest_Included_

#define 	CHAT_BANNER			"\x03[SM] \x04%t"
#define 	NORMAL_VISION		90
#define 	MAX_DISPLAYNAME_SIZE		64
#define 	MAX_DATAENTRY_SIZE			5

// Custom types
enum LastRequest
{
	LR_KnifeFight = 0,
	LR_Shot4Shot,
	LR_GunToss,
	LR_ChickenFight,
	LR_HotPotato,
	LR_Dodgeball,
	LR_NoScope,
	LR_RockPaperScissors,
	LR_Rebel,
	LR_Mag4Mag,
	LR_Race,
	LR_RussianRoulette,
	LR_JumpContest
};

enum PartnersArray
{
	Block_LRType = 0,
	Block_Prisoner,
	Block_Guard,
	Block_PrisonerData,
	Block_GuardData,
	Block_Global1,
	Block_Global2,
	Block_Global3,
	Block_Global4,
	Block_DataPackHandle
};

enum DataType
{
	Type_Int = 0,
	Type_Float,
	Type_Handle,
	Type_LastRequest,
	Type_PartnerArray
};

enum LR_Structure
{
	DataType:LR_Type,
	DataType:Prisoner_Index,
	DataType:Guard_Index,
	DataType:Prisoner_Data,
	DataType:Guard_Data,
	DataType:Global1,
	DataType:Global2,
	DataType:Global3,
	DataType:Global4,
	DataType:TheDataPack
};

public SharedPlugin:__pl_lastrequest =
{
	name = "lastrequest",
	file = "sm_hosties.smx",
	#if defined REQUIRE_PLUGIN
	required = 1,
	#else
	required = 0,
	#endif
};

public __pl_lastrequest_SetNTVOptional()
{
	MarkNativeAsOptional("IsClientRebel");
	MarkNativeAsOptional("IsClientInLastRequest");
	MarkNativeAsOptional("AddLastRequestToList");
	MarkNativeAsOptional("RemoveLastRequestFromList");
	MarkNativeAsOptional("ProcessAllLastRequests");
	MarkNativeAsOptional("ChangeRebelStatus");
	MarkNativeAsOptional("InitializeLR");
	MarkNativeAsOptional("CleanupLR");
}

functag FuncLastRequest public(type, prisoner, guard);
functag FuncProcessLR public(Handle:array, iLRNumber);


forward OnStartLR(PrisonerIndex, GuardIndex, LR_Type);

forward OnAvailableLR(Announced);

/**
 * Find if a client is listed as a rebel.
 *
 * @param client				Client index.
 * @return						True if rebel, false otherwise.
 * @error                       Invalid client index.
 */
native bool:IsClientRebel(client);

/**
 * Find if a client is in a last request.
 *
 * @param client				Client index.
 * @return						False if not in LR
 *									Otherwise client index of partner or -1 if in LR but no partner exists
 * @error                       Invalid client index.
 */
native IsClientInLastRequest(client);

/**
 * Adds a custom last request.
 *
 * @param Start					Function call to when the LR is started.
 * @param Stop					Function call to when the LR is ended.
 * @param LR_Name				The name for the LR that will appear on the menu.
 * @param AutoStart				Whether the LR will start immediately (true) or if additional menus are needed (false).
 * @return						The type index of the LR added.
 */
native AddLastRequestToList(FuncProcessLR:Start, FuncLastRequest:Stop, String:LR_Name[], bool:AutoStart = true);

/**
 * Removes a custom last request.
 *
 * @param Start					Function call to when the LR is started.
 * @param Stop					Function call to when the LR is ended.
 * @param LR_Name				Name of the LR that appeared on the menu.
 * @noreturn
 * @error                     	Last request not found.
 */
native RemoveLastRequestFromList(FuncProcessLR:Start, FuncLastRequest:Stop, String:LR_Name[]);

/**
 * Provides iteration for all active last requests.
 *
 * @param ProcessLR				Function call to process each last request.
 * @param iLastRequestIndex		Index number of last request in array.
 * @return						Number of last requests in progress.
 */
native ProcessAllLastRequests(FuncProcessLR:ProcessLR, iLastRequestIndex);

/**
 * Alters the boolean array determining if a given client is considered a rebel.
 *
 * @param client				Client Index
 * @param status				Boolean Rebel Status (true = rebel)
 * @noreturn
 * @error						Invalid parameters
 */
native ChangeRebelStatus(client, status);

/**
 * Starts the lr if autostart is false.
 *
 * @param prisoner				Prisoner Index
 * @noreturn
 * @error						Invalid parameters or wrong client index
 */
native InitializeLR(prisoner);

/**
 * Cleanup the data about the autostart LR for a client.
 * (All the data stored by using the Prisoner's client index)
 *
 * @param prisoner				Prisoner Index
 * @noreturn
 * @error						Invalid parameters or wrong client index
 */
native CleanupLR(prisoner);

stock SetThirdPerson(client)
{
	if (IsValidEntity(client) && IsClientInGame(client))
	{
		if (GetEngineVersion() == Engine_CSGO)
		{
			ClientCommand(client, "thirdperson");
		}
		else
		{
			SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
			SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
			SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
			SetEntProp(client, Prop_Send, "m_iFOV", 120);
		}
	}
}

stock SetFirstPerson(client)
{
	if (IsValidEntity(client) && IsClientInGame(client))
	{
		if (GetEngineVersion() == Engine_CSGO)
		{
			ClientCommand(client, "firstperson");
		}
		else
		{
			SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", client);
			SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
			SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
			SetEntProp(client, Prop_Send, "m_iFOV", 90);
		}
	}
}

stock CancelAllMenus()
{
	for (new idx = 1; idx < MaxClients; idx++)
	{
		if (IsClientInGame(idx))
		{
			if (GetClientMenu(idx))
			{
				CancelClientMenu(idx);
			}
		}
	}
}

stock ClosePotentialLRMenus()
{
   for (new idx = 1; idx < MaxClients; idx++)
   {
      if (IsClientInGame(idx))
      {
			if (GetClientTeam(idx) == CS_TEAM_T)
			{
				if (GetClientMenu(idx))
				{
					CancelClientMenu(idx);
				}
			}
      }
   }
}

stock bool:PlayerHasGun(client)
{
	if (PlayerHasPrimary(client) || PlayerHasSecondary(client))
	{
		return true;
	}
	return false;
}

stock bool:PlayerHasPrimary(client)
{
	if (GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY) != -1)
	{
		return true;
	}
	return false;
}

stock bool:PlayerHasSecondary(client)
{
	if (GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY) != -1)
	{
		return true;
	}
	return false;
}

// filter function to ignore everything
public bool:Trace_FilterNothing(entity, contentsMask)
{
	return entity == 0;
}

// Based on Client_IsLookingAtWall, Edict_GetClosestToEdict from SM-LIB with permission from Berni
// detects if it's safe to teleport a player where the player is aiming
stock bool:IsClientTooNearObstacle(client, Float:distance = 110.0, bool:checkAllEntities = false)
{
	decl Float:posEye[3], Float:posEyeAngles[3], Float:vecOrigin[3], Float:vecOrigin_edict[3], String:Class_edict[64];
	new bool:isClientLookingAtWall = false;
	new bool:isClientCloseToEdict = false;

	GetClientAbsOrigin(client, vecOrigin);

	if (checkAllEntities)
	{
		for (new edict=1; edict <= GetMaxEntities(); edict++)
		{

			if (!IsValidEntity(edict))
			{
				continue;
			}

			GetEdictClassname(edict, Class_edict, sizeof(Class_edict));

			if (StrContains(Class_edict, "player") != -1)
			{
				continue;
			}

			if (StrContains(Class_edict, "weapon") != -1)
			{
				continue;
			}

			if (GetEntSendPropOffs(edict, "m_vecOrigin") == -1)
			{
				continue;
			}

			GetEntPropVector(edict, Prop_Data, "m_vecOrigin", vecOrigin_edict);

			new Float:edict_distance = GetVectorDistance(vecOrigin, vecOrigin_edict);

			if (edict_distance <= distance)
			{
				isClientCloseToEdict = true;
			}
		}
	}

	GetClientEyePosition(client, posEye);
	GetClientEyeAngles(client,	posEyeAngles);

	posEyeAngles[0] = 0.0;

	new Handle:trace = TR_TraceRayFilterEx(posEye, posEyeAngles, CONTENTS_SOLID, RayType_Infinite, Trace_FilterNothing);

	if (TR_DidHit(trace))
	{
		decl Float:posEnd[3];

		TR_GetEndPosition(posEnd, trace);

		if (GetVectorDistance(posEye, posEnd) <= distance)
		{
			new Float:m_vHullMin[3] = {-16.0, -16.0, 0.0};
			new Float:m_vHullMax[3] = {16.0, 16.0, 72.0};
			new Handle:hullTrace = 	TR_TraceHullEx(posEye, posEnd, m_vHullMin, m_vHullMax, CONTENTS_SOLID);
			if (TR_DidHit(hullTrace))
			{
				TR_GetEndPosition(posEnd, hullTrace);
				if (GetVectorDistance(posEye, posEnd) <= distance)
				{
					isClientLookingAtWall = true;
				}
			}
			CloseHandle(hullTrace);
		}
	}

	CloseHandle(trace);

	if (isClientCloseToEdict || isClientLookingAtWall)
	{
		return true;
	}
	return false;
}

enum GameType
{
  Game_Unknown = -1,
  Game_CSS,
  Game_CSGO
};

enum FreekillPunishment
{
  FP_Slay = 0,
  FP_Kick,
  FP_Ban
};

enum MediaType
{
  type_Generic = 0,
  type_Sound,
  type_Material,
  type_Model,
  type_Decal
};

stock ShowOverlayToClient(client, const String:overlaypath[])
{
  ClientCommand(client, "r_screenoverlay \"%s\"", overlaypath);
}

stock ShowOverlayToAll(const String:overlaypath[])
{
  // x = client index.
  for (new x = 1; x <= MaxClients; x++)
  {
    // If client isn't in-game, then stop.
    if (IsClientInGame(x) && !IsFakeClient(x))
    {
      ShowOverlayToClient(x, overlaypath);
    }
  }
}

stock StripAllWeapons(client)
{
  new wepIdx;
  for (new i; i < 4; i++)
  {
    while ((wepIdx = GetPlayerWeaponSlot(client, i)) != -1)
    {
      RemovePlayerItem(client, wepIdx);
      AcceptEntityInput(wepIdx, "Kill");
    }
  }
}

stock BlockEntity(client, cachedOffset)
{
  SetEntData(client, cachedOffset, 5, 4, true);
}

stock UnblockEntity(client, cachedOffset)
{
  SetEntData(client, cachedOffset, 2, 4, true);
}

stock BlockClientAll()
{
  for (new i = 1; i <= MaxClients; i++)
  {
    if ( IsClientInGame(i) && IsPlayerAlive(i) )
    {
      BlockEntity(i);
    }
  }
}

stock UnblockClientAll()
{
  for (new i = 1; i <= MaxClients; i++)
  {
    if ( IsClientInGame(i) && IsPlayerAlive(i) )
    {
      UnblockEntity(i);
    }
  }
}

stock MutePlayer(client)
{
  SetClientListeningFlags(client, VOICE_MUTED);
}

stock UnmutePlayer(client)
{
  SetClientListeningFlags(client, VOICE_NORMAL);
}

stock CacheTheFile(const String:path[], MediaType:filetype)
{
  decl String:sDownloadPath[PLATFORM_MAX_PATH];
  switch (filetype)
  {
    case type_Sound:
    {
      PrecacheSoundAny(path, true);
      Format(sDownloadPath, PLATFORM_MAX_PATH, "sound/%s", path);
      AddFileToDownloadsTable(sDownloadPath);
    }
    case type_Decal, type_Material:
    {
      PrecacheDecal(path, true);
      Format(sDownloadPath, PLATFORM_MAX_PATH, "materials/%s", path);
      AddFileToDownloadsTable(sDownloadPath);
    }
    case type_Model:
    {
      PrecacheModel(path, true);
      Format(sDownloadPath, PLATFORM_MAX_PATH, "models/%s", path);
      AddFileToDownloadsTable(sDownloadPath);
    }
    default:
    {
      PrecacheGeneric(path, true);
      AddFileToDownloadsTable(path);
    }
  }
}

// #pragma deprecated Use Hosties_GiveItem instead!
stock GiveItem(client, const String:sWeapon[], iSlot, bool:bAmmoReplace = false, bool:bNoScope = false)
{
  new iWeapon = GetPlayerWeaponSlot(client, iSlot);
  new Handle:hPack;

  if (iWeapon != INVALID_ENT_REFERENCE)
  {
    RemovePlayerItem(client, iWeapon);
    AcceptEntityInput(iWeapon, "Kill");
  }

  CreateDataTimer(0.1, Timer_GiveItem, hPack);

  WritePackCell(hPack, GetClientUserId(client));
  WritePackCell(hPack, iSlot);
  WritePackCell(hPack, bAmmoReplace);
  WritePackCell(hPack, bNoScope);

  WritePackString(hPack, sWeapon);
}

public Action:Timer_GiveItem(Handle:timer, Handle:hPack)
{
  new client, iSlot;
  new bool:bAmmoReplace, bool:bNoScope;
  decl String:sWeapon[64];

  ResetPack(hPack);

  client = GetClientOfUserId(ReadPackCell(hPack));
  iSlot = ReadPackCell(hPack);
  bAmmoReplace = ReadPackCell(hPack);
  bNoScope = ReadPackCell(hPack);

  ReadPackString(hPack, sWeapon, sizeof(sWeapon));

  if(IsClientInGame(client))
  {
    new iWeapon = GetPlayerWeaponSlot(client, iSlot);

    if (iWeapon != INVALID_ENT_REFERENCE)
    {
      return;
    }
    else
    {
      new iItem = GivePlayerItem(client, sWeapon);
      EquipPlayerWeapon(client, iItem);

      if(StrEqual(sWeapon, "weapon_awp", false) || StrEqual(sWeapon, "weapon_scout", false) || StrEqual(sWeapon, "weapon_ssg08", false) || StrEqual(sWeapon, "weapon_sg550", false) || StrEqual(sWeapon, "weapon_scar20", false) || StrEqual(sWeapon, "weapon_g3sg1", false))
      {
        if(bAmmoReplace)
        {
          Weapon_SetClips(iItem, 100, 100);
        }

        if(bNoScope)
        {
          SetNoScope(iItem);
        }
      }

      if(StrEqual(sWeapon, "weapon_m249", false))
      {
        if(bAmmoReplace)
        {
          Weapon_SetClips(iItem, 100, 200);
        }
      }

      if(StrEqual(sWeapon, "weapon_deagle", false))
      {
        if(bAmmoReplace)
        {
          Weapon_SetClips(iItem, 7, 35);
        }
      }
    }
  }
}

// Not finished yet
stock Hosties_GiveItem(client, const String:sWeapon[], iSlot, bool:bAmmoReplace = false, iPrimary, iSecondary, bool:bNoScope = false)
{
  new iWeapon = GetPlayerWeaponSlot(client, iSlot);
  new Handle:hPack;

  if (iWeapon != INVALID_ENT_REFERENCE)
  {
    RemovePlayerItem(client, iWeapon);
    AcceptEntityInput(iWeapon, "Kill");
  }

  CreateDataTimer(0.1, Timer_Hosties_GiveItem, hPack);

  WritePackCell(hPack, GetClientUserId(client));
  WritePackCell(hPack, iSlot);
  WritePackCell(hPack, bAmmoReplace);
  if(bAmmoReplace)
  {
    WritePackCell(hPack, iPrimary);
    WritePackCell(hPack, iSecondary);
  }
  WritePackCell(hPack, bNoScope);

  WritePackString(hPack, sWeapon);
}

public Action:Timer_Hosties_GiveItem(Handle:timer, Handle:hPack)
{
  new client, iSlot, iPrimary, iSecondary;
  new bool:bAmmoReplace, bool:bNoScope;
  decl String:sWeapon[64];

  ResetPack(hPack);

  client = GetClientOfUserId(ReadPackCell(hPack));
  iSlot = ReadPackCell(hPack);
  bAmmoReplace = ReadPackCell(hPack);
  if(bAmmoReplace)
  {
    iPrimary = ReadPackCell(hPack);
    iSecondary = ReadPackCell(hPack);
  }
  bNoScope = ReadPackCell(hPack);

  ReadPackString(hPack, sWeapon, sizeof(sWeapon));

  if(IsClientInGame(client))
  {
    new iWeapon = GetPlayerWeaponSlot(client, iSlot);

    if (iWeapon != INVALID_ENT_REFERENCE)
    {
      return;
    }
    else
    {
      new iItem = GivePlayerItem(client, sWeapon);
      EquipPlayerWeapon(client, iItem);

      if(bAmmoReplace)
      {
        Weapon_SetClips(iItem, iPrimary, iSecondary);
      }

      if(bNoScope)
      {
        SetNoScope(iItem);
      }
    }
  }
}

stock SetNoScope(weapon)
{
  if(IsValidEdict(weapon))
  {
    decl String:sWeapon[32];
    GetEdictClassname(weapon, sWeapon, sizeof(sWeapon));

    if(StrEqual(sWeapon, "weapon_awp", false) || StrEqual(sWeapon, "weapon_scout", false) || StrEqual(sWeapon, "weapon_ssg08", false) || StrEqual(sWeapon, "weapon_sg550", false) || StrEqual(sWeapon, "weapon_scar20", false) || StrEqual(sWeapon, "weapon_g3sg1", false))
    {
      new g_Offset_NextSecAttack = FindSendPropOffs("CBaseCombatWeapon", "m_flNextSecondaryAttack");
      SetEntDataFloat(weapon, g_Offset_NextSecAttack, GetGameTime() + 9999.9);
    }
  }
}

stock Hosties_CheckGame()
{
  if(GetEngineVersion() != Engine_CSS && GetEngineVersion() != Engine_CSGO)
  {
    SetFailState("Only Counter-Strike: Source and Counter-Strike: Global Offensive are supported");
  }
}
