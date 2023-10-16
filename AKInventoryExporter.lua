local addonId = "AKInventoryExporter"

AKInventoryExporter = {}
AKInventoryExporter.name = "AKInventoryExporter"

local task = AKInventoryExporter.task or LibAsync:Create("AKInventoryExporterAsync")

local logger = LibDebugLogger("AKInventoryExporter")

function AKInventoryExporter:readData()
	task:Call(function()
		logger:Info("Starting Report")
		local worldName = GetWorldName():gsub(" Megaserver", "")
		local iifaData = IIfA.data[worldName].DBv3
		local count = 0
		for itemLink, itemData in pairs(iifaData) do
			local myItem = {}
			myItem.itemName = itemData.itemName
			myItem.itemQuality = itemData.itemQuality
			myItem.locations = {}
			for locationId, locationDetails in pairs(itemData.locations) do
				local location = {}
				location.id = locationId
				for k, v in pairs(locationDetails) do
					if ( k == "bagID" ) then
						location.bagId = v
					elseif( k == "bagSlot" ) then
						for w, z in pairs(v) do
							location.slotId = w
							location.locationQuantity = z
						end
					end
				end
				
				if( location.id == "Bank" or location.id == "CraftBag" ) then
					location.locationType = location.id
					location.locationName = location.id
				elseif( string.len(location.id) < 16 ) then
					location.locationType = "HouseCollectible"
					location.locationName = GetCollectibleNickname(location.id)
				else
					location.locationType = "Character"
					local charName = GetCharacterNameById(StringToId64(location.id))
					charName = charName:sub(1, charName:find("%^") - 1)
					location.locationName = charName
				end
				
				myItem.locations[#myItem.locations + 1] = location
			end
			myItem.trait = GetItemLinkTraitInfo(itemLink)
			myItem.style = GetItemStyleName(GetItemLinkItemStyle(itemLink))
			
			local outfitStyleName = GetItemStyleName(GetOutfitStyleItemStyleId(GetItemLinkOutfitStyleId(itemLink)))
			
			if(outfitStyleName ~= nil and outfitStyleName ~= '') then
				myItem.outfitStyleId = outfitStyleName
			end
			
			local hasSet, _setName, _numBonuses, _numEquipped, _maxEquipped, setId = GetItemLinkSetInfo(itemLink)
			if hasSet then
				myItem.setName = _setName
			end
			local itemType =  GetItemLinkItemType(itemLink)
			if(itemType == 1) then
				myItem.itemType = GetString("SI_WEAPONTYPE", GetItemLinkWeaponType(itemLink))
			elseif(itemType == 2) then
				local itemTypePrefix = ""
				if(GetItemLinkArmorType(itemLink) > 0) then
					itemTypePrefix = GetString("SI_ARMORTYPE", GetItemLinkArmorType(itemLink)).." "
				end
				myItem.itemType = itemTypePrefix..GetString("SI_EQUIPTYPE",  GetItemLinkEquipType(itemLink))
			else
				myItem.itemType = GetString("SI_ITEMTYPE", GetItemLinkItemType(itemLink))
			end
			-- myItem.itemType2 = GetItemLinkItemType(itemLink)
			-- myItem.itemType3 = GetItemLinkArmorType(itemLink)
			-- myItem.itemType4 = GetItemLinkEquipType(itemLink)
			local gold   = LibPrice.ItemLinkToPriceGold(itemLink)
			if(gold  ~= nil) then
				myItem.price = gold
			end
			count = count + 1
			AKInventoryExporter.savedVariables.data[tonumber((tostring(itemLink):match("|H%d:item:(%d+)") or -1))] = myItem
		end
		logger:Info("Completing Report: ",count," items found")
	end)
end

	
EVENT_MANAGER:RegisterForEvent(AKInventoryExporter.name, EVENT_ADD_ON_LOADED, function(eventCode, addonName) -- {{{

    if addonName ~= AKInventoryExporter.name then return end
	
	AKInventoryExporter.savedVariables = ZO_SavedVars:NewAccountWide("AKInventoryExporter_Data", 1, nil, {}) 
	AKInventoryExporter.savedVariables.data = {}

    --unregister the event again as our addon was loaded now and we do not need it anymore to be run for each other addon that will load
    EVENT_MANAGER:UnregisterForEvent(AKInventoryExporter.name, EVENT_ADD_ON_LOADED) 
	 
	ZO_PreHook("Logout", function() 
	  AKInventoryExporter:readData()
	end)
	 
	ZO_PreHook("Quit", function() 
	  AKInventoryExporter:readData()
	end)

	SLASH_COMMANDS["/akt"] = AKInventoryExporter.readData 

	EVENT_MANAGER:RegisterForUpdate(AKInventoryExporter.name .. "ExportInterval", 60000,  AKInventoryExporter.readData)

	AKInventoryExporter:readData()
end) -- }}}

