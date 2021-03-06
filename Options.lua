--[[ @file-author@ @file-date-iso@ @file-abbreviated-hash@ ]]--
local LibStub = LibStub
local Fortress = LibStub("AceAddon-3.0"):GetAddon("Fortress")

local AceCfgReg = LibStub("AceConfigRegistry-3.0")
local AceCfgDlg = LibStub("AceConfigDialog-3.0")
local AceCfgCmd = LibStub("AceConfigCmd-3.0")

local media = LibStub("LibSharedMedia-3.0")
local hasWidgets = AceGUISharedMediaWidgets ~= nil

local L = LibStub("AceLocale-3.0"):GetLocale("Fortress")

local db
local appName = "Fortress"

local Debug = Fortress.Debug
local GetPluginSetting = Fortress.GetPluginSetting
local IsLauncher = Fortress.IsLauncher

--------
-- utility functions
--------
local function GetAppName(name)
	return string.gsub(name, "^Fortress", "")
end

--------
-- db getter/setter
--------
local function DefaultGet(info)
	return db[info.arg or info[#info]] 
end

local function DefaultSet(info, value)
	db[info.arg or info[#info]] = value
end

local function MasterGet(info)
	return db.masterSettings[info.arg or info[#info]]
end

local function MasterSet(info, value)
	db.masterSettings[info.arg or info[#info]] = value
	Fortress:UpdateAllObjects()
end

local function MasterColorGet(info)
	local index = info.arg or info[#info]
	local clr = db.masterSettings[index]
	return clr.r, clr.g, clr.b, clr.a
end

local function MasterColorSet(info, r, g, b, a)	
	local clr = db.masterSettings[info[#info]]
	clr.r = r
	clr.g = g
	clr.b = b
	clr.a = a
	Fortress:UpdateAllObjects()
end

local function PluginGet(info)
	local name = GetAppName(info.appName)
	local setting = info.arg or info[#info]
	
	if db.pluginUseMaster[name][setting] then
		return db.masterSettings[setting]
	else
		return db.pluginSettings[name][setting]
	end
end

local function PluginSet(info, value)
	local name = GetAppName(info.appName)
	local setting = info.arg or info[#info]
	
	if value ~= db.masterSettings[setting] then
		db.pluginUseMaster[name][setting] = false
	else
		db.pluginUseMaster[name][setting] = true
	end
	db.pluginSettings[name][setting] = value
	Fortress:UpdateObject(name)
end

local function PluginColorGet(info)
	local name = GetAppName(info.appName)
	local setting = info.arg or info[#info]
		
	local clr
	if db.pluginUseMaster[name][setting] then
		clr = db.masterSettings[setting]
	else
		clr = db.pluginSettings[name][setting]
	end
	return clr.r, clr.g, clr.b, clr.a
end

local function PluginColorSet(info, r, g, b, a)
	local name = GetAppName(info.appName)
	local setting = info.arg or info[#info]
	
	db.pluginUseMaster[name][setting] = false
	
	local clr = db.pluginSettings[name][setting]
	clr.r = r
	clr.g = g
	clr.b = b
	clr.a = a
	Fortress:UpdateColor(name)
end

local function UseMasterGet(info)
	local name = GetAppName(info.appName)
	local setting = info.arg or info[#info]
	
	return db.pluginUseMaster[name][setting]
end

local function UseMasterSet(info, value)
	local name = GetAppName(info.appName)
	local setting = info.arg or info[#info]
	
	db.pluginUseMaster[name][setting] = value
end

local function PluginDisabled(info)
	local name = GetAppName(info.appName)
	return not db.pluginSettings[name].enabled -- enabled is always handled per plugin
end

--[[ options table ]]--
local options = {
	handler = Fortress,
	get     = DefaultGet,
	set     = DefaultSet,
	name    = "Fortress",
	type    = "group",
	childGroups = "tab",
	args    = {
		general = {
			name = L["General"],
			desc = L["General options."],
			type = "group",
			order = 1,
			args = {
				enabled = {
					name = L["Enabled"],
					desc = L["Enable/disable the addon."],
					type = "toggle",
					get  = "IsEnabled",
					set  = function(info, value)
						DefaultSet(info, value)
						if value then
							Fortress:Enable()
						else
							Fortress:Disable()
						end
					end,
					order = 2,
				},
				showAllPlugins = {
					name = L["Show all plugins"],
					desc = L["Shows all plugins at full alpha."],
					type = "execute",
					func = function(info)
						Fortress:ShowAllObjects(true)
					end,
					order = 1,
				},
				hideAllOnMouseOut = {
					name = L["Hide all on mouse out"],
					desc = L["Show all plugins when the mouse is over one, hide them otherwise."],
					type = "toggle",
					set  = function(info, value)
						DefaultSet(info, value)
						
						if value then
							Fortress:HideAllObjects()
						else
							Fortress:ShowAllObjects()
						end
					end,
					order = 3,
				},
				showLinked = {
					name = L["Show Linked"],
					desc = L["Show all linked blocks when the mouse is over one, hide them otherwise."],
					type = "toggle",
					set  = function(info, value)
						DefaultSet(info, value)
						
						if value then
							Fortress:HideAllObjects()
						else
							Fortress:ShowAllObjects()
						end
					end,
					order = 4,
				},
				ignoreLaunchers = {
					name = L["Ignore Launchers"],
					desc = L["Do not display launcher plugins."],
					type = "toggle",
					set  = function(info, value)
						DefaultSet(info, value)
						Fortress:ToggleLaunchers()
					end,
					order = 5,
				},
				enableNewPlugins = {
					name = L["Enable new plugins"],
					desc = L["Enable plugins by default, when they are loaded the first time."],
					type = "toggle",
					order = 6,
				},
				--@alpha@
				debug = {
					name = "Debug",
					desc = "Enable debug messages.",
					type = "toggle",
					order = 98,
				},
				deprecated = {
					name = "Deprecated",
					desc = "Complain about deprecated attributes.",
					type = "toggle",
					order = 99,
				},
				--@end-alpha@
			},
		},
		masterPluginSettings = {
			name = L["Master Plugin Settings"],
			desc = L["Settings for all plugins."],
			type = "group",
			order = 2,
			get  = MasterGet,
			set  = MasterSet,
			args = {
				-- filled by CreatePluginOptions()
			},
		},
	},
}

local alignValues = {
	left  = L["Left"],
	right = L["Right"],
}

local pointValues = {
	LEFT   = L["Left"],
	RIGHT  = L["Right"],
	CENTER = L["Center"],
}

local relModes = {
	textToIcon  = L["Text to icon"],
	iconToText  = L["Icon to text"],
	bothToFrame = L["Both to block"],
}

local function DisabledIfIconInvisible(info)
	local name = GetAppName(info.appName)
	local obj = Fortress.DataObjects[name]
	
	if not obj.icon then
		return true
	end	
	return not GetPluginSetting(name, "showIcon")
end

local function VisibleForSimpleMode(info)
	local name = GetAppName(info.appName)
	return not GetPluginSetting(name, "simpleAlign")
end

local function VisibleForExtendedMode(info)
	local name = GetAppName(info.appName)
	return GetPluginSetting(name, "simpleAlign")
end

local function HasTooltipScale(info)
	local name = GetAppName(info.appName)
	local obj = Fortress.DataObjects[name]
	return Fortress.IsUsingGameTooltip(obj)
end

local function NotHasTooltipScale(info)
	return not HasTooltipScale(info)
end

-- This table will be converted to the AceOptions table for both
-- the settings (incl. the master-mode toggle) and the master settings.
-- It consists of subtables (each one standing for one group of settings),
-- that hold the options.
--
-- Options contain mainly AceOptions members, but some are special:
-- key            - The database key for this option. The option's type is
--                   choosen according to theto the type of the db value
-- masterDisabled - Like disabled, but for the master mode
-- masterHidden   - Like hidden, but only for master mode
--
-- See CreatePluginOptions() for any details
local pluginSettings = {
	{
		name = L["General Settings"],
		{
			key = "showText",
			name = L["Show Text"],
			desc = L["Show the plugin's text."],
		},
		{
			key = "showLabel",
			name = L["Show Label"],
			desc = L["Show the plugin's label."],
		},
		{
			key = "showIcon",
			name = L["Show Icon"],
			desc = L["Show the plugin's icon."],
			disabled = function(info)
				local name = GetAppName(info.appName)
				local obj = Fortress.DataObjects[name]
				return obj.icon == nil
			end,
		},
		{
			key = "blockLocked",
			name = L["Locked"],
			desc = "",
		},
		{
			key = "hideInCombat",
			name = L["Hide in combat"],
			desc = L["Hide this plugin in combat."],
		},
		{
			key = "hideOutOfCombat",
			name = L["Hide out of combat"],
			desc = L["Hide this plugin out of combat."],
		},
		{
			key = "hideOnMouseOut",
			name = L["Hide on mouse out"],
			desc = L["Hide this plugin until the mouse is over the frame."],
		},
		{
			key = "hideTooltipInCombat",
			name = L["Hide tooltip in combat"],
			desc = L["Hide this plugin's tooltip in combat."],
		},
		{
			key = "disableTooltip",
			name = L["Disable tooltip"],
			desc = L["Do not show this plugin's tooltip."],
		},
	},
	----------------------
	{
		name = L["Block Customization"],
		{
			key = "blockScale",
			name = L["Block Scale"],
			desc = L["Adjusts the plugin's size."],
			min  = .1,
			max  = 2,
			step = .01,
			isPercent = true,
		},
		{
			key = "blockHeight",
			name = L["Block Height"],
			desc = L["Adjusts the plugin's height."],
			min  =   5,
			max  = 100,
			step =   1,
		},	
		{
			key = "fixedWidth",
			name = L["Fixed Width"],
			desc = L["Don't change the width of this plugin automatically."],
		},
		{
			key = "blockWidth",
			name = L["Width"],
			desc = L["The width of this plugin in fixed width mode."],
			min =   5,
			max = 600,
			step =  1,
			disabled = function(info)
				local name = GetAppName(info.appName)
				return not GetPluginSetting(name, "fixedWidth")
			end,
			masterDisabled = function(info)
				return not db.masterSettings.fixedWidth
			end,
		},
		{
			key = "iconSize",
			name = L["Icon Size"],
			desc = L["The size of the plugin's icon."],
			min  = 5,
			max  = 50,
			step = 1,
		},
	},
	{	-- Font Settings
		{
			key = "font",
			name = L["Font"],
			desc = L["The font for the plugin text."],
			dialogControl = hasWidgets and "LSM30_Font" or nil, -- fallback to default control, if mediaWidgets is not available
			values = media:HashTable("font"), 
		},
		{
			key = "fontSize",
			name = L["Font Size"],
			desc = L["The text's font size."],
			min  = 5,
			max  = 20,
			step = 1,
		},
		{
			key = "textColor",
			name = L["Text Color"],
			desc = L["The text color."],
		},
		{
			key = "labelColor",
			name = L["Label Color"],
			desc = L["The label color."],
		},
		{
			key = "unitColor",
			name = L["Suffix Color"],
			desc = L["The suffix color."],
		},
	},
	{	-- Background Settings
		{
			key = "background",
			name = L["Background"],
			desc = L["The background for the plugin."],
			dialogControl = hasWidgets and "LSM30_Background" or nil,
			values = media:HashTable("background"),
		},
		{
			key = "blockAlpha",
			name = L["Block Alpha"],
			desc = L["Adjusts the plugin's alpha value."],
			min  = 0,
			max  = 1,
			step = .1,
			isPercent = true,
		},
		{
			key = "frameColor",
			name = L["Frame Color"],
			desc = L["The plugins main color."],
			hasAlpha = true,
		},
	},
	{	-- Border Settings
		{
			key = "border",
			name = L["Border"],
			desc = L["The border texture for the plugin. Use 'None' to show no border."],
			dialogControl = hasWidgets and "LSM30_Border" or nil,		
			values = media:HashTable("border"), 
		},
		{
			key = "borderColor",
			name = L["Border Color"],
			desc = L["The plugins border color."],
			hasAlpha = true,
		},
	},
	----------------------
	{
		name = L["Advanced Settings"],
		{
			key = "bgTiled",
			name = L["Tiled background"],
			desc = L["Use tiled background."],
		},
		{
			key = "bgTileSize",
			name = L["Tile size"],
			desc = L["The size for the background tiles."],
			min  = 1,
			max  = 25,
			step = 1,
			disabled = function(info)
				local name = GetAppName(info.appName)
				return not GetPluginSetting(name, "bgTiled")
			end,
			masterDisabled = function(info)
				return not db.masterSettings.bgTiled
			end,			
		},
		{
			key = "edgeSize",
			name = L["Edge size"],
			desc = L["The size for the edges."],
			min  = 1,
			max  = 30,
			step = 1,
		},
		{
			key = "hideTooltipOnClick",
			name = L["Hide tooltip on click"],
			desc = L["Hide the plugin's tooltip when you click the block."],
		},
		{
			key = "forceVisible",
			name = L["Force Visible"],
			desc = L["Force this plugin to be visible, even if it should be hidden by any other option."],
		},
		
		{
			key = "tooltipScale",
			name = L["Tooltip scale"],
			desc = L["The scale of the tooltip"],
			min  = .1,
			max  = 2,
			bigStep = .1,
			hidden = NotHasTooltipScale,
			disabled = NotHasTooltipScale,
		},
		{
			type = "description",
			name = L["The tooltip scale option is not available for this plugin"],
			desc = "",
			hidden = HasTooltipScale,
			masterHidden = true,
		},
		
		-- Alignment
		-- TODO: Split alignment to an extra group?
		{
			key = "simpleAlign",
			name = L["Simple Layout"],
			desc = L["!simple-align-desc!"]
		},
		{ -- simple
			key = "align",
			name = L["Icon position"],
			desc = L["Controls the position of the icon."],
			values = alignValues,
			disabled = DisabledIfIconInvisible,
			hidden = VisibleForSimpleMode,
		},
		{ -- extended
			key = "alignRelMode",
			name = L["Relative Mode"],
			desc = L["Controls what item depends on what."],
			values = relModes,
			hidden = VisibleForExtendedMode,
		},
		{ -- extended
			key = "iconAlign",
			name = L["Icon point"],
			desc = "",
			values = pointValues,
			hidden = VisibleForExtendedMode,
		},
		{ -- extended
			key = "iconAlignTo",
			name = L["Icon relative point"],
			desc = "",
			values = pointValues,
			hidden = VisibleForExtendedMode,
		},
		{ -- both
			key = "iconAlignXOffs",
			name = L["Icon X offset"],
			desc = "",
			min = -20, max = 20, step = 1,
			disabled = DisabledIfIconInvisible,
		},
		{ -- both
			key = "iconAlignYOffs",
			name = L["Icon Y offset"],
			desc = "",
			min = -20, max = 20, step = 1,
			disabled = DisabledIfIconInvisible,
		},
		{ -- extended 
			key = "textAlign",
			name = L["Text point"],
			desc = "",
			values = pointValues,
			hidden = VisibleForExtendedMode,
		},
		{ -- extended 
			key = "textAlignTo",
			name = L["Text relative point"],
			desc = "",
			values = pointValues,
			hidden = VisibleForExtendedMode,
		},
		{ -- both
			key = "textAlignXOffs",
			name = L["Text X offset"],
			desc = "",
			min = -20, max = 20, step = 1,
		},
		{ -- both
			key = "textAlignYOffs",
			name = L["Text Y offset"],
			desc = "",
			min = -20, max = 20, step = 1,
		},
		{ -- extended
			key = "textJustify",
			name = L["Text justify"],
			desc = "",
			values = pointValues,
			hidden = VisibleForExtendedMode,
		},
	},
}

-- Special options, that should not have a "master mode" are directly
-- declared here.
local pluginOptions = {
	enabled = {
		name = L["Enabled"],
		desc = L["Enables or disables the plugin."],
		type = "toggle",
		get  = function(info)
			local name = GetAppName(info.appName)
			return db.pluginSettings[name].enabled
		end,
		set  = function(info, value)
			local name = GetAppName(info.appName)
			if value then
				Fortress:EnableDataObject(name)
			else
				Fortress:DisableDataObject(name)
			end
		end, 
		disabled = function(info)
			local name = GetAppName(info.appName)
			return db.ignoreLaunchers and IsLauncher(name)
		end,
		order = 0,
	},
}
-- This group holds all the "use master" toggles
local pluginUseMasterOptions = {}

-- This group holds the actual 
local pluginOptionsGroup = {
	settings = {
		type = "group",
		name = L["Settings"],
		desc = L["Individual plugin settings."],
		args = pluginOptions,
		-- Don't disable this, otherwise there's no way to reenable it...
		-- Never!
		order = 1,
	},
	masterSettings = {
		type = "group",
		name = L["Select master"],
		desc = L["Select which setting should be handled individualy."],
		args = pluginUseMasterOptions,
		order = 2,
	},
}

-- Maps the type of a database entry (the according Lua type)
-- to an AceOptions entry type
local typeToType = {
	boolean = "toggle",
	table   = "color",
	number  = "range",
	string  = "select",
}

local function CopyTable(tab, deep)
	local ret = {}
	for k, v in pairs(tab) do
		if deep and type(v) == "table" then
			ret[k] = CopyTable(v, deep)
		else
			ret[k] = v
		end
	end
	return ret
end

-- Special fields in the pluginSettings subtables,
-- that are no AceOptions entries and should be
-- ignored
local ignoreFields = { 
	key = true, 
	masterDisabled = true,
	masterHidden = true,
}

-- This function takes the pluginSettings table and
-- transforms it into the settings categories
-- * The master settings
-- * The per plugin settings
-- * The per plugin "use master" toggles
local function CreatePluginOptions()
	-- The database defaults, used to determine an option type
	local optType = Fortress.defaults.profile.masterSettings

	-- Iterate through each subgroup of options (like general or block customization)
	for i, group in ipairs(pluginSettings) do
		-- Layout of the group table
		local groupName = "group" .. i
		local groupTable = {
			name   = "",
			inline = true,
			type   = "group",
			order  = i,
			args   = {},
		}
		local tmp
	
		-- copied for each setting category
		tmp = CopyTable(groupTable, true)
		pluginOptions[groupName] = tmp
		local optionsArgs = tmp.args
		
		tmp = CopyTable(groupTable, true)
		options.args.masterPluginSettings.args[groupName] = tmp
		local masterArgs = tmp.args
		
		tmp = groupTable -- no need to copy here, it's the last one (remember this, when adding another one (-; )
		pluginUseMasterOptions[groupName] = tmp
		local useMasterArgs = tmp.args
		
		if group.name then
			-- Add a nice title
			local heading = {
				type = "header",
				name = group.name,
				desc = "",
				order = 0,
			}
			optionsArgs.heading = heading
			masterArgs.heading = heading
			useMasterArgs.heading = heading
		end

		-- And loop through the entries
		for ii, setting in ipairs(group) do
			local key = setting.key
			local t
			if key then 
				-- if key is provided, the type should be determined by
				-- the db type
				t = typeToType[type(optType[key])]
			else
				key = "entry"..ii
				t = setting.type -- otherwise it should be provided
			end
			Debug("Type for", key, "is", t or "nil")
			
			-- Get the getter/setter for per-plugin/master mode
			local get, set, mget, mset
			if t == "color" then
				get = PluginColorGet
				set = PluginColorSet
				mget = MasterColorGet
				mset = MasterColorSet
			else
				get = PluginGet
				set = PluginSet
				mget = MasterGet
				mset = MasterSet
			end
			
			-- Any special overrides?
			get = setting.get or get
			set = setting.set or set
			
			-- Create the options entry
			local opt = {
				type  = t,
				get   = get,
				set   = set,
				order = ii,
			}
			-- And copy in all the information
			for k, v in pairs(setting) do	
				if not ignoreFields[k] then
					opt[k] = v
				end
			end
			optionsArgs[key] = opt
			
			-- Copy it for the master mode and
			-- adjust get,set,disabled,hidden
			local masterOpt = CopyTable(opt)
			masterOpt.get = mget
			masterOpt.set = mset
			masterOpt.disabled = setting.masterDisabled
			masterOpt.hidden = setting.masterHidden
			masterArgs[key] = masterOpt			
			
			-- Create a simple toggle for the
			-- "use master" switches.
			-- I wonder if anybody uses them...
			useMasterArgs[key] = {
				type = "toggle",
				name = setting.name,
				desc = L["Use the master setting for this option."],
				set  = UseMasterSet,
				get  = UseMasterGet,
				hidden = setting.hidden,
				order = ii,
			}
		end
	end
end

-- Holds the InterfaceOptionsFrame entry
local blizOptions

-- /fortress without any paramter will open the GUI, 
-- anything else goes to the slashcmd handler
local function ChatCmd(input)
	if not input or input:trim() == "" then
		InterfaceOptionsFrame_OpenToCategory(blizOptions)
	else
		if input:trim() == "help" then
			input = "" -- let AceCfgCmd show the list of paramters
		end
		AceCfgCmd.HandleCommand(Fortress, "fortress", appName, input)
	end
end

function Fortress:RegisterOptions()
	db = assert(self.db.profile)	-- assert to ensure that AceDB:New() gets called before this function
	self.optionsFrames = {}
	
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	
	for name, module in self:IterateModules() do
		options.args[name] = module:GetOptionsTable()
	end
	
	CreatePluginOptions()
	
	AceCfgReg:RegisterOptionsTable(appName, options)
	blizOptions = AceCfgDlg:AddToBlizOptions(appName, L["Fortress"])
	
	self:RegisterChatCommand("fortress", ChatCmd)
	self:RegisterChatCommand("ft", ChatCmd)
end

function Fortress:UpdateOptionsDbRef()
	db = self.db.profile
end

local function tswap(tab, a, b)
	local tmp = tab[a]
	tab[a] = tab[b]
	tab[b] = tmp
end

-- Bubble bubble blub!
local function SortSubCategories(parent)
	local list = INTERFACEOPTIONS_ADDONCATEGORIES
	local done = true
	for i=1, #list-1 do
		if (list[i].parent == parent) and (list[i+1].parent == parent) then
			if list[i].name:lower() > list[i+1].name:lower() then
				tswap(list, i, i+1)
				done = false
			end
		end
	end
	if not done then
		SortSubCategories(parent)
	end
end

function Fortress:AddObjectOptions(name, obj)
	local t = self.optionsFrames[name] or {}
	local cfgname = obj.configName or name
	t.name = cfgname
	t.desc = L["Options for %s"]:format(name)
	t.type = "group"
	t.childGroups = "tab"
	t.args = pluginOptionsGroup
	t.get  = PluginGet
	t.set  = PluginSet
	AceCfgReg:RegisterOptionsTable("Fortress"..name, t)
	
	-- HACK: The dash in front of the displayed name is a hack to prevent the suboption
	--       from stealing the suboptions of an equal named config entry later in the list.
	--       Hopefully nobody will name his DO 'Foo' and his config group '- Foo'...
	local panel = AceCfgDlg:AddToBlizOptions("Fortress"..name, "- "..cfgname, "Fortress")
	panel.obj:SetTitle(cfgname)
	
	-- Keep suboptions in alphabetical order
	SortSubCategories("Fortress")
end
