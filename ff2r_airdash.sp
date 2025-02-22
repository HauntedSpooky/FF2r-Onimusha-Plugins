/*
"ff2_airdash_HUD"
{
    "slot"         "0"                     // Ability slot
    "tickrate"     "1"                     // Tickrate (don't change this)
    "max_charges"  "3"                     // Max dash charges
    "start_charges" "1"                    // Starting charges, do not set to 0 or they will not recharge
    "delay"        "1.0"                   // Delay before dashes become available at the start of the round
    "recharge_time" "10.0"                 // Time it takes to recharge a dash after one is used
    "dash_velocity" "2150"                 // Dash velocity
    "velocity_override" "1"                // Velocity override
    "cooldown"     "1.0"                   // Cooldown between dashes to prevent spam
    "air_time"     "15"                    // Time in ticks after player has left the ground before they can dash
    "sound_slot"   "1"                     // Which slot to take sounds from when dashing, set to -1 to make dashes silent
    "allow_glide"  "0"                     // Allow player to glide after a dash?
    "min_glide_speed" "-100.0"             // Minimum glide speed
    "glide_delay"  "15"                    // Time in ticks since dash until player can glide
    "max_glide_time" "0.0"                 // Max glide time
    "dash_key"     "2"                     // Key to use dash
    "hud_color_r"  "37"                    // HUD R Value
    "hud_color_g"  "109"                   // HUD G Value
    "hud_color_b"  "141"                   // HUD B Value
    "hud_color_a"  "141"                   // HUD A Value
    "hud_x"        "-1.0"                  // HUD X POS
    "hud_y"        "0.86"                  // HUD Y POS
    "hud_text"     "Dashes (HOLD Right Click): [%d / %d] - [CD: %.1f sec]" // HUD text
    "message"      "Dashes are now available Under Right Click Up To Max 3." // Message displayed on the screen
    
    "plugin_name"  "ff2r_airdash"
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

#define PLUGIN_NAME    "Freak Fortress 2 Rewrite: Airdash"
#define PLUGIN_AUTHOR  "Onimusha"
#define PLUGIN_DESC    "Airdash ability for FF2R"
#define PLUGIN_VERSION "1.0.0"

#define MAXTF2PLAYERS  MAXPLAYERS + 1
#define INACTIVE       100000000.0


int g_iMaxCharges[MAXTF2PLAYERS];
int g_iCurrentCharges[MAXTF2PLAYERS];
float g_flRechargeTime[MAXTF2PLAYERS];
float g_flDashVelocity[MAXTF2PLAYERS];
float g_flCooldown[MAXTF2PLAYERS];
float g_flLastDashTime[MAXTF2PLAYERS];
float g_flDelay[MAXTF2PLAYERS];
int g_iDashKey[MAXTF2PLAYERS];
bool g_bAllowGlide[MAXTF2PLAYERS];
float g_flMinGlideSpeed[MAXTF2PLAYERS];
float g_flMaxGlideTime[MAXTF2PLAYERS];
float g_flGlideDelay[MAXTF2PLAYERS];
bool g_bVelocityOverride[MAXTF2PLAYERS];
int g_iAirTime[MAXTF2PLAYERS];
float g_flLastGroundTime[MAXTF2PLAYERS];
int g_iSoundSlot[MAXTF2PLAYERS];
int g_iHudColor[4][MAXTF2PLAYERS]; // R, G, B, A
float g_flHudPos[2][MAXTF2PLAYERS]; // X, Y
char g_sHudText[MAXTF2PLAYERS][128];
char g_sMessage[MAXTF2PLAYERS][256];

public Plugin myinfo = {
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = PLUGIN_DESC,
    version = PLUGIN_VERSION,
    url = "https://github.com/YourRepository"
};

public void OnPluginStart()
{
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
}

public void OnClientDisconnect(int client)
{
    ResetClientVariables(client);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && FF2R_GetBossIndex(i) != -1) 
        {
            ResetClientVariables(i);
            InitializeDashAbility(i); 
        }
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsClientValid(client) && FF2R_GetBossIndex(client) != -1)
    {
        ResetClientVariables(client);
        InitializeDashAbility(client); 
    }
}

void InitializeDashAbility(int client)
{
    
    FF2R_AbilityData cfg = FF2R_GetAbilityData(client, "ff2_airdash_HUD");
    if (cfg == null)
        return;

    g_iMaxCharges[client] = cfg.GetInt("max_charges", 3);
    g_iCurrentCharges[client] = cfg.GetInt("start_charges", 1);
    g_flRechargeTime[client] = cfg.GetFloat("recharge_time", 10.0);
    g_flDashVelocity[client] = cfg.GetFloat("dash_velocity", 2150.0);
    g_flCooldown[client] = cfg.GetFloat("cooldown", 1.0);
    g_flDelay[client] = cfg.GetFloat("delay", 1.0);
    g_iDashKey[client] = cfg.GetInt("dash_key", 2); 
    g_bAllowGlide[client] = cfg.GetBool("allow_glide", false);
    g_flMinGlideSpeed[client] = cfg.GetFloat("min_glide_speed", -100.0);
    g_flMaxGlideTime[client] = cfg.GetFloat("max_glide_time", 0.0);
    g_flGlideDelay[client] = cfg.GetFloat("glide_delay", 15.0);
    g_bVelocityOverride[client] = cfg.GetBool("velocity_override", true);
    g_iAirTime[client] = cfg.GetInt("air_time", 15);
    g_iSoundSlot[client] = cfg.GetInt("sound_slot", 1);

    g_iHudColor[0][client] = cfg.GetInt("hud_color_r", 37);
    g_iHudColor[1][client] = cfg.GetInt("hud_color_g", 109);
    g_iHudColor[2][client] = cfg.GetInt("hud_color_b", 141);
    g_iHudColor[3][client] = cfg.GetInt("hud_color_a", 141);
    g_flHudPos[0][client] = cfg.GetFloat("hud_x", -1.0);
    g_flHudPos[1][client] = cfg.GetFloat("hud_y", 0.86);
    cfg.GetString("hud_text", g_sHudText[client], sizeof(g_sHudText[]), "Dashes (HOLD Right Click): [%d / %d] - [CD: %.1f sec]");
    cfg.GetString("message", g_sMessage[client], sizeof(g_sMessage[]), "Dashes are now available Under Right Click Up To Max 3.");

    PrintToChat(client, g_sMessage[client]);

    
    CreateTimer(0.1, Timer_UpdateHUD, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    CreateTimer(g_flDelay[client], Timer_ActivateAirdash, client);
}

public Action Timer_UpdateHUD(Handle timer, int client)
{
    if (!IsClientValid(client) || !IsPlayerAlive(client) || g_iMaxCharges[client] <= 0)
        return Plugin_Stop;

    float cooldown = g_flRechargeTime[client] - (GetGameTime() - g_flLastDashTime[client]);
    if (cooldown < 0.0)
        cooldown = 0.0;

    char hudText[128];
    Format(hudText, sizeof(hudText), g_sHudText[client], g_iCurrentCharges[client], g_iMaxCharges[client], cooldown);

    SetHudTextParams(g_flHudPos[0][client], g_flHudPos[1][client], 0.1, g_iHudColor[0][client], g_iHudColor[1][client], g_iHudColor[2][client], g_iHudColor[3][client], 0, 0.0, 0.0, 0.0);
    ShowHudText(client, -1, hudText);

    return Plugin_Continue;
}

public Action Timer_ActivateAirdash(Handle timer, int client)
{
    if (!IsClientValid(client) || !IsPlayerAlive(client))
        return Plugin_Stop;

    CreateTimer(0.1, Timer_Airdash, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Continue;
}

public Action Timer_Airdash(Handle timer, int client)
{
    if (!IsClientValid(client) || !IsPlayerAlive(client))
        return Plugin_Stop;

    if (GetGameTime() - g_flLastGroundTime[client] < g_iAirTime[client] * 0.1)
        return Plugin_Continue;

    if (IsPlayerPressingDashKey(client, g_iDashKey[client]) && g_iCurrentCharges[client] > 0 && (GetGameTime() - g_flLastDashTime[client]) >= g_flCooldown[client])
    {
        PerformAirdash(client);
    }

    return Plugin_Continue;
}

void PerformAirdash(int client)
{
    float eyeAngles[3];
    GetClientEyeAngles(client, eyeAngles);

    float direction[3];
    GetAngleVectors(eyeAngles, direction, NULL_VECTOR, NULL_VECTOR);

    float velocity[3];
    if (g_bVelocityOverride[client])
    {
        velocity[0] = direction[0] * g_flDashVelocity[client];
        velocity[1] = direction[1] * g_flDashVelocity[client];
        velocity[2] = direction[2] * g_flDashVelocity[client];
    }
    else
    {
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
        velocity[0] += direction[0] * g_flDashVelocity[client];
        velocity[1] += direction[1] * g_flDashVelocity[client];
        velocity[2] += direction[2] * g_flDashVelocity[client];
    }

    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);

    float pos[3];
    GetClientAbsOrigin(client, pos);
    TE_SetupGlowSprite(pos, PrecacheModel("sprites/glow01.vmt"), 1.0, 1.0, 255);
    TE_SendToAll();

    if (g_iSoundSlot[client] != -1)
    {
        EmitSoundToAll("freak_fortress_2/boss/dash1.mp3", client, g_iSoundSlot[client]);
    }

    g_iCurrentCharges[client]--;
    g_flLastDashTime[client] = GetGameTime();

    if (g_iCurrentCharges[client] < g_iMaxCharges[client])
    {
        CreateTimer(g_flRechargeTime[client], Timer_RechargeCharge, client);
    }

    if (g_bAllowGlide[client])
    {
        CreateTimer(g_flGlideDelay[client], Timer_StartGlide, client);
    }
}

public Action Timer_RechargeCharge(Handle timer, int client)
{
    if (IsClientValid(client) && IsPlayerAlive(client))
    {
        g_iCurrentCharges[client]++;
    }

    return Plugin_Stop;
}

public Action Timer_StartGlide(Handle timer, int client)
{
    if (!IsClientValid(client) || !IsPlayerAlive(client))
        return Plugin_Stop;

    float velocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);

    if (velocity[2] < g_flMinGlideSpeed[client])
    {
        velocity[2] = g_flMinGlideSpeed[client];
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
    }

    if (g_flMaxGlideTime[client] > 0.0)
    {
        CreateTimer(g_flMaxGlideTime[client], Timer_StopGlide, client);
    }

    return Plugin_Continue;
}

public Action Timer_StopGlide(Handle timer, int client)
{
    if (!IsClientValid(client) || !IsPlayerAlive(client))
        return Plugin_Stop;

    float velocity[3];
    GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
    velocity[2] = 0.0;
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);

    return Plugin_Continue;
}

bool IsPlayerPressingDashKey(int client, int key)
{
    switch (key)
    {
        case 1: return (GetClientButtons(client) & IN_ATTACK) != 0;
        case 2: return (GetClientButtons(client) & IN_ATTACK2) != 0;
        case 3: return (GetClientButtons(client) & IN_RELOAD) != 0;
        case 4: return (GetClientButtons(client) & IN_USE) != 0;
        case 5: return (GetClientButtons(client) & IN_JUMP) != 0;
        case 6: return (GetClientButtons(client) & IN_DUCK) != 0;
    }
    return false;
}

bool IsClientValid(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}

void ResetClientVariables(int client)
{
    g_iMaxCharges[client] = 0;
    g_iCurrentCharges[client] = 0;
    g_flRechargeTime[client] = 0.0;
    g_flDashVelocity[client] = 0.0;
    g_flCooldown[client] = 0.0;
    g_flLastDashTime[client] = 0.0;
    g_flDelay[client] = 0.0;
    g_iDashKey[client] = 0;
    g_bAllowGlide[client] = false;
    g_flMinGlideSpeed[client] = 0.0;
    g_flMaxGlideTime[client] = 0.0;
    g_flGlideDelay[client] = 0.0;
    g_bVelocityOverride[client] = false;
    g_iAirTime[client] = 0;
    g_flLastGroundTime[client] = 0.0;
    g_iSoundSlot[client] = 0;
    g_iHudColor[0][client] = 0;
    g_iHudColor[1][client] = 0;
    g_iHudColor[2][client] = 0;
    g_iHudColor[3][client] = 0;
    g_flHudPos[0][client] = 0.0;
    g_flHudPos[1][client] = 0.0;
    g_sHudText[client][0] = '\0';
    g_sMessage[client][0] = '\0';
}
