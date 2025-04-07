/*
    "rage_black_hole"                                    // Ability name can use suffixes
    {
        "slot"                  "0"                     // Ability slot
        
        "duration"              "10.0"                  // Duration of the black hole
        "damage"                "25.0"                  // Damage per tick
        "radius"                "500.0"                 // Radius of the black hole
        "force"                 "1000.0"                // Pull force

        "plugin_name"           "ff2r_black_hole"
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

#define PLUGIN_NAME         "Freak Fortress 2 Rewrite: Black Hole"
#define PLUGIN_AUTHOR       "Haunted Bone"
#define PLUGIN_DESC         "Black hole ability for FF2R"

#define MAJOR_REVISION      "1"
#define MINOR_REVISION      "0"
#define STABLE_REVISION     "0"
#define PLUGIN_VERSION      MAJOR_REVISION..."."...MINOR_REVISION..."."...STABLE_REVISION

#define MAXTF2PLAYERS       MAXPLAYERS+1
#define INACTIVE            100000000.0

public Plugin myinfo = 
{
    name        = PLUGIN_NAME,
    author      = PLUGIN_AUTHOR,
    description = PLUGIN_DESC,
    version     = PLUGIN_VERSION,
};

float BH_Duration[MAXTF2PLAYERS];
float BH_Damage[MAXTF2PLAYERS];
float BH_Radius[MAXTF2PLAYERS];
float BH_Force[MAXTF2PLAYERS];
int BH_ParticleRef[MAXTF2PLAYERS] = {INVALID_ENT_REFERENCE, ...};

public void OnPluginStart()
{    
    PrecacheSound("ambient/atmosphere/terrain_rumble1.wav");
    PrecacheModel("materials/sprites/strider_blackball.vmt");
    PrecacheParticleEffect("eye_boss_vortex");
}

public void OnMapEnd()
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(BH_ParticleRef[i] != INVALID_ENT_REFERENCE)
        {
            int entity = EntRefToEntIndex(BH_ParticleRef[i]);
            if(entity > MaxClients && IsValidEntity(entity))
                RemoveEntity(entity);
            BH_ParticleRef[i] = INVALID_ENT_REFERENCE;
        }
    }
}

public void FF2R_OnAbility(int clientIdx, const char[] ability, AbilityData cfg)
{
    if(!cfg.IsMyPlugin()) 
        return;
    
    if(!StrContains(ability, "rage_black_hole", false))
    {
        Ability_BlackHole(clientIdx, ability, cfg);
    }
}

public void FF2R_OnLose(int clientIdx)
{
    if(BH_ParticleRef[clientIdx] != INVALID_ENT_REFERENCE)
    {
        int entity = EntRefToEntIndex(BH_ParticleRef[clientIdx]);
        if(entity > MaxClients && IsValidEntity(entity))
            RemoveEntity(entity);
        BH_ParticleRef[clientIdx] = INVALID_ENT_REFERENCE;
    }
}

public void Ability_BlackHole(int clientIdx, const char[] ability_name, AbilityData ability)
{
    BH_Duration[clientIdx] = ability.GetFloat("duration", 10.0);
    BH_Damage[clientIdx] = ability.GetFloat("damage", 25.0);
    BH_Radius[clientIdx] = ability.GetFloat("radius", 500.0);
    BH_Force[clientIdx] = ability.GetFloat("force", 1000.0);

    float bossPos[3];
    GetClientAbsOrigin(clientIdx, bossPos);
    bossPos[2] += 50.0; 

    CreateBlackHole(bossPos, clientIdx);
}

public void CreateBlackHole(float pos[3], int clientIdx)
{
    EmitSoundToAll("ambient/atmosphere/terrain_rumble1.wav", clientIdx);

    int particle = CreateEntityByName("info_particle_system");
    if(IsValidEntity(particle))
    {
        DispatchKeyValue(particle, "effect_name", "eye_boss_vortex");
        DispatchSpawn(particle);
        ActivateEntity(particle);
        TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
        AcceptEntityInput(particle, "Start");
        
        BH_ParticleRef[clientIdx] = EntIndexToEntRef(particle);
        
        CreateTimer(BH_Duration[clientIdx], Timer_RemoveParticle, BH_ParticleRef[clientIdx]);
    }

    DataPack pack;
    CreateDataTimer(0.1, Timer_BlackHole, pack, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    pack.WriteCell(clientIdx);
    pack.WriteFloat(GetGameTime());
    pack.WriteFloat(BH_Duration[clientIdx]);
}

public Action Timer_RemoveParticle(Handle timer, any ref)
{
    int entity = EntRefToEntIndex(ref);
    if(entity > MaxClients && IsValidEntity(entity))
        RemoveEntity(entity);
        
    return Plugin_Stop;
}

public Action Timer_BlackHole(Handle timer, DataPack pack)
{
    pack.Reset();
    int clientIdx = pack.ReadCell();
    float startTime = pack.ReadFloat();
    float duration = pack.ReadFloat();
    
    if(!IsValidClient(clientIdx) || !IsPlayerAlive(clientIdx) || (GetGameTime() - startTime) >= duration)
    {
        return Plugin_Stop;
    }

    float bossPos[3];
    GetClientAbsOrigin(clientIdx, bossPos);
    bossPos[2] += 50.0; 

    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) != GetClientTeam(clientIdx))
        {
            float playerPos[3];
            GetClientAbsOrigin(i, playerPos);
            float distance = GetVectorDistance(bossPos, playerPos);

            if(distance <= BH_Radius[clientIdx])
            {
                SDKHooks_TakeDamage(i, clientIdx, clientIdx, BH_Damage[clientIdx], DMG_ENERGYBEAM);

                float direction[3];
                SubtractVectors(bossPos, playerPos, direction);
                NormalizeVector(direction, direction);
                ScaleVector(direction, BH_Force[clientIdx] * (1.0 - (distance / BH_Radius[clientIdx]))); 
                
                direction[2] *= 0.5;
                
                TeleportEntity(i, NULL_VECTOR, NULL_VECTOR, direction);

                if(distance <= 50.0)
                {
                    SDKHooks_TakeDamage(i, clientIdx, clientIdx, 9999.0, DMG_ENERGYBEAM);
                }
            }
        }
    }

    int entity = -1;
    while((entity = FindEntityByClassname(entity, "obj_*")) != -1)
    {
        if(IsValidEntity(entity))
        {
            float entityPos[3];
            GetEntPropVector(entity, Prop_Data, "m_vecOrigin", entityPos);
            float distance = GetVectorDistance(bossPos, entityPos);

            if(distance <= BH_Radius[clientIdx])
              {
                SDKHooks_TakeDamage(entity, clientIdx, clientIdx, BH_Damage[clientIdx], DMG_ENERGYBEAM);

                float direction[3];
                SubtractVectors(bossPos, entityPos, direction);
                NormalizeVector(direction, direction);
                ScaleVector(direction, BH_Force[clientIdx] * (1.0 - (distance / BH_Radius[clientIdx])));
                direction[2] *= 0.5;
                
                TeleportEntity(entity, NULL_VECTOR, NULL_VECTOR, direction);

                if(distance <= 50.0)
                {
                    SDKHooks_TakeDamage(entity, clientIdx, clientIdx, 9999.0, DMG_ENERGYBEAM);
                }
            }
        }
    }

    return Plugin_Continue;
}

stock bool IsValidClient(int clientIdx, bool replaycheck = true)
{
    if(clientIdx <= 0 || clientIdx > MaxClients)
        return false;

    if(!IsClientInGame(clientIdx) || !IsClientConnected(clientIdx))
        return false;

    if(GetEntProp(clientIdx, Prop_Send, "m_bIsCoaching"))
        return false;

    if(replaycheck && (IsClientSourceTV(clientIdx) || IsClientReplay(clientIdx)))
        return false;

    return true;
}

stock void PrecacheParticleEffect(const char[] sEffectName)
{
    static int table = INVALID_STRING_TABLE;
    if(table == INVALID_STRING_TABLE)
        table = FindStringTable("ParticleEffectNames");
    
    if(FindStringIndex(table, sEffectName) == INVALID_STRING_INDEX)
    {
        bool save = LockStringTables(false);
        AddToStringTable(table, sEffectName);
        LockStringTables(save);
    }
}
