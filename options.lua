
local L = LibStub('AceLocale-3.0'):GetLocale('ExperienceMonitor');
local Heading, Checkbox, Slider = LibStub('tekKonfig-Heading'), LibStub('tekKonfig-Checkbox'), LibStub('tekKonfig-Slider');


local frame = CreateFrame('Frame', nil, InterfaceOptionsFrame);
frame.name = 'ExperienceMonitor';

InterfaceOptions_AddCategory(frame);



--generic getter and setter functions
local function getOption(self)
	return ExperienceMonitor.db.char[self.db_key];
end
local function setOption(self)
	ExperienceMonitor.db.char[self.db_key] = self.GetValue and self:GetValue() or not ExperienceMonitor.db.char[self.db_key];
end



local title, subtitle = Heading.new(frame, L['EXPERIENCE'], L['EXPERIENCE_DESC']);

local showPostCombatMessage = Checkbox.new(frame, nil, L['SHOW_POST_COMBAT_MSG'], 'TOPLEFT', subtitle, 'BOTTOMLEFT', 10, -12);
showPostCombatMessage:SetScript('OnClick', setOption);
showPostCombatMessage.db_key = 'showPostCombatMessage';

local usageExplaination = frame:CreateFontString(nil, 'ARTWORK', 'GameFontHighlightSmall');
usageExplaination:SetText(L['USAGE_EXPLAINATION']);
usageExplaination:SetHeight(64);
usageExplaination:SetPoint('TOPLEFT', showPostCombatMessage, 'BOTTOMLEFT', -10, -20);
usageExplaination:SetPoint('RIGHT', frame, -32, 0);
usageExplaination:SetNonSpaceWrap(true);
usageExplaination:SetJustifyH('LEFT');
usageExplaination:SetJustifyV('TOP');


frame:SetScript('OnShow', function()
	showPostCombatMessage:SetChecked(getOption(showPostCombatMessage));
end);
