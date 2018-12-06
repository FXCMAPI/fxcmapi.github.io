-- Strategy profile initialization routine
-- Defines Strategy profile properties and Strategy parameters
-- TODO: Add minimal and maximal value of numeric parameters and default color of the streams
function Init()
    strategy:name("Stochastic During Asia");
    strategy:description("Trades Stochastic but only during Asia trading hours");
    strategy:type(core.Both);
    strategy:setTag("NonOptimizableParameters", "SendEmail,PlaySound,Email,SoundFile,RecurrentSound,ShowAlert");

    strategy.parameters:addGroup("Price Parameters");
    strategy.parameters:addString("TF", "Time frame ('t1', 'm1', 'm5', etc.)", "", "m15");
    strategy.parameters:setFlag("TF", core.FLAG_PERIODS);
    strategy.parameters:addGroup("Parameters");
    strategy.parameters:addInteger("KPeriods", "%K Periods", "No description", 15);
    strategy.parameters:addInteger("DSlowingPeriods", "%D slowing periods", "No description", 5);
    strategy.parameters:addInteger("DPeriods", "%D periods", "No description", 5);
    strategy.parameters:addString("StartTime", "Start Time (hh:mm:ss)", "The time we want to start looking for trades each day.", "17:00:00");
    strategy.parameters:addString("EndTime", "End Time (hh:mm:ss)", "The time to stop looking for trades each day.", "03:00:00");
    strategy.parameters:addBoolean("UseStartEndTime", "Use Start/End Time?", "Yes = Use Start/End Time, No = Trade 24 hours a day", true);

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
local KPeriods;
local DSlowingPeriods;
local DPeriods;
local StartTime;
local EndTime;
local UseStartEndTime;
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
local iStoch;

-- Routine
function Prepare(nameOnly)
    KPeriods = instance.parameters.KPeriods;
    DSlowingPeriods = instance.parameters.DSlowingPeriods;
    DPeriods = instance.parameters.DPeriods;
    StartTime = instance.parameters.StartTime;
    EndTime = instance.parameters.EndTime;
    UseStartEndTime = instance.parameters.UseStartEndTime;

    local name = profile:id() .. "(" .. instance.bid:instrument() .. ", " .. tostring(KPeriods) .. ", " .. tostring(DSlowingPeriods) .. ", " .. tostring(DPeriods) .. ", " .. tostring(StartTime) .. ", " .. tostring(EndTime) .. ", " .. tostring(UseStartEndTime) .. ")";
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
    
    iStoch = core.indicators:create("SSD", gSource, KPeriods, DSlowingPeriods, DPeriods);
    
end

-- strategy calculation routine
-- TODO: Add your code for decision making
-- TODO: Update the instance of your indicator(s) if needed
function ExtUpdate(id, source, period)

    -- update indicator values
    iStoch:update(core.UpdateLast);
    
    -- TRADING LOGIC
    
    -- Entry Logic
    -- Use Start End/Time
    if not UseStartEndTime or IsTradingTime() then
        -- Buy Logic, when K line crosses above D line, while they are both below 20, then Buy
        if core.crossesOver(iStoch.K, iStoch.D, period) and iStoch.K[period] < 20 and iStoch.D[period] < 20 then
            -- BUY SIGNAL
            if not haveTrades("B") then
                enter("B")
            end
        end
        
        
        -- Sell Logic, when K line crosses below D line, while they are both above 80, then Sell
        if core.crossesUnder(iStoch.K, iStoch.D, period) and iStoch.K[period] > 80 and iStoch.D[period] > 80 then
            -- SELL SIGNAL
            if not haveTrades("S") then
                enter("S")
            end
        end
    end

    -- Exit Logic
    if haveTrades("B") and iStoch.K[period] > 80 then
        -- Exit Buy Trade
        exit("B")
    end
    
    if haveTrades("S") and iStoch.K[period] < 20 then
        -- Exit Sell Trade
        exit("S")
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

-- exits positions in direction BuySell
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


--return true if current time is in trading time
function IsTradingTime()
    local currentTime = core.host:execute("getServerTime");

	local startTimeToday = ConvertStrToTime(StartTime);
	local endTimeToday = ConvertStrToTime(EndTime);

	--compare current time
	if startTimeToday <= endTimeToday then
		if currentTime >= startTimeToday and currentTime < endTimeToday then
			return true;
		end
	else
		if currentTime >= startTimeToday or currentTime < endTimeToday then
			return true;
		end
	end

    return false;
end

--Converts a time in string to time value
function ConvertStrToTime(timeString, source, period)
    local h, m, s;
    local currentTime = core.host:execute("getServerTime");
    
    local nowTable = core.dateToTable(currentTime);

    for HH, MM, SS in string.gmatch(timeString, "(%w+):(%w+):(%w+)") do
        h = tonumber(HH);
        m = tonumber(MM);
        s = tonumber(SS);
    end
    local time = core.datetime(nowTable.year, nowTable.month, nowTable.day, h, m, s);
    return time;
end



dofile(core.app_path() .. "\\strategies\\standard\\include\\helper.lua");
