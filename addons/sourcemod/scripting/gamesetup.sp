#include <sourcemod>
#include <sdktools>
#include <cstrike>
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

#define SHOW_MENU_TIME		30
#define VOTE_OVERTIME_TIME	15

#define PLUGIN_PREFIX "[{green}Game Setup{default}]"

public Plugin myinfo = {
	name = "Game Setup",
	description = "Simple game management developed for Final Respawn.",
	author = "Clarkey",
	version = "1.0",
	url = "http://finalrespawn.com"
};

/***********VARIABLES***********/

Handle g_ReadyHud = null;
bool g_Knife;
bool g_MatchCanClinch = true;
bool g_Paused[3];
bool g_Ready[MAXPLAYERS + 1];
bool g_Recording;
char g_ClanTag[MAXPLAYERS + 1][16];
char g_Commands[16][16];
char g_Maps[64][PLATFORM_MAX_PATH];
int g_KnifeWinners;
int g_Leader;
int g_Mode;
int g_TotalCommands;
int g_MaxRounds;

/*************START*************/

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
	AddChatCommand(".stay", Command_Stay);
	AddChatCommand(".swap", Command_Swap);
	AddChatCommand(".switch", Command_Swap);
	AddChatCommand(".endgame", Command_EndGame);
	AddChatCommand(".gg", Command_EndGame);
	AddChatCommand(".help", Command_Help);
	AddChatCommand(".commands", Command_Help);
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("cs_win_panel_match", Event_EndGame);
	
	//Clan tag events
	HookEvent("player_team", Event_ClanTag, EventHookMode_Post);
	HookEvent("player_spawn", Event_ClanTag, EventHookMode_Post);
	
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

/***********COMMANDS***********/

public Action Command_Menu(int client, int args)
{
	if (IsLeader(client))
	{
		Menu menu = new Menu(Menu_Handler);
		menu.SetTitle("Game Setup");
		menu.AddItem("start", "Start Game");
		menu.AddItem("practice", "Practice Mode");
		menu.AddItem("map", "Change Map");
		menu.Display(client, SHOW_MENU_TIME);
	}
	else
	{
		PrintLeaderMessage(client);
	}
}

public Action Command_Ready(int client, int args)
{
	if (g_Mode == MODE_WARMUP)
	{
		if (g_Ready[client])
		{
			CPrintToChat(client, "%t", "Already Ready");
		}
		else
		{
			g_Ready[client] = true;
			HandleClanTag(client);
			
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
				if (g_ReadyHud != null)
				{
					KillTimer(g_ReadyHud);
					g_ReadyHud = null;
				}
			}
		}
	}
}

public Action Command_Gaben(int client, int args)
{
	CPrintToChat(client, "%t", "Gaben");
	FakeClientCommand(client, "sm_ready");
}

public Action Command_UnReady(int client, int args)
{
	if (g_Mode == MODE_WARMUP)
	{
		if (g_Ready[client] == true)
		{
			g_Ready[client] = false;
			HandleClanTag(client);
		}
		else
		{
			CPrintToChat(client, "%t", "Already Unready");
		}
	}
}

public Action Command_Pause(int client, int args)
{
	if (g_Mode == MODE_LIVE)
	{
		if (!g_Paused[0])
		{
			CPrintToChatAll("%t", "Pause Called");
			ServerCommand("mp_pause_match");
			g_Paused[0] = true;
			g_Paused[1] = true;
			g_Paused[2] = true;
		}
	}
}

public Action Command_UnPause(int client, int args)
{
	if (g_Mode == MODE_LIVE)
	{
		if (g_Paused[0])
		{
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
				CPrintToChatAll("%t", "Pause Cancelled");
				ServerCommand("mp_unpause_match");
				g_Paused[0] = false;
			}
			else
			{
				CPrintToChatAll("%t", "Both Teams");
			}
		}
	}
}

public Action Command_Stay(int client, int args)
{
	if (g_Mode == MODE_KNIFEPOST)
	{
		if (GetClientTeam(client) == g_KnifeWinners)
		{
			CPrintToChatAll("%t", "Knife Keep");
			ChangeMode(MODE_LIVE);
		}
		else
		{
			CPrintToChat(client, "%t", "Didnt Win");
		}
	}
}

public Action Command_Swap(int client, int args)
{
	if (g_Mode == MODE_KNIFEPOST)
	{
		if (GetClientTeam(client) == g_KnifeWinners)
		{
			CPrintToChatAll("%t", "Swap Sides");
			ServerCommand("mp_swapteams");
			ChangeMode(MODE_LIVE);
		}
		else
		{
			CPrintToChat(client, "%t", "Didnt Win");
		}
	}
}

public Action Command_Switch(int client, int args)
{
	FakeClientCommand(client, "sm_swap");
}

public Action Command_EndGame(int client, int args)
{
	if (IsLeader(client))
	{
		Menu endmenu = new Menu(Menu_Handler_EndGame);
		endmenu.SetTitle("Are you sure you want to end the game?");
		endmenu.AddItem("yes", "Yes");
		endmenu.AddItem("no", "No");
		endmenu.Display(client, SHOW_MENU_TIME);
	}
	else
	{
		PrintLeaderMessage(client);
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
			Format(Buffer, sizeof(Buffer), "%s", PLUGIN_PREFIX);
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

/************CUSTOM************/

void AddChatCommand(const char command[16], ConCmd callback)
{
	g_Commands[g_TotalCommands] = command;
	g_TotalCommands++;
	
	char Buffer[32];
	Buffer = RemoveFirstChar(command);
	Format(Buffer, 32, "sm_%s", Buffer);
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
	
	CPrintToChatAll("%t", "Overtime");
}

void PracticeModeMenu(int client)
{
	Menu PracticeMenu = new Menu(Menu_Handler_Practice);
	PracticeMenu.SetTitle("Practices modes");
	PracticeMenu.AddItem("default", "Default");
	PracticeMenu.AddItem("gun-round", "Gun Round");
	PracticeMenu.AddItem("pistol-round", "Pistol Round");
	PracticeMenu.Display(client, SHOW_MENU_TIME);
}

void PracticeMode()
{
	g_Leader = 0;
	ChangeMode(MODE_PRACTICE);
	CPrintToChatAll("%t", "Practice Mode");
}

void GunRoundMode()
{
	g_Leader = 0;
	ChangeMode(MODE_PRACTICEGUN);
	CPrintToChatAll("%t", "Practice Gun Mode");
}

void PistolRoundMode()
{
	g_Leader = 0;
	ChangeMode(MODE_PRACTICEPISTOL);
	CPrintToChatAll("%t", "Practice Pistol Mode");
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
			g_ReadyHud = CreateTimer(1.0, Timer_ReadyHud, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}
		case MODE_PRACTICE:ServerCommand("exec sourcemod/gamesetup/practice");
		case MODE_PRACTICEGUN:ServerCommand("exec sourcemod/gamesetup/practice-gun-round");
		case MODE_PRACTICEPISTOL:ServerCommand("exec sourcemod/gamesetup/practice-pistol-round");
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
	if (IsClientInGame(client))
	{
		if (!IsFakeClient(client))
		{
			//Check to see if their clan tag isn't stored yet
			if (StrEqual(g_ClanTag[client], ""))
			{
				char Buffer[sizeof(g_ClanTag[])];
				int ClanTag = CS_GetClientClanTag(client, Buffer, sizeof(g_ClanTag[]));
				if (ClanTag)
					g_ClanTag[client] = Buffer;
				else
					g_ClanTag[client] = "0";
			}
			
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
			else
			{
				if (!StrEqual(g_ClanTag[client], "0"))
				{
					CS_SetClientClanTag(client, g_ClanTag[client]);
				}
				else
				{
					CS_SetClientClanTag(client, "");
				}
			}
		}
	}
}

bool IsLeader(int client)
{
	if (g_Leader == client || !g_Leader)return true;
	else return false;
}

void PrintLeaderMessage(int client)
{
	char Name[64];
	GetClientName(g_Leader, Name, sizeof(Name));
	CPrintToChat(client, "%t", "Leader Only", Name);
}

void PrintGameInfo()
{
	//There will always be a leader when this is printed
	char Name[64];
	GetClientName(g_Leader, Name, sizeof(Name));
	CPrintToChatAll("%t", "Menu Border");
	CPrintToChatAll("%t", "Menu Admin", Name);
	CPrintToChatAll("%t", "Menu Border");
}

void StartRecording()
{
	char DemoName[64], MapName[64];
	FormatTime(DemoName, sizeof(DemoName), "%y_%m_%d_%H_%M_%S");
	GetCurrentMap(MapName, sizeof(MapName));
	Format(DemoName, sizeof(DemoName), "%s_%s", MapName, DemoName);
	ServerCommand("tv_record %s", DemoName);
	CPrintToChatAll("%t", "Start Recording", DemoName);
	g_Recording = true;
}

void StopRecording()
{
	if (g_Recording)
	{
		ServerCommand("tv_stoprecord");
		CPrintToChatAll("%t", "Stop Recording");
		g_Recording = false;
	}
}

/***********HANDLERS***********/

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
	}
	else if (action == MenuAction_Cancel)
	{
		delete menu;
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
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
	else if (action == MenuAction_Cancel)
	{
		delete menu;
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
		g_Leader = client;
		PrintGameInfo();
		
		//Change the mode
		ChangeMode(MODE_WARMUP);
	}
	else if (action == MenuAction_Cancel)
	{
		delete menu;
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
		CPrintToChatAll("%t", "Overtime Equal");
	}
	/* If there was a clear winner */
	else if (StrEqual(Buffer, "yes"))
	{
		ServerCommand("mp_overtime_enable 1");
		CPrintToChatAll("%t", "Overtime Enough");
	}
	else
	{
		ServerCommand("mp_overtime_enable 0");
		CPrintToChatAll("%t", "Overtime Not Enough");
	}
}

public int Menu_Handler_Practice(Menu menu, MenuAction action, int client, int item)
{
	if (action == MenuAction_Select)
	{
		char Buffer[32];
		GetMenuItem(menu, item, Buffer, 32);
		
		if (StrEqual("default", Buffer))
		{
			PracticeMode();
		}
		else if (StrEqual("gun-round", Buffer))
		{
			GunRoundMode();
		}
		else if (StrEqual("pistol-round", Buffer))
		{
			PistolRoundMode();
		}
	}
	else if (action == MenuAction_Cancel)
	{
		delete menu;
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
		CPrintToChatAll("%t", "Changing Map", Buffer);
		CreateTimer(5.0, Timer_ChangeMap, item, TIMER_FLAG_NO_MAPCHANGE);
		StopRecording();
	}
	else if (action == MenuAction_Cancel)
	{
		delete menu;
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
			CPrintToChatAll("%t", "Game Ended", ClientName);
			ChangeMode(MODE_WARMUP);
			StopRecording();
		}
		else
		{
			delete menu;
		}
	}
	else if (action == MenuAction_Cancel)
	{
		delete menu;
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

/************EVENTS************/

public Action OnClientSayCommand(int client, const char[] command, const char[] args)
{
	for (int i; i < g_TotalCommands; i++)
	{
		if (StrEqual(args, g_Commands[i], false))
		{
			char Buffer[32];
			Buffer = RemoveFirstChar(args);
			FakeClientCommand(client, "sm_%s", Buffer);
		}
	}
	
	return Plugin_Continue;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (g_Mode == MODE_KNIFE)
	{
		CPrintToChatAll("%s {darkred}KNIFE!", PLUGIN_PREFIX);
		CPrintToChatAll("%s {orange}KNIFE!", PLUGIN_PREFIX);
		CPrintToChatAll("%s {yellow}KNIFE!", PLUGIN_PREFIX);
		CPrintToChatAll("%s {green}KNIFE!", PLUGIN_PREFIX);
		CPrintToChatAll("%s {lightblue}KNIFE!", PLUGIN_PREFIX);
		CPrintToChatAll("%s {darkblue}KNIFE!", PLUGIN_PREFIX);
		CPrintToChatAll("%s {purple}KNIFE!", PLUGIN_PREFIX);
	}
	else if (g_Mode == MODE_KNIFEPOST)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if (GetClientTeam(i) == g_KnifeWinners)
				{
					CPrintToChat(i, "%t", "Won The Knife");
				}
				else
				{
					CPrintToChat(i, "%t", "Waiting On Team");
				}
			}
		}
	}
	else if (g_Mode == MODE_LIVE && GetTeamScore(CS_TEAM_CT) == 0 && GetTeamScore(CS_TEAM_T) == 0)
	{
		CPrintToChatAll("%s {darkred}LIVE!", PLUGIN_PREFIX);
		CPrintToChatAll("%s {orange}LIVE!", PLUGIN_PREFIX);
		CPrintToChatAll("%s {yellow}LIVE!", PLUGIN_PREFIX);
		CPrintToChatAll("%s {green}LIVE!", PLUGIN_PREFIX);
		CPrintToChatAll("%s {lightblue}LIVE!", PLUGIN_PREFIX);
		CPrintToChatAll("%s {darkblue}LIVE!", PLUGIN_PREFIX);
		CPrintToChatAll("%s {purple}LIVE!", PLUGIN_PREFIX);
	}
	else if ((-1 <= (GetTeamScore(CS_TEAM_CT) - GetTeamScore(CS_TEAM_T))) && ((GetTeamScore(CS_TEAM_CT) - GetTeamScore(CS_TEAM_T)) <= 1))
	{
		int HalfMaxRounds = g_MaxRounds / 2;
		
		if (((GetTeamScore(CS_TEAM_CT) == HalfMaxRounds)
		|| (GetTeamScore(CS_TEAM_T) == HalfMaxRounds))
		&& (GetTeamScore(CS_TEAM_CT) != GetTeamScore(CS_TEAM_T))
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
				CPrintToChatAll("%t", "Knife Draw");
				g_KnifeWinners = Random;
			}
			else if (GetTeamAliveCount(CS_TEAM_CT) > GetTeamAliveCount(CS_TEAM_T))
			{
				CPrintToChatAll("%t", "Knife CT");
				g_KnifeWinners = CS_TEAM_CT;
			}
			else
			{
				CPrintToChatAll("%t", "Knife T");
				g_KnifeWinners = CS_TEAM_T;
			}
		}
		else
		{
			g_KnifeWinners = GetEventInt(event, "winner");
			ChangeMode(MODE_KNIFEPOST);
		}
	}
	else if (g_Mode == MODE_KNIFEPOST)
	{
		int Random = GetRandomInt(0, 1);
		CPrintToChatAll("%t", "Winners Too Long");
		
		if (Random)
			ServerCommand("mp_swapteams");
			
		ChangeMode(MODE_LIVE);
	}
	else if (g_Mode == MODE_PRACTICEPISTOL)
	{
		ServerCommand("mp_restartgame 1");
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

public void OnClientDisconnect_Post(int client)
{
	g_Ready[client] = false;
	g_ClanTag[client] = "";
	if (g_Leader == client)g_Leader = 0;
}

/************STOCKS************/

stock int ReadyCount()
{
	int Ready;
	
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			if (g_Ready[i] == true)
				Ready++;
				
	return Ready;
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
	char Buffer[32];
	
	for (int i = 1; i <= 32; i++)
		Buffer[i - 1] = command[i];
		
	return Buffer;
}

/************TIMERS************/

public Action Timer_ChangeMap(Handle timer, any data)
{
	ServerCommand("changelevel %s", g_Maps[data]);
}

public Action Timer_ReadyHud(Handle timer, any data)
{
	if (g_Mode == MODE_WARMUP && ReadyCount() < 10)
	{
		PrintHintTextToAll("%t", "Ready Hud", ReadyCount(), GetClientCount() - 1);
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