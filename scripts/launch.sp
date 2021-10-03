#include <sdktools>
#include <sourcemod>
#include <sdkhooks>

#define PLUGIN_VERSION "1.1.0"


public Plugin: myinfo = {
  name = "Launch",
  author = "LordOfPixels",
  description = "Launch in the direction your looking",
  version = PLUGIN_VERSION,
  url = ""
}

new Handle: gH_Enabled = INVALID_HANDLE;
new bool: gB_Enabled;

new Handle: h_staminaCost = INVALID_HANDLE;
new Float: staminaCost;
const Float: maxStamina = 100.0;
new Float: currentStamina[MAXPLAYERS + 1];
new bool:showStamina[MAXPLAYERS+1];

new Handle: h_multiplierHidden = INVALID_HANDLE;
new Float: multiplierHidden;

new Handle: h_staminaInterval = INVALID_HANDLE;
new Float: staminaInterval;

new Handle: tercera_cvar;

new bool:fallDamage[MAXPLAYERS+1];

const Float: defaultVertical = 400.0;

public OnPluginStart() {
  gH_Enabled = CreateConVar("sm_launch_enabled", "0", "Whether sm_launch is enabled", FCVAR_CHEAT, true, 0.0, true, 1.0);
  gB_Enabled = true;
  HookConVarChange(gH_Enabled, ConVarChanged);

  new String: staminaCostInfo[55];
  Format(staminaCostInfo, sizeof(staminaCostInfo), "How much stamina used per jump (Max stamina - %.0f)", maxStamina);
  h_staminaCost = CreateConVar("sm_launch_stamina_cost", "33", staminaCostInfo, FCVAR_CHEAT, true, 0.01, true, 100.0);
  staminaCost = 33.0;
  for(new i = 1; i <= MaxClients; i++) {
    if(IsClientInGame(i)) {
      OnClientPutInServer(i);
    }
  }
  HookConVarChange(h_staminaCost, ConVarChanged);

  h_multiplierHidden = CreateConVar("sm_launch_multiplier", "600", "Power of launch for sm_launch", FCVAR_CHEAT, true, 10.0, true, 10000.0);
  multiplierHidden = 600.0;
  HookConVarChange(h_multiplierHidden, ConVarChanged);

  h_staminaInterval = CreateConVar("sm_launch_interval", "15", "Number of seconds to fully refill stamina while on the ground", FCVAR_CHEAT, true, 1.0, true, 120.0);
  staminaInterval = 15.0;
  HookConVarChange(h_staminaInterval, ConVarChanged);


  RegAdminCmd("sm_launch_admin", Command_Launch_Admin, ADMFLAG_CUSTOM1, "Launch yourself forward in the direction you are looking");
  RegAdminCmd("sm_falldamage", Command_FallDamage, ADMFLAG_CUSTOM1, "sm_falldamage <#userid|name> <0/1> - Enable - 1 or Disable - 0 fall damage for a player");

  RegConsoleCmd("sm_launch", Command_Launch, "Launch yourself forward in the direction you are looking");
  RegConsoleCmd("sm_launch_visibility", Command_Launch_Visibility, "Enable - 1, Disable - 0 visiblity of stamina");

  CreateTimer(1.0, CheckContact, _, TIMER_REPEAT);

  AutoExecConfig(_, "launch");
}

public OnClientPutInServer(iClient) {
  currentStamina[iClient] = maxStamina;
  fallDamage[iClient] = true;
  showStamina[iClient] = true;
  SDKHook(iClient, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action CheckContact(Handle timer) {
  for(new i = 1; i <= MaxClients; i++) {
    new Float: oldStamina = currentStamina[i];
    if(GetEntityFlags(i) & FL_ONGROUND) {
      currentStamina[i] += maxStamina / staminaInterval;
    }
    else {
      currentStamina[i] += maxStamina / (staminaInterval * 4);
    }

    if (currentStamina[i] > maxStamina) {
      currentStamina[i] = maxStamina;
    }

    if (RoundToFloor(currentStamina[i] / staminaCost) > RoundToFloor(oldStamina / staminaCost) && showStamina[i]) {
      PrintCenterText(i, "Stamina - %d/%.0f", RoundToFloor(currentStamina[i]), maxStamina);
    }
  }
}

public ConVarChanged(Handle: cvar, const String: oldVal[], const String: newVal[]) {
  if(cvar == gH_Enabled) {
    gB_Enabled = StringToInt(newVal) ? true: false;
  }
  else if(cvar == h_staminaCost) {
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
  else if(cvar == tercera_cvar) {
    if(StringToInt(newVal) != 1) {
      SetConVarInt(tercera_cvar, 1);
    }
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
  if(IsClientInGame(iClient) && IsPlayerAlive(iClient) && gB_Enabled && (currentStamina[iClient]) >= staminaCost) {
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
    if (iArgCount < 2) {
        decl String:szCommand[20];
        GetCmdArg(0, szCommand, sizeof(szCommand));

        ReplyToCommand(iClient, "\x01Usage: \x07%s \x02<#userid|name> \x01<0/1> Default - '1'", szCommand);
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
        showStamina[iTargetList[i]] = bEnable;
    }

    return Plugin_Handled;
}

public Action:Command_FallDamage(iClient, iArgCount) {
    if (iArgCount < 2) {
        decl String:szCommand[13];
        GetCmdArg(0, szCommand, sizeof(szCommand));

        ReplyToCommand(iClient, "\x01Usage: \x07%s \x02<#userid|name> \x01<0/1>", szCommand);
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
        fallDamage[iTargetList[i]] = bEnable;
    }

    return Plugin_Handled;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3]) {
  if (!fallDamage[victim] && damagetype == 32) {
    damage = 0.0;
    return Plugin_Changed;
  }
  return Plugin_Continue;
}