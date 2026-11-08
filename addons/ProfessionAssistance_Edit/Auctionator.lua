local addonName, addon = ...;

local function GetPriceAPI()
	if not PA_SavedSettings or PA_SavedSettings.AuctionatorPrices == false then return end;
	local api = Auctionator and Auctionator.API and Auctionator.API.v1;
	return api and type(api.GetAuctionPriceByItemID) == 'function' and api.GetAuctionPriceByItemID or nil;
end

local function GetMaterialID(item)
	if type(item) == 'number' then return item end;
	if type(item) == 'string' then
		return tonumber(item:match('item:(%d+)'));
	end
end

function addon.HasAuctionatorPrices()
	return GetPriceAPI() ~= nil;
end

function addon.AddMaterialLine(tooltip, item, text)
	local getPrice = GetPriceAPI();
	local itemID = GetMaterialID(item);
	if not getPrice or not itemID then
		tooltip:AddLine(text, 1, 1, 1);
		return;
	end

	-- Query by exact material ID, including quality-specific IDs. Read the current
	-- database on each tooltip build so a later Auctionator scan replaces misses.
	local ok, price = pcall(getPrice, addonName, itemID);
	if ok and type(price) == 'number' and price > 0 and price < math.huge then
		-- Retail moved the coin formatter to C_CurrencyInfo. Keep the material
		-- visible even if formatting fails, instead of aborting the whole tooltip.
		local formatMoney = C_CurrencyInfo and C_CurrencyInfo.GetCoinTextureString;
		local formatted, moneyText = pcall(formatMoney, math.floor(price));
		if formatted and type(moneyText) == 'string' and moneyText ~= '' then
			tooltip:AddDoubleLine(text, moneyText, 1, 1, 1, 1, 1, 1);
		else
			tooltip:AddDoubleLine(text, 'Price unavailable', 1, 1, 1, 0.55, 0.55, 0.55);
		end
	else
		tooltip:AddDoubleLine(text, 'No price', 1, 1, 1, 0.55, 0.55, 0.55);
	end
end
