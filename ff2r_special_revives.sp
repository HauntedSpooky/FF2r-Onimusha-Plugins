/*

    "special_revives" 
    {

        "slot"             "1"      //  0    Ability Slot
        "suicide"          "1"      //    respawn when suicide or killed by non-boss? 1 = yes 0 = no
        "revives"          "2"      // Player Max Revives
        "time"             "6.0"    //  delay between death and respawning
        "respawn"          "2"          // Respawn place: 0 - at death position, 1 - random teammate, 2 - spawn
        "uber"             "3"          // Float,   additional ubercharge duration after respawn
        "sound"            "freak_fortress_2/folder/respawn.mp3"         //  Sound to play when respawned.
        "stringrev"        "Your revives left: %amount"    // String, shows when you respawn and when you are in spect
        "stringcooldown"   "%%sec before your respawn"    //  string when you are dead and waiting for respawn
        "hudx"             "-1.0"    // X POSITION
        "hudy"             "0.80"    // Y POSITION
        "hudz"             "1.0"    // Z POSITION
        "colorr"           "255" // R Value
        "colorg"           "255" // G Value 
        "colorb"           "255" // B Value
        "colora"           "255" // A Value

        "plugin_name"    "ff2r_special_revives"
    }  

*/
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME     "Freak Fortress 2 Rewrite: Special Revives"
#define PLUGIN_AUTHOR   "Haunted Bone"
#define PLUGIN_DESC     "Special revives ability for FF2R"
#define PLUGIN_VERSION  "1.0.0"

#define MAXTF2PLAYERS   MAXPLAYERS + 1

int Revives_Remaining[MAXTF2PLAYERS]; 
float Revives_Time[MAXTF2PLAYERS];   
int Revives_Max[MAXTF2PLAYERS];       
float Revives_Delay[MAXTF2PLAYERS];  
int Revives_RespawnType[MAXTF2PLAYERS]; 
float Revives_Uber[MAXTF2PLAYERS];  
char Revives_Sound[MAXTF2PLAYERS][PLATFORM_MAX_PATH]; 
char Revives_StringRev[MAXTF2PLAYERS][256]; 
char Revives_StringCooldown[MAXTF2PLAYERS][256]; 
float Revives_HudX[MAXTF2PLAYERS];    
float Revives_HudY[MAXTF2PLAYERS];   
float Revives_HudZ[MAXTF2PLAYERS];   
int Revives_ColorR[MAXTF2PLAYERS];    
int Revives_ColorG[MAXTF2PLAYERS];   
int Revives_ColorB[MAXTF2PLAYERS];    
int Revives_ColorA[MAXTF2PLAYERS];   

bool g_bAllowSuicide[MAXTF2PLAYERS];  

Handle g_hHudSync; 

public Plugin myinfo = 
{
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESC,
    version     = PLUGIN_VERSION,
};

public void OnPluginStart()
{
    HookEvent("player_death", Event_PlayerDeath);
    g_hHudSync = CreateHudSynchronizer();
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
    if (!cfg.IsMyPlugin()) 
        return;

    if (StrEqual(ability, "special_revives", false))
    {
       
        Revives_Max[client] = cfg.GetInt("revives", 2);
        Revives_Delay[client] = cfg.GetFloat("time", 6.0);
        Revives_RespawnType[client] = cfg.GetInt("respawn", 2);
        Revives_Uber[client] = cfg.GetFloat("uber", 3.0);
        cfg.GetString("sound", Revives_Sound[client], PLATFORM_MAX_PATH, "freak_fortress_2/folder/respawn.mp3");
        cfg.GetString("stringrev", Revives_StringRev[client], 256, "Your revives left: %amount");
        cfg.GetString("stringcooldown", Revives_StringCooldown[client], 256, "%sec before your respawn");
        Revives_HudX[client] = cfg.GetFloat("hudx", -1.0);
        Revives_HudY[client] = cfg.GetFloat("hudy", 0.80);
        Revives_HudZ[client] = cfg.GetFloat("hudz", 1.0);
        Revives_ColorR[client] = cfg.GetInt("colorr", 255);
        Revives_ColorG[client] = cfg.GetInt("colorg", 255);
        Revives_ColorB[client] = cfg.GetInt("colorb", 255);
        Revives_ColorA[client] = cfg.GetInt("colora", 255);
        g_bAllowSuicide[client] = (cfg.GetInt("suicide", 1) != 0); 

        Revives_Remaining[client] = Revives_Max[client];
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client) || Revives_Remaining[client] <= 0 || GetClientTeam(client) != 2) 
        return;

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    bool isSuicide = (attacker == client || attacker == 0); 


    if ((isSuicide && g_bAllowSuicide[client]) || GetClientTeam(attacker) != GetClientTeam(client)) 
    {
        Revives_Remaining[client]--;
        Revives_Time[client] = GetGameTime() + Revives_Delay[client];


        char buffer[256];
        Format(buffer, sizeof(buffer), Revives_StringCooldown[client], Revives_Delay[client]);
        SetHudTextParams(Revives_HudX[client], Revives_HudY[client], Revives_HudZ[client], 
                         Revives_ColorR[client], Revives_ColorG[client], Revives_ColorB[client], Revives_ColorA[client]);
        ShowSyncHudText(client, g_hHudSync, buffer);

        CreateTimer(Revives_Delay[client], Timer_RespawnPlayer, GetClientUserId(client));
    }
}

public Action Timer_RespawnPlayer(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!IsValidClient(client) || IsPlayerAlive(client) || GetClientTeam(client) != 2) 
        return Plugin_Stop;


    switch (Revives_RespawnType[client])
    {
        case 0: 
        {
            float deathPos[3];
            GetClientAbsOrigin(client, deathPos);
            TeleportEntity(client, deathPos, NULL_VECTOR, NULL_VECTOR);
            TF2_RespawnPlayer(client);
        }
        case 1: 
        {
            int teammate = GetRandomAliveTeammate(client);
            if (teammate != -1)
            {
                float teammatePos[3];
                GetClientAbsOrigin(teammate, teammatePos);
                TeleportEntity(client, teammatePos, NULL_VECTOR, NULL_VECTOR);
                TF2_RespawnPlayer(client);
            }
            else
            {
                
                TF2_RespawnPlayer(client);
            }
        }
        case 2: 
        {
            TF2_RespawnPlayer(client);
        }
    }

    if (Revives_Uber[client] > 0.0)
    {
        TF2_AddCondition(client, TFCond_Ubercharged, Revives_Uber[client]);
    }

    if (Revives_Sound[client][0] != '\0')
    {
        EmitSoundToClient(client, Revives_Sound[client]);
    }

    char buffer[256];
    Format(buffer, sizeof(buffer), Revives_StringRev[client], Revives_Remaining[client]);
    SetHudTextParams(Revives_HudX[client], Revives_HudY[client], Revives_HudZ[client], 
                     Revives_ColorR[client], Revives_ColorG[client], Revives_ColorB[client], Revives_ColorA[client]);
    ShowSyncHudText(client, g_hHudSync, buffer);

    return Plugin_Continue;
}

stock int GetRandomAliveTeammate(int client)
{
    int[] teammates = new int[MaxClients];
    int count = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == GetClientTeam(client) && i != client)
        {
            teammates[count++] = i;
        }
    }

    if (count > 0)
    {
        return teammates[GetRandomInt(0, count - 1)];
    }

    return -1; 
}

stock bool IsValidClient(int client, bool replaycheck = true)
{
    if (client <= 0 || client > MaxClients)
        return false;

    if (!IsClientInGame(client) || !IsClientConnected(client))
        return false;

    if (GetEntProp(client, Prop_Send, "m_bIsCoaching"))
        return false;

    if (replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
        return false;

    return true;
}