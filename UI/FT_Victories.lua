
include("InstanceManager");
--include("CivilizationIcon");
--include("WorldRankings");

--print("ffffff", g_GenericIM)

local m_EcoViewInstanceManager = InstanceManager:new("EconomicVictoryInstance", "ButtonBG")

local EcoViewStack = nil
EcoViewStack = Controls.EcoViewStack
local GenericViewScrollPanel = nil
local m_EcoItems = {}

local m_iCurrentPlayerID = Game.GetLocalPlayer()
local m_pCurrentPlayer = Players[m_iCurrentPlayerID]
local m_pLocalPlayerConfig = PlayerConfigurations[m_iCurrentPlayerID]


function EcoViewStack_SortFunction(a, b)
    local itemA = m_EcoItems[tostring(a.Controls)]
    local itemB = m_EcoItems[tostring(b.Controls)]
    if itemA == nil then return false; end
    if itemB == nil then return true; end
    return itemA.GeneralIncome > itemB.GeneralIncome
end



local EcoItem = {}

function EcoItem:New()
    local t = {
        PlayerId = -1,
        Controls = nil,
        GeneralIncome = 0,
        CivIcon = nil
    }
    setmetatable(t, self)
    self.__index = self
    
    return t
end

function EcoItem:UpdateIncome(bIncrease)
    if bIncrease then
        local treasury = Players[self.PlayerId]:GetTreasury()
        local iGoldYield = treasury:GetGoldYield()
        self.GeneralIncome = math.floor(self.GeneralIncome + iGoldYield)
    end
    self.Controls.IncomeLabel:SetText(tostring(self.GeneralIncome))
    self.Controls.LocalPlayer:SetHide(self.PlayerId ~= m_iCurrentPlayerID)
    --self.CivIcon:UpdateIconFromPlayerID(self.PlayerId)
    
    if m_iCurrentPlayerID == self.PlayerId 
    or m_pCurrentPlayer:GetDiplomacy():HasMet(self.PlayerId) then
        self:UpdateIcon()
        self.Controls.CivName:SetHide(false)
        self.Controls.CivNameUnknow:SetHide(true)
        self.Controls.CivIcon:SetHide(false)
        self.Controls.CivIconUnknow:SetHide(true)
    else
        self.Controls.CivName:SetHide(true)
        self.Controls.CivNameUnknow:SetHide(false)
        self.Controls.CivIcon:SetHide(true)
        self.Controls.CivIconUnknow:SetHide(false)
    end
end

function EcoItem:UpdateIcon()
    local playerConfig = PlayerConfigurations[self.PlayerId]
    local civIcon = "ICON_" .. playerConfig:GetCivilizationTypeName()
    local backColor, frontColor = UI.GetPlayerColors(self.PlayerId)
    
    self.Controls.CivIcon:SetColor(frontColor)
    self.Controls.CivIconBackground:SetColor(backColor)
    
	local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(civIcon, self.Controls.CivIcon:GetSizeX());
    if(textureSheet == nil or textureSheet == "") then
		print("Could not find icon in CivilizationIcon.UpdateIcon: icon=\""..civIcon.."\", iconSize="..tostring(self.Controls.CivIcon:GetSizeX()));
	else
		self.Controls.CivIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
	end
	
	--print("EcoItem:SetIcon", civIcon, textureSheet)
end



function SetupVictoryScreen()
--    if EcoViewStack == nil then
--        EcoViewStack = ContextPtr:LookUpControl("/InGame/PartialScreens/WorldRankings/GenericViewStack")
--    end
    
    --EcoViewStack:DestroyAllChildren()
    m_EcoItems = {}
    
    for _, playerID in ipairs(PlayerManager.GetAliveMajorIDs()) do
        local ecoView = m_EcoViewInstanceManager:GetInstance(EcoViewStack)
        --local civIcon = CivilizationIcon:AttachInstance(ecoView.CivilizationIcon)
        local playerConfig = PlayerConfigurations[playerID]
        local civText = playerConfig:GetCivilizationShortDescription()
        ecoView.CivName:LocalizeAndSetText(civText)
        ecoView.CivNameUnknow:LocalizeAndSetText("LOC_DIPLOPANEL_UNMET_PLAYER")
        --civIcon:UpdateIconFromPlayerID(playerID)
        
        local item = EcoItem:New()
        item.PlayerId = playerID
        item.Controls = ecoView
        --item.CivIcon = civIcon
        m_EcoItems[tostring(ecoView)] = item
    end
end

function UpdateEconomicItems(bIncrease)
    for key,item in pairs(m_EcoItems) do
        item:UpdateIncome(bIncrease)
    end
    EcoViewStack:SortChildren(EcoViewStack_SortFunction)
end


function SaveFTVictoryData()
    local data = {}
    for key,item in pairs(m_EcoItems) do
        data[item.PlayerId] = item.GeneralIncome
    end
    
    ExposedMembers.FT.SaveFTVictoryData(data)
end

function LoadFTVictoryData()

    local data = ExposedMembers.FT.FetchFTVictoryData()
    if data ~= nil then
        for key,item in pairs(m_EcoItems) do
            local income = data[item.PlayerId]
            if income ~= nil then
                item.GeneralIncome = income
            end
        end
    end
    
end

------------------------

function InitHandler(isReload)
    if isReload then
        OnLoadGameViewStateDone()
    end
    
    LoadFTVictoryData()
    UpdateEconomicItems(false)
end

function ShutdownHandler()
    for key,item in pairs(m_EcoItems) do
        m_EcoViewInstanceManager:ReleaseInstance(item.Controls)
    end
end

function OnLoadGameViewStateDone()
    local originalStack = ContextPtr:LookUpControl("/InGame/PartialScreens/WorldRankings/GenericViewStack")
    originalStack:SetHide(true)
    
    GenericViewScrollPanel = ContextPtr:LookUpControl("/InGame/PartialScreens/WorldRankings/GenericViewScrollbar")
    EcoViewStack:ChangeParent(GenericViewScrollPanel)
    
    SetupVictoryScreen()
    LoadFTVictoryData()
end

function OnLocalPlayerTurnChanged()
    UpdateEconomicItems(true)
end

function OnWorldRankingOpen()
    
    EcoViewStack:SortChildren(EcoViewStack_SortFunction)
    UpdateEconomicItems(false)
    
    -- test --
--    print('EcoViewStack:GetChildren', EcoViewStack:GetChildren()[1])
--    EcoViewStack:GetChildren()[2]:GetChildren()[2]:SetText(tostring(Game.GetCurrentGameTurn()))
end


function OnSaveComplete()
    SaveFTVictoryData()
end

function Init()
    ContextPtr:SetInitHandler(InitHandler)
    ContextPtr:SetShutdown(ShutdownHandler)
    
    Events.LoadGameViewStateDone.Add(OnLoadGameViewStateDone)
    Events.LocalPlayerTurnEnd.Add(OnLocalPlayerTurnChanged)
    Events.SaveComplete.Add(OnSaveComplete)
    
    LuaEvents.PartialScreenHooks_OpenWorldRankings.Add(OnWorldRankingOpen)
end

Init()