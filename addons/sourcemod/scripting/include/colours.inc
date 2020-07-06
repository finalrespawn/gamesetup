#if defined _colours_included
 #endinput
#endif
#define _colours_included

#define MAX_MESSAGE_LENGTH	256
#define MAX_COLOURS			13

char ColourName[][] = { "{default}", "{darkred}", "{purple}", "{green}", "{olive}", "{lime}", "{lightred}", "{grey}", "{yellow}", "{orange}", "{lightblue}", "{darkblue}", "{pink}" };
char ColourCode[][] = { "\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07", "\x08", "\x09", "\x10", "\x0B", "\x0C", "\x0E" };

stock void CPrintToChat(int client, const char[] message, any ...)
{
	if (0 >= client > MaxClients)
	{
		ThrowError("Invalid client index %i", client);
	}
	
	if (!IsClientInGame(client))
	{
		ThrowError("Client %i is not in game", client);
	}
	
	char Buffer[MAX_MESSAGE_LENGTH];
	VFormat(Buffer, MAX_MESSAGE_LENGTH, message, 3);
	
	CFormat(Buffer, MAX_MESSAGE_LENGTH);
	
	PrintToChat(client, Buffer);
}

stock void CPrintToChatAll(const char[] message, any ...)
{
	char Buffer[MAX_MESSAGE_LENGTH];
	VFormat(Buffer, MAX_MESSAGE_LENGTH, message, 2);
	
	CFormat(Buffer, MAX_MESSAGE_LENGTH);
	
	PrintToChatAll(Buffer);
}

stock void CFormat(char[] message, int maxlength, int foo = 0)
{
	CBracket(message, maxlength);
	
	for (int i; i < MAX_COLOURS; i++)
	{
		if (StrContains(message, ColourName[i]))
		{
			ReplaceString(message, maxlength, ColourName[i], ColourCode[i]);
		}
	}
}

stock void CBracket(char[] message, int maxlength)
{
	if (message[0] == '{')
	{
		Format(message, maxlength, " %s", message);
	}
}

stock void CReplyToCommand(int client, char[] message, any ...)
{
	char Buffer[MAX_MESSAGE_LENGTH];
	VFormat(Buffer, MAX_MESSAGE_LENGTH, message, 3);
	
	if (client == 0)
	{
		CRemoveTags(Buffer, sizeof(Buffer));
		PrintToServer(Buffer);
	}
	else if (GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
	{
		CRemoveTags(Buffer, sizeof(Buffer));
		PrintToConsole(client, Buffer);
	}
	else
	{
		CPrintToChat(client, Buffer);
	}
}

stock void CRemoveTags(char[] message, int maxlength)
{
	for (int i; i < MAX_COLOURS; i++)
	{
		if (StrContains(message, ColourName[i]))
		{
			ReplaceString(message, maxlength, ColourName[i], "");
		}
	}
}