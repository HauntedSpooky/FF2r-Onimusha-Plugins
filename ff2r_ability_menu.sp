/* 

	"rage_ability_menu"
    {
        "slot"                  "0"                     // Ability slot
        "mana_start"            "100.0"                // Starting mana
        "mana_max"              "100.0"                // Maximum mana
        "mana_regen"            "1.0"                  // Mana regeneration per tick
        "switch"                "3"                    // 3 = R switch ability
        "key"                   "2"                    // 2 = M3 use ability

        "menu_position"         "0"                    // Menu position (0: Center, 1: Top, 2: Bottom)
        "menu_color_r"          "255"                  // Menu text color (Red)
        "menu_color_g"          "0"                    // Menu text color (Green)
        "menu_color_b"          "0"                    // Menu text color (Blue)
        "menu_color_a"          "255"                  // Menu text color (Alpha)

        "ability_name_1"        "Fireball"             // Name of ability 1
        "ability_cost_1"        "30.0"                 // Cost of ability 1
        "ability_cooldown_1"    "10.0"                 // Cooldown of ability 1
        "global cooldown"	"30.0"	               // Like 'cooldown', but applies to all spells
	"low"		        "8"		               // Lowest ability slot to activate. If left blank, "high" is used
	"high"		        "8"		               // Highest ability slot to activate. If left blank, "low" is used

        "ability_name_2"        "Ice Blast"            // Name of ability 2
        "ability_cost_2"        "40.0"                 // Cost of ability 2
        "ability_cooldown_2"    "15.0"                 // Cooldown of ability 2
        "global cooldown"       "30.0"	               // Like 'cooldown', but applies to all spells
	"low"		        "8"		               // Lowest ability slot to activate. If left blank, "high" is used
	"high"		        "8"		               // Highest ability slot to activate. If left blank, "low" is used

        "ability_name_3"        "Lightning Strike"     // Name of ability 3
        "ability_cost_3"        "50.0"                 // Cost of ability 3
        "ability_cooldown_3"    "20.0"                 // Cooldown of ability 3
        "global cooldown"	"30.0"	               // Like 'cooldown', but applies to all spells
	"low"		        "8"		               // Lowest ability slot to activate. If left blank, "high" is used
	"high"		        "8"		               // Highest ability slot to activate. If left blank, "low" is used

        "plugin_name"           "ff2r_ability_menu"
    }

*/


#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cfgmap>
#include <ff2r>
#include <tf2_stocks>
#include <tf2items>
#include <morecolors> 

#define PLUGIN_NAME 		"Freak Fortress 2 Rewrite: Ability Menu"
#define PLUGIN_AUTHOR 		"Onimusha"
#define PLUGIN_DESC 		"Adds a menu for boss abilities"
#define PLUGIN_VERSION 		"1.0.0"

#define MAX_ABILITIES 		3
#define MENU_DURATION 		10

public Plugin myinfo = 
{
	name 		= PLUGIN_NAME,
	author 		= PLUGIN_AUTHOR,
	description	= PLUGIN_DESC,
	version 	= PLUGIN_VERSION,
};

enum struct BossAbilityData
{
	char AbilityName[64];
	float AbilityCost;
	float AbilityCooldown;
	float GlobalCooldown;
	float NextUseTime;
	int AbilitySlotLow;
	int AbilitySlotHigh;
	int MenuColor[4]; 
}

int g_iCurrentAbility[MAXPLAYERS + 1];
BossAbilityData g_Abilities[MAXPLAYERS + 1][MAX_ABILITIES];
float g_fGlobalCooldown[MAXPLAYERS + 1];

public void OnPluginStart()
{
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidClient(client) && FF2R_GetBossData(client) != null)
	{
		
		for (int i = 0; i < MAX_ABILITIES; i++)
		{
			g_Abilities[client][i].NextUseTime = 0.0;
		}
		g_fGlobalCooldown[client] = 0.0;
	}
}

public void FF2R_OnAbility(int client, const char[] ability, AbilityData cfg)
{
	if (!cfg.IsMyPlugin())
		return;

	if (StrEqual(ability, "rage_ability_menu"))
	{
		
		for (int i = 1; i <= MAX_ABILITIES; i++)
		{
			char key[32];
			Format(key, sizeof(key), "ability_name_%d", i);
			cfg.GetString(key, g_Abilities[client][i-1].AbilityName, sizeof(g_Abilities[][].AbilityName));

			Format(key, sizeof(key), "ability_cost_%d", i);
			g_Abilities[client][i-1].AbilityCost = cfg.GetFloat(key);

			Format(key, sizeof(key), "ability_cooldown_%d", i);
			g_Abilities[client][i-1].AbilityCooldown = cfg.GetFloat(key);

			g_Abilities[client][i-1].GlobalCooldown = cfg.GetFloat("global cooldown");
			g_Abilities[client][i-1].NextUseTime = 0.0;

			g_Abilities[client][i-1].AbilitySlotLow = cfg.GetInt("low", 8);
			g_Abilities[client][i-1].AbilitySlotHigh = cfg.GetInt("high", 8);
		}

		
		g_Abilities[client][0].MenuColor[0] = cfg.GetInt("menu_color_r", 255);
		g_Abilities[client][0].MenuColor[1] = cfg.GetInt("menu_color_g", 0);
		g_Abilities[client][0].MenuColor[2] = cfg.GetInt("menu_color_b", 0);
		g_Abilities[client][0].MenuColor[3] = cfg.GetInt("menu_color_a", 255);

		
		OpenAbilityMenu(client);
	}
}

void OpenAbilityMenu(int client)
{
	Menu menu = new Menu(MenuHandler_AbilityMenu);

	
	float mana = GetBossMana(client);
	float rage = FF2R_GetBossData(client).GetFloat("rage", 0.0) * 100.0;

	
	char menuTitle[256];
	Format(menuTitle, sizeof(menuTitle), "\x07FFFFFFEnergy-Meter: \x07FF4500%.0f/50000\n\x07FFFFFFRAGE: \x07FF0000%.0f%%", mana, rage);

	menu.SetTitle(menuTitle);

	for (int i = 0; i < MAX_ABILITIES; i++)
	{
		char item[128];
		float cooldownRemaining = g_Abilities[client][i].NextUseTime - GetGameTime();

		if (cooldownRemaining > 0)
		{
			
			Format(item, sizeof(item), "\x07FF0000[ON COOLDOWN] %s (%.1fs)", 
				g_Abilities[client][i].AbilityName, 
				cooldownRemaining);
		}
		else
		{
			
			Format(item, sizeof(item), "\x0700FF00[READY] %s (COST: \x07FF4500%.1f\x07FFFFFF | Cooldown: \x0742A5F5%.1f\x07FFFFFF)", 
				g_Abilities[client][i].AbilityName, 
				g_Abilities[client][i].AbilityCost, 
				g_Abilities[client][i].AbilityCooldown);
		}

		menu.AddItem("", item);
	}

	
	char footer[128];
	Format(footer, sizeof(footer), "\n\x07FFFFFFRELOAD to SWAP ABILITIES");
	menu.AddItem("", footer, ITEMDRAW_DISABLED);

	menu.ExitButton = false;
	menu.Display(client, MENU_DURATION);
}


public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (IsValidClient(client) && FF2R_GetBossData(client) != null)
	{
		
		if (buttons & IN_RELOAD)
		{
			OpenAbilityMenu(client);
			buttons &= ~IN_RELOAD; 
		}

		
		if (buttons & IN_ATTACK3)
		{
			UseAbility(client);
			buttons &= ~IN_ATTACK3; 
		}
	}

	return Plugin_Continue;
}

void UseAbility(int client)
{
	int abilityIndex = g_iCurrentAbility[client];
	if (abilityIndex < 0 || abilityIndex >= MAX_ABILITIES)
		return;

	float currentTime = GetGameTime();
	if (currentTime < g_Abilities[client][abilityIndex].NextUseTime || currentTime < g_fGlobalCooldown[client])


	float mana = GetBossMana(client); 
	if (mana < g_Abilities[client][abilityIndex].AbilityCost)
	{
		PrintToChat(client, "Test!");
		return;
	}

	
	SetBossMana(client, mana - g_Abilities[client][abilityIndex].AbilityCost); 

	
	g_Abilities[client][abilityIndex].NextUseTime = currentTime + g_Abilities[client][abilityIndex].AbilityCooldown;
	g_fGlobalCooldown[client] = currentTime + g_Abilities[client][abilityIndex].GlobalCooldown;

	
	char abilityName[64];
	strcopy(abilityName, sizeof(abilityName), g_Abilities[client][abilityIndex].AbilityName);
	

}


float GetBossMana(int client)
{
	return FF2R_GetBossData(client).GetFloat("mana", 100.0);
}


void SetBossMana(int client, float mana)
{
	FF2R_GetBossData(client).SetFloat("mana", mana);
}

stock bool IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
