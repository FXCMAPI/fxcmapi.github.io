-- Strategy profile initialization routine
-- Defines Strategy profile properties and Strategy parameters
-- TODO: Add minimal and maximal value of numeric parameters and default color of the streams
function Init()
    strategy:name("Trend and Range Strategy");
    strategy:description("Trades trends and ranges based on ADX.");
    strategy:type(core.Both);
    strategy:setTag("NonOptimizableParameters", "SendEmail,PlaySound,Email,SoundFile,RecurrentSound,ShowAlert");

    strategy.parameters:addGroup("Price Parameters");
    strategy.parameters:addString("TF", "Time frame ('t1', 'm1', 'm5', etc.)", "", "m15");
    strategy.parameters:setFlag("TF", core.FLAG_PERIODS);
    strategy.parameters:addGroup("Parameters");
    strategy.parameters:addInteger("ADXPeriods", "ADX Periods", "No description", 14);
    strategy.parameters:addString("ADXTimeFrame", "ADX TimeFrame", "No description", "D1");
    strategy.parameters:addInteger("EMAFastPeriods", "EMAFast Periods", "No description", 50);
    strategy.parameters:addInteger("EMAMedPeriods", "EMAMed Periods", "No description", 150);
    strategy.parameters:addInteger("EMASlowPeriods", "EMASlow Periods", "No description", 250);
    strategy.parameters:addInteger("RSIPeriods", "RSI Periods", "No description", 14);
    strategy.parameters:addString("TrendRangeSwitch", "Trade Trend-Range-Both?", "No description", "Both");

    strategy.parameters:addGroup("Trading Parameters");
    strategy.parameters:addBoolean("AllowTrade", "Allow strategy to trade", "", false);
    strategy.parameters:setFlag("AllowTrade", core.FLAG_ALLOW_TRADE);
    strategy.parameters:addString("Account", "Account to trade on", "", "");
    strategy.parameters:setFlag("Account", core.FLAG_ACCOUNT);
    strategy.parameters:addInteger("Amount", "Trade Amount in Lots", "", 1, 1, 100);
    strategy.parameters:addBoolean("SetLimit", "Set Limit Orders", "", false);
    strategy.parameters:addInteger("Limit", "Limit Order in pips", "", 30, 1, 10000);
    strategy.parameters:addBoolean("SetStop", "Set Stop Orders", "", false);
    strategy.parameters:addInteger("Stop", "Stop Order in pips", "", 30, 1, 10000);
    strategy.parameters:addBoolean("TrailingStop", "Trailing stop order", "", false);

    strategy.parameters:addGroup("Notification");
    strategy.parameters:addBoolean("ShowAlert", "Show Alert", "", true);
    strategy.parameters:addBoolean("PlaySound", "Play Sound", "", false);
    strategy.parameters:addBoolean("RecurrentSound", "Recurrent Sound", "", false);
    strategy.parameters:addFile("SoundFile", "Sound File", "", "");
    strategy.parameters:setFlag("SoundFile", core.FLAG_SOUND);
    strategy.parameters:addBoolean("SendEmail", "Send Email", "", false);
    strategy.parameters:addString("Email", "Email", "", "");
    strategy.parameters:setFlag("Email", core.FLAG_EMAIL);
end

-- strategy instance initialization routine
-- Processes strategy parameters and creates output streams
-- TODO: Calculate all constants, create instances all necessary indicators and load all required libraries
-- Parameters block
local ADXPeriods;
local ADXTimeFrame;
local EMAFastPeriods;
local EMAMedPeriods;
local EMASlowPeriods;
local RSIPeriods;
local TrendRangeSwitch;
local gSource = nil; -- the source stream
local PlaySound;
local RecurrentSound;
local SoundFile;
local Email;
local SendEmail;
local AllowTrade;
local Account;
local Amount;
local BaseSize;
local SetLimit;
local Limit;
local SetStop;
local Stop;
local TrailingStop;
local Offer;
local CanClose;
--TODO: Add variable(s) for your indicator(s) if needed
local iADX;
local iEMAFast;
local iEMAMed;
local iEMASlow;
local iRSI;

-- Routine
function Prepare(nameOnly)
    ADXPeriods = instance.parameters.ADXPeriods;
    ADXTimeFrame = instance.parameters.ADXTimeFrame;
    EMAFastPeriods = instance.parameters.EMAFastPeriods;
    EMAMedPeriods = instance.parameters.EMAMedPeriods;
    EMASlowPeriods = instance.parameters.EMASlowPeriods;
    RSIPeriods = instance.parameters.RSIPeriods;
    TrendRangeSwitch = instance.parameters.TrendRangeSwitch;

    local name = profile:id() .. "(" .. instance.bid:instrument() .. ", " .. tostring(ADXPeriods) .. ", " .. tostring(ADXTimeFrame) .. ", " .. tostring(EMAFastPeriods) .. ", " .. tostring(EMAMedPeriods) .. ", " .. tostring(EMASlowPeriods) .. ", " .. tostring(RSIPeriods) .. ", " .. tostring(TrendRangeSwitch) .. ")";
    instance:name(name);

    if nameOnly then
        return ;
    end

    ShowAlert = instance.parameters.ShowAlert;

    PlaySound = instance.parameters.PlaySound;
    if PlaySound then
        RecurrentSound = instance.parameters.RecurrentSound;
        SoundFile = instance.parameters.SoundFile;
    else
        SoundFile = nil;
    end
    assert(not(PlaySound) or (PlaySound and SoundFile ~= ""), "Sound file must be specified");

    SendEmail = instance.parameters.SendEmail;
    if SendEmail then
        Email = instance.parameters.Email;
    else
        Email = nil;
    end
    assert(not(SendEmail) or (SendEmail and Email ~= ""), "E-mail address must be specified");


    AllowTrade = instance.parameters.AllowTrade;
    if AllowTrade then
        Account = instance.parameters.Account;
        Amount = instance.parameters.Amount;
        BaseSize = core.host:execute("getTradingProperty", "baseUnitSize", instance.bid:instrument(), Account);
        Offer = core.host:findTable("offers"):find("Instrument", instance.bid:instrument()).OfferID;
        CanClose = core.host:execute("getTradingProperty", "canCreateMarketClose", instance.bid:instrument(), Account);
        SetLimit = instance.parameters.SetLimit;
        Limit = instance.parameters.Limit * instance.bid:pipSize();
        SetStop = instance.parameters.SetStop;
        Stop = instance.parameters.Stop * instance.bid:pipSize();
        TrailingStop = instance.parameters.TrailingStop;
    end

    gSource = ExtSubscribe(1, nil, instance.parameters.TF, true, "bar");
    gSourceADX = ExtSubscribe(2, nil, instance.parameters.ADXTimeFrame, true, "bar"); 
    --TODO: Find indicator's profile, intialize parameters, and create indicator's instance (if needed)
    iADX = core.indicators:create("ADX", gSourceADX, ADXPeriods);
    iEMAFast = core.indicators:create("EMA", gSource.close, EMAFastPeriods);
    iEMAMed = core.indicators:create("EMA", gSource.close, EMAMedPeriods);
    iEMASlow = core.indicators:create("EMA", gSource.close, EMASlowPeriods);
    iRSI = core.indicators:create("RSI", gSource.close, RSIPeriods);
end

-- strategy calculation routine
-- TODO: Add your code for decision making
-- TODO: Update the instance of your indicator(s) if needed
function ExtUpdate(id, source, period)

    if id == 1 then
        -- update indicator streams
        iADX:update(core.UpdateLast)
        iEMAFast:update(core.UpdateLast)
        iEMAMed:update(core.UpdateLast)
        iEMASlow:update(core.UpdateLast)
        iRSI:update(core.UpdateLast)
        
        
        -- Trend Logic
        if TrendRangeSwitch == "Trend" or (TrendRangeSwitch == "Both" and iADX.DATA[iADX.DATA:size()-1] >= 25) then
            
            -- BUY LOGIC
            if iEMAFast.DATA[period] > iEMAMed.DATA[period] and iEMAMed.DATA[period] > iEMASlow.DATA[period] then
                -- close any sell trades
                if haveTrades("S") then
                    exit("S")
                end
                -- place a buy trade if none exists
                if not haveTrades("B") then
                    enter("B")
                end
            
            end
            
            
            -- SELL LOGIC
            if iEMAFast.DATA[period] < iEMAMed.DATA[period] and iEMAMed.DATA[period] < iEMASlow.DATA[period] then
                -- close any buy trades
                if haveTrades("B") then
                    exit("B")
                end
                -- place a sell trade if none exists
                if not haveTrades("S") then
                    enter("S")
                end
            
            
            end
        
            -- EXIT LOGIC
            -- Buy Close
            if haveTrades("B") and not (iEMAFast.DATA[period] > iEMAMed.DATA[period] and iEMAMed.DATA[period] > iEMASlow.DATA[period]) then
                exit("B")
            end
            -- Sell Close
            if haveTrades("S") and not (iEMAFast.DATA[period] < iEMAMed.DATA[period] and iEMAMed.DATA[period] < iEMASlow.DATA[period]) then
                exit("S")
            end
        
        end

        -- Range Logic
        if TrendRangeSwitch == "Range" or (TrendRangeSwitch == "Both" and iADX.DATA[iADX.DATA:size()-1] < 25) then
        
            -- BUY LOGIC
            if iRSI.DATA[period] < 30 then
                -- close any sell trades
                if haveTrades("S") then
                    exit("S")
                end
                -- place a buy trade if none exists
                if not haveTrades("B") then
                    enter("B")
                end
            
            end
            
            
            -- SELL LOGIC
            if iRSI.DATA[period] > 70 then
                -- close any buy trades
                if haveTrades("B") then
                    exit("B")
                end
                -- place a sell trade if none exists
                if not haveTrades("S") then
                    enter("S")
                end
            
            end
        
        
        
        end
    end
    
    
    
    
end





-- open positions in direction BuySell
function enter(BuySell)

    local valuemap, success, msg;
    valuemap = core.valuemap();

    valuemap.OrderType = "OM";
    valuemap.OfferID = Offer;
    valuemap.AcctID = Account;
    valuemap.Quantity = Amount * BaseSize;
    valuemap.BuySell = BuySell;
    valuemap.GTC = "GTC";

    if SetLimit then
        -- set limit order
        valuemap.PegTypeLimit = "O";
        if BuySell == "B" then
           valuemap.PegPriceOffsetPipsLimit = Limit/instance.bid:pipSize();
        else
           valuemap.PegPriceOffsetPipsLimit = -Limit/instance.bid:pipSize();
        end
    end

    if SetStop then
        -- set stop order
        valuemap.PegTypeStop = "O";
        if BuySell == "B" then
           valuemap.PegPriceOffsetPipsStop = -Stop/instance.bid:pipSize();
        else
           valuemap.PegPriceOffsetPipsStop = Stop/instance.bid:pipSize();
        end
		
		if TrailingStop then
            valuemap.TrailStepStop = 1;
        end
    end

    if (not CanClose) and (StopLoss > 0 or TakeProfit > 0) then
        valuemap.EntryLimitStop = "Y"
    end
    
    success, msg = terminal:execute(100, valuemap);

    if not(success) then
        terminal:alertMessage(instance.bid:instrument(), instance.bid[instance.bid:size() - 1], "open order failure: " .. msg, instance.bid:date(instance.bid:size() - 1));
        return false;
    end

    return true;
end


-- exit positions in direction BuySell
function exit(BuySell)
	enum = core.host:findTable("trades"):enumerator();
	row = enum:next();

	while row ~= nil do
		if row.OfferID == Offer and
		   row.AccountID == Account and
		   (row.BS == BuySell or BuySell == nil) then
		   
			-- close trade
			local valuemap = core.valuemap();
			valuemap.Command = "CreateOrder";
			valuemap.OrderType = "CM";
			valuemap.OfferID = Offer;
			valuemap.AcctID = Account;
			valuemap.Quantity = row.Lot;
			valuemap.TradeID = row.TradeID;
			if row.BS == "B" then
                valuemap.BuySell = "S";
			else
                valuemap.BuySell = "B";
			end
			local success, msg = terminal:execute(200, valuemap);
			if not (success) then
                terminal:alertMessage(instance.bid:instrument(), instance.bid[NOW], "close order failure:" .. msg, instance.bid:date(NOW));
			end

		end
		row = enum:next();
	end
end

-- return true if trade is found (can check single side as well)
function haveTrades(BuySell)
    local enum, row;
    local found = false;
    enum = core.host:findTable("trades"):enumerator();
    row = enum:next();
    while (not found) and (row ~= nil) do
        if row.AccountID == Account and
           row.OfferID == Offer and
           (row.BS == BuySell or BuySell == nil) then
           found = true;
        end
        row = enum:next();
    end

    return found;
end













dofile(core.app_path() .. "\\strategies\\standard\\include\\helper.lua");
