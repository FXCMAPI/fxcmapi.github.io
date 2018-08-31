-- Strategy profile initialization routine
-- Defines Strategy profile properties and Strategy parameters
-- TODO: Add minimal and maximal value of numeric parameters and default color of the streams
function Init()
    strategy:name("Fractal MA Pullback");
    strategy:description("Trades fractals when price pulls back to the MA");
    strategy:type(core.Both);
    strategy:setTag("NonOptimizableParameters", "SendEmail,PlaySound,Email,SoundFile,RecurrentSound,ShowAlert");

    strategy.parameters:addGroup("Price Parameters");
    strategy.parameters:addString("TF", "Time frame ('t1', 'm1', 'm5', etc.)", "", "m5");
    strategy.parameters:setFlag("TF", core.FLAG_PERIODS);
    strategy.parameters:addGroup("Parameters");
    strategy.parameters:addInteger("MVAPeriods", "MVA Periods", "Number of periods for the moving average.", 200);
    strategy.parameters:addDouble("StopOffset", "Stop Offset in Pips", "How far to set our stop from the fractal in pips.", 2.0);
    strategy.parameters:addDouble("LimitMultiplier", "Limit Multiplier", "StopDistance * Limit Multiplier = limit distance", 3.0);
    strategy.parameters:addBoolean("UseOffset", "Use Offset?", "true = use stoplossoffset and limit multiplier, false = use parameters options for stop limit.", true);

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
local MVAPeriods;
local StopOffset;
local LimitMultiplier;
local UseOffset;
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
local iMVA;
local MVAPeriods;
local StopOffset;
local LimitMultiplier;
local UseOffset;

-- Routine
function Prepare(nameOnly)
    MVAPeriods = instance.parameters.MVAPeriods;
    StopOffset = instance.parameters.StopOffset;
    LimitMultiplier = instance.parameters.LimitMultiplier;
    UseOffset = instance.parameters.UseOffset;

    local name = profile:id() .. "(" .. instance.bid:instrument() .. ", " .. tostring(MVAPeriods) .. ", " .. tostring(StopOffset) .. ", " .. tostring(LimitMultiplier) .. ", " .. tostring(UseOffset) .. ")";
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
    iMVA = core.indicators:create("MVA", gSource.close, MVAPeriods);
end

-- strategy calculation routine
-- TODO: Add your code for decision making
-- TODO: Update the instance of your indicator(s) if needed
function ExtUpdate(id, source, period)

    -- update indicator values
    iMVA:update(core.UpdateLast)
    
    
    
    -- BUY LOGIC
    -- if 3rd candle low needs to be below MA of the 3rd candle and 5th candle low needs to be above MA of the 5th candle and last candle low 
    -- needs to above MA of the last candle and 3rd candle low is below 5th candle low and 4th candle low and the 2nd candle low and the last 
    -- candle low
    if gSource.low[period-2] < iMVA.DATA[period-2] and gSource.low[period-4] > iMVA.DATA[period-4] and gSource.low[period] > iMVA.DATA[period] and
        gSource.low[period-2] < gSource.low[period-4] and
        gSource.low[period-2] < gSource.low[period-3] and
        gSource.low[period-2] < gSource.low[period-1] and
        gSource.low[period-2] < gSource.low[period] then
        
        -- BUY SIGNAL
        stopdistanceinpips = (instance.bid[NOW] - gSource.low[period-2]) / instance.bid:pipSize() + StopOffset
        limitdistanceinpips = stopdistanceinpips * LimitMultiplier
        enter("B", stopdistanceinpips, limitdistanceinpips)
    
    end
    
    
    -- SELL LOGIC
    -- if 3rd candle high needs to be above MA of the 3rd candle and 5th candle high needs to be below MA of the 5th candle and last candle high 
    -- needs to below MA of the last candle and 3rd candle high is above 5th candle high and 4th candle high and the 2nd candle high and the last 
    -- candle high
    if gSource.high[period-2] > iMVA.DATA[period-2] and gSource.high[period-4] < iMVA.DATA[period-4] and gSource.high[period] < iMVA.DATA[period] and
        gSource.high[period-2] > gSource.high[period-4] and
        gSource.high[period-2] > gSource.high[period-3] and
        gSource.high[period-2] > gSource.high[period-1] and
        gSource.high[period-2] > gSource.high[period] then
        
        -- SELL SIGNAL
        stopdistanceinpips = (gSource.high[period-2] - instance.bid[NOW]) / instance.bid:pipSize() + StopOffset
        limitdistanceinpips = stopdistanceinpips * LimitMultiplier
        enter("S", stopdistanceinpips, limitdistanceinpips)
    
    end



end



-- open positions in direction BuySell
function enter(BuySell, stopdistance, limitdistance)

    local valuemap, success, msg;
    valuemap = core.valuemap();

    valuemap.OrderType = "OM";
    valuemap.OfferID = Offer;
    valuemap.AcctID = Account;
    valuemap.Quantity = Amount * BaseSize;
    valuemap.BuySell = BuySell;
    valuemap.GTC = "GTC";

    -- if using the offset
    if UseOffset then

        -- set limit order
        valuemap.PegTypeLimit = "O";
        if BuySell == "B" then
           valuemap.PegPriceOffsetPipsLimit = limitdistance;
        else
           valuemap.PegPriceOffsetPipsLimit = -limitdistance;
        end

        -- set stop order
        valuemap.PegTypeStop = "O";
        if BuySell == "B" then
           valuemap.PegPriceOffsetPipsStop = -stopdistance;
        else
           valuemap.PegPriceOffsetPipsStop = stopdistance;
        end
        
        if TrailingStop then
            valuemap.TrailStepStop = 1;
        end

        if (not CanClose) and (StopLoss > 0 or TakeProfit > 0) then
            valuemap.EntryLimitStop = "Y"
        end
    
    -- if not using the offset
    else
    
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
        
    end
    
    
    success, msg = terminal:execute(100, valuemap);

    if not(success) then
        terminal:alertMessage(instance.bid:instrument(), instance.bid[instance.bid:size() - 1], "open order failure: " .. msg, instance.bid:date(instance.bid:size() - 1));
        return false;
    end

    return true;
end


dofile(core.app_path() .. "\\strategies\\standard\\include\\helper.lua");
