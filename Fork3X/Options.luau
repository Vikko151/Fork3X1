local Tool = script.Parent
local Support = require(Tool.Libraries.SupportLibrary)
local ImportCooldown = 0
local LastCopy = 0

local Settings = {}

-- NOTE: If you want to check if a setting is enabled, use Settings.Name
-- The final settings WON'T be under various categories.
-- E. g. -> If I want to see if Security -> CanSelectAll is enabled, I should put Settings.CanSelectAll

local OrganisedSettings = {

	--------------------------------------
	--	SECURITY
	--------------------------------------

	-- TIP: if you want to disable those behaviors in private servers, you can use logic gates or check in the function.

	Security = {
		-- How many lag-friendly parts (unanchored, particle emitters, etc...) you can create in a minute without getting kicked.

		LagFriendlyPartLimit = math.huge,

		-- Ungrouping a humanoid can cause kill loops. Anybody doing so will get affected by the BadBehaviorSubFunction.
		-- Disabling this is a silly idea, in my opinion.

		DisallowHumanoidUngrouping = false,

		-- Enormous meshes are very annoying to remove, and can cause Z-fighting artifacts that are very disturbing. 
		-- You can prevent them so. Note that the size is calculated this way: Mesh.Size.X * Part.Size.X e. g.

		MaxNormalMeshSize = 10240,

		-- If you want to kick the player when they place a big normal mesh.

		TriggerBadBehaviorForNormalMeshes = false,

		-- Determines the biggest mesh a player can make.
		-- If BetterMeshSizeControl is enabled, this setting will apply to the mesh's real size (if it looks like being X studs big, it'll calculate for a X studs size).
		-- Else, it will calculate the file mesh's size by supposing it's 2048x2048x2048 big.

		MaxFileMeshSize = 10240,

		-- If you want to kick the player when they place a big file mesh.
		-- Avoid enabling this without BetterMeshSizeControl.

		TriggerBadBehaviorForFileMeshes = false,

		-- Toggle if resizing takes the mesh size limits in account (NB: mesh type switching is covered whatsoever)

		StrictMeshResizing = true,

		-- If you got some c00lkid fans, enabling this will trigger a BadBehaviorSubFunction that will check the image/independent texture.
		-- You can decide there if you want to kick the user or not.

		BlacklistImages = false,

		-- You can set where the player will be able to find and select parts in the game.
		-- return workspace is the default value.

		GetScope = function(Player)
			return workspace
		end,

		-- You can also set the locations where Fork3X is allowed to manipulate objects
		-- The scope is always included when checking this table, so one doesn't need to worry about this
		AllowedLocations = {},

		TriggerBadBehaviorForForbiddenSelections = false,
		
		-- Rich text is a popular solution to attempt to bypass the Roblox filters
		-- Although Fork3X filters the raw text, Roblox may still be fooled by the rich text markers
		-- If you're worried about the above, you can disable this option
		CanUseRichText = true,
	},

	--------------------------------------
	--	CONSEQUENCES
	--------------------------------------

	-- If a bad behavior is triggered, it returns a BehaviorCode that can be:
	-- - Mass unanchoring - "Anchor"
	-- - Mass particle emitters - "Lag"
	-- - Humanoid Ungrouping - "Ungroup"
	-- - MeshSize - "Mesh"
	-- - ImageBlacklist - "Image"
	-- The table below contains a specific function for each of those. In this case, I used the webhook and kicked the player.

	Consequences = {
		BadBehaviorSubFunctions = {
			Anchor = function(Player: Player, Module, Values)
				Module.Embed("", "INAPPROPRIATE BEHAVIOR WARNING FOR ".. Player.DisplayName .." (@"..Player.Name.."):", "The mentioned player unanchored " .. Values.Parts .. " parts at the minute, which is above the limit.", 0xff0000)
				Player:Kick("KICKED: You got kicked for mass unanchoring.")
				return true
			end,
			Lag = function(Player: Player, Module, Values)
				Module.Embed("", "INAPPROPRIATE BEHAVIOR WARNING FOR ".. Player.DisplayName .." (@"..Player.Name.."):", "The mentioned player placed approximatively " .. Values.Rate / 20 .. " particles at the minute, which is above the limit.", 0xff0000)
				Player:Kick("KICKED: You got kicked for placing too many particle emitters.")
				return true
			end,
			Forbidden = function(Player: Player, Module, Values)
				if Values.DidCircumferePlayerTolerance then
					Module.Embed("", "INAPPROPRIATE BEHAVIOR WARNING FOR ".. Player.DisplayName .." (@"..Player.Name.."):", "The mentioned player tried to circumfere the built-in anti-player security with a tool such as F3X-sploit.", 0xff0000)
					Player:Kick("KICKED: You got kicked for potentially circumfering the anti-player security.")
				else
					Module.Embed("", "INAPPROPRIATE BEHAVIOR WARNING FOR ".. Player.DisplayName .." (@"..Player.Name.."):", "The mentioned player tried to select instances in forbidden location.", 0xff0000)
					Player:Kick("KICKED: You got kicked for selecting parts that are forbidden.")
				end

				return true
			end,
			Ungroup = function(Player: Player, Module, Values)
				Module.Embed("", "INAPPROPRIATE BEHAVIOR WARNING FOR "..Player.DisplayName.." (@"..Player.Name.."):", "The mentioned player has attempted to ungroup somebody. See by yourself if taking action is necessary.", 0xff0000)
				Player:Kick("KICKED: You got kicked for ungrouping a player/NPC.")
				return true
			end,
			MeshSize = function(Player: Player, Module, Values)
				Module.Embed("", "INAPPROPRIATE BEHAVIOR WARNING FOR "..Player.DisplayName.." (@"..Player.Name.."):", "The mentioned player has attempted to create a part with a mesh of a total size of " .. Values.X .. ", " .. Values.Y .. ", " .. Values.Z .. ". As this can create destructive glitches, the player has been kicked.", 0xff0000)
				Player:Kick("KICKED: You got kicked for potentially creating enormous meshes.")
				return true
			end,
			Image = function(Player: Player, Module, Values)

				local function ParseAssetId(Input)
					-- Returns the intended asset ID for the given input

					-- Get the ID number from the input
					local Id = tonumber(Input)
						or tonumber(Input:lower():match("%d+"))
						or tonumber(Input:lower():match('%?id=([0-9]+)'))
						or tonumber(Input:match('/([0-9]+)/'))
						or tonumber(Input:lower():match('rbxassetid://([0-9]+)'))
						or tonumber(Input:lower():match('https://www.roblox.com/asset-thumbnail/image?assetId=/([0-9]+)/&width=50&height=50&format=png'))
						or tonumber(Input:lower():match('rbxthumb://type=Asset&id=/([0-9]+)/&w=420&h=420'))

					-- Return the ID
					return Id;
				end;

				if not Values.Image or not tonumber(ParseAssetId(Values.Image)) then return end		-- rbxthumbs are also checked too! Only the ID is submitted...

				local ImageId = ParseAssetId(Values.Image)

				local BadNames = {
					"coolkid",
					"c00lkid",
					"coolkidd",
					"c00lkidd",
					"hacker",
					"hack"
				}

				local MarketplaceService = game:GetService("MarketplaceService")
				local ProductName = MarketplaceService:GetProductInfoAsync(ImageId, Enum.InfoType.Asset) and 
					string.lower(MarketplaceService:GetProductInfoAsync(ImageId, Enum.InfoType.Asset).Name)

				if not ProductName then return end

				local IsBlacklisted = false

				for _, BadName in BadNames do
					if string.find(ProductName, BadName) then
						IsBlacklisted = true
					end
				end

				if IsBlacklisted == true then
					Module.Embed("", "INAPPROPRIATE BEHAVIOR WARNING FOR "..Player.DisplayName.." (@"..Player.Name.."):", "The mentioned player placed a blacklisted image named " .. ProductName .. ". They have been kicked.", 0xff0000)
					Player:Kick("KICKED: You got kicked for placing a blacklisted image.")
					return true
				end
			end,
		};

		BadBehaviorFunction = function(Player: Player, Module, BehaviorCode, Values)	
			local Positive

			if Settings.BadBehaviorSubFunctions[BehaviorCode] then
				Positive = Settings.BadBehaviorSubFunctions[BehaviorCode](Player, Module, Values)
			end

			return Positive or false
		end,
	},

	--------------------------------------
	--	PERMISSIONS
	--------------------------------------

	-- If you want to set this up and use raidRoleplay's tags, you can safely put "return true" in the space between function() and end
	-- If you want to use your own system, you can check the part with CheckPermission and own/unown parts with SetPermission.

	-- The Type argument will be:

	-- "New" when a new part is created.
	-- "Lock" if a part gets locked. You can know if you're locking or unlocking with the Locking argument.
	-- "Ungroup" happens when a model gets ungrouped. As

	-- If you use HD admin or Adonis, feel free to check the rank too!

	-- Set PartSelectionLimit or CloningDelay to 0 if you don't want it/them to be applied. Otherwisely, use logic gates or numbers for it.

	-- Every settings after have to be a boolean or a logic gate under specific conditions.

	Permissions = {
		CheckPermission = function(Item: Instance, Player: Player)
			return true
		end,

		SetPermission = function(Item: Instance, Player: Player, Type: string, ...)
			if Type == "Lock" then
				local Locking = ...

				Item.Locked = Locking
			elseif Type == "Ungroup" then
				local Model = ...

			end 
		end,

		-- The consider part function determines whether a part will be considered or not.
		-- Compared to CheckPermission, when this function returns false, the part will just be ignored.
		-- Use CheckPermission if you want to make the system to be aware of the part, or this function if you want to ignore it (baseplate i. e.)

		ConsiderPart = function(Item: Instance, Player: Player)
			local IsLocked = Item:IsA("BasePart") and Item.Locked or false
			local IsTerrain = Item:IsA("Terrain")
			local IsChildOfTerrain = workspace.Terrain:IsAncestorOf(Item)
			local NotInScope = not Item:IsDescendantOf(Settings.GetScope(Player))

			return if IsLocked or IsTerrain or IsChildOfTerrain or NotInScope then false else true
		end,


		PartSelectionLimit = 0,
		CloningDelay = 0,

		CanUseExplorer = true,
		CanUseSaveLoad = true,
		CanUseExport = true,

		CanSelectAll = false,

		-- If you are alright to let people clone/delete/move other players, set this setting to 0.
		-- If you don't want people to be able to delete/clone/move other players, set this setting to 1.
		-- If you just want to prohibt any modification at players, set this setting to 2.

		PlayerTolerance = 0,

		-- Does your game have a lobby? You can disable spawns by adding "Spawn" to this table.
		-- This setting is here if you want to blacklist certain parts to be created via the New Part Tool.

		InstanceBlacklist = {},

		-- Is there any tool you don't want or find useless? You can add it to the list so it doesn't display.
		-- You need to put the tool's familiar name ("Marketplace Tool" e. g.)
		-- Doing this will also prevent the tool from being used completely (vs. removing the icon), which is efficient against hackers.

		ToolsBlacklist = {},

		-- If you don't want people to create annoying machines with HingeConstraints or inappropriate scenes with RopeConstraints, you can add them here.

		ConstraintsBlacklist = {},

		MaxEventsPerSecond = 15;
	},

	--------------------------------------
	--	EXTRA FEATURES
	--------------------------------------

	-- Here you can extend Fork3X's features. This means you can enable things that aren't forcedly available in a first time.

	ExtraFeatures = {
		ExtraMaterials = function()
			local Materials = {}
			local Blacklist = {
				Enum.Material.Air,
				Enum.Material.Water
			}

			for _, Material in Enum.Material:GetEnumItems() do 	
				if table.find(Blacklist, Material) then continue end

				Materials[Material] = Material.Name
			end
		end,

		-- If you want to let people manipulate some vehicle seats' properties such as max speed, turn speed, and torque, you can enable this.

		AllowExtraVehicleSeatsSettings = true,

		ExtraFonts = {},

		-- If you're interested in adding custom instances via the New Part tool, you can add them here.
		-- If you don't need - or don't want - to convert to the given part type, you need to specify the name of the instance and the function to create it.
		-- Example:
		-- ["Part but red"] = function() end;
		-- If you want to convert parts to the given type, you must use a table as done here:
		--[[["Part but red"] = {
				Create = function()
					-- Create the part
					local Part = Instance.new('Part')

					-- Set the size
					Part.Size = vector.create(4, 1, 2)
					
					-- Color it
					Part.Color = BrickColor.new("Bright red").Color

					-- Make part surfaces smooth
					Part.TopSurface = Enum.SurfaceType.Smooth;
					Part.BottomSurface = Enum.SurfaceType.Smooth;

					-- Make sure the part is anchored
					Part.Anchored = true

					-- Return the new part
					return Part
				end,

				IgnorePropertiesWhenConverting = false,

				IgnoreChildrenWhenConverting = false,

				CanBeConverted = true,

				ClassName = "Part",
			},]]


		CustomPartTypes = {};

		AllowMaterialVariants = true,

		-- You can set up a secret and an API key to allow Fork3X to send requests to an API.
		-- This will cover assets searching.

		-- Interested in setting this up? You can use this excellent tutorial as a base (note you have to use the permissions below for this):
		-- https://devforum.roblox.com/t/group-ranking-with-roblox-opencloud/3763957

		-- PS: You need to setup/use a key that allows creator-store-product:read (marketplace searching)

		EnableAPIs = false;
		SearchingSecret = "";

		AvailableConstraints = {
			Weld = {
				Name = "BTWeld"
			},
			RopeConstraint = {
				Name = 'BTRopeConstraint',
				Visible = true,
				Thickness = 0.5,
				Length = 20
			},
			RodConstraint = {
				Name = 'BTRodConstraint',
				Visible = true,
				Thickness = 0.5,
				Length = 20
			},
			HingeConstraint = {
				Name = 'BTHingeConstraint',
				Visible = true,
			},
		};

		ManipulateAnyConstraint = false;

		-- Toggles whether players can create MeshParts
		AllowMeshParts = true;

		-- THIS IS A VERY DANGEROUS SETTING! When enabled, you can modify any MeshPart.
		-- By default, Fork3X will only be able to modify MeshParts it has created to prevent hackers from using the tools to bypass MeshId.
		-- When you enable this, you acknowledge that this may cause significant problems in your game if misused.
		-- Prefer using the BT_CanModifyMeshPart tag on MeshParts that won't cause any problem.
		ManipulateAnyMeshPart = false;

		-- As an extra layer of security and as a way to prevent mistakes with big meshes, you can allow Fork3X to use meshes' absolute size.
		-- This will, when using Roblox servers/apis, calculate the mesh's real size and then resize it to the part.
		-- Be careful though! Avoid putting MaxFileMeshSize = 2048, as a part with a single size axis at 2048 will kick the player/revert the change!

		BetterMeshSizeControl = true;

	},

	--------------------------------------
	--	CODE-BASED CUSTOMISATION
	--------------------------------------

	-- Here you can change some parts of code Fork3X uses to generate objects such as the selection outlines.
	-- Avoid editing "SelectionRectangleMake" as it is recommended to edit the selection rectangle via themes.

	CodeBasedCustomisation = {
		SelectionBoxMake = function(Core)
			return {
				Name = 'BTSelectionBox',
				Parent = Core.UI,
				LineThickness = 0.025,
				Transparency = 0.6,
				Color = Core.Selection.Color,
			};
		end;

		TargetBoxMake = function(Core)
			return {
				Name = 'BTTargetBox',
				Parent = Core.UI,
				LineThickness = 0.025,
				Transparency = 0.6,
				Color = BrickColor.new 'Institutional white'
			};
		end;

		BoundingBoxHighlightMake = function(Core)
			return {
				Name = 'BTBoundingBoxHighlight',
				Parent = Core.UI,
				Color = Core.Selection.Color,
				Transparency = 0.6,
				LineThickness = 0.1,
				SurfaceColor = Core.Selection.Color,
				SurfaceTransparency = 0.8,
				Visible = Core.Selection.DisableHighlights
			};
		end;

		FocusHighlightMake = function(Core)
			return {
				Name = 'BTFocusHighlight',
				Parent = Core.UI,
				FillTransparency = 1,
				OutlineTransparency = 0.5,
			};
		end;

		SelectionRectangleMake = function(Core)
			return {
				Name = 'SelectionRectangle',
				Parent = Core.UI,
				RBXTAG_SelectionRectangle = true
			};

		end;

		GetClassIcons = function(Theme)
			local Table, ZeroPosition = {
				Part = Vector2.new(2, 1),
				MeshPart = Vector2.new(4, 8),
				UnionOperation = Vector2.new(4, 8),
				NegateOperation = Vector2.new(3, 8),
				VehicleSeat = Vector2.new(6, 4),
				Seat = Vector2.new(6, 4),
				TrussPart = Vector2.new(2, 1),
				CornerWedgePart = Vector2.new(2, 1),
				WedgePart = Vector2.new(2, 1),
				SpawnLocation = Vector2.new(6, 3),
				Model = Vector2.new(3, 1),
				Folder = Vector2.new(8, 8),
				Tool = Vector2.new(8, 2),
				Workspace = Vector2.new(10, 2),
				Accessory = Vector2.new(3, 4),
				Accoutrement = Vector2.new(3, 4),
				Attachment = Vector2.new(2, 9)
			}, Vector2.new()

			for Name, Position in Table do
				Table[Name] = (Position - Vector2.new(1, 1)) * Vector2.new(16, 16)
			end

			return Table, ZeroPosition
		end,

		-- Determines how many parts need to be selected to use a selection box instead of separate highlights.
		-- Set to nil to disable this feature. Careful, disabling it might cause lag when selecting a lot of parts!
		-- I advise 70 as a value as it keeps the draw calls number at a convenient value for most devices (840)

		UseBoxSelectionAt = 70;

		-- Highlights the focused part (last selected part) when there's more than one part.
		-- This can be very handy when using certain tools that attach the handles or use the focus (weld, last mode with the move tool, etc...)

		HighlightFocus = true;
	},

	--------------------------------------
	--	UI
	--------------------------------------

	-- Here you can change UI-related stuff, such as profiles, themes, etc...

	UI = {
		-- When you point at a part, you can add a hint where you can input the part's name and more things.
		-- Set it to false if you don't want hints to display (mostly if you use raidRoleplay).
		-- You can just display the item's name by putting "return Item.Name".

		PartHintFunction = function(Core, Item, Player)
			return Item.Name
		end,

		-- In the explorer, you can add a custom name (Part [@John Doe] e. g.) with this function.
		-- If this doesn't matter for you, just put "return Item.Name".

		CustomNameFunction = function(Item, Player)
			return Item.Name
		end,

		-- WARNING: While not deprecated, profiles should be used as a last resort over themes.
		-- Profiles are indeed very clunky and hard to use. Their counterintuitiveness is very painful and is better avoided.
		-- Remember themes also allow you to program behaviours via components (note you don't forcedly need to know how to use Roact)

		-- To allow everyone to feel comfortable, Fork3X supports profiles.
		-- Profiles can allow layout changes, other colors, etc...
		-- Your profile is a folder that includes everything about UIs. That means it must contain:

		-- • The custom UI folder.
		-- • The custom Interface folder.

		-- Then, once the Building Tools will be opened, it will call this function that must return the profile's name.
		-- You can use datastores in-game for example, but in Studio you can put your profile folder in ServerStorage -> Fork3XProfiles.
		-- The Studio profile will of course be ignored in-game
		-- You need to return the name of your profile in the function. Of course, you can do many things to check which profile the user uses.

		CheckProfile = function(Player)
			return nil
		end,

		-- Use this function to pick a theme's StyleSheet. Feel free to use InstanceValues to refer to objects in other places (which is better for performance)
		-- Confused? The wiki explains it better with visual content and examples.
		-- By the way, you can also set the theme here.

		CheckTheme = function(Core, Player)
			local Profile = Core.Options.CheckProfile(Player)

			if Core.Plugin and game:GetService("ReplicatedStorage"):FindFirstChild("Fork3XTheme") then
				local Theme: Folder = game:GetService("ReplicatedStorage").Fork3XTheme

				return Theme:FindFirstChildWhichIsA("StyleSheet"), Theme.Tokens:FindFirstChildWhichIsA("StyleSheet"), Theme.Components
			elseif Core.Plugin and Core.UseGigsDarkWithPlugin == true then
				local Theme = Core.Themes:WaitForChild("GigsDark")

				return Theme.GigsDark, Theme.Tokens.GigsDarkTokens, Theme.Components
			elseif Profile and Core.Themes:FindFirstChild(Profile) then
				local Theme = Core.Themes[Profile]

				local GetStyleObject = function(Object)
					return Object:FindFirstChildOfClass("StyleSheet") or Object:FindFirstChildOfClass("StyleLink") and Object:FindFirstChildOfClass("StyleLink").StyleSheet
				end

				return GetStyleObject(Theme), GetStyleObject(Theme.Tokens), Theme.Components, true
			else
				local Theme = Core.Themes:WaitForChild("CementDark")

				return Theme.CementDark, Theme.Tokens.CementDarkTokens, Theme.Components
			end
		end,

		CheckThemeWhenEquipped = false,

		-- The version 696 seems to interfere with the way parts are indexed, causing certain things to get delayed and result to unwanted yet uncontrolable effects.
		-- Among them, profiles may get parts of CementDark added even if they already exist.
		-- To prevent conficts and visual bugs, you can put a value above 0 to manage the delay once a profile is found.

		WaitForProfile = 0.5;

		-- On PC, it may be disturbing to not be able to move your camera while holding a handle.
		-- You can enable the following option to make the camera ignore the UI and be able to be moved while dragging.
		-- NOTE: This feature is disabled on mobile and isn't certified to be stable. Use at your own risks!

		IgnoreHandlesWithCamera = false;
	},

	--------------------------------------
	--	MODIFICATIONS
	--------------------------------------

	-- Here you can modify functions inside essential parts of Fork3X such as the Core (client) module and the SyncAPI (server) module.

	Modifications = {
		-- Adding tools is pretty way to go. However, adding new buttons for the selection pane might be more challenging.
		-- The selection pane isn't too hard to modify. But the core module almost gets modified at each update.
		-- This is why you can add some extra functions here that will be added natively to the Core module.
		-- Your custom function requires the code as a first table element, then the hotkey to which it's assigned as a second element (a string like 'Y' or a table)
		-- Put the hotkey to nil if you don't want it to have a key assigned.
		-- Any function that's called gets the core module as a first argument.
		-- You DON'T need to submit Core as an argument when calling the function.

		CustomCoreFunctions = {};

		-- If you're interested in triggering sounds, notifications, etc... when core-related functions or event are triggered, you can add events here.
		-- This function will be called at the setup with core as an argument, and will set up connections.
		-- You can add a click sound when selecting with an signal like Core.Selection.Changed:Connect() i. e.

		CustomCoreConnections = function(Core)
		end;
		
		CustomSyncModuleFunctions = {};

		CustomSyncModuleConnections = function(SyncModule)
		end;
	},

	--------------------------------------
	--	SAVING/LOADING
	--------------------------------------

	-- Here you can modify functions inside essential parts of Fork3X such as the Core (client) module and the SyncAPI (server) module.

	SavingLoading = {
		-- You can change the delay between each time you press the Load button with the Save/Load utility.

		LoadDelay = 0;

		-- You can set the number of slots people are able to have here.
		-- WARNING! Do not give too many slots, else you might saturate your game's datastores and cause data loses. 3 is a good value.

		-- You can also set a size limit that will be slot-specific if positive, and global if negative.
		-- Setting it to 0 or nil will jump the limit. This behaviour is strongly unrecommended.
		-- (PS: remember Fork3X is given as-is and that I discard any responsibility revolving datastore problems)

		-- The size limit is in KiChar, so in KiB but without compression.

		NumberOfSaveSlots = 3;
		SizeLimit = -4096;

		AllowRenaming = true;
		RenamingCharacterLimit = 25;

		PreSerialization = function(Items, Player)
			return true
		end;

		PreInflation = function(Data, Player) 
			return {}
		end;

		-- Set a number beyond which the save slot won't have a preview (to prevent too much server overhead)
		NoPreviewBeyond = 128;

		-- You can add a secondary loading mode if you want to have a placement system i. e.

		-- Insert both modes' names here:
		PrimaryLoadingText = "Load at Original Position";
		SecondaryLoadingText = "Load";

		-- You can put here a function for the secondary loading mode
		-- For maximum flexibility, the build won't have loaded by the time this function got fired.
		-- This means you have to load it in the function itself. This can be done with:
		--[[
			local Success, Build = pcall(Core.SyncAPI.Invoke, Core.SyncAPI, 'LoadBuild', Slot)
		]]
		-- PS: the function is automatically cooldowned. This is to avoid the cooldown system from being overridden

		SecondaryLoadingFunction = {
			-- This will be called after loading the build and setting permissions
			-- If you want to manipulate the build on the client afterwards, parent the build to the Player
			-- Else, parent it into Core.Options.GetScope()
			Server = function(Slot, Build, Player)
				Build.Parent = Player

				return Build
			end,

			-- This will be called when pressing the secondary loading button
			Client = function(Core, Slot)
				local Success, Data = pcall(Core.SyncAPI.Invoke, Core.SyncAPI, 'LoadSave', Slot, true)

				if Success then
					game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Add"))
				else
					game:GetService("SoundService"):PlayLocalSound(Core.Sounds:WaitForChild("Remove"))

					if Data and Core.AddNotification then
						Core.AddNotification:Fire({
							ThemeColor = Color3.new(1, 0, 0);
							NoticeText = [[Fork3X experienced an unexpected error while loading your build. It's likely not corrupted nor lost though. You can find it in the "What can I do?" section.]];
							DetailText = [[If this build of Fork3X isn't modified, report to the Fork3X creator the following error. Don't worry, your username has been removed:

]] .. string.gsub(Data, "." .. Core.Player.Name, "[PLAYER]");
						})
					end

					return
				end

				-- Once we loaded the build, ask the player to press somewhere so the build can be placed

				-- Hide the saving/loading interface
				Core.SaveLoadVisible = false
				Core.SaveLoadVisibilityChanged:Fire()

				local IndicatorText = Core.Make('TextLabel')({
					Name = "IndicatorText";
					Parent = Core.UI;
					AnchorPoint = Vector2.new(0.5, 1);
					Size = UDim2.new(0.4, 0, 0, 12);
					Position = UDim2.new(0.5, 0, 1, -90);
					Text = "Hold wherever you want to place your build.";
					RBXTAG_STATE_CenterAlignment = true;
					RBXTAG_Label = true;
				})

				local function HoldStarted(_, InputState)
					if InputState == Enum.UserInputState.Begin then
						game:GetService("ContextActionService"):UnbindAction('BT: Place build')
						IndicatorText:Destroy()

						Data.Parent = Settings.GetScope()

						Data:PivotTo( CFrame.new(Core.Mouse.Hit.Position) )

						-- To prevent disruptions, we would like to only parent after placing the build
						-- Wait for the drag to end before doing it (the player as a parent is whitelisted by security permissions, so moving is allowed)
						game:GetService("ContextActionService"):BindAction('BT: Re-parent build', 
							function(_, InputState)
								if InputState == Enum.UserInputState.Cancel or InputState == Enum.UserInputState.End then
									game:GetService("ContextActionService"):UnbindAction('BT: Re-parent build')
									Core.SyncAPI:Invoke('SetParent', {Data}, Settings.GetScope())
								end
							end,
							false,
							Enum.UserInputType.MouseButton1,
							Enum.UserInputType.Touch
						)


						Core.Selection.Replace({ Data })

						local MoveTool = require(Core.Tools.Move)
						Core.EquipTool(MoveTool)

						-- Enable dragging to allow easy positioning of the build
						MoveTool.FreeDragging:SetUpDragging(Data)
					end
				end

				-- Register input handler
				game:GetService("ContextActionService"):BindAction('BT: Place build', HoldStarted, false,
					Enum.UserInputType.MouseButton1,
					Enum.UserInputType.Touch
				)
			end;
		}
	},

	--------------------------------------
	--	EXPLORER SETTINGS
	--------------------------------------

	-- Here you can modify functions inside essential parts of Fork3X such as the Core (client) module and the SyncAPI (server) module.

	Explorer = {

		ExplorerSearchingAlgorithm = function(Items, IdMap, SearchArgument: string)
			local ReturnedItems = {}

			-- Find parts with the desired text inside
			for Index, Item in Items do
				local IsStrict = SearchArgument:sub(1, 1) == "!"
				local Result = IsStrict and Item.Name:lower():sub(1, #SearchArgument - 1) == SearchArgument:sub(2, #SearchArgument)
					or Item.Name:lower():find( SearchArgument:lower() )

				if Result then
					ReturnedItems[Index] = Item
					-- Add the returned part's ancestry
					local Ancestor = Item
					local OutOfRange = false

					repeat
						Ancestor = Ancestor.Parent

						local Index = IdMap[Ancestor]

						if Index then
							ReturnedItems[Index] = Items[Index]
							ReturnedItems[Index].Expanded = true
						else
							OutOfRange = true
						end
					until OutOfRange == true
				end
			end

			return ReturnedItems
		end,

		-- You can set here whether a player can see an object in the explorer.
		-- This DOESN'T mean it isn't selectable. This should be used as a matter of convenience to only display specific parts (return Settings.CheckPermission(Item, Player))

		GetIndexableItemsFunction = function(Scope: Instance, Core: {})
			local FinalDescendants = Support.FlipTable(Scope:QueryDescendants("Model,BasePart:not(Terrain),Tool,Accessory,Accoutrement,Attachment,Folder"))
			local ScopeDescendants = Scope:GetDescendants()

			local Results = table.create(#FinalDescendants)

			for Index, Descendant in ScopeDescendants do	
				if FinalDescendants[Descendant] and (Descendant.Parent == Scope or FinalDescendants[Descendant.Parent]) then
					Results[#Results + 1] = Descendant
				end

				if Index % 700 == 0 then
					task.wait()
				end
			end

			return Results
		end,

		-- The explorer doesn't have a negligible cost on performance.
		-- You can make the tool close the explorer automatically when unequipping the building tools.
		-- It will reopen, but not at the previous position, but this ensures great performance.
		CloseExplorerWhenUnequipping = true;

	},

	--------------------------------------
	--	CLASSIC F3X SETTINGS
	--------------------------------------

	Classic = {
		DisallowLocked = false;
		--[[
			When streaming is enabled, and the tool is being used by a player, cloned
			items are tagged with a temporary ID for this long in order for clients to
			be able to identify them as they replicate in.
		]]
		StreamingCloneTagLifetime = 2,
	},

	--------------------------------------
	--	MISCS
	--------------------------------------

	-- Here you can edit rarely edited settings,

	Miscs = {
		-- If you find the new union system laggy/buggy, you can enable this to make Fork3X use the old union functions.

		UseOldUnionSystem = false;

		-- You can change how accurate the collisions are with MeshParts and Unions
		-- Note that a too high precision can create flaws people can use to generate lag at ease
		CollisionFidelity = Enum.CollisionFidelity.Hull,

		-- You can change the RenderFidelity of unions and MeshParts
		PartRenderFidelity = Enum.RenderFidelity.Automatic,

		-- InsertService:GetFreeDecals(), which is the api-free method to search decals, is very outdated and might give very inaccurate results.
		-- If you want to avoid them, you can make a function that checks the product's infos and determine if's it's accurate or not.
		-- (in a nutshell make your own algorithm)

		CheckDecalResult = function(Results, Options)
			local FinishedResults = 0

			local Time = Options.Time

			for Index, Result in Results do
				coroutine.wrap(function()
					local ProductInfo = game:GetService("MarketplaceService"):GetProductInfoAsync(Result.AssetId, Enum.InfoType.Asset)
					if tonumber(os.date("%Y")) and tonumber(os.date("%Y")) - tonumber(string.sub(ProductInfo.Created, 1, 4)) < Time then
						Results[Index] = {}
					end
					FinishedResults += 1
				end)()
			end

			repeat task.wait(0.05) until FinishedResults == #Results

			return Results
		end,

		-- Show a warning if HTTP service isn't enabled.
		ShowHttpRequestsWarning = true;

		-- Show a warning if Fork3X is outdated.
		ShowUpdateWarning = true;

		-- If you want to access a part's physical properties, enable this setting so they can be edited with the material tool
		CustomPhysicalPropertiesEditing = true;

		-- Roblox characters are horribly unoptimized and cause lag with anything inside them, including tools.
		-- Enabling this option may reduce greatly the lag upon equipping the tool.
		-- Leave it to false if you have done modifications to Fork3X as they may break with this change.
		StoreFilesInPlayer = false;
	}
}

for _, SubTable in OrganisedSettings do
	for Index, Value in SubTable do
		Settings[Index] = Value
	end
end

-- You can put the names of the settings thay may vary over time OR that may need a function to be initialised
-- Do note the value must be a function in order for this to work

Settings.VariableSettings = {}

return Settings
