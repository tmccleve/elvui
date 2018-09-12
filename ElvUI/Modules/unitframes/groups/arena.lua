local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule('UnitFrames');
local _, ns = ...
local ElvUF = ns.oUF
assert(ElvUF, "ElvUI was unable to locate oUF.")

--Cache global variables
--Lua functions
local _G = _G
local unpack = unpack
--WoW API / Variables
local CreateFrame = CreateFrame
local GetArenaOpponentSpec = GetArenaOpponentSpec
local GetSpecializationInfoByID = GetSpecializationInfoByID
local IsInInstance = IsInInstance
local UnitExists = UnitExists
local LOCALIZED_CLASS_NAMES_MALE = LOCALIZED_CLASS_NAMES_MALE
local RAID_CLASS_COLORS = RAID_CLASS_COLORS

--Global variables that we don't cache, list them here for mikk's FindGlobals script
-- GLOBALS: UIParent, ArenaHeaderMover
-- GLOBALS: CUSTOM_CLASS_COLORS

local ArenaHeader = CreateFrame('Frame', 'ArenaHeader', UIParent)

function UF:PostUpdateArenaPreparation(_, specID)
	if not (self.__owner and self.__owner.ArenaPrepSpec and self.__owner.ArenaPrepIcon) then return end

	local _, spec, texture, class
	if specID and specID > 0 then
		_, spec, _, texture, _, class = GetSpecializationInfoByID(specID)
	end

	local pvpIconEnabled = self.__owner.db.pvpSpecIcon and self.__owner:IsElementEnabled('PVPSpecIcon')
	if class and spec then
		self.__owner.ArenaPrepSpec:SetText(spec.."  -  "..LOCALIZED_CLASS_NAMES_MALE[class])

		if pvpIconEnabled then
			self.__owner.ArenaPrepIcon:SetTexture(texture or [[INTERFACE\ICONS\INV_MISC_QUESTIONMARK]])
			self.__owner.ArenaPrepIcon.bg:Show()
			self.__owner.ArenaPrepIcon:Show()
			self.__owner.PVPSpecIcon:Hide()
		end
	else
		self.__owner.ArenaPrepSpec:SetText('')

		if pvpIconEnabled then
			self.__owner.ArenaPrepIcon.bg:Hide()
			self.__owner.ArenaPrepIcon:Hide()
			self.__owner.PVPSpecIcon:Show()
		end
	end
end

function UF:Construct_ArenaFrames(frame)
	frame.RaisedElementParent = CreateFrame('Frame', nil, frame)
	frame.RaisedElementParent.TextureParent = CreateFrame('Frame', nil, frame.RaisedElementParent)
	frame.RaisedElementParent:SetFrameLevel(frame:GetFrameLevel() + 100)

	frame.Health = self:Construct_HealthBar(frame, true, true, 'RIGHT')
	frame.Name = self:Construct_NameText(frame)

	if(not frame.isChild) then
		frame.Power = self:Construct_PowerBar(frame, true, true, 'LEFT')

		frame.Portrait3D = self:Construct_Portrait(frame, 'model')
		frame.Portrait2D = self:Construct_Portrait(frame, 'texture')

		frame.Buffs = self:Construct_Buffs(frame)
		frame.Debuffs = self:Construct_Debuffs(frame)
		frame.Castbar = self:Construct_Castbar(frame)
		frame.HealthPrediction = self:Construct_HealComm(frame)
		frame.MouseGlow = self:Construct_MouseGlow(frame)
		frame.TargetGlow = self:Construct_TargetGlow(frame)
		frame.Trinket = self:Construct_Trinket(frame)
		frame.PVPSpecIcon = self:Construct_PVPSpecIcon(frame)
		frame.Range = self:Construct_Range(frame)
		frame:SetAttribute("type2", "focus")

		frame.customTexts = {}
		frame.InfoPanel = self:Construct_InfoPanel(frame)
		frame.unitframeType = "arena"
	end

	if not frame.isChild then
		frame.ArenaPrepIcon = frame:CreateTexture(nil, 'OVERLAY')
		frame.ArenaPrepIcon.bg = CreateFrame('Frame', nil, frame)
		frame.ArenaPrepIcon.bg:SetAllPoints(frame.PVPSpecIcon)
		frame.ArenaPrepIcon.bg:SetTemplate('Default')
		frame.ArenaPrepIcon:SetParent(frame.ArenaPrepIcon.bg)
		frame.ArenaPrepIcon:SetTexCoord(unpack(E.TexCoords))
		frame.ArenaPrepIcon:SetInside(frame.ArenaPrepIcon.bg)
		frame.ArenaPrepIcon.bg:Hide()
		frame.ArenaPrepIcon:Hide()

		frame.ArenaPrepSpec = frame.Health:CreateFontString(nil, "OVERLAY")
		frame.ArenaPrepSpec:Point("CENTER")
		UF:Configure_FontString(frame.ArenaPrepSpec)

		frame.Health.PostUpdateArenaPreparation = self.PostUpdateArenaPreparation
	end

	ArenaHeader:Point('BOTTOMRIGHT', E.UIParent, 'RIGHT', -105, -165)
	E:CreateMover(ArenaHeader, ArenaHeader:GetName()..'Mover', L["Arena Frames"], nil, nil, nil, 'ALL,ARENA')
	frame.mover = ArenaHeader.mover
end

function UF:Update_ArenaFrames(frame, db)
	frame.db = db

	do
		frame.ORIENTATION = db.orientation --allow this value to change when unitframes position changes on screen?
		frame.UNIT_WIDTH = db.width
		frame.UNIT_HEIGHT = db.infoPanel.enable and (db.height + db.infoPanel.height) or db.height

		frame.USE_POWERBAR = db.power.enable
		frame.POWERBAR_DETACHED = db.power.detachFromFrame
		frame.USE_INSET_POWERBAR = not frame.POWERBAR_DETACHED and db.power.width == 'inset' and frame.USE_POWERBAR
		frame.USE_MINI_POWERBAR = (not frame.POWERBAR_DETACHED and db.power.width == 'spaced' and frame.USE_POWERBAR)
		frame.USE_POWERBAR_OFFSET = db.power.offset ~= 0 and frame.USE_POWERBAR and not frame.POWERBAR_DETACHED
		frame.POWERBAR_OFFSET = frame.USE_POWERBAR_OFFSET and db.power.offset or 0

		frame.POWERBAR_HEIGHT = not frame.USE_POWERBAR and 0 or db.power.height
		frame.POWERBAR_WIDTH = frame.USE_MINI_POWERBAR and (frame.UNIT_WIDTH - (frame.BORDER*2))/2 or (frame.POWERBAR_DETACHED and db.power.detachedWidth or (frame.UNIT_WIDTH - ((frame.BORDER+frame.SPACING)*2)))

		frame.USE_PORTRAIT = db.portrait and db.portrait.enable
		frame.USE_PORTRAIT_OVERLAY = frame.USE_PORTRAIT
		frame.PORTRAIT_WIDTH = (frame.USE_PORTRAIT_OVERLAY or not frame.USE_PORTRAIT) and 0 or db.portrait.width

		frame.CLASSBAR_YOFFSET = 0

		frame.USE_INFO_PANEL = not frame.USE_MINI_POWERBAR and not frame.USE_POWERBAR_OFFSET and db.infoPanel.enable
		frame.INFO_PANEL_HEIGHT = frame.USE_INFO_PANEL and db.infoPanel.height or 0

		frame.BOTTOM_OFFSET = UF:GetHealthBottomOffset(frame)

		frame.PVPINFO_WIDTH = db.pvpSpecIcon and frame.UNIT_HEIGHT or 0

		frame.VARIABLES_SET = true
	end

	frame.colors = ElvUF.colors
	frame.Portrait = frame.Portrait or (db.portrait.style == '2D' and frame.Portrait2D or frame.Portrait3D)
	frame:RegisterForClicks(self.db.targetOnMouseDown and 'AnyDown' or 'AnyUp')
	frame:Size(frame.UNIT_WIDTH, frame.UNIT_HEIGHT)

	UF:Configure_InfoPanel(frame)

	--Health
	UF:Configure_HealthBar(frame)

	--Name
	UF:UpdateNameSettings(frame)

	--Power
	UF:Configure_Power(frame)

	--Portrait
	UF:Configure_Portrait(frame)

	--Auras
	UF:EnableDisable_Auras(frame)
	UF:Configure_Auras(frame, 'Buffs')
	UF:Configure_Auras(frame, 'Debuffs')

	--Castbar
	UF:Configure_Castbar(frame)

	--PVPSpecIcon
	UF:Configure_PVPSpecIcon(frame)

	--Trinket
	UF:Configure_Trinket(frame)

	--Range
	UF:Configure_Range(frame)

	--Heal Prediction
	UF:Configure_HealComm(frame)

	--CustomTexts
	UF:Configure_CustomTexts(frame)

	frame:ClearAllPoints()
	if frame.index == 1 then
		if db.growthDirection == 'UP' then
			frame:Point('BOTTOMRIGHT', ArenaHeaderMover, 'BOTTOMRIGHT')
		elseif db.growthDirection == 'RIGHT' then
			frame:Point('LEFT', ArenaHeaderMover, 'LEFT')
		elseif db.growthDirection == 'LEFT' then
			frame:Point('RIGHT', ArenaHeaderMover, 'RIGHT')
		else --Down
			frame:Point('TOPRIGHT', ArenaHeaderMover, 'TOPRIGHT')
		end
	else
		if db.growthDirection == 'UP' then
			frame:Point('BOTTOMRIGHT', _G['ElvUF_Arena'..frame.index-1], 'TOPRIGHT', 0, db.spacing)
		elseif db.growthDirection == 'RIGHT' then
			frame:Point('LEFT', _G['ElvUF_Arena'..frame.index-1], 'RIGHT', db.spacing, 0)
		elseif db.growthDirection == 'LEFT' then
			frame:Point('RIGHT', _G['ElvUF_Arena'..frame.index-1], 'LEFT', -db.spacing, 0)
		else --Down
			frame:Point('TOPRIGHT', _G['ElvUF_Arena'..frame.index-1], 'BOTTOMRIGHT', 0, -db.spacing)
		end
	end

	if db.growthDirection == 'UP' or db.growthDirection == 'DOWN' then
		ArenaHeader:Width(frame.UNIT_WIDTH)
		ArenaHeader:Height(frame.UNIT_HEIGHT + ((frame.UNIT_HEIGHT + db.spacing) * 4))
	elseif db.growthDirection == 'LEFT' or db.growthDirection == 'RIGHT' then
		ArenaHeader:Width(frame.UNIT_WIDTH + ((frame.UNIT_WIDTH + db.spacing) * 4))
		ArenaHeader:Height(frame.UNIT_HEIGHT)
	end

	frame:UpdateAllElements("ElvUI_UpdateAllElements")
end

UF['unitgroupstoload']['arena'] = {5, 'ELVUI_UNITTARGET'}
