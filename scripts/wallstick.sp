#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

static bool:allowSticking[MAXPLAYERS+1] = false;
static bool:trySticking[MAXPLAYERS+1] = false;
static bool:stuck[MAXPLAYERS+1] = false;

public Plugin:myinfo = {
  name = "Wallstick",
  author = "LordOfPixels",
  description = "Allows users to stick to walls",
  version = "1.1",
  url = ""
}

public OnPluginStart() {
  RegAdminCmd("sm_stick_player", Command_Stick_Player, ADMFLAG_KICK, "<Client> Toggles sticking on a player");
  RegConsoleCmd("sm_stick", Command_Stick, "Attempts to stick you to a wall");
}

public Action:Command_Stick_Player(iClient, Arguments) {
  if(Arguments < 2) {
    PrintToConsole(iClient, "Usage: sm_stick_player <#userid|name> <0/1>");

    return Plugin_Handled;
  }

  decl String:szTarget[MAX_NAME_LENGTH+1];
  GetCmdArg(1, szTarget, sizeof(szTarget));

  decl String:szTargetName[MAX_TARGET_LENGTH+1];
  decl iTargetList[MAXPLAYERS+1], iTargetCount, bool:bTnIsMl;

  if ((iTargetCount = ProcessTargetString(
      szTarget,
      iClient,
      iTargetList,
      MAXPLAYERS,
      COMMAND_FILTER_CONNECTED,
      szTargetName,
      sizeof(szTargetName),
      bTnIsMl)) <= 0) {
    ReplyToTargetError(iClient, iTargetCount);
    return Plugin_Handled;
  }

  decl String:szEnable[2];
  GetCmdArg(2, szEnable, sizeof(szEnable));

  new bool:bEnable = !!StringToInt(szEnable);
  for (new i = 0; i < iTargetCount; i++) {
      allowSticking[iTargetList[i]] = bEnable;
  }

  return Plugin_Handled;
}

public Action:Command_Stick(iClient, Arguments) {
  if (allowSticking[iClient]) {
    trySticking[iClient] = true;
  }

  return Plugin_Handled;
}


public OnGameFrame() {

  for(new i = 1; i < MaxClients; i++) {


    if(IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i)) {

      if (trySticking[i] && !stuck[i]) {
        new bool:nearWall = false;

        // Circle
        for(new AngleRotate = 0; AngleRotate < 360; AngleRotate += 30) {

          decl Handle:TraceRay;
          decl Float:StartOrigin[3], Float:Angles[3];

          Angles[0] = 0.0;
          Angles[2] = 0.0;
          Angles[1] = float(AngleRotate);
          GetClientEyePosition(i, StartOrigin);

          TraceRay = TR_TraceRayFilterEx(StartOrigin, Angles, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, IgnorePlayerEntity);

          if(TR_DidHit(TraceRay)) {

            decl Float:Distance;
            decl Float:EndOrigin[3];

            TR_GetEndPosition(EndOrigin, TraceRay);

            Distance = (GetVectorDistance(StartOrigin, EndOrigin));

            if(allowSticking[i] && Distance < 50) {
              nearWall = true;
            }
          }

          CloseHandle(TraceRay);
        }

        // Ceiling
        decl Handle:TraceRay;
        decl Float:StartOrigin[3];
        new Float:Angles[3] =  {270.0, 0.0, 0.0};

        GetClientEyePosition(i, StartOrigin);

        TraceRay = TR_TraceRayFilterEx(StartOrigin, Angles, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, IgnorePlayerEntity);

        if(TR_DidHit(TraceRay)) {
          decl Float:Distance;
          decl Float:EndOrigin[3];

          TR_GetEndPosition(EndOrigin, TraceRay);

          Distance = (GetVectorDistance(StartOrigin, EndOrigin));

          if(Distance < 50) {
            nearWall = true;
          }
        }

        CloseHandle(TraceRay);

        if (nearWall) {
          stuck[i] = true;
          SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 0.0);
          new Float:ZeroVector[3] = {0.0, 0.0, 0.0};
          TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, ZeroVector);
        }
      } else if (trySticking[i] && stuck[i]) {
        stuck[i] = false;
        SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.0);
      } else if (!allowSticking[i] && stuck[i]) {
        stuck[i] = false;
        SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.0);
      }

      trySticking[i] = false;
    }
  }
}

public bool: IgnorePlayerEntity(entity, contentsMask, any: data) {
  for (new i = 1; i < MaxClients; i++) {
    if (entity == GetClientOfUserId(i)) {
      return false;
    }
  }

  return true;
}