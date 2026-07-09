SyncModule = {}

local AddonsFolders = script.Parent.Parent:WaitForChild("Addons") and script.Parent.Parent:QueryDescendants("#Addons")

local ChosenAddonsFolder

-- Because I forgot to delete the former addon folder, find the right one
for _, AddonsFolder in AddonsFolders do
	local IsPatched = AddonsFolder:GetAttribute("AutoUpdatingPatch")

	if not IsPatched then
		ChosenAddonsFolder = AddonsFolder
	end
end

if ChosenAddonsFolder then
	for _, AddonsFolder in AddonsFolders do
		if AddonsFolder ~= ChosenAddonsFolder then
			AddonsFolder:Destroy()
		end
	end
else
	ChosenAddonsFolder = AddonsFolders[1]
end

local UpdateCheck = ChosenAddonsFolder:GetAttribute("AutoUpdatingPatch") or ChosenAddonsFolder:GetAttribute("WasNewVersion")

-- Purge any remainder in the case of a faulty update
if not UpdateCheck then
	task.delay(3, function()
		ChosenAddonsFolder:SetAttribute("AutoUpdatingPatch", 2)
	end)
end

local HttpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')
local MaterialService = game:GetService('MaterialService')
local AssetService = game:GetService("AssetService")
local InsertService = game:GetService("InsertService")
local DataStoreService = game:GetService("DataStoreService")

SyncModule.BuildsDatastore = nil

type SlotsData = { 
	["Data"]: { 
		[number]: { [string]: any }
	},
	["Client"]: { 
		[number]: { 
			["Name"]: string  | nil, 
			["Preview"]: { [string]: { [string]: any } } | nil,
			["Size"]: number | nil,
			["Version"]: number | nil,
		} 
	} 
}

SyncModule.SlotsData = nil
SyncModule.SlotsTotalSize = 0

SyncModule.UpdatedSlots = {}

-- References
SyncModule.SyncAPI = script.Parent;
SyncModule.Tool = SyncModule.SyncAPI.Parent;
SyncModule.Player = nil;

-- Libraries
SyncModule.Security = require(SyncModule.Tool.Core.Security);
SyncModule.Support = require(SyncModule.Tool.Libraries.SupportLibrary);
SyncModule.Signal = require(SyncModule.Tool.Libraries.Signal)
SyncModule.PropScan = require(SyncModule.Tool.Libraries.PropScan)

SyncModule.CSGTreeV1 = require(SyncModule.Tool.Libraries.CSGTreeV1)
SyncModule.CSGTreeV2 = require(SyncModule.Tool.Libraries.CSGTreeV2)

SyncModule.SerializationV2 = require(SyncModule.Tool.Libraries.SerializationV2)
SyncModule.SerializationV3 = require(SyncModule.Tool.Libraries.SerializationV3)
SyncModule.SerializationV4 = require(SyncModule.Tool.Libraries.SerializationV4)
SyncModule.SerializationV5 = require(SyncModule.Tool.Libraries.SerializationV5)
SyncModule.SerializationV6 = require(SyncModule.Tool.Libraries.SerializationV6)(SyncModule.CSGTreeV1, SyncModule.CSGTreeV2)

-- Default SyncModule.Options

local ToolOptions = SyncModule.Tool:FindFirstChild("Options") and require(SyncModule.Tool.Options)

if ToolOptions == nil then error("Failed to load Building Tools by F3X: SyncModule.Options module is missing!") end

SyncModule.Options = require(SyncModule.Tool.Libraries.LTSOptions)(ToolOptions)

local ShapeParameters = {
	CollisionFidelity = SyncModule.Options.CollisionFidelity,
	RenderFidelity = SyncModule.Options.PartRenderFidelity,
	FluidFidelity = Enum.FluidFidelity.UseCollisionGeometry,
	SplitApart = false
}


SyncModule.Plugin = SyncModule.Tool.Parent:IsA 'Plugin' and SyncModule.Tool.Parent or nil

--[[
Options = {
	DisallowLocked = false;
		--[[
		When streaming is enabled, and the tool is being used by a player, cloned
		items are tagged with a temporary ID for this long in order for clients to
		be able to identify them as they replicate in.
	StreamingCloneTagLifetime = 2,
	UnanchoredPartsLimitPerMinute = game.PrivateServerId ~=  "" and game.PrivateServerOwnerId ~= 0 and math.huge or 150
}]]

SyncModule.LagFriendlyParts = 0

-- Keep track of created items in memory to not lose them in garbage collection
SyncModule.CreatedInstances = {};
SyncModule.LastParents = {};

SyncModule.streamingClonesPendingUntagging = {}

-- Determine whether we're in tool or SyncModule.Plugin mode
SyncModule.ToolMode = (SyncModule.Tool.Parent:IsA 'Plugin') and 'Plugin' or 'Tool'

SyncModule.IsHttpServiceEnabled = nil

-- Prevent spammed warnings
SyncModule.WarnedAbout = {}

local Globals = {}

local function GetGlobal(Name)
	if not SyncModule.Player then
		return
	end

	return _G[ string.format("BT_%*_%*", SyncModule.Player.Name, Name) ]
end

local function SetGlobal(Name, Value)
	if not SyncModule.Player then
		return
	end

	local IdentificationString = string.format("BT_%*_%*", SyncModule.Player.Name, Name)

	_G[ IdentificationString ] = Value

	Globals[ Name ] = Value
end

function SyncModule.CanModifyItems(Items)
	-- Returns whether the items can be modified
	-- Check each item
	for _, Item in pairs(Items) do

		-- Catch items that cannot be reached
		local ItemAllowed = SyncModule.Security.IsItemAllowed(Item, SyncModule.Player)
		local LastParentKnown = SyncModule.LastParents[Item]

		if not (ItemAllowed or LastParentKnown) then
			if SyncModule.Options.TriggerBadBehaviorForForbiddenSelections == true then
				SyncModule.Options.BadBehaviorFunction(SyncModule.Player, SyncModule.Options.WebhookModule, "Forbidden", {})
			end

			return false
		end

		-- Catch the baseplate
		if SyncModule.Options.OnlySelectInWorkspace == true then
			if not SyncModule.WarnedAbout.OnlySelectInWorkspace then
				warn("[FORK3X]: OnlySelectInWorkspace is deprecated and instable. Please prefer using GetScope and AllowedLocations instead.\n\n More information can be found on github.com/VikkoMakesStuff/Fork3X/wiki/Options#onlyselectinworkspace")
				WarnedAbout.OnlySelectInWorkspace = true
			end

			if Item:FindFirstAncestorWhichIsA("Terrain") or not Item:FindFirstAncestor("Workspace") and Item.Parent ~= nil and Item.Parent ~= SyncModule.Player then
				SyncModule.Options.BadBehaviorFunction(SyncModule.Player, SyncModule.Options.WebhookModule, "Forbidden", {})
				return false
			end
		end


		-- Prevent hackers from circumventing SyncModule.PlayerTolerance (thank you for pointing out flaws f3xsploiters :P)
		local FirstModelAncestor = Item:FindFirstAncestorWhichIsA("Model")
		local DetectedPlayer = game.Players:GetPlayerFromCharacter(FirstModelAncestor)

		if DetectedPlayer then
			local PlayerTolerance = SyncModule.Options.PlayerTolerance
			local IsAllowed = if PlayerTolerance == 2 then false elseif PlayerTolerance == 1 then DetectedPlayer == SyncModule.Player else true

			if not IsAllowed then
				SyncModule.Options.BadBehaviorFunction(SyncModule.Player, SyncModule.Options.WebhookModule, "Forbidden", {DidCircumferePlayerTolerance = true})
				return false
			end
		end

		-- Catch locked parts
		if SyncModule.Options.DisallowLocked and (Item:IsA 'BasePart') and Item.Locked then
			return false
		end

	end

	-- Return true if all items modifiable
	return true

end

function SyncModule.GetPartsFromSelection(Selection)
	local Parts = {}

	-- Get parts from selection
	for _, Item in pairs(Selection) do
		if Item:IsA 'BasePart' then
			Parts[#Parts + 1] = Item

			-- Get parts within other items
		else
			for _, Descendant in pairs(Item:GetDescendants()) do
				if Descendant:IsA 'BasePart' then
					Parts[#Parts + 1] = Descendant
				end
			end
		end
	end

	-- Return parts
	return Parts
end

-- References to reduce indexing time
local GetConnectedParts = Instance.new('Part').GetConnectedParts;
local GetChildren = script.GetChildren;

-- Types of joints to assume should be preserved
local ManualJointTypes = SyncModule.Support.FlipTable { 'Weld', 'ManualWeld', 'ManualGlue', 'Motor', 'Motor6D' };

local function SearchJoints(Haystack, Part, Whitelist)
	-- Searches for and returns manual joints in `Haystack` involving `Part` and other parts in `Whitelist`

	local Joints = {};

	-- Search the haystack for joints involving `Part`
	for _, Item in pairs(GetChildren(Haystack)) do

		-- Check if this item is a manual, intentional joint
		if ManualJointTypes[Item.ClassName] and
			(Whitelist[Item.Part0] and Whitelist[Item.Part1]) then

			-- Save joint and state if intentional
			Joints[Item] = Item.Parent;

		end;

	end;

	-- Return the found joints
	return Joints;

end;

local function GetPartJoints(Part, Whitelist)
	-- Returns any manual joints involving `Part`

	local Joints = {};

	-- Get joints stored inside `Part`
	for Joint, JointParent in pairs(SearchJoints(Part, Part, Whitelist)) do
		Joints[Joint] = JointParent;
	end;

	-- Get joints stored inside connected parts
	for _, ConnectedPart in pairs(GetConnectedParts(Part)) do
		for Joint, JointParent in pairs(SearchJoints(ConnectedPart, Part, Whitelist)) do
			Joints[Joint] = JointParent;
		end;
	end;

	-- Return all found joints
	return Joints;

end;

local function RestoreJoints(Joints)
	-- Restores the joints from the given `Joints` data

	-- Restore each joint
	for Joint, JointParent in pairs(Joints) do
		Joint.Parent = JointParent;
	end;

end;

local function PreserveJoints(Part, Whitelist)
	-- Preserves and returns intentional joints of `Part` connecting parts in `Whitelist`

	-- Get the part's joints
	local Joints = GetPartJoints(Part, Whitelist);

	-- Save the joints from being broken
	for Joint in pairs(Joints) do
		Joint.Parent = nil;
	end;

	-- Return the joints
	return Joints;

end;

function SyncModule.FilterText(Text)
	-- If the text starts with _COMP_, remove the first underscore to prevent confusion with the compression system
	if Text:sub(1, 6) == '_COMP_' then
		Text = Text:sub(2, #Text)
	end

	if not RunService:IsStudio() then
		local CleanedText = Text

		local FilterResult

		local success, errorMessage = pcall(function()
			FilterResult = game:GetService("TextService"):FilterStringAsync(CleanedText, SyncModule.Player.UserId)
				:GetNonChatStringForBroadcastAsync()
		end)
		
		if success then
			return FilterResult
		elseif errorMessage then
			warn(errorMessage)
			return ""
		end
	else
		return Text
	end
end

-- Returns a table containing the custom properties, the tags, the attributes, and the children of an object
function SyncModule.GetObjectData(Object)
	-- Create the data we'll return
	local Data = {
		Properties = SyncModule.PropScan.GetCustomPropertiesOfObject(Object),
		Attributes = Object:GetAttributes(),
		Tags = game:GetService("CollectionService"):GetTags(Object),
	}
	
	-- Return this data
	return Data
end

local PropertiesBlacklist = {
	Name = true,
	Archivable = true,
	CFrame = true,
	BrickColor = true,
	Position = true,
	Orientation = true,
	Size = true,
	Anchored = true,
}

function SyncModule.TransferDataFromObjectToObject(Source, Target, Blacklist)
	
	local SourceData = SyncModule.GetObjectData(Source)
	
	if not Blacklist or not Blacklist.Properties then
		-- Get the common properties through both classes
		local CommonProperties = SyncModule.PropScan.GetCommonPropertiesFromClasses(Target.ClassName, Source.ClassName)

		for _, CommonProperty in CommonProperties do
			if SourceData.Properties[CommonProperty] and not PropertiesBlacklist[CommonProperty] then
				Target[CommonProperty] = SourceData.Properties[CommonProperty]
			end
		end
	end

	if not Blacklist or not Blacklist.Tags then
		local PartTags = game:GetService("CollectionService"):GetTags(Source)

		for _, Name in PartTags do
			Target:AddTag(Name)
		end
	end

	if not Blacklist or not Blacklist.Attributes then
		for Name, Value in SourceData.Attributes do
			Target:SetAttribute(Name, Value)
		end
	end
	
	for _, CustomChild in Target:QueryDescendants(">.FORK3X_SubType") do
		SyncModule.LastParents[CustomChild] = CustomChild.Parent
		
		CustomChild.Parent = nil
	end
	
	if not Blacklist or not Blacklist.Children then
		for _, Child in Source:GetChildren() do
			local Clone = Child:Clone()
			
			Clone:AddTag("FORK3X_SubType")
			
			Clone.Parent = Target
		end
	end

	if (not Blacklist or not Blacklist.Joints) and Source.Parent ~= nil then

		for _, Joint in Source:GetJoints() do
			if Joint.Part0 == Source then
				Joint.Part0 = Target
			end

			if Joint.Part1 == Source then
				Joint.Part1 = Target
			end
		end

	end
end

function SyncModule.TrackSubTypeChanges(Part, Changes)
	local PartChanges = Part:GetAttribute("FORK3X_Changed") and HttpService:JSONDecode( Part:GetAttribute("FORK3X_Changed") ) or {}

	for Name, Change in Changes do

		if not PartChanges[Name] or Change == true then

			PartChanges[Name] = Change
		elseif type(PartChanges[Name]) == "table" then

			if type(Change) == "string" then

				PartChanges[Name] = true
			else

				for _, Value in Change do
					if not table.find(PartChanges[Name], Value) then
						table.insert(PartChanges[Name], Value)
					end
				end
			end
		elseif type(PartChanges[Name]) == "string" then

			PartChanges[Name] ..= PartChanges[Name] .. "," .. Change
		end

	end

	Part:SetAttribute("FORK3X_Changed", HttpService:JSONEncode( PartChanges ))
end

function SyncModule.ConvertPartToType(Part, Type, Params)
	-- Get the part's class
	local CurrentType = Part.ClassName

	-- If this is already the right class, just return the current part
	if CurrentType == Type then
		return Part
	end

	local NewPart
	local FutureSize
	local SpecialMeshToRestore

	-- Create the new object with the requested class
	if Type == "MeshPart" and Part:FindFirstChildOfClass("SpecialMesh") then
		local SpecialMesh = Part:FindFirstChildOfClass("SpecialMesh")

		if SpecialMesh.MeshType == Enum.MeshType.FileMesh and SpecialMesh.MeshId ~= "" then
			NewPart = AssetService:CreateMeshPartAsync( Content.fromUri(SpecialMesh.MeshId), {
				CollisionFidelity = SyncModule.Options.CollisionFidelity
			} )

			NewPart.TextureID = SpecialMesh.TextureId

			if SpecialMesh:GetAttribute("BTAbsoluteSize") then
				FutureSize = SpecialMesh.Scale / SpecialMesh:GetAttribute("BTAbsoluteSize")
			end
		end
		
		SpecialMeshToRestore = SpecialMesh
		SpecialMesh.Parent = nil
	else
		NewPart = Instance.new(Type)
	end

	SyncModule.TransferDataFromObjectToObject(Part, NewPart, Params)
	
	if SpecialMeshToRestore then
		SpecialMeshToRestore.Parent = Part
	end
	
	if FutureSize then
		NewPart.Size = FutureSize
	end

	if Part:IsA("MeshPart") and Part.MeshId ~= "" and not Part:FindFirstAncestorOfClass("SpecialMesh") then
		local SpecialMesh = Instance.new("SpecialMesh")

		SpecialMesh.MeshType = Enum.MeshType.FileMesh
		SpecialMesh.MeshId = Part.MeshId
		
		local AbsoluteSize = Part:GetAttribute("BTAbsoluteSize") or vector.one / Part.MeshSize
		
		SpecialMesh.Scale = AbsoluteSize
			and Part.Size * AbsoluteSize
			or vector.one
		SpecialMesh.TextureId = Part.TextureID

		if Part:GetAttribute("BTAbsoluteSize") then
			SpecialMesh:SetAttribute( "BTAbsoluteSize", Part:GetAttribute("BTAbsoluteSize") )
		end

		SpecialMesh.Parent = NewPart
	end

	SyncModule.LastParents[Part] = Part.Parent

	SyncModule.CreatedInstances[Part] = Part

	SyncModule.CreatedInstances[NewPart] = NewPart
	
	-- Restore a few properties we blacklisted
	NewPart.CFrame = Part.CFrame
	NewPart.Size = Part.Size
	
	-- Restore deprecated properties
	NewPart.TopSurface = Part.TopSurface
	NewPart.BottomSurface = Part.BottomSurface
	NewPart.LeftSurface = NewPart.LeftSurface
	NewPart.RightSurface = NewPart.RightSurface
	NewPart.FrontSurface = NewPart.FrontSurface
	NewPart.BackSurface = NewPart.BackSurface
	
	NewPart.Anchored = Part.Anchored
	
	NewPart.Parent = Part.Parent

	Part.Parent = nil

	return NewPart
end

local function CanConvertToType(PartType)
	local IsAFunction = type(PartType) == "function"

	return not IsAFunction and PartType.CanBeConverted
end

local function CreatePart(PartType)
	-- Creates and returns new part based on `PartType` with sensible defaults

	if SyncModule.Options.InstanceBlacklist[PartType] then
		return
	end

	local CustomPartTypes = type(SyncModule.Options.CustomPartTypes) == "function" and SyncModule.Options.CustomPartTypes() or SyncModule.Options.CustomPartTypes

	local NewPart

	if PartType == 'Normal' then
		NewPart = Instance.new('Part')
		NewPart.Size = vector.create(4, 1, 2)

	elseif PartType == 'Truss' then
		NewPart = Instance.new('TrussPart')

	elseif PartType == 'Wedge' then
		NewPart = Instance.new('WedgePart')
		NewPart.Size = vector.create(4, 1, 2)

	elseif PartType == 'Corner' then
		NewPart = Instance.new('CornerWedgePart')
		NewPart.Size = vector.one

	elseif PartType == 'Cylinder' then
		NewPart = Instance.new('Part')
		NewPart.Shape = 'Cylinder'
		NewPart.Size = vector.create(2, 2, 2)

	elseif PartType == 'Ball' then
		NewPart = Instance.new('Part')
		NewPart.Shape = 'Ball'
		NewPart.Size = vector.one

	elseif PartType == 'Seat' then
		NewPart = Instance.new('Seat')
		NewPart.Size = vector.create(4, 1, 2)

	elseif PartType == 'Vehicle Seat' then
		NewPart = Instance.new('VehicleSeat')
		NewPart.Size = vector.create(4, 1, 2)

	elseif PartType == 'Spawn' then
		NewPart = Instance.new('SpawnLocation')
		NewPart.Size = vector.create(4, 1, 2)

	elseif PartType == 'MeshPart' then
		NewPart = Instance.new('MeshPart')
		NewPart.Size = vector.create(4, 1, 2)

		NewPart:AddTag("BT_CanModifyMeshPart")
	elseif PartType == 'Tool' then
		NewPart = Instance.new('Tool')

		local Handle = Instance.new('Part')
		Handle.Name = "Handle"
		Handle.Size = vector.one
		Handle.Parent = NewPart
		Handle.Anchored = false

		Handle.TopSurface = Enum.SurfaceType.Smooth;
		Handle.BottomSurface = Enum.SurfaceType.Smooth;

		SyncModule.Options.SetPermission(Handle, SyncModule.Player, "New")

		return NewPart
	elseif CustomPartTypes[PartType] then
		if type(CustomPartTypes[PartType]) == "function" then
			NewPart = CustomPartTypes[PartType]()
		else
			NewPart = CustomPartTypes[PartType].Create(SyncModule.Player)

			NewPart:SetAttribute("BTSubType", PartType)
		end

		SyncModule.Options.SetPermission(NewPart, SyncModule.Player, "New")
		
		return NewPart
	end

	SyncModule.Options.SetPermission(NewPart, SyncModule.Player, "New")

	-- Make part surfaces smooth
	NewPart.TopSurface = Enum.SurfaceType.Smooth;
	NewPart.BottomSurface = Enum.SurfaceType.Smooth;

	-- Make sure the part is anchored
	NewPart.Anchored = true

	return NewPart
end

local function RestrictMeshSize(Mesh, Scale, TriggerBadBehaviour)
	if Mesh.MeshType ~= Enum.MeshType.FileMesh then
		local Axis = {
			X = math.abs(Scale.X),
			Y = math.abs(Scale.Y),
			Z = math.abs(Scale.Z)
		}
		local BiggestDimension = math.max(Axis.X, Axis.Y, Axis.Z)
		if BiggestDimension > SyncModule.Options.MaxNormalMeshSize then
			if SyncModule.ToolMode == "Tool" and SyncModule.Options.TriggerBadBehaviorForNormalMeshes == true and TriggerBadBehaviour then
				SyncModule.Options.BadBehaviorFunction(SyncModule.Player, SyncModule.Options.WebhookModule, "MeshSize", Axis)
				return
			elseif SyncModule.ToolMode == "Tool" then
				Scale = (vector.one * SyncModule.Options.MaxNormalMeshSize):Min(Scale)
			end
		end
	else
		-- If it's a Fork3X mesh, listen to bad behavior settings and find the mesh's absolute size
		local AbsoluteSize = Mesh.MeshId == "" and vector.one or Mesh:GetAttribute("BTAbsoluteSize") or vector.create(2048, 2048, 2048)

		local Axis = {
			X = Mesh:GetAttribute("BTAbsoluteSize") and Scale.X / AbsoluteSize.X or Scale.X * AbsoluteSize.X,
			Y = Mesh:GetAttribute("BTAbsoluteSize") and Scale.Y / AbsoluteSize.Y or Scale.Y * AbsoluteSize.Y,
			Z = Mesh:GetAttribute("BTAbsoluteSize") and Scale.Z / AbsoluteSize.Z or Scale.Z * AbsoluteSize.Z
		}

		local ModifiedDimensions = {
			Mesh.Scale.X ~= Scale.X and math.abs(Axis.X) or 0,
			Mesh.Scale.Y ~= Scale.Y and math.abs(Axis.Y) or 0,
			Mesh.Scale.Z ~= Scale.Z and math.abs(Axis.Z) or 0,
		}

		--local XSize = 
		--local YSize = Axis.Y * 10
		--local ZSize = Axis.Z * 10
		local BiggestDimension = math.max(0, ModifiedDimensions[1], ModifiedDimensions[2], ModifiedDimensions[3])

		--print(BiggestDimension)

		if BiggestDimension > SyncModule.Options.MaxFileMeshSize then


			if SyncModule.ToolMode == "Tool" and SyncModule.Options.TriggerBadBehaviorForFileMeshes == true and TriggerBadBehaviour then
				SyncModule.Options.BadBehaviorFunction(SyncModule.Player, SyncModule.Options.WebhookModule, "MeshSize", Axis)
				return
			elseif SyncModule.ToolMode == "Tool" then
				Scale = (vector.one * (Mesh:GetAttribute("BTAbsoluteSize") and SyncModule.Options.MaxFileMeshSize or SyncModule.Options.MaxFileMeshSize / 2048)):Min(Scale)
			end
		end
	end

	return Scale
end

local function GetRawSize(Data)
	-- If it's a table, convert it to JSON
	if type(Data) == "table" then
		Data = HttpService:JSONEncode(Data)
	end

	-- Just return the size considering one character equals one byte without compression
	return string.len(Data) / 1024
end

local function DecodeSave(Data)
	if type(Data) == "table" then
		return Data
	end

	return HttpService:JSONDecode( string.gsub(Data, "Fork3X Save: ", "", 1) )
end

--[[
Returns the SlotsData. Calling this function is necessary in order to inflate the table.
]]

local function GetSlots()
	-- If we already assigned SlotsData, give it directly
	--print(SlotsData)

	if SyncModule.SlotsData ~= nil then
		return SyncModule.SlotsData
	end

	SyncModule.SlotsData = { Client = {}, Data = {} }

	-- Also get the global datastore as we need it for each slot
	if not SyncModule.BuildsDatastore then
		SyncModule.BuildsDatastore = DataStoreService:GetDataStore(SyncModule.Player.UserId .. "Builds")
	end
	-- Use task.spawn and a count variable in order to prevent the process from being too long
	local SlotsLoaded = 0
	SyncModule.SlotsTotalSize = 0

	local DoneEvent = SyncModule.Signal.new()

	for SlotNumber = 1, SyncModule.Options.NumberOfSaveSlots do
		task.spawn(function()

			local SlotInformation = {}
			
			-- Get the necessary information
			local SlotData = SyncModule.BuildsDatastore:GetAsync("Slot" .. SlotNumber)
			local SlotName = SyncModule.BuildsDatastore:GetAsync("Name" .. SlotNumber)

			if SlotData == "" or SlotData == nil then
				SlotsLoaded += 1

				if SlotsLoaded == SyncModule.Options.NumberOfSaveSlots then
					DoneEvent:Fire()
				end

				return
			end

			-- Find the slot's raw size
			local SlotSize = SlotData and GetRawSize(SlotData) or 0

			local SlotFinalData = SlotData and DecodeSave(SlotData)

			-- Put them inside SlotInformation
			SlotInformation.Name = SlotName or "Slot " .. SlotNumber
			SlotInformation.Preview = SlotSize < SyncModule.Options.NoPreviewBeyond and SlotFinalData or nil
			SlotInformation.Size = SyncModule.Support.Round(SlotSize, 3)
			SlotInformation.Version = SlotFinalData.Version

			-- Modify the main table
			SyncModule.SlotsData.Client[SlotNumber] = SlotInformation
			SyncModule.SlotsData.Data[SlotNumber] = SlotFinalData or nil

			-- Increment
			SlotsLoaded += 1
			SyncModule.SlotsTotalSize += SlotSize

			-- If SlotsLoaded equals the number of save slots we allow, return the table
			if SlotsLoaded == SyncModule.Options.NumberOfSaveSlots then
				DoneEvent:Fire()
			end
		end)
	end

	DoneEvent:Wait()

	DoneEvent:Destroy()

	return SyncModule.SlotsData
end

-- List of actions that could be requested
local Actions = {

	['RecolorHandle'] = function (NewColor)
		-- Recolors the tool handle
		SyncModule.Tool.Handle.BrickColor = NewColor;
	end;

	['Clone'] = function (Items, Parent)
		-- Clones the given items

		-- Validate arguments
		assert(type(Items) == 'table', 'Invalid items')
		assert(typeof(Parent) == 'Instance', 'Invalid parent')
		assert(SyncModule.Security.IsLocationAllowed(Parent, SyncModule.Player), 'Permission denied for client')

		if not SyncModule.Plugin then
			if GetGlobal("CanClone") == false then
				-- In case there was a synchronisation issue, just check again after waiting a bit

				task.wait(0.2)
				if GetGlobal("CanClone") == false then
					return
				end
			end
			if SyncModule.Options.CloningDelay ~= 0 then
				SetGlobal("CanClone", false)
				SetGlobal("CanCloneEnableFunction", task.delay( SyncModule.Options.CloningDelay, function() 
					SetGlobal("CanClone", nil) 
					SetGlobal("CanCloneEnableFunction", nil) 
				end) )
			end
		end

		for _, Part in pairs(Items) do
			if game.Players:GetPlayerFromCharacter( Part:FindFirstAncestorOfClass("Model") ) ~= nil then continue end

			if Part:IsA("BasePart") and Part.Anchored == false and SyncModule.Options.LagFriendlyPartLimit ~= math.huge then
				SyncModule.LagFriendlyParts += 1
				coroutine.wrap(function() task.wait(60) SyncModule.LagFriendlyParts -= 1 end)()
			end
		end

		if SyncModule.LagFriendlyParts >= SyncModule.Options.LagFriendlyPartLimit then
			SyncModule.Options.BadBehaviorFunction(SyncModule.Player, SyncModule.Options.WebhookModule, "Anchor", { Parts = SyncModule.LagFriendlyParts })
			return
		end

		-- Check if items modifiable
		if not SyncModule.CanModifyItems(Items) then
			return {}
		end

		-- Check if parts intruding into private areas
		local Parts = SyncModule.GetPartsFromSelection(Items)
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, false) then
			return {}
		end

		local Clones = {}		
		local StreamingCloneId = if (SyncModule.Player and game.Workspace.StreamingEnabled)
			then math.random(-2^30, 2^30)
			else nil

		-- Clone items
		for _, Item in pairs(Items) do
			local Clone = Item:Clone()

			if not Clone then continue end

			-- Include metadata when streaming is enabled in tool mode
			if StreamingCloneId then
				Clone:SetAttribute("BTStreamingCloneID", StreamingCloneId)
				Clone:AddTag("BTStreamingClone")
				SyncModule.streamingClonesPendingUntagging[Clone] = true
			end

			Clone.Parent = Parent

			-- Register the clone
			table.insert(Clones, Clone)
			SyncModule.CreatedInstances[Item] = Item
		end

		-- If streaming is enabled in tool mode, return temporary clone operation metadata
		-- (instead of invalid instance references)
		if StreamingCloneId then
			task.delay(SyncModule.Options.StreamingCloneTagLifetime, function ()
				for _, Clone in Clones do
					Clone:RemoveTag("BTStreamingClone")
					Clone:SetAttribute("BTStreamingCloneID", nil)
					SyncModule.streamingClonesPendingUntagging[Clone] = nil
				end
			end)
			return nil, StreamingCloneId, #Clones
		end

		-- Return the clones
		return Clones
	end;

	['CreatePart'] = function (PartType, Position, Parent)
		-- Creates a new part based on `PartType`

		-- Validate requested parent
		assert(typeof(Parent) == 'Instance', 'Invalid parent')
		assert(SyncModule.Security.IsLocationAllowed(Parent, SyncModule.Player), 'Permission denied for client')

		-- Create the part
		local NewPart = CreatePart(PartType);

		-- Position the part
		if NewPart:IsA("Tool") then
			NewPart:FindFirstChild("Handle").CFrame = Position;
		elseif NewPart:IsA("Model") then
			NewPart:PivotTo(Position)
		else
			NewPart.CFrame = Position
		end


		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas({ NewPart }), SyncModule.Player);

		-- Make sure the player is allowed to create parts in the area
		if SyncModule.Security.ArePartsViolatingAreas({ NewPart }, SyncModule.Player, false, AreaPermissions) then
			return;
		end;

		-- Parent the part

		-- If streaming is enabled in tool mode, to ensure returned instance reference isn't invalid,
		-- trigger immediate part replication by parenting elsewhere first
		if SyncModule.Player and game.Workspace.StreamingEnabled then
			NewPart.Parent = SyncModule.Player
		end

		NewPart.Parent = Parent

		-- Register the part
		SyncModule.CreatedInstances[NewPart] = NewPart;

		-- Return the part
		return NewPart;
	end;

	['CreateGroup'] = function (Type, Parent, Items)
		-- Creates a new group of type `Type`

		local ValidGroupTypes = {
			Model = true,
			Folder = true
		}

		-- Validate arguments
		assert(ValidGroupTypes[Type], 'Invalid group type')
		assert(typeof(Parent) == 'Instance', 'Invalid parent')
		assert(SyncModule.Security.IsLocationAllowed(Parent, SyncModule.Player), 'Permission denied for client')

		-- Check if items selectable
		if not SyncModule.CanModifyItems(Items) then
			return
		end

		-- Check if parts intruding into private areas
		local Parts = SyncModule.GetPartsFromSelection(Items)
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player)
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return
		end

		-- Create group
		local Group = Instance.new(Type)

		-- Attach children
		for _, Item in pairs(Items) do
			Item.Parent = Group
		end

		-- Parent group
		Group.Parent = Parent

		-- Make joints
		if Type == 'Model' then
			Group:MakeJoints()
		elseif Type == 'Folder' then
			local Parts = SyncModule.Support.GetDescendantsWhichAreA(Group, 'BasePart')
			for _, Part in pairs(Parts) do
				Part:MakeJoints()
			end
		end

		-- Return the new group
		return Group

	end,

	['Ungroup'] = function (Groups)

		-- Validate arguments
		assert(type(Groups) == 'table', 'Invalid groups')

		-- Check if items modifiable
		if not SyncModule.CanModifyItems(Groups) then
			return
		end

		-- Check if parts intruding into private areas
		local Parts = SyncModule.GetPartsFromSelection(Groups)
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player)
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return
		end

		local Results = {}

		-- Check each group
		for Key, Group in ipairs(Groups) do
			assert(typeof(Group) == 'Instance', 'Invalid group')

			if Group:FindFirstChildOfClass("Humanoid") then -- Imminent annilation for this top tier griefer.
				if SyncModule.ToolMode == "Tool" and SyncModule.Options.DisallowHumanoidUngrouping == true then
					SyncModule.Options.BadBehaviorFunction(SyncModule.Player, SyncModule.Options.WebhookModule, "Ungroup", {})
					return
				end
			end

			-- Track group children
			local Children = {}
			Results[Key] = Children

			-- Unpack group children into parent
			local NewParent = Group.Parent
			for _, Child in pairs(Group:GetChildren()) do
				if Child:IsA("Highlight") then
					Child:Destroy()
					continue
				end
				SyncModule.LastParents[Child] = Group
				Children[#Children + 1] = Child
				Child.Parent = NewParent
				if Child:IsA 'BasePart' then
					Child:MakeJoints()
				elseif Child:IsA 'Folder' then
					local Parts = SyncModule.Support.GetDescendantsWhichAreA(Child, 'BasePart')
					for _, Part in pairs(Parts) do
						Part:MakeJoints()
					end
				end
			end

			-- Track removing group
			SyncModule.LastParents[Group] = Group.Parent
			SyncModule.CreatedInstances[Group] = Group

			-- Remove group
			Group.Parent = nil
		end

		return Results
	end,

	['SetParent'] = function (Items, Parent)

		-- Validate arguments
		assert(type(Items) == 'table', 'Invalid items')
		assert(type(Parent) == 'table' or typeof(Parent) == 'Instance', 'Invalid parent')

		-- Check if items modifiable
		if not SyncModule.CanModifyItems(Items) then
			return
		end

		-- Check if parts intruding into private areas
		local Parts = SyncModule.GetPartsFromSelection(Items)
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player)
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return
		end

		-- Move each item to different parent
		if type(Parent) == 'table' then
			for Key, Item in pairs(Items) do
				local Parent = Parent[Key]

				-- Check if parent allowed
				assert(SyncModule.Security.IsLocationAllowed(Parent, SyncModule.Player), 'Permission denied for client')

				-- Move item
				Item.Parent = Parent
				if Item:IsA 'BasePart' then
					Item:MakeJoints()
				elseif Item:IsA 'Folder' then
					local Parts = SyncModule.Support.GetDescendantsWhichAreA(Item, 'BasePart')
					for _, Part in pairs(Parts) do
						Part:MakeJoints()
					end
				end
			end

			-- Move to single parent
		elseif typeof(Parent) == 'Instance' then
			assert(SyncModule.Security.IsLocationAllowed(Parent, SyncModule.Player), 'Permission denied for client')

			-- Reparent items
			for _, Item in pairs(Items) do
				Item.Parent = Parent
				if Item:IsA 'BasePart' then
					Item:MakeJoints()
				elseif Item:IsA 'Folder' then
					local Parts = SyncModule.Support.GetDescendantsWhichAreA(Item, 'BasePart')
					for _, Part in pairs(Parts) do
						Part:MakeJoints()
					end
				end
			end
		end

	end,

	['SetName'] = function (Items, Name)

		-- Validate arguments
		assert(type(Items) == 'table', 'Invalid items')
		assert(type(Name) == 'table' or type(Name) == 'string', 'Invalid name')

		-- Check if items modifiable
		if not SyncModule.CanModifyItems(Items) then
			return
		end

		-- Check if parts intruding into private areas
		local Parts = SyncModule.GetPartsFromSelection(Items)
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player)
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return
		end

		-- Rename each item to a different name
		if type(Name) == 'table' then
			for Key, Item in pairs(Items) do
				local Name = Name[Key]

				local FinalName = SyncModule.FilterText(Name) or ""

				Item.Name = FinalName
			end

			-- Rename to single name
		elseif type(Name) == 'string' then
			for _, Item in pairs(Items) do
				local FinalName = SyncModule.FilterText(Name) or ""

				Item.Name = FinalName
			end
		end

	end,

	['Remove'] = function (Objects)
		-- Removes the given objects

		-- Get the relevant parts for each object, for permission checking
		local Parts = {};

		-- Go through the selection
		for _, Object in pairs(Objects) do

			-- Make sure the object still exists
			if Object then

				if Object:IsA 'BasePart' then
					table.insert(Parts, Object);

				elseif Object:IsA 'Smoke' or Object:IsA 'Fire' or Object:IsA 'Sparkles' or Object:IsA 'DataModelMesh' or Object:IsA 'Decal' or Object:IsA 'Texture' or Object:IsA 'Light' or Object:IsA 'Attachment' then
					table.insert(Parts, Object.Parent);

				elseif Object:IsA 'TextLabel' then
					table.insert(Parts, Object.Parent.Parent);

				elseif Object:IsA 'Model' or Object:IsA 'Folder' then
					if game.Players:GetPlayerFromCharacter(Object) then return end
					SyncModule.Support.ConcatTable(Parts, SyncModule.Support.GetDescendantsWhichAreA(Object, 'BasePart'))
				end

			end;

		end;

		-- Check if items modifiable
		if not SyncModule.CanModifyItems(Objects) then
			return
		end 

		-- Check if parts intruding into private areas
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true) then
			return
		end

		-- After confirming permissions, perform each removal
		for _, Object in pairs(Objects) do
			if Object:IsDescendantOf(workspace) then
				-- Store the part's current parent
				SyncModule.LastParents[Object] = Object.Parent;

				-- Register the object
				SyncModule.CreatedInstances[Object] = Object;

				-- Set the object's current parent to `nil`
				Object.Parent = nil;
			end
		end;

	end;

	['UndoRemove'] = function (Objects)
		-- Restores the given removed objects to their last parents

		-- Get the relevant parts for each object, for permission checking
		local Parts = {};

		-- Go through the selection
		for _, Object in pairs(Objects) do

			-- Make sure the object still exists, and that its last parent is registered
			if Object and SyncModule.LastParents[Object] then

				if Object:IsA 'BasePart' then
					table.insert(Parts, Object);

				elseif Object:IsA 'Smoke' or Object:IsA 'Fire' or Object:IsA 'Sparkles' or Object:IsA 'DataModelMesh' or Object:IsA 'Decal' or Object:IsA 'Texture' or Object:IsA 'Light' or Object:IsA 'Attachment' then
					table.insert(Parts, Object.Parent);

				elseif Object:IsA 'TextLabel' then
					table.insert(Parts, Object.Parent.Parent);

				elseif Object:IsA 'Model' or Object:IsA 'Folder' then
					SyncModule.Support.ConcatTable(Parts, SyncModule.Support.GetDescendantsWhichAreA(Object, 'BasePart'))
				end

			end;

		end;

		-- Check if items modifiable
		if not SyncModule.CanModifyItems(Objects) then
			return
		end

		-- Check if parts intruding into private areas
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, false) then
			return
		end

		-- After confirming permissions, perform each removal
		for _, Object in pairs(Objects) do

			-- Store the part's current parent
			local LastParent = SyncModule.LastParents[Object];
			SyncModule.LastParents[Object] = Object.Parent;

			-- Register the object
			SyncModule.CreatedInstances[Object] = Object;

			-- Set the object's parent to the last parent
			Object.Parent = LastParent;

			-- Make joints
			if Object:IsA 'BasePart' then
				Object:MakeJoints()
			else
				local Parts = SyncModule.Support.GetDescendantsWhichAreA(Object, 'BasePart')
				for _, Part in pairs(Parts) do
					Part:MakeJoints()
				end
			end

		end;

	end;

	['SyncMove'] = function (Changes)
		-- Updates parts server-side given their new CFrames

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		local Models = {};
		local Attachments = {}
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			elseif Change.Attachments then
				table.insert(Attachments, Change.Attachment);
			elseif Change.Model then
				table.insert(Models, Change.Model)
			end
		end;

		-- Ensure parts are selectable
		if not (SyncModule.CanModifyItems(Parts) and SyncModule.CanModifyItems(Attachments) and SyncModule.CanModifyItems(Models)) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local PartChangeSet = {}
		local ModelChangeSet = {}
		local AttachmentChangeSet = {}
		for _, Change in ipairs(Changes) do
			if Change.Part then
				Change.InitialState = {
					Anchored = Change.Part.Anchored;
					CFrame = Change.Part.CFrame;
				}
				PartChangeSet[Change.Part] = Change
			elseif Change.Model then
				ModelChangeSet[Change.Model] = Change.Pivot
			elseif Change.Attachment then
				AttachmentChangeSet[Change.Attachment] = Change.WorldCFrame
			end
		end;

		local PartCFrames = {}
		local PartsToMove = {}

		-- Preserve joints
		for Part, Change in pairs(PartChangeSet) do
			Change.Joints = PreserveJoints(Part, PartChangeSet)
		end;

		local Count = 0

		-- Perform each change
		for Part, Change in pairs(PartChangeSet) do

			-- Stabilize the parts and maintain the original anchor state
			Part.Anchored = true;
			Part:BreakJoints();
			Part.Velocity = vector.zero;
			Part.RotVelocity = vector.zero;

			-- Set the part's CFrame

			table.insert(PartsToMove, Part)
			table.insert(PartCFrames, Change.CFrame)

			Count += 1

			if Count % 500 == 0 then
				task.wait()
			end
		end;

		game.Workspace:BulkMoveTo(PartsToMove, PartCFrames)

		for Model, Pivot in pairs(ModelChangeSet) do
			Model.WorldPivot = Pivot
		end
		for Attachment, WorldCFrame in pairs(AttachmentChangeSet) do
			Attachment.WorldCFrame = WorldCFrame
		end

		-- Make sure the player is authorized to move parts into this area
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, false, AreaPermissions) then

			local RevertCFrames =  {}
			local PartsToRevert = {}
			-- Revert changes if unauthorized destination
			for Part, Change in pairs(PartChangeSet) do
				table.insert(PartsToRevert, Part);
				table.insert(RevertCFrames, Change.InitialState.CFrame);
			end;

			game.Workspace:BulkMoveTo(PartsToRevert, RevertCFrames)
		end;

		-- Restore the parts' original states
		for Part, Change in pairs(PartChangeSet) do
			Part:MakeJoints();
			RestoreJoints(Change.Joints);
			Part.Anchored = Change.InitialState.Anchored;
		end;

	end;

	['SyncResize'] = function (Changes)
		-- Updates parts server-side given their new sizes and CFrames

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		local Meshes = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			elseif Change.Mesh then
				table.insert(Meshes, Change.Mesh);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local PartChangeSet = {};
		local MeshChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				Change.InitialState = { Anchored = Change.Part.Anchored, Size = Change.Part.Size, CFrame = Change.Part.CFrame };
				PartChangeSet[Change.Part] = Change;
			elseif Change.Mesh then
				Change.InitialState = { Scale = Change.Mesh.Scale, Offset = Change.Mesh.Offset };
				MeshChangeSet[Change.Mesh] = Change;
			end;
		end;

		-- Perform each change
		for Part, Change in pairs(PartChangeSet) do

			-- Stabilize the parts and maintain the original anchor state
			Part.Anchored = true;
			Part:BreakJoints();
			Part.Velocity = vector.zero;
			Part.RotVelocity = vector.zero;

			-- Set the part's size and CFrame
			Part.Size = Change.Size;
			Part.CFrame = Change.CFrame;

		end;

		for Mesh, Change in pairs(MeshChangeSet) do
			--print(Change.Scale)

			-- Set the part's size and CFrame
			Mesh.Scale = SyncModule.Options.StrictMeshResizing == true and RestrictMeshSize(Mesh, Change.Scale, false) or Change.Scale;
			Mesh.Offset = Change.Offset;

		end;

		-- Make sure the player is authorized to move parts into this area
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, false, AreaPermissions) then

			-- Revert changes if unauthorized destination
			for Part, Change in pairs(PartChangeSet) do
				Part.Size = Change.InitialState.Size;
				Part.CFrame = Change.InitialState.CFrame;
			end;

			for Mesh, Change in pairs(MeshChangeSet) do
				Mesh.Scale = Change.InitialState.Scale;
				Mesh.Offset = Change.InitialState.Offset;
			end;

		end;

		-- Restore the parts' original states
		for Part, Change in pairs(PartChangeSet) do
			Part:MakeJoints();
			Part.Anchored = Change.InitialState.Anchored;
		end;

	end;

	['SyncRotate'] = function (Changes)
		-- Updates parts server-side given their new CFrames

		-- Grab a list of every part and model we're attempting to modify
		local Parts = {};
		local Models = {};
		local Attachments = {}
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			elseif Change.Model then
				table.insert(Models, Change.Model)
			elseif Change.Attachment then
				table.insert(Attachments, Change.Attachment)
			end
		end;

		-- Ensure parts are selectable
		if not (SyncModule.CanModifyItems(Parts) and SyncModule.CanModifyItems(Models)) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local PartChangeSet = {}
		local ModelChangeSet = {}
		local AttachmentsChangeSet = {}
		for _, Change in pairs(Changes) do
			if Change.Part then
				Change.InitialState = {
					Anchored = Change.Part.Anchored;
					CFrame = Change.Part.CFrame;
				}
				PartChangeSet[Change.Part] = Change
			elseif Change.Model then
				ModelChangeSet[Change.Model] = Change.Pivot
			elseif Change.Attachment then
				AttachmentsChangeSet[Change.Attachment] = Change.WorldCFrame
			end
		end;

		-- Preserve joints
		for Part, Change in pairs(PartChangeSet) do
			Change.Joints = PreserveJoints(Part, PartChangeSet)
		end;

		-- Perform each change
		for Part, Change in pairs(PartChangeSet) do

			-- Stabilize the parts and maintain the original anchor state
			Part.Anchored = true;
			Part:BreakJoints();
			Part.Velocity = vector.zero;
			Part.RotVelocity = vector.zero;

			-- Set the part's CFrame
			Part.CFrame = Change.CFrame;

		end;
		for Model, Pivot in pairs(ModelChangeSet) do
			Model.WorldPivot = Pivot
		end
		for Attachment, WorldCFrame in pairs(AttachmentsChangeSet) do
			Attachment.WorldCFrame = WorldCFrame
		end

		-- Make sure the player is authorized to move parts into this area
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, false, AreaPermissions) then

			-- Revert changes if unauthorized destination
			for Part, Change in pairs(PartChangeSet) do
				Part.CFrame = Change.InitialState.CFrame;
			end;

		end;

		-- Restore the parts' original states
		for Part, Change in pairs(PartChangeSet) do
			Part:MakeJoints();
			RestoreJoints(Change.Joints);
			Part.Anchored = Change.InitialState.Anchored;
		end;

	end;

	['SyncColor'] = function (Changes)
		-- Updates parts server-side given their new colors

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Perform each change
		for Part, Change in pairs(ChangeSet) do

			-- Set the part's color
			Part.Color = Change.Color;

			-- If this part is a union, set its UsePartColor state
			if Part.ClassName == 'UnionOperation' or Part.ClassName == 'PartOperation' then
				Part.UsePartColor = Change.UnionColoring;
			end;

		end;

	end;

	['SyncSurface'] = function (Changes)
		-- Updates parts server-side given their new surfaces

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Enumerate every possible surface property
		local NameToSurface = {
			Right = "RightSurface",
			Top = "TopSurface",
			Back = "BackSurface",
			Left = "LeftSurface",
			Bottom = "BottomSurface",
			Front = "FrontSurface",
		}

		-- Perform each change
		for Part, Change in pairs(ChangeSet) do

			-- Apply each surface change
			for Surface, SurfaceType in pairs(Change.Surfaces) do
				-- Get the surface's name (if it exists)
				local SurfaceName = NameToSurface[Surface]

				-- Make sure it exists
				assert(SurfaceName, "[FORK3X]: An invalid surface name was submitted. Aborting.")

				-- Also check the surface type
				assert(typeof(SurfaceType) == "EnumItem" 
					and SurfaceType.EnumType == Enum.SurfaceType,
					"[FORK3X]: An invalid surface type has been submitted. Aborting.")

				-- If everything is correct, set the new surface type
				Part[SurfaceName] = SurfaceType;
			end;

		end;

	end;

	['CreateLights'] = function (Changes)
		-- Creates lights in the given parts

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Make a list of allowed light type requests
		local AllowedLightTypes = { PointLight = true, SurfaceLight = true, SpotLight = true };

		-- Keep track of the newly created lights
		local Lights = {};

		-- Create each light
		for Part, Change in pairs(ChangeSet) do

			-- Make sure the requested light type is valid
			if AllowedLightTypes[Change.LightType] then

				-- Create the light
				local Light = Instance.new(Change.LightType, Part);
				table.insert(Lights, Light);

				-- Register the light
				SyncModule.CreatedInstances[Light] = Light;

			end;

		end;

		-- Return the new lights
		return Lights;

	end;

	['SyncLighting'] = function (Changes)
		-- Updates aspects of the given selection's lights

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Make a list of allowed light type requests
		local AllowedLightTypes = { PointLight = true, SurfaceLight = true, SpotLight = true };

		-- Update each part's lights
		for Part, Change in pairs(ChangeSet) do

			-- Make sure that the light type requested is valid
			if AllowedLightTypes[Change.LightType] then

				-- Grab the part's light
				local Light = SyncModule.Support.GetChildOfClass(Part, Change.LightType);

				-- Make sure the light exists
				if Light then

					-- Make the requested changes
					if Change.Range ~= nil then
						Light.Range = Change.Range;
					end;
					if Change.Brightness ~= nil then
						Light.Brightness = Change.Brightness;
					end;
					if Change.Color ~= nil then
						Light.Color = Change.Color;
					end;
					if Change.Shadows ~= nil then
						Light.Shadows = Change.Shadows;
					end;
					if Change.Face ~= nil then
						Light.Face = Change.Face;
					end;
					if Change.Angle ~= nil then
						Light.Angle = Change.Angle;
					end;

				end;

			end;

		end;

	end;

	['CreateDecorations'] = function (Changes)
		-- Creates decorations in the given parts

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Make a list of allowed decoration type requests
		local AllowedDecorationTypes = { Smoke = true, Fire = true, Sparkles = true, ParticleEmitter = true, SelectionBox = true, Highlight = true};

		-- Keep track of the newly created decorations
		local Decorations = {};

		-- Create each decoration
		for Part, Change in pairs(ChangeSet) do

			-- Make sure the requested decoration type is valid
			if AllowedDecorationTypes[Change.DecorationType] and not Part:FindFirstChildOfClass(Change.DecorationType) then

				-- Create the decoration

				local Decoration = Instance.new(Change.DecorationType);
				if Change.DecorationType == ("SelectionBox" or "Highlight") then
					Decoration.Adornee = Part
				elseif Change.DecorationType == "ParticleEmitter" then
					SyncModule.LagFriendlyParts += 20
					if SyncModule.LagFriendlyParts > SyncModule.Options.LagFriendlyPartLimit then
						SyncModule.Options.BadBehaviorFunction(SyncModule.Player, SyncModule.Options.WebhookModule, "Lag", {Rate = SyncModule.LagFriendlyParts})
					end
				end
				
				Decoration.Parent = Part
				
				if Part:IsA("Attachment") and Decoration:IsA("ParticleEmitter") then
					Decoration.EmissionDirection = Enum.NormalId.Right
				end
				
				
				table.insert(Decorations, Decoration);

				-- Register the decoration
				SyncModule.CreatedInstances[Decoration] = Decoration;

			end;

		end;

		-- Return the new decorations
		return Decorations;

	end;

	['SyncDecorate'] = function (Changes)
		-- Updates aspects of the given selection's decorations

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Make a list of allowed decoration type requests
		local AllowedDecorationTypes = { Smoke = true, Fire = true, Sparkles = true, ParticleEmitter = true, Highlight = true, SelectionBox = true };

		-- Update each part's decorations
		for Part, Change in pairs(ChangeSet) do

			-- Make sure that the decoration type requested is valid
			if AllowedDecorationTypes[Change.DecorationType] then

				-- Grab the part's decoration
				local Decoration = SyncModule.Support.GetChildOfClass(Part, Change.DecorationType);

				-- Make sure the decoration exists
				if Decoration then

					-- Use the new, quicker method
					if Change.DecorationType == "ParticleEmitter" then
						-- Make a table with every whitelisted properties
						local AllowedProperties = {
							"Brightness",
							"Color",
							"LightEmission",
							"LightInfluence",
							"Orientation",
							"Size",
							"Squash",
							"Texture",
							"Transparency",
							"ZOffset",
							"EmissionDirection",
							"Lifetime",
							"Rate",
							"Rotation",
							"RotSpeed",
							"Speed",
							"SpreadAngle",
							"Shape",
							"ShapeInOut",
							"ShapePartial",
							"ShapeStyle",
							"FlipbookLayout",
							"FlipbookBlendFrames",
							"FlipbookFramerate",
							"FlipbookMode",
							"FlipbookSizeX",
							"FlipbookSizeY",
							"FlipbookStartRandom",
							"Acceleration",
							"Drag",
							"LockedToPart",
							"TimeScale",
						}

						local Conversions = {
							NumberRange = function(Input)
								local FirstValue, SecondValue = unpack( string.split(Input, ",") )

								if not SecondValue then
									return NumberRange.new( FirstValue )
								end

								if tonumber(FirstValue) and tonumber(SecondValue) then
									FirstValue, SecondValue = tonumber(FirstValue), tonumber(SecondValue)

									return NumberRange.new( math.min(FirstValue, SecondValue), math.max(FirstValue, SecondValue) )
								end
							end,

							NumberSequence = function(Input)
								local Values = string.split(Input, ",")

								if #Values == 1 and tonumber(Values[1]) then
									return NumberSequence.new(Values[1])
								end

								local Factor = 1 / (#Values - 1)

								local Sequence = {}

								for Index, Value in Values do
									if not tonumber(Value) then
										return
									end

									local Position = Factor * (Index - 1)

									local Keypoint = NumberSequenceKeypoint.new( Position, tonumber(Value) )

									Sequence[Index] = Keypoint
								end

								return NumberSequence.new(Sequence)
							end,

							ColorSequence = function(Input)
								return ColorSequence.new(Input)
							end,
						}

						for _, Property in AllowedProperties do
							if Change[Property] ~= nil then
								local Type = SyncModule.PropScan.GetPropertyType("ParticleEmitter", Property)

								local Value = Change[Property]

								if Conversions[Type] and type(Value) ~= Type then
									Value = Conversions[Type](Value)

									if Value == nil then
										continue
									end
								end

								--print(Property, Value)

								Decoration[Property] = Value
							end
						end

					else
						-- Make the requested changes
						if Change.Color ~= nil then
							if Change.DecorationType == "ParticleEmitter" then
								Decoration.Color = ColorSequence.new{
									ColorSequenceKeypoint.new(0, Change.Color),
									ColorSequenceKeypoint.new(1, Change.Color),
								}
							else
								Decoration.Color = Change.Color;
							end
						end;
						if Change.Opacity ~= nil then
							Decoration.Opacity = Change.Opacity;
						end;
						if Change.RiseVelocity ~= nil then
							Decoration.RiseVelocity = Change.RiseVelocity;
						end;
						if Change.Size ~= nil then
							if Change.DecorationType == "ParticleEmitter" then
								local FirstValue
								local SecondValue

								local CommaStart, CommaEnd = string.find(Change.Size, ",", 1)

								if CommaStart then
									FirstValue = tonumber(string.sub(Change.Size, 0, CommaEnd - 1)) or 1
									SecondValue = tonumber(string.sub(Change.Size, CommaEnd + 1, #Change.Size)) or 1
								else
									FirstValue = tonumber(Change.Size)
									SecondValue = tonumber(Change.Size)
								end

								Decoration.Size = NumberSequence.new(FirstValue, SecondValue)
							else
								Decoration.Size = Change.Size;
							end
						end;
						if Change.Heat ~= nil then
							Decoration.Heat = Change.Heat;
						end;
						if Change.SecondaryColor ~= nil then
							Decoration.SecondaryColor = Change.SecondaryColor;
						end;
						if Change.SparkleColor ~= nil then
							Decoration.SparkleColor = Change.SparkleColor;
						end;
						if Change.Rate ~= nil then
							if tonumber(Change.Rate) > 100 then
								Change.Rate = 100
							end
							Decoration.Rate = tonumber(Change.Rate);
						end;
						if Change.Speed ~= nil then
							local FirstValue
							local SecondValue

							local CommaStart, CommaEnd = string.find(Change.Speed, ",", 1)

							if CommaStart then
								FirstValue = tonumber(string.sub(Change.Speed, 0, CommaEnd - 1)) or 1
								SecondValue = tonumber(string.sub(Change.Speed, CommaEnd + 1, #Change.Speed)) or 1
							else
								FirstValue = tonumber(Change.Speed) or 1
								SecondValue = tonumber(Change.Speed) or 1
							end

							local Valid, Range = pcall(function() return NumberRange.new(FirstValue, SecondValue) end)

							if not Valid then
								Valid, Range = pcall(function() return NumberRange.new(SecondValue, FirstValue) end)
							end

							Decoration.Speed = Valid and Range or NumberRange.new(1)
						end;
						if Change.RotSpeed ~= nil then
							local FirstValue
							local SecondValue

							local CommaStart, CommaEnd = string.find(Change.RotSpeed, ",", 1)

							if CommaStart then
								FirstValue = tonumber(string.sub(Change.RotSpeed, 0, CommaEnd - 1)) or 1
								SecondValue = tonumber(string.sub(Change.RotSpeed, CommaEnd + 1, #Change.RotSpeed)) or 1
							else
								FirstValue = tonumber(Change.RotSpeed) or 1
								SecondValue = tonumber(Change.RotSpeed) or 1
							end

							local Valid, Range = pcall(function() return NumberRange.new(FirstValue, SecondValue) end)

							if not Valid then
								Valid, Range = pcall(function() return NumberRange.new(SecondValue, FirstValue) end)
							end

							Decoration.RotSpeed = Valid and Range or NumberRange.new(1)
						end;
						if Change.Transparency ~= nil then
							if Decoration:IsA("ParticleEmitter") then
								local FirstValue
								local SecondValue

								local CommaStart, CommaEnd = string.find(Change.Transparency, ",", 1)

								if CommaStart then
									FirstValue = tonumber(string.sub(Change.Transparency, 0, CommaEnd - 1)) or 1
									SecondValue = tonumber(string.sub(Change.Transparency, CommaEnd + 1, #Change.Transparency)) or 1
								else
									FirstValue = tonumber(Change.Transparency) or 1
									SecondValue = tonumber(Change.Transparency) or 1
								end

								Decoration.Transparency = NumberSequence.new(FirstValue, SecondValue)
							else
								Decoration.Transparency = Change.Transparency
							end
						end;
						if Change.Lifetime ~= nil then
							local FirstValue
							local SecondValue

							local CommaStart, CommaEnd = string.find(Change.Lifetime, ",", 1)

							if CommaStart then
								FirstValue = tonumber(string.sub(Change.Lifetime, 0, CommaEnd - 1)) or 1
								SecondValue = tonumber(string.sub(Change.Lifetime, CommaEnd + 1, #Change.Lifetime)) or 1
							else
								FirstValue = tonumber(Change.Lifetime) or 1
								SecondValue = tonumber(Change.Lifetime) or 1
							end

							local Valid, Range = pcall(function() return NumberRange.new(FirstValue, SecondValue) end)

							if not Valid then
								Valid, Range = pcall(function() return NumberRange.new(SecondValue, FirstValue) end)
							end

							Decoration.Lifetime = Valid and Range or NumberRange.new(1)
						end;
						if Change.Texture ~= nil then
							local Positive = SyncModule.Options.BlacklistImages and SyncModule.Options.BadBehaviorFunction(SyncModule.Player, SyncModule.Options.WebhookModule, "Image", {Image = Change.Texture}) or false
							if Positive == false then
								Decoration.Texture = Change.Texture
							end
						end;
						if Change.SpreadAngle ~= nil then
							Decoration.SpreadAngle = Vector2.new(math.abs(Change.SpreadAngle), (math.abs(Change.SpreadAngle)*-1))
						end;
						if Change.Orientation ~= nil then
							Decoration.Orientation = Change.Orientation
						end;
						if Change.Rotation ~= nil then
							local FirstValue
							local SecondValue

							local CommaStart, CommaEnd = string.find(Change.Rotation, ",", 1)

							if CommaStart then
								FirstValue = tonumber(string.sub(Change.Rotation, 0, CommaEnd - 1)) or 1
								SecondValue = tonumber(string.sub(Change.Rotation, CommaEnd + 1, #Change.Rotation)) or 1
							else
								FirstValue = tonumber(Change.Rotation) or 1
								SecondValue = tonumber(Change.Rotation) or 1
							end

							local Valid, Range = pcall(function() return NumberRange.new(FirstValue, SecondValue) end)

							if not Valid then
								Valid, Range = pcall(function() return NumberRange.new(SecondValue, FirstValue) end)
							end

							Decoration.Rotation = Valid and Range or NumberRange.new(1)
						end;
						if Change.LockedToPart ~= nil then
							Decoration.LockedToPart = Change.LockedToPart
						end;
						if Change.Acceleration ~= nil then
							local Weight = Change.Acceleration * -1
							Decoration.Acceleration = vector.create(0, Weight, 0)
						end;
						if Change.Color3 ~= nil then
							Decoration.Color3 = Change.Color3
						end;
						if Change.SurfaceColor3 ~= nil then
							Decoration.SurfaceColor3 = Change.SurfaceColor3
						end;
						if Change.SurfaceTransparency ~= nil then
							Decoration.SurfaceTransparency = Change.SurfaceTransparency
						end;
						if Change.LineThickness ~= nil then
							Decoration.LineThickness = Change.LineThickness
						end;
						if Change.FillColor ~= nil then
							Decoration.FillColor = Change.FillColor
						end;
						if Change.OutlineColor ~= nil then
							Decoration.OutlineColor = Change.OutlineColor
						end;
						if Change.OutlineTransparency ~= nil then
							Decoration.OutlineTransparency = Change.OutlineTransparency
						end;
						if Change.FillTransparency ~= nil then
							Decoration.FillTransparency = Change.FillTransparency
						end;
						if Change.DepthMode ~= nil then
							Decoration.DepthMode = Change.DepthMode
						end;
					end

				end;

			end;

		end;

	end;

	['CreateMeshes'] = function (Changes)
		-- Creates meshes in the given parts

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Keep track of the newly created meshes
		local Meshes = {};

		-- Create each mesh
		for Part, Change in pairs(ChangeSet) do

			-- Create the mesh
			local Mesh = Instance.new('SpecialMesh', Part);
			table.insert(Meshes, Mesh);

			-- Register the mesh
			SyncModule.CreatedInstances[Mesh] = Mesh;

		end;

		-- Return the new meshes
		return Meshes;

	end;

	['SyncMesh'] = function (Changes, KeepProportions)
		-- Updates aspects of the given selection's meshes

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		local NewMeshParts = {}

		-- Update each part's meshes
		for Part, Change in pairs(ChangeSet) do

			-- Grab the part's mesh
			local Mesh = SyncModule.Support.GetChildOfClass(Part, 'SpecialMesh');

			-- Make sure the mesh exists
			if Mesh then

				-- Make the requested changes
				if Change.VertexColor ~= nil then
					Mesh.VertexColor = Change.VertexColor;
				end;
				if Change.MeshType ~= nil then
					Mesh.MeshType = Change.MeshType;
				end;
				if Change.Scale ~= nil and Change.MeshId == nil then
					Mesh.Scale = RestrictMeshSize(Mesh, Change.Scale, true);
				end;
				if Change.Offset ~= nil then
					Mesh.Offset = Change.Offset;
				end;
				if Change.MeshId ~= nil then
					if Change.Scale ~= nil and SyncModule.Options.BetterMeshSizeControl == true then
						local AbsoluteSize = vector.one / Change.Scale
						if not SyncModule.Plugin then
							Mesh:SetAttribute("BTAbsoluteSize", AbsoluteSize)
						end

						if KeepProportions == 0 then
							Mesh.Scale = AbsoluteSize * Part.Size
						elseif KeepProportions ~= nil then
							local Axis = {
								X = math.abs(Change.Scale.X),
								Y = math.abs(Change.Scale.Y),
								Z = math.abs(Change.Scale.Z)
							}

							local BiggestDimensionSize = math.max(Axis.X, Axis.Y, Axis.Z)
							local BiggestDimensionName = SyncModule.Support.FindTableOccurrence(Axis, BiggestDimensionSize)

							local OriginalToFinalRatio = Part.Size[BiggestDimensionName] / BiggestDimensionSize

							Mesh.Scale = vector.create(OriginalToFinalRatio, OriginalToFinalRatio, OriginalToFinalRatio) --Change.Scale / Change.Scale[BiggestDimensionName] * OriginalToFinalRatio

							if KeepProportions == 2 then
								Part.Size = Mesh.Scale / AbsoluteSize
							end
						end
					end

					Mesh.MeshId = Change.MeshId;

				end;
				if Change.TextureId ~= nil then
					local Positive = SyncModule.Options.BlacklistImages and SyncModule.Options.BadBehaviorFunction(SyncModule.Player, SyncModule.Options.WebhookModule, "Image", {Image = Change.TextureId}) or false
					if Positive == false then
						Mesh.TextureId = Change.TextureId;
					end
				end;

			elseif Part:IsA("MeshPart") and (SyncModule.Options.ManipulateAnyMeshPart == true or Part:HasTag("BT_CanModifyMeshPart")) then
				if Change.MeshId ~= nil then

					local Success, NewMeshPart = pcall( AssetService.CreateMeshPartAsync, AssetService, Content.fromUri(Change.MeshId), {
						CollisionFidelity = SyncModule.Options.CollisionFidelity,
						RenderFidelity = SyncModule.Options.PartRenderFidelity
					} )

					if Success then

						local PartCustomProperties = SyncModule.PropScan.GetCustomPropertiesOfObject(Part)
						local PartTags = game:GetService("CollectionService"):GetTags(Part)
						local PartAttributes = Part:GetAttributes()
						local PartChildren = Part:GetChildren()

						local MeshPartOriginalSize = NewMeshPart.Size

						for Name, Value in PartCustomProperties do
							NewMeshPart[Name] = Value
						end

						for _, Name in PartTags do
							NewMeshPart:AddTag(Name)
						end

						for Name, Value in PartAttributes do
							NewMeshPart:SetAttribute(Name, Value)
						end

						for _, Object in PartChildren do
							Object.Parent = NewMeshPart
						end

						for _, Joint in Part:GetJoints() do
							if Joint.Part0 == Part then
								Joint.Part0 = NewMeshPart
							end

							if Joint.Part1 == Part then
								Joint.Part1 = NewMeshPart
							end
						end

						if KeepProportions ~= 0 then
							local Axis = {
								X = math.abs(MeshPartOriginalSize.X),
								Y = math.abs(MeshPartOriginalSize.Y),
								Z = math.abs(MeshPartOriginalSize.Z)
							}

							local BiggestDimensionSize = math.max(Axis.X, Axis.Y, Axis.Z)
							local BiggestDimensionName = SyncModule.Support.FindTableOccurrence(Axis, BiggestDimensionSize)

							local FinalToOriginalRatio = Part.Size[BiggestDimensionName] / BiggestDimensionSize

							--print(NewMeshPart, Part.Size[BiggestDimensionName], FinalToOriginalRatio, BiggestDimensionSize * FinalToOriginalRatio)

							NewMeshPart.Size = MeshPartOriginalSize * FinalToOriginalRatio--Change.Scale / Change.Scale[BiggestDimensionName] * OriginalToFinalRatio
						end

						if workspace.StreamingEnabled then
							NewMeshPart.Parent = SyncModule.Player
						end

						NewMeshPart.Parent = Part.Parent
						table.insert(NewMeshParts, NewMeshPart)

						Part:Destroy()

						Part = NewMeshPart
					end

				end;

				if Change.TextureID ~= nil then
					local Positive = SyncModule.Options.BlacklistImages and SyncModule.Options.BadBehaviorFunction(SyncModule.Player, SyncModule.Options.WebhookModule, "Image", {Image = Change.TextureId}) or false
					if Positive == false then
						Part.TextureID = Change.TextureID;
					end
				end;
			end;

		end;

		return NewMeshParts

	end;

	['CreateTextures'] = function (Changes)
		-- Creates textures in the given parts

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Make a list of allowed texture type requests
		local AllowedTextureTypes = { Texture = true, Decal = true };

		-- Keep track of the newly created textures
		local Textures = {};

		-- Create each texture
		for Part, Change in pairs(ChangeSet) do

			-- Make sure the requested light type is valid
			if AllowedTextureTypes[Change.TextureType] then

				-- Create the texture
				local Texture = Instance.new(Change.TextureType, Part);
				Texture.Face = Change.Face;
				table.insert(Textures, Texture);

				-- Register the texture
				SyncModule.CreatedInstances[Texture] = Texture;

			end;

		end;

		-- Return the new textures
		return Textures;

	end;

	['SyncTexture'] = function (Changes)
		-- Updates aspects of the given selection's textures

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Make a list of allowed texture type requests
		local AllowedTextureTypes = { Texture = true, Decal = true };

		-- Update each part's textures
		for Part, Change in pairs(ChangeSet) do

			-- Make sure that the texture type requested is valid
			if AllowedTextureTypes[Change.TextureType] then

				-- Get the right textures within the part
				for _, Texture in pairs(Part:GetChildren()) do
					if Texture.ClassName == Change.TextureType and Texture.Face == Change.Face then

						-- Perform the changes
						if Change.Texture ~= nil then
							local Positive = SyncModule.Options.BlacklistImages and SyncModule.Options.BadBehaviorFunction(SyncModule.Player, SyncModule.Options.WebhookModule, "Image", {Image = Change.Texture}) or false
							if Positive == false then
								Texture.Texture = Change.Texture
							end
						end;
						if Change.Transparency ~= nil then
							Texture.Transparency = Change.Transparency;
						end;
						if Change.StudsPerTileU ~= nil then
							Texture.StudsPerTileU = Change.StudsPerTileU;
						end;
						if Change.StudsPerTileV ~= nil then
							Texture.StudsPerTileV = Change.StudsPerTileV;
						end;
						if Change.Color3 ~= nil then
							Texture.Color3 = Change.Color3;
						end;

					end;
				end;

			end;

		end;

	end;

	['SyncAnchor'] = function (Changes)
		-- Updates parts server-side given their new anchor status

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		for _, Part in pairs(Parts) do
			if ChangeSet[Part].Anchored == false and Part.Anchored == true then
				SyncModule.LagFriendlyParts += 1
				coroutine.wrap(function() task.wait(60) SyncModule.LagFriendlyParts -= 1 end)()
			end
		end

		if SyncModule.LagFriendlyParts >= SyncModule.Options.LagFriendlyPartLimit then
			SyncModule.Options.BadBehaviorFunction(SyncModule.Player, SyncModule.Options.WebhookModule, "Anchor", { Parts = SyncModule.LagFriendlyParts })
			return
		end

		-- Perform each change
		for Part, Change in pairs(ChangeSet) do
			Part.Anchored = Change.Anchored;
			if Change.CFrame then
				Part.CFrame = Change.CFrame
			end
		end;

	end;

	['SyncCollision'] = function (Changes)
		-- Updates parts server-side given their new collision status

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Perform each change
		for Part, Change in pairs(ChangeSet) do
			Part.CanCollide = Change.CanCollide;
		end;

	end;

	['SyncMaterial'] = function (Changes)
		-- Updates parts server-side given their new material

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Perform each change
		for Part, Change in pairs(ChangeSet) do
			if Change.Material ~= nil then
				if typeof(Change.Material) ~= "EnumItem" and MaterialService:FindFirstChild(Change.Material, true) then
					Part.Material = MaterialService:FindFirstChild(Change.Material, true).BaseMaterial;
					Part.MaterialVariant = Change.Material
				else
					Part.Material = Change.Material;
					Part.MaterialVariant = ""
				end
			end;
			if Change.Transparency ~= nil then
				Part.Transparency = Change.Transparency;
			end;
			if Change.Reflectance ~= nil then
				Part.Reflectance = Change.Reflectance;
			end;
			if Change.Massless ~= nil then
				Part.Massless = Change.Massless;
			end;
			if Change.CastShadow ~= nil then
				Part.CastShadow = Change.CastShadow;
			end;
			if Change.CustomPhysicalProperties ~= nil and SyncModule.Options.CustomPhysicalPropertiesEditing == true then
				Part.CustomPhysicalProperties = Change.CustomPhysicalProperties;
			end;
			if Part:IsA("VehicleSeat") and SyncModule.Options.AllowExtraVehicleSeatsSettings == true then
				if Change.MaxSpeed ~= nil then
					Part.MaxSpeed = Change.MaxSpeed;
				end;
				if Change.TurnSpeed ~= nil then
					Part.TurnSpeed = Change.TurnSpeed;
				end;
				if Change.Torque ~= nil then
					Part.Torque = Change.Torque;
				end;
			end
		end;

	end;

	['CreateConstraints'] = function (PartsToAttach, Attachments, TargetPart, Type)
		-- Creates welds for the given parts to the target part
		-- Group every attachable into one table for use with RopeConstraints, RodConstraints and HingeConstraints

		if SyncModule.Options.ConstraintsBlacklist[Type] then
			return
		end

		local Parts = {}

		for _, PartToAttach in pairs(PartsToAttach) do
			if type(PartToAttach) == "table" then
				local Attachment = Instance.new("Attachment")
				Attachment.CFrame = PartToAttach.CFrame
				Attachment.Parent = PartToAttach.Part
				
				SyncModule.CreatedInstances[Attachment] = Attachment
				SyncModule.LastParents[Attachment] = Attachment.Parent
				
				table.insert(Parts, Attachment)
			else
				table.insert(Parts, PartToAttach)
			end
		end
		for _, Attachment in pairs(Attachments) do
			table.insert(Parts, Attachment)
		end

		-- If there is no target part, get the last part in the part list
		if not TargetPart then
			TargetPart = Parts[#Parts]
		end

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;
		
		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;
		
		local Constraints = {};

		-- Create the welds
		for _, Part in pairs(Parts) do

			-- Make sure we're not welding this part to itself
			if Part ~= TargetPart then

				if Type == "Weld" and table.find(PartsToAttach, Part) then

					-- Calculate the offset of the part from the target part
					local Offset = Part.CFrame:toObjectSpace(TargetPart.CFrame);

					-- Create the weld
					local Weld = Instance.new('Weld');
					Weld.Name = 'BTWeld';
					Weld.Part0 = TargetPart;
					Weld.Part1 = Part;
					Weld.C1 = Offset;
					Weld.Archivable = true;
					Weld.Parent = TargetPart;

					Weld:AddTag("BTConstraint")

					-- Register the weld
					SyncModule.CreatedInstances[Weld] = Weld;
					table.insert(Constraints, Weld);
				elseif SyncModule.Options.AvailableConstraints[Type] then
					local Attachment0
					local Attachment1

					if not Part:IsA("Attachment") and Part:FindFirstChild("BTAttachment") == nil then
						Attachment0 = Instance.new('Attachment');
						Attachment0.Name = 'BTAttachment';
						Attachment0.Parent = Part;
					elseif Part:IsA("Attachment") then
						Attachment0 = Part
					else
						Attachment0 = Part.BTAttachment
					end

					if not TargetPart:IsA("Attachment") and TargetPart:FindFirstChild("BTAttachment") == nil then
						Attachment1 = Instance.new('Attachment');
						Attachment1.Name = 'BTAttachment';
						Attachment1.Parent = TargetPart;
					elseif TargetPart:IsA("Attachment") then
						Attachment1 = TargetPart
					else
						Attachment1 = TargetPart.BTAttachment
					end

					-- Create the constraint
					local Constraint = Instance.new(Type);

					for Name, Value in SyncModule.Options.AvailableConstraints[Type] do
						Constraint[Name] = Value
					end

					Constraint.Attachment0 = Attachment0
					Constraint.Attachment1 = Attachment1

					Constraint.Parent = Attachment1
					
					Constraint:AddTag("BTConstraint")

					-- Register the constraint
					SyncModule.CreatedInstances[Constraint] = Constraint;
					table.insert(Constraints, Constraint);
				--[[
				elseif Type == "RopeConstraint" then

					local Attachment0
					local Attachment1

					if not Part:IsA("Attachment") and Part:FindFirstChild("BTAttachment") == nil then
						Attachment0 = Instance.new('Attachment');
						Attachment0.Name = 'BTAttachment';
						Attachment0.Parent = Part;
					elseif Part:IsA("Attachment") then
						Attachment0 = Part
					else
						Attachment0 = Part.BTAttachment
					end

					if not TargetPart:IsA("Attachment") and TargetPart:FindFirstChild("BTAttachment") == nil then
						Attachment1 = Instance.new('Attachment');
						Attachment1.Name = 'BTAttachment';
						Attachment1.Parent = TargetPart;
					elseif TargetPart:IsA("Attachment") then
						Attachment1 = TargetPart
					else
						Attachment1 = TargetPart.BTAttachment
					end

					local RopeConstraint = Instance.new('RopeConstraint');
					RopeConstraint.Name = 'BTRopeConstraint';
					RopeConstraint.Attachment0 = Attachment0;
					RopeConstraint.Attachment1 = Attachment1;
					RopeConstraint.Visible = true;
					RopeConstraint.Thickness = 0.5;
					RopeConstraint.Length = 20;
					RopeConstraint.Archivable = true;
					RopeConstraint.Parent = TargetPart;

					-- Register the weld
					SyncModule.CreatedInstances[RopeConstraint] = RopeConstraint;
					table.insert(Constraints, RopeConstraint);

				elseif Type == "RodConstraint" then

					local Attachment0
					local Attachment1

					if not Part:IsA("Attachment") and Part:FindFirstChild("BTAttachment") == nil then
						Attachment0 = Instance.new('Attachment');
						Attachment0.Name = 'BTAttachment';
						Attachment0.Parent = Part;
					elseif Part:IsA("Attachment") then
						Attachment0 = Part
					else
						Attachment0 = Part.BTAttachment
					end

					if not TargetPart:IsA("Attachment") and TargetPart:FindFirstChild("BTAttachment") == nil then
						Attachment1 = Instance.new('Attachment');
						Attachment1.Name = 'BTAttachment';
						Attachment1.Parent = TargetPart;
					elseif TargetPart:IsA("Attachment") then
						Attachment1 = TargetPart
					else
						Attachment1 = TargetPart.BTAttachment
					end

					local RodConstraint = Instance.new('RodConstraint');
					RodConstraint.Name = 'BTRodConstraint';
					RodConstraint.Attachment0 = Attachment0;
					RodConstraint.Attachment1 = Attachment1;
					RodConstraint.Visible = true;
					RodConstraint.Thickness = 0.5;
					RodConstraint.Length = 20;
					RodConstraint.Archivable = true;
					RodConstraint.Parent = TargetPart;

					-- Register the weld
					SyncModule.CreatedInstances[RodConstraint] = RodConstraint;
					table.insert(Constraints, RodConstraint);

				elseif Type == "HingeConstraint" then

					local Attachment0
					local Attachment1

					if not Part:IsA("Attachment") and Part:FindFirstChild("BTAttachment") == nil then
						Attachment0 = Instance.new('Attachment');
						Attachment0.Name = 'BTAttachment';
						Attachment0.Parent = Part;
					elseif Part:IsA("Attachment") then
						Attachment0 = Part
					else
						Attachment0 = Part.BTAttachment
					end

					if not TargetPart:IsA("Attachment") and TargetPart:FindFirstChild("BTAttachment") == nil then
						Attachment1 = Instance.new('Attachment');
						Attachment1.Name = 'BTAttachment';
						Attachment1.Parent = TargetPart;
					elseif TargetPart:IsA("Attachment") then
						Attachment1 = TargetPart
					else
						Attachment1 = TargetPart.BTAttachment
					end

					local HingeConstraint = Instance.new('HingeConstraint');
					HingeConstraint.Name = 'BTHingeConstraint';
					HingeConstraint.Attachment0 = Attachment0;
					HingeConstraint.Attachment1 = Attachment1;
					HingeConstraint.Visible = true;
					HingeConstraint.Archivable = true;
					HingeConstraint.Parent = TargetPart;

					-- Register the weld
					SyncModule.CreatedInstances[HingeConstraint] = HingeConstraint;
					table.insert(Constraints, HingeConstraint);
					]]
				end

			end;

		end;

		-- Return the welds created
		return Constraints;
	end;

	['RemoveConstraints'] = function (Welds, Type)
		-- Removes the given welds

		local Parts = {};

		-- Go through each weld
		for _, Weld in pairs(Welds) do

			-- Make sure each given weld is valid
			if Weld.ClassName ~= Type  then
				return;
			end;

			-- Collect the relevant parts for this weld
			if Type == 'Weld' then
				table.insert(Parts, Weld.Part0);
				table.insert(Parts, Weld.Part1);
			else
				table.insert(Parts, Weld.Attachment0.Parent);
				table.insert(Parts, Weld.Attachment1.Parent);
			end

		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		local WeldsRemoved = 0;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Go through each weld
		for _, Weld in pairs(Welds) do

			local Part0Unauthorized
			local Part1Unauthorized

			-- Check the permissions on each weld-related part
			if Type == 'Weld' then
				Part0Unauthorized = SyncModule.Security.ArePartsViolatingAreas({ Weld.Part0 }, SyncModule.Player, true, AreaPermissions);
				Part1Unauthorized = SyncModule.Security.ArePartsViolatingAreas({ Weld.Part1 }, SyncModule.Player, true, AreaPermissions);
			else
				Part0Unauthorized = SyncModule.Security.ArePartsViolatingAreas({ Weld.Attachment0.Parent }, SyncModule.Player, true, AreaPermissions);
				Part1Unauthorized = SyncModule.Security.ArePartsViolatingAreas({ Weld.Attachment1.Parent }, SyncModule.Player, true, AreaPermissions);	
			end

			-- If at least one of the involved parts is authorized, remove the weld
			if not Part0Unauthorized or not Part1Unauthorized then

				-- Register the weld
				SyncModule.CreatedInstances[Weld] = Weld;
				SyncModule.LastParents[Weld] = Weld.Parent;
				WeldsRemoved = WeldsRemoved + 1;

				-- Remove the weld
				Weld.Parent = nil;

			end;

		end;

		-- Return the number of welds removed
		return WeldsRemoved;
	end;

	['UndoRemovedConstraints'] = function (Welds, Type)
		-- Restores the given removed welds

		local Parts = {};

		-- Go through each weld
		for _, Weld in pairs(Welds) do

			-- Make sure each given weld is valid
			if Weld.ClassName ~= Type then
				return;
			end;

			-- Make sure each weld has its old parent registered
			if not SyncModule.LastParents[Weld] then
				return;
			end;

			-- Collect the relevant parts for this weld
			if Type == 'Weld' then
				table.insert(Parts, Weld.Part0);
				table.insert(Parts, Weld.Part1);
			else
				table.insert(Parts, Weld.Attachment0.Parent);
				table.insert(Parts, Weld.Attachment1.Parent);
			end

		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Go through each weld
		for _, Weld in pairs(Welds) do

			local Part0Unauthorized
			local Part1Unauthorized

			-- Check the permissions on each weld-related part
			if Type == 'Weld' then
				Part0Unauthorized = SyncModule.Security.ArePartsViolatingAreas({ Weld.Part0 }, SyncModule.Player, true, AreaPermissions);
				Part1Unauthorized = SyncModule.Security.ArePartsViolatingAreas({ Weld.Part1 }, SyncModule.Player, true, AreaPermissions);
			else
				Part0Unauthorized = SyncModule.Security.ArePartsViolatingAreas({ Weld.Attachment0.Parent }, SyncModule.Player, true, AreaPermissions);
				Part1Unauthorized = SyncModule.Security.ArePartsViolatingAreas({ Weld.Attachment1.Parent }, SyncModule.Player, true, AreaPermissions);	
			end

			-- If at least one of the involved parts is authorized, restore the weld
			if not Part0Unauthorized or not Part1Unauthorized then

				-- Store the part's current parent
				local LastParent = SyncModule.LastParents[Weld];
				SyncModule.LastParents[Weld] = Weld.Parent;

				-- Register the weld
				SyncModule.CreatedInstances[Weld] = Weld;

				-- Set the weld's parent to the last parent
				Weld.Parent = LastParent;

			end;

		end;

	end;

	['SyncConstraints'] = function (Changes)
		-- Updates aspects of the given selection's meshes

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Constraint and Change.Part:IsAncestorOf(Change.Constraint) then
				ChangeSet[Change.Constraint] = Change;
			end;
		end;

		-- Update each part's meshes
		for Constraint, Change in pairs(ChangeSet) do
			
			local ConstraintType = Change.Type
			
			-- Cancel if the type isn't allowed
			if not SyncModule.Options.AvailableConstraints[ConstraintType] then
				continue
			end
			
			--require(script.Parent.Parent.Libraries.PropScan)
			local ConstraintProperties = SyncModule.PropScan.GetPropertiesOfClass(ConstraintType, false)

			local AllowedTypes = {
				Color3 = true,
				ColorSequence = true,
				BrickColor = true,
				boolean = true,
				NumberSequence = true,
				NumberRange = true,
				number = true,
				string = true,
				EnumItem = true,
				Vector2 = true,
				Vector3 = true
			}
			
			local BlacklistedProperties = {
				Archivable = true,
				LocalTransparencyModifier = true,
				Name = true
			}
			
			local Conversions = {
				NumberRange = function(Input)
					local FirstValue, SecondValue = unpack( string.split(Input, ",") )

					if not SecondValue then
						return NumberRange.new( FirstValue )
					end

					if tonumber(FirstValue) and tonumber(SecondValue) then
						FirstValue, SecondValue = tonumber(FirstValue), tonumber(SecondValue)

						return NumberRange.new( math.min(FirstValue, SecondValue), math.max(FirstValue, SecondValue) )
					end
				end,

				NumberSequence = function(Input)
					local Values = string.split(Input, ",")

					if #Values == 1 and tonumber(Values[1]) then
						return NumberSequence.new(Values[1])
					end

					local Factor = 1 / (#Values - 1)

					local Sequence = {}

					for Index, Value in Values do
						if not tonumber(Value) then
							return
						end

						local Position = Factor * (Index - 1)

						local Keypoint = NumberSequenceKeypoint.new( Position, tonumber(Value) )

						Sequence[Index] = Keypoint
					end

					return NumberSequence.new(Sequence)
				end,

				ColorSequence = function(Input)
					return ColorSequence.new(Input)
				end,
				
				BrickColor = function(Input)
					return BrickColor.new(Input)
				end,
			}
			
			for _, Property in ConstraintProperties do
				local Type = SyncModule.PropScan.GetPropertyType(ConstraintType, Property)
				
				if Change[Property] ~= nil and not BlacklistedProperties[Property] and AllowedTypes[ Type ] then
					
					local Value = Change[Property]

					if Conversions[Type] then
						Value = Conversions[Type](Value)

						if Value == nil then
							continue
						end
					end
					
					if Property == "Segments" then
						Value = math.min(Value, 75)
					end

					Constraint[Property] = Value
				end
			end
			
			--[[
			for Name, Value in Change do
				local Type = SyncModule.PropScan.GetPropertyType(ConstraintType, Name)
				
				if ConstraintProperties[Name] and not BlacklistedProperties[Name] and AllowedTypes[ Type ] then
					if Conversions[Type] then
						Value = Conversions[Type](Value)

						if Value == nil then
							continue
						end
					end
					
					
					Constraint[Name] = Value
 				end
			end]]
			
			--[[
			-- Grab the part's mesh
			local Constraint = SyncModule.Support.GetChildOfClass(Part, 'RopeConstraint') or SyncModule.Support.GetChildOfClass(Part, 'RodConstraint') or SyncModule.Support.GetChildOfClass(Part, 'HingeConstraint');

			-- Make sure the mesh exists
			if Constraint then

				-- Make the requested changes
				if Change.Color ~= nil then
					Constraint.Color = Change.Color;
				end;
				if Change.Length ~= nil then
					Constraint.Length = Change.Length;
				end;
				if Change.Thickness ~= nil then
					Constraint.Thickness = Change.Thickness;
				end;
				if Change.Radius ~= nil then
					Constraint.Radius = Change.Radius;
				end;
				if Change.Visible ~= nil then
					Constraint.Visible = Change.Visible;
				end;
				if Change.ActuatorType ~= nil then
					Constraint.ActuatorType = Change.ActuatorType;
				end;
				if Change.Speed ~= nil then
					if Constraint.ActuatorType == Enum.ActuatorType.Servo then
						Constraint.AngularSpeed = Change.Speed;
					else
						Constraint.AngularVelocity = Change.Speed;
					end
				end;
				if Change.MaxSpeed ~= nil then
					if Constraint.ActuatorType == Enum.ActuatorType.Servo then
						Constraint.ServoMaxTorque = Change.MaxSpeed;
					else
						Constraint.MotorMaxTorque = Change.MaxSpeed;
					end
				end;
				if Change.TargetAngle ~= nil then
					Constraint.TargetAngle = Change.TargetAngle;
				end;


			end;]]

		end;

	end;
	
	['ExtractMeshFromAsset'] = function (AssetId)
		-- Returns the first found mesh in the given asset
		
		-- Figure out if the given asset is a mesh
		
		-- Create a variable to put what we want to return
		local Returned = AssetId
		
		-- Create a special mesh
		local TestMesh = Instance.new("SpecialMesh")
		
		-- Create the ID we'll put
		local ID = tonumber(AssetId) and "rbxassetid://" .. AssetId or AssetId
		
		-- Set the mesh's MeshId to the given ID
		TestMesh.MeshId = ID
		
		-- Use ContentProvider to load the mesh
		-- Use the function parameter to know if it's actually a mesh
		local ContentProvider = game:GetService("ContentProvider")
		
		local IsAMesh = false
		
		-- Preload the mesh and see what it returns
		ContentProvider:PreloadAsync({TestMesh}, function(AssetId, AssetFetchStatus)
			if AssetId == ID and AssetFetchStatus == Enum.AssetFetchStatus.Success then
				IsAMesh = true
			end
		end)
		
		-- If it's indeed a mesh, create a MeshPart to find its MeshSize property
		if IsAMesh then
			local IDContent = Content.fromUri(ID)
			
			local FetchingBeginsAt = os.clock()
			
			local Success, ReferenceMeshPart = pcall(AssetService.CreateMeshPartAsync, AssetService, IDContent)
			
			if not Success or os.clock() - FetchingBeginsAt >= 6 then

				Returned = {
					success = true,
					meshID = 0
				}
			end
			
			local Size = ReferenceMeshPart.MeshSize
			
			Returned = {
				success = true,
				meshID = AssetId,
				scale = Size,
			}
		end
		
		return Returned
	end;

	['ExtractImageFromDecal'] = function (DecalAssetId)
		local FinalID = tonumber(DecalAssetId)

		if not FinalID then
			return DecalAssetId
		else
			return "rbxthumb://type=Asset&id=" .. FinalID .. "&w=420&h=420"
		end
	end;

	['SetMouseLockEnabled'] = function (Enabled)
		-- Sets whether mouse lock is enabled for the current player

		-- Offload action to server-side if API is running locally
		if RunService:IsClient() and not RunService:IsStudio() then
			return SyncModule.SyncAPI.ServerEndpoint:InvokeServer('SetMouseLockEnabled', Enabled);
		end;

		-- Set whether mouse lock is enabled
		SyncModule.Player.DevEnableMouseLock = Enabled;

	end;

	['SetLocked'] = function (Items, Locked)
		-- Locks or unlocks the specified parts

		-- Validate arguments
		assert(type(Items) == 'table', 'Invalid items')
		assert(type(Locked) == 'table' or type(Locked) == 'boolean', 'Invalid lock state')

		-- Check if items modifiable
		if not SyncModule.CanModifyItems(Items) then
			return
		end

		-- Check if parts intruding into private areas
		local Parts = SyncModule.GetPartsFromSelection(Items)
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player)
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return
		end

		-- Set each item to a different lock state
		if type(Locked) == 'table' then
			for Key, Item in pairs(Items) do
				local Locked = Locked[Key]
				--		Item.Locked = Locked
				SyncModule.Options.SetPermission(Item, SyncModule.Player, "Lock", Locked)
			end

			-- Set to single lock state
		elseif type(Locked) == 'boolean' then
			for _, Item in pairs(Items) do
				--		Item.Locked = Locked
				SyncModule.Options.SetPermission(Item, SyncModule.Player, "Lock", Locked)
			end
		end

	end;

	["SearchAsset"] = function(Type, Input, Page, Settings)

		local Results

		--> Detect if the keyword arg is an ID, and if so, load only that audio instead:

		--> Request songs list from proxy server:
		if Type == "Decal" then
			if not Page then
				Page = 1
			end

			local Success, ErrorMessage = pcall(function()
				Results = SyncModule.Options.CheckDecalResult(InsertService:GetFreeDecalsAsync(Input, Page)[1].Results, Settings)
			end)

			if ErrorMessage then
				warn(ErrorMessage)
			end
		end

		if not Results then
			return {}, true
		else
			return Results, true, Page + 1
		end
	end;

	['CreateText'] = function (Changes)
		-- Creates textures in the given parts

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Keep track of the newly created textures
		local Texts = {};

		-- Create each texture
		for Part, Change in pairs(ChangeSet) do

			-- Make sure the requested light type is valid
			-- Create the texture
			local SurfaceGUI = Instance.new("SurfaceGui");
			SurfaceGUI.Parent = Part
			SurfaceGUI.Name = "F3XSurfaceGui"
			SurfaceGUI.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			SurfaceGUI.PixelsPerStud = 60
			SurfaceGUI.Face = Change.Face;	
			local Text = Instance.new("TextLabel");
			Text.BackgroundTransparency = 1;
			Text.Size = UDim2.new(1, 0, 1, 0);
			Text.TextScaled = true;
			Text.RichText = false;
			Text.Font = Enum.Font.Arimo;
			Text.Text = "Use the text tool to edit me.";
			Text.TextTransparency = 0;
			Text.TextColor3 = Color3.fromRGB(255, 255, 255);
			Text.Parent = SurfaceGUI;




			table.insert(Texts, Text);

			-- Register the texture
			SyncModule.CreatedInstances[SurfaceGUI] = SurfaceGUI;
			SyncModule.CreatedInstances[Text] = Text;

		end;

		-- Return the new textures
		return Texts;

	end;

	['SyncText'] = function (Changes)
		-- Updates aspects of the given selection's textures

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Surface then
				ChangeSet[Change.Surface] = Change;
			end;
		end;
		
		-- Make a list of allowed texture type requests

		-- Update each part's textures
		for Surface, Change in pairs(ChangeSet) do

			-- Make sure that the texture type requested is valid
			-- Get the right textures within the part
			if Surface.ClassName == "SurfaceGui" and Surface.Name == "F3XSurfaceGui" and Surface.Face == Change.Face then
				for _, Text in Surface:GetChildren() do
					if Text.ClassName == "TextLabel" then
						-- Perform the changes
						if Change.Text ~= nil then
							local FinalText = SyncModule.FilterText(Change.Text) or ""
							
							Text.Text = FinalText

						end;
						if Change.TextTransparency ~= nil then
							Text.TextTransparency = Change.TextTransparency;
						end;
						if SyncModule.Options.CanUseRichText and Change.RichText ~= nil then
							Text.RichText = Change.RichText;

							local FinalText = SyncModule.FilterText(Text.Text) or ""
							Text.Text = FinalText
						end;
						if Change.Font ~= nil then
							if typeof(Change.Font) == "EnumItem" then
								Text.Font = Change.Font;
							else
								Text.FontFace = Change.Font;
							end
						end;
						if Change.TextColor3 ~= nil then
							Text.TextColor3 = Change.TextColor3;
						end;

					end;
				end;
			end;
		end;

	end;

	['SyncTransform'] = function (Changes)
		-- Updates parts server-side with the given changes

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the SyncModule.Player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Get the custom part types
		local CustomPartTypes = SyncModule.Options.CustomPartTypes

		-- If it's a function, get its result
		if type(CustomPartTypes) == "function" then 
			CustomPartTypes = SyncModule.Options.CustomPartTypes() 
		end

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		local PartsToReturn = {}

		local AvailableTypes = {
			Part = "Part",
			Seat = "Seat",
			VehicleSeat = "VehicleSeat",
			Spawn = "SpawnLocation",
			MeshPart = "MeshPart",
		}

		-- Perform each change
		for Part, Change in pairs(ChangeSet) do

			local IsForbiddenMeshPart = Part:IsA("MeshPart") and not ( SyncModule.Options.ManipulateAnyMeshPart == true 
				or Part:HasTag("BT_CanModifyMeshPart") 
				or not RunService:IsRunning() )

			if Change.Shape ~= nil and Part:IsA("Part") then
				Part.Shape = Change.Shape;
			end

			if Change.Type ~= nil and AvailableTypes[Change.Type] and not IsForbiddenMeshPart then
				local Parent = Part.Parent

				local NewPart = SyncModule.ConvertPartToType(Part, AvailableTypes[Change.Type])

				if NewPart:IsA("MeshPart") then
					NewPart:AddTag("BT_CanModifyMeshPart")
				end

				if workspace.StreamingEnabled then
					NewPart.Parent = SyncModule.Player
				end

				table.insert(PartsToReturn, NewPart)

				NewPart.Parent = Parent
			end
			-- and CanConvertToType(CustomPartTypes[Change.SubType])
			
			if Change.SubType ~= nil then
				local SubType = CustomPartTypes[Change.SubType]

				local Parent = Part.Parent
				
				local CurrentSubTypeName = Part:GetAttribute("BTSubType")
				
				if CurrentSubTypeName ~= Change.SubType and (SubType or Change.SubType == "Default") then
					if CurrentSubTypeName then
						local CurrentReference = CustomPartTypes[CurrentSubTypeName].Create(SyncModule.Player)
						
						local CurrentData = SyncModule.GetObjectData(CurrentReference)
						
						for Index, Value in CurrentData do
							if Index == "Tags" then
								
								for _, TagName in Value do
									Part:RemoveTag(TagName)
								end
							elseif Index == "Attributes" then
								
								for AttributeName in Value do
									Part:SetAttribute(AttributeName, nil)
								end
							elseif Index == "Properties" and CustomPartTypes[CurrentSubTypeName].IgnorePropertiesWhenConverting == false then
								
								local PartProperties = SyncModule.PropScan.GetPropertiesOfClass(Part.ClassName, false)
								
								local Blacklist = table.clone(PropertiesBlacklist)
								
								if Change.SubType == "Default" then
									Blacklist.TopSurface = true
									Blacklist.BottomSurface = true
								end
								
								for _, PropertyName in PartProperties do
									if Value[PropertyName] == Part[PropertyName] and not Blacklist[PropertyName] then
										Part:ResetPropertyToDefault(PropertyName)
									end
								end
							end
						end
					end
					
					if SubType then
						local Source = SubType.Create(SyncModule.Player)

						SyncModule.TransferDataFromObjectToObject(Source, Part, {
							Properties = SubType.IgnorePropertiesWhenConverting,
							Children = SubType.IgnoreChildrenWhenConverting
						})

						Part:SetAttribute("BTSubType", Change.SubType)
					else
						Part:SetAttribute("BTSubType", nil)
					end

					table.insert(PartsToReturn, Part)
				end
			end
			
			--[[
			if Change.SubType ~= nil 
				and AvailableTypes[Part.ClassName] 
				and ( CustomPartTypes[Change.SubType] and CanConvertToType(CustomPartTypes[Change.SubType])
					or Change.SubType == "Default") then

				if Change.SubType == "Default" and Part:GetAttribute("FORK3X_Changed") then

					local Changes = HttpService:JSONDecode( Part:GetAttribute("FORK3X_Changed") )

					local ResetActions = {
						Properties = function()
							local WhatToReset = Changes.Properties == true and SyncModule.PropScan.GetPropertiesOfClass(Part.ClassName)
								or Changes.Properties

							for _, Name in WhatToReset do
								Part:ResetPropertyToDefault(Name)
							end
						end,

						Attributes = function()
							local WhatToReset = Changes.Attributes == true and Part:GetAttributes()
								or SyncModule.Support.FlipTable(Changes.Attributes)

							for Name in WhatToReset do
								Part:SetAttribute(Name, nil)
							end
						end,

						Tags = function()
							local WhatToReset = Changes.Tags == true and Part:GetTags()
								or Changes.Tags

							for _, Name in WhatToReset do
								Part:RemoveTag(Name)
							end
						end,

						Children = function()
							local WhatToReset = Changes.Children == true and Part:QueryDescendants(".FORK3X_SubType")
								or Changes.Children

							for _, Object in WhatToReset do
								Object:Destroy()
							end
						end,
					}

					for Name in Changes do
						if ResetActions[Name] then
							ResetActions[Name]()
						end
					end

					Part:SetAttribute("FORK3X_Changed", nil)

				else
					local SubType = CustomPartTypes[Change.SubType]

					local Parent = Part.Parent
					
					--[[
					if type(SubType.Convert) == "function" then
						local NewPart = SubType:Convert(SyncModule, Part)

						if workspace.StreamingEnabled then
							NewPart.Parent = SyncModule.Player
						end

						table.insert(PartsToReturn, NewPart)

						NewPart.Parent = Parent
					else
						
						
						local NewReference = SubType.Create()
						
						SyncModule.TransferDataFromObjectToObject(NewReference, Part, SubType.Convert)

						--SyncModule.TrackSubTypeChanges(Part, SubType.Convert)

						table.insert(PartsToReturn, Part)
					end
				end
			end]]

		end;

		return PartsToReturn

	end;

	['OldCreateUnion'] = function (Parts, NegativeParts, Split, Intersect)

		local AllParts = SyncModule.Support.Merge(table.clone(Parts), NegativeParts)

		if not SyncModule.CanModifyItems(AllParts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(AllParts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- First, negate the parts.
		local NegatedUnions = {}
		local GeometryService = game:GetService("GeometryService")

		for _, NormalPart in ipairs(Parts) do
			local NegatedParts
			if #NegativeParts ~= 0 then
				NegatedParts = GeometryService:SubtractAsync(NormalPart, NegativeParts)
				for _, NegatedPart in NegatedParts do
					table.insert(NegatedUnions, NegatedPart)
					if game.Workspace.StreamingEnabled then
						NegatedPart.Parent = SyncModule.Player
					end

					NegatedPart.Parent = NormalPart.Parent
				end
			else
				table.insert(NegatedUnions, NormalPart)
			end
		end

		local FinalUnion = {}

		local NegatedPart = NegatedUnions[1]
		local FinalUnions = {NegatedPart}

		if #NegatedUnions > 1 then
			table.remove(NegatedUnions, 1)
		end

		if #NegatedUnions ~= 0 then	
			FinalUnions = not Intersect and 
				GeometryService:UnionAsync(NegatedPart, NegatedUnions, {
					CollisionFidelity = Enum.CollisionFidelity.Hull,
					RenderFidelity = Enum.RenderFidelity.Performance,
					FluidFidelity = Enum.FluidFidelity.Automatic,
					SplitApart = Split}) or
				GeometryService:IntersectAsync(NegatedPart, NegatedUnions, {
					CollisionFidelity = Enum.CollisionFidelity.Hull,
					RenderFidelity = Enum.RenderFidelity.Automatic,
					FluidFidelity = Enum.FluidFidelity.Automatic,
					SplitApart = Split})
		end

		for _, PartToDelete in ipairs(NegatedUnions) do
			if PartToDelete:IsA("TriangleMeshPart") then
				-- Store the part's current parent
				SyncModule.LastParents[PartToDelete] = PartToDelete.Parent;

				-- Register the object
				SyncModule.CreatedInstances[PartToDelete] = PartToDelete;

				-- Set the object's current parent to `nil`
				PartToDelete.Parent = nil;
			end
		end

		for _, Part in ipairs(AllParts) do
			-- Store the part's current parent
			SyncModule.LastParents[Part] = Part.Parent;

			-- Register the object
			SyncModule.CreatedInstances[Part] = Part;

			-- Set the object's current parent to `nil`
			Part.Parent = nil;
		end

		for _, Union in FinalUnions do
			if SyncModule.Player and game.Workspace.StreamingEnabled then
				Union.Parent = SyncModule.Player
			end

			Union.Parent = AllParts[1] and AllParts[1].Parent or game.Workspace
		end

		return FinalUnions
	end;

	['ConvertUnion'] = function (Unions)
		-- Do not proceed if this function is run by the tool
		if not SyncModule.Plugin then
			return
		end

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Unions) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Unions), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Unions, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Use CSGTree's built-in function to convert the unions
		local ConvertedUnions = SyncModule.CSGTreeV2.RobloxToCSGTree(Unions)

		-- JSON encode the result so it can be set as Fork3X-compatible attribute
		for Union, Data in ConvertedUnions do
			local EncodedData = HttpService:JSONEncode(Data)

			Union:SetAttribute("BTUnionData", EncodedData)
		end

		return Unions
	end;

	['CreateUnion'] = function (GivenParts, GivenNegativeParts, Split, Intersect)
		local AllParts = SyncModule.Support.ConcatTable(table.clone(GivenParts), GivenNegativeParts)

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(AllParts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(AllParts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(AllParts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		local PositiveUnions = {}
		local PositiveParts = {}
		local NegativeUnions = {}
		local NegativeParts = {}

		-- Set up every objects
		for _, Part in GivenParts do
			if Part:IsA("TriangleMeshPart") and Part:GetAttribute("BTUnionData") then
				PositiveUnions[Part] = HttpService:JSONDecode(Part:GetAttribute("BTUnionData"))
			else
				PositiveParts[#PositiveParts + 1] = Part
			end
		end

		for _, Part in GivenNegativeParts do
			if Part:IsA("TriangleMeshPart") and Part:GetAttribute("BTUnionData") then
				NegativeUnions[Part] = HttpService:JSONDecode(Part:GetAttribute("BTUnionData"))
			else
				NegativeParts[#NegativeParts + 1] = Part
			end
		end

		local Focus = SyncModule.Support.Keys(PositiveUnions)[1] or PositiveParts[1]

		if not Focus or #PositiveParts == 0 and #NegativeParts == 0 and SyncModule.Support.CountKeys(PositiveUnions) == 1 then
			return
		end

		-- Create the normal parts' leaves
		local PartsLeaf = SyncModule.CSGTreeV2.CreateLeafFromItems(PositiveParts, Focus.CFrame, 1)
		local NegativePartsLeaf = SyncModule.CSGTreeV2.CreateLeafFromItems(NegativeParts, Focus.CFrame, 2)

		local function SetUpUnion(Union, Data, Type)
			-- Create a parenthesis from the data
			local NewData = SyncModule.CSGTreeV2.CreateParenthesisWithTree(Data, Type)

			-- Offset the data from the focus
			if Union ~= Focus then
				SyncModule.CSGTreeV2.OffsetLeafFromUnion(NewData, Union, Focus)
			end

			-- Write the properties of the union
			SyncModule.CSGTreeV2.TrackUnionProperties(NewData, Union)

			return NewData
		end

		-- Set up the unions
		for Union, Data in PositiveUnions do
			PositiveUnions[Union] = SetUpUnion(Union, Data, 1)
		end

		for Union, Data in NegativeUnions do
			NegativeUnions[Union] = SetUpUnion(Union, Data, 2)
		end

		local Tree = SyncModule.CSGTreeV2.CreateTree()
		local Method = Intersect and SyncModule.CSGTreeV2.Intersect or SyncModule.CSGTreeV2.Union

		-- Insert each category of objects in the new tree
		for Union, Data in PositiveUnions do
			Method(Tree, Data)
		end

		Method(Tree, PartsLeaf)

		SyncModule.CSGTreeV2.Negate(Tree, NegativePartsLeaf)

		for Union, Data in NegativeUnions do
			SyncModule.CSGTreeV2.Negate(Tree, Data)
		end

		-- Clean the tree before building
		--	CSGTreeV1.RemoveBlanks(Tree)

		local Parameters = table.clone(ShapeParameters)
		Parameters.SplitApart = Split

		local Result, UnionCFrame = SyncModule.CSGTreeV2.CreateUnionFromTree(Tree, Focus.CFrame, Parameters)--, SyncModule.Support.Merge(PositiveUnions, NegativeUnions))

		local EncodedTree = HttpService:JSONEncode(Tree)

		for _, Part in Result do
			local CurrentTree = EncodedTree

			if Split == true then
				local NewTree = table.clone(Tree)

				SyncModule.CSGTreeV2.SplitFromUnion(NewTree, UnionCFrame, Part)

				CurrentTree = HttpService:JSONEncode(NewTree)
			end

			Part:SetAttribute("BTUnionData", CurrentTree)

			if SyncModule.Player and workspace.StreamingEnabled then
				Part.Parent = SyncModule.Player
			end

			Part.Parent = Focus.Parent

			SyncModule.CreatedInstances[Part] = Part
			SyncModule.LastParents[Part] = Part.Parent
		end

		return Result
	end;

	['CreateAttachments'] = function (Changes)
		-- Creates meshes in the given parts

		-- Grab a list of every part we're attempting to modify
		local Parts = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Parts, Change.Part);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Keep track of the newly created attachments
		local Attachments = {};

		-- Create each mesh
		for Part, Change in pairs(ChangeSet) do

			-- Create the mesh
			local Attachment = Instance.new('Attachment', Part);
			Attachment.CFrame = Change.CFrame or CFrame.new()
			table.insert(Attachments, Attachment);

			-- Register the mesh
			SyncModule.CreatedInstances[Attachment] = Attachment;

		end;

		-- Return the new meshes
		return Attachments;

	end;

	['SyncAttachments'] = function (Changes)
		-- Updates aspects of the given selection's meshes

		-- Grab a list of every part we're attempting to modify
		local Attachments = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				table.insert(Attachments, Change.Attachment);
			end;
		end;

		-- Ensure parts are selectable
		if not SyncModule.CanModifyItems(Attachments) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Attachments), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Attachments, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Attachment then
				ChangeSet[Change.Attachment] = Change;
			end;
		end;

		-- Update each part's meshes
		for Attachment, Change in pairs(ChangeSet) do

			-- Make the requested changes
			if Change.Visible ~= nil then
				Attachment.Visible = Change.Visible;
			end;
			if Change.Position ~= nil then
				Attachment.Position = Change.Position;
			end;
			if Change.Name ~= nil then
				local FinalName = SyncModule.FilterText(Change.Name) or ""

				Attachment.Name = FinalName;
			end;

		end;

	end;

	['CheckDataStores'] = function()
		local FinalValue = _G.DataStoresEnabled
		
		if FinalValue == nil then
			local Success, Result = pcall(function()
				return DataStoreService:GetDataStore("a")
			end)

			_G.DataStoresEnabled = Success
			FinalValue = Success
		end

		return FinalValue
	end,


	['FetchSaves'] = function()
		return SyncModule.Support.ToStringIndexes( GetSlots().Client ), SyncModule.SlotsTotalSize
	end,

	['ChangeSave'] = function(Slot, Parts, Name)
		-- Ensure everything is right to change data and one isn't using remotes to go against the set limit
		if SyncModule.Player == nil or Slot > SyncModule.Options.NumberOfSaveSlots then
			return;
		end;

		-- Put what changed here
		local Changes = {}

		-- If there are parts, ensure they are selectable
		if Parts then
			if not SyncModule.CanModifyItems(Parts) then
				return;
			end;

			-- Cache up permissions for all private areas
			local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Parts), SyncModule.Player);

			-- Make sure the player is allowed to access these parts
			if SyncModule.Security.ArePartsViolatingAreas(Parts, SyncModule.Player, true, AreaPermissions) then
				return;
			end;

			-- Get all descendants of the parts
			local Items = SyncModule.Support.CloneTable(Parts);
			for _, Part in Parts do
				SyncModule.Support.ConcatTable(Items, Part:GetDescendants());
			end;

			-- Pass through the SyncModule.Options.PreSerialization function for extra controls
			if SyncModule.Options.PreSerializaton then
				if SyncModule.Options.PreSerialization(Items, SyncModule.Player) ~= true then
					return false, "Fork3X's configuration denied your save.", [[Own this game? Make sure to return <b>true</b> at the end of the PreSerialization function if nothing's wrong.
				
				If nothing is wrong, you may have selected parts you aren't in measure to serialize, or another element forbids you to save.]]
				end
			end

			-- After confirming permissions, serialize parts
			local Error

			local Success, SerializedBuildData = xpcall(SyncModule.SerializationV6.SerializeModel, function(TheError) 
				Error = debug.traceback(TheError) 
			end
			, Items, nil);

			-- Update the data in the SlotsData table (encoding is done to avoid irregular dictionary <-> table conversions when saving)
			local JSONTable = HttpService:JSONEncode(SerializedBuildData)

			-- Check if the data fits with the size limits
			local TotalSizeWithoutPreviousData = GetSlots().Client[Slot] and SyncModule.SlotsTotalSize - GetSlots().Client[Slot].Size or SyncModule.SlotsTotalSize
			local RawSize = GetRawSize(JSONTable)
			local NewTotalSize = TotalSizeWithoutPreviousData + RawSize

			if #Parts ~= 0 then
				if SyncModule.Options.SizeLimit < 0 and NewTotalSize > math.abs(SyncModule.Options.SizeLimit :: number) then
					return false, "Your slot doesn't fit the global size limit.", 
					"Own this game? You can edit the tool's SyncModule.Options and increase the limit if you find it too small."
				elseif SyncModule.Options.SizeLimit > 0 and GetRawSize(JSONTable) > SyncModule.Options.SizeLimit then
					return false, "Your slot is bigger than the maximum slot size.", 
					"Own this game? You can edit the tool's SyncModule.Options and increase the limit if you find it too small."
				end
			end

			-- Return creation ID on success
			if Success == true and SerializedBuildData and SyncModule.BuildsDatastore then
				if #Parts == 0 then
					SyncModule.BuildsDatastore:RemoveAsync("Slot" .. Slot, nil)--SerializedBuildData)

					GetSlots().Data[Slot] = nil
				else
					SyncModule.BuildsDatastore:SetAsync("Slot" .. Slot, "Fork3X Save: " .. tostring(JSONTable))--SerializedBuildData)

					GetSlots().Data[Slot] = SerializedBuildData
				end
			elseif Error then
				return false, 'Fork3X experienced an unexpected error while serializing. You can find it in the "What can I do?" section.',
				[[If this build of Fork3X isn't modified, report to the Fork3X creator the following error. Don't worry, your username has been removed:
				
<font size="10">]] .. string.gsub(Error, "." .. SyncModule.Player.Name, "[PLAYER]") .. [[</font>]]
			end;

			SyncModule.SlotsTotalSize = NewTotalSize

			Changes.Preview = RawSize < SyncModule.Options.NoPreviewBeyond and SerializedBuildData or nil
			Changes.Size = RawSize
			Changes.Version = 6
		end

		if Name and Name ~= "" then
			if #Name > SyncModule.Options.RenamingCharacterLimit then
				return false, nil
			end

			local DefaultSlotName = "Slot " .. Slot
			local SlotName = SyncModule.Options.AllowRenaming and Name ~= DefaultSlotName and Name or nil

			if SyncModule.BuildsDatastore then
				SyncModule.BuildsDatastore:SetAsync("Name" .. Slot, SlotName)
			end

			Changes.Name = SlotName
		end

		local SlotList = GetSlots().Client
		local Save = SlotList[Slot]

		if not Save then
			SlotList[Slot] = {
				Name = "Slot" .. Slot,
			}

			Save = SlotList[Slot]
		end

		for Name, Value in Changes do
			Save[Name] = Value
		end

		return true, Changes
	end,

	['LoadSave'] = function (Slot, UseSecondary)

		-- Ensure there are items to export
		if SyncModule.Player == nil then
			return;
		end;

		-- Make sure the loading ability isn't under cooldown
		if not SyncModule.Plugin then
			if GetGlobal("CanLoad") == false then
				-- In case there was a synchronisation issue, just check again after waiting a bit

				task.wait(0.2)
				if GetGlobal("CanLoad") == false then
					return
				end
			end

			if SyncModule.Options.LoadDelay ~= 0 then
				SetGlobal("CanLoad", false)
				SetGlobal("CanLoadEnableFunction", task.delay( SyncModule.Options.LoadDelay, function() 
					SetGlobal("CanLoad", nil) 
					SetGlobal("CanLoadEnableFunction", nil) 
				end) )
			end
		end

		-- After confirming permissions, serialize parts
		local Build = GetSlots().Data[Slot]

		-- Return creation ID on success
		if Build then
			local Success, WhereToSpawn = pcall(SyncModule.Options.GetScope, SyncModule.Player)

			if not Success then
				WhereToSpawn = workspace
				if not SyncModule.WarnedAbout.GetScope then
					warn("[FORK3X]: Fork3X has run into an error when trying to parent your build, and parented it into workspace. This may be because the SyncModule.Options.GetScope function uses client-only code.\n\n More information can be found on github.com/VikkoMakesStuff/Fork3X/wiki/Options#getscope")
					WarnedAbout.GetScope = true
				end
			end

			local Container = Instance.new( 'Model' );
			Container.Name = SyncModule.Player.Name ..'BTLoad';

			local UsedModule = Build.Version == 3 and SyncModule.SerializationV4 
				or Build.Version == 4 and SyncModule.SerializationV4 
				or Build.Version == 5 and SyncModule.SerializationV5 
				or SyncModule.SerializationV6

			if SyncModule.Options.PreInflation then
				local InflatedData = SyncModule.Options.PreInflation(Build, SyncModule.Player)

				if InflatedData then
					for _, Item in InflatedData do
						Item.Parent = Container
					end
				end
			end
			
			local Error

			local Success, LoadedModel = xpcall(UsedModule.InflateBuildData, function(TheError) 
				Error = debug.traceback(TheError) 
			end
			, Build);
			
			if not Success then
				error(Error)
			end
			
			for _, Part in LoadedModel do
				Part.Parent = Container;

				SyncModule.Options.SetPermission(Part, SyncModule.Player, "New")
			end;

			if UseSecondary then
				SyncModule.Options.SecondaryLoadingFunction.Server(Slot, Container, SyncModule.Player)
			else
				if workspace.StreamingEnabled then
					Container.Parent = SyncModule.Player
				end

				Container.Parent = WhereToSpawn
			end

			SyncModule.LastParents[Container] = Container.Parent;

			return Container
		end;

		return nil
	end;

	['UpdateSave'] = function(Slot)
		-- Ensure there's a player
		if SyncModule.Player == nil then
			return;
		end;
		
		-- Get the build and perform a few checks
		local Build = GetSlots().Data[Slot]

		-- If the build is up-to-date, do not convert
		if not Build or Build.Version == 6 then
			return
		end

		-- Otherwise, load it to serialise it again
		-- It's definitely the best and simplest solution though

		-- Find the right module to inflate the build
		local UsedModule = Build.Version == 3 and SyncModule.SerializationV4
			or Build.Version == 4 and SyncModule.SerializationV4 
			or Build.Version == 5 and SyncModule.SerializationV5

		-- Inflate the data
		local LoadedModel = UsedModule.InflateBuildData(Build)

		-- Get everything inside the returned result
		local ItemsToSerialize = SyncModule.Support.ConcatTable(LoadedModel, SyncModule.Support.QueryDescendantsInObjects(LoadedModel, "Instance"))

		-- Convert the build to the new system
		local NewDataSample = SyncModule.SerializationV6.SerializeModel(ItemsToSerialize)

		-- Set the data temporarily as the new slot's
		GetSlots().Data[Slot] = NewDataSample

		-- Tell the system this slot got updated so the update can be confirmed
		SyncModule.UpdatedSlots[Slot] = true

		-- Return the new size
		return GetRawSize(NewDataSample)
	end,

	['ConfirmSaveUpdate'] = function(Slot)
		-- Ensure there's a player
		if SyncModule.Player == nil then
			return;
		end;

		-- Make sure the build got indeed updated previously
		if not SyncModule.UpdatedSlots[Slot] then
			return
		end

		-- Prepare our changes for later
		local Changes = {}

		local ReturnedSlots = GetSlots()

		-- If there actually were an update, set the new data on the datastores
		local Build = ReturnedSlots.Data[Slot]

		-- If there's a build, continue
		if Build then
			-- JSON encode to prevent table compression issue (if requested)
			local BuildData = HttpService:JSONEncode(Build)

			SyncModule.BuildsDatastore:SetAsync( "Slot" .. Slot, "Fork3X Save: " .. tostring(BuildData) )--SerializedBuildData)


			local RawSize = GetRawSize(BuildData)

			-- Now we know the slot got updated, apply the necessary changes
			Changes.Preview = RawSize < SyncModule.Options.NoPreviewBeyond and Build or nil
			Changes.Size = RawSize
			Changes.Version = 6
		end

		local ClientSlotList = ReturnedSlots.Client
		local Save = ClientSlotList[Slot]

		-- Apply the changes made
		for Name, Value in Changes do
			Save[Name] = Value
		end
		
		-- Remove the build from the list 
		SyncModule.UpdatedSlots[Slot] = false
		
		-- Return the changes so they can also be applied on the client side
		return Changes
	end,



	--[[
	['SeparateUnion'] = function(Unions)
		if not SyncModule.CanModifyItems(Unions) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Unions), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Unions, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		local FinalParts = {}
		local FinalNegativeParts = {}

		for _, Union in Unions do
			if Union:FindFirstChild("UnionData") then
				local UnionData = require(Union.UnionData)

				local DataParts, DataNegativeParts, DataPosition = UnionData:Get()

				local LoadedParts = SerializationV5.InflateBuildData(DataParts)

				--	local Translation = Union.CFrame:ToObjectSpace(UnionData.Position)

				for _, Part in LoadedParts do
					if game.Workspace.StreamingEnabled then
						Part.Parent = SyncModule.Player
					end

					Part.Parent = Union.Parent
					table.insert(FinalParts, Part)

					local Translation = DataPosition:ToObjectSpace(Part.CFrame)

					Part.CFrame = Union.CFrame * Translation
				end

				local LoadedNegativeParts = SerializationV5.InflateBuildData(DataNegativeParts)

				for _, NegativePart in LoadedNegativeParts do
					if game.Workspace.StreamingEnabled then
						NegativePart.Parent = SyncModule.Player
					end

					NegativePart.Parent = Union.Parent
					table.insert(FinalParts, NegativePart)
					table.insert(FinalNegativeParts, NegativePart)

					local Translation = DataPosition:ToObjectSpace(NegativePart.CFrame)

					NegativePart.CFrame = Union.CFrame * Translation
				end
			end
		end

		return FinalParts, FinalNegativeParts
	end,]]
	['SeparateUnion'] = function(Unions)
		if not SyncModule.CanModifyItems(Unions) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = SyncModule.Security.GetPermissions(SyncModule.Security.GetSelectionAreas(Unions), SyncModule.Player);

		-- Make sure the player is allowed to perform changes to these parts
		if SyncModule.Security.ArePartsViolatingAreas(Unions, SyncModule.Player, true, AreaPermissions) then
			return;
		end;

		local FinalParts = {}
		local FinalNegativeParts = {}

		-- Require the CSGTreeV2 module locally to have correct types
		local CSGTreeV2 = SyncModule.CSGTreeV2

		-- Get the tree from each union if they got one
		for _, Union in Unions do
			if Union:IsA("TriangleMeshPart") and Union:GetAttribute("BTUnionData") then --and Union:GetAttribute("BTOriginalCFrame") then
				local Tree = HttpService:JSONDecode( Union:GetAttribute("BTUnionData") )

				if Tree.Version == 2 then
					local TreeData = Tree.Data

					-- Go through rach leaf
					for _, Leaf in TreeData do
						local Action = Leaf.Action

						local InflatedData = {}

						local LeafData = Leaf.Data
						local LeafOffset

						-- If it's a parenthesis, inflate the data as an union
						if CSGTreeV2.IsAParenthesis(Leaf) then
							InflatedData = CSGTreeV2.CreateUnionFromTree(LeafData, Union.CFrame, ShapeParameters)
						else
							InflatedData = CSGTreeV2.Desialize(LeafData, Union.CFrame)
						end

						local NewTree = CSGTreeV2.IsAParenthesis(Leaf) and Leaf.Data

						if not NewTree then
							NewTree = CSGTreeV2.CreateTree()

							NewTree.Data = {Leaf}
						end

						local EncodedData = HttpService:JSONEncode(NewTree)

						for _, Part in InflatedData do
							if Part:IsA("PartOperation") then
								Part:SetAttribute("BTUnionData", EncodedData)
							end

							if SyncModule.Player and workspace.StreamingEnabled then
								Part.Parent = SyncModule.Player
							end

							Part.Parent = Union.Parent

							SyncModule.CreatedInstances[Part] = Part
							SyncModule.LastParents[Part] = Part.Parent
						end
					end
				else
					local SeparatedTree, Negative, Leave, FinalLeave = SyncModule.CSGTreeV1.Separate(Tree)

					--print(SeparatedTree)

					local SerializedTree = SeparatedTree.Items and SyncModule.SerializationV6.InflateBuildData(SeparatedTree, false, Union.CFrame) 
						or SyncModule.CSGTreeV1.CreateFromTree(SeparatedTree, ShapeParameters, Union.CFrame)
					local SerializedLeave = Leave.Items and SyncModule.SerializationV6.InflateBuildData(Leave, false, Union.CFrame) 
						or SyncModule.CSGTreeV1.CreateFromTree(Leave, ShapeParameters, Union.CFrame)

					--local SerializedTree = CSGTreeV1.CreateFromTree(SeparatedTree, Parameters, Union.CFrame)
					--local SerializedLeave = SerializationV6.InflateBuildData(Leave, true, Union.CFrame)

					if Negative == true then
						FinalNegativeParts = type(SerializedLeave) == "table" and SerializedLeave or {SerializedLeave}
					else
						FinalParts = type(SerializedLeave) == "table" and SerializedLeave or {SerializedLeave}
					end

					SyncModule.Support.ConcatTable(FinalParts, type(SerializedTree) == "table" and SerializedTree or {SerializedTree})

					--print(FinalParts, FinalNegativeParts)

					local EncodedTree = HttpService:JSONEncode(SeparatedTree)
					local EncodedLeave = HttpService:JSONEncode(FinalLeave)

					local function ApplyExtraChanges(Part, Data)
						if Part:IsA("TriangleMeshPart") then
							Part:SetAttribute("BTUnionData", Data)
							--	Part:SetAttribute("BTOriginalCFrame", Union:GetAttribute("BTOriginalCFrame"))
						end

						if SyncModule.Player and workspace.StreamingEnabled then
							Part.Parent = SyncModule.Player
						end

						Part.Parent = Union.Parent
					end

					if type(SerializedTree) == "table"  then
						for _, Part in SerializedTree do
							ApplyExtraChanges(Part, EncodedTree)

							SyncModule.CreatedInstances[Part] = Part
							SyncModule.LastParents[Part] = Part.Parent
						end
					elseif SerializedTree ~= nil then
						ApplyExtraChanges(SerializedTree, EncodedTree)

						SyncModule.CreatedInstances[SerializedTree] = SerializedTree
						SyncModule.LastParents[SerializedTree] = SerializedTree.Parent
					end

					if type(SerializedLeave) == "table"  then
						for _, Part in SerializedLeave do
							ApplyExtraChanges(Part, EncodedLeave)

							SyncModule.CreatedInstances[Part] = Part
							SyncModule.LastParents[Part] = Part.Parent
						end
					elseif SerializedLeave ~= nil then
						ApplyExtraChanges(SerializedLeave, EncodedLeave)

						SyncModule.CreatedInstances[SerializedLeave] = SerializedLeave
						SyncModule.LastParents[SerializedLeave] = SerializedLeave.Parent
					end
				end
			end
		end

		return FinalParts, FinalNegativeParts
	end,
};

for FunctionName, Function in SyncModule.Options.ExtraSyncAPIFunctions do
	if not SyncModule.WarnedAbout.ExtraSyncAPIFunctions then
		warn("[FORK3X]: ExtraSyncAPIFunctions has been superseded by CustomSyncModuleFunctions, which gives direct access to the SyncModule.\n\nMore information can be found on github.com/VikkoMakesStuff/Fork3X/wiki/Options#onlyselectinworkspace")

		SyncModule.WarnedAbout.ExtraSyncAPIFunctions = true
	end

	Actions[FunctionName] = function(...)
		return Function(SyncModule.Player, SyncModule.Security, ...)
	end
end

for FunctionName, Function in SyncModule.Options.CustomSyncModuleFunctions do
	Actions[FunctionName] = function(...)
		return Function(SyncModule, ...)
	end
end

local PlayerFunction = function (Child, Parent)

	-- Ensure tool's parent changed
	if Child ~= SyncModule.Tool then
		return;
	end;

	local OldPlayer = SyncModule.Player

	-- Set `Player` to player of the backpack the tool is in
	if Parent and Parent:IsA 'Backpack' then
		SyncModule.Player = SyncModule.Tool:FindFirstAncestorWhichIsA("Player")--Parent.Parent;

		-- Set `Player` to player of the character holding the tool
	elseif Parent and Parent:IsA 'Model' then
		SyncModule.Player = game.Players:GetPlayerFromCharacter(Parent);

		-- Clear `Player` if tool is not parented to a player
	else
		SyncModule.Player = nil;

		-- Clean up remaining clone streaming metadata before tool becomes unable to
		for clone in SyncModule.streamingClonesPendingUntagging do
			clone:RemoveTag("BTStreamingClone")
			clone:SetAttribute("BTStreamingCloneID", nil)
			SyncModule.streamingClonesPendingUntagging[clone] = nil
		end
	end;

	if OldPlayer ~= SyncModule.Player then
		SyncModule.BuildsDatastore = nil
		SyncModule.SlotsData = nil
		SyncModule.SlotsTotalSize = 0

		SyncModule.UpdatedSlots = {}

		if SyncModule.Player then
			for Name, Value in Globals do
				_G[ string.format("BT_%*_%*", SyncModule.Player.Name, Name) ] = Value
			end
		end
	end

end;

-- Keep current player updated in tool mode
if SyncModule.ToolMode == 'Tool' then

	-- Set current player if in backpack
	if SyncModule.Tool.Parent and SyncModule.Tool.Parent:IsA 'Backpack' then
		SyncModule.Player = SyncModule.Tool:FindFirstAncestorWhichIsA("Player") --SyncModule.Tool.Parent.Parent;

		-- Set current player if in character
	elseif SyncModule.Tool.Parent and SyncModule.Tool.Parent:IsA 'Model' then
		SyncModule.Player = game.Players:GetPlayerFromCharacter(SyncModule.Tool.Parent);

		-- Clear `Player` if not in possession of a player
	else
		SyncModule.Player = nil;
	end;

	-- Stay updated with latest player operating the tool
	SyncModule.Tool.AncestryChanged:Connect(PlayerFunction);

end;

-- Set up external connections
SyncModule.Options.CustomSyncModuleConnections(SyncModule)

-- Provide an interface into the module
return {

	-- Provide access to internal SyncModule.Options
	Options = SyncModule.Options;

	-- Provide client actions API
	PerformAction = function (Client, ActionName, ...)
		-- Make sure the action exists
		local Action = Actions[ActionName];
		if not Action then
			return;
		end;

		-- Ensure client is current player in tool mode
		if SyncModule.ToolMode == 'Tool' then
			assert(SyncModule.Player and (Client == SyncModule.Player), 'Permission denied for client');
		end;

		if not SyncModule.Plugin and SyncModule.Options.MaxEventsPerSecond and SyncModule.Options.MaxEventsPerSecond ~= 0 then
			SetGlobal( "EventsLimit", GetGlobal("EventsLimit") and GetGlobal("EventsLimit") + 1 or 1 )

			local BTCooldown = math.max(1, GetGlobal("EventsLimit") // SyncModule.Options.MaxEventsPerSecond)
			
			
			
			if not GetGlobal("Cooldown") 
				or ( GetGlobal("Cooldown") and coroutine.status( GetGlobal("Cooldown") ) ~= "running" )
				or GetGlobal("CooldownLength") ~= BTCooldown 
			then
				if GetGlobal("Cooldown") then
					pcall( task.cancel, GetGlobal("Cooldown") )
				end

				SetGlobal( "CooldownLength", BTCooldown )

				SetGlobal( "Cooldown", task.delay(BTCooldown, function()
					SetGlobal( "EventsLimit", nil )
					SetGlobal( "Cooldown", nil )
					SetGlobal( "CooldownLength", nil )
				end) )
			end

			if GetGlobal("EventsLimit") > SyncModule.Options.MaxEventsPerSecond then
				task.wait(BTCooldown)
			end
		end

		-- Execute valid actions
		return Action(...);

	end;

};