-- Strategy profile initialization routine
-- Defines Strategy profile properties and Strategy parameters
-- TODO: Add minimal and maximal value of numeric parameters and default color of the streams
function Init()
    strategy:name("Bitcoin Breakout Strategy");
    strategy:description("Buys/Sells breakouts with Stop based on Highs/Lows. Tailored for BTC/USD trading.");
    strategy:type(core.Both);
    strategy:setTag("NonOptimizableParameters", "SendEmail,PlaySound,Email,SoundFile,RecurrentSound,ShowAlert");

    strategy.parameters:addGroup("Price Parameters");
    strategy.parameters:addString("TF", "Time frame ('t1', 'm1', 'm5', etc.)", "", "H1");
    strategy.parameters:setFlag("TF", core.FLAG_PERIODS);
    strategy.parameters:addGroup("Parameters");
    strategy.parameters:addInteger("ChannelPeriods", "Channel Periods", "how many bars to look back for highs lows", 24);
    strategy.parameters:addDouble("LimitMultiplier", "Limit Multiplier", "how far to set limit based on stop distance", 1.5);

    strategy.parameters:addGroup("Trading Parameters");
    strategy.parameters:addBoolean("AllowTrade", "Allow strategy to trade", "", true);
    strategy.parameters:setFlag("AllowTrade", core.FLAG_ALLOW_TRADE);
    strategy.parameters:addString("Account", "Account to trade on", "", "");
    strategy.parameters:setFlag("Account", core.FLAG_ACCOUNT);
    strategy.parameters:addInteger("Amount", "Trade Amount in Lots", "", 1, 1, 100);

    strategy.parameters:addGroup("Notification");
    strategy.parameters:addBoolean("ShowAlert", "Show Alert", "", false);
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
local ChannelPeriods;
local LimitMultiplier;
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
local Offer;
local CanClose;
--TODO: Add variable(s) for your indicator(s) if needed
local Channel_High = 0;
local Channel_Low = 0;

-- Routine
function Prepare(nameOnly)
    ChannelPeriods = instance.parameters.ChannelPeriods;
    LimitMultiplier = instance.parameters.LimitMultiplier;

    local name = profile:id() .. "(" .. instance.bid:instrument() .. ", " .. tostring(ChannelPeriods) .. ", " .. tostring(LimitMultiplier) .. ")";
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
    end

    gSource = ExtSubscribe(1, nil, instance.parameters.TF, true, "bar"); 
	tSource = ExtSubscribe(2, nil, 't1', true, "bar"); 
    --TODO: Find indicator's profile, intialize parameters, and create indicator's instance (if needed)
end

-- strategy calculation routine
-- TODO: Add your code for decision making
-- TODO: Update the instance of your indicator(s) if needed
function ExtUpdate(id, source, period)

    -- Strategy logic
    
	-- Close of Bar Actions
	if id == 1 then
		
		-- Update Channel High/Low
		-- create a range of candles
		local range = core.rangeTo(period-1, ChannelPeriods)

		-- find high and low
		local High, Highpos = mathex.max(gSource.high, range)
		local Low, Lowpos = mathex.min(gSource.low, range)	
		
		-- Updating global channel values
		Channel_High = High
		Channel_Low = Low
		
	end
	
	-- Tick Actions
	if id == 2 then
		-- Get High and Low the First tick if Channel_High or Channel_High == 0
		if Channel_High == 0 or Channel_Low == 0 then
			if gSource:hasData(gSource:size()-2-ChannelPeriods) then
				core.host:trace("Calculating Channel High/Low Values.")
				-- create a range of candles
				local range = core.rangeTo(gSource:size()-2, ChannelPeriods)

				-- find high and low
				local High, Highpos = mathex.max(gSource.high, range)
				local Low, Lowpos = mathex.min(gSource.low, range)	
				
				-- Updating global channel values
				Channel_High = High
				Channel_Low = Low
				core.host:trace("Channel High: " .. tostring(Channel_High))
				core.host:trace("Channel Low: " .. tostring(Channel_Low))
			end
		end
		
		-- BUY Logic
		if Channel_High ~= 0 and CrossedOver(instance.bid[NOW], Channel_High) == 1 then
			-- BUY
			if not haveTrades("B") then
				local limitprice = (instance.bid[NOW] - Channel_Low)* LimitMultiplier + instance.bid[NOW]
				enter("B", limitprice)
				exit("S")
			end
		end
		
		
		-- SELL Logic
		if Channel_Low ~= 0 and CrossedUnder(instance.bid[NOW], Channel_Low) == 2 then
			-- SELL
			if not haveTrades("S") then
				local limitprice = instance.bid[NOW] - (Channel_High - instance.bid[NOW])*LimitMultiplier
				enter("S", limitprice)
				exit("B")
			end
		end
	
	
	end



end


-- open positions in direction BuySell
function enter(BuySell, LimitPrice)

    local valuemap, success, msg;
    valuemap = core.valuemap();

    valuemap.OrderType = "OM";
    valuemap.OfferID = Offer;
    valuemap.AcctID = Account;
    valuemap.Quantity = Amount * BaseSize;
    valuemap.BuySell = BuySell;
    valuemap.GTC = "GTC";

    valuemap.RateLimit = LimitPrice

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


local blastdirection_T=0;
local bcurrentdirection_T=0;
local bfirsttime_T=true;
function CrossedOver (bline1, bline2)      
    if bfirsttime_T then
        bfirsttime_T=false;
        if bline1 > bline2 then
            bcurrentdirection_T = 1;
            blastdirection_T = 1;
        elseif bline1 < bline2 then
            bcurrentdirection_T = 2;
            blastdirection_T = 2;
        end
        return 0;
    else
        if bline1 > bline2 then
            bcurrentdirection_T = 1;
        elseif bline1 < bline2 then
            bcurrentdirection_T = 2;
        end
        if bcurrentdirection_T ~= blastdirection_T then
            blastdirection_T=bcurrentdirection_T;
            return bcurrentdirection_T;
        else
            return 0;
        end
    end
end


local blastdirection_B=0;
local bcurrentdirection_B=0;
local bfirsttime_B=true;
function CrossedUnder (bline1, bline2)      
    if bfirsttime_B then
        bfirsttime_B=false;
        if bline1 > bline2 then
            bcurrentdirection_B = 1;
            blastdirection_B = 1;
        elseif bline1 < bline2 then
            bcurrentdirection_B = 2;
            blastdirection_B = 2;
        end
        return 0;
    else
        if bline1 > bline2 then
            bcurrentdirection_B = 1;
        elseif bline1 < bline2 then
            bcurrentdirection_B = 2;
        end
        if bcurrentdirection_B ~= blastdirection_B then
            blastdirection_B=bcurrentdirection_B;
            return bcurrentdirection_B;
        else
            return 0;
        end
    end
end




dofile(core.app_path() .. "\\strategies\\standard\\include\\helper.lua");
