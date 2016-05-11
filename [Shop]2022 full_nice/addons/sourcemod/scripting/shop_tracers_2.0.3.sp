#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <shop>

#define LIFE	0.2
#define WIDTH	2.0

new Handle:g_hKv;

new bool:g_bEnabled[MAXPLAYERS+1],
	bool:g_bHide;

new g_iSprite;
new g_iColor[MAXPLAYERS+1][4];

public Plugin:myinfo =
{
	name = "[Shop] Color Tracers",
	author = "FrozDark & R1KO (HLModders LLC)",
	version = "2.0.3",
	url  = "www.hlmod.ru"
};

public OnPluginStart()
{
	HookEvent("bullet_impact", Event_BulletImpact);	

	AutoExecConfig(true, "shop_color_tracers", "shop");

	if (Shop_IsStarted()) Shop_Started();
}

public OnPluginEnd()
{
	Shop_UnregisterMe();
}

public OnMapStart() 
{
	if (g_hKv != INVALID_HANDLE) CloseHandle(g_hKv);

	decl String:buffer[PLATFORM_MAX_PATH];

	g_hKv = CreateKeyValues("Tracers");

	Shop_GetCfgFile(buffer, sizeof(buffer), "trasers.txt");

	if (!FileToKeyValues(g_hKv, buffer)) SetFailState("Couldn't parse file %s", buffer);
	KvRewind(g_hKv);

	KvGetString(g_hKv, "material", buffer, sizeof(buffer), "materials/sprites/laser.vmt");
	g_iSprite = PrecacheModel(buffer);
}

public Shop_Started()
{
	if (g_hKv == INVALID_HANDLE) OnMapStart();

	KvRewind(g_hKv);
	decl String:sName[64], String:sDescription[64];
	g_bHide = bool:KvGetNum(g_hKv, "hide_opposite_team");
	KvGetString(g_hKv, "name", sName, sizeof(sName), "Color Tracers");
	KvGetString(g_hKv, "description", sDescription, sizeof(sDescription));

	new CategoryId:category_id = Shop_RegisterCategory("color_tracers", sName, sDescription);

	KvRewind(g_hKv);

	if (KvGotoFirstSubKey(g_hKv))
	{
		do
		{
			if (KvGetSectionName(g_hKv, sName, sizeof(sName)) && Shop_StartItem(category_id, sName))
			{
				KvGetString(g_hKv, "name", sDescription, sizeof(sDescription), sName);
				Shop_SetInfo(sDescription, "", KvGetNum(g_hKv, "price", 1000), KvGetNum(g_hKv, "sellprice", -1), Item_Togglable, KvGetNum(g_hKv, "duration", 604800));
				Shop_SetCustomInfo("level", KvGetNum(g_hKv, "level", 0));
				Shop_SetCallbacks(_, OnTracersUsed);
				Shop_EndItem();
			}
		} while (KvGotoNextKey(g_hKv));
	}
	
	KvRewind(g_hKv);
}

public OnClientPostAdminCheck(iClient) g_bEnabled[iClient] = false;

public ShopAction:OnTracersUsed(iClient, CategoryId:category_id, const String:category[], ItemId:item_id, const String:item[], bool:isOn, bool:elapsed)
{
	if (isOn || elapsed)
	{
		g_bEnabled[iClient] = false;
		return Shop_UseOff;
	}

	KvRewind(g_hKv);	
	if(KvJumpToKey(g_hKv, item, false))
	{
		g_bEnabled[iClient] = true;
		KvGetColor(g_hKv, "color", g_iColor[iClient][0], g_iColor[iClient][1], g_iColor[iClient][2], g_iColor[iClient][3]);
		return Shop_UseOn;
	}
	KvRewind(g_hKv);
	
	return Shop_Raw;
}

public Event_BulletImpact(Handle:hEvent, const String:weaponName[], bool:dontBroadcast)
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));

 	if (iClient && g_bEnabled[iClient])
	{
		decl Float:bulletOrigin[3], Float:newBulletOrigin[3], clients[MaxClients], i, totalClients;
		GetClientEyePosition(iClient, bulletOrigin);

		decl Float:bulletDestination[3];
		bulletDestination[0] = GetEventFloat(hEvent, "x");
		bulletDestination[1] = GetEventFloat(hEvent, "y");
		bulletDestination[2] = GetEventFloat(hEvent, "z");

		new Float:distance = GetVectorDistance( bulletOrigin, bulletDestination );

		new Float:percentage = 0.4 / ( distance / 100 );
 
		newBulletOrigin[0] = bulletOrigin[0] + ((bulletDestination[0] - bulletOrigin[0]) * percentage);
		newBulletOrigin[1] = bulletOrigin[1] + ((bulletDestination[1] - bulletOrigin[1]) * percentage) - 0.08;
		newBulletOrigin[2] = bulletOrigin[2] + ((bulletDestination[2] - bulletOrigin[2]) * percentage);

		TE_SetupBeamPoints(newBulletOrigin, bulletDestination, g_iSprite, 0, 0, 0, LIFE, WIDTH, WIDTH, 1, 0.0, g_iColor[iClient], 0);

		i = 1;
		totalClients = 0;
		
		if(g_bHide) 
		{
			decl iTeam;
			iTeam = GetClientTeam(iClient);
			while(i <= MaxClients)
			{ 
				if(IsClientInGame(i) && IsFakeClient(i) == false && GetClientTeam(i) == iTeam)
				{
					clients[totalClients++] = i;
				}
				++i;
			}
		}
		else while(i <= MaxClients)
		{ 
			if(IsClientInGame(i) && IsFakeClient(i) == false)
			{
				clients[totalClients++] = i;
			}
			++i;
		}

		TE_Send(clients, totalClients);
	}
}