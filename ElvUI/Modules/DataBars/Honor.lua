local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local DB = E:GetModule('DataBars')

local _G = _G
local format = format
local UnitHonor = UnitHonor
local UnitHonorLevel = UnitHonorLevel
local UnitHonorMax = UnitHonorMax
local TogglePVPUI = TogglePVPUI
local HONOR = HONOR

local CurrentHonor, MaxHonor, CurrentLevel, PercentHonor, RemainingHonor

function DB:HonorBar_Update(event, unit)
	local bar = DB.StatusBars.Honor
	if not DB.db.honor.enable or (event == 'PLAYER_FLAGS_CHANGED' and unit ~= 'player') then
		bar:Hide()
		bar.holder:Hide()
		return
	else
		bar:Show()
		bar.holder:Show()
	end

	CurrentHonor, MaxHonor, CurrentLevel = UnitHonor('player'), UnitHonorMax('player'), UnitHonorLevel('player')

	--Guard against division by zero, which appears to be an issue when zoning in/out of dungeons
	if MaxHonor == 0 then MaxHonor = 1 end

	PercentHonor, RemainingHonor = (CurrentHonor / MaxHonor) * 100, MaxHonor - CurrentHonor

	local displayString, textFormat = '', DB.db.honor.textFormat
	local color = DB.db.colors.honor

	bar:SetMinMaxValues(0, MaxHonor)
	bar:SetValue(CurrentHonor)
	bar:SetStatusBarColor(color.r, color.g, color.b, color.a)

	if textFormat == 'PERCENT' then
		displayString = format('%d%%', PercentHonor)
	elseif textFormat == 'CURMAX' then
		displayString = format('%s - %s', E:ShortValue(CurrentHonor), E:ShortValue(MaxHonor))
	elseif textFormat == 'CURPERC' then
		displayString = format('%s - %d%%', E:ShortValue(CurrentHonor), PercentHonor)
	elseif textFormat == 'CUR' then
		displayString = format('%s', E:ShortValue(CurrentHonor))
	elseif textFormat == 'REM' then
		displayString = format('%s', E:ShortValue(RemainingHonor))
	elseif textFormat == 'CURREM' then
		displayString = format('%s - %s', E:ShortValue(CurrentHonor), E:ShortValue(RemainingHonor))
	elseif textFormat == 'CURPERCREM' then
		displayString = format('%s - %d%% (%s)', E:ShortValue(CurrentHonor), CurrentHonor, E:ShortValue(RemainingHonor))
	end

	bar.text:SetText(displayString)
end

function DB:HonorBar_OnEnter()
	if self.db.mouseover then
		E:UIFrameFadeIn(self, .4, self:GetAlpha(), 1)
	end

	if _G.GameTooltip:IsForbidden() then return end

	_G.GameTooltip:ClearLines()
	_G.GameTooltip:SetOwner(self, 'ANCHOR_CURSOR')

	_G.GameTooltip:AddLine(HONOR)

	_G.GameTooltip:AddDoubleLine(L["Current Level:"], CurrentLevel, 1, 1, 1)
	_G.GameTooltip:AddLine(' ')

	_G.GameTooltip:AddDoubleLine(L["Honor XP:"], format(' %d / %d (%d%%)', CurrentHonor, MaxHonor, PercentHonor), 1, 1, 1)
	_G.GameTooltip:AddDoubleLine(L["Honor Remaining:"], format(' %d (%d%% - %d '..L["Bars"]..')', RemainingHonor, (RemainingHonor) / MaxHonor * 100, 20 * (RemainingHonor) / MaxHonor), 1, 1, 1)

	_G.GameTooltip:Show()
end

function DB:HonorBar_OnClick()
	TogglePVPUI()
end

function DB:HonorBar_Toggle()
	local bar = DB.StatusBars.Honor
	bar.db = DB.db.honor

	bar.holder:SetShown(bar.db.enable)

	if bar.db.enable then
		E:EnableMover(bar.holder.mover:GetName())

		DB:RegisterEvent('HONOR_XP_UPDATE', 'HonorBar_Update')
		DB:RegisterEvent('PLAYER_FLAGS_CHANGED', 'HonorBar_Update')

		DB:HonorBar_Update()
	else
		E:DisableMover(bar.holder.mover:GetName())

		DB:UnregisterEvent('HONOR_XP_UPDATE')
		DB:UnregisterEvent('PLAYER_FLAGS_CHANGED')
	end
end

function DB:HonorBar()
	local Honor = DB:CreateBar('ElvUI_HonorBar', 'Honor', DB.HonorBar_Update, DB.HonorBar_OnEnter, DB.HonorBar_OnClick, {'TOPRIGHT', E.UIParent, 'TOPRIGHT', -3, -255})

	E:CreateMover(Honor.holder, 'HonorBarMover', L["Honor Bar"], nil, nil, nil, nil, nil, 'databars,honor')

	DB:HonorBar_Toggle()
end
