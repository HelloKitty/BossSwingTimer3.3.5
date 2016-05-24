local band = bit.band
local tinsert = table.insert
local tremove = table.remove
local next = next
local strsplit = strsplit
local strfind = strfind
local GetNetStats = GetNetStats

local k,v,_

BossSwingTimer = LibStub("AceAddon-3.0"):NewAddon("BossSwingTimer", "AceConsole-3.0", "AceEvent-3.0")

local BossSwingTimerPath = "Interface\\AddOns\\BossSwingTimer\\"
local BossSwingTimerMediaPath = "Interface\\AddOns\\BossSwingTimer\\Media\\"

local time = GetTime()


local function MergeTables(dst, src)
	for k, v in pairs (src) do
		if type (v) ~= "table" then
			if dst[k] == nil then
				dst[k] = v
			end
		else
			if type(dst[k]) ~= "table" then
				dst[k] = {}
			end
			MergeTables(dst[k], v)
		end
	end
end

local framepoints = {
	["CENTER"] = "CENTER",
	["TOP"] = "TOP",
	["RIGHT"] = "RIGHT",
	["BOTTOM"] = "BOTTOM",
	["LEFT"] = "LEFT",
	["TOPRIGHT"] = "TOPRIGHT",
	["TOPLEFT"] = "TOPLEFT",
	["BOTTOMLEFT"] = "BOTTOMLEFT",
	["BOTTOMRIGHT"] = "BOTTOMRIGHT",
}

local defaults = {
	profile = {
		enabled = true,
		hideooc = false,
		showonlyintankspec = false,
		frame = {
			locked = false,
			lag = true,
			texture = " Default",
			point = {
				x = 0,
				y = 0,
				p = "CENTER",
				r = "CENTER",
				rf = "UIParent",
			},
			width = 300,
			height = 32,
			length = 2500,
			scale = 1,
			alpha = 0.8,
		},
		targetbar = {
			locked = false,
			texture = " Default",
			point = {
				x = 0,
				y = 0,
				p = "CENTER",
				r = "CENTER",
				rf = "UIParent",
			},
			width = 300,
			height = 32,
			length = 2.5,
			scale = 1,
			alpha = 0.8,
		},
	},
	global = {
		speeds = {},
	},
}

local OptionsSlash = {
	type = "group",
	name = "Slash Command",
	order = -3,
	args = {
		config = {
			type = "execute",
			name = "Configure",
			desc = "Open the configuration dialog",
			func = function() BossSwingTimer:ShowConfig() end,
			guiHidden = true,
		},
		enable = {
			type = "execute",
			name = "Enable",
			desc = "Enable BossSwingTimer",
			func = function() BossSwingTimer.db.profile.enabled = true; BossSwingTimer:OnEnable() end,
		},
		disable = {
			type = "execute",
			name = "Disable",
			desc = "Disable BossSwingTimer",
			func = function() BossSwingTimer.db.profile.enabled = false; BossSwingTimer:OnDisable() end,
		},
	},
}

local tankspec = {
	["DEATHKNIGHT"] = 1,
	["DRUID"] = 3,
	["MONK"] = 1,
	["PALADIN"] = 2,
	["WARRIOR"] = 3,
}
local unitclass
local function istankspec()
	local currentSpec = GetSpecialization() or 0
	unitClass = unitClass or select(2, UnitClass("player"))
	return currentSpec == tankspec[unitClass]
end

BossSwingTimer.swings = {}

local unitList = {{id = "target", color = {r = 1, g = 0.2, b = 0.2}}, {id = "focus", color = {r = 1, g = 1, b = 0}}}

local function npcid(guid)
	return tonumber(guid:sub(-10, -7), 16) -- suppose to do some bit math to get NPC id from GUID. See http://wowwiki.wikia.com/wiki/API_UnitGUID?oldid=2401007
end
local function isnpc(guid)

	-- For info on 3.3.5 implementation of GUIDs visit http://wowwiki.wikia.com/wiki/API_UnitGUID?oldid=2401007

	-- We need to check the mask for if it's an NPC or not
	local B = tonumber(guid:sub(5,5), 16)
	local maskedB = B % 8 -- x % 8 has the same effect as x & 0x7 on numbers <= 0xf

	if maskedB == 3 then-- 3 is NPC
		return true
	else
		return false
	end
end

local LSM_statusbars
local LSM_statusbars_optionsList
local function createLSMlist()
	LSM_statusbars = LibStub:GetLibrary("LibSharedMedia-3.0",true):HashTable("statusbar")
	LSM_statusbars[" Default"] = BossSwingTimerMediaPath .. "glaze.tga"
	
	local t = {}
	
	for k,v in pairs(LSM_statusbars) do
		t[k] = k
	end
	
	LSM_statusbars_optionsList = t
end

function BossSwingTimer:GetOptions()

if not BossSwingTimer.Options then
	BossSwingTimer.Options = {
		type = "group",
		name = "BossSwingTimer",
		handler = BossSwingTimer,
		set = function(info, value) db[ info[#info] ] = value end,
		get = function(info) return db[ info[#info] ] end,
		args = {
			enabled = {
				name = "Enable",
				desc = "Enables / disables BossSwingTimer",
				order = 0,
				type = "toggle",
				set = function(info,val)
						self.db.profile[info[1]] = val
						BossSwingTimer:ToggleEnable()
					end,
				get = function(info) return self.db.profile[info[1]] end
			},
			hideooc = {
				name = "Hide out of combat",
				desc = "Only show the BossSwingTimer when in combat",
				order = 0,
				type = "toggle",
				set = function(info,val)
						self.db.profile[info[1]] = val
						self:UpdateVisibility()
					end,
				get = function(info) return self.db.profile[info[1]] end
			},
			showonlyintankspec = {
				name = "Only show in tank spec",
				desc = "Only show the BossSwingTimer when in tanking spec",
				order = 0,
				type = "toggle",
				set = function(info,val)
						self.db.profile[info[1]] = val
						self:UpdateVisibility()
					end,
				get = function(info) return self.db.profile[info[1]] end
			},
			frame = {
				name = "Frame",
				order = 2,
				type = "group",
				args = {
					locked = {
						name = "Lock Frame",
						desc = "Locks/unlocks the bar (needs to be unchecked to enable dragging/moving)",
						order = 0,
						type = "toggle",
						width = "full",
						set = function(info,val)
								self.db.profile[info[1]][info[2]] = val
								self.bar:EnableMouse(not val)
							end,
						get = function(info) return self.db.profile[info[1]][info[2]] end
					},
					lag = {
						name = "Show Lag",
						desc = "Shows/Hides the lag indicator",
						order = 0,
						type = "toggle",
						width = "full",
						set = function(info,val)
								self.db.profile[info[1]][info[2]] = val
								BossSwingTimer:CreateUI()
							end,
						get = function(info) return self.db.profile[info[1]][info[2]] end
					},
					texture = {
						name = "Bar Texture",
						desc = "The bar's texture",
						type = "select",
						order = 1.1,
						width = "double",
						values = function() return LSM_statusbars_optionsList or createLSMlist() end,
						set = function(info, val)
							self.db.profile[info[1]][info[2]] = val
							BossSwingTimer:CreateUI()
						end,
						get = function(info, val)
							return self.db.profile[info[1]][info[2]]
						end,
					},
					description1 = {
						name = " ",
						order = 1.9,
						type = "description",
						width = "full",
					},
					header2 = {
						name = "Size / Visuals",
						order = 2.0,
						type = "header",
						width = "full",
					},
					width = {
						name = "Width",
						desc = "The bar's width (default: "..defaults.profile.frame.width..")",
						order = 2.1,
						type = "range",
						min = 1,
						max = 500,
						step = 1,
						set = function(info, val)
							self.db.profile[info[1]][info[2]] = val;
							BossSwingTimer:CreateUI()
						end,
						get = function(info) return self.db.profile[info[1]][info[2]] end
					},
					height = {
						name = "Height",
						desc = "The bar's height (default: "..defaults.profile.frame.height..")",
						order = 2.1,
						type = "range",
						min = 1,
						max = 500,
						step = 1,
						set = function(info, val)
							self.db.profile[info[1]][info[2]] = val;
							BossSwingTimer:CreateUI()
						end,
						get = function(info) return self.db.profile[info[1]][info[2]] end
					},
					scale = {
						name = "Scale",
						desc = "The bar's scale (default: "..defaults.profile.frame.scale..")",
						order = 2.4,
						type = "range",
						min = 0.2,
						max = 2,
						step = 0.05,
						set = function(info, val)
							self.db.profile[info[1]][info[2]] = val;
							BossSwingTimer:CreateUI()
						end,
						get = function(info) return self.db.profile[info[1]][info[2]] end
					},
					alpha = {
						name = "Alpha",
						desc = "The bar's width (default: "..defaults.profile.frame.alpha..")",
						order = 2.5,
						type = "range",
						min = 0,
						max = 1,
						step = 0.05,
						set = function(info, val)
							self.db.profile[info[1]][info[2]] = val
							BossSwingTimer:CreateUI()
						end,
						get = function(info) return self.db.profile[info[1]][info[2]] end
					},
					length = {
						name = "Time frame (seconds)",
						desc = "Defines the maximum duration displayed on the bar (default: "..(defaults.profile.frame.length/1000).." seconds)",
						order = 2.6,
						type = "range",
						min = 1,
						max = 5,
						step = 0.1,
						set = function(info, val)
							self.db.profile[info[1]][info[2]] = val*1000
							BossSwingTimer:CreateUI()
						end,
						get = function(info) return self.db.profile[info[1]][info[2]]/1000 end
					},
					description2 = {
						name = " ",
						order = 2.9,
						type = "description",
						width = "full",
					},
					point = {
						type = "group",
						order = 3,
						name = "Position",
						inline = true,
						args = {
							p = {
								name = "Point",
								desc = "",
								type = "select",
								order = 1.1,
								values = framepoints,
								set = function(info, val)
									self.db.profile[info[1]][info[2]][info[3]] = val
									BossSwingTimer:CreateUI()
								end,
								get = function(info, val)
									return self.db.profile[info[1]][info[2]][info[3]]
								end,
							},
							r = {
								name = "Relative Point",
								desc = "",
								type = "select",
								order = 1.2,
								values = framepoints,
								set = function(info, val)
									self.db.profile[info[1]][info[2]][info[3]] = val
									BossSwingTimer:CreateUI()
								end,
								get = function(info, val)
									return self.db.profile[info[1]][info[2]][info[3]]
								end,
							},
							rf = {
								name = "Relative Frame",
								desc = "",
								type = "input",
								order = 1.3,
								width = "full",
								set = function(info, val)
									if not val or not _G[val] then
										val = "UIParent"
									end
									self.db.profile[info[1]][info[2]][info[3]] = val
									BossSwingTimer:CreateUI()
								end,
								get = function(info, val)
									return self.db.profile[info[1]][info[2]][info[3]]
								end,
							},
							description1 = {
								name = " ",
								order = 1.4,
								type = "description",
								width = "full",
							},
							x = {
								name = "X offset",
								desc = "Modifies the horizontal position",
								order = 2.1,
								type = "range",
								min = -1000,
								max = 1000,
								step = 1,
								set = function(info, val)
									self.db.profile[info[1]][info[2]][info[3]] = val
									BossSwingTimer:CreateUI()
								end,
								get = function(info) return self.db.profile[info[1]][info[2]][info[3]] end
							},
							y = {
								name = "Y offset",
								desc = "Modifies the vertical position",
								order = 2.1,
								type = "range",
								min = -1000,
								max = 1000,
								step = 1,
								set = function(info, val)
									self.db.profile[info[1]][info[2]][info[3]] = val
									BossSwingTimer:CreateUI()
								end,
								get = function(info) return self.db.profile[info[1]][info[2]][info[3]] end
							},
						},
					},
				},
			},
			profile = {
				name = "Profile",
				order = -1,
				type = "group",
				args = {
				},
			},
		}
	}
	
end

	BossSwingTimer.Options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	
	return BossSwingTimer.Options
end

function BossSwingTimer:OnInitialize()
	
	self.db = LibStub("AceDB-3.0"):New("BossSwingTimerDB", defaults, true)
	
	BossSwingTimer:GetOptions()	--create options

	local LibDualSpec = LibStub("LibDualSpec-1.0")
	LibDualSpec:EnhanceDatabase(self.db, "BossSwingTimer")
	LibDualSpec:EnhanceOptions(self.Options.args.profile, self.db)
	
	self.db.RegisterCallback(self, "OnProfileChanged", "ToggleEnable")
	self.db.RegisterCallback(self, "OnProfileCopied", "ToggleEnable")
	self.db.RegisterCallback(self, "OnProfileReset", "ToggleEnable")
	
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("BossSwingTimer", BossSwingTimer:GetOptions())
	LibStub("AceConfig-3.0"):RegisterOptionsTable("BossSwingTimer SlashCommand", OptionsSlash, {"bossswingtimer", "bst"})
	
end

function BossSwingTimer:ToggleEnable()
	if self.db.profile.enabled then
		self:OnEnable()
	else
		self:OnDisable()
	end
end

function BossSwingTimer:OnEnable()
	
	if (LSM_statusbars == nil) then
		createLSMlist()
	end
	
	if not self.db.profile.enabled then return end
	
	self:CreateUI()
	
	self:UpdateVisibility()

	self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:RegisterEvent("PLAYER_TARGET_CHANGED")
	self:RegisterEvent("PLAYER_FOCUS_CHANGED")
	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	
	self.bar:SetScript("OnShow", function() time = GetTime() end)
	
end

function BossSwingTimer:UpdateVisibility()
	if (self.db.profile.hideooc and not InCombatLockdown())
	or (self.db.profile.showonlyintankspec and not istankspec()) then
		self.bar:Hide()
	else
		self.bar:Show()
	end
end

function BossSwingTimer:OnDisable()
	self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
	self:UnregisterEvent("PLAYER_TARGET_CHANGED")
	self:UnregisterEvent("PLAYER_FOCUS_CHANGED")
	self:UnregisterEvent("PLAYER_REGEN_DISABLED")
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	
	self.bar:SetScript("OnUpdate", nil)
	
	self.bar:Hide()
end

function BossSwingTimer:ShowConfig()
	LibStub("AceConfigDialog-3.0"):Open("BossSwingTimer")
end


function BossSwingTimer:CreateUI()
	local bartexture = LSM_statusbars[self.db.profile.frame.texture]
	
	if not self.bar then
		self.bar = CreateFrame("Frame", "BossSwingTimerBar", UIParent)
		
		self.bar:EnableMouse(true)
		self.bar:SetMovable(true)
		self.bar:SetResizable(true)
		self.bar:SetScript("OnMouseDown", function()
			if not self.db.profile.frame.locked then
				self.bar:StartMoving()
			end
		end)
		self.bar:SetScript("OnMouseUp", function()
			if not self.db.profile.frame.locked then
				self.bar:StopMovingOrSizing()
				self.db.profile.frame.point.p, _, self.db.profile.frame.point.r, self.db.profile.frame.point.x, self.db.profile.frame.point.y = self.bar:GetPoint()
				LibStub("AceConfigRegistry-3.0"):NotifyChange("BossSwingTimer")
			end
		end)
	end
	if not self.bar.lag then
		self.bar.lag = self.bar:CreateTexture(nil, "BACKGROUND")
		self.bar.lag:SetPoint("TOPLEFT", self.bar, "TOPLEFT", 0, 0)
		self.bar.lag:SetPoint("BOTTOMLEFT", self.bar, "BOTTOMLEFT", 0, 0)
	end
	self.bar.lag:SetWidth(1)
	self.bar.lag:SetTexture(bartexture)
	self.bar.lag:SetVertexColor(0.6, 0.0, 0.0)
	self.bar.lag:SetAlpha(self.db.profile.frame.alpha)
	if not self.bar.background then
		self.bar.background = self.bar:CreateTexture(nil, "BACKGROUND")
	end
	self.bar.background:SetTexture(bartexture)
	self.bar.background:SetVertexColor(0.4, 0.4, 0.4)
	self.bar.background:SetAlpha(self.db.profile.frame.alpha)
	
	if self.db.profile.frame.lag then
		self.bar.background:ClearAllPoints()
		self.bar.background:SetPoint("TOPLEFT", self.bar.lag, "TOPRIGHT", 0, 0)
		self.bar.background:SetPoint("BOTTOMRIGHT", self.bar, "BOTTOMRIGHT", 0, 0)
		self.bar.lag:Show()
	else
		self.bar.background:ClearAllPoints()
		self.bar.background:SetPoint("TOPLEFT", self.bar, "TOPLEFT", 0, 0)
		self.bar.background:SetPoint("BOTTOMRIGHT", self.bar, "BOTTOMRIGHT", 0, 0)
		self.bar.background:SetTexCoord(0,1,0,1)
		self.bar.lag:Hide()
	end
	
	if self.db.profile.frame.locked then
		self.bar:EnableMouse(false)
	end
	
	self.bar:SetScript("OnUpdate", function(f,elapsed) self:OnUpdate(elapsed) end)
	
--[[
	if not self.bar.grip then
		self.bar.grip = CreateFrame("Frame", nil, self.bar)
	end
	if not self.bar.grip.tex then
		self.bar.grip.tex = self.bar.grip:CreateTexture(nil, "OVERLAY")
		self.bar.grip:SetPoint("BOTTOMRIGHT", self.bar, "BOTTOMRIGHT", 0, 0)
	end
	self.bar.grip:SetSize(10, 10)
	self.bar.grip:EnableMouse(true)
	self.bar.grip:SetScript("OnMouseDown", function()
		if not self.db.profile.frame.locked then
			self.bar:StartSizing("BOTTOMRIGHT")
		end
	end)
	self.bar.grip:SetScript("OnMouseUp", function()
		if not self.db.profile.frame.locked then
			self.bar:StopMovingOrSizing()
			self.db.profile.frame.width = self.bar:GetWidth()
			self.db.profile.frame.height = self.bar:GetHeight()
		end
	end)
	self.bar.grip.tex:SetAllPoints()
	self.bar.grip.tex:SetAlpha(0)
	self.bar.grip:Show()
]]

	self.bar:SetSize(self.db.profile.frame.width, self.db.profile.frame.height)
	self.bar:SetScale(self.db.profile.frame.scale)
	self.bar:ClearAllPoints()
	self.bar:SetPoint(self.db.profile.frame.point.p, self.db.profile.frame.point.rf, self.db.profile.frame.point.r, self.db.profile.frame.point.x, self.db.profile.frame.point.y)
	
end

function BossSwingTimer:UpdateAttackSpeeds()
	for _, u in ipairs(unitList) do
		local uid = UnitGUID(u.id)
		if uid and isnpc(uid) then
			local speed = UnitAttackSpeed(u.id)
			if speed then
				self.db.global.speeds[npcid(uid)] = {value = speed, api = true}
			end
		end
	end
end

function BossSwingTimer:OnSwing(time, guid, damage)
	time = time
	self:UpdateAttackSpeeds()

	local id = npcid(guid)
	self.swings[guid] = self.swings[guid] or {}
	local prev = self.swings[guid].time
	self.swings[guid].time = time
	local speed = nil
	if prev and (time - prev) < 5 then
		speed = time - prev
	end
	if self.db.global.speeds[id] and self.db.global.speeds[id].api then
		speed = self.db.global.speeds[id].value
	elseif speed then
		self.db.global.speeds[id] = {value = speed}
	end
	if speed then
		self.swings[guid].next = time + speed
		if damage then
			self.swings[guid].damage = damage
		end
	end
end

-- gui --

BossSwingTimer.texpool = {}
function BossSwingTimer:CreateTick()
	if #self.texpool > 0 then
		return tremove(self.texpool)
	end
	local result = self.bar:CreateTexture(nil, "ARTWORK")
	result:SetTexture(BossSwingTimerMediaPath .. "tick.tga")
	result:SetTexCoord(0.40625, 0.5625, 0, 1)
	result:SetPoint("TOP", self.bar, "TOP", 0, 0)
	result:SetPoint("BOTTOM", self.bar, "BOTTOM", 0, 0)
	result:SetWidth(5)
	return result
end
function BossSwingTimer:RecycleTick(tex)
	tinsert(self.texpool, tex)
	tex:Hide()
end


local special = {}
local alpha = 1
local color = {r = 0.7, g = 0.7, b = 0.7}
function BossSwingTimer:OnUpdate(elapsed)
	
	time = time + elapsed
	
	for _, u in ipairs(unitList) do
		local uid = UnitGUID(u.id)
		if uid then
			special[uid] = u.color
		end
	end

	local length = self.db.profile.frame.length
	
	if self.db.profile.frame.lag then
		local lag = select(3,GetNetStats())
		--lag = lag / 1000
		if lag > length then
			lag = length
		end
		local lagwidth = lag / length
		self.bar.lag:SetWidth(lagwidth * self.db.profile.frame.width)
		self.bar.lag:SetTexCoord(0,lagwidth,0,1)
		self.bar.background:SetTexCoord(lagwidth,1,0,1)
	end

	local maxDamage = 1
	local length = self.db.profile.frame.length / 1000
	for k, v in pairs(self.swings) do
		if not v.next or v.next < time then
			v.next = nil
			if v.tick then
				self:RecycleTick(v.tick)
				v.tick = nil
			end
		elseif v.damage and v.damage > maxDamage then
			maxDamage = v.damage
		end
	end
	for k, v in pairs(self.swings) do
		if v.next and v.next < time + length then
			if not v.tick then
				v.tick = self:CreateTick()
			end
			local c
			if special[k] then
				c = special[k]
			else
				if v.damage and v.damage < maxDamage then
					alpha = v.damage / maxDamage
				end
				c = color
			end
			v.tick:SetVertexColor(c.r, c.g, c.b, alpha)
			v.tick:SetPoint("LEFT", self.bar, "LEFT", (v.next - time) / length * self.db.profile.frame.width - 2, 0)
			if special[k] then
				v.tick:SetDrawLayer("ARTWORK", 2)
			else
				v.tick:SetDrawLayer("ARTWORK", 0)
			end
			v.tick:Show()
		end 
	end
	for k,v in pairs(special) do
	  special[k] = nil
	end
end

---------
local events = {
	["SWING_DAMAGE"] = true,
	["SWING_MISSED"] = true,
	["UNIT_DIED"] = true,
}

function BossSwingTimer:COMBAT_LOG_EVENT_UNFILTERED(mainevent, timestamp, event, sourceGUID, sourceName, sourceFlags, destGUID, destName, destFlags)
	if not events[event] then
		return
	end

	if sourceGUID == "0x0000000000000000" or sourceGUID == nil or sourceName == nil then
		return
	end --check for environmental damage

	if(isnpc(sourceGUID)) then
		message("Source is NPC")
	end

	if (event == "SWING_DAMAGE" or event == "SWING_MISSED") and destGUID == UnitGUID("player") and isnpc(sourceGUID) then
		self:OnSwing(GetTime(), sourceGUID, event == "SWING_DAMAGE")
	elseif event == "UNIT_DIED" then
		local v = BossSwingTimer.swings[destGUID]
		if v and v.tick then
			self:RecycleTick(v.tick)
			v.tick = nil
		end
		BossSwingTimer.swings[destGUID] = nil	--remove the UnitGUID from the table if the unit dies
	end
end

function BossSwingTimer:PLAYER_REGEN_DISABLED()
	if not (self.db.profile.showonlyintankspec and not istankspec()) then
		self.bar:Show()
	end
end

function BossSwingTimer:PLAYER_REGEN_ENABLED()
	if self.db.profile.hideooc then
		self.bar:Hide()
	end
end

BossSwingTimer.PLAYER_TARGET_CHANGED = BossSwingTimer.UpdateAttackSpeeds
BossSwingTimer.PLAYER_FOCUS_CHANGED = BossSwingTimer.UpdateAttackSpeeds

