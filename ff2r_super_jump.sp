/*
    "special_jump"
    {
        "slot"             "1"                     
        "options"          "1"                     
        "button"           "11"                    
        "charge"           "1.5"                   
        "cooldown"         "5.0"                   
        "delay"            "5.0"                  
        "upward"           "750 + (n * 3.25)"      
        "forward"          "1.0 + (n * 0.00275)"  
        "emergency"        "2000.0"               
        "strings_charge"   "Super Jump Charging [%.0f%%]" 
        "strings_cooldown" "Super Jump On Cooldown [%.1f]" 
        "strings"          "Super Jump Ready [Hold M2]"    
        "color"            "255 0 0 255"           

        "plugin_name"      "ff2r_super_jump"       
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

#define PLUGIN_NAME     "Freak Fortress 2 Rewrite: Super Jump with Color"
#define PLUGIN_AUTHOR   "Haunted Bone"
#define PLUGIN_DESC     "Adds a customizable Super Jump ability with color effects for FF2R bosses."
#define PLUGIN_VERSION  "1.0.1"

#define MAXTF2PLAYERS MAXPLAYERS + 1

public Plugin myinfo =
{
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = PLUGIN_DESC,
    version = PLUGIN_VERSION,
};

float g_flSuperJumpCharge[MAXTF2PLAYERS];
float g_flSuperJumpCooldown[MAXTF2PLAYERS];
float g_flSuperJumpDelay[MAXTF2PLAYERS];
bool g_bSuperJumpReady[MAXTF2PLAYERS];
int g_iSuperJumpColor[MAXTF2PLAYERS][4];
Handle g_hHudSync;


native int FF2R_GetBossIndex(int client);
native int FF2R_GetBossLevel(int client);

public void OnPluginStart()
{
    g_hHudSync = CreateHudSynchronizer();
    if (g_hHudSync == null)
    {
        LogError("Failed to create HUD synchronizer!");
    }

    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("teamplay_round_start", Event_RoundStart);
    HookEvent("player_death", Event_PlayerDeath);

    CreateTimer(0.1, Timer_UpdateHud, _, TIMER_REPEAT);
}

public void OnClientPutInServer(int client)
{
    ResetSuperJump(client);
}

void ResetSuperJump(int client)
{
    g_flSuperJumpCharge[client] = 0.0;
    g_flSuperJumpCooldown[client] = 0.0;
    g_flSuperJumpDelay[client] = 0.0;
    g_bSuperJumpReady[client] = false;
    g_iSuperJumpColor[client] = {255, 255, 255, 255}; 
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
    if (!cfg.IsMyPlugin())
        return;

    if (StrEqual(ability, "special_jump"))
    {
        char colorStr[32];
        cfg.GetString("color", colorStr, sizeof(colorStr), "255 255 255 255");
        ParseColorString(colorStr, g_iSuperJumpColor[client]);

        g_flSuperJumpCharge[client] = 100.0;
        g_bSuperJumpReady[client] = true;

        
        SetHudTextParams(-1.0, 0.8, 5.0, g_iSuperJumpColor[client][0], g_iSuperJumpColor[client][1], g_iSuperJumpColor[client][2], g_iSuperJumpColor[client][3]);
        ShowSyncHudText(client, g_hHudSync, "Super Jump Ready [Hold M2]");
    }
}

public Action Timer_UpdateHud(Handle timer)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsValidClient(client) && IsPlayerAlive(client) && FF2R_GetBossIndex(client) != -1)
        {
            char hudText[128];
            if (g_flSuperJumpCooldown[client] > GetGameTime())
            {
                Format(hudText, sizeof(hudText), "Super Jump On Cooldown [%.1f]", g_flSuperJumpCooldown[client] - GetGameTime());
            }
            else if (g_flSuperJumpCharge[client] < 100.0 && g_flSuperJumpCharge[client] > 0.0)
            {
                Format(hudText, sizeof(hudText), "Super Jump Charging [%.0f%%]", g_flSuperJumpCharge[client]);
            }
            else if (g_flSuperJumpCharge[client] >= 100.0)
            {
                Format(hudText, sizeof(hudText), "Super Jump Ready [Hold M2]");
            }
            else
            {
                Format(hudText, sizeof(hudText), "");
            }

            SetHudTextParams(-1.0, 0.8, 1.0, g_iSuperJumpColor[client][0], g_iSuperJumpColor[client][1], g_iSuperJumpColor[client][2], g_iSuperJumpColor[client][3]);
            ShowSyncHudText(client, g_hHudSync, hudText);
        }
    }

    return Plugin_Continue;
}

void ParseColorString(const char[] colorStr, int color[4])
{
    char buffer[4][8];
    ExplodeString(colorStr, " ", buffer, sizeof(buffer), sizeof(buffer[]));
    color[0] = StringToInt(buffer[0]); 
    color[1] = StringToInt(buffer[1]); 
    color[2] = StringToInt(buffer[2]); 
    color[3] = StringToInt(buffer[3]); 
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client))
        return;

    ResetSuperJump(client);

    if (FF2R_GetBossIndex(client) != -1)
    {
        g_flSuperJumpCharge[client] = 100.0;
        g_bSuperJumpReady[client] = true;

        
        SetHudTextParams(-1.0, 0.8, 5.0, g_iSuperJumpColor[client][0], g_iSuperJumpColor[client][1], g_iSuperJumpColor[client][2], g_iSuperJumpColor[client][3]);
        ShowSyncHudText(client, g_hHudSync, "Super Jump Ready [Hold M2]");
    }
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsValidClient(client) && FF2R_GetBossIndex(client) != -1)
        {
            ResetSuperJump(client);
            g_flSuperJumpCharge[client] = 100.0;
            g_bSuperJumpReady[client] = true;

            
            SetHudTextParams(-1.0, 0.8, 5.0, g_iSuperJumpColor[client][0], g_iSuperJumpColor[client][1], g_iSuperJumpColor[client][2], g_iSuperJumpColor[client][3]);
            ShowSyncHudText(client, g_hHudSync, "Super Jump Ready [Hold M2]");
        }
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(client))
        return;

    ShowSyncHudText(client, g_hHudSync, "");

    ResetSuperJump(client);
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

public Action OnPlayerRunCmd(int client, int &buttons)
{
    if (!IsValidClient(client) || !IsPlayerAlive(client)) 
        return Plugin_Continue;

    
    if (FF2R_GetBossIndex(client) == -1)
        return Plugin_Continue;

    static bool holdingM2[MAXTF2PLAYERS]; 

    if (buttons & IN_ATTACK2) 
    {
        if (!holdingM2[client])
        {
            holdingM2[client] = true;
        }

        if (g_flSuperJumpCharge[client] < 100.0)
        {
            g_flSuperJumpCharge[client] += 0.5; 
            if (g_flSuperJumpCharge[client] > 100.0)
            {
                g_flSuperJumpCharge[client] = 100.0; 
            }
        }
    }
    else if (holdingM2[client]) 
    {
        holdingM2[client] = false;

        if (g_flSuperJumpCharge[client] >= 100.0 && g_flSuperJumpCooldown[client] <= GetGameTime())
        {
           
            int bossLevel = FF2R_GetBossLevel(client); 
            float flJumpHeight = 750.0 + (bossLevel * 3.25); 
            float flForwardMulti = 1.0 + (bossLevel * 0.00275); 

            float flVelocity[3];
            GetEntPropVector(client, Prop_Data, "m_vecVelocity", flVelocity);
            flVelocity[2] = flJumpHeight; 
            flVelocity[0] *= flForwardMulti; 
            flVelocity[1] *= flForwardMulti; 
            TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, flVelocity);

            g_flSuperJumpCharge[client] = 0.0;
            g_flSuperJumpCooldown[client] = GetGameTime() + 5.0; 
            g_flSuperJumpDelay[client] = GetGameTime() + 5.0; 
        }
    }

    return Plugin_Continue;
}
