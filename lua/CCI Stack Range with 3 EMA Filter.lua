-- Strategy profile initialization routine
-- Defines Strategy profile properties and Strategy parameters
-- TODO: Add minimal and maximal value of numeric parameters and default color of the streams
function Init()
    strategy:name("CCI Stack Range with 3 EMA Filter");
    strategy:description("Stack positions when CCI reaches extremes but not if EMA is showing a counter trend.");
    strategy:type(core.Both);
    strategy:setTag("NonOptimizableParameters", "SendEmail,PlaySound,Email,SoundFile,RecurrentSound,ShowAlert");

    strategy.parameters:addGroup("Price Parameters");
    strategy.parameters:addString("TF", "Time frame ('t1', 'm1', 'm5', etc.)", "", "m15");
    strategy.parameters:setFlag("TF", core.FLAG_PERIODS);
    strategy.parameters:addGroup("Parameters");
    strategy.parameters:addInteger("CCIPeriods", "CCI Periods", "No description", 14);
    strategy.parameters:addInteger("FastEMAPeriods", "Fast EMA Periods", "No description", 50);
    strategy.parameters:addInteger("MedEMAPeriods", "Med EMA Periods", "No description", 150);
    strategy.parameters:addInteger("SlowEMAPeriods", "Slow EMA Periods", "No description", 250);

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
local CCIPeriods;
local FastEMAPeriods;
local MedEMAPeriods;
local SlowEMAPeriods;
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
local iCCI;
local iFastEMA;
local iMedEMA;
local iSlowEMA;

-- Routine
function Prepare(nameOnly)
    CCIPeriods = instance.parameters.CCIPeriods;
    FastEMAPeriods = instance.parameters.FastEMAPeriods;
    MedEMAPeriods = instance.parameters.MedEMAPeriods;
    SlowEMAPeriods = instance.parameters.SlowEMAPeriods;

    local name = profile:id() .. "(" .. instance.bid:instrument() .. ", " .. tostring(CCIPeriods) .. ", " .. tostring(FastEMAPeriods) .. ", " .. tostring(MedEMAPeriods) .. ", " .. tostring(SlowEMAPeriods) .. ")";
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
    --TODO: Find indicator's profile, intialize parameters, and create indicator's instance (if needed)
    
    iCCI = core.indicators:create("CCI", gSource, CCIPeriods);
    iFastEMA = core.indicators:create("EMA", gSource.close, FastEMAPeriods);
    iMedEMA = core.indicators:create("EMA", gSource.close, MedEMAPeriods);
    iSlowEMA = core.indicators:create("EMA", gSource.close, SlowEMAPeriods);
    
end

-- strategy calculation routine
-- TODO: Add your code for decision making
-- TODO: Update the instance of your indicator(s) if needed
function ExtUpdate(id, source, period)

    -- update indicators
    iCCI:update(core.UpdateLast)
    iFastEMA:update(core.UpdateLast)
    iMedEMA:update(core.UpdateLast)
    iSlowEMA:update(core.UpdateLast)
    
    -- TRADING LOGIC
    
    OpenBuyPositions = haveTrades("B")
    OpenSellPositions = haveTrades("S")
    
    -- BUY Signals
    if not (iFastEMA.DATA[period] < iMedEMA.DATA[period] and iMedEMA.DATA[period] < iSlowEMA.DATA[period]) then
    
        if iCCI.DATA[period] <= -100 and OpenBuyPositions == 0 then
            enter("B")
        elseif iCCI.DATA[period] <= -150 and OpenBuyPositions == 1 then
            enter("B")
        elseif iCCI.DATA[period] <= -200 and OpenBuyPositions == 2 then
            enter("B")
        elseif iCCI.DATA[period] <= -250 and OpenBuyPositions == 3 then
            enter("B")
        end
        
    end
    
    
    
    -- SELL Signals
    
    if not (iFastEMA.DATA[period] > iMedEMA.DATA[period] and iMedEMA.DATA[period] > iSlowEMA.DATA[period]) then
    
        if iCCI.DATA[period] >= 100 and OpenSellPositions == 0 then
            enter("S")
        elseif iCCI.DATA[period] >= 150 and OpenSellPositions == 1 then
            enter("S")
        elseif iCCI.DATA[period] >= 200 and OpenSellPositions == 2 then
            enter("S")
        elseif iCCI.DATA[period] >= 250 and OpenSellPositions == 3 then
            enter("S")
        end
        
    end
    
    
    -- EXIT LOGIC
    
    if iCCI.DATA[period] > 0 then
        -- close buy trades
        exit("B")
    end
    
    if iCCI.DATA[period] < 0 then
        -- close sell trades
        exit("S")
    end


end


-- return number of buy or sell trades we have open
function haveTrades(BuySell)
    local enum, row;
    local openpositions = 0;
    enum = core.host:findTable("trades"):enumerator();
    row = enum:next();
    while (row ~= nil) do
        if row.AccountID == Account and
           row.OfferID == Offer and
           (row.BS == BuySell or BuySell == nil) then
           openpositions = openpositions + 1
        end
        row = enum:next();
    end

    return openpositions;
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


dofile(core.app_path() .. "\\strategies\\standard\\include\\helper.lua");
