-- Strategy profile initialization routine
-- Defines Strategy profile properties and Strategy parameters
-- TODO: Add minimal and maximal value of numeric parameters and default color of the streams
function Init()
    strategy:name("3 EMA Pullback");
    strategy:description("Trades trends when price pulls back from significant high/low");
    strategy:type(core.Both);
    strategy:setTag("NonOptimizableParameters", "SendEmail,PlaySound,Email,SoundFile,RecurrentSound,ShowAlert");

    strategy.parameters:addGroup("Price Parameters");
    strategy.parameters:addString("TF", "Time frame ('t1', 'm1', 'm5', etc.)", "", "m15");
    strategy.parameters:setFlag("TF", core.FLAG_PERIODS);
    strategy.parameters:addGroup("Parameters");
    strategy.parameters:addInteger("FastEMA", "Fast EMA", "No description", 50);
    strategy.parameters:addInteger("MedEMA", "Medium EMA", "No description", 150);
    strategy.parameters:addInteger("SlowEMA", "Slow EMA", "No description", 250);
    strategy.parameters:addInteger("LookBack", "LookBack Periods", "No description", 100);

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

-- Routine
function Prepare(nameOnly)
    FastEMA = instance.parameters.FastEMA;
    MedEMA = instance.parameters.MedEMA;
    SlowEMA = instance.parameters.SlowEMA;
    LookBack = instance.parameters.LookBack;

    local name = profile:id() .. "(" .. instance.bid:instrument() .. ", " .. tostring(FastEMA) .. ", " .. tostring(MedEMA) .. ", " .. tostring(SlowEMA) .. ", " .. tostring(LookBack) .. ")";
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

    gSource = ExtSubscribe(1, nil, instance.parameters.TF, instance.parameters.Type == "Bid", "bar");
    tSource = ExtSubscribe(2, nil, "t1", instance.parameters.Type == "Bid", "bar");
    --TODO: Find indicator's profile, intialize parameters, and create indicator's instance (if needed)
    
    iEMAFast = core.indicators:create("EMA", gSource.close, FastEMA)
    iEMAMed = core.indicators:create("EMA", gSource.close, MedEMA)
    iEMASlow = core.indicators:create("EMA", gSource.close, SlowEMA)
end



local Status = "Neutral" -- possible values "Neutral", "Buy", "Sell"
-- strategy calculation routine
-- TODO: Add your code for decision making
-- TODO: Update the instance of your indicator(s) if needed
function ExtUpdate(id, source, period)

    -- update indicators
    iEMAFast:update(core.UpdateLast)
    iEMAMed:update(core.UpdateLast)
    iEMASlow:update(core.UpdateLast)
    
    -- PHASE 1
    -- close of bar, make sur ethe EMAs are lined up, and price is at a 100 bar high/low
    if id == 1 and Status == "Neutral" then
        
        --core.host:trace("Phase 1 Running...")
        -- create a range of candles
        local range = core.rangeTo(period-1, LookBack)

        -- find high and low
        local High, Highpos = mathex.max(gSource.high, range)
        local Low, Lowpos = mathex.min(gSource.low, range)
        
        --core.host:trace("High: " ..  tostring(High));
        --core.host:trace("Low: " ..  tostring(Low));
        
        -- BUY SETUP
        -- if price > Fast > Med > Slow AND close price is above 100 period high
        if gSource.close[period] > iEMAFast.DATA[period] and
            iEMAFast.DATA[period] > iEMAMed.DATA[period] and
            iEMAMed.DATA[period] > iEMASlow.DATA[period] and
            gSource.close[period] > High then
                -- move to next phase looking for Buys
                Status = "Buy"
                terminal:alertMessage(instance.bid:instrument(), instance.bid[NOW], "Looking for Buy Trigger...", instance.bid:date(NOW));
        end
        
        -- SELL SETUP
        -- if price < Fast < Med < Slow AND close price is below 100 period low
        if gSource.close[period] < iEMAFast.DATA[period] and
            iEMAFast.DATA[period] < iEMAMed.DATA[period] and
            iEMAMed.DATA[period] < iEMASlow.DATA[period] and
            gSource.close[period] < Low then
                -- move to next phase looking for Sells
                Status = "Sell"
                terminal:alertMessage(instance.bid:instrument(), instance.bid[NOW], "Looking for Sell Trigger...", instance.bid:date(NOW));
        end
    
    
    
    end
    
    
    
    -- PHASE 2
    -- every tick, see if price hits the 50 EMA, trigger trades
    if id == 2 and Status ~= "Neutral" then
        
        -- BUY Signal
        if Status == "Buy" then
            if instance.bid[NOW] <= iEMAFast.DATA[iEMAFast.DATA:size()-1] then
                -- BUY
                enter("B");
                Status = "Neutral"
            end       
        
        end
    
        
        
        -- SELL Signal
        if Status == "Sell" then
            if instance.bid[NOW] >= iEMAFast.DATA[iEMAFast.DATA:size()-1] then
                -- SELL
                enter("S")
                Status = "Neutral"
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





dofile(core.app_path() .. "\\strategies\\standard\\include\\helper.lua");
