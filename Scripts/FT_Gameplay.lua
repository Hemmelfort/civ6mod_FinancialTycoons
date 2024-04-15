
--  8888888888 d8b                                     d8b          888 
--  888        Y8P                                     Y8P          888 
--  888                                                             888 
--  8888888    888 88888b.   8888b.  88888b.   .d8888b 888  8888b.  888 
--  888        888 888 "88b     "88b 888 "88b d88P"    888     "88b 888 
--  888        888 888  888 .d888888 888  888 888      888 .d888888 888 
--  888        888 888  888 888  888 888  888 Y88b.    888 888  888 888 
--  888        888 888  888 "Y888888 888  888  "Y8888P 888 "Y888888 888 
--                                                                      
--    88888888888                                                         
--        888                                                             
--        888                                                             
--        888  888  888  .d8888b .d88b.   .d88b.  88888b.  .d8888b        
--        888  888  888 d88P"   d88""88b d88""88b 888 "88b 88K            
--        888  888  888 888     888  888 888  888 888  888 "Y8888b.       
--        888  Y88b 888 Y88b.   Y88..88P Y88..88P 888  888      X88       
--        888   "Y88888  "Y8888P "Y88P"   "Y88P"  888  888  88888P'       
--                  888                                                   
--             Y8b d88P                                                   
--              "Y88P"                                                    
--------------------------------------------------------------
------------------ Coded by Hemmelfort -----------------------
------------------------- 2023.08 ----------------------------
--------------------------------------------------------------
--    __  __                              ______           __ 
--   / / / /__  ____ ___  ____ ___  ___  / / __/___  _____/ /_
--  / /_/ / _ \/ __ `__ \/ __ `__ \/ _ \/ / /_/ __ \/ ___/ __/
-- / __  /  __/ / / / / / / / / / /  __/ / __/ /_/ / /  / /_  
--/_/ /_/\___/_/ /_/ /_/_/ /_/ /_/\___/_/_/  \____/_/   \__/  
--------------------------------------------------------------

local FT_LOAN_PROPERTY_ID = "FINACIAL_TYCOONS_LOAN"
local FT_VICTORY_PROPERTY_ID = "FINACIAL_TYCOONS_VICTORY"


function SaveFTData(data)
    Game:SetProperty(FT_LOAN_PROPERTY_ID, data)
end

function FetchFTData()
    return Game:GetProperty(FT_LOAN_PROPERTY_ID)
end

function FetchSimulateData()
    local loansData = {
        {
            Arrears = 0,
            Amount = 100,
            TurnsRemain = 5,
            RateIndex = 1
        },
        {
            Arrears = 200,
            Amount = 500,
            TurnsRemain = -3,
            RateIndex = 2
        }
    }
    local data = {
        LoansData = loansData,
        FreeLoanedBalance = 88
    }
    return data
end



-- ==============================================
-- 胜利模式
-- ==============================================

function SaveFTVictoryData(data)
    Game:SetProperty(FT_VICTORY_PROPERTY_ID, data)
end

function FetchFTVictoryData()
    return Game:GetProperty(FT_VICTORY_PROPERTY_ID)
end

-- ==============================================
-- 修改金币
-- ==============================================
function ChangeGoldBalance(iPlayerID, iAmount)
    local pPlayer = Players[iPlayerID]
    if pPlayer ~= nil then
        pPlayer:GetTreasury():ChangeGoldBalance(iAmount)
    end
end



-- ==============================================
-- 装载ExposedMembers
-- ==============================================
if ExposedMembers.FT == nil then
    ExposedMembers.FT = {}
end

ExposedMembers.FT.SaveFTData = SaveFTData
ExposedMembers.FT.FetchFTData = FetchFTData
ExposedMembers.FT.SaveFTVictoryData = SaveFTVictoryData
ExposedMembers.FT.FetchFTVictoryData = FetchFTVictoryData
ExposedMembers.FT.FetchSimulateData = FetchSimulateData
ExposedMembers.FT.ChangeGoldBalance = ChangeGoldBalance

