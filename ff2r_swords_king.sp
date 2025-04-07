/*
    "sword_aura"
    {
        "slot"                "0"         
        "duration"            "10.0"      
        "radius"              "100.0"     
        "sword_speed"         "2.0"      
        "sword_count"         "5"        
        "damage"              "10.0"      
        "model"               "models/weapons/c_models/c_claidheamohmor.mdl"
        "glow_color"          "255 0 0"   
        "trail_effect"        "1"        
        "sound_loop"          "weapons/medigun_heal.wav" // Dźwięk pętli
        "sound_hit"           "weapons/samurai/tf_katana_slash_01.wav" 
        
        "plugin_name"         "ff2r_swords_king"
    }

    "sword_recall"
    {
        "slot"                "0"
        "sword_count"         "6"
        "damage"              "45.0"
        "speed"               "1200.0"
        "range"               "800.0"
        "model"               "models/weapons/c_models/c_claidheamohmor.mdl"
        "sound_throw"         "weapons/samurai/tf_katana_swing.wav"
        "sound_return"        "weapons/medigun_heal.wav"
        "trail_effect"        "1"
        
        "plugin_name"         "ff2r_swords_king"
    }

    "sword_tornado"
    {
        "slot"                "0"
        "duration"            "12.0"
        "sword_count"         "15"
        "damage"              "35.0"
        "pull_force"          "800.0"
        "height"              "300.0"
        "model"               "models/weapons/c_models/c_claidheamohmor.mdl"
        "sound_loop"          "ambient/wind/windgust.wav"
        "particle_effect"     "invasion_ray_gun_fx"
        
        "plugin_name"         "ff2r_swords_king"
    }
*/

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>
#undef REQUIRE_PLUGIN
#include <tf2attributes>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN_NAME    "Freak Fortress 2 Rewrite: Swords King"
#define PLUGIN_AUTHOR  "Haunted Bone"
#define PLUGIN_DESC    "Multiple sword abilities for FF2R"
#define PLUGIN_VERSION "1.2.0"

#define MAXTF2PLAYERS MAXPLAYERS+1
#define MAX_SWORDS 15
#define COLLISION_DISTANCE 50.0
#define SWORD_HEIGHT 50.0

enum TrailType
{
    TRAIL_NONE = 0,
    TRAIL_STANDARD,
    TRAIL_BLOODY
}

// Shared sword data
char g_szSwordModel[MAXTF2PLAYERS][PLATFORM_MAX_PATH];
int g_iGlowColor[MAXTF2PLAYERS][3];
TrailType g_eTrailEffect[MAXTF2PLAYERS];

// Sword Aura
float g_flAuraDuration[MAXTF2PLAYERS];
float g_flAuraRadius[MAXTF2PLAYERS];
float g_flAuraSpeed[MAXTF2PLAYERS];
int g_iAuraSwordCount[MAXTF2PLAYERS];
float g_flAuraDamage[MAXTF2PLAYERS];
char g_szAuraSoundLoop[MAXTF2PLAYERS][PLATFORM_MAX_PATH];
char g_szAuraSoundHit[MAXTF2PLAYERS][PLATFORM_MAX_PATH];
int g_iAuraSwords[MAXTF2PLAYERS][MAX_SWORDS];
int g_iAuraTrails[MAXTF2PLAYERS][MAX_SWORDS];
float g_flAuraAngles[MAXTF2PLAYERS][MAX_SWORDS];
int g_iAuraSoundLoopEnt[MAXTF2PLAYERS] = {INVALID_ENT_REFERENCE, ...};

// Sword Recall
int g_iRecallSwordCount[MAXTF2PLAYERS];
float g_flRecallDamage[MAXTF2PLAYERS];
float g_flRecallSpeed[MAXTF2PLAYERS];
float g_flRecallRange[MAXTF2PLAYERS];
char g_szRecallThrowSound[MAXTF2PLAYERS][PLATFORM_MAX_PATH];
char g_szRecallReturnSound[MAXTF2PLAYERS][PLATFORM_MAX_PATH];
int g_iRecallSwords[MAXTF2PLAYERS][MAX_SWORDS];
bool g_bRecallReturning[MAXTF2PLAYERS][MAX_SWORDS];
float g_flRecallTargetPos[MAXTF2PLAYERS][MAX_SWORDS][3];

// Sword Tornado
float g_flTornadoDuration[MAXTF2PLAYERS];
int g_iTornadoSwordCount[MAXTF2PLAYERS];
float g_flTornadoDamage[MAXTF2PLAYERS];
float g_flTornadoPullForce[MAXTF2PLAYERS];
float g_flTornadoHeight[MAXTF2PLAYERS];
char g_szTornadoSound[MAXTF2PLAYERS][PLATFORM_MAX_PATH];
char g_szTornadoParticle[MAXTF2PLAYERS][PLATFORM_MAX_PATH];
int g_iTornadoSwords[MAXTF2PLAYERS][MAX_SWORDS];
int g_iTornadoParticle[MAXTF2PLAYERS] = {INVALID_ENT_REFERENCE, ...};

public Plugin myinfo = 
{
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = PLUGIN_DESC,
    version = PLUGIN_VERSION,
    url = "https://github.com/TwojRepozytorium"
};

public void OnPluginStart()
{
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("teamplay_round_end", Event_RoundEnd);
    PrecacheSound("weapons/medigun_heal.wav");
    PrecacheSound("weapons/samurai/tf_katana_slash_01.wav");
    PrecacheSound("weapons/samurai/tf_katana_swing.wav");
    PrecacheSound("ambient/wind/windgust.wav");
}

public void OnMapEnd()
{
    for(int i = 1; i <= MaxClients; i++)
    {
        DestroyAuraSwords(i);
        DestroyTornado(i);
    }
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
    if(!cfg.IsMyPlugin())
        return;

    if(StrEqual(ability, "sword_aura"))
    {
        g_flAuraDuration[client] = cfg.GetFloat("duration", 10.0);
        g_flAuraRadius[client] = cfg.GetFloat("radius", 100.0);
        g_flAuraSpeed[client] = cfg.GetFloat("sword_speed", 2.0);
        g_iAuraSwordCount[client] = cfg.GetInt("sword_count", 5);
        g_flAuraDamage[client] = cfg.GetFloat("damage", 10.0);
        cfg.GetString("model", g_szSwordModel[client], PLATFORM_MAX_PATH, "models/weapons/c_models/c_claidheamohmor.mdl");
        
        char glowColor[32];
        cfg.GetString("glow_color", glowColor, sizeof(glowColor), "255 0 0");
        char colors[3][4];
        ExplodeString(glowColor, " ", colors, 3, 4);
        g_iGlowColor[client][0] = StringToInt(colors[0]);
        g_iGlowColor[client][1] = StringToInt(colors[1]);
        g_iGlowColor[client][2] = StringToInt(colors[2]);
        
        g_eTrailEffect[client] = view_as<TrailType>(cfg.GetInt("trail_effect", 1));
        cfg.GetString("sound_loop", g_szAuraSoundLoop[client], PLATFORM_MAX_PATH, "weapons/medigun_heal.wav");
        cfg.GetString("sound_hit", g_szAuraSoundHit[client], PLATFORM_MAX_PATH, "weapons/samurai/tf_katana_slash_01.wav");
        
        if(!StrEqual(g_szAuraSoundLoop[client], "weapons/medigun_heal.wav"))
            PrecacheSound(g_szAuraSoundLoop[client]);
        if(!StrEqual(g_szAuraSoundHit[client], "weapons/samurai/tf_katana_slash_01.wav"))
            PrecacheSound(g_szAuraSoundHit[client]);
        
        if(g_iAuraSwordCount[client] > MAX_SWORDS)
            g_iAuraSwordCount[client] = MAX_SWORDS;

        CreateAuraSwords(client);
        CreateTimer(0.05, Timer_ManageAuraSwords, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(g_flAuraDuration[client], Timer_EndAuraAbility, GetClientUserId(client));
        
        PlayAuraLoopSound(client);
    }
    else if(StrEqual(ability, "sword_recall"))
    {
        g_iRecallSwordCount[client] = cfg.GetInt("sword_count", 6);
        g_flRecallDamage[client] = cfg.GetFloat("damage", 45.0);
        g_flRecallSpeed[client] = cfg.GetFloat("speed", 1200.0);
        g_flRecallRange[client] = cfg.GetFloat("range", 800.0);
        cfg.GetString("model", g_szSwordModel[client], PLATFORM_MAX_PATH, "models/weapons/c_models/c_claidheamohmor.mdl");
        cfg.GetString("sound_throw", g_szRecallThrowSound[client], PLATFORM_MAX_PATH, "weapons/samurai/tf_katana_swing.wav");
        cfg.GetString("sound_return", g_szRecallReturnSound[client], PLATFORM_MAX_PATH, "weapons/medigun_heal.wav");
        g_eTrailEffect[client] = view_as<TrailType>(cfg.GetInt("trail_effect", 1));

        ThrowRecallSwords(client);
    }
    else if(StrEqual(ability, "sword_tornado"))
    {
        g_flTornadoDuration[client] = cfg.GetFloat("duration", 12.0);
        g_iTornadoSwordCount[client] = cfg.GetInt("sword_count", 15);
        g_flTornadoDamage[client] = cfg.GetFloat("damage", 35.0);
        g_flTornadoPullForce[client] = cfg.GetFloat("pull_force", 800.0);
        g_flTornadoHeight[client] = cfg.GetFloat("height", 300.0);
        cfg.GetString("model", g_szSwordModel[client], PLATFORM_MAX_PATH, "models/weapons/c_models/c_claidheamohmor.mdl");
        cfg.GetString("sound_loop", g_szTornadoSound[client], PLATFORM_MAX_PATH, "ambient/wind/windgust.wav");
        cfg.GetString("particle_effect", g_szTornadoParticle[client], PLATFORM_MAX_PATH, "invasion_ray_gun_fx");

        CreateSwordTornado(client);
    }
}

// ========================
// SWORD AURA FUNCTIONALITY
// ========================

public Action Timer_ManageAuraSwords(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if(!IsValidClient(client) || !IsPlayerAlive(client))
    {
        DestroyAuraSwords(client);
        return Plugin_Stop;
    }

    float bossPos[3];
    GetClientAbsOrigin(client, bossPos);
    bossPos[2] += SWORD_HEIGHT;

    for(int i = 0; i < g_iAuraSwordCount[client]; i++)
    {
        if(!IsValidEntity(g_iAuraSwords[client][i]))
            continue;

        g_flAuraAngles[client][i] += g_flAuraSpeed[client];
        if(g_flAuraAngles[client][i] > 360.0)
            g_flAuraAngles[client][i] -= 360.0;

        float swordPos[3];
        swordPos[0] = bossPos[0] + g_flAuraRadius[client] * Cosine(DegToRad(g_flAuraAngles[client][i]));
        swordPos[1] = bossPos[1] + g_flAuraRadius[client] * Sine(DegToRad(g_flAuraAngles[client][i]));
        swordPos[2] = bossPos[2];

        int target = FindClosestEnemy(client, swordPos);
        float angles[3];
        
        if(target != -1)
        {
            float targetPos[3];
            GetClientAbsOrigin(target, targetPos);
            targetPos[2] += 40.0; 
            
            float direction[3];
            SubtractVectors(targetPos, swordPos, direction);
            GetVectorAngles(direction, angles);
        }
        else
        {
            angles[0] = 0.0;
            angles[1] = g_flAuraAngles[client][i];
            angles[2] = 0.0;
        }

        TeleportEntity(g_iAuraSwords[client][i], swordPos, angles, NULL_VECTOR);
        
        CheckSwordCollision(client, g_iAuraSwords[client][i], swordPos, g_flAuraDamage[client], g_szAuraSoundHit[client]);
    }
    
    return Plugin_Continue;
}

public Action Timer_EndAuraAbility(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if(IsValidClient(client))
    {
        DestroyAuraSwords(client);
    }
    return Plugin_Stop;
}

void CreateAuraSwords(int client)
{
    PrecacheModel(g_szSwordModel[client]);

    for(int i = 0; i < g_iAuraSwordCount[client]; i++)
    {
        g_iAuraSwords[client][i] = CreateEntityByName("prop_dynamic_override");
        if(g_iAuraSwords[client][i] != -1)
        {
            SetEntityModel(g_iAuraSwords[client][i], g_szSwordModel[client]);
            DispatchKeyValue(g_iAuraSwords[client][i], "solid", "0");
            DispatchSpawn(g_iAuraSwords[client][i]);
            
            TF2_CreateGlow(g_iAuraSwords[client][i], g_iGlowColor[client]);
            
            CreateTrail(g_iAuraSwords[client][i], g_eTrailEffect[client]);
            
            g_flAuraAngles[client][i] = 360.0 / g_iAuraSwordCount[client] * i;
        }
    }
}

void DestroyAuraSwords(int client)
{
    StopAuraLoopSound(client);
    
    for(int i = 0; i < g_iAuraSwordCount[client]; i++)
    {
        if(IsValidEntity(g_iAuraSwords[client][i]))
        {
            RemoveEntity(g_iAuraSwords[client][i]);
            g_iAuraSwords[client][i] = -1;
        }
        
        if(IsValidEntity(g_iAuraTrails[client][i]))
        {
            RemoveEntity(g_iAuraTrails[client][i]);
            g_iAuraTrails[client][i] = -1;
        }
    }
}

void PlayAuraLoopSound(int client)
{
    if(g_szAuraSoundLoop[client][0] == '\0')
        return;
        
    int sound = CreateEntityByName("ambient_generic");
    if(sound != -1)
    {
        DispatchKeyValue(sound, "message", g_szAuraSoundLoop[client]);
        DispatchKeyValue(sound, "health", "10");
        DispatchKeyValue(sound, "spawnflags", "16");
        DispatchSpawn(sound);
        
        float pos[3];
        GetClientAbsOrigin(client, pos);
        TeleportEntity(sound, pos, NULL_VECTOR, NULL_VECTOR);
        
        SetVariantString("!activator");
        AcceptEntityInput(sound, "SetParent", client);
        
        AcceptEntityInput(sound, "Play");
        
        g_iAuraSoundLoopEnt[client] = EntIndexToEntRef(sound);
    }
}

void StopAuraLoopSound(int client)
{
    if(g_iAuraSoundLoopEnt[client] != INVALID_ENT_REFERENCE)
    {
        int entity = EntRefToEntIndex(g_iAuraSoundLoopEnt[client]);
        if(entity > MaxClients && IsValidEntity(entity))
        {
            AcceptEntityInput(entity, "Stop");
            RemoveEntity(entity);
        }
        g_iAuraSoundLoopEnt[client] = INVALID_ENT_REFERENCE;
    }
}

// ========================
// SWORD RECALL FUNCTIONALITY
// ========================

void ThrowRecallSwords(int client)
{
    float eyePos[3], eyeAng[3];
    GetClientEyePosition(client, eyePos);
    GetClientEyeAngles(client, eyeAng);
    
    EmitSoundToAll(g_szRecallThrowSound[client], client);
    
    for(int i = 0; i < g_iRecallSwordCount[client]; i++)
    {
        g_iRecallSwords[client][i] = CreateEntityByName("prop_physics_override");
        if(g_iRecallSwords[client][i] != -1)
        {
            SetEntityModel(g_iRecallSwords[client][i], g_szSwordModel[client]);
            DispatchKeyValue(g_iRecallSwords[client][i], "solid", "2");
            DispatchSpawn(g_iRecallSwords[client][i]);
            
            float spreadAngle[3];
            spreadAngle[0] = eyeAng[0] + GetRandomFloat(-15.0, 15.0);
            spreadAngle[1] = eyeAng[1] + GetRandomFloat(-15.0, 15.0);
            
            float endPos[3];
            GetAngleVectors(spreadAngle, endPos, NULL_VECTOR, NULL_VECTOR);
            ScaleVector(endPos, g_flRecallRange[client]);
            AddVectors(eyePos, endPos, endPos);
            
            g_flRecallTargetPos[client][i][0] = endPos[0];
            g_flRecallTargetPos[client][i][1] = endPos[1];
            g_flRecallTargetPos[client][i][2] = endPos[2];
            g_bRecallReturning[client][i] = false;
            
            TeleportEntity(g_iRecallSwords[client][i], eyePos, spreadAngle, NULL_VECTOR);
            
            CreateTrail(g_iRecallSwords[client][i], g_eTrailEffect[client]);
            
            DataPack pack = new DataPack();
            pack.WriteCell(GetClientUserId(client));
            pack.WriteCell(i);
            CreateTimer(0.01, Timer_RecallSwordMove, pack, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        }
    }
}

public Action Timer_RecallSwordMove(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    int swordIndex = pack.ReadCell();
    
    if(!IsValidClient(client) || !IsValidEntity(g_iRecallSwords[client][swordIndex]))
    {
        delete pack;
        return Plugin_Stop;
    }
    
    float swordPos[3], targetPos[3], direction[3];
    GetEntPropVector(g_iRecallSwords[client][swordIndex], Prop_Data, "m_vecOrigin", swordPos);
    
    if(!g_bRecallReturning[client][swordIndex])
    {
        targetPos[0] = g_flRecallTargetPos[client][swordIndex][0];
        targetPos[1] = g_flRecallTargetPos[client][swordIndex][1];
        targetPos[2] = g_flRecallTargetPos[client][swordIndex][2];
        
        if(GetVectorDistance(swordPos, targetPos) < 50.0)
        {
            g_bRecallReturning[client][swordIndex] = true;
            EmitSoundToAll(g_szRecallReturnSound[client], g_iRecallSwords[client][swordIndex]);
        }
    }
    else
    {
        GetClientAbsOrigin(client, targetPos);
        targetPos[2] += 50.0;
        
        if(GetVectorDistance(swordPos, targetPos) < 50.0)
        {
            RemoveEntity(g_iRecallSwords[client][swordIndex]);
            delete pack;
            return Plugin_Stop;
        }
    }
    
    SubtractVectors(targetPos, swordPos, direction);
    NormalizeVector(direction, direction);
    ScaleVector(direction, g_flRecallSpeed[client] * 0.01);
    
    float newPos[3];
    AddVectors(swordPos, direction, newPos);
    
    float angles[3];
    GetVectorAngles(direction, angles);
    
    TeleportEntity(g_iRecallSwords[client][swordIndex], newPos, angles, NULL_VECTOR);
    
    CheckSwordCollision(client, g_iRecallSwords[client][swordIndex], newPos, g_flRecallDamage[client], g_szRecallReturnSound[client]);
    
    return Plugin_Continue;
}

// ========================
// SWORD TORNADO FUNCTIONALITY
// ========================

void CreateSwordTornado(int client)
{
    float origin[3];
    GetClientAbsOrigin(client, origin);
    
    int particle = CreateEntityByName("info_particle_system");
    if(particle != -1)
    {
        DispatchKeyValue(particle, "effect_name", g_szTornadoParticle[client]);
        DispatchSpawn(particle);
        ActivateEntity(particle);
        TeleportEntity(particle, origin, NULL_VECTOR, NULL_VECTOR);
        AcceptEntityInput(particle, "Start");
        g_iTornadoParticle[client] = EntIndexToEntRef(particle);
    }
    
    for(int i = 0; i < g_iTornadoSwordCount[client]; i++)
    {
        g_iTornadoSwords[client][i] = CreateEntityByName("prop_dynamic_override");
        if(g_iTornadoSwords[client][i] != -1)
        {
            SetEntityModel(g_iTornadoSwords[client][i], g_szSwordModel[client]);
            DispatchSpawn(g_iTornadoSwords[client][i]);
            
            float angles[3];
            angles[1] = GetRandomFloat(0.0, 360.0);
            TeleportEntity(g_iTornadoSwords[client][i], origin, angles, NULL_VECTOR);
        }
    }
    
    EmitSoundToAll(g_szTornadoSound[client], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.8);
    
    DataPack pack = new DataPack();
    pack.WriteCell(GetClientUserId(client));
    pack.WriteFloat(GetGameTime());
    CreateTimer(0.1, Timer_TornadoEffect, pack, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_TornadoEffect(Handle timer, DataPack pack)
{
    pack.Reset();
    int client = GetClientOfUserId(pack.ReadCell());
    float startTime = pack.ReadFloat();
    
    if(!IsValidClient(client) || GetGameTime() - startTime > g_flTornadoDuration[client])
    {
        DestroyTornado(client);
        delete pack;
        return Plugin_Stop;
    }
    
    float origin[3];
    GetClientAbsOrigin(client, origin);
    origin[2] += 50.0;
    
    for(int i = 0; i < g_iTornadoSwordCount[client]; i++)
    {
        if(IsValidEntity(g_iTornadoSwords[client][i]))
        {
            float angle = GetGameTime() * 2.0 + (360.0 / g_iTornadoSwordCount[client] * i);
            float height = Sine(GetGameTime() * 3.0) * g_flTornadoHeight[client];
            
            float pos[3];
            pos[0] = origin[0] + Cosine(angle) * g_flTornadoPullForce[client] * 0.1;
            pos[1] = origin[1] + Sine(angle) * g_flTornadoPullForce[client] * 0.1;
            pos[2] = origin[2] + height;
            
            float swordAngles[3];
            swordAngles[0] = angle;
            swordAngles[1] = angle;
            
            TeleportEntity(g_iTornadoSwords[client][i], pos, swordAngles, NULL_VECTOR);
            
            CheckSwordCollision(client, g_iTornadoSwords[client][i], pos, g_flTornadoDamage[client], "");
        }
    }
    
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client))
        {
            float playerPos[3];
            GetClientAbsOrigin(i, playerPos);
            
            if(GetVectorDistance(origin, playerPos) < g_flTornadoPullForce[client])
            {
                float direction[3];
                SubtractVectors(origin, playerPos, direction);
                NormalizeVector(direction, direction);
                ScaleVector(direction, g_flTornadoPullForce[client] * 0.05);
                
                direction[2] += 0.3;
                
                float currentVel[3];
                GetEntPropVector(i, Prop_Data, "m_vecVelocity", currentVel);
                AddVectors(currentVel, direction, currentVel);
                TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, currentVel);
            }
        }
    }
    
    return Plugin_Continue;
}

void DestroyTornado(int client)
{
    if(g_iTornadoParticle[client] != INVALID_ENT_REFERENCE)
    {
        int particle = EntRefToEntIndex(g_iTornadoParticle[client]);
        if(particle > MaxClients)
            RemoveEntity(particle);
        g_iTornadoParticle[client] = INVALID_ENT_REFERENCE;
    }
    
    for(int i = 0; i < g_iTornadoSwordCount[client]; i++)
    {
        if(IsValidEntity(g_iTornadoSwords[client][i]))
            RemoveEntity(g_iTornadoSwords[client][i]);
    }
}

// ========================
// SHARED FUNCTIONALITY
// ========================

void CheckSwordCollision(int client, int sword, float swordPos[3], float damage, const char[] sound)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client))
        {
            float playerPos[3];
            GetClientAbsOrigin(i, playerPos);
            playerPos[2] += 40.0; 

            if(GetVectorDistance(swordPos, playerPos) <= COLLISION_DISTANCE)
            {
                SDKHooks_TakeDamage(i, client, client, damage, DMG_SLASH|DMG_PREVENT_PHYSICS_FORCE, -1);
                
                if(sound[0] != '\0')
                {
                    EmitSoundToAll(sound, sword, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.8);
                }
                
                if(g_eTrailEffect[client] == TRAIL_BLOODY)
                {
                    float direction[3] = {0.0, 0.0, 0.0};
                    direction[2] = 30.0;
                    TE_SetupBloodSprite(playerPos, direction, {200, 0, 0, 255}, 5, 
                        PrecacheModel("sprites/bloodspray.vmt"), 
                        PrecacheModel("sprites/blood.vmt"));
                    TE_SendToAll();
                }
            }
        }
    }
}

void CreateTrail(int entity, TrailType trailType)
{
    if(trailType == TRAIL_NONE)
        return;

    int trail = CreateEntityByName("env_spritetrail");
    if(trail != -1)
    {
        float color[4] = {255.0, 255.0, 255.0, 255.0};
        
        switch(trailType)
        {
            case TRAIL_STANDARD:
            {
                DispatchKeyValue(trail, "spritename", "materials/effects/spark.vmt");
                DispatchKeyValue(trail, "rendercolor", "255 255 255");
                DispatchKeyValue(trail, "renderamt", "200");
                DispatchKeyValue(trail, "lifetime", "0.5");
            }
            case TRAIL_BLOODY:
            {
                DispatchKeyValue(trail, "spritename", "materials/effects/blood_core.vmt");
                DispatchKeyValue(trail, "rendercolor", "200 0 0");
                DispatchKeyValue(trail, "renderamt", "200");
                DispatchKeyValue(trail, "lifetime", "0.8");
                color = {200.0, 0.0, 0.0, 200.0};
            }
        }
        
        DispatchKeyValue(trail, "startwidth", "8.0");
        DispatchKeyValue(trail, "endwidth", "1.0");
        DispatchKeyValue(trail, "texture", "sprites/laserbeam.spr");
        DispatchSpawn(trail);
        
        float pos[3];
        GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos);
        TeleportEntity(trail, pos, NULL_VECTOR, NULL_VECTOR);
        
        SetVariantString("!activator");
        AcceptEntityInput(trail, "SetParent", entity);
    }
}

int FindClosestEnemy(int client, float swordPos[3])
{
    int closest = -1;
    float closestDist = -1.0;

    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(client))
        {
            float pos[3];
            GetClientAbsOrigin(i, pos);
            pos[2] += 40.0; 
            
            float dist = GetVectorDistance(swordPos, pos);
            if(closestDist == -1.0 || dist < closestDist)
            {
                closestDist = dist;
                closest = i;
            }
        }
    }
    
    return closest;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(IsValidClient(client))
    {
        DestroyAuraSwords(client);
        DestroyTornado(client);
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsValidClient(i))
        {
            DestroyAuraSwords(i);
            DestroyTornado(i);
        }
    }
}

stock bool IsValidClient(int client, bool replaycheck = true)
{
    if(client <= 0 || client > MaxClients)
        return false;

    if(!IsClientInGame(client) || !IsClientConnected(client))
        return false;

    if(GetEntProp(client, Prop_Send, "m_bIsCoaching"))
        return false;

    if(replaycheck && (IsClientSourceTV(client) || IsClientReplay(client)))
        return false;

    return true;
}

stock void TF2_CreateGlow(int entity, int color[3])
{
    char strClassname[32];
    GetEntityClassname(entity, strClassname, sizeof(strClassname));
    
    int glow = CreateEntityByName("tf_glow");
    if(glow != -1)
    {
        char colorStr[32];
        Format(colorStr, sizeof(colorStr), "%i %i %i", color[0], color[1], color[2]);
        
        DispatchKeyValue(glow, "target", strClassname);
        DispatchKeyValue(glow, "Mode", "0");
        DispatchKeyValue(glow, "GlowColor", colorStr);
        DispatchSpawn(glow);
        
        SetVariantString("!activator");
        AcceptEntityInput(glow, "SetParent", entity);
        
        AcceptEntityInput(glow, "Enable");
    }
}