//Wall Walking v1.1 by Pinkfairie

//Termination:
#pragma semicolon 1

//Includes:
#include <sourcemod>
#include <sdktools>

//Variables:
static bool:AllowSticking[MAXPLAYERS+1] = false;
static bool:Stick[MAXPLAYERS+1] = false;
static bool:Stuck[MAXPLAYERS+1] = false;

//Information:
public Plugin:myinfo = {
  name = "Wallstick",
  author = "LordOfPixels",
  description = "Allows users to stick to walls",
  version = "1.1",
  url = ""
}

//Initation:
public OnPluginStart() {

  //Commands:
  RegAdminCmd("sm_stick_player", Command_Stick_Player, ADMFLAG_KICK, "<Client> Toggles sticking on a player");
  RegConsoleCmd("sm_stick", Command_Stick, "Attempts to stick you to a wall");
}

public Action:Command_Stick_Player(iClient, Arguments) {

  //Default:
  if(Arguments < 2) {

    //Print:
    PrintToConsole(iClient, "Usage: sm_stick_player <#userid|name> <0/1>");

    //Return:
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
      AllowSticking[iTargetList[i]] = bEnable;
  }

  return Plugin_Handled;

}

public Action:Command_Stick(iClient, Arguments) {

  Stick[iClient] = true;

  return Plugin_Handled;
}

//Prethink:
public OnGameFrame() {
  //Loop:
  for(new i = 1; i < MaxClients; i++) {

    //Connected:
    if(IsClientConnected(i) && IsClientInGame(i) && IsPlayerAlive(i)) {

      //Wall?
      new bool:NearWall = false;

      //Circle:
      for(new AngleRotate = 0; AngleRotate < 360; AngleRotate += 30) {

        //Declare:
        decl Handle:TraceRay;
        decl Float:StartOrigin[3], Float:Angles[3];

        //Initialize:
        Angles[0] = 0.0;
        Angles[2] = 0.0;
        Angles[1] = float(AngleRotate);
        GetClientEyePosition(i, StartOrigin);

        //Ray:
        TraceRay = TR_TraceRayFilterEx(StartOrigin, Angles, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, IgnorePlayerEntity);

        //Collision:
        if(TR_DidHit(TraceRay)) {

          //Declare:
          decl Float:Distance;
          decl Float:EndOrigin[3];

          //Retrieve:
          TR_GetEndPosition(EndOrigin, TraceRay);

          //Distance:
          Distance = (GetVectorDistance(StartOrigin, EndOrigin));

          //Allowed:
          if(AllowSticking[i]) {
            if(Distance < 50) {
              NearWall = true;
            }
          }

        }

        //Close:
        CloseHandle(TraceRay);

      }

      //Ceiling:
      decl Handle:TraceRay;
      decl Float:StartOrigin[3];
      new Float:Angles[3] =  {270.0, 0.0, 0.0};

      //Initialize:
      GetClientEyePosition(i, StartOrigin);

      //Ray:
      TraceRay = TR_TraceRayFilterEx(StartOrigin, Angles, MASK_PLAYERSOLID_BRUSHONLY, RayType_Infinite, IgnorePlayerEntity);

      //Collision:
      if(TR_DidHit(TraceRay)) {
        //Declare:
        decl Float:Distance;
        decl Float:EndOrigin[3];

        //Retrieve:
        TR_GetEndPosition(EndOrigin, TraceRay);

        //Distance:
        Distance = (GetVectorDistance(StartOrigin, EndOrigin));

        //Allowed:
        if(AllowSticking[i]) {
          if(Distance < 50) {
            NearWall = true;
          }
        }
      }

      //Close:
      CloseHandle(TraceRay);

      //Near:
      if(NearWall) {
        if (AllowSticking[i]) {
          if (Stick[i]) {
            Stuck[i] = !Stuck[i];
          }
          if (Stuck[i]) {
            SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 0.0);
            new Float:ZeroVector[3] = {0.0, 0.0, 0.0};
            TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, ZeroVector);
          } else {
            SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.0);
          }
        }

      } else {
        Stuck[i] = false;
        SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.0);
      }

      if (!AllowSticking[i]) {
        Stuck[i] = false;
        SetEntPropFloat(i, Prop_Data, "m_flLaggedMovementValue", 1.0);
      }

      Stick[i] = false;
    }

  }

}

public bool: IgnorePlayerEntity(entity, contentsMask, any: data) {
  ResetPack(data);
  new client = ReadPackCell(data);

  if (entity == client) {
    return false;
  }

  return true;
}