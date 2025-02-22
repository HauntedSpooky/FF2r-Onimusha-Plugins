/*
"sentryhat"
{
    "level" "3" // Level of sentryhat
    "health" "100" // HP of sentryhat
    "flags" "8" // Flags (2 = invulnerable, 4 = upgradable, 8 = infinite ammo, etc.)
    "duration" "15.0" // Sentryhat's live time
    "type" "1" // Type of sentryhat (1 = normal, 2 = mini, 3 = disposable)
    "random" "0" // Randomization (0 = none, 1 = random level and type, 2 = random level, 3 = random type)
    "random_health" "0" // Enable random health
    "random_health_min" "0" // Min random health
    "random_health_max" "0" // Max random health
    
    "plugin_name"    "ff2r_ragesentry"
}

"Spawn_sentry"
{
    "level" "2" // Level of sentry
    "health" "100" // HP of sentry
    "flags" "8" // Flags (2 = invulnerable, 4 = upgradable, 8 = infinite ammo, etc.)
    "duration" "15.0" // Sentry's live time
    "type" "1" // Type of sentry (1 = normal, 2 = mini, 3 = disposable)
    "random" "2" // Randomization (0 = none, 1 = random level and type, 2 = random level, 3 = random type)
    "random_health" "0" // Enable random health
    "random_health_min" "0" // Min random health
    "random_health_max" "0" // Max random health
    
    "plugin_name"    "ff2r_ragesentry"
}

"teletrap"
{
    "health" "250" // HP of teletrap
    "duration" "10.0" // Teletrap duration
    "range" "2000" // Teletrap range
    "notify" "1" // Hud notification (0 = off, 1 = on)
     
     "plugin_name"    "ff2r_ragesentry"
}
	
*/

#pragma semicolon 1
#include <sourcemod>
#include <tf2_stocks>
#include <tf2>
#include <sdkhooks>
#include <sdktools>
#include <ff2r>

float g_pos[3];
float ReplaceO[3];
float ReplaceA[3];
int heal = 0;
int healhat = 0;

int Boss;

public Plugin myinfo = {
    name = "Freak Fortress 2 Rewrite: Sentry and Teleporter Abilities",
    author = "LeAlex14",
    description = "Allows bosses to spawn sentries, sentry hats, and teleporter traps.",
    version = "0.75.1"
}

public void FF2R_OnAbility(int client, const char[] ability_name, int status)
{
    if (strcmp(ability_name, "Spawn_sentry") == 0)
        Rage_sentry(client);

    if (strcmp(ability_name, "teletrap") == 0)
        teletraps(client);

    if (strcmp(ability_name, "sentryhat") == 0)
        Rage_sentryhat(client);
}

public Action Healsentry(Handle timer, int sentry)
{
    if (IsValidEntity(sentry))
        SetEntProp(sentry, Prop_Data, "m_iHealth", heal);
}

public Action Healsentryhat(Handle timer, int sentry)
{
    if (IsValidEntity(sentry))
        SetEntProp(sentry, Prop_Data, "m_iHealth", healhat);
}

public Action Destroysentry(Handle timer, int sentry)
{
    if (IsValidEntity(sentry))
        AcceptEntityInput(sentry, "Kill");
}

public Action Replace_sentry(Handle timer, int sentry)
{
    if (IsValidEntity(sentry))
    {
        GetClientAbsAngles(Boss, ReplaceA);
        GetClientAbsOrigin(Boss, ReplaceO);
        ReplaceO[2] += 50.0;
        TeleportEntity(sentry, ReplaceO, ReplaceA, NULL_VECTOR);
        CreateTimer(0.05, Replace_sentry, sentry, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Sentryhattimer(Handle timer, int sentry)
{
    if (IsValidEntity(sentry))
        AcceptEntityInput(sentry, "Kill");
}

void Rage_sentry(int client)
{
    Boss = client;
    int level = FF2R_GetAbilityArgument(client, "Spawn_sentry", "level", 2);
    int typesentry = FF2R_GetAbilityArgument(client, "Spawn_sentry", "type", 1);
    int random = FF2R_GetAbilityArgument(client, "Spawn_sentry", "random", 0);

    float flAng[3];
    GetClientEyeAngles(Boss, flAng);

    g_pos[2] -= 10.0;
    flAng[0] = 0.0;

    if (!SetTeleportEndPoint(Boss))
    {
        PrintToChat(Boss, "[SM] Could not find spawn point.");
        return;
    }

    if (random == 1)
    {
        typesentry = GetRandomInt(1, 3);
        level = GetRandomInt(1, 3);
    }
    else if (random == 2)
    {
        level = GetRandomInt(1, 3);
    }
    else if (random == 3)
    {
        typesentry = GetRandomInt(1, 3);
    }

    if (typesentry == 1)
        SpawnSentry(Boss, g_pos, flAng, level, false);
    else if (typesentry == 2)
        SpawnSentry(Boss, g_pos, flAng, level, true);
    else if (typesentry == 3)
        SpawnSentry(Boss, g_pos, flAng, level, false, true);
}

void Rage_sentryhat(int client)
{
    Boss = client;
    int levelhat = FF2R_GetAbilityArgument(client, "sentryhat", "level", 2);
    int typesentryhat = FF2R_GetAbilityArgument(client, "sentryhat", "type", 1);
    int randomhat = FF2R_GetAbilityArgument(client, "sentryhat", "random", 0);

    float flAng[3];
    GetClientEyeAngles(Boss, flAng);

    g_pos[2] -= 10.0;
    flAng[0] = 0.0;

    if (!SetTeleportEndPoint(Boss))
    {
        PrintToChat(Boss, "[SM] Could not find spawn point.");
        return;
    }

    if (randomhat == 1)
    {
        typesentryhat = GetRandomInt(1, 3);
        levelhat = GetRandomInt(1, 3);
    }
    else if (randomhat == 2)
    {
        levelhat = GetRandomInt(1, 3);
    }
    else if (randomhat == 3)
    {
        typesentryhat = GetRandomInt(1, 3);
    }

    g_pos[2] -= 10.0;
    flAng[0] = 0.0;

    if (typesentryhat == 1)
        SpawnSentryhat(Boss, g_pos, flAng, levelhat, false);
    else if (typesentryhat == 2)
        SpawnSentryhat(Boss, g_pos, flAng, levelhat, true);
    else if (typesentryhat == 3)
        SpawnSentryhat(Boss, g_pos, flAng, levelhat, false, true);
}

void SpawnSentry(int builder, float Position[3], float Angle[3], int level, bool mini = false, bool disposable = false)
{
    int sentry = CreateEntityByName("obj_sentrygun");
    if (IsValidEntity(sentry))
    {
        DispatchKeyValueVector(sentry, "origin", Position);
        DispatchKeyValueVector(sentry, "angles", Angle);

        if (mini)
        {
            SetEntProp(sentry, Prop_Send, "m_bMiniBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", level);
            SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", level);
            SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
            DispatchSpawn(sentry);

            SetEntProp(sentry, Prop_Data, "m_iHealth", heal);
        }
        else if (disposable)
        {
            SetEntProp(sentry, Prop_Send, "m_bMiniBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_bDisposableBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", level);
            SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", level);
            SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
            DispatchSpawn(sentry);

            SetEntProp(sentry, Prop_Data, "m_iHealth", heal);
        }
        else
        {
            SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", level);
            SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", level);
            SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
            DispatchSpawn(sentry);

            SetEntProp(sentry, Prop_Data, "m_iHealth", heal);
        }
    }
}

void SpawnSentryhat(int builder, float Position[3], float Angle[3], int level, bool mini = false, bool disposable = false)
{
    int sentry = CreateEntityByName("obj_sentrygun");
    if (IsValidEntity(sentry))
    {
        DispatchKeyValueVector(sentry, "origin", Position);
        DispatchKeyValueVector(sentry, "angles", Angle);

        if (mini)
        {
            SetEntProp(sentry, Prop_Send, "m_bMiniBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", level);
            SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", level);
            SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
            DispatchSpawn(sentry);

            SetEntProp(sentry, Prop_Data, "m_iHealth", healhat);
        }
        else if (disposable)
        {
            SetEntProp(sentry, Prop_Send, "m_bMiniBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_bDisposableBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", level);
            SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", level);
            SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
            DispatchSpawn(sentry);

            SetEntProp(sentry, Prop_Data, "m_iHealth", healhat);
        }
        else
        {
            SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", level);
            SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", level);
            SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
            SetEntProp(sentry, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
            DispatchSpawn(sentry);

            SetEntProp(sentry, Prop_Data, "m_iHealth", healhat);
        }

        float hattimeduration = FF2R_GetAbilityArgumentFloat(builder, "sentryhat", "duration", 15.0);
        CreateTimer(hattimeduration, Sentryhattimer, sentry, TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(0.05, Replace_sentry, sentry, TIMER_FLAG_NO_MAPCHANGE);
    }
}

void teletraps(int client)
{
    Boss = client;
    float flAng[3];
    SpawnTeleporter(Boss, g_pos, flAng, 1, TFObjectMode_Exit);
}

void SpawnTeleporter(int builder, float Position[3], float Angle[3], int level, TFObjectMode mode)
{
    int teleheal = FF2R_GetAbilityArgument(builder, "teletrap", "health", 500);
    float teleduration = FF2R_GetAbilityArgumentFloat(builder, "teletrap", "duration", 10.0);
    float Traprange = FF2R_GetAbilityArgumentFloat(builder, "teletrap", "range", 2500.0);
    int Notifyhud = FF2R_GetAbilityArgument(builder, "teletrap", "notify", 1);

    float pos[3];
    float pos2[3];
    float distance;

    GetEntPropVector(builder, Prop_Send, "m_vecOrigin", pos);
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(builder))
        {
            GetEntPropVector(i, Prop_Send, "m_vecOrigin", pos2);
            distance = GetVectorDistance(pos, pos2);
            if (distance < Traprange)
            {
                int teleporter = CreateEntityByName("obj_teleporter");
                GetClientAbsAngles(i, Angle);
                GetClientAbsOrigin(i, Position);
                Position[2] += 1.0;
                DispatchKeyValueVector(teleporter, "origin", Position);
                DispatchKeyValueVector(teleporter, "angles", Angle);

                SetEntProp(teleporter, Prop_Send, "m_iHighestUpgradeLevel", 1);
                SetEntProp(teleporter, Prop_Send, "m_bBuilding", 1);
                SetEntProp(teleporter, Prop_Data, "m_iTeleportType", mode);
                SetEntProp(teleporter, Prop_Send, "m_iObjectMode", mode);
                SetEntProp(teleporter, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
                DispatchSpawn(teleporter);

                AcceptEntityInput(teleporter, "SetBuilder", builder);
                SetVariantInt(GetClientTeam(builder));
                AcceptEntityInput(teleporter, "SetTeam");
                SetEntProp(teleporter, Prop_Data, "m_iHealth", teleheal);

                CreateTimer(teleduration, Destroysentry, teleporter, TIMER_FLAG_NO_MAPCHANGE);

                if (Notifyhud == 1)
                    PrintCenterText(i, "You have been teletrapped!");
            }
        }
    }
}

bool SetTeleportEndPoint(int client)
{
    float vAngles[3];
    float vOrigin[3];
    float vBuffer[3];
    float vStart[3];

    GetClientEyePosition(client, vOrigin);
    GetClientEyeAngles(client, vAngles);

    Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceEntityFilterPlayer);
    if (TR_DidHit(trace))
    {
        TR_GetEndPosition(vStart, trace);
        GetAngleVectors(vAngles, vBuffer, NULL_VECTOR, NULL_VECTOR);
        g_pos[0] = vStart[0] + (vBuffer[0] * -35.0);
        g_pos[1] = vStart[1] + (vBuffer[1] * -35.0);
        g_pos[2] = vStart[2] + (vBuffer[2] * -35.0);
        CloseHandle(trace);
        return true;
    }
    CloseHandle(trace);
    return false;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
    return entity > MaxClients || !entity;
}