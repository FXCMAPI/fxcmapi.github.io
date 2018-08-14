-- Strategy profile initialization routine
-- Defines Strategy profile properties and Strategy parameters
-- TODO: Add minimal and maximal value of numeric parameters and default color of the streams
function Init()
    strategy:name("3 EMA Pullback 2.0");
    strategy:description("No description");
    strategy:type(core.Both);
    strategy:setTag("NonOptimizableParameters", "SendEmail,PlaySound,Email,SoundFile,RecurrentSound,ShowAlert");

    strategy.parameters:addGroup("Price Parameters");
    strategy.parameters:addString("TF", "Time frame ('t1', 'm1', 'm5', etc.)", "", "m1");
    strategy.parameters:setFlag("TF", core.FLAG_PERIODS);
    strategy.parameters:addGroup("Parameters");
    strategy.parameters:addInteger("FastEMA", "Fast EMA Periods", "No description", 50);
    strategy.parameters:addInteger("MedEMA", "Medium EMA Periods", "No description", 150);
    strategy.parameters:addInteger("SlowEMA", "Slow EMA Periods", "No description", 250);
	
	strategy.parameters:addGroup("Stage 1 High/Low Parameters");
    strategy.parameters:addInteger("LookBack", "LookBack Periods", "No description", 100);
	strategy.parameters:addBoolean("EnableStage1Timeframe", "EnableStage1Timeframe", "if set to yes, high/low can only be made when time is between TimeRangeStart and TimeRangeEnd", true);
	strategy.parameters:addString("TimeRangeStart", "TimeRangeStart", "set the time to start looking for high/low", "03:00:00");
    strategy.parameters:addString("TimeRangeEnd", "TimeRangeEnd", "set the time to stop looking for high/low", "17:00:00");

    strategy.parameters:addGroup("Trading Parameters");
    strategy.parameters:addBoolean("AllowTrade", "Allow strategy to trade", "", true);
    strategy.parameters:setFlag("AllowTrade", core.FLAG_ALLOW_TRADE);
    strategy.parameters:addString("Account", "Account to trade on", "", "");
    strategy.parameters:setFlag("Account", core.FLAG_ACCOUNT);
    strategy.parameters:addInteger("Amount", "Trade Amount in Lots", "", 1, 1, 100);
    strategy.parameters:addBoolean("SetLimit", "Set Limit Orders", "", true);
    strategy.parameters:addInteger("Limit", "Limit Order in pips", "", 30, 1, 10000);
    strategy.parameters:addBoolean("SetStop", "Set Stop Orders", "", true);
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
local FastEMA;
local MedEMA;
local SlowEMA;
local LookBack;
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
local iEMAFast;
local iEMAMed;
local iEMASlow;

local EnableStage1Timeframe;
local TimeRangeStart;
local TimeRangeEnd;
local PrevHigh;
local Prevlow;


-- Routine
function Prepare(nameOnly)
    FastEMA = instance.parameters.FastEMA;
    MedEMA = instance.parameters.MedEMA;
    SlowEMA = instance.parameters.SlowEMA;
    LookBack = instance.parameters.LookBack;
	EnableStage1Timeframe = instance.parameters.EnableStage1Timeframe;
	TimeRangeStart = instance.parameters.TimeRangeStart;
	TimeRangeEnd = instance.parameters.TimeRangeEnd;

    local name = profile:id() .. "(" .. instance.bid:instrument() .. ", " .. tostring(FastEMA) .. ", " .. tostring(MedEMA) .. ", " .. tostring(SlowEMA) .. ", " .. tostring(LookBack).. ", " .. tostring(EnableStage1Timeframe) .. ")";
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
    tSource = ExtSubscribe(2, nil, "t1", true, "bar"); 
    --TODO: Find indicator's profile, intialize parameters, and create indicator's instance (if needed)
    iEMAFast = core.indicators:create("EMA", gSource.close, FastEMA)
    iEMAMed = core.indicators:create("EMA", gSource.close, MedEMA)
    iEMASlow = core.indicators:create("EMA", gSource.close, SlowEMA)
end


local Stage1Status = "Neutral"; -- possible values are "Neutral", "Buy", "Sell"

-- strategy calculation routine
-- TODO: Add your code for decision making
-- TODO: Update the instance of your indicator(s) if needed
function ExtUpdate(id, source, period)


    -- update indicators
    iEMAFast:update(core.UpdateLast);
    iEMAMed:update(core.UpdateLast);
    iEMASlow:update(core.UpdateLast);

    -- check for data
    --if not iEMAFast.DATA:hasData(period) or not iEMAMed.DATA:hasData(period) or not iEMAMed.DATA:hasData(period) then
        --core.host:trace("Not Enough Data. Checking Next Bar...")
        --return;
    --end
    
    -- close of bar, Stage 1, making sure EMAs are lined up and price has reached 100 bar high/low
    if id == 1 and not haveTrades() then
    
        -- create a range of candles
        local range = core.rangeTo(period-1, LookBack)

        -- find high and low
        local High, Highpos = mathex.max(gSource.high, range)
        local Low, Lowpos = mathex.min(gSource.low, range)
        
        -- buy setup, if Price > Fast > Med > Slow AND close Price is above 100 period high
        if gSource.close[period] > iEMAFast.DATA[period] and
            iEMAFast.DATA[period] > iEMAMed.DATA[period] and
            iEMAMed.DATA[period] > iEMASlow.DATA[period] and
            gSource.close[period] > High then
				if not EnableStage1Timeframe or insideTimeRange() then
					Stage1Status = "Buy"
					terminal:alertMessage(instance.bid:instrument(), instance.bid[NOW], "Looking for Buy Trigger...", instance.bid:date(NOW));
					PrevHigh, PrevHighpos = mathex.max(gSource.high, core.rangeTo(period-10, 50))
				else
					Stage1Status = "Neutral"
					terminal:alertMessage(instance.bid:instrument(), instance.bid[NOW], "New High Occurred Outside of Time Range, Removing Any Prior Signal...", instance.bid:date(NOW));
				end
        end
    
        
        -- sell setup, if Price < Fast < Med < Slow AND close Price is below 100 period low
        if gSource.close[period] < iEMAFast.DATA[period] and
            iEMAFast.DATA[period] < iEMAMed.DATA[period] and
            iEMAMed.DATA[period] < iEMASlow.DATA[period] and
            gSource.close[period] < Low then
				if not EnableStage1Timeframe or insideTimeRange() then
					Stage1Status = "Sell"
					terminal:alertMessage(instance.bid:instrument(), instance.bid[NOW], "Looking for Sell Trigger...", instance.bid:date(NOW));
					PrevLow, PrevLowpos = mathex.min(gSource.low, core.rangeTo(period-10, 50))
				else
					Stage1Status = "Neutral"
					terminal:alertMessage(instance.bid:instrument(), instance.bid[NOW], "New Low Occurred Outside of Time Range, Removing Any Prior Signal...", instance.bid:date(NOW));
				end
        end
    
    end
    
    -- every tick, Stage 2, Stage1Status must not be "Neutral" and trigger buy/sell when Fast EMA is hit or crossed
    if id == 2 and Stage1Status ~= "Neutral" then
        
        --core.host:trace("EMA Value = " .. tostring(iEMAFast.DATA[iEMAFast.DATA:size()-1]));
        
        -- Buy trigger
        if Stage1Status == "Buy" and instance.bid[NOW] <= iEMAFast.DATA[iEMAFast.DATA:size()-1] then
            Stage1Status = "Neutral"
            -- BUY
			if instance.bid[NOW] >= PrevHigh - instance.bid:pipSize()*5 then
				enter("B")
				terminal:alertMessage(instance.bid:instrument(), instance.bid[NOW], "Opening Buy Trade...", instance.bid:date(NOW));
			else
				-- NOT PLACING A BUY TRADE
				terminal:alertMessage(instance.bid:instrument(), instance.bid[NOW], "Price is Below PrevHigh-5, Skipping Buy Signal...", instance.bid:date(NOW));
			end
        end
        
        -- Sell trigger
        if Stage1Status == "Sell" and instance.bid[NOW] >= iEMAFast.DATA[iEMAFast.DATA:size()-1] then
            Stage1Status = "Neutral"
            -- SELL
			if instance.bid[NOW] <= PrevLow + instance.bid:pipSize()*5 then
				enter("S")
				terminal:alertMessage(instance.bid:instrument(), instance.bid[NOW], "Opening Sell Trade...", instance.bid:date(NOW));
			else
				-- NOT PLACING A SELL TRADE
				terminal:alertMessage(instance.bid:instrument(), instance.bid[NOW], "Price is Above PrevLow+5, Skipping Sell Signal...", instance.bid:date(NOW));
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


function insideTimeRange()
	local currentTime = core.host:execute("getServerTime");

	local startTimeToday = ConvertStrToTime(TimeRangeStart);
	local endTimeToday = ConvertStrToTime(TimeRangeEnd);

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
