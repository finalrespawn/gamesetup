#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <smlib>
#include <colours>

#pragma semicolon 1
#pragma newdecls required

#define MODE_WARMUP			0
#define MODE_PRACTICE		1
#define MODE_PRACTICEGUN	2
#define MODE_PRACTICEPISTOL	3
#define MODE_KNIFE			4
#define MODE_KNIFEPOST		5
#define MODE_LIVE			6

#define DISABLED_ITEM "##disabled##"
#define MAX_COMMAND_LENGTH	16
#define SHOW_MENU_TIME		30
#define VOTE_OVERTIME_TIME	15

public Plugin myinfo = {
	name = "Game Setup",
	description = "Simple game management developed for Final Respawn.",
	author = "Clarkey",
	version = "1.0",
	url = "http://finalrespawn.com"
};

/***************/
/** VARIABLES **/
/***************/

ArrayList g_hLeaders;
ConVar g_hCaptainSystem;
ConVar g_hLeaderSystem;
ConVar g_hOvertimeVote;
ConVar g_hPluginPrefix;
ConVar g_hShowReadyHud;
Handle g_hReadyHud;
bool g_Knife;
bool g_MatchCanClinch = true;
bool g_Paused[3];
bool g_Ready[MAXPLAYERS + 1];
bool g_Recording;
char g_Commands[32][MAX_COMMAND_LENGTH];
char g_Maps[64][PLATFORM_MAX_PATH];
char g_PluginPrefix[64];
int g_CaptainProgress;
int g_Captains[2];
int g_KnifeWinners;
int g_Leader;
int g_Mode;
int g_TotalCommands;
int g_MaxRounds;

/***********/
/** START **/
/***********/

public void OnPluginStart()
{
	AddChatCommand(".menu", Command_Menu);
	AddChatCommand(".ready", Command_Ready);
	AddChatCommand(".r", Command_Ready);
	AddChatCommand(".gaben", Command_Gaben);
	AddChatCommand(".unready", Command_UnReady);
	AddChatCommand(".ur", Command_UnReady);
	AddChatCommand(".pause", Command_Pause);
	AddChatCommand(".paws", Command_Pause);
	AddChatCommand(".unpause", Command_UnPause);
	AddChatCommand(".unpaws", Command_UnPause);
	AddChatCommand(".map", Command_Map);
	AddChatCommand(".stay", Command_Stay);
	AddChatCommand(".swap", Command_Swap);
	AddChatCommand(".switch", Command_Swap);
	AddChatCommand(".endgame", Command_EndGame);
	AddChatCommand(".gg", Command_EndGame);
	AddChatCommand(".help", Command_Help);
	AddChatCommand(".commands", Command_Help);
	
	g_hCaptainSystem = CreateConVar("sm_gamesetup_captainsystem", "1", "Enable/disable the captain system.", _, true, 0.0, true, 1.0);
	g_hLeaderSystem = CreateConVar("sm_gamesetup_leadersystem", "1", "Enable/disable the leaders.cfg file.", _, true, 0.0, true, 1.0);
	g_hOvertimeVote = CreateConVar("sm_gamesetup_overtimevote", "1", "Enable/disable the overtime vote in competitive play.", _, true, 0.0, true, 1.0);
	g_hPluginPrefix = CreateConVar("sm_gamesetup_pluginprefix", "[{green}Game Setup{default}] ", "Change the plugin prefix, see the translations file for colours.");
	g_hShowReadyHud = CreateConVar("sm_gamesetup_showreadyhud", "1", "Enable/disable the ready hud showing for everyone.", _, true, 0.0, true, 1.0);
	
	AutoExecConfig();
	
	GetLeaders();
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("cs_win_panel_match", Event_EndGame);
	
	//Clan tag events
	HookEvent("player_team", Event_ClanTag);
	HookEvent("player_spawn", Event_ClanTag);
	
	LoadTranslations("gamesetup.phrases");
}

public void OnMapEnd()
{
	g_Mode = MODE_WARMUP;
	g_Recording = false;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			FakeClientCommand(i, "sm_unready");
		}
	}
}

public void OnConfigsExecuted()
{
	g_hPluginPrefix.GetString(g_PluginPrefix, sizeof(g_PluginPrefix));
}

public void OnClientDisconnect_Post(int client)
{
	g_Ready[client] = false;
	
	if (client == g_Leader)
		SetLeader(0);
		
	if (client == g_Captains[0])
		g_Captains[0] = 0;
		
	if (client == g_Captains[1])
		g_Captains[1] = 0;
}

/**************/
/** COMMANDS **/
/**************/

public Action Command_Menu(int client, int args)
{
	SetLeader(client);
	
	if (IsLeader(client))
	{
		Menu menu = new Menu(Menu_Handler);
		menu.SetTitle("Game Setup");
		menu.AddItem("start", "Start Game");
		menu.AddItem("practice", "Practice Mode");
		menu.AddItem("map", "Change Map");
		
		if (g_hCaptainSystem.BoolValue)
		{
			menu.AddItem("captains", "Pick Captains");
			
			char Captain[64];
			Format(Captain, sizeof(Captain), "Captain #1: %s", GetCaptainName(0));
			menu.AddItem(DISABLED_ITEM, Captain, ITEMDRAW_DISABLED);
			Format(Captain, sizeof(Captain), "Captain #2: %s", GetCaptainName(1));
			menu.AddItem(DISABLED_ITEM, Captain, ITEMDRAW_DISABLED);
		}
		
		menu.Display(client, SHOW_MENU_TIME);
	}
}

public Action Command_Ready(int client, int args)
{
	if (g_Mode == MODE_WARMUP)
	{
		if (!g_hCaptainSystem.BoolValue)
		{
			if (g_Ready[client])
			{
				CPrintToChat(client, "%s%t", g_PluginPrefix, "Already Ready");
			}
			else
			{
				g_Ready[client] = true;
				HandleClanTag(client);
			}
		}
		else
		{
			if (!IsCaptain(client))
			{
				CPrintToChat(client, "%s%t", g_PluginPrefix, "Not Captain");
				return Plugin_Handled;
			}
			
			int Team = GetClientTeam(client);
			
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i))
					continue;
					
				if (IsFakeClient(i))
					continue;
					
				if (GetClientTeam(i) == Team)
				{
					g_Ready[i] = true;
					HandleClanTag(i);
				}
			}
		}
		
		//If we have the required players start the game
		if (ReadyCount() == 10)
		{
			if (g_Knife)
			{
				ChangeMode(MODE_KNIFE);
			}
			else
			{
				ChangeMode(MODE_LIVE);
			}
			
			//Stop the timer that shows the hud
			if (g_hReadyHud != null)
			{
				KillTimer(g_hReadyHud);
				g_hReadyHud = null;
			}
		}
	}
	
	return Plugin_Handled;
}

public Action Command_Gaben(int client, int args)
{
	if (g_hCaptainSystem.BoolValue && !IsCaptain(client))
	{
		CPrintToChat(client, "%s%t", g_PluginPrefix, "Not Captain");
		return Plugin_Handled;
	}
	
	CPrintToChat(client, "%s%t", g_PluginPrefix, "Gaben");
	FakeClientCommand(client, "sm_ready");
	
	return Plugin_Handled;
}

public Action Command_UnReady(int client, int args)
{
	if (g_Mode == MODE_WARMUP)
	{
		if (!g_hCaptainSystem.BoolValue)
		{
			if (g_Ready[client] == true)
			{
				g_Ready[client] = false;
				HandleClanTag(client);
			}
			else
			{
				CPrintToChat(client, "%s%t", g_PluginPrefix, "Already Unready");
			}
		}
		else
		{
			if (!IsCaptain(client))
			{
				CPrintToChat(client, "%s%t", g_PluginPrefix, "Not Captain");
				return Plugin_Handled;
			}
			
			int Team = GetClientTeam(client);
			
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i))
					continue;
					
				if (IsFakeClient(i))
					continue;
					
				if (GetClientTeam(i) == Team)
				{
					g_Ready[i] = false;
					HandleClanTag(i);
				}
			}
		}
	}
	
	return Plugin_Handled;
}

public Action Command_Pause(int client, int args)
{
	if (g_Mode == MODE_LIVE)
	{
		if (!g_Paused[0])
		{
			if (g_hCaptainSystem.BoolValue && !IsCaptain(client))
			{
				CPrintToChat(client, "%s%t", g_PluginPrefix, "Not Captain");
				return Plugin_Handled;
			}
			
			CPrintToChatAll("%s%t", g_PluginPrefix, "Pause Called");
			ServerCommand("mp_pause_match");
			g_Paused[0] = true;
			g_Paused[1] = true;
			g_Paused[2] = true;
		}
	}
	
	return Plugin_Handled;
}

public Action Command_UnPause(int client, int args)
{
	if (g_Mode == MODE_LIVE)
	{
		if (g_Paused[0])
		{
			if (g_hCaptainSystem.BoolValue && !IsCaptain(client))
			{
				CPrintToChat(client, "%s%t", g_PluginPrefix, "Not Captain");
				return Plugin_Handled;
			}
			
			int Team = GetClientTeam(client);
			
			if (Team == CS_TEAM_CT && g_Paused[1])
			{
				g_Paused[1] = false;
			}
			else if (Team == CS_TEAM_T && g_Paused[2])
			{
				g_Paused[2] = false;
			}
			
			if (!(g_Paused[1] || g_Paused[2]))
			{
				CPrintToChatAll("%s%t", g_PluginPrefix, "Pause Cancelled");
				ServerCommand("mp_unpause_match");
				g_Paused[0] = false;
			}
			else
			{
				CPrintToChatAll("%s%t", g_PluginPrefix, "Both Teams");
			}
		}
	}
	
	return Plugin_Handled;
}

public Action Command_Map(int client, int args)
{
	if (g_Mode == MODE_KNIFEPOST)
	{
		if (g_hCaptainSystem.BoolValue && !IsCaptain(client))
		{
			CPrintToChat(client, "%s%t", g_PluginPrefix, "Not Captain");
			return Plugin_Handled;
		}
		
		if (GetClientTeam(client) == g_KnifeWinners)
		{
			ChangeMap(client);
		}
		else
		{
			CPrintToChat(client, "%s%t", g_PluginPrefix, "Didnt Win");
		}
	}
	
	return Plugin_Handled;
}

public Action Command_Stay(int client, int args)
{
	if (g_Mode == MODE_KNIFEPOST)
	{
		if (g_hCaptainSystem.BoolValue && !IsCaptain(client))
		{
			CPrintToChat(client, "%s%t", g_PluginPrefix, "Not Captain");
			return Plugin_Handled;
		}
		
		if (GetClientTeam(client) == g_KnifeWinners)
		{
			CPrintToChatAll("%s%t", g_PluginPrefix, "Knife Keep");
			ChangeMode(MODE_LIVE);
		}
		else
		{
			CPrintToChat(client, "%s%t", g_PluginPrefix, "Didnt Win");
		}
	}
	
	return Plugin_Handled;
}

public Action Command_Swap(int client, int args)
{
	if (g_Mode == MODE_KNIFEPOST)
	{
		if (g_hCaptainSystem.BoolValue && !IsCaptain(client))
		{
			CPrintToChat(client, "%s%t", g_PluginPrefix, "Not Captain");
			return Plugin_Handled;
		}
		
		if (GetClientTeam(client) == g_KnifeWinners)
		{
			CPrintToChatAll("%s%t", g_PluginPrefix, "Swap Sides");
			ServerCommand("mp_swapteams");
			ChangeMode(MODE_LIVE);
		}
		else
		{
			CPrintToChat(client, "%s%t", g_PluginPrefix, "Didnt Win");
		}
	}
	
	return Plugin_Handled;
}

public Action Command_EndGame(int client, int args)
{
	SetLeader(client);
	
	if (IsLeader(client))
	{
		Menu endmenu = new Menu(Menu_Handler_EndGame);
		endmenu.SetTitle("Are you sure you want to end the game?");
		endmenu.AddItem("yes", "Yes");
		endmenu.AddItem("no", "No");
		endmenu.Display(client, SHOW_MENU_TIME);
	}
}

public Action Command_Help(int client, int args)
{
	char Buffer[117], Item[32]; //The buffer is 117 because 116 (CS:GO MAX CHARS) + 1 ('\0')
	
	for (int i; i < g_TotalCommands; i++)
	{
		//Do we need to add a prefix?
		if (StrEqual("", Buffer))
		{
			Format(Buffer, sizeof(Buffer), "%s", RemoveEndSpaces(g_PluginPrefix));
			if (i != 0)
			{
				Format(Buffer, sizeof(Buffer), "%s %s", Buffer, Item);
			}
		}
		
		Format(Item, sizeof(Item), "%s", g_Commands[i]);
		
		//If we are not on the last item
		if (i != (g_TotalCommands - 1))
		{
			Format(Item, sizeof(Item), "%s,", Item);
		}
		
		//Will it fit in the string
		if (strlen(Buffer) + 1 + strlen(Item) < sizeof(Buffer))
		{
			Format(Buffer, sizeof(Buffer), "%s %s", Buffer, Item);
		}
		else
		{
			CPrintToChat(client, Buffer);
			Buffer = "";
		}
	}
	
	if (!StrEqual("", Buffer))
	{
		CPrintToChat(client, Buffer);
	}
	
	return Plugin_Handled;
}

/************/
/** CUSTOM **/
/************/

void AddChatCommand(const char command[MAX_COMMAND_LENGTH], ConCmd callback)
{
	g_Commands[g_TotalCommands] = command;
	g_TotalCommands++;
	
	char Buffer[32];
	Format(Buffer, sizeof(Buffer), "sm_%s", RemoveFirstChar(command));
	RegConsoleCmd(Buffer, callback);
}

void KnifeMenu(int client)
{
	Menu KnifeRoundMenu = new Menu(Menu_Handler_Knife);
	KnifeRoundMenu.SetTitle("Would you like to have a knife round?");
	KnifeRoundMenu.AddItem("yes", "Yes");
	KnifeRoundMenu.AddItem("no", "No");
	KnifeRoundMenu.Display(client, SHOW_MENU_TIME);
}

void MatchCanClinch(int client)
{
	Menu MatchCanClinchMenu = new Menu(Menu_Handler_MatchCanClinch);
	MatchCanClinchMenu.SetTitle("How many rounds do you want to play?");
	MatchCanClinchMenu.AddItem("yes", "Best of 30 rounds");
	MatchCanClinchMenu.AddItem("no", "30 rounds total");
	MatchCanClinchMenu.Display(client, SHOW_MENU_TIME);
}

void OvertimeVote()
{
	Menu OvertimeVoteMenu = new Menu(Menu_Handler_Overtime);
	OvertimeVoteMenu.VoteResultCallback = Vote_Handler_Overtime;
	OvertimeVoteMenu.SetTitle("Overtime?");
	OvertimeVoteMenu.AddItem("yes", "Yes");
	OvertimeVoteMenu.AddItem("no", "No");
	OvertimeVoteMenu.ExitButton = false;
	OvertimeVoteMenu.DisplayVoteToAll(VOTE_OVERTIME_TIME);
	
	CPrintToChatAll("%s%t", g_PluginPrefix, "Overtime");
}

void PracticeModeMenu(int client)
{
	Menu PracticeMenu = new Menu(Menu_Handler_Practice);
	PracticeMenu.SetTitle("Practices modes");
	PracticeMenu.AddItem("default", "Default");
	PracticeMenu.AddItem("gunround", "Gun Round");
	PracticeMenu.AddItem("pistolround", "Pistol Round");
	PracticeMenu.Display(client, SHOW_MENU_TIME);
}

void PracticeMode()
{
	SetLeader(0);
	ChangeMode(MODE_PRACTICE);
	CPrintToChatAll("%s%t", g_PluginPrefix, "Practice Mode");
}

void GunRoundMode()
{
	SetLeader(0);
	ChangeMode(MODE_PRACTICEGUN);
	CPrintToChatAll("%s%t", g_PluginPrefix, "Practice Gun Mode");
}

void PistolRoundMode()
{
	SetLeader(0);
	ChangeMode(MODE_PRACTICEPISTOL);
	CPrintToChatAll("%s%t", g_PluginPrefix, "Practice Pistol Mode");
}

void ChangeMap(int client)
{
	Menu mapmenu = new Menu(Menu_Handler_Map);
	mapmenu.SetTitle("Maps");
	Handle hFile = OpenFile("mapcycle.txt", "r");
	
	if (hFile == null)
	{
		SetFailState("[Game Setup] Mapcycle.txt not found.");
	}
	
	char Buffer[PLATFORM_MAX_PATH];
	int Counter;
	
	while (ReadFileLine(hFile, Buffer, sizeof(Buffer)))
	{
		mapmenu.AddItem(Buffer, Buffer);
		g_Maps[Counter] = Buffer;
		Counter++;
	}
	
	mapmenu.Display(client, SHOW_MENU_TIME);
}

void PickCaptainsMenu(int client)
{
	Menu CaptainsMenu = new Menu(Menu_Handler_Captains);
	CaptainsMenu.SetTitle("Captain #%i", g_CaptainProgress + 1);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
			
		if (IsFakeClient(i))
			continue;
			
		char Name[64];
		GetClientName(i, Name, sizeof(Name));
		
		char Client[4];
		IntToString(i, Client, sizeof(Client));
		
		if (!((g_CaptainProgress == 1)
		&& (i == g_Captains[0])))
		{
			CaptainsMenu.AddItem(Client, Name);
		}
	}
	
	CaptainsMenu.Display(client, SHOW_MENU_TIME);
}

void ChangeMode(int mode)
{
	g_Mode = mode;
	
	//Let's exec our default config before any others, makes things easier...
	ServerCommand("exec gamemode_competitive");
	ServerCommand("exec sourcemod/gamesetup/default");
	
	switch(mode)
	{
		case MODE_WARMUP:
		{
			ServerCommand("exec sourcemod/gamesetup/warmup");
			if (g_hShowReadyHud.BoolValue)
			{
				g_hReadyHud = CreateTimer(1.0, Timer_ReadyHud, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			}
		}
		case MODE_PRACTICE:ServerCommand("exec sourcemod/gamesetup/practice");
		case MODE_PRACTICEGUN:ServerCommand("exec sourcemod/gamesetup/practicegun");
		case MODE_PRACTICEPISTOL:ServerCommand("exec sourcemod/gamesetup/practicepistol");
		case MODE_KNIFE:ServerCommand("exec sourcemod/gamesetup/knife");
		case MODE_LIVE:
		{
			//Let the file execute then check the number of maxrounds for overtime
			ServerCommand("exec sourcemod/gamesetup/live");
			
			//This time is set off 1.0 second after the live mode is executed
			CreateTimer(1.0, Timer_LivePost, _, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
	
	//This time is set off 1.0 second after any mode is executed
	CreateTimer(1.0, Timer_ModePost, _, TIMER_FLAG_NO_MAPCHANGE);
}

void HandleClanTag(int client)
{
	if ((0 < client)
	&& (client <= MaxClients)
	&& IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
			//Now we see what we need to set their clan tag
			if (g_Mode == MODE_WARMUP)
			{
				if (g_Ready[client])
				{
					CS_SetClientClanTag(client, "[Ready]");
				}
				else
				{
					CS_SetClientClanTag(client, "[Not Ready]");
				}
			}
		}
	}
}

void GetLeaders()
{
	g_hLeaders = new ArrayList(32, 0);
	
	char Path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, Path, sizeof(Path), "configs/gamesetup/leaders.cfg");
	
	KeyValues Leaders = new KeyValues("Leaders");
	Leaders.ImportFromFile(Path);
	Leaders.GotoFirstSubKey();
	
	do {
		char SteamId[32];
		Leaders.GetString("steamid", SteamId, sizeof(SteamId));
		ReplaceString(SteamId, sizeof(SteamId), "STEAM_0", "STEAM_1");
		g_hLeaders.PushString(SteamId);
	} while (Leaders.GotoNextKey());
	
	delete Leaders;
}

void SetLeader(int client)
{
	if (client == 0)
	{
		g_Leader = 0;
	}
	else if (g_Leader == 0)
	{
		if (g_hLeaderSystem.BoolValue)
		{
			char SteamId[32];
			GetClientAuthId(client, AuthId_Steam2, SteamId, sizeof(SteamId));
			if (g_hLeaders.FindString(SteamId) != -1)
			{
				g_Leader = client;
			}
			else
			{
				CPrintToChat(client, "%s%t", g_PluginPrefix, "Not Leader");
			}
		}
		else
		{
			g_Leader = client;
		}
	}
	else if (client != g_Leader)
	{
		char Name[64];
		GetClientName(g_Leader, Name, sizeof(Name));
		CPrintToChat(client, "%s%t", g_PluginPrefix, "Leader Only", Name);
	}
}

bool IsLeader(int client)
{
	return (client == g_Leader);
}

bool IsCaptain(int client)
{
	if (IsLeader(client)
	|| (client == g_Captains[0])
	|| (client == g_Captains[1]))
	{
		return true;
	}
	
	return false;
}

char[] GetCaptainName(int captain)
{
	char Name[64];
	
	if ((0 < g_Captains[captain]) && (g_Captains[captain] <= MaxClients))
	{
		if (IsClientInGame(g_Captains[captain]))
		{
			GetClientName(g_Captains[captain], Name, sizeof(Name));
		}
	}
	else
	{
		Name = "None";
	}
	
	return Name;
}

void PrintGameInfo()
{
	//There will always be a leader when this is printed
	char Name[64];
	
	CPrintToChatAll("%t", "Menu Border", RemoveEndSpaces(g_PluginPrefix));
	
	GetClientName(g_Leader, Name, sizeof(Name));
	CPrintToChatAll("%t", "Menu Admin", Name);
	
	if (g_hCaptainSystem.BoolValue)
	{
		CPrintToChatAll("%t", "Menu Captain", 1, GetCaptainName(0));
		CPrintToChatAll("%t", "Menu Captain", 2, GetCaptainName(1));
	}
	
	CPrintToChatAll("%t", "Menu Border", RemoveEndSpaces(g_PluginPrefix));
}

void StartRecording()
{
	char DemoName[64], MapName[64];
	FormatTime(DemoName, sizeof(DemoName), "%y_%m_%d_%H_%M_%S");
	GetCurrentMap(MapName, sizeof(MapName));
	Format(DemoName, sizeof(DemoName), "%s_%s", MapName, DemoName);
	ServerCommand("tv_record %s", DemoName);
	CPrintToChatAll("%s%t", g_PluginPrefix, "Start Recording", DemoName);
	g_Recording = true;
}

void StopRecording()
{
	if (g_Recording)
	{
		ServerCommand("tv_stoprecord");
		CPrintToChatAll("%s%t", g_PluginPrefix, "Stop Recording");
		g_Recording = false;
	}
}

/**************/
/** HANDLERS **/
/**************/

public int Menu_Handler(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char Buffer[32];
		GetMenuItem(menu, item, Buffer, 32);
		
		if (StrEqual("start", Buffer))
		{
			KnifeMenu(client);
		}
		else if (StrEqual("practice", Buffer))
		{
			PracticeModeMenu(client);
		}
		else if (StrEqual("map", Buffer))
		{
			ChangeMap(client);
		}
		else if (StrEqual("captains", Buffer))
		{
			if (GetHumanClientCount() > 1)
			{
				g_CaptainProgress = 0;
				PickCaptainsMenu(client);
			}
			else
			{
				CPrintToChat(client, "%s%t", g_PluginPrefix, "Not Enough Players");
				FakeClientCommand(client, "sm_menu");
			}
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

public int Menu_Handler_Knife(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		//Get the item, and set the knife option
		char Buffer[32];
		GetMenuItem(menu, item, Buffer, sizeof(Buffer));
		if (StrEqual(Buffer, "yes"))
		{
			g_Knife = true;
		}
		else
		{
			g_Knife = false;
		}
		
		//Show them the next menu
		MatchCanClinch(client);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int Menu_Handler_MatchCanClinch(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		//Get the item, and set the matchcanclinch option
		char Buffer[32];
		menu.GetItem(item, Buffer, sizeof(Buffer));
		if (StrEqual(Buffer, "yes"))
		{
			g_MatchCanClinch = true;
		}
		else
		{
			g_MatchCanClinch = false;
		}
		
		//Print game information
		PrintGameInfo();
		
		//Change the mode
		ChangeMode(MODE_WARMUP);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int Menu_Handler_Overtime(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
}

public void Vote_Handler_Overtime(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	char Buffer[32];
	int Winner = 0;
	menu.GetItem(item_info[Winner][VOTEINFO_ITEM_INDEX], Buffer, sizeof(Buffer));
	
	/* See if there were multiple winners */
	if (num_items > 1 && (item_info[0][VOTEINFO_ITEM_VOTES] == item_info[1][VOTEINFO_ITEM_VOTES]))
	{
		Winner = 1;
		ServerCommand("mp_overtime_enable 0");
		CPrintToChatAll("%s%t", g_PluginPrefix, "Overtime Equal");
	}
	/* If there was a clear winner */
	else if (StrEqual(Buffer, "yes"))
	{
		ServerCommand("mp_overtime_enable 1");
		CPrintToChatAll("%s%t", g_PluginPrefix, "Overtime Enough");
	}
	else
	{
		ServerCommand("mp_overtime_enable 0");
		CPrintToChatAll("%s%t", g_PluginPrefix, "Overtime Not Enough");
	}
}

public int Menu_Handler_Practice(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char Buffer[32];
		GetMenuItem(menu, item, Buffer, sizeof(Buffer));
		
		if (StrEqual("default", Buffer))
		{
			PracticeMode();
		}
		else if (StrEqual("gunround", Buffer))
		{
			GunRoundMode();
		}
		else if (StrEqual("pistolround", Buffer))
		{
			PistolRoundMode();
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int Menu_Handler_Map(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char Buffer[PLATFORM_MAX_PATH];
		GetMenuItem(menu, item, Buffer, sizeof(Buffer));
		CPrintToChatAll("%s%t", g_PluginPrefix, "Changing Map", Buffer);
		CreateTimer(5.0, Timer_ChangeMap, item, TIMER_FLAG_NO_MAPCHANGE);
		StopRecording();
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int Menu_Handler_Captains(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char Buffer[PLATFORM_MAX_PATH];
		GetMenuItem(menu, item, Buffer, sizeof(Buffer));
		int Captain = StringToInt(Buffer);
		g_Captains[g_CaptainProgress] = Captain;
		
		if (g_CaptainProgress == 0)
		{
			g_CaptainProgress++;
			PickCaptainsMenu(client);
		}
		else if (g_CaptainProgress == 1)
		{
			FakeClientCommand(client, "sm_menu");
		}
	}
	else if (action == MenuAction_Cancel && (g_CaptainProgress == 1))
	{
		//If 2 captains aren't selected no one is captain
		g_Captains[0] = 0;
		g_Captains[1] = 0;
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int Menu_Handler_EndGame(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char Buffer[32];
		GetMenuItem(menu, item, Buffer, 32);
		
		if (StrEqual(Buffer, "yes"))
		{
			char ClientName[32];
			GetClientName(client, ClientName, 32);
			CPrintToChatAll("%s%t", g_PluginPrefix, "Game Ended", ClientName);
			ChangeMode(MODE_WARMUP);
			StopRecording();
		}
		else
		{
			delete menu;
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

/************/
/** EVENTS **/
/************/

public Action OnClientSayCommand(int client, const char[] command, const char[] args)
{
	for (int i; i < g_TotalCommands; i++)
	{
		if (StrEqual(args, g_Commands[i], false))
		{
			FakeClientCommand(client, "sm_%s", RemoveFirstChar(args));
		}
	}
	
	return Plugin_Continue;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_Mode == MODE_PRACTICEPISTOL)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))
				continue;
				
			if (!IsPlayerAlive(i))
				continue;
				
			Client_RemoveAllWeapons(i, "weapon_c4");
			
			int Team = GetClientTeam(i);
			char Secondary[64];
			
			if (Team == CS_TEAM_CT)
			{
				GetConVarString(FindConVar("mp_ct_default_secondary"), Secondary, sizeof(Secondary));
				GivePlayerItem(i, Secondary);
				GivePlayerItem(i, "weapon_knife");
			}
			else if (Team == CS_TEAM_T)
			{
				GetConVarString(FindConVar("mp_t_default_secondary"), Secondary, sizeof(Secondary));
				GivePlayerItem(i, Secondary);
				GivePlayerItem(i, "weapon_knife_t");
			}
		}
	}
	else if (g_Mode == MODE_KNIFE)
	{
		CPrintToChatAll("%s{darkred}KNIFE!", g_PluginPrefix);
		CPrintToChatAll("%s{orange}KNIFE!", g_PluginPrefix);
		CPrintToChatAll("%s{yellow}KNIFE!", g_PluginPrefix);
		CPrintToChatAll("%s{green}KNIFE!", g_PluginPrefix);
		CPrintToChatAll("%s{lightblue}KNIFE!", g_PluginPrefix);
		CPrintToChatAll("%s{darkblue}KNIFE!", g_PluginPrefix);
		CPrintToChatAll("%s{purple}KNIFE!", g_PluginPrefix);
	}
	else if (g_Mode == MODE_KNIFEPOST)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if (GetClientTeam(i) == g_KnifeWinners)
				{
					if (!g_hCaptainSystem.BoolValue)
					{
						CPrintToChat(i, "%s%t", g_PluginPrefix, "Won The Knife");
					}
					else
					{
						CPrintToChat(i, "%s%t", g_PluginPrefix, "Won The Knife Captain");
					}
				}
				else
				{
					CPrintToChat(i, "%s%t", g_PluginPrefix, "Waiting On Team");
				}
			}
		}
	}
	else if (g_Mode == MODE_LIVE && GetTeamScore(CS_TEAM_CT) == 0 && GetTeamScore(CS_TEAM_T) == 0)
	{
		CPrintToChatAll("%s{darkred}LIVE!", g_PluginPrefix);
		CPrintToChatAll("%s{orange}LIVE!", g_PluginPrefix);
		CPrintToChatAll("%s{yellow}LIVE!", g_PluginPrefix);
		CPrintToChatAll("%s{green}LIVE!", g_PluginPrefix);
		CPrintToChatAll("%s{lightblue}LIVE!", g_PluginPrefix);
		CPrintToChatAll("%s{darkblue}LIVE!", g_PluginPrefix);
		CPrintToChatAll("%s{purple}LIVE!", g_PluginPrefix);
	}
	else if ((-1 <= (GetTeamScore(CS_TEAM_CT) - GetTeamScore(CS_TEAM_T))) && ((GetTeamScore(CS_TEAM_CT) - GetTeamScore(CS_TEAM_T)) <= 1))
	{
		int HalfMaxRounds = g_MaxRounds / 2;
		
		if (((GetTeamScore(CS_TEAM_CT) == HalfMaxRounds)
		|| (GetTeamScore(CS_TEAM_T) == HalfMaxRounds))
		&& (GetTeamScore(CS_TEAM_CT) != GetTeamScore(CS_TEAM_T))
		&& (g_hOvertimeVote.BoolValue)
		&& (g_Mode == MODE_LIVE)
		&& (GetConVarInt(FindConVar("mp_overtime_enable")) != 1))
		{
			OvertimeVote();
		}
	}
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_Mode == MODE_KNIFE)
	{
		if (GetTeamAliveCount(CS_TEAM_CT) && GetTeamAliveCount(CS_TEAM_T))
		{
			if (GetTeamAliveCount(CS_TEAM_CT) == GetTeamAliveCount(CS_TEAM_T))
			{
				int Random = GetRandomInt(CS_TEAM_CT, CS_TEAM_T);
				CPrintToChatAll("%s%t", g_PluginPrefix, "Knife Draw");
				g_KnifeWinners = Random;
			}
			else if (GetTeamAliveCount(CS_TEAM_CT) > GetTeamAliveCount(CS_TEAM_T))
			{
				CPrintToChatAll("%s%t", g_PluginPrefix, "Knife CT");
				g_KnifeWinners = CS_TEAM_CT;
			}
			else
			{
				CPrintToChatAll("%s%t", g_PluginPrefix, "Knife T");
				g_KnifeWinners = CS_TEAM_T;
			}
		}
		else
		{
			g_KnifeWinners = GetEventInt(event, "winner");
		}
		
		ChangeMode(MODE_KNIFEPOST);
	}
	else if (g_Mode == MODE_KNIFEPOST)
	{
		int Random = GetRandomInt(0, 1);
		CPrintToChatAll("%s%t", g_PluginPrefix, "Winners Too Long");
		
		if (Random)
			ServerCommand("mp_swapteams");
			
		ChangeMode(MODE_LIVE);
	}
}

public Action Event_EndGame(Event event, const char[] name, bool dontBroadcast)
{
	// We have done this to avoid lag at the end of games
	CreateTimer(5.0, Timer_StopRecording);
}

public Action Event_ClanTag(Event event, const char[] name, bool dontBroadcast)
{
	int Client = GetEventInt(event, "userid");
	CreateTimer(1.0, Timer_ClanTag, Client, TIMER_FLAG_NO_MAPCHANGE);
}

/************/
/** STOCKS **/
/************/

stock int ReadyCount()
{
	int Ready;
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			if (g_Ready[i] == true)
				Ready++;
				
	return Ready;
}

stock int GetHumanClientCount()
{
	int Count;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
			
		if (IsFakeClient(i))
			continue;
			
		Count++;
	}
	
	return Count;
}

stock int GetTeamAliveCount(int team)
{
	int Count;
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			if (IsPlayerAlive(i) && GetClientTeam(i) == team)
				Count++;
				
	return Count;
}

stock char[] RemoveFirstChar(const char[] command)
{
	char Buffer[MAX_COMMAND_LENGTH];
	strcopy(Buffer, sizeof(Buffer), command);
	
	for (int i = 1; i < sizeof(Buffer); i++)
	{
		Buffer[i - 1] = command[i];
	}
	
	return Buffer;
}

stock char[] RemoveEndSpaces(const char[] string)
{
	char Buffer[32];
	strcopy(Buffer, sizeof(Buffer), string);
	
	int Counter = strlen(Buffer) - 1;
	
	while (Buffer[Counter] == ' ')
	{
		Buffer[Counter] = '\0';
		Counter--;
	}
	
	return Buffer;
}

/************/
/** TIMERS **/
/************/

public Action Timer_ChangeMap(Handle timer, any data)
{
	ServerCommand("changelevel %s", g_Maps[data]);
}

public Action Timer_ReadyHud(Handle timer, any data)
{
	if (g_Mode == MODE_WARMUP && ReadyCount() < 10)
	{
		PrintHintTextToAll("%t", "Ready Hud", ReadyCount(), GetHumanClientCount());
		return Plugin_Continue;
	}
	else
	{
		return Plugin_Stop;
	}
}

public Action Timer_ClanTag(Handle timer, any data)
{
	int Client = GetClientOfUserId(data);
	HandleClanTag(Client);
}

//This time is set off 1.0 second after any mode is executed
public Action Timer_ModePost(Handle timer, any data)
{
	g_MaxRounds = GetConVarInt(FindConVar("mp_maxrounds"));
}

//This time is set off 1.0 second after the live mode is executed
public Action Timer_LivePost(Handle timer, any data)
{
	//Check to see if match can clinch
	if (g_MatchCanClinch)
	{
		ServerCommand("mp_match_can_clinch 1");
	}
	else
	{
		ServerCommand("mp_match_can_clinch 0");
	}
	
	StartRecording();
}

public Action Timer_StopRecording(Handle timer, any data)
{
	StopRecording();
}