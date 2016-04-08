
local L = LibStub('AceLocale-3.0'):GetLocale('ExperienceMonitor')
ExperienceMonitor = DongleStub('Dongle-1.2'):New('ExperienceMonitor')

function ExperienceMonitor:Initialize()
	self.db = self:InitializeDB('ExperienceMonitorDatabase', {
		char = {
			showPostCombatMessage = true,
		}
	});

	self:RegisterEvent('PLAYER_ENTERING_WORLD');
	self:RegisterEvent('TIME_PLAYED_MSG');
	self:RegisterEvent('PLAYER_XP_UPDATE');
	self:RegisterEvent('PLAYER_LEVEL_UP');
	self:RegisterEvent('CHAT_MSG_COMBAT_XP_GAIN');
	self:RegisterEvent('PLAYER_REGEN_ENABLED');
	self:RegisterEvent('PLAYER_REGEN_DISABLED');
	RequestTimePlayed();

	self:ScheduleRepeatingTimer('EXPERIENCE_TIMEKEEPER', function()
		if ExperienceMonitor.data then
			ExperienceMonitor.data.time_played.total = ExperienceMonitor.data.time_played.total + 1;
			ExperienceMonitor.data.time_played.level = ExperienceMonitor.data.time_played.level + 1;
		end
	end, 1);
end

function ExperienceMonitor:PLAYER_ENTERING_WORLD()
	if not self.data then
		self.data = {
			xp = {
				gain = 0,
				last_mob = 0,
				last_gain = UnitXP('player'),
				initial = UnitXP('player'),
				accumulated = 0,
				session = 0,
				fight = 0,
			},
			started = time(),
			time_played = {
				total = 0,
				level = 0,
			},
		};
	end
end

function ExperienceMonitor:TIME_PLAYED_MSG(event, total, level)
	if not self.data then
		self:PLAYER_ENTERING_WORLD();
	end
	self.data.time_played.total = total;
	self.data.time_played.level = level;
end

function ExperienceMonitor:PLAYER_XP_UPDATE()
	if (not self.data) then
		self:PLAYER_ENTERING_WORLD();
	end
	local player_xp = UnitXP('player');
	self.data.xp.gain = player_xp - self.data.xp.last_gain;
	if self.data.xp.gain < 0 then
		self.data.xp.gain = 0;
	end
	self.data.xp.last_gain = player_xp;
	self.data.xp.session = player_xp - self.data.xp.initial + self.data.xp.accumulated;
end

function ExperienceMonitor:PLAYER_LEVEL_UP()
	self.data.time_played.level = 0;
	self.data.xp.accumulated = self.data.xp.accumulated + UnitXPMax('player') - self.data.xp.initial;
	self.data.xp.initial = 0;
end

function ExperienceMonitor:CHAT_MSG_COMBAT_XP_GAIN(event, msg)
	local _,_,_, kill_xp = string.find(msg, '^' .. L['TITAN_XP_GAIN_PATTERN'])
	if kill_xp then
		self.data.xp.last_mob = tonumber(kill_xp);
	end
	if self.data.xp.last_mob < 0 then
		self.data.xp.last_mob = 0;
	end
	self.data.xp.fight = self.data.xp.fight + self.data.xp.last_mob;
end

function ExperienceMonitor:GetExperience()
	local current = UnitXP('player');
	local required = UnitXPMax('player');
	local remaining = required - current;
	local percentage = math.floor(10000 * (current / required) + 0.5) / 100;
	local rested = GetXPExhaustion() == nil and 0 or GetXPExhaustion();
	local played = self.data.time_played.total;

	local session = {
		gained = self.data.xp.session,
		duration = time() - self.data.started,
		last_gain = self.data.xp.gain,
		last_mob = self.data.xp.last_mob,
		last_fight = self.data.xp.fight,
	};
	session.per_hour = session.gained / session.duration * 3600;
	session.time_to_level = session.gained == 0 and -1 or math.ceil((required - current) / session.gained * session.duration);

	local level = {
		duration = self.data.time_played.level,
		per_hour = current / self.data.time_played.level * 3600,
	};
	level.time_to_level = current == 0 and -1 or math.ceil((required - current) / current * level.duration);

	local gains_to_level = session.last_gain ~= 0 and math.ceil(remaining / session.last_gain) or L["TITAN_NA"];
	local kills_to_level = session.last_mob  ~= 0 and math.ceil(remaining / session.last_mob)  or L["TITAN_NA"];

	return {
		current = current,
		required = required,
		remaining = remaining,
		percentage = percentage,
		rested = rested,
		played = played,
		session = session,
		level = level,
		gains_to_level = gains_to_level,
		kills_to_level = kills_to_level,
	};
end


function ExperienceMonitor:PLAYER_REGEN_ENABLED()
	if self.db.char.showPostCombatMessage then
		local stats = self:GetExperience();
		if stats.session.last_fight ~= 0 then
			print(L["POST_COMBAT_EXPERIENCE"]:format(
				stats.session.last_fight,
				stats.session.last_fight / stats.required * 100,
				stats.percentage,
				UnitLevel('player') + 1
			));
		end
	end
end

function ExperienceMonitor:PLAYER_REGEN_DISABLED()
	self.data.xp.fight = 0;
end


SLASH_EXPERIENCE1 = "/em"
SlashCmdList['EXPERIENCE'] = function(cmd)
	if cmd == 'reset' then
		ExperienceMonitor.data = nil;
		ExperienceMonitor:PLAYER_ENTERING_WORLD();
		return;
	end

	local output = function(title, message)
		print(("|cffbbbbff%s|r%s"):format(title, message));
	end
	local stats = ExperienceMonitor:GetExperience();
	output(L["TITAN_XP_TOOLTIP_TOTAL_TIME"],      ExperienceMonitor.TitanUtils_GetAbbrTimeText(stats.played));
	output(L["TITAN_XP_TOOLTIP_LEVEL_TIME"],      ExperienceMonitor.TitanUtils_GetAbbrTimeText(stats.level.duration));
	output(L["TITAN_XP_TOOLTIP_SESSION_TIME"],    ExperienceMonitor.TitanUtils_GetAbbrTimeText(stats.session.duration));
	output(L["TITAN_XP_TOOLTIP_TOTAL_XP"],        tostring(stats.required));
	output(L["TITAN_XP_TOTAL_RESTED"],            tostring(stats.rested));
	output(L["TITAN_XP_TOOLTIP_LEVEL_XP"],        format(L["TITAN_XP_PERCENT_FORMAT"], stats.current, stats.percentage));
	output(L["TITAN_XP_TOOLTIP_TOLEVEL_XP"],      format(L["TITAN_XP_PERCENT_FORMAT"], stats.remaining, 100 - stats.percentage));
	output(L["TITAN_XP_TOOLTIP_SESSION_XP"],      tostring(stats.session.gained));
	output(format(L["TITAN_XP_KILLS_LABEL"],      stats.session.last_mob), tostring(stats.kills_to_level));
	output(format(L["TITAN_XP_XPGAINS_LABEL"],    stats.session.last_gain), tostring(stats.gains_to_level));
	output(L["TITAN_XP_TOOLTIP_XPHR_LEVEL"],      format(L["TITAN_XP_FORMAT"], stats.level.per_hour));
	output(L["TITAN_XP_TOOLTIP_XPHR_SESSION"],    format(L["TITAN_XP_FORMAT"], stats.session.per_hour));
	output(L["TITAN_XP_TOOLTIP_TOLEVEL_LEVEL"],   ExperienceMonitor.TitanUtils_GetAbbrTimeText(stats.level.time_to_level));
	output(L["TITAN_XP_TOOLTIP_TOLEVEL_SESSION"], ExperienceMonitor.TitanUtils_GetAbbrTimeText(stats.session.time_to_level));
end



function ExperienceMonitor.TitanUtils_GetAbbrTimeText(duration)
	if not duration or duration < 0 then
		return L["TITAN_NA"];
	end

	local days = math.floor(duration / 86400);
	local hours = math.floor(duration / 3600) - (days * 24);
	local minutes = math.floor(duration / 60) - (days * 1440) - (hours * 60);
	local seconds = duration % 60;
	
	local timeText = "";
	if (days ~= 0) then
		timeText = timeText..format("%d"..L["TITAN_DAYS_ABBR"].." ", days);
	end
	if (days ~= 0 or hours ~= 0) then
		timeText = timeText..format("%d"..L["TITAN_HOURS_ABBR"].." ", hours);
	end
	if (days ~= 0 or hours ~= 0 or minutes ~= 0) then
		timeText = timeText..format("%d"..L["TITAN_MINUTES_ABBR"].." ", minutes);
	end	
	timeText = timeText..format("%d"..L["TITAN_SECONDS_ABBR"], seconds);
	
	return timeText;
end











