-- Strategy profile initialization routine
-- Defines Strategy profile properties and Strategy parameters
-- TODO: Add minimal and maximal value of numeric parameters and default color of the streams
function Init()
    strategy:name("Breakout Strategy with Smart Stops");
    strategy:description("Buys/Sells breakouts with Stop based on Highs/Lows");
    strategy:type(core.Both);
    strategy:setTag("NonOptimizableParameters", "SendEmail,PlaySound,Email,SoundFile,RecurrentSound,ShowAlert");

    strategy.parameters:addGroup("Price Parameters");
    strategy.parameters:addString("TF", "Time frame ('t1', 'm1', 'm5', etc.)", "", "H1");
    strategy.parameters:setFlag("TF", core.FLAG_PERIODS);
    strategy.parameters:addGroup("Parameters");
    strategy.parameters:addInteger("ChannelPeriods", "Channel Periods", "how many bars to look back for highs lows", 20);
    strategy.parameters:addDouble("StopOffset", "Stop Offset (in pips)", "how far to set our stop from previous high/low", 5.0);
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
local StopOffset;
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


-- Routine
function Prepare(nameOnly)
    ChannelPeriods = instance.parameters.ChannelPeriods;
    StopOffset = instance.parameters.StopOffset;
    LimitMultiplier = instance.parameters.LimitMultiplier;

    local name = profile:id() .. "(" .. instance.bid:instrument() .. ", " .. tostring(ChannelPeriods) .. ", " .. tostring(StopOffset) .. ", " .. tostring(LimitMultiplier) .. ")";
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

    gSource = ExtSubscribe(1, nil, instance.parameters.TF, instance.parameters.Type == "Bid", "bar"); 
    --TODO: Find indicator's profile, intialize parameters, and create indicator's instance (if needed)
end

-- strategy calculation routine
-- TODO: Add your code for decision making
-- TODO: Update the instance of your indicator(s) if needed
function ExtUpdate(id, source, period)



--wwww.fxcodebase.com
--rob@fxcm.com

    -- Strategy logic
    
    -- create a range of candles
    local range = core.rangeTo(period-1, ChannelPeriods)

    -- find high and low
    local High, Highpos = mathex.max(gSource.high, range)
    local Low, Lowpos = mathex.min(gSource.low, range)
    
    -- BUY Logic
    if gSource.close[period] > High then
        -- BUY
        if not haveTrades("B") then
            local stopprice = Low - StopOffset*instance.bid:pipSize()
            local limitprice = (instance.bid[NOW] - stopprice)* LimitMultiplier + instance.bid[NOW]
            enter("B", stopprice, limitprice)
        end
    end
    
    
    -- SELL Logic
    if gSource.close[period] < Low then
        -- SELL
        if not haveTrades("S") then
            local stopprice = High + StopOffset*instance.bid:pipSize()
            local limitprice = instance.bid[NOW] - (stopprice - instance.bid[NOW])*LimitMultiplier
            enter("S", stopprice, limitprice)
        end
    end



end


-- open positions in direction BuySell
function enter(BuySell, StopPrice, LimitPrice)

    local valuemap, success, msg;
    valuemap = core.valuemap();

    valuemap.OrderType = "OM";
    valuemap.OfferID = Offer;
    valuemap.AcctID = Account;
    valuemap.Quantity = Amount * BaseSize;
    valuemap.BuySell = BuySell;
    valuemap.GTC = "GTC";

    valuemap.RateLimit = LimitPrice

    valuemap.RateStop = StopPrice

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







dofile(core.app_path() .. "\\strategies\\standard\\include\\helper.lua");
