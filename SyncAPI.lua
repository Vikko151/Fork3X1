local HttpService = game:GetService('HttpService')
local RunService = game:GetService('RunService')
local MaterialService = game:GetService('MaterialService')
local InsertService = game:GetService("InsertService")

local ASecret
local SlotsTotalSize = 0
local SlotsSizes = {}

-- References
SyncAPI = script.Parent;
Tool = SyncAPI.Parent;
Player = nil;

-- Libraries
Security = require(Tool.Core.Security);
Support = require(Tool.Libraries.SupportLibrary);

CSGTree = require(Tool.Libraries.CSGTree)

SerializationV1 = require(Tool.Libraries.SerializationV1)
SerializationV2 = require(Tool.Libraries.SerializationV2)
SerializationV3 = require(Tool.Libraries.SerializationV3)
SerializationV4 = require(Tool.Libraries.SerializationV4)
SerializationV5 = require(Tool.Libraries.SerializationV5)
SerializationV6 = require(Tool.Libraries.SerializationV6)(CSGTree)

local Parameters = {
	CollisionFidelity = Enum.CollisionFidelity.Hull,
	RenderFidelity = Enum.RenderFidelity.Performance,
	FluidFidelity = Enum.FluidFidelity.UseCollisionGeometry,
	SplitApart = false}

-- Default options

Options = Tool:FindFirstChild("Options") and require(Tool.Options)

if Options == nil then error("Failed to load Building Tools by F3X: options module is missing!") end

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

LagFriendlyParts = 0

-- Keep track of created items in memory to not lose them in garbage collection

CreatedInstances = {};
LastParents = {};

local streamingClonesPendingUntagging = {}

-- Determine whether we're in tool or plugin mode
ToolMode = (Tool.Parent:IsA 'Plugin') and 'Plugin' or 'Tool'

local IsHttpServiceEnabled = nil

-- List of actions that could be requested
Actions = {

	['RecolorHandle'] = function (NewColor)
		-- Recolors the tool handle
		Tool.Handle.BrickColor = NewColor;
	end;

	['Clone'] = function (Items, Parent)
		-- Clones the given items

		-- Validate arguments
		assert(type(Items) == 'table', 'Invalid items')
		assert(typeof(Parent) == 'Instance', 'Invalid parent')
		assert(Security.IsLocationAllowed(Parent, Player), 'Permission denied for client')

		for _, Part in pairs(Items) do
			if game.Players:GetPlayerFromCharacter(Part:FindFirstAncestorOfClass("Model")) ~= nil then continue end
			if Part:IsA("BasePart") and Part.Anchored == false then
				LagFriendlyParts += 1
				coroutine.wrap(function() task.wait(60) LagFriendlyParts -= 1 end)()
			end
		end

		if LagFriendlyParts >= Options.LagFriendlyPartLimit then
			Options.BadBehaviorFunction(Player, Options.WebhookModule, "Anchor", { Parts = LagFriendlyParts })
			return
		end

		-- Check if items modifiable
		if not CanModifyItems(Items) then
			return {}
		end

		-- Check if parts intruding into private areas
		local Parts = GetPartsFromSelection(Items)
		if Security.ArePartsViolatingAreas(Parts, Player, false) then
			return {}
		end

		local Clones = {}		
		local StreamingCloneId = if (Player and game.Workspace.StreamingEnabled)
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
				streamingClonesPendingUntagging[Clone] = true
			end

			Clone.Parent = Parent

			-- Register the clone
			table.insert(Clones, Clone)
			CreatedInstances[Item] = Item
		end

		-- If streaming is enabled in tool mode, return temporary clone operation metadata
		-- (instead of invalid instance references)
		if StreamingCloneId then
			task.delay(Options.StreamingCloneTagLifetime, function ()
				for _, Clone in Clones do
					Clone:RemoveTag("BTStreamingClone")
					Clone:SetAttribute("BTStreamingCloneID", nil)
					streamingClonesPendingUntagging[Clone] = nil
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
		assert(Security.IsLocationAllowed(Parent, Player), 'Permission denied for client')

		-- Create the part
		local NewPart = CreatePart(PartType);

		-- Position the part
		if NewPart:IsA("Tool") then
			NewPart:FindFirstChild("Handle").CFrame = Position;
		elseif NewPart:IsA("Model") then
			NewPart:SetPivot(Position)
		else
			NewPart.CFrame = Position
		end


		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas({ NewPart }), Player);

		-- Make sure the player is allowed to create parts in the area
		if Security.ArePartsViolatingAreas({ NewPart }, Player, false, AreaPermissions) then
			return;
		end;

		-- Parent the part

		-- If streaming is enabled in tool mode, to ensure returned instance reference isn't invalid,
		-- trigger immediate part replication by parenting elsewhere first
		if Player and game.Workspace.StreamingEnabled then
			NewPart.Parent = Player
		end

		NewPart.Parent = Parent

		-- Register the part
		CreatedInstances[NewPart] = NewPart;

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
		assert(Security.IsLocationAllowed(Parent, Player), 'Permission denied for client')

		-- Check if items selectable
		if not CanModifyItems(Items) then
			return
		end

		-- Check if parts intruding into private areas
		local Parts = GetPartsFromSelection(Items)
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player)
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
			local Parts = Support.GetDescendantsWhichAreA(Group, 'BasePart')
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
		if not CanModifyItems(Groups) then
			return
		end

		-- Check if parts intruding into private areas
		local Parts = GetPartsFromSelection(Groups)
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player)
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return
		end

		local Results = {}

		-- Check each group
		for Key, Group in ipairs(Groups) do
			assert(typeof(Group) == 'Instance', 'Invalid group')

			if Group:FindFirstChildOfClass("Humanoid") then -- Imminent annilation for this top tier griefer.
				if ToolMode == "Tool" and Options.DisallowHumanoidUngrouping == true then
					Options.BadBehaviorFunction(Player, Options.WebhookModule, "Ungroup", {})
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
				LastParents[Child] = Group
				Children[#Children + 1] = Child
				Child.Parent = NewParent
				if Child:IsA 'BasePart' then
					Child:MakeJoints()
				elseif Child:IsA 'Folder' then
					local Parts = Support.GetDescendantsWhichAreA(Child, 'BasePart')
					for _, Part in pairs(Parts) do
						Part:MakeJoints()
					end
				end
			end

			-- Track removing group
			LastParents[Group] = Group.Parent
			CreatedInstances[Group] = Group

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
		if not CanModifyItems(Items) then
			return
		end

		-- Check if parts intruding into private areas
		local Parts = GetPartsFromSelection(Items)
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player)
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return
		end

		-- Move each item to different parent
		if type(Parent) == 'table' then
			for Key, Item in pairs(Items) do
				local Parent = Parent[Key]

				-- Check if parent allowed
				assert(Security.IsLocationAllowed(Parent, Player), 'Permission denied for client')

				-- Move item
				Item.Parent = Parent
				if Item:IsA 'BasePart' then
					Item:MakeJoints()
				elseif Item:IsA 'Folder' then
					local Parts = Support.GetDescendantsWhichAreA(Item, 'BasePart')
					for _, Part in pairs(Parts) do
						Part:MakeJoints()
					end
				end
			end

			-- Move to single parent
		elseif typeof(Parent) == 'Instance' then
			assert(Security.IsLocationAllowed(Parent, Player), 'Permission denied for client')

			-- Reparent items
			for _, Item in pairs(Items) do
				Item.Parent = Parent
				if Item:IsA 'BasePart' then
					Item:MakeJoints()
				elseif Item:IsA 'Folder' then
					local Parts = Support.GetDescendantsWhichAreA(Item, 'BasePart')
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
		if not CanModifyItems(Items) then
			return
		end

		-- Check if parts intruding into private areas
		local Parts = GetPartsFromSelection(Items)
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player)
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return
		end

		-- Rename each item to a different name
		if type(Name) == 'table' then
			for Key, Item in pairs(Items) do
				local Name = Name[Key]
				
				local FinalName = FilterText(Name) or Item.Name
				
				Item.Name = FinalName
			end

			-- Rename to single name
		elseif type(Name) == 'string' then
			for _, Item in pairs(Items) do
				local FinalName = FilterText(Name) or Item.Name

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
					Support.ConcatTable(Parts, Support.GetDescendantsWhichAreA(Object, 'BasePart'))
				end

			end;

		end;

		-- Check if items modifiable
		if not CanModifyItems(Objects) then
			return
		end 

		-- Check if parts intruding into private areas
		if Security.ArePartsViolatingAreas(Parts, Player, true) then
			return
		end

		-- After confirming permissions, perform each removal
		for _, Object in pairs(Objects) do
			if Object:IsDescendantOf(workspace) then
				-- Store the part's current parent
				LastParents[Object] = Object.Parent;

				-- Register the object
				CreatedInstances[Object] = Object;

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
			if Object and LastParents[Object] then

				if Object:IsA 'BasePart' then
					table.insert(Parts, Object);

				elseif Object:IsA 'Smoke' or Object:IsA 'Fire' or Object:IsA 'Sparkles' or Object:IsA 'DataModelMesh' or Object:IsA 'Decal' or Object:IsA 'Texture' or Object:IsA 'Light' or Object:IsA 'Attachment' then
					table.insert(Parts, Object.Parent);

				elseif Object:IsA 'TextLabel' then
					table.insert(Parts, Object.Parent.Parent);

				elseif Object:IsA 'Model' or Object:IsA 'Folder' then
					Support.ConcatTable(Parts, Support.GetDescendantsWhichAreA(Object, 'BasePart'))
				end

			end;

		end;

		-- Check if items modifiable
		if not CanModifyItems(Objects) then
			return
		end

		-- Check if parts intruding into private areas
		if Security.ArePartsViolatingAreas(Parts, Player, false) then
			return
		end

		-- After confirming permissions, perform each removal
		for _, Object in pairs(Objects) do

			-- Store the part's current parent
			local LastParent = LastParents[Object];
			LastParents[Object] = Object.Parent;

			-- Register the object
			CreatedInstances[Object] = Object;

			-- Set the object's parent to the last parent
			Object.Parent = LastParent;

			-- Make joints
			if Object:IsA 'BasePart' then
				Object:MakeJoints()
			else
				local Parts = Support.GetDescendantsWhichAreA(Object, 'BasePart')
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
		if not (CanModifyItems(Parts) and CanModifyItems(Attachments) and CanModifyItems(Models)) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
		if Security.ArePartsViolatingAreas(Parts, Player, false, AreaPermissions) then

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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

			-- Set the part's size and CFrame
			Mesh.Scale = Change.Scale;
			Mesh.Offset = Change.Offset;

		end;

		-- Make sure the player is authorized to move parts into this area
		if Security.ArePartsViolatingAreas(Parts, Player, false, AreaPermissions) then

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
		if not (CanModifyItems(Parts) and CanModifyItems(Models)) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
		if Security.ArePartsViolatingAreas(Parts, Player, false, AreaPermissions) then

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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

			-- Apply each surface change
			for Surface, SurfaceType in pairs(Change.Surfaces) do
				Part[Surface .. 'Surface'] = SurfaceType;
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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
				CreatedInstances[Light] = Light;

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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
				local Light = Support.GetChildOfClass(Part, Change.LightType);

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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
			if AllowedDecorationTypes[Change.DecorationType] then

				-- Create the decoration

				local Decoration = Instance.new(Change.DecorationType, Part);
				if Change.DecorationType == ("SelectionBox" or "Highlight") then
					Decoration.Adornee = Part
				elseif Change.DecorationType == "ParticleEmitter" then
					LagFriendlyParts += 20
					if LagFriendlyParts > Options.LagFriendlyPartLimit then
						Options.BadBehaviorFunction(Player, Options.WebhookModule, "Lag", {Rate = LagFriendlyParts})
					end
				end
				table.insert(Decorations, Decoration);

				-- Register the decoration
				CreatedInstances[Decoration] = Decoration;

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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
				local Decoration = Support.GetChildOfClass(Part, Change.DecorationType);

				-- Make sure the decoration exists
				if Decoration then

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
						local Positive = Options.BlacklistImages and Options.BadBehaviorFunction(Player, Options.WebhookModule, "Image", {Image = Change.Texture}) or false
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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
			CreatedInstances[Mesh] = Mesh;

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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Update each part's meshes
		for Part, Change in pairs(ChangeSet) do

			-- Grab the part's mesh
			local Mesh = Support.GetChildOfClass(Part, 'SpecialMesh');

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
					if Mesh.MeshType ~= Enum.MeshType.FileMesh then
						local Axis = {
							X = math.abs(Change.Scale.X),
							Y = math.abs(Change.Scale.Y),
							Z = math.abs(Change.Scale.Z)
						}
						local BiggestDimension = math.max(Axis.X, Axis.Y, Axis.Z)
						if BiggestDimension > Options.MaxNormalMeshSize then
							if ToolMode == "Tool" and Options.TriggerBadBehaviorForNormalMeshes == true then
								Options.BadBehaviorFunction(Player, Options.WebhookModule, "MeshSize", Axis)
								return
							elseif ToolMode == "Tool" then
								Change.Scale = (Vector3.one * Options.MaxNormalMeshSize):Min(Change.Scale)
							end
						end
					else
						-- If it's a Fork3X mesh, listen to bad behavior settings and find the mesh's absolute size
						local AbsoluteSize = Mesh.MeshId == "" and Vector3.one or Mesh:GetAttribute("BTAbsoluteSize") or vector.create(2048, 2048, 2048)

						local Axis = {
							X = Mesh:GetAttribute("BTAbsoluteSize") and Change.Scale.X / AbsoluteSize.X or Change.Scale.X * AbsoluteSize.X,
							Y = Mesh:GetAttribute("BTAbsoluteSize") and Change.Scale.Y / AbsoluteSize.Y or Change.Scale.Y * AbsoluteSize.Y,
							Z = Mesh:GetAttribute("BTAbsoluteSize") and Change.Scale.Z / AbsoluteSize.Z or Change.Scale.Z * AbsoluteSize.Z
						}
						--local XSize = 
						--local YSize = Axis.Y * 10
						--local ZSize = Axis.Z * 10
						local BiggestDimension = math.max(Axis.X, Axis.Y, Axis.Z)

						print(Axis)

						if BiggestDimension > Options.MaxFileMeshSize then
							if ToolMode == "Tool" and Options.TriggerBadBehaviorForFileMeshes == true then
								Options.BadBehaviorFunction(Player, Options.WebhookModule, "MeshSize", Axis)
								return
							elseif ToolMode == "Tool" then
								Change.Scale = (Vector3.one * Options.MaxFileMeshSize / 2048):Min(Change.Scale)
							end
						end
					end

					Mesh.Scale = Change.Scale;
				end;
				if Change.Offset ~= nil then
					Mesh.Offset = Change.Offset;
				end;
				if Change.MeshId ~= nil then
					if Change.Scale ~= nil and Options.BetterMeshSizeControl == true then
						local AbsoluteSize = vector.one / Change.Scale
						if not plugin then
							Mesh:SetAttribute("BTAbsoluteSize", AbsoluteSize)
						end

						if KeepProportions == 0 then
							Mesh.Scale = AbsoluteSize * Part.Size
						else
							local Axis = {
								X = math.abs(Change.Scale.X),
								Y = math.abs(Change.Scale.Y),
								Z = math.abs(Change.Scale.Z)
							}

							local BiggestDimensionSize = math.max(Axis.X, Axis.Y, Axis.Z)
							local BiggestDimensionName = Support.FindTableOccurrence(Axis, BiggestDimensionSize)

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
					local Positive = Options.BlacklistImages and Options.BadBehaviorFunction(Player, Options.WebhookModule, "Image", {Image = Change.TextureId}) or false
					if Positive == false then
						Mesh.TextureId = Change.TextureId;
					end
				end;
			end;

		end;

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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
				CreatedInstances[Texture] = Texture;

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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
							local Positive = Options.BlacklistImages and Options.BadBehaviorFunction(Player, Options.WebhookModule, "Image", {Image = Change.Texture}) or false
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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
				LagFriendlyParts += 1
				coroutine.wrap(function() task.wait(60) LagFriendlyParts -= 1 end)()
			end
		end

		if LagFriendlyParts >= Options.LagFriendlyPartLimit then
			Options.BadBehaviorFunction(Player, Options.WebhookModule, "Anchor", { Parts = LagFriendlyParts })
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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
			if Part:IsA("VehicleSeat") and Options.AllowExtraVehicleSeatsSettings == true then
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
		
		if Options.ConstraintsBlacklist[Type] then
			return
		end
		
		local Parts = {}

		for _, PartToAttach in pairs(PartsToAttach) do
			table.insert(Parts, PartToAttach)
		end
		for _, Attachment in pairs(Attachments) do
			table.insert(Parts, Attachment)
		end

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

					-- Register the weld
					CreatedInstances[Weld] = Weld;
					table.insert(Constraints, Weld);

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
					CreatedInstances[RopeConstraint] = RopeConstraint;
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
					CreatedInstances[RodConstraint] = RodConstraint;
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
					CreatedInstances[HingeConstraint] = HingeConstraint;
					table.insert(Constraints, HingeConstraint);
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
		if not CanModifyItems(Parts) then
			return;
		end;

		local WeldsRemoved = 0;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Go through each weld
		for _, Weld in pairs(Welds) do

			local Part0Unauthorized
			local Part1Unauthorized

			-- Check the permissions on each weld-related part
			if Type == 'Weld' then
				Part0Unauthorized = Security.ArePartsViolatingAreas({ Weld.Part0 }, Player, true, AreaPermissions);
				Part1Unauthorized = Security.ArePartsViolatingAreas({ Weld.Part1 }, Player, true, AreaPermissions);
			else
				Part0Unauthorized = Security.ArePartsViolatingAreas({ Weld.Attachment0.Parent }, Player, true, AreaPermissions);
				Part1Unauthorized = Security.ArePartsViolatingAreas({ Weld.Attachment1.Parent }, Player, true, AreaPermissions);	
			end

			-- If at least one of the involved parts is authorized, remove the weld
			if not Part0Unauthorized or not Part1Unauthorized then

				-- Register the weld
				CreatedInstances[Weld] = Weld;
				LastParents[Weld] = Weld.Parent;
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
			if not LastParents[Weld] then
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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Go through each weld
		for _, Weld in pairs(Welds) do

			local Part0Unauthorized
			local Part1Unauthorized

			-- Check the permissions on each weld-related part
			if Type == 'Weld' then
				Part0Unauthorized = Security.ArePartsViolatingAreas({ Weld.Part0 }, Player, true, AreaPermissions);
				Part1Unauthorized = Security.ArePartsViolatingAreas({ Weld.Part1 }, Player, true, AreaPermissions);
			else
				Part0Unauthorized = Security.ArePartsViolatingAreas({ Weld.Attachment0.Parent }, Player, true, AreaPermissions);
				Part1Unauthorized = Security.ArePartsViolatingAreas({ Weld.Attachment1.Parent }, Player, true, AreaPermissions);	
			end

			-- If at least one of the involved parts is authorized, restore the weld
			if not Part0Unauthorized or not Part1Unauthorized then

				-- Store the part's current parent
				local LastParent = LastParents[Weld];
				LastParents[Weld] = Weld.Parent;

				-- Register the weld
				CreatedInstances[Weld] = Weld;

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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return;
		end;

		-- Reorganize the changes
		local ChangeSet = {};
		for _, Change in pairs(Changes) do
			if Change.Part then
				ChangeSet[Change.Part] = Change;
			end;
		end;

		-- Update each part's meshes
		for Part, Change in pairs(ChangeSet) do

			-- Grab the part's mesh
			local Constraint = Support.GetChildOfClass(Part, 'RopeConstraint') or Support.GetChildOfClass(Part, 'RodConstraint') or Support.GetChildOfClass(Part, 'HingeConstraint');

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


			end;

		end;

	end;

	['Export'] = function (Parts)
		-- Serializes, exports, and returns ID for importing given parts

		-- Offload action to server-side if API is running locally
		if RunService:IsClient() and not RunService:IsStudio() then
			return SyncAPI.ServerEndpoint:InvokeServer('Export', Parts);
		end;

		-- Ensure valid selection
		assert(type(Parts) == 'table', 'Invalid item table');

		-- Ensure there are items to export
		if #Parts == 0 then
			return;
		end;

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to access these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return;
		end;

		-- Get all descendants of the parts
		local Items = Support.CloneTable(Parts);
		for _, Part in pairs(Parts) do
			Support.ConcatTable(Items, Part:GetDescendants());
		end;
		
		if Options.PreSerialization then
			if Options.PreSerialization(Items, Player) ~= true then
				error("Failed PreSerialization")
			end
		end

		-- After confirming permissions, serialize parts
		local SerializedBuildData = SerializationV3.SerializeModel(Items);

		-- Push serialized data to server
		local Response = HttpService:JSONDecode(
			HttpService:PostAsync(
				'http://f3xteam.com/bt/export',
				HttpService:JSONEncode { data = SerializedBuildData, version = 3, userId = (Player and Player.UserId) },
				Enum.HttpContentType.ApplicationJson,
				true
			)
		);

		-- Return creation ID on success
		if Response.success then
			return Response.id;
		else
			error('Export failed due to server-side error', 2);
		end;

	end;

	['IsHttpServiceEnabled'] = function ()
		-- Returns whether HttpService is enabled

		-- Offload action to server-side if API is running locally
		if RunService:IsClient() then
			return SyncAPI.ServerEndpoint:InvokeServer('IsHttpServiceEnabled')
		end

		-- Return cached status if available
		if IsHttpServiceEnabled ~= nil then
			return IsHttpServiceEnabled
		end

		-- Perform test HTTP request
		local DidSucceed, Result = pcall(function ()

			local ReturnedAsset = HttpService:RequestAsync({
				Url = 'https://google.com',
			}) 


			return ReturnedAsset.Success
		end)

		-- Determine whether HttpService is enabled based on whether request succeeded
		if DidSucceed then
			IsHttpServiceEnabled = true
		elseif (not DidSucceed) and Result:match('Http requests are not enabled') then
			IsHttpServiceEnabled = false
		end

		return IsHttpServiceEnabled or false
	end;

	['ExtractMeshFromAsset'] = function (AssetId)
		-- Returns the first found mesh in the given asset

		-- Offload action to server-side if API is running locally
		if RunService:IsClient() and not RunService:IsStudio() then
			return SyncAPI.ServerEndpoint:InvokeServer('ExtractMeshFromAsset', AssetId);
		end;

		-- Ensure valid asset ID is given
		assert(type(AssetId) == 'number', 'Invalid asset ID');

		local AssetIdWhitelist = {
			4,
			8,
			19,
			40,
			41,
			42,
			43,
			44,
			45,
			46,
			47
		}

		-- TAKE 1: If it's a mesh part, use the Roblox APIs
		--[[
		local Success, Result = pcall(function()
			if AssetInfo.AssetTypeId == 40 and IsHttpServiceEnabled and Options.EnableAPIs == true then
				local URL = "https://apis.roblox.com/asset-delivery-api/v1/assetId/" .. AssetId
				local Result

				Result = HttpService:RequestAsync({Url = URL, Method = "GET", Headers = {
					["x-api-key"] = HttpService:GetSecret(Options.SearchingSecret)}})--> Get songs from search.roblox.com result

				if Result then
					print(Result)
				end
			end

			error(tostring(AssetInfo.AssetTypeId) .. " isn't a mesh or an accessory.")
		end)]]

		-- TAKE 1: Attempt to insert the asset.
		local Success, Result = pcall(function()
			local AssetInfo = game:GetService("MarketplaceService"):GetProductInfoAsync(AssetId, Enum.InfoType.Asset)
			if table.find(AssetIdWhitelist, AssetInfo.AssetTypeId) then
				local LoadedAsset = game:GetService("AssetService"):LoadAssetAsync(AssetId)

				-- Look for a mesh (if it's an accessory)

				local Mesh = Support.GetDescendantsWhichAreA(LoadedAsset, "MeshPart")[1] or Support.GetDescendantsWhichAreA(LoadedAsset, "SpecialMesh")[1]

				assert(Mesh, "The asset has no mesh.")

				return Mesh:IsA("SpecialMesh") and {
					meshID = Mesh.MeshId:lower():match("%d+"),
					textureID = Mesh.TextureId ~= "" and Mesh.TextureId:lower():match("%d+") or nil,
					tint = Mesh.VertexColor,
					scale = Mesh.Parent:IsA("BasePart") and Mesh.Parent.Size / Mesh.Scale or Mesh.Scale,
					success = true
				} or {
					meshID = Mesh.MeshId:lower():match("%d+"),
					textureID = Mesh.TextureID ~= "" and Mesh.TextureID:lower():match("%d+") or nil,
					tint = vector.one,
					scale = Mesh.Size,
					success = true
				}
			end

			error(tostring(AssetInfo.AssetTypeId) .. " isn't a mesh or an accessory.")
		end)

		-- TAKE 2: Rely on the API
		if not Success then

			local ReturnedAsset = HttpService:RequestAsync({
				Url = 'http://f3xteam.com/bt/getFirstMeshData/' .. AssetId,
			})

			local FinalResult = HttpService:JSONDecode(ReturnedAsset.Body)

			return FinalResult --HttpService:JSONDecode(ReturnedAsset.Body)
		else
			return Result
		end

		-- Return parsed response from API
		--	return HttpService:JSONDecode(ReturnedAsset.Body) or nil

	end;

	['ExtractImageFromDecal'] = function (DecalAssetId)
		-- Returns the first image found in the given decal asset
		-- Offload action to server-side if API is running locally
		if RunService:IsClient() and not RunService:IsStudio() then
			return SyncAPI.ServerEndpoint:InvokeServer('ExtractImageFromDecal', DecalAssetId);
		end;

		local FinalID = DecalAssetId

		local InsertedDecal = InsertService:LoadAsset(DecalAssetId)

		if #InsertedDecal:GetChildren() == 1 and InsertedDecal:FindFirstChildOfClass("Decal") then

			FinalID = tonumber(InsertedDecal:FindFirstChildOfClass("Decal").Texture:lower():match("%d+"))

		end

		InsertedDecal:Destroy()

		return FinalID

		-- Return direct response from the API

	end;

	['SetMouseLockEnabled'] = function (Enabled)
		-- Sets whether mouse lock is enabled for the current player

		-- Offload action to server-side if API is running locally
		if RunService:IsClient() and not RunService:IsStudio() then
			return SyncAPI.ServerEndpoint:InvokeServer('SetMouseLockEnabled', Enabled);
		end;

		-- Set whether mouse lock is enabled
		Player.DevEnableMouseLock = Enabled;

	end;

	['SetLocked'] = function (Items, Locked)
		-- Locks or unlocks the specified parts

		-- Validate arguments
		assert(type(Items) == 'table', 'Invalid items')
		assert(type(Locked) == 'table' or type(Locked) == 'boolean', 'Invalid lock state')

		-- Check if items modifiable
		if not CanModifyItems(Items) then
			return
		end

		-- Check if parts intruding into private areas
		local Parts = GetPartsFromSelection(Items)
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player)
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return
		end

		-- Set each item to a different lock state
		if type(Locked) == 'table' then
			for Key, Item in pairs(Items) do
				local Locked = Locked[Key]
				--		Item.Locked = Locked
				Options.SetPermission(Item, Player, "Lock", Locked)
			end

			-- Set to single lock state
		elseif type(Locked) == 'boolean' then
			for _, Item in pairs(Items) do
				--		Item.Locked = Locked
				Options.SetPermission(Item, Player, "Lock", Locked)
			end
		end

	end;

	['Import'] = function (creation_id)


	--[[
		local export_base_url = 'http://www.f3xteam.com/bt/export/%s' -- I know, this code is not good, but it's made by GigsD4X, not me.
		-- Try to download the creation
		local creation_data;
		local download_attempt, download_error = ypcall( function ()
			creation_data = HttpService:GetAsync( export_base_url:format( creation_id ) );
		end );

		-- Fail graciously
		if not download_attempt and download_error == 'Http requests are not enabled' then
			print 'Import from Building Tools by F3X: Please enable HTTP requests (see http://wiki.roblox.com/index.php?title=Sending_HTTP_requests#Http_requests_are_not_enabled)';
			return false;
		end;
		if not download_attempt then
			print( 'Import from Building Tools by F3X (download request error): ' .. tostring( download_error ) );
			return false;
		end;
		if not ( creation_data and type( creation_data ) == 'string' and creation_data:len() > 0 ) then
			return false;
		end;
		if not pcall( function () creation_data = HttpService:JSONDecode( creation_data ); end ) then
			return false;
		end;
		
		print(creation_data.userId)
		
		if creation_data.userId ~= game.Players:GetPlayerFromCharacter(Tool.Parent).UserId then
			return false;
		end

		-- Create a container to hold the creation
		local Container = Instance.new( 'Model', Workspace );
		Container.Name = Player.Name ..'BTExport';

		-- Inflate legacy v1 export data
		if creation_data.version == 1 then
			SerializationV1(creation_data, Container)
			Container:MakeJoints()

			-- Parse builds with serialization format version 2
		elseif creation_data.Version == 2 then

			-- Inflate the build data
			local Parts = SerializationV2.InflateBuildData(creation_data);

			-- Parent the build into the export container
			for _, Part in pairs(Parts) do
				Part.Parent = Container;
			end;

			-- Finalize the import
			Container:MakeJoints();

			-- Parse builds with serialization format version 3
		elseif creation_data.Version == 3 then
			-- Inflate the build data
			local Parts = SerializationV3.InflateBuildData(creation_data);

			-- Parent the build into the export container
			for _, Part in pairs(Parts) do
				Part.Parent = Container;
			end;

			-- Finalize the import
			Container:MakeJoints();
		end;]]

	end;

	["SearchAssetu"] = function(Type, Input, Page)

		local Results
		local CategoryNumber

		--> Detect if the keyword arg is an ID, and if so, load only that audio instead:

		--> Request songs list from proxy server:
		repeat

			local url = "https://search.RoProxy.com/catalog/json?CatalogContext=2&Subcategory=16&CreatorID=&SortAggregation=5&PageNumber=".. Page .."&Keyword=".. Input .."&LegendExpanded=true&Category=".. CategoryNumber .."&SearchId=3e31c553-b9e1-4811-8ba4-c0c511cf915f"
			local success, errormsg = pcall(function()
				Results = HttpService:JSONDecode(HttpService:RequestAsync({Url = url, Method = "GET"}).Body) --> Get songs from search.roblox.com result
			end)

			if not success then
				--			warn(errormsg)
				task.wait(.2)
			end

		until success

		if not Results then
			return {}, true
		else
			return Results	
		end

	end;

	["SearchAsset"] = function(Type, Input, Page, Settings)

		local Results

		--> Detect if the keyword arg is an ID, and if so, load only that audio instead:

		--> Request songs list from proxy server:
		if Settings.UseHttp == false then
			if Type == "Decal" then
				if not Page then
					Page = 1
				end
				
				local Success, ErrorMessage = pcall(function()
					Results = Options.CheckDecalResult(InsertService:GetFreeDecalsAsync(Input, Page)[1].Results, Settings)
				end)

				if ErrorMessage and ErrorMessage == 'GetFreeDecalsAsync is not a valid member of InsertService "InsertService"' then
					ErrorMessage = nil
					
					Success, ErrorMessage = pcall(function()
						Results = Options.CheckDecalResult(InsertService:GetFreeDecalsAsync(Input, Page)[1].Results, Settings)
					end)
				end
				
				if ErrorMessage then
					warn(ErrorMessage)
				end
				--		Results = game:GetService("InsertService"):GetFreeDecals(Input, Page)[1].Results
			end

			if not Results then
				return {}, true
			else
				return Results, true, Page + 1
			end
		else
			local URL = string.format("https://apis.roblox.com/toolbox-service/v2/assets:search?searchCategoryType=%s&query=%s&pageNumber=%s&maxPageSize=50", Type, Input, Page)

			local Success, Error = pcall(function()
				Results = HttpService:RequestAsync({Url = URL, Method = "GET", Headers = {
					["x-api-key"] = HttpService:GetSecret(Options.SearchingSecret),
					["Content-Type"] = "application/json"}})--> Get songs from search.roblox.com result
			end)

			if not Success then
				warn(Error)
			end

			if not Results then
				return {}, true
			else
				Results = HttpService:JSONDecode(Results.Body)

				return Results.creatorStoreAssets, true, Results.nextPageToken
			end
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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
			local SurfaceGUI = Instance.new("SurfaceGui", Part);
			SurfaceGUI.Parent = Part
			SurfaceGUI.Name = "F3XSurfaceGui"
			SurfaceGUI.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			SurfaceGUI.PixelsPerStud = 60
			SurfaceGUI.Face = Change.Face;	
			local Text = Instance.new("TextLabel", SurfaceGUI);
			Text.BackgroundTransparency = 1;
			Text.Size = UDim2.new(1, 0, 1, 0);
			Text.TextScaled = true;
			Text.RichText = false;
			Text.Font = Enum.Font.Arimo;
			Text.Text = "Use the text tool to edit me.";
			Text.TextTransparency = 0;
			Text.TextColor3 = Color3.fromRGB(255, 255, 255);
			local ActualTextValue = Instance.new("StringValue");
			ActualTextValue.Name = "ActualText";
			ActualTextValue.Parent = Text;
			ActualTextValue.Value = "Use the text tool to edit me.";




			table.insert(Texts, Text);

			-- Register the texture
			CreatedInstances[Text] = Text;

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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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

		-- Update each part's textures
		for Part, Change in pairs(ChangeSet) do

			-- Make sure that the texture type requested is valid
			-- Get the right textures within the part
			if Part.ClassName == "SurfaceGui" and Part.Face == Change.Face then
				for _, Surface in pairs(Part:GetChildren()) do
					for _, Text in pairs(Part:GetChildren()) do
						if Text.ClassName == "TextLabel" then
							-- Perform the changes
							if Change.Text ~= nil then
								
								local FinalText = FilterText(Change.Text) or Text.Text
								Text.Text = FinalText
								
								if Text:FindFirstChild("ActualText") then
									Text.ActualText.Value = Change.Text
								end
								
								--[[
								local filterResult
								local CleanedText

								local function CleanText(Text)
									return Text:gsub("<.+>", "") -- ".+" as for like any character more than 1 character. 
								end

								if Text.RichText == true then
									CleanedText = CleanText(Change.Text)
								else
									CleanedText = Change.Text
								end
								if not RunService:IsStudio() then
									local success, errorMessage = pcall(function()
										filterResult = game:GetService("TextService"):FilterStringAsync(CleanedText, game.Players:GetPlayerFromCharacter(Tool.Parent).UserId):GetNonChatStringForBroadcastAsync()
									end)
									if success then
										if CleanedText == filterResult then
											Text.Text = Change.Text
										else
											Text.Text = filterResult
										end
									end
									if errorMessage then
										warn(errorMessage)
										Text.Text = "Oops! Seems like the Roblox filtering experienced a problem..."
									end
									if Text:FindFirstChild("ActualText") then
										Text.ActualText.Value = Change.Text
									end
								else
									Text.Text = Change.Text
									if Text:FindFirstChild("ActualText") then
										Text.ActualText.Value = Change.Text
									end
								end]]
							end;
							if Change.TextTransparency ~= nil then
								Text.TextTransparency = Change.TextTransparency;
							end;
							if Change.RichText ~= nil then
								Text.RichText = Change.RichText;
								if not RunService:IsStudio() then
									local filterResult
									local CleanedText
									local StartText = Change.Text
									if Change.Text == nil then
										StartText = Text.ActualText.Value
									end
									local	function CleanText(Text)
										return Text:gsub("<.+>", "") -- ".+" as for like any character more than 1 character. 
									end
									if Text.RichText == true then
										CleanedText = CleanText(StartText)
									else
										CleanedText = StartText
									end
									local success, errorMessage = pcall(function()
										filterResult = game:GetService("TextService"):FilterStringAsync(CleanedText, game.Players:GetPlayerFromCharacter(Tool.Parent).UserId):GetNonChatStringForBroadcastAsync()
									end)
									if success then
										if CleanedText == filterResult then
											Text.Text = StartText
										else
											Text.Text = filterResult
										end
									end
									if errorMessage then
										warn(errorMessage)
										Text.Text = "Oops! Seems like the Roblox filtering experienced a problem..."
									end
								end
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

	end;


	['OldCreateUnion'] = function (Parts, NegativeParts, Split, Intersect)

		local AllParts = Support.Merge(table.clone(Parts), NegativeParts)

		if not CanModifyItems(AllParts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(AllParts, Player, true, AreaPermissions) then
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
						NegatedPart.Parent = Player
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
			if PartToDelete:IsA("PartOperation") then
				PartToDelete:Destroy()
			end
		end

		for _, Part in ipairs(AllParts) do
			Part:Destroy()
		end

		for _, Union in FinalUnions do
			if Player and game.Workspace.StreamingEnabled then
				Union.Parent = Player
			end

			Union.Parent = AllParts[1] and AllParts[1].Parent or game.Workspace
		end

		return FinalUnions
	end;

	['CreateUnion'] = function (Parts, NegativeParts, Split, Intersect)
		local AllParts = Support.ConcatTable(table.clone(Parts), NegativeParts)

		-- Ensure parts are selectable
		if not CanModifyItems(AllParts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(AllParts, Player, true, AreaPermissions) then
			return;
		end;

		local Unions = {}
		local FocusedUnion
		local TableToPart = {}
		
		-- Sort the unions to be able to add them to the final tree later
		for _, Part in AllParts do
			print(Part.ClassName)
			if (Part:IsA("PartOperation") or Part:IsA("UnionOperation")) and Part:GetAttribute("BTUnionData") then --and Part:GetAttribute("BTOriginalCFrame") then
				if not FocusedUnion and not table.find(NegativeParts, Part) then
					FocusedUnion = {Part, Part:GetAttribute("BTUnionData")}
				else
					table.insert(Unions, {Part, Part:GetAttribute("BTUnionData")})
				end
			end
		end

		local Result
		local IsFocusedUnionNegative = false

		print(Parts, NegativeParts)

		if #Unions ~= 0 and not FocusedUnion then
			FocusedUnion = Unions[1]
			table.remove(Unions, 1)
			IsFocusedUnionNegative = true
		end

		if not FocusedUnion then
			-- Get the union tree corresponding to the parts sets
			local UnionTree, Relative = CSGTree.CreateTreeFromParts(Parts, NegativeParts, Intersect or false)

			-- Create the union(s) from the obtained tree
			Result = CSGTree.CreateFromTree(UnionTree, {
				CollisionFidelity = Enum.CollisionFidelity.Hull,
				RenderFidelity = Enum.RenderFidelity.Performance,
				FluidFidelity = Enum.FluidFidelity.UseCollisionGeometry,
				SplitApart = false}, Relative)

			if Split == true then
				local OldResult = Result

				Result = game:GetService("GeometryService"):UnionAsync(Result, {}, {
					CollisionFidelity = Enum.CollisionFidelity.Hull,
					RenderFidelity = Enum.RenderFidelity.Performance,
					FluidFidelity = Enum.FluidFidelity.UseCollisionGeometry,
					SplitApart = true})

				for i, Part in Result do
					local NewTree = #Result > 1 and CSGTree.Split(table.clone(UnionTree), Relative, Part) or UnionTree

					local EncodedTable = HttpService:JSONEncode(NewTree)

					Part:SetAttribute("BTUnionData", EncodedTable)

					if Player and game.Workspace.StreamingEnabled then
						Part.Parent = Player
					end

					Part.Parent = AllParts[1] and AllParts[1].Parent or game.Workspace
					--	Part:SetAttribute("BTOriginalCFrame", FocusedUnion:GetAttribute("BTOriginalCFrame"))
				end
			else
				local EncodedTable = HttpService:JSONEncode(UnionTree)

				Result:SetAttribute("BTUnionData", EncodedTable)

				if Player and game.Workspace.StreamingEnabled then
					Result.Parent = Player
				end

				Result.Parent = AllParts[1] and AllParts[1].Parent or game.Workspace
			end
		else
			-- Get the union tree from the focused union
			local UnionTree = HttpService:JSONDecode(FocusedUnion[2])
			local UnionRelative = IsFocusedUnionNegative == true and Parts[1] and Parts[1].CFrame or FocusedUnion[1].CFrame

			if IsFocusedUnionNegative == true then
				UnionTree = CSGTree.OffsetTreeParts(UnionTree, UnionRelative:Inverse() * FocusedUnion[1].CFrame)

				UnionTree = CSGTree.AddPropertiesToTree(UnionTree, FocusedUnion[1])
			end

			local PartsWithoutUnions = table.clone(Parts)
			local NegativePartsWithoutUnions = table.clone(NegativeParts)
			local NegativeUnions = {}

			local FocusedUnionTree = IsFocusedUnionNegative and {[1] = {}} or UnionTree

			-- Add the other unions to the union tree according to their nature
			for _, Union in Unions do
				local UnionPart, Data = table.unpack(Union)
				
				TableToPart[UnionPart] = Data
				
				Data = HttpService:JSONDecode(Data)

				-- Set the relative to the focused union's
				Data = CSGTree.OffsetTreeParts(Data, UnionRelative:Inverse() * UnionPart.CFrame)

				-- Write the properties of the union
				Data = CSGTree.AddPropertiesToTree(Data, UnionPart)

				if table.find(NegativePartsWithoutUnions, UnionPart) then
					table.insert(NegativeUnions, Data)
					table.remove(NegativePartsWithoutUnions, table.find(NegativePartsWithoutUnions, UnionPart))
					
				elseif Intersect == true then
					FocusedUnionTree = CSGTree.AddIntersection(FocusedUnionTree, Data)
					table.remove(PartsWithoutUnions, table.find(PartsWithoutUnions, UnionPart))
				else
					FocusedUnionTree = CSGTree.AddUnion(FocusedUnionTree, Data)
					table.remove(PartsWithoutUnions, table.find(PartsWithoutUnions, UnionPart))
				end
			end

			-- Add the delayed negative unions
			for _, Union in NegativeUnions do
				FocusedUnionTree = CSGTree.AddNegation(FocusedUnionTree, Union)
			end

			-- Remove the focused union
			if table.find(NegativePartsWithoutUnions, FocusedUnion[1]) then
				table.remove(NegativePartsWithoutUnions, table.find(NegativePartsWithoutUnions, FocusedUnion[1]))
			else
				table.remove(PartsWithoutUnions, table.find(PartsWithoutUnions, FocusedUnion[1]))
			end

			--			print(PartsWithoutUnions, NegativePartsWithoutUnions)

			local TreePosition
			local PartsTree
			local NegativeTreePosition
			local NegativePartsTree

			--	PartsTree, TreePosition = CSGTree.CreateTreeFromParts(PartsWithoutUnions, {}, false, FocusedUnion.CFrame)
			--	NegativePartsTree, NegativeTreePosition = CSGTree.CreateTreeFromParts(NegativePartsWithoutUnions, {}, false, FocusedUnion.CFrame)

			-- Finally add the normal parts

			local PartsTree = CSGTree.CreateTreeFromParts(PartsWithoutUnions, {}, false, UnionRelative)
			local NegativePartsTree = CSGTree.CreateTreeFromParts(NegativePartsWithoutUnions, {}, false, UnionRelative)

			if IsFocusedUnionNegative then
				NegativePartsTree = CSGTree.AddUnion(NegativePartsTree, UnionTree)

				table.remove(FocusedUnionTree, 1)

				FocusedUnionTree[1] = PartsTree[1]
			else	
				FocusedUnionTree = Intersect and CSGTree.AddIntersection(FocusedUnionTree, PartsTree, true) or
					CSGTree.AddUnion(FocusedUnionTree, PartsTree, true)
			end

			FocusedUnionTree = CSGTree.AddNegation(FocusedUnionTree, NegativePartsTree, true)
			
			print(FocusedUnionTree)
			
			-- Create the union(s) from the obtained tree
			Result = CSGTree.CreateFromTree(FocusedUnionTree, {
				CollisionFidelity = Enum.CollisionFidelity.Hull,
				RenderFidelity = Enum.RenderFidelity.Automatic,
				FluidFidelity = Enum.FluidFidelity.UseCollisionGeometry,
				SplitApart = false}, UnionRelative, TableToPart)

				--[[
				if IsFocusedUnionNegative and Result and Parts[1] then
					Result.CFrame = Parts[1].CFrame
				end]]

			if Split == true then
				--		local OldResult = Result
				local OldResultCFrame = Result.CFrame

				Result = game:GetService("GeometryService"):UnionAsync(Result, {}, {
					CollisionFidelity = Enum.CollisionFidelity.Hull,
					RenderFidelity = Enum.RenderFidelity.Automatic,
					FluidFidelity = Enum.FluidFidelity.UseCollisionGeometry,
					SplitApart = true})

				for i, Part in Result do
					local NewTree = #Result > 1 and CSGTree.Split(table.clone(FocusedUnionTree), OldResultCFrame, Part) or UnionTree

					local EncodedTable = HttpService:JSONEncode(NewTree)

					Part:SetAttribute("BTUnionData", EncodedTable)

					if Player and game.Workspace.StreamingEnabled then
						Part.Parent = Player
					end

					Part.Parent = AllParts[1] and AllParts[1].Parent or game.Workspace
					--	Part:SetAttribute("BTOriginalCFrame", FocusedUnion:GetAttribute("BTOriginalCFrame"))
				end
			else
				local EncodedTable = HttpService:JSONEncode(FocusedUnionTree)

				Result:SetAttribute("BTUnionData", EncodedTable)

				if Player and game.Workspace.StreamingEnabled then
					Result.Parent = Player
				end

				Result.Parent = AllParts[1] and AllParts[1].Parent or game.Workspace
			end
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
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
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
			table.insert(Attachments, Attachment);

			-- Register the mesh
			CreatedInstances[Attachment] = Attachment;

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
		if not CanModifyItems(Attachments) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Attachments), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Attachments, Player, true, AreaPermissions) then
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
				local FinalName = FilterText(Change.Name) or Attachment.Name
				
				Attachment.Name = FinalName;
			end;

		end;

	end;

	['SaveBuild'] = function (Parts, Slot)
		-- Serializes, exports, and returns ID for importing given parts

		-- Offload action to server-side if API is running locally

		-- Ensure valid selection
		assert(type(Parts) == 'table', 'Invalid item table');

		-- Ensure there are items to export
		if #Parts == 0 or Player == nil or Slot > Options.NumberOfSaveSlots then
			return;
		end;

		-- Ensure parts are selectable
		if not CanModifyItems(Parts) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Parts), Player);

		-- Make sure the player is allowed to access these parts
		if Security.ArePartsViolatingAreas(Parts, Player, true, AreaPermissions) then
			return;
		end;

		-- Get all descendants of the parts
		local Items = Support.CloneTable(Parts);
		for _, Part in pairs(Parts) do
			Support.ConcatTable(Items, Part:GetDescendants());
		end;
		
		if Options.PreSerializaton then
			if Options.PreSerialization(Items, Player) ~= true then
				return "Fork3X's configuration denied your save.", [[Own this game? Make sure to return <b>true</b> at the end of the PreSerialization function if nothing's wrong.
				
				If nothing is wrong, you may have selected parts you aren't in measure to serialize, or another element forbids you to save.]]
			end
		end
		
		-- After confirming permissions, serialize parts
		local Success, SerializedBuildData = pcall(function() return SerializationV6.SerializeModel(Items, false) end);
		
		-- Check if the data fits with the size limits
		local TotalSizeWithoutPreviousData = SlotsTotalSize - SlotsSizes[Slot]
		
		if Options.SizeLimit < 0 and TotalSizeWithoutPreviousData + string.len(HttpService:JSONEncode(SerializedBuildData)) / 10240 > math.abs(Options.SizeLimit) then
			return "Your slot doesn't fit the global size limit.", 
			"Own this game? You can edit the tool's options and increase the limit if you find it too small."
		elseif Options.SizeLimit > 0 and string.len(HttpService:JSONEncode(SerializedBuildData)) / 10240 > Options.SizeLimit then
			return "Your slot is bigger than the maximum slot size.", 
			"Own this game? You can edit the tool's options and increase the limit if you find it too small."
		end

		-- Return creation ID on success
		if Success == true and SerializedBuildData then
			local DataStoreService = game:GetService("DataStoreService")
			local PlayerDataStore = DataStoreService:GetDataStore(Player.UserId .. "Builds")

			if PlayerDataStore then
				PlayerDataStore:SetAsync("Slot" .. Slot, SerializedBuildData)
				print(SerializedBuildData)
			end
		elseif SerializedBuildData then
			return 'Fork3X experienced an unexpected error while serializing. You can find it in the "What can I do?" section.',
			[[If this build of Fork3X isn't modified, report to the Fork3X creator the following error. Don't worry, your username has been removed:
			
			]] .. string.gsub(SerializedBuildData, "." .. Player.Name, "[PLAYER]")
		end;
		
		return true

	end;

	['LoadBuild'] = function (Slot)

		-- Ensure there are items to export
		if Player == nil then
			return;
		end;

		-- After confirming permissions, serialize parts
		local Build

		local DataStoreService = game:GetService("DataStoreService")
		local PlayerDataStore = DataStoreService:GetDataStore(Player.UserId .. "Builds")

		if PlayerDataStore then
			Build = PlayerDataStore:GetAsync("Slot" .. Slot)
			
			if type(Build) == "string" then
				Build = HttpService:JSONDecode(Build)
			end
		end

		-- Return creation ID on success
		if Build then
			local Container = Instance.new( 'Model', game.Workspace );
			Container.Name = Player.Name ..'BTLoad';

			local UsedModule = Build.Version == 4 and SerializationV4 or Build.Version == 5 and SerializationV5 or SerializationV6
			
			if Options.PreInflation then
				local InflatedData = Options.PreInflation(Build, Player)
				
				if InflatedData then
					for _, Item in InflatedData do
						Item.Parent = Container
					end
				end
			end
			
			local LoadedModel = UsedModule.InflateBuildData(Build)
			for _, Part in pairs(LoadedModel) do
				if game.Workspace.StreamingEnabled then
					Part.Parent = Player
				end

				Part.Parent = Container;
				Options.SetPermission(Part, Player, "New")
			end;

			return LoadedModel
		end;
		
		return true
		
	end;

	['CheckDataStores'] = function()
		local success, result = pcall(function()
			return game:GetService("DataStoreService"):GetDataStore("a")
		end)

		return success
	end,
	
	['GetSlotsSize'] = function(Slots)
		local DataStoreService = game:GetService("DataStoreService")
		local PlayerDataStore = DataStoreService:GetDataStore(Player.UserId .. "Builds")
		
		SlotsSizes = {}
		SlotsTotalSize = 0
		
		if PlayerDataStore then
			for Number in Slots do
				local Success, Data = pcall(function()
					return HttpService:JSONEncode(PlayerDataStore:GetAsync("Slot" .. Number))
				end)
				
--				print(Data)
				
				if Success and Data ~= "" and Data ~= nil then
					SlotsSizes[Number] = Support.Round(#Data / 1024, 3)
					
					SlotsTotalSize += SlotsSizes[Number]
				else
					SlotsSizes[Number] = 0
				end;
			end
		end

		-- Return creation ID on success
		return SlotsSizes, SlotsTotalSize
	end,

	--[[
	['SeparateUnion'] = function(Unions)
		if not CanModifyItems(Unions) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Unions), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Unions, Player, true, AreaPermissions) then
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
						Part.Parent = Player
					end

					Part.Parent = Union.Parent
					table.insert(FinalParts, Part)

					local Translation = DataPosition:ToObjectSpace(Part.CFrame)

					Part.CFrame = Union.CFrame * Translation
				end

				local LoadedNegativeParts = SerializationV5.InflateBuildData(DataNegativeParts)

				for _, NegativePart in LoadedNegativeParts do
					if game.Workspace.StreamingEnabled then
						NegativePart.Parent = Player
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
		if not CanModifyItems(Unions) then
			return;
		end;

		-- Cache up permissions for all private areas
		local AreaPermissions = Security.GetPermissions(Security.GetSelectionAreas(Unions), Player);

		-- Make sure the player is allowed to perform changes to these parts
		if Security.ArePartsViolatingAreas(Unions, Player, true, AreaPermissions) then
			return;
		end;

		local FinalParts = {}
		local FinalNegativeParts = {}

		-- Get the tree from each union if they got one
		for _, Union in Unions do
			if Union:IsA("PartOperation") and Union:GetAttribute("BTUnionData") then --and Union:GetAttribute("BTOriginalCFrame") then
				local Tree = HttpService:JSONDecode(Union:GetAttribute("BTUnionData"))

				local SeparatedTree, Negative, Leave, FinalLeave = CSGTree.Separate(Tree)

				local Parameters = {
					CollisionFidelity = Enum.CollisionFidelity.Hull,
					RenderFidelity = Enum.RenderFidelity.Performance,
					FluidFidelity = Enum.FluidFidelity.UseCollisionGeometry,
					SplitApart = false}

				local SerializedTree = SeparatedTree.Items and SerializationV6.InflateBuildData(SeparatedTree, true, Union.CFrame) or CSGTree.CreateFromTree(SeparatedTree, Parameters, Union.CFrame)
				local SerializedLeave = Leave.Items and SerializationV6.InflateBuildData(Leave, true, Union.CFrame) or CSGTree.CreateFromTree(Leave, Parameters, Union.CFrame)

				--local SerializedTree = CSGTree.CreateFromTree(SeparatedTree, Parameters, Union.CFrame)
				--local SerializedLeave = SerializationV6.InflateBuildData(Leave, true, Union.CFrame)

				if Negative == true then
					FinalNegativeParts = type(SerializedLeave) == "table" and SerializedLeave or {SerializedLeave}
				else
					FinalParts = type(SerializedLeave) == "table" and SerializedLeave or {SerializedLeave}
				end

				Support.ConcatTable(FinalParts, type(SerializedTree) == "table" and SerializedTree or {SerializedTree})
				
				print(SeparatedTree, FinalLeave)
				
				local EncodedTree = HttpService:JSONEncode(SeparatedTree)
				local EncodedLeave = HttpService:JSONEncode(FinalLeave)

				local function ApplyExtraChanges(Part, Data)

					print(Part, Part.Parent)
					--[[
					if Table and not Table.Items and Table[#Table - 1] == 5 then
						local UnionProperties = Table[#Table]

						if type(SerializedTree) == "table" then
							print("blame you vikko")
						end

						Part.Size = vector.create(table.unpack(Support.Slice(SeparatedTree, 1, 3)))
						if Part:IsA("PartOperation") then
							Part.UsePartColor = SeparatedTree[4]
						end
						Part.Color = Color3.new(table.unpack(Support.Slice(SeparatedTree, 5, 7)))
						Part.Material = Enum.Material:FromValue(SeparatedTree[8])
						Part.MaterialVariant = SeparatedTree[9]
						
						for i = 1, 2 do
							table.remove(Table, #Table)
						end
					end

					if Table and not Table.Items and Table[#Table - 1] == 4 then
						for i = 1, 2 do
							table.remove(Table, #Table)
						end
					end]]

					if Part:IsA("PartOperation") then
						Part:SetAttribute("BTUnionData", Data)
						--	Part:SetAttribute("BTOriginalCFrame", Union:GetAttribute("BTOriginalCFrame"))
					end

					if Player and game.Workspace.StreamingEnabled then
						Part.Parent = Player
					end

					Part.Parent = Union.Parent
				end

				if type(SerializedTree) == "table"  then
					for _, Part in SerializedTree do
						ApplyExtraChanges(Part, EncodedTree)
					end
				elseif SerializedTree ~= nil then
					ApplyExtraChanges(SerializedTree, EncodedTree)
				end

				if type(SerializedLeave) == "table"  then
					for _, Part in SerializedLeave do
						ApplyExtraChanges(Part, EncodedLeave)
					end
				elseif SerializedLeave ~= nil then
					ApplyExtraChanges(SerializedLeave, EncodedLeave)
				end
			end
		end

		return FinalParts, FinalNegativeParts
	end,
};

for FunctionName, Function in Options.ExtraSyncAPIFunctions do
	Actions[FunctionName] = function(...)
		return Function(Player, Security, ...)
	end
end

function CanModifyItems(Items)
	-- Returns whether the items can be modified
	-- Check each item
	for _, Item in pairs(Items) do

		-- Catch items that cannot be reached
		local ItemAllowed = Security.IsItemAllowed(Item, Player)
		local LastParentKnown = LastParents[Item]
		if not (ItemAllowed or LastParentKnown) then
			return false
		end
		
		-- Catch the baseplate
		if Item:FindFirstAncestorWhichIsA("Terrain") or not Item:FindFirstAncestor("Workspace") and Item.Parent ~= nil and Item.Parent ~= Player then
			if Options.OnlySelectInWorkspace == true then
				Options.BadBehaviorFunction(Player, Options.WebhookModule, "Forbidden", {})
				return false
			end
		end

		-- Catch locked parts
		if Options.DisallowLocked and (Item:IsA 'BasePart') and Item.Locked then
			return false
		end

	end

	-- Return true if all items modifiable
	return true

end

function GetPartsFromSelection(Selection)
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

function GetPartJoints(Part, Whitelist)
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

-- Types of joints to assume should be preserved
local ManualJointTypes = Support.FlipTable { 'Weld', 'ManualWeld', 'ManualGlue', 'Motor', 'Motor6D' };

function SearchJoints(Haystack, Part, Whitelist)
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

function RestoreJoints(Joints)
	-- Restores the joints from the given `Joints` data

	-- Restore each joint
	for Joint, JointParent in pairs(Joints) do
		Joint.Parent = JointParent;
	end;

end;

function PreserveJoints(Part, Whitelist)
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

function FilterText(Text, RichText)
	if not RunService:IsStudio() then
		local CleanedText

		if RichText == true then
			CleanedText = Text:gsub("<.+>", "")
		else
			CleanedText = Text
		end
		
		local FilterResult
		
		local success, errorMessage = pcall(function()
			FilterResult = game:GetService("TextService"):FilterStringAsync(CleanedText, game.Players:GetPlayerFromCharacter(Tool.Parent).UserId):GetNonChatStringForBroadcastAsync()
		end)
		if success then
			if CleanedText == FilterResult then
				return Text
			else
				return FilterResult
			end
		elseif errorMessage then
			warn(errorMessage)
			return nil
		end
	else
		return Text
	end
end

function CreatePart(PartType)
	-- Creates and returns new part based on `PartType` with sensible defaults

	if Options.InstanceBlacklist[PartType] then
		return
	end
	
	local CustomPartTypes = type(Options.CustomPartTypes) == "function" and Options.CustomPartTypes() or Options.CustomPartTypes
	
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

	elseif PartType == 'Cylinder' then
		NewPart = Instance.new('Part')
		NewPart.Shape = 'Cylinder'
		NewPart.Size = vector.create(2, 2, 2)

	elseif PartType == 'Ball' then
		NewPart = Instance.new('Part')
		NewPart.Shape = 'Ball'

	elseif PartType == 'Seat' then
		NewPart = Instance.new('Seat')
		NewPart.Size = vector.create(4, 1, 2)

	elseif PartType == 'Vehicle Seat' then
		NewPart = Instance.new('VehicleSeat')
		NewPart.Size = vector.create(4, 1, 2)

	elseif PartType == 'Spawn' then
		NewPart = Instance.new('SpawnLocation')
		NewPart.Size = vector.create(4, 1, 2)

	elseif PartType == 'Tool' then
		NewPart = Instance.new('Tool')

		local Handle = Instance.new('Part')
		Handle.Name = "Handle"
		Handle.Size = vector.one
		Handle.Parent = NewPart
		Handle.Anchored = false

		Handle.TopSurface = Enum.SurfaceType.Smooth;
		Handle.BottomSurface = Enum.SurfaceType.Smooth;

		Options.SetPermission(Handle, Player, "New")

		return NewPart
	elseif CustomPartTypes[PartType] then
		NewPart = CustomPartTypes[PartType]()

		Options.SetPermission(NewPart, Player, "New")

		return NewPart
	end

	Options.SetPermission(NewPart, Player, "New")

	-- Make part surfaces smooth
	NewPart.TopSurface = Enum.SurfaceType.Smooth;
	NewPart.BottomSurface = Enum.SurfaceType.Smooth;

	-- Make sure the part is anchored
	NewPart.Anchored = true

	return NewPart
end

-- Keep current player updated in tool mode
if ToolMode == 'Tool' then

	-- Set current player if in backpack
	if Tool.Parent and Tool.Parent:IsA 'Backpack' then
		Player = Tool.Parent.Parent;

		-- Set current player if in character
	elseif Tool.Parent and Tool.Parent:IsA 'Model' then
		Player = game.Players:GetPlayerFromCharacter(Tool.Parent);

		-- Clear `Player` if not in possession of a player
	else
		Player = nil;
	end;

	-- Stay updated with latest player operating the tool
	Tool.AncestryChanged:Connect(function (Child, Parent)

		-- Ensure tool's parent changed
		if Child ~= Tool then
			return;
		end;

		-- Set `Player` to player of the backpack the tool is in
		if Parent and Parent:IsA 'Backpack' then
			Player = Parent.Parent;

			-- Set `Player` to player of the character holding the tool
		elseif Parent and Parent:IsA 'Model' then
			Player = game.Players:GetPlayerFromCharacter(Parent);

			-- Clear `Player` if tool is not parented to a player
		else
			Player = nil;

			-- Clean up remaining clone streaming metadata before tool becomes unable to
			for clone in streamingClonesPendingUntagging do
				clone:RemoveTag("BTStreamingClone")
				clone:SetAttribute("BTStreamingCloneID", nil)
				streamingClonesPendingUntagging[clone] = nil
			end
		end;

	end);

end;

-- Provide an interface into the module
return {

	-- Provide access to internal options
	Options = Options;

	-- Provide client actions API
	PerformAction = function (Client, ActionName, ...)

		-- Make sure the action exists
		local Action = Actions[ActionName];
		if not Action then
			return;
		end;

		-- Ensure client is current player in tool mode
		if ToolMode == 'Tool' then
			assert(Player and (Client == Player), 'Permission denied for client');
		end;

		-- Execute valid actions
		return Action(...);

	end;

};
