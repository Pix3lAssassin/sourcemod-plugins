#include <sdktools>
#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0.0"

public Plugin: myinfo = {
  name = "Stalker",
  author = "LordOfPixels",
  description = "Provides commands to duplicate the experience of the stalker/hidden gamemodes from other source games",
  version = PLUGIN_VERSION,
  url = ""
}

new Handle: h_staminaCost = INVALID_HANDLE;
new Float: staminaCost;
const Float: maxStamina = 100.0;
new Float: currentStamina[MAXPLAYERS + 1];
new bool:showStamina[MAXPLAYERS+1];

const Float: defaultVertical = 400.0;

new Handle: h_multiplierHidden = INVALID_HANDLE;
new Float: multiplierHidden;

new Handle: h_staminaInterval = INVALID_HANDLE;
new Float: staminaInterval;

new Handle: h_stickStaminaDrain = INVALID_HANDLE;
new Float: stickStaminaDrain;

new Float:fallDamage[MAXPLAYERS+1];

new bool:isInvisible[MAXPLAYERS+1];
new bool:allowLaunching[MAXPLAYERS+1];
new bool:allowSticking[MAXPLAYERS+1] = false;
new bool:trySticking[MAXPLAYERS+1] = false;
new bool:stuck[MAXPLAYERS+1] = false;

public OnPluginStart() {
  new String: staminaCostInfo[55];
  Format(staminaCostInfo, sizeof(staminaCostInfo), "How much stamina used per jump (Max stamina - %.0f)", maxStamina);
  h_staminaCost = CreateConVar("sm_launch_stamina_cost", "20", staminaCostInfo, FCVAR_CHEAT, true, 0.01, true, 100.0);
  staminaCost = 20.0;
  HookConVarChange(h_staminaCost, ConVarChanged);

  h_multiplierHidden = CreateConVar("sm_launch_multiplier", "500", "Power of launch for sm_launch", FCVAR_CHEAT, true, 10.0, true, 10000.0);
  multiplierHidden = 500.0;
  HookConVarChange(h_multiplierHidden, ConVarChanged);

  h_staminaInterval = CreateConVar("sm_launch_interval", "15", "Number of seconds to fully refill stamina while on the ground", FCVAR_CHEAT, true, 1.0, true, 120.0);
  staminaInterval = 15.0;
  HookConVarChange(h_staminaInterval, ConVarChanged);

  h_stickStaminaDrain = CreateConVar("sm_stick_stamina_drain", "1", "Amount of stamina drained per second while stuck to a wall", FCVAR_CHEAT, true, 0.0, true, 100.0);
  stickStaminaDrain = 1.0;
  HookConVarChange(h_stickStaminaDrain, ConVarChanged);

  for(new i = 1; i <= MaxClients; i++) {
    if(IsClientInGame(i)) {
      OnClientPutInServer(i);
    }
  }

  RegAdminCmd("sm_launch_admin", Command_Launch_Admin, ADMFLAG_BAN, "Launch yourself forward in the direction you are looking with a specified power");
  RegAdminCmd("sm_launch_player", Command_Launch_Player, ADMFLAG_BAN, "Enable/Disable launching for a player");
  RegAdminCmd("sm_falldamage", Command_FallDamage, ADMFLAG_KICK, "Set the multiplier for fall damage for specific players");
  RegAdminCmd("sm_invisible", Command_Invisible, ADMFLAG_BAN, "Enable/Disable invisibility for a player");
  RegAdminCmd("sm_stick_player", Command_Stick_Player, ADMFLAG_KICK, "Toggles sticking on a player");
  RegAdminCmd("sm_stalker", Command_Stalker, ADMFLAG_BAN, "Enable/Disable stalker settings (invisility, no falldamage, launch, and stick) for a player");

  RegConsoleCmd("sm_launch", Command_Launch, "Launch yourself forward in the direction you are looking");
  RegConsoleCmd("sm_launch_visibility", Command_Launch_Visibility, "Enable - 1, Disable - 0 visiblity of stamina");
  RegConsoleCmd("sm_stick", Command_Stick, "Attempts to stick you to a wall");

  CreateTimer(1.0, CheckContact, _, TIMER_REPEAT);

  AutoExecConfig(_, "stalker");
}

public OnClientPutInServer(iClient) {
  currentStamina[iClient] = maxStamina;
  fallDamage[iClient] = 1.0;
  showStamina[iClient] = true;
  SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
  SDKHook(iClient, SDKHook_SetTransmit, Hook_SetTransmit);
}

public Action CheckContact(Handle timer) {
  for(new i = 1; i <= MaxClients; i++) {
    if (stuck[i]) {
      currentStamina[i] -= stickStaminaDrain;
    } else {
      if(GetEntityFlags(i) & FL_ONGROUND) {
        currentStamina[i] += (maxStamina / staminaInterval);
      } else {
        currentStamina[i] += maxStamina / (staminaInterval * 4);
      }
    }

    if (currentStamina[i] > maxStamina) {
      currentStamina[i] = maxStamina;
    } else if (currentStamina[i] < 0) {
      currentStamina[i] = 0.0;
    }

    if (showStamina[i] && currentStamina[i] < maxStamina - 0.1) {
      PrintCenterText(i, "Stamina - %d/%.0f", RoundToFloor(currentStamina[i]), maxStamina);
    }
  }
}

public ConVarChanged(Handle: cvar, const String: oldVal[], const String: newVal[]) {
  if(cvar == h_staminaCost) {
    staminaCost = StringToFloat(newVal);
    for(new i = 1; i <= MaxClients; i++) {
      if(IsClientInGame(i)) {
        currentStamina[i] = StringToFloat(newVal);
      }
    }
  }
  else if(cvar == h_multiplierHidden) {
    PrintToChatAll("%s", newVal);
    multiplierHidden = StringToFloat(newVal)
  }
  else if(cvar == h_multiplierHidden) {
    staminaInterval = StringToFloat(newVal)
  }
}

public Action: Command_Launch_Admin(iClient, iArgs) {
  if(iArgs < 1) {
    ReplyToCommand(iClient, "[SM] Usage: sm_launch_admin <power>");
    return Plugin_Handled;
  }


  decl String: sArg[64];
  GetCmdArg(1, sArg, sizeof(sArg));

  new Float: multiplier;
  multiplier = StringToFloat(sArg);

  if(IsClientInGame(iClient) && IsPlayerAlive(iClient)) {
    decl Float: eyes[3];
    decl Float: fVelocity[3];
    decl Float: newVelocity[3];

    GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);
    GetClientEyeAngles(iClient, eyes);

    newVelocity[0] = multiplier * (Cosine(DegToRad(eyes[1])) * FloatAbs(Cosine(DegToRad(eyes[0])))) + fVelocity[0];
    newVelocity[1] = multiplier * (Sine(DegToRad(eyes[1])) * FloatAbs(Cosine(DegToRad(eyes[0])))) + fVelocity[1];
    newVelocity[2] = multiplier * (Sine(DegToRad(eyes[0])) * -1) + fVelocity[2] + 250;

    TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, newVelocity);
  }

  return Plugin_Handled;
}

public Action: Command_Launch(iClient, iArgs) {
  if(IsClientInGame(iClient) && IsPlayerAlive(iClient) && allowLaunching[iClient] && (currentStamina[iClient]) >= staminaCost) {
    new Float: verticalAddition;

    decl Float: eyes[3];
    decl Float: fVelocity[3];
    decl Float: newVelocity[3];
    GetEntPropVector(iClient, Prop_Data, "m_vecVelocity", fVelocity);
    GetClientEyeAngles(iClient, eyes);

    if((Sine(DegToRad(eyes[0])) * -1) < 0) {
      verticalAddition = defaultVertical * (1 / Sine(DegToRad(eyes[0])) / 60);
    } else {
      verticalAddition = defaultVertical;
    }

    newVelocity[0] = multiplierHidden * (Cosine(DegToRad(eyes[1])) * FloatAbs(Cosine(DegToRad(eyes[0])))) + fVelocity[0];
    newVelocity[1] = multiplierHidden * (Sine(DegToRad(eyes[1])) * FloatAbs(Cosine(DegToRad(eyes[0])))) + fVelocity[1];
    newVelocity[2] = multiplierHidden * (Sine(DegToRad(eyes[0])) * -1) + fVelocity[2] + verticalAddition;

    TeleportEntity(iClient, NULL_VECTOR, NULL_VECTOR, newVelocity);

    currentStamina[iClient] -= staminaCost;
    PrintCenterText(iClient, "Stamina - %d/%.0f", RoundToFloor(currentStamina[iClient]), maxStamina);
  }

  return Plugin_Handled;
}

public Action:Command_Launch_Visibility(iClient, iArgCount) {
    if (iArgCount < 1) {
        showStamina[iClient] = !showStamina[iClient];
        return Plugin_Handled;
    }

    decl String:szEnable[2];
    GetCmdArg(1, szEnable, sizeof(szEnable));

    new bool:bEnable = !!StringToInt(szEnable);
    showStamina[iClient] = bEnable;

    return Plugin_Handled;
}

public Action:Command_FallDamage(iClient, iArgCount) {
    if (iArgCount < 2) {
        decl String:szCommand[13];
        GetCmdArg(0, szCommand, sizeof(szCommand));

        ReplyToCommand(iClient, "[SM] Usage: sm_falldamage <#userid|name> <multiplier>  (0 - No falldamage, 1 - regular falldamage)", szCommand);
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

    decl String:szMultiplier[3];
    GetCmdArg(2, szMultiplier, sizeof(szMultiplier));

    new Float:multiplier = StringToFloat(szMultiplier);
    for (new i = 0; i < iTargetCount; i++) {
        fallDamage[iTargetList[i]] = multiplier;
    }

    return Plugin_Handled;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) {
  if (damagetype == 32) {
    damage *= fallDamage[victim];
    return Plugin_Changed;
  }
  return Plugin_Continue;
}

public Action:Command_Invisible(iClient, iArgCount) {
    if (iArgCount < 2) {
        ReplyToCommand(iClient, "[SM] Usage: sm_invisible <#userid|name> <0/1>");
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
        isInvisible[iTargetList[i]] = bEnable;
    }

    return Plugin_Handled;
}

public Action:Command_Launch_Player(iClient, iArgCount) {
    if (iArgCount < 2) {
        ReplyToCommand(iClient, "[SM] Usage: sm_invisible <#userid|name> <0/1>");
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
        isInvisible[iTargetList[i]] = bEnable;
    }

    return Plugin_Handled;
}

public Action:Command_Stalker(iClient, iArgCount) {
    if (iArgCount < 2) {
        ReplyToCommand(iClient, "[SM] Usage: sm_stalker <#userid|name> <0/1>");
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
      isInvisible[iTargetList[i]] = bEnable;
      allowSticking[iTargetList[i]] = bEnable;
      fallDamage[iTargetList[i]] = bEnable ? 0.0 : 1.0;
      allowLaunching[iTargetList[i]] = bEnable;
    }

    return Plugin_Handled;
}

public Action:Command_Stick_Player(iClient, Arguments) {
  if(Arguments < 2) {
    PrintToConsole(iClient, "[SM] Usage: sm_stick_player <#userid|name> <0/1>");

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

      if (trySticking[i] && !stuck[i] && currentStamina[i] >= 1) {
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
      } else if (currentStamina[i] < 1 || (stuck[i] && (trySticking[i] || !allowSticking[i]))) {
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

public Action:Hook_SetTransmit(iClient, iOther) {
    if (isInvisible[iClient] && iClient != iOther) {
        return Plugin_Handled;
    }

    return Plugin_Continue;
}