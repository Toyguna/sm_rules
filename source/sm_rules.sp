#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION "0.00"

public Plugin myinfo = 
{
	name = "SM Rules",
	author = "Toyguna",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

char ruledir[PLATFORM_MAX_PATH] = "addons/sourcemod/configs/smrules.cfg";

ConVar g_cvMenuTitle;
ConVar g_cvRulesCommand;
ConVar g_cvShowOnConnect;

StringMap rules;
ArrayList ruletitles;

public void OnPluginStart() {
	LoadTranslations("smrules.phrases");
	
	g_cvMenuTitle = CreateConVar("smrules_menutitle", "Rules", "Sets the rules menu's title.");
	g_cvRulesCommand = CreateConVar("smrules_rulecommand", "rules", "Sets the command for rule.");	
	g_cvShowOnConnect = CreateConVar("smrules_show_on_connect", "1", "Show the rules menu to players who connect.", _, true, 0.0, true, 1.0);	

	rules = new StringMap();
	ruletitles = new ArrayList(64);
	UpdateRules();
	
	//	init commands	//
	char command[64];
	g_cvRulesCommand.GetString(command, sizeof(command));
	char command_format[66];
	Format(command_format, sizeof(command_format), "sm_%s", command);
	
	RegConsoleCmd(command_format, Command_Rules, "Rules");
	
	RegAdminCmd("sm_update_rules", Command_UpdateRules, ADMFLAG_GENERIC, "Usage: !update_rules");
}

public void OnMapStart() {
	UpdateRules();
}

public void OnClientPutInServer(int client) {
	if (g_cvShowOnConnect.BoolValue) {
		ShowRules(client);
	}
} 


public void UpdateRules() {
	rules.Clear();
	ruletitles.Clear();
	
	KeyValues kv = new KeyValues("Config");
	kv.ImportFromFile(ruledir);

	BrowseRules(kv);
	
	delete kv;
	
	PrintToServer("[SM Rules] %T", "UpdateRules", LANG_SERVER);
}

public void BrowseRules(KeyValues kv) {
	kv.JumpToKey("Settings");
	
	char buffer[64];
	kv.GetSectionName(buffer, sizeof(buffer));
	
	if (StrEqual("Rules", buffer)) {
		//	- Read Rules -	//
	
		bool complete = false;
		char current_title[64];

		kv.GotoFirstSubKey(false);

		do {
			char item[64];
			kv.GetSectionName(item, sizeof(item))
			
			int dummy;
			
			// check if item consists of only numbers (meaning its a rule, not a title)
			if (StringToIntEx(item, dummy) == strlen(item)) {
				// rule
				
				char rule[512];
				
				kv.GetString(NULL_STRING, rule, sizeof(rule), "not found");
					  
				// add rule to arraylist
				ArrayList list;
				rules.GetValue(current_title, list);
				list.PushString(rule);
					
				rules.SetValue(current_title, list);
				
				// check if any values are after this
				if (!kv.GotoNextKey(false)) {
					// go to the next title
					kv.GoBack();
					kv.GotoNextKey();
				}
				
			} else {
				// title
					
					
				// check if repeating
				if (StrEqual(current_title, item)) {
					complete = true;
					break;
				}
				
				rules.SetValue(item, new ArrayList(512), true);
				ruletitles.PushString(item);
				
				// set current title var
				strcopy(current_title, sizeof(current_title), item);

				// go to the first rule
				kv.GotoFirstSubKey(false)
			}
			
			
		} while (!complete)
	
	
		// return to stop the recursion; reading is complete.
		return;
		
	} 
	else if (StrEqual("Settings", buffer)) {
		//	- Set settings here -	//
	
		kv.GotoFirstSubKey(false);
	
		do {
			char key[64];
			kv.GetSectionName(key, sizeof(key))
			
			char item[64];
			kv.GetString(NULL_STRING, item, sizeof(item));
			
			if (StrEqual("smrules_menutitle", key)) {
				g_cvMenuTitle.SetString(item);
			} else if (StrEqual("smrules_rulecommand", key)) {
				g_cvRulesCommand.SetString(item);
			} else if (StrEqual("smrules_show_on_connect", key)) {
				g_cvShowOnConnect.SetInt(StringToInt(item));
			} else {
				break;
			}
			
		} while (kv.GotoNextKey(false))
		
		kv.GoBack();
		kv.GotoNextKey();
	}

	BrowseRules(kv);
}


public void ShowRules(int client) {
	
	Menu menu = new Menu(Menu_RulesCallback);
	
	char title[64];
	g_cvMenuTitle.GetString(title, sizeof(title));
	
	menu.SetTitle("%s", title);
	
	for (int i = 0; i < ruletitles.Length; i++) {

		
		char key[64];
		ruletitles.GetString(i, key, sizeof(key));
		
		menu.AddItem(key, key);
	}
	
	
	menu.Display(client, 30);
}

public Menu ShowSubPage(char[] id, int client) {
	Menu page = new Menu(Menu_PageCallback);
	SetMenuExitBackButton(page, true);

	ArrayList list;

	bool success = rules.GetValue(id, list);
	
	if (!success) {
		PrintToServer("[SM Rules] %T", "FailFindTitle", LANG_SERVER, id);
	}

	page.SetTitle("%s", id);

	for (int i = 0; i < list.Length; i++) {
		char rule[512];
		
		list.GetString(i, rule, sizeof(rule));
		
		char index[64];
		IntToString(i, index, sizeof(index));
		
		// add item
		
		int style = ITEMDRAW_DEFAULT;
		
		// check for special items
		
		if (StrEqual(rule, "ITEMDRAW_SPACER")) {
			style = ITEMDRAW_SPACER;
		}
		
		page.AddItem(index, rule, style);
	}
	
	
	page.Display(client, 30);
}


//		commands		//

public Action Command_Rules(int client, int args) {
	ShowRules(client);
	
	return Plugin_Handled;
}

public Action Command_UpdateRules(int client, int args) {
	UpdateRules();
	
	return Plugin_Handled;
}

//		menus		//

public int Menu_RulesCallback(Menu menu, MenuAction action, int param1, int param2) {
	
	switch (action) {
		case MenuAction_Select:
		{
			char id[64];
			menu.GetItem(param2, id, sizeof(id));
			
			ShowSubPage(id, param1);
		}
		
		case MenuAction_End:
		{	
			delete menu;
		}
		
	}
	
}

public int Menu_PageCallback(Menu menu, MenuAction action, int param1, int param2) {
	
	switch (action) {
		
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_ExitBack) {
				ShowRules(param1);
			}
			
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
		
	}
	
}