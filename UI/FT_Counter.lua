--------------------------------------------------------------
--------------------------------------------------------------
--  ______ _                        _       _ 
--  |  ___(_)                      (_)     | |
--  | |_   _ _ __   __ _ _ __   ___ _  __ _| |
--  |  _| | | '_ \ / _` | '_ \ / __| |/ _` | |
--  | |   | | | | | (_| | | | | (__| | (_| | |
--  \_|   |_|_| |_|\__,_|_| |_|\___|_|\__,_|_|
--   _____                                    
--  |_   _|                                   
--    | |_   _  ___ ___   ___  _ __  ___      
--    | | | | |/ __/ _ \ / _ \| '_ \/ __|     
--    | | |_| | (_| (_) | (_) | | | \__ \     
--    \_/\__, |\___\___/ \___/|_| |_|___/     
--        __/ |                               
--       |___/                                
--------------------------------------------------------------
------------------ Coded by Hemmelfort -----------------------
--------------------------------------------------------------
--    __  __                              ______           __ 
--   / / / /__  ____ ___  ____ ___  ___  / / __/___  _____/ /_
--  / /_/ / _ \/ __ `__ \/ __ `__ \/ _ \/ / /_/ __ \/ ___/ __/
-- / __  /  __/ / / / / / / / / / /  __/ / __/ /_/ / /  / /_  
--/_/ /_/\___/_/ /_/ /_/_/ /_/ /_/\___/_/_/  \____/_/   \__/  
--------------------------------------------------------------

local DEBUG_MODE = false

function IsDebugMode()
    return DEBUG_MODE == true
end

--------------------------------------------------------------

include("InstanceManager");

local m_LaunchItemInstanceManager = InstanceManager:new("LaunchBarItem", "LaunchItemButton")
local m_LaunchBarPinInstanceManager = InstanceManager:new("LaunchBarPinInstance", "Pin")
local m_LoanInstanceManager = InstanceManager:new("LoanInstance", "Root", Controls.LoanInstanceStack)

local EntryButtonInstance = nil
local LaunchBarPinInstance = nil

local RELOAD_CACHE_ID = "ft_ui"

local m_iSliderSteps = 9    --> Slider步数
local m_kLoanItems = {}

local m_iCurrentPlayerID = Game.GetLocalPlayer()
local m_pCurrentPlayer = Players[m_iCurrentPlayerID]

------------ 利率表 ------------
local m_kRateTable = nil
if IsDebugMode() then
    m_kRateTable = {    ---->仅用于调试
        {Turns=1, Rate=0.5},
        {Turns=2, Rate=1},
        {Turns=5, Rate=5},
    }
else
    m_kRateTable = {    ---->贷款回合数及其利率请在下表修改
        {Turns=10, Rate=0.05},
        {Turns=20, Rate=0.15},
        {Turns=30, Rate=0.3},
        {Turns=50, Rate=0.5},
        {Turns=100, Rate=1},
    }
end

function UpdateRateTable()
    for _,v in ipairs(m_kRateTable) do
        v.Text = string.format("[ICON_Turn]%dT (%d%%)", v.Turns, v.Rate*100)
    end
    table.sort(m_kRateTable, function (a,b) return a.Turns < b.Turns end)
end


-- 免费贷款的四个按钮的数值
local m_kFreeLoanOptions = {
    [1] = 100,
    [2] = 500,
    [3] = 1000,
    [4] = 5000
}

-- 各个时代的贷款额度
local m_kLoanQuotas = {
    [1] = 1000,     --远古
    [2] = 1200,     --古典
    [3] = 1500,     --中世纪
    [4] = 2000,     --文艺复兴
    [5] = 2600,     --工业
    [6] = 3200,     --现代
    [7] = 4000,     --原子能
    [8] = 5000,     --信息
}

-- 各个时代免费贷款的额度
local m_kFreeLoanQuotas  = {
    [1] = 1000,     --远古
    [2] = 1500,     --古典
    [3] = 2000,     --中世纪
    [4] = 2500,     --文艺复兴
    [5] = 3000,     --工业
    [6] = 3500,     --现代
    [7] = 4000,     --原子能
    [8] = 5000,     --信息
}



-- ==============================================
-- 计算利息
-- iAmount: 本金
-- iTurnsPast: 已贷回合数
-- ==============================================
function CaculateInterest(iAmount, iTurnsPast)
    --根据贷款金额及时长计算利息。
    --先找到大于iTurnsPast的最小回合数。比如35对应50，51对应100
    --否则就按最高档计息
    local iRate = m_kRateTable[#m_kRateTable].Rate
    for _,entry in ipairs(m_kRateTable) do
        if iTurnsPast <= entry.Turns then
            iRate = entry.Rate
            break
        end
    end
    return math.floor( iAmount * iRate )
end




-- ==============================================
-- 其他玩家获益
-- ==============================================
local OtherPlayers = {}

OtherPlayers.Share = function(iNumber)
    --这些钱给一群ai平分
    local counts = PlayerManager.GetAliveMajorsCount() - 1
    if counts > 0 then
        OtherPlayers.GainEach(iNumber / counts)
    end
end

OtherPlayers.GainEach = function(iNumber)
    --每个ai都能得到这么多钱
    local kPlayers = PlayerManager.GetAliveMajors()
    for _,pPlayer in ipairs(kPlayers) do
        local iPlayerID = pPlayer:GetID()
        if iPlayerID ~= m_iCurrentPlayerID then
            ExposedMembers.FT.ChangeGoldBalance(iPlayerID, iNumber)
        end
    end
end


----------------------------------------------------------
--        ___   ________________  __  ___   ________    --
--       /   | / ____/ ____/ __ \/ / / / | / /_  __/    --
--      / /| |/ /   / /   / / / / / / /  |/ / / /       --
--     / ___ / /___/ /___/ /_/ / /_/ / /|  / / /        --
--    /_/  |_\____/\____/\____/\____/_/ |_/ /_/         --
----------------------------------------------------------

local m_iUpperLimit = 1000          -->默认贷款额度
local m_iLoanedBalance = 0          -->玩家已借数额
local m_iFreeLoanUpperLimit = 1000
local m_iFreeLoanedBalance = 0

local Account = {
    
    UpdateUpperLimits = function(newEra)
        --local currentEra = newEra or (Game.GetEras():GetCurrentEra() + 1)
        local currentEra = Game.GetEras():GetCurrentEra() + 1
        m_iUpperLimit = m_kLoanQuotas[currentEra] or m_iUpperLimit
        m_iFreeLoanUpperLimit = m_kFreeLoanQuotas[currentEra] or m_iFreeLoanUpperLimit
    end,
    
    ChangeGoldBalance = function(iNumber)
        --本来这里不用获取iGold，但官方的改金币的方法有点延迟
        --以致于界面刷新完了，钱还没到账
        local iGold = m_pCurrentPlayer:GetTreasury():GetGoldBalance()
        RefreshPayableState(iGold + iNumber)
        ExposedMembers.FT.ChangeGoldBalance(m_iCurrentPlayerID, iNumber)
    end,
    
    GetGoldBalance = function()
        local iGold = m_pCurrentPlayer:GetTreasury():GetGoldBalance()
        return iGold
    end,
    
    GetGoldPerTurn = function()
        local treasury = m_pCurrentPlayer:GetTreasury()
        local iGoldYield = treasury:GetGoldYield()
        local iMaintenance = treasury:GetTotalMaintenance()
        return iGoldYield - iMaintenance
    end,
    
    CanLoanMore = function()
        return m_iLoanedBalance < m_iUpperLimit
    end,
    
    AvailableLoanedAmount = function()
        return m_iUpperLimit - m_iLoanedBalance
    end,
}

Account.Loan = function(iNumber)
    m_iLoanedBalance = m_iLoanedBalance + iNumber
    Account.ChangeGoldBalance(iNumber)
end

Account.Pay = function(iNumber, iInterest)
    m_iLoanedBalance = m_iLoanedBalance - iNumber
    if m_iLoanedBalance < 0 then
        m_iLoanedBalance = 0
    end
    local debt = iNumber + iInterest
    Account.ChangeGoldBalance(-debt)
    OtherPlayers.Share(debt)
end

Account.PayOverdue = function(iNumber)
    --逾期还款不更新贷款额度，要等下个时代再更新
    Account.ChangeGoldBalance(- iNumber)
    OtherPlayers.Share(iNumber)
end

Account.FreeLoan = function(iNumber)
    if iNumber > 0 then
        m_iFreeLoanedBalance = m_iFreeLoanedBalance + iNumber
    end
    Account.ChangeGoldBalance(iNumber)
    OtherPlayers.GainEach(iNumber + iNumber)
    
    return iNumber + iNumber
end





--------------------------------------------------------
--      _______              _______
--     /\:::::/\            /\:::::/\
--    /  \:::/  \          /==\:::/::\
--   /    \_/    \   .--. /====\_/::::\
--  /_____/ \_____\-' .-.`-----' \_____\
--  \:::::\_/:::::/-. `-'.-----._/:::::/
--   \::::/ \::::/   `--' \::::/:\::::/
--    \::/   \::/          \::/:::\::/ 
--     \/     \/            \/:::::\/ 
--      """""""              """""""
--------------------------------------------------------------
local LoanItem = {}

function LoanItem:New()
    local t = {
        ui = nil,
        Arrears = 0,
    }
    setmetatable(t, self)
    self.__index = self
    t:Init()
    return t
end

------------ ui初始化 ------------
function LoanItem:Init()
    local ui = m_LoanInstanceManager:GetInstance()
    
    ui.AmountSlider:RegisterSliderCallback(function()
        self:UpdateSlider()
    end)
    ui.LoanButton:RegisterCallback(Mouse.eLClick, function()
        self:Loan()
    end)
    ui.PayButton:RegisterCallback(Mouse.eLClick, function()
        self:Pay()
    end)
    ui.PullDown:SetEntrySelectedCallback(function (entry)
        local iInterest, iAmount = self:GetFullInterest()
        local iPayAmount = iAmount + iInterest
        local iPayPerTurn = math.floor(iPayAmount / entry.Turns)
        local tooltip = Locale.Lookup("LOC_LOAN_PAYABLE_LABEL", iPayAmount, iPayPerTurn)
        ui.InterestLabel:SetText(tostring(iInterest))
        ui.InterestLabel:SetToolTipString(tooltip)
        ui.TurnsRemain:SetText(tostring(entry.Turns))
    end)
    
    ui.LoanButton:SetHide(false)
    ui.PayButton:SetEnabled(false)
    ui.PullDown:SetEnabled(true)
    ui.PullDown:SetEntries(m_kRateTable, 1)
    ui.TurnsRemain:SetText(tostring(m_kRateTable[1].Turns))
    ui.AmountSlider:SetEnabled(true)
    ui.AmountSlider:SetHide(false)
    ui.AmountSlider:SetNumSteps(m_iSliderSteps)
    ui.AmountSlider:SetStep(m_iSliderSteps)
    ui.ArrearLabel:SetHide(true)
    
    self.ui = ui
    self.Arrears = 0
    self:UpdateSlider()
    
end
------------ 用户拖动滑块 ------------
function LoanItem:UpdateSlider()
    local stepNum = self.ui.AmountSlider:GetStep() + 1
    local iAvailableAmount = Account.AvailableLoanedAmount()
    local iAmount = stepNum * iAvailableAmount / (m_iSliderSteps+1)
    local entry = self.ui.PullDown:GetSelectedEntry()
    local iInterest = CaculateInterest(iAmount, entry.Turns)
    local iPayAmount = iAmount + iInterest
    local iPayPerTurn = math.floor(iPayAmount / entry.Turns)
    local tooltip = Locale.Lookup("LOC_LOAN_PAYABLE_LABEL", iPayAmount, iPayPerTurn)
    self.ui.NumberDisplay:SetText(tostring(math.floor(iAmount)))
    self.ui.InterestLabel:SetText(tostring(iInterest))
    self.ui.InterestLabel:SetToolTipString(tooltip)
end

------------ 更新控件的状态 ------------
function LoanItem:RefreshPayableState(spareGold)
    --如果客户只是看看，还没开始借，就返回false
    if self.ui.LoanButton:IsVisible() then
        return false
    end
    
    local necessaryGold = nil
    if self.Arrears > 0 then
        necessaryGold = self.Arrears
    else
        local iInterest = tonumber(self.ui.InterestLabel:GetText())
        local iAmount = tonumber(self.ui.NumberDisplay:GetText())
        necessaryGold = iAmount + iInterest
    end
    
    local iGold = spareGold or Account.GetGoldBalance()
    if (iGold >= necessaryGold) then
        self.ui.PayButton:SetEnabled(true)
        self.ui.PayButton:LocalizeAndSetToolTip("LOC_LOAN_EARLY_REPAYMENT_TOOLTIP")
        return true
    else
        self.ui.PayButton:SetEnabled(false)
        self.ui.PayButton:LocalizeAndSetToolTip("LOC_FT_ACCOUNT_CANNOT_AFFORD")
        return false
    end
end


------------ 当新回合开始时更新 ------------
function LoanItem:OnNewTurn()
    local isPayable = self:RefreshPayableState()
    
    local turns = tonumber(self.ui.TurnsRemain:GetText())
    if turns == nil then
        turns = 0
    elseif turns > 0 then
        --正常倒计时
    elseif turns == 0 and isPayable then
        self:Pay()
    else
        --用户没钱还款，就用回合金偿还，每回合持续扣款
        --先记录欠款
        if turns == 0 then
            local iInterest, iAmount = self:GetFullInterest()
            self.Arrears = iAmount + iInterest
        end
        self:PayOverdue()
    end
    
    self.ui.TurnsRemain:SetText(tostring(turns - 1))
end



------------ 计算利息（如果现在还款） ------------
function LoanItem:GetCurrentInterest()
    local iTurnsRemain = tonumber(self.ui.TurnsRemain:GetText())
    if iTurnsRemain < 0 then
        iTurnsRemain = 0
    end
    
    local iAmount = tonumber(self.ui.NumberDisplay:GetText())
    local entry = self.ui.PullDown:GetSelectedEntry()
    local iTurnsPast = entry.Turns - iTurnsRemain
    local iInterest = CaculateInterest(iAmount, iTurnsPast)
    return iInterest, iAmount
end
------------ 计算利息（如果到期再还） ------------
function LoanItem:GetFullInterest()
    local iAmount = tonumber(self.ui.NumberDisplay:GetText())
    local entry = self.ui.PullDown:GetSelectedEntry()
    local iInterest = CaculateInterest(iAmount, entry.Turns)
    return iInterest, iAmount
end

------------ 用户开始贷款 ------------
function LoanItem:Loan()
    local iAmount = tonumber(self.ui.NumberDisplay:GetText())
    local entry = self.ui.PullDown:GetSelectedEntry()
    self.ui.TurnsRemain:SetText(tostring(entry.Turns))
    self.ui.LoanButton:SetHide(true)
    self.ui.PullDown:SetEnabled(false)
    self.ui.AmountSlider:SetEnabled(false)
    self.ui.AmountSlider:SetHide(true)
    --self:RefreshPayableState()

    OnPlayerLoaned(iAmount)
end



------------ 用户还款 ------------
function LoanItem:Pay()
    if self.Arrears > 0 then
        self:PayOverdue()
        return
    end
    
    local iInterest, iAmount = self:GetCurrentInterest()
    OnPlayerPayed(iAmount, iInterest)
    RemoveLoanItem(self)
end
------------ 用户没钱，就用回合金偿还 ------------
function LoanItem:PayOverdue()
    --如果有现金就先扣
    if self.Arrears > 0 then
        local iGold = Account.GetGoldBalance()
        if iGold > 0 then
            if iGold >= self.Arrears then
                Account.PayOverdue(self.Arrears)
                self.Arrears = 0
            else
                Account.PayOverdue(iGold)
                self.Arrears = self.Arrears - iGold
            end
        end
    end
    
    --扣完现金扣回合金
    if self.Arrears > 0 then
        local iGoldPerTurn = Account.GetGoldPerTurn()
        Account.PayOverdue(iGoldPerTurn)
        self.Arrears = self.Arrears - iGoldPerTurn
    end
    
    --全扣了还是还不上，打上标签，下回合继续扣
    if self.Arrears > 0 then        
        self.ui.ArrearLabel:SetHide(false)
        self.ui.ArrearLabel:LocalizeAndSetText("LOC_LOAN_ARREAR", 
            tostring(math.floor(self.Arrears)))
    else
        RemoveLoanItem(self)
    end
    
end


------------ 序列化与反序列化 ------------
function LoanItem:Serialize()
    local tab = {
        Arrears = self.Arrears,
        Amount = tonumber(self.ui.NumberDisplay:GetText()),
        TurnsRemain = tonumber(self.ui.TurnsRemain:GetText()),
        RateIndex = self.ui.PullDown:GetSelectedIndex()
    }
    return tab
end
function LoanItem:Deserialize(tab)
    self.Arrears = tab.Arrears
    self.ui.NumberDisplay:SetText(tostring(tab.Amount))
    self.ui.PullDown:SetSelectedIndex(tab.RateIndex, false)
    self.ui.PullDown:SetEnabled(false)
    self.ui.TurnsRemain:SetText(tostring(tab.TurnsRemain))
    self.ui.LoanButton:SetHide(true)
    self.ui.AmountSlider:SetEnabled(false)
    self.ui.AmountSlider:SetHide(true)

    local entry = self.ui.PullDown:GetSelectedEntry()
    local iInterest, iAmount = self:GetFullInterest()
    local iPayAmount = iAmount + iInterest
    local iPayPerTurn = math.floor(iPayAmount / entry.Turns)
    local tooltip = Locale.Lookup("LOC_LOAN_PAYABLE_LABEL", iPayAmount, iPayPerTurn)
    self.ui.InterestLabel:SetText(tostring(iInterest))
    self.ui.InterestLabel:SetToolTipString(tooltip)
    
    if self.Arrears > 0 then        
        self.ui.ArrearLabel:SetHide(false)
        self.ui.ArrearLabel:LocalizeAndSetText("LOC_LOAN_ARREAR", 
            tostring(math.floor(self.Arrears)))
    end
    
    self:RefreshPayableState()
end





------------------------------------------------------------
--                  |                 
--                  |                 
--                -/_\-   
--   ____________(/ o \)_____________  
--   <>           \___/      <>    <> 
--      ||   
--      <>   
--                            ||  
--                            <>       
------------------------------------------------------------



------------ 添加一笔贷款 ------------
function AddNewLoanItem()
    local item = LoanItem:New()
    table.insert(m_kLoanItems, item)
    Controls.NewLoanButton:SetEnabled(false)
    return item
end
------------ 移除一笔贷款（并非还款） ------------
function RemoveLoanItem(item)
    for index,value in ipairs(m_kLoanItems) do
        if value == item then
            RemoveLoanItemByIndex(index)
            break
        end
    end
end
function RemoveLoanItemByIndex(index)
    local item = m_kLoanItems[index]
    table.remove(m_kLoanItems, index)
    m_LoanInstanceManager:ReleaseInstance(item.ui)
    
    --更新已借金额
    m_iLoanedBalance = 0
    for index,value in ipairs(m_kLoanItems) do
        local _,iAmount = value:GetFullInterest()
        m_iLoanedBalance = m_iLoanedBalance + iAmount
    end
    UpdateControlsState()
end


------------ 每回合更新剩余还款期限 ------------
function UpdateLoanedTurns()
    for i,item in ipairs(m_kLoanItems) do
        item:OnNewTurn()
    end
end


------------ 在Gameplay那边从Property里面读取数据 ------------
function FetchDataFromGameplay()
    local data = ExposedMembers.FT.FetchFTData()
    --local data = ExposedMembers.FT.FetchSimulateData()
    if data == nil then
        return
    end
    
    m_iLoanedBalance = 0
    m_iFreeLoanedBalance = data.FreeLoanedBalance
    
    for _,tab in ipairs(data.LoansData) do
        local item = AddNewLoanItem()
        item:Deserialize(tab)
        m_iLoanedBalance = m_iLoanedBalance + tab.Amount
    end
    
    UpdateControlsState()
end

function SaveDataToGameplay()
    local loansData = {}
    for _,item in ipairs(m_kLoanItems) do
        table.insert(loansData, item:Serialize())
    end
    
    local data = {
        LoansData = loansData,
        FreeLoanedBalance = m_iFreeLoanedBalance
    }
    ExposedMembers.FT.SaveFTData(data)
end




function OnPlayerLoaned(iNumber)
    Account.Loan(iNumber)
    UpdateControlsState()
    UI.PlaySound("Purchase_With_Gold")
end

function OnPlayerPayed(iNumber, iInterest)
    Account.Pay(iNumber, iInterest)
    UpdateControlsState()
    UI.PlaySound("Purchase_With_Gold")
end

function UpdateControlsState()
    local text = tostring(Account.AvailableLoanedAmount() .."/".. m_iUpperLimit)
    Controls.NewLoanButton:SetEnabled(Account.CanLoanMore())
    Controls.NoteLabel:LocalizeAndSetText("LOC_FT_WINDOW_NOTE", text)
    
    local iAvailableAmount = m_iFreeLoanUpperLimit - m_iFreeLoanedBalance
    Controls.FreeLoanButton1:SetEnabled(m_kFreeLoanOptions[1] <= iAvailableAmount)
    Controls.FreeLoanButton2:SetEnabled(m_kFreeLoanOptions[2] <= iAvailableAmount)
    Controls.FreeLoanButton3:SetEnabled(m_kFreeLoanOptions[3] <= iAvailableAmount)
    Controls.FreeLoanButton4:SetEnabled(m_kFreeLoanOptions[4] <= iAvailableAmount)
    Controls.FreeLoanAvailableAmount:SetText(text)
    Controls.FreeLoanAvailableAmount:LocalizeAndSetText("LOC_FT_WINDOW_NOTE",
        string.format("%d / %d", iAvailableAmount, m_iFreeLoanUpperLimit))
    
end

function SetDueAlertVisible(isVisible:boolean)
    EntryButtonInstance.AlertIndicator:SetHide(isVisible == false)
end



-- 刷新各个控件的还款按钮
-- spareGold: 玩家有多少钱可以还款（可以为nil）
function RefreshPayableState(spareGold)
    for i,item in ipairs(m_kLoanItems) do
        item:RefreshPayableState(spareGold)
    end
end


function OnNewLoanButtonCallback()
    AddNewLoanItem()
end

function OnFreeLoanButtonCallback(iNumber)
    if type(iNumber) ~= "number" then
        return
    end
    local windfall = Account.FreeLoan(iNumber)
    Controls.FreeLoanMsg:LocalizeAndSetText("LOC_FREE_LOAN_OTHER_PLAYERS_RECEIVE", windfall)
    --Controls.FreeLoanMsgAlpha:SetHide(false)
    Controls.FreeLoanMsgAlpha:SetToBeginning()
    Controls.FreeLoanMsgAlpha:Play()
    UpdateControlsState()
    UI.PlaySound("Purchase_With_Gold")
end


function SetupLaunchBarButton()
    local ctrl = ContextPtr:LookUpControl("/InGame/LaunchBar/ButtonStack")
    if ctrl == nil then
        --print("[Error]LaunchBar ButtonStack not found!!")
        return
    end
    
    if EntryButtonInstance == nil then
        EntryButtonInstance = m_LaunchItemInstanceManager:GetInstance(ctrl)
        LaunchBarPinInstance = m_LaunchBarPinInstanceManager:GetInstance(ctrl)
        EntryButtonInstance.LaunchItemButton:RegisterCallback(Mouse.eLClick, 
        function()
            ShowFTWindow()
        end)
    end
end

--没必要
--function SetupFTWindow()
--    local ctr = ContextPtr:LookUpControl("/InGame/Screens")
--    Controls.MainContainer:ChangeParent(ctr)
--    Controls.MainContainer:SetHide(false)
--end


-------- __@      __@       __@       __@      __~@
----- _`\<,_    _`\<,_    _`\<,_     _`\<,_    _`\<,_
---- (*)/ (*)  (*)/ (*)  (*)/ (*)  (*)/ (*)  (*)/ (*)


function HideFTWindow()
    --if Controls.MainContainer:IsVisible() then
    if not ContextPtr:IsHidden() then
        --UIManager:DequeuePopup(ContextPtr)
        --Controls.MainContainer:SetHide(true)
        ContextPtr:SetHide(true)
        UI.PlaySound("UI_Screen_Close")
        
        --移除那些没有提交的贷款项
        local t = {}
        for index,item in ipairs(m_kLoanItems) do
            if item.ui.LoanButton:IsVisible() then
                table.insert(t, index)
            end
        end
        table.sort(t, function(x,y) return x>y end)
        for _,index in ipairs(t) do
            RemoveLoanItemByIndex(index)
        end
    end
end

function ShowFTWindow()
    --UIManager:QueuePopup(ContextPtr, PopupPriority.Current)
    --Controls.MainContainer:SetHide(false)
    ContextPtr:SetHide(false)
    
    UpdateControlsState()
    UI.PlaySound("UI_Screen_Open")
end

function InputHandler(uiMsg, wParam, lParam)
    if (uiMsg == KeyEvents.KeyUp) then
        if (wParam == Keys.VK_ESCAPE) then
            if not ContextPtr:IsHidden() then
                HideFTWindow()
                return true
            end
        end
    end
    
    return false
end

function InitHandler(isReload:boolean)
    m_kLoanItems = {}
    Account.UpdateUpperLimits()
    SetupLaunchBarButton()
    
    if isReload then
        --LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID)
        ShowFTWindow()
        --Controls.TabControl:SelectTabByID("FreeLoan")
    else
        FetchDataFromGameplay()
    end
    
end

function ShutdownHandler()
    --LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_iUpperLimit", m_iUpperLimit)
    --LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "m_iLoanedBalance", m_iLoanedBalance)
    
    if EntryButtonInstance ~= nil then
        m_LaunchItemInstanceManager:ReleaseInstance(EntryButtonInstance)
    end
    if LaunchBarPinInstance ~= nil then
        m_LaunchBarPinInstanceManager:ReleaseInstance(LaunchBarPinInstance)
    end
end

function OnGameDebugReturn(context:string, contextTable:table)
    if context == RELOAD_CACHE_ID then
        if contextTable["m_iUpperLimit"] ~= nil then
            m_iUpperLimit = contextTable["m_iUpperLimit"]
        end
        if contextTable["m_iLoanedBalance"] ~= nil then
            m_iLoanedBalance = contextTable["m_iLoanedBalance"]
        end
    end
end

function OnPlayerEraChanged(iPlayerID, newEra)
    local currentTurn	:number = Game.GetCurrentGameTurn()
    local gameStartTurn	:number = GameConfiguration.GetStartTurn()
    if (iPlayerID ~= m_iCurrentPlayerID)
    or (gameStartTurn == currentTurn)
    then
        return
    end
    
    m_iFreeLoanedBalance = 0
    Account.UpdateUpperLimits(newEra)
    UpdateControlsState()
end

function OnLocalPlayerTurnChanged()
    --扣钱
    UpdateLoanedTurns()
end

function OnSaveComplete()
    SaveDataToGameplay()
end

function OnLoadGameViewStateDone()
    SetupLaunchBarButton()
    --SetupFTWindow()
end



function InitFTScreen()
    UpdateRateTable()
    
    ContextPtr:SetInputHandler(InputHandler)
    ContextPtr:SetInitHandler(InitHandler)
    ContextPtr:SetShutdown(ShutdownHandler)
    
    Controls.BackButton:RegisterCallback(Mouse.eLClick, HideFTWindow)
    Controls.CloseButton:RegisterCallback(Mouse.eLClick, HideFTWindow)
    Controls.NewLoanButton:RegisterCallback(Mouse.eLClick, OnNewLoanButtonCallback)
    
    Controls.FreeLoanButton1:SetText("[ICON_Gold]" .. tostring(m_kFreeLoanOptions[1]))
    Controls.FreeLoanButton2:SetText("[ICON_Gold]" .. tostring(m_kFreeLoanOptions[2]))
    Controls.FreeLoanButton3:SetText("[ICON_Gold]" .. tostring(m_kFreeLoanOptions[3]))
    Controls.FreeLoanButton4:SetText("[ICON_Gold]" .. tostring(m_kFreeLoanOptions[4]))
    Controls.FreeLoanButton1:RegisterCallback(Mouse.eLClick, function()
        OnFreeLoanButtonCallback(m_kFreeLoanOptions[1])
    end)
    Controls.FreeLoanButton2:RegisterCallback(Mouse.eLClick, function()
        OnFreeLoanButtonCallback(m_kFreeLoanOptions[2])
    end)
    Controls.FreeLoanButton3:RegisterCallback(Mouse.eLClick, function()
        OnFreeLoanButtonCallback(m_kFreeLoanOptions[3])
    end)
    Controls.FreeLoanButton4:RegisterCallback(Mouse.eLClick, function()
        OnFreeLoanButtonCallback(m_kFreeLoanOptions[4])
    end)
    UpdateControlsState()

    
    Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone)
    --Events.LocalPlayerTurnBegin.Add(OnLocalPlayerTurnChanged)
    Events.LocalPlayerTurnEnd.Add(OnLocalPlayerTurnChanged)
    Events.PlayerEraChanged.Add(OnPlayerEraChanged)
    Events.SaveComplete.Add(OnSaveComplete)
    
    --其他Popup出现时要隐藏窗口
    --LuaEvents.DiploScene_SceneOpened.Add(HideFTWindow)
    LuaEvents.DiplomacyActionView_HideIngameUI.Add(HideFTWindow)
    LuaEvents.EndGameMenu_Shown.Add(HideFTWindow)
    LuaEvents.FullscreenMap_Shown.Add(HideFTWindow)
    LuaEvents.NaturalWonderPopup_Shown.Add(HideFTWindow)
    LuaEvents.ProjectBuiltPopup_Shown.Add(HideFTWindow)
    LuaEvents.Tutorial_ToggleInGameOptionsMenu.Add(HideFTWindow)
    LuaEvents.WonderBuiltPopup_Shown.Add(HideFTWindow)
    LuaEvents.NaturalDisasterPopup_Shown.Add(HideFTWindow)  --标准模式可以吗?
    LuaEvents.RockBandMoviePopup_Shown.Add(HideFTWindow)
    
    --LuaEvents.GameDebug_Return.Add(OnGameDebugReturn)
    
    
    if IsDebugMode() then
        Controls.MsgLabel:SetHide(false)
        Controls.MsgLabel:SetText("DEBUG_MODE IS ON")
        
        Controls.TestButton1:SetHide(false)
        Controls.TestButton2:SetHide(false)
        Controls.TestButton3:SetHide(false)
        Controls.TestButton1:RegisterCallback(Mouse.eLClick, function()
            print("current upperlimit:", m_iUpperLimit, m_iLoanedBalance)
            m_iUpperLimit = m_iUpperLimit + 1000
            m_iFreeLoanUpperLimit = m_iFreeLoanUpperLimit + 1000
            UpdateControlsState()
        end)
        Controls.TestButton2:RegisterCallback(Mouse.eLClick, function()
            FetchDataFromGameplay()
            UI.PlaySound("WC_Open")
        end)
        Controls.TestButton3:RegisterCallback(Mouse.eLClick, function()
            SaveDataToGameplay()
            UI.PlaySound("WC_Exit")
        end)
    end

end


InitFTScreen()




