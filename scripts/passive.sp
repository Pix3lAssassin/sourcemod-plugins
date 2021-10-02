#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <sdkhooks>

public Plugin myinfo =
{
    name = "Passive",
    author = "LordOfPixels",
    version = "1.0",
    description = "Passive",
    url = "https://forums.alliedmods.net"
};

public void OnPluginStart()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i))
            OnClientPutInServer(i);
    }
}

public void OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
    damage = 0.0;
    return Plugin_Changed;
}