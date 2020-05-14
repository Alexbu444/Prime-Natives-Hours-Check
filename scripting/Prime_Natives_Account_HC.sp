#include <sourcemod>
#include <prime_natives>
#include <ripext>

public Plugin myinfo =
{
	name		= "[Prime Natives] Hours Check",
	author		= "Alexbu444",
	description = "Checks players account game hours",
	version		= "1.0.0.1",
	url			= "https://t.me/alexbu444"
};

HTTPClient httpClient;
ConVar g_ConVar;

char g_szApiKey[34];
int g_iHours;
bool g_bAccess[MAXPLAYERS+1];

public void OnPluginStart()
{
	g_ConVar = CreateConVar("sm_prime_natives_account_hc_minimum_hours", "20", "Minimum account game hours", _, true, 1.0);
	g_iHours = g_ConVar.IntValue;

	g_ConVar = CreateConVar("sm_prime_natives_account_hc_api_key", "", "Steam Web API Key");
	g_ConVar.GetString(g_szApiKey, sizeof(g_szApiKey));

	AutoExecConfig(true, "account_hc", "sourcemod/prime_natives");
	
	httpClient = new HTTPClient("https://api.steampowered.com/IPlayerService/GetOwnedGames/v0001");	
}

public Action PN_OnPlayerStatusChange(int iClient, PRIME_STATUS &iNewStatus, STATUS_CHANGE_REASON iReason)
{
	if(iReason == PLAYER_LOAD && iNewStatus != PRIME)
	{
		iNewStatus = VERIFICATION;
		
		char szApiUrlP[256];
		char szAuthId[20];
		
		GetClientAuthId(iClient, AuthId_SteamID64, szAuthId, sizeof(szAuthId));
		
		FormatEx(szApiUrlP, sizeof(szApiUrlP), "?key=%s&steamid=%s&appids_filter[0]=730&format=json", g_szApiKey, szAuthId);	
		httpClient.Get(szApiUrlP, OnRequestComplete, iClient);
		
		return Plugin_Changed;
	}
	return (iReason == WHITE_LIST_REMOVE && g_bAccess[iClient]) ? Plugin_Stop : Plugin_Continue;
}

public void OnRequestComplete(HTTPResponse response, any value)
{
	if (response.Status != HTTPStatus_OK)
		return;

	if (response.Data == null)
		return;
	
	JSONObject hResponse = view_as<JSONObject>(response.Data);
	JSONObject hResponseRoot = view_as<JSONObject>(hResponse.Get("response"));
	JSONArray hResponseGames = view_as<JSONArray>(hResponseRoot.Get("games"));
	
	if (hResponseGames.Length < 1)
	{
		CloseHandle(hResponseGames);
		CloseHandle(hResponseRoot);
		return;
	}
	
	JSONObject hGame = view_as<JSONObject>(hResponseGames.Get(0));

	int iPlaytime = hGame.GetInt("playtime_forever");
	
	if(g_iHours > (iPlaytime / 60))
	{
		PN_SetPlayerStatus(value, WHITE_LIST, WHITE_LIST_ADD);
		g_bAccess[value] = true;
	
		CloseHandle(hGame);
		CloseHandle(hResponseGames);
		CloseHandle(hResponseRoot);
		return;
	}

	PN_SetPlayerStatus(value, NO_PRIME, VERIFICATION_END);
	
	CloseHandle(hGame);
	CloseHandle(hResponseGames);
	CloseHandle(hResponseRoot);
}

public void OnClientDisconnect(int iClient)
{
	g_bAccess[iClient] = false;
}