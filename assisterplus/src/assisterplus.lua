local addonName			= "ASSISTERPLUS"
local author			= "XINXS"

_G["ADDONS"] = _G["ADDONS"] or {}
_G["ADDONS"][author] = _G["ADDONS"][author] or {}
_G["ADDONS"][author][addonName] = _G["ADDONS"][author][addonName] or {}
local g = _G["ADDONS"][author][addonName]
local acutil = require('acutil')
local settingsFileLoc = string.format("../addons/%s/settings.json", string.lower(addonName));
g.settings = {saves = {}, locklist = {}, alert = 1};
local loaded = false;

function ASSISTERPLUS_LOAD()
	if loaded == true then return end
	local t, err = acutil.loadJSON(settingsFileLoc);
	if not err then
		g.settings = t;
		if g.settings.alert == nil then
			g.settings.alert = 1;
		end
		loaded = true;
	end
end

function ASSISTERPLUS_SAVEBTN()
	INPUT_STRING_BOX_CB(nil,'Set name:', 'ASSISTERPLUS_SAVESET', '', nil, nil, 10);
end

function ASSISTERPLUS_SAVESET(setname, frame)
	local frame = ui.GetFrame("ancient_card_list");
	local cnt = session.pet.GetAncientCardCount();
	g.settings.saves[setname] = {};
	for i = 0,3 do
		local card = session.pet.GetAncientCardBySlot(i);
		if card ~= nil then
			if not ap_iscardlocked(card:GetGuid()) then
				table.insert(g.settings.locklist, tostring(card:GetGuid()));
			end
			g.settings.saves[setname][i+1] = card:GetGuid();
		end
	end
	acutil.saveJSON(settingsFileLoc, g.settings);
	ASSISTERPLUS_DROPLIST(frame);
end

function ASSISTERPLUS_LOADSET()
	local delay = 0;
	local frame = ui.GetFrame("ancient_card_list");
	local droplist = GET_CHILD(frame, "ADropList", "ui::CDropList");
	local setname = tostring(droplist:GetSelItemKey());
	local tab = frame:GetChild("tab");
    AUTO_CAST(tab);
    if tab ~= nil then
        tab:SelectTab(0);
        ANCIENT_CARD_LIST_TAB_CHANGE(frame)
    end
	for i = 0,3 do
		local card = session.pet.GetAncientCardBySlot(i);
		if card ~= nil then
			ReserveScript(string.format("REQUEST_SWAP_ANCIENT_CARD(frame,\"%s\",nil)", card:GetGuid()), delay);
			delay = delay + 0.4;
		end
	end
	if g.settings.saves[setname] ~= nil then
		for slot, guid in pairs(g.settings.saves[setname]) do
			ReserveScript(string.format("REQUEST_SWAP_ANCIENT_CARD(frame,\"%s\",%d)", guid, slot-1), delay);
			delay = delay + 0.4;
		end
	end
end

function ASSISTERPLUS_DELETEBTN()
	ui.MsgBox("Delete set?","ASSISTERPLUS_DELETESET","")
end

function ASSISTERPLUS_DELETESET()
	local frame = ui.GetFrame("ancient_card_list");
	local droplist = GET_CHILD(frame, "ADropList", "ui::CDropList");
	local setname = tostring(droplist:GetSelItemKey());
	g.settings.saves[setname] = nil;
	acutil.saveJSON(settingsFileLoc, g.settings);
	ASSISTERPLUS_DROPLIST(frame);
end
	
function ASSISTERPLUS_DROPLIST(frame)
	local DropList = tolua.cast(frame:CreateOrGetControl('droplist', 'ADropList', 460, 75, 150, 20), 'ui::CDropList');
	DropList:SetSelectedScp('ASSISTERPLUS_LOADSET');
	DropList:SetSkinName('droplist_normal'); 
	DropList:EnableHitTest(1);
	DropList:ClearItems();
	if g.settings.saves ~= nil then
		for k, v in pairs(g.settings.saves) do
			DropList:AddItem(k, k)
		end
	end
	local deletebtn = frame:CreateOrGetControl('button', 'delbtn', 438, 75, 20, 20);
	deletebtn:SetText("{#FF0000}{ol}X");
	deletebtn:SetEventScript(ui.LBUTTONUP,"ASSISTERPLUS_DELETEBTN");
	local savebtn = frame:CreateOrGetControl('button', 'sbtn', 612, 75, 85, 20);
	savebtn:SetText("{ol}Save");
	savebtn:SetEventScript(ui.LBUTTONUP,"ASSISTERPLUS_SAVEBTN");
	local Alertbox = frame:CreateOrGetControl('checkbox', 'alertbox', 95, 647, 100, 20)
    Alertbox:SetText("{ol}Fusion alert");
	Alertbox:SetEventScript(ui.LBUTTONUP,"ASSISTERPLUS_TABRESET");
	Alertbox:SetTextTooltip("Popup an alert if you try to fusion 3 of the same card, to avoid the mistake of doing a fusion instead of evolving.");
	local Alertboxchild = GET_CHILD(frame, "alertbox");
	Alertboxchild:SetCheck(g.settings.alert);
end

function ASSISTERPLUS_LOCKBTN(parent, FromctrlSet, argStr, argNum)
	local frame = ui.GetFrame("ancient_card_list");
	if ap_iscardlocked(argStr) then
		table.remove(g.settings.locklist, ap_tablefind(g.settings.locklist, tostring(argStr)));
	else
		table.insert(g.settings.locklist, tostring(argStr));
	end
	acutil.saveJSON(settingsFileLoc, g.settings);
	ON_ANCIENT_CARD_RELOAD(frame);
end

function ap_iscardlocked(guid)
	local Llist = g.settings.locklist;
	for k, v in pairs(Llist) do
		if v == tostring(guid) then
			return true
		end
	end
	return false
end

function ap_tablefind(tab,el)
	for index, value in pairs(tab) do
		if value == el then
			return index
		end
	end
end

function ASSISTERPLUS_ON_INIT(addon, frame)
	ASSISTERPLUS_LOAD();
	acutil.setupHook(ANCIENT_CARD_LIST_OPEN_HOOKED, "ANCIENT_CARD_LIST_OPEN");
	acutil.setupHook(SET_ANCIENT_CARD_LIST_HOOKED, "SET_ANCIENT_CARD_LIST");
	acutil.setupHook(ANCIENT_CARD_COMBINE_CHECK_HOOKED, "ANCIENT_CARD_COMBINE_CHECK");
end

function ANCIENT_CARD_LIST_OPEN_HOOKED(aframe)
	local frame = ui.GetFrame("ancient_card_list");
    local tab = frame:GetChild("tab")
    AUTO_CAST(tab);
    if tab ~= nil then
        tab:SelectTab(0);
        ANCIENT_CARD_LIST_TAB_CHANGE(frame)
    end 
    local ancient_card_num = frame:GetChild('ancient_card_num')
    ancient_card_num:SetTextByKey("max",ANCIENT_CARD_SLOT_MAX)
    ANCEINT_PASSIVE_LIST_SET(frame)
    ANCIENT_SET_COST(frame)
    local ancient_card_comb_name = GET_CHILD_RECURSIVELY(frame,"ancient_card_comb_name")
    ancient_card_comb_name:SetTooltipType('ancient_passive')
	ASSISTERPLUS_DROPLIST(frame)
end

function SET_ANCIENT_CARD_LIST_HOOKED(gbox,card)
    local height = (gbox:GetChildCount()-1) * 25.5
    local ctrlSet = gbox:CreateOrGetControlSet("ancient_card_item_list", "SET_" .. card.slot, 0, height);
	--lock
	local lockbtn = gbox:CreateOrGetControl('button', "lockbtn".. card.slot, 400, height+20, 60, 20);
	lockbtn:SetText("{ol}Lock");
	lockbtn:SetEventScript(ui.LBUTTONDOWN, 'ASSISTERPLUS_LOCKBTN');
    lockbtn:SetEventScriptArgString(ui.LBUTTONDOWN, tostring(card:GetGuid()));
	if ap_iscardlocked(card:GetGuid()) then
		lockbtn:SetText("{#FF0000}{ol}Locked");
	end
    --set level
    local exp = card:GetStrExp();
    local xpInfo = gePetXP.GetXPInfo(gePetXP.EXP_ANCIENT, tonumber(exp))
    local level = xpInfo.level
    local levelText = GET_CHILD_RECURSIVELY(ctrlSet,"ancient_card_level")
    levelText:SetText("{@st42b}{s16}Lv. "..level.."{/}")

    --set image
    local monCls = GetClass("Monster", card:GetClassName());
    local iconName = TryGetProp(monCls, "Icon");
    local slot = GET_CHILD_RECURSIVELY(ctrlSet,"ancient_card_slot")
    local image = CreateIcon(slot)
    image:SetImage(iconName)

    --set name
    local nameText = GET_CHILD_RECURSIVELY(ctrlSet,"ancient_card_name")
    local name = monCls.Name
    local starStr = ""
    for i = 1, card.starrank do
        starStr = starStr ..string.format("{img monster_card_starmark %d %d}", 21, 20)
    end
    local ancientCls = GetClass("Ancient_Info",monCls.ClassName)
    local rarity = ancientCls.Rarity
    AUTO_CAST(ctrlSet)
	if rarity == 1 then
		name = ctrlSet:GetUserConfig("NORMAL_GRADE_TEXT")..name..' '..starStr.."{/}"
	elseif rarity == 2 then
		name = ctrlSet:GetUserConfig("MAGIC_GRADE_TEXT")..name..' '..starStr.."{/}" 
	elseif rarity == 3 then
		name = ctrlSet:GetUserConfig("UNIQUE_GRADE_TEXT")..name..' '..starStr.."{/}"
	elseif rarity == 4 then
		name = ctrlSet:GetUserConfig("LEGEND_GRADE_TEXT")..name..' '..starStr.."{/}"
	end
    nameText:SetText(name)

    local racetypeDic = {
                        Klaida="insect",
                        Widling="wild",
                        Velnias="devil",
                        Forester="plant",
                        Paramune="variation",
                        None="melee"
                    }
    --set type
    local type1Slot = GET_CHILD_RECURSIVELY(ctrlSet,"ancient_card_type1_pic")
    local type1Icon = CreateIcon(type1Slot)
    type1Icon:SetImage("monster_"..racetypeDic[monCls.RaceType])

    local type2Slot = GET_CHILD_RECURSIVELY(ctrlSet,"ancient_card_type2_pic")
    local type2Icon = CreateIcon(type2Slot)
    type2Icon:SetImage("attribute_"..monCls.Attribute)    
    
    --tooltip
    ctrlSet:SetTooltipType("ancient_card")
    ctrlSet:SetTooltipStrArg(card:GetGuid())

	if not ap_iscardlocked(card:GetGuid()) then
		ctrlSet:SetUserValue("ANCIENT_GUID",card:GetGuid())
		ctrlSet:SetDragFrame('ancient_frame_drag')
		ctrlSet:SetDragScp("INIT_ANCEINT_FRAME_DRAG")
		if card.isNew == true then
			local slot = GET_CHILD_RECURSIVELY(ctrlSet,'ancient_card_slot')
			slot:SetHeaderImage('new_inventory_icon');
		end
	end
    return ctrlSet
end

function ANCIENT_CARD_COMBINE_CHECK_HOOKED(frame, guid)
	local samecardcnt = 0;
    local fromCard = session.pet.GetAncientCardByGuid(guid)
    local slotBox = GET_CHILD_RECURSIVELY(frame,"ancient_card_slot_Gbox")
    local cnt = slotBox:GetChildCount()
	for j = 0,cnt-1 do
		local toCtrlSet = slotBox:GetChildByIndex(j)
        local toGuid = toCtrlSet:GetUserValue("ANCIENT_GUID")
        if toGuid ~= nil and toGuid ~= "None" then   
			local toCard = session.pet.GetAncientCardByGuid(toGuid);
			if toCard:GetClassName() == fromCard:GetClassName() then
				samecardcnt = samecardcnt + 1;
				print(samecardcnt);
			end
        end	
	end
    for i = 0,cnt-1 do
        local toCtrlSet = slotBox:GetChildByIndex(i)
        local toGuid = toCtrlSet:GetUserValue("ANCIENT_GUID")
        if toGuid ~= nil and toGuid ~= "None" then 
			local toCard = session.pet.GetAncientCardByGuid(toGuid);
			if g.settings.alert == 1 and samecardcnt >= 2 then
				ui.MsgBox("{#FF0000}{ol}ALERT!{/}{/}{nl} {#FF0000}{ol}This is FUSION tab, will sacrifice 3 cards to get a random one.{/}{/}{nl}Continue?","","ASSISTERPLUS_TABRESET");
			end
            if toCard.rarity ~= fromCard.rarity then
                return false;
            else
                return true;
            end
        end
    end
    return true;
end

function ASSISTERPLUS_TABRESET()
	local frame = ui.GetFrame("ancient_card_list");
	local Alertboxchild = GET_CHILD(frame, "alertbox");
	g.settings.alert = Alertboxchild:IsChecked();
	acutil.saveJSON(settingsFileLoc, g.settings);
    local tab = frame:GetChild("tab")
    AUTO_CAST(tab);
    if tab ~= nil then
        tab:SelectTab(0);
        ANCIENT_CARD_LIST_TAB_CHANGE(frame)
    end 
end