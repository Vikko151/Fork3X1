--!strict
--[[
A simple library that allows unions to be manipulated and tracked

Author: Copyright (c) 2026 VikkoMakesStuff, Vikko151
License: MIT License
Github: https://github.com/VikkoMakesStuff/CSGTree
]]

local CSGTree = {}
CSGTree.Version = 2

-- Enable this to get Studio-alike unions
CSGTree.UseParityPatch = true

-- ==================================
-- SERVICES
-- ==================================

local HttpService = game:GetService("HttpService")
local GeometryService = game:GetService("GeometryService")

-- ==================================
-- MODULES
-- ==================================

local PropScan = require(script.Parent.PropScan)
local Support = require(script.Parent.SupportLibrary)
local CSGTreeV1 = require(script.Parent.CSGTreeV1)

-- ==================================
-- CONFIGURATION
-- ==================================

-- You can also type check the serialized data if you want
-- If you don't, just put any
type ItemsData = {
	["Version"]: number,
	["Items"]: {
		[string]: {
			[number]: any
		},
	}
}

-- You can put the serialization method here
CSGTree.Serialize = function(Items: { [number]: Instance }, ReferenceCFrame: CFrame?): ItemsData
	type Serializer = { 
		["SerializeModel"]: ( { [number]: Instance }, CFrame? ) -> ItemsData
	}
	
	local ItemsToSerialize = table.clone(Items);
	
	for _, Item in Items do
		Support.ConcatTable(ItemsToSerialize, Item:GetDescendants());
	end;

	local SerializationModule: Serializer = require(script.Parent.SerializationV6)() :: Serializer

	return SerializationModule.SerializeModel(ItemsToSerialize, ReferenceCFrame)
end

-- You can put the desialize method here
CSGTree.Desialize = function(Data: ItemsData, DesiredCFrame: CFrame?): {Instance}
	type Serializer = { 
		["InflateBuildData"]: ( ItemsData, boolean?, CFrame? ) -> {Instance}
	}

	local VersionsToModule: {Serializer} = {
		[6] = require(script.Parent.SerializationV6)() :: Serializer
	}

	local SerializationModule: Serializer = VersionsToModule[Data.Version]

	return SerializationModule.InflateBuildData(Data, nil, DesiredCFrame)
end

-- ==================================
-- TYPES
-- ==================================

-- The data we find in a CSGHandler
export type CSGLeaf = {
	["Operation"]: number?,
	["Data"]: ItemsData? | CSGHandler?,
	["CFrame"]: { [number]: number }?,
	["Properties"]: { [string]: any }?,
}

-- Where we put our union's data
export type CSGHandler = {
	["Version"]: number?,
	["Data"]: { CSGLeaf }?,
	["Pivot"]: { [number]: number }? | boolean?,
	["SplitAt"]: { [number]: number }?,
}

-- The GeometryService's parameters
export type CSGParameters = {
	["CollisionFidelity"]: Enum.CollisionFidelity?,
	["RenderFidelity"]: Enum.RenderFidelity?,
	["FluidFidelity"]: Enum.FluidFidelity?,
	["SplitApart"]: boolean?,
}

-- ==================================
-- LOCAL FUNCTIONS
-- ==================================

-- Converts the given table into a CFrame
local function TableToCFrame(Table: {number}): CFrame
	return CFrame.new( unpack( Support.Slice(Table, 1, 3) ) ) * CFrame.fromOrientation( unpack( Support.Slice(Table, 4, 6) ) )
end

-- Converts the given table into a Vector3
local function TableToVector3(Table: {number}): Vector3
	return Vector3.new( unpack(Table) )
end

-- Converts the given CFrame into a table
local function CFrameToTable(GivenCFrame: CFrame): {number}
	return { 
		GivenCFrame.Position.X, GivenCFrame.Position.Y, GivenCFrame.Position.Z, -- Position
		GivenCFrame:ToOrientation() -- Rotation
	}
end

-- ==================================
-- READING
-- ==================================

-- Returns whether the given leaf is a parenthesis
function CSGTree.IsAParenthesis(Leaf: CSGLeaf): boolean
	return Leaf.Operation and Leaf.Operation < 0 or false
end

-- ==================================
-- CREATION
-- ==================================

--[[Creates a CSGLeaf from the given Items and Operation

AVAILABLE OPERATIONS:
- 1: Union
- 2: Negate
- 3: Intersection

Use a negative number to put a tree (parenthesis) inside]] 
function CSGTree.CreateLeafFromItems(Items: { [number]: Instance }, Origin: CFrame, Operation: number): CSGLeaf
	-- Create the leaf with its type
	local NewLeaf: CSGLeaf = {}

	-- Set some data with the given parameters
	NewLeaf.Operation = Operation
	NewLeaf.Data = CSGTree.Serialize(Items, Origin)

	return NewLeaf
end

--[[Returns a parenthesis with the tree inside

AVAILABLE OPERATIONS:
- 1: Union
- 2: Negate
- 3: Intersection]]
function CSGTree.CreateParenthesisWithTree(Tree: CSGHandler, Operation: number): CSGLeaf
	-- Create the leaf with its type
	local NewLeaf: CSGLeaf = {}

	-- Set some data with the given parameters
	NewLeaf.Operation = -Operation
	NewLeaf.Data = Tree

	return NewLeaf
end

-- Returns an empty tree
function CSGTree.CreateTree(): CSGHandler
	-- Create the leaf with its type
	local NewTree: CSGHandler = {}

	NewTree.Version = CSGTree.Version
	NewTree.Data = {}

	return NewTree
end

--[[Creates a CSG Tree from the given Items and Operation

AVAILABLE OPERATIONS:
- 1: Union
- 2: Negate
- 3: Intersection]]
function CSGTree.CreateTreeFromItems(Items: { [number]: Instance }, Origin: CFrame, Operation: number): CSGHandler
	-- Create the leaf with its type
	local NewTree: CSGHandler = {}

	NewTree.Version = CSGTree.Version
	NewTree.Data = { CSGTree.CreateLeafFromItems(Items, Origin, Operation) }

	return NewTree
end

-- ==================================
-- MODIFICATION
-- ==================================

-- Returns a new version of the union that's correctly centered
function CSGTree.FixUnionCFrame(Item: TriangleMeshPart, Parameters: CSGParameters, DesiredCFrame: CFrame?): TriangleMeshPart
	-- If a position for the patch is given, use it
	if DesiredCFrame then
		-- Create the reference part for the patch
		local PatchPart = Instance.new("Part")

		-- Replicate most properties
		local PartProperties = Support.FlipTable( PropScan.GetPropertiesOfClass("Part", false) )
		local CustomResultProperties = PropScan.GetCustomPropertiesOfObject(Item)

		for Property, Value in CustomResultProperties do
			if PartProperties[Property] then
				PatchPart[Property] = Value
			end
		end

		-- Reposition this part at the given reference
		PatchPart.CFrame = DesiredCFrame

		-- Make it transparent and very small to avoid issues
		PatchPart.Size = Vector3.zero

		local Mesh = Instance.new("SpecialMesh")
		Mesh.MeshType = Enum.MeshType.Brick
		Mesh.Scale = Vector3.zero

		-- Create a duplicate of the parameters with SplitApart disabled
		local LocalParameters: CSGParameters = Parameters
		LocalParameters.SplitApart = false

		-- Return the new result
		return GeometryService:UnionAsync( PatchPart, {Item}, LocalParameters :: { [string]: any } )[1]	
	else
		-- If only the patch is enabled, find the union's actual position and union it back with a part at the origin as the main one

		-- Create a model as a container
		local Container = Instance.new("Model")
		
		local ItemPreviousParent = Item.Parent
		
		-- Put the result in it
		Item.Parent = Container

		-- Get the bounding box's position of the union
		local Position = Container:GetBoundingBox()
		
		-- Restore the Item's former parent
		Item.Parent = ItemPreviousParent
		
		-- Create the reference part for the patch
		local PatchPart = Instance.new("Part")

		-- Replicate most properties
		local PartProperties = Support.FlipTable( PropScan.GetPropertiesOfClass("Part", false) )
		local CustomResultProperties = PropScan.GetCustomPropertiesOfObject(Item)

		for Property, Value in CustomResultProperties do
			if PartProperties[Property] then
				PatchPart[Property] = Value
			end
		end
		
		-- Reposition this part
		PatchPart.CFrame = Position

		-- Make it very small and use a SpecialMesh to avoid issues
		PatchPart.Size = Vector3.zero

		local Mesh = Instance.new("SpecialMesh")
		Mesh.MeshType = Enum.MeshType.Brick
		Mesh.Scale = Vector3.zero

		-- Create a duplicate of the parameters with SplitApart disabled
		local LocalParameters: CSGParameters = Parameters
		LocalParameters.SplitApart = false

		-- Set the new result in the result table
		return GeometryService:UnionAsync( PatchPart, {Item}, LocalParameters :: { [string]: any } )[1]
	end
end

-- Tracks relevant properties from the given leaf and its respective union.
function CSGTree.TrackUnionProperties( Leaf: CSGLeaf, Union: TriangleMeshPart )

	-- Make sure nothing is missing
	assert(Leaf and type(Leaf) == "table" and Leaf.Operation, "[CSGTREE]: A CSG leaf must be given. Use CSGTree.CreateLeafFromItems to create a leaf from objects.")
	
	-- Set the properties table
	Leaf.Properties = {
		Size = HttpService:JSONEncode({ Union.Size.X, Union.Size.Y, Union.Size.Z }),
		UsePartColor = Union:IsA("PartOperation") and Union.UsePartColor or false,
		Color = Union.Color:ToHex(),
		Material = Union.Material.Value,
		MaterialVariant = Union.MaterialVariant
	}
end

-- Offsets the given leaf from the given union according to its part.
function CSGTree.OffsetLeafFromUnion( Leaf: CSGLeaf, LeafUnion: TriangleMeshPart, MainUnion: TriangleMeshPart )

	-- Make sure nothing is missing
	assert(Leaf and type(Leaf) == "table" and Leaf.Operation, "[CSGTREE]: A CSG leaf must be given. Use CSGTree.CreateLeafFromItems to create a leaf from objects.")

	-- Find the distance between both objects
	local Distance = MainUnion.CFrame:Inverse() * LeafUnion.CFrame

	-- Put this distance as the CFrame property
	Leaf.CFrame = CFrameToTable(Distance)
end

-- ==================================
-- OPERATIONS
-- ==================================

--[[Adds a union operation to a tree]]
function CSGTree.Union( Tree: CSGHandler, Leaf: CSGLeaf )

	-- Make sure nothing is missing
	assert(Tree and type(Tree) == "table", "[CSGTREE]: A CSG tree or a list of instances must be given. Use CSGTree.CreateTreeFromItems to create a tree from objects.")

	assert(Leaf and type(Leaf) == "table", "[CSGTREE]: A CSG leaf or a list of instances must be given. Use CSGTree.CreateLeafFromItems to create a tree from objects.")

	-- If there's nothing in the leaf, don't add it
	if not Leaf.Data or (Leaf.Data.Items and Support.CountKeys(Leaf.Data.Items) == 0
		or Leaf.Data.Data and #Leaf.Data.Data == 0) then

		return
	end

	-- Make sure the leaf is an union ( Leaf.Operation / math.abs(Leaf.Operation) maintains the nature of the leaf )
	Leaf.Operation = 1 * Leaf.Operation :: number / math.abs(Leaf.Operation :: number)

	-- Add it to the tree
	table.insert(Tree.Data :: {CSGLeaf}, Leaf :: CSGLeaf)
end

--[[Adds a negate operation to a tree]]
function CSGTree.Negate( Tree: CSGHandler, Leaf: CSGLeaf )

	-- Make sure nothing is missing
	assert(Tree and type(Tree) == "table", "[CSGTREE]: A CSG tree or a list of instances must be given. Use CSGTree.CreateTreeFromItems to create a tree from objects.")

	assert(Leaf and type(Leaf) == "table", "[CSGTREE]: A CSG leaf or a list of instances must be given. Use CSGTree.CreateLeafFromItems to create a tree from objects.")

	-- If there's nothing in the leaf, don't add it
	if not Leaf.Data or (Leaf.Data.Items and Support.CountKeys(Leaf.Data.Items) == 0
		or Leaf.Data.Data and #Leaf.Data.Data == 0) then

		return
	end

	-- Make sure the leaf is an union ( Leaf.Operation / math.abs(Leaf.Operation) maintains the nature of the leaf )
	Leaf.Operation = 2 * Leaf.Operation :: number / math.abs(Leaf.Operation :: number)

	-- Add it to the tree
	table.insert(Tree.Data :: {CSGLeaf}, Leaf :: CSGLeaf)
end

--[[Adds an intersect operation to a tree]]
function CSGTree.Intersect( Tree: CSGHandler, Leaf: CSGLeaf )

	-- Make sure nothing is missing
	assert(Tree and type(Tree) == "table", "[CSGTREE]: A CSG tree or a list of instances must be given. Use CSGTree.CreateTreeFromItems to create a tree from objects.")

	assert(Leaf and type(Leaf) == "table", "[CSGTREE]: A CSG leaf or a list of instances must be given. Use CSGTree.CreateLeafFromItems to create a tree from objects.")

	-- If there's nothing in the leaf, don't add it
	if not Leaf.Data or (Leaf.Data.Items and Support.CountKeys(Leaf.Data.Items) == 0
		or Leaf.Data.Data and #Leaf.Data.Data == 0) then

		return
	end

	-- Make sure the leaf is an union ( Leaf.Operation / math.abs(Leaf.Operation) maintains the nature of the leaf )
	Leaf.Operation = 3 * Leaf.Operation :: number / math.abs(Leaf.Operation :: number)

	-- Add it to the tree
	table.insert(Tree.Data :: {CSGLeaf}, Leaf :: CSGLeaf)
end

--[[Changes the given tree to take in account that a part of the union must be split.]]
function CSGTree.SplitFromUnion( Tree: CSGHandler, TreeCFrame: CFrame, SplitUnion: TriangleMeshPart )
	-- Make sure nothing is missing
	assert(Tree and type(Tree) == "table", "[CSGTREE]: A CSG tree or a list of instances must be given. Use CSGTree.CreateTreeFromItems to create a tree from objects.")

	-- Find the distance between both objects
	local Distance = TreeCFrame:Inverse() * SplitUnion.CFrame

	-- Put this distance as the CFrame property
	Tree.SplitAt = CFrameToTable(Distance)
end

-- ==================================
-- GENERATION
-- ==================================

--[[Returns the result of the GeometryService function corresponding to the action. UseParityPatchAt also readjusts the union's postion to the given CFrame.]]
function CSGTree.UseGeometryServiceWithOperation( Operation: number, MainObject: Instance?, Objects: {Instance}, Parameters: CSGParameters, UseParityPatchAt: CFrame? | boolean? ): {TriangleMeshPart}
	-- Make equivalences for the operations
	local FunctionsEquivalences: { ( GeometryService, Instance?, {Instance}, CSGParameters ) -> {TriangleMeshPart} } = {
		[1] = GeometryService.UnionAsync,
		[2] = GeometryService.SubtractAsync,
		[3] = GeometryService.IntersectAsync,
	}

	-- Make sure the action exists
	assert(FunctionsEquivalences[ math.abs(Operation) ], "The given action number doesn't exist. It must be between 1 and 3.")

	-- Make sure there's a main object if it's not an union
	if Operation == 2 then
		assert(MainObject, "A main object is necessary for this action (" .. math.abs(Operation) .. ")")
	end

	-- Register the action
	local RequestedFunction = FunctionsEquivalences[ math.abs(Operation) ]

	-- In the case of an union operation, make sure there's a MainObject
	if not MainObject then
		-- Find the first object
		MainObject = Objects[1]
		
		-- Make sure there's an object
		assert(MainObject, "The 3rd parameter `Objects` has no first index, while `MainObject` is missing.")

		-- Clone the objects list to prevent touching the original one
		Objects = table.clone(Objects)

		-- Remove the main object
		table.remove(Objects, 1)
	end

	-- Do the action
	local Result: {TriangleMeshPart} = RequestedFunction(GeometryService, MainObject, Objects, Parameters)

	-- If the parity patch is requested, apply it
	if CSGTree.UseParityPatch and UseParityPatchAt ~= false then
		for Index, Object in Result do
			Result[Index] = CSGTree.FixUnionCFrame(Object, Parameters, UseParityPatchAt)
		end
	end

	-- Return the result
	return Result
end	

-- Returns an array of unions from the given tree at the given CFrame. The parts can be sorted according to the SplitNegatives parameter
function CSGTree.CreatePartsFromTree( Tree: CSGHandler, DesiredCFrame: CFrame, SplitNegatives: boolean ): ({Instance}, {Instance}?)
	-- Create a list of every part
	local Parts = {}

	-- Create the optional negative parts table
	local NegativeParts = {}

	-- Make sure the tree has data
	assert(Tree and Tree.Data, "The tree is empty. Did you set its data in Tree.Data?")

	-- Go through each leaf
	for _, Leaf: CSGLeaf in Tree.Data do
		-- Make sure it's a leaf and not a full stop
		if type(Leaf) == "table" then
			-- Find the leaf's data
			local LeafData = Leaf.Data

			-- Check whether the leaf is a parenthesis
			local IsAParenthesis = CSGTree.IsAParenthesis(Leaf)

			-- Track the data
			local LeafParts: {Instance} = {}
			local LeafNegativeParts: {Instance} = {}

			-- If it's a parenthesis, call this function on the data
			if IsAParenthesis then
				LeafParts, LeafNegativeParts = CSGTree.CreatePartsFromTree(LeafData :: CSGHandler, DesiredCFrame, SplitNegatives)
			else
				-- Desialise the data instead
				if SplitNegatives and Leaf.Operation == 2 then
					LeafNegativeParts = CSGTree.Desialize(LeafData :: ItemsData, DesiredCFrame)
				else
					LeafParts = CSGTree.Desialize(LeafData :: ItemsData, DesiredCFrame)
				end
			end

			-- Concat both tables
			Support.ConcatTable(Parts, LeafParts)
			Support.ConcatTable(NegativeParts, LeafNegativeParts)
		end
	end

	-- Return the parts
	return Parts, NegativeParts
end

-- Returns an array of unions from the given tree at the given CFrame, with optional Parameters.
function CSGTree.CreateUnionFromTree( Tree: CSGHandler, DesiredCFrame: CFrame, Parameters: CSGParameters ): ({TriangleMeshPart}, CFrame)
	-- If the tree is a legacy one, use the old module
	if not Tree.Version then
		return {CSGTreeV1.CreateFromTree( Tree, Parameters, DesiredCFrame, TableToPart )}
	end

	-- Create a list of every union
	local Unions = {}

	local CurrentUnion: TriangleMeshPart

	-- Create a duplicate of the current parameters with SplitApart disabled
	local LocalParameters: CSGParameters = table.clone(Parameters)
	
	LocalParameters.SplitApart = false

	-- Make sure the tree has data
	assert(Tree and Tree.Data, "The tree is empty. Did you set its data in Tree.Data?")

	-- Go through each leaf in their respective order
	for _, Leaf: CSGLeaf in next, Tree.Data do
		-- Make sure it's a leaf and not a full stop
		if type(Leaf) == "table" then
			-- Find the leaf's data
			local LeafData = Leaf.Data

			-- Check whether the leaf is a parenthesis
			local IsAParenthesis = CSGTree.IsAParenthesis(Leaf)

			-- Track the data
			local LeafUnion: TriangleMeshPart

			-- Decompile the CFrame
			local LeafCFrame = Leaf.CFrame and TableToCFrame(Leaf.CFrame) or CFrame.new()

			-- If it's a parenthesis, call this function on the data
			if IsAParenthesis then
				local Result = CSGTree.CreateUnionFromTree(LeafData :: CSGHandler, DesiredCFrame * LeafCFrame, LocalParameters)

				if Result then
					LeafUnion = Result[1]
					
				else
					error("[CSGTREE]: No union got returned when trying to inflate a parenthesis. Aborting.")
				end
			else
				-- Desialise the leaf's data
				local Parts = CSGTree.Desialize(LeafData :: ItemsData, DesiredCFrame * LeafCFrame)
				
				-- Union them so further changes can be applied
				LeafUnion = CSGTree.UseGeometryServiceWithOperation(Leaf.Operation == 2 and 1 or Leaf.Operation :: number, nil, Parts, LocalParameters)[1]
			end

			-- If there are any, apply the properties
			if Leaf.Properties then
				-- Inflate a table with functions to convert each property
				local ConversionFunctions = {
					Size = function(Value)
						return TableToVector3( HttpService:JSONDecode(Value) )
					end,
					Color = Color3.fromHex,
					Material = function(Value)
						return Enum.Material:FromValue(Value)
					end,
				}

				for Name, Value in Leaf.Properties do
					LeafUnion[Name] = ConversionFunctions[Name] and ConversionFunctions[Name](Value) or Value
				end
			end
			
			if CurrentUnion then
				-- If there currently is an union, apply the action on it
				CurrentUnion = CSGTree.UseGeometryServiceWithOperation(Leaf.Operation :: number, CurrentUnion, {LeafUnion}, LocalParameters, nil)[1]
			else
				-- If there's no union, set the leaf as the union
				CurrentUnion = LeafUnion
			end
		end
	end
	
	-- If there is no CurrentUnion, abort creation
	if CurrentUnion == nil then
		return {}, CFrame.new()
	end

	local Result: {TriangleMeshPart}

	if Tree.Pivot then
		-- If a pivot is requested, create it and fix the union's position
		local TreePivot = TableToCFrame(Tree.Pivot)
		
		CurrentUnion = CSGTree.FixUnionCFrame(CurrentUnion, LocalParameters, CurrentUnion.CFrame:ToWorldSpace(TreePivot))
	elseif Tree.Pivot == nil and CSGTree.UseParityPatch then
		-- However, if the parity patch is requested, adapt the tree to the new CFrame
		
		-- Calculate the distance between the new union's CFrame and the desired one
		local Distance = CurrentUnion.CFrame:ToObjectSpace(DesiredCFrame)--DesiredCFrame:Inverse() * CurrentUnion.CFrame
		
		-- For each leaf, adjust their offset to the new position
		for _, Leaf: CSGLeaf in Tree.Data do
			-- Get the leaf's CFrame
			local LeafCFrame: CFrame = Leaf.CFrame and TableToCFrame(Leaf.CFrame) or CFrame.new()
			
			-- Adjust its CFrame to the new one
			Leaf.CFrame = CFrameToTable(Distance * LeafCFrame)
		end
		
		-- Set the pivot to false to prevent this piece of code from being executed uselessly
		Tree.Pivot = false
	end
	
	-- To allow separation to be tracked, keep the current union's CFrame
	local CurrentCFrame = CurrentUnion.CFrame

	-- If spliting is required by the environment OR by the tree itself, split the final union
	if Parameters.SplitApart == true or Tree.SplitAt then
		-- Because there won't be any new operation, recycle the LocalParameters
		LocalParameters.SplitApart = true
		
		Result = CSGTree.UseGeometryServiceWithOperation(1, CurrentUnion, {}, LocalParameters, nil)

		-- If spliting was required by the tree, find the necessary part
		if Tree.SplitAt then
			-- Convert this data into a CFrame
			local SplitAt = TableToCFrame(Tree.SplitAt)

			for _, Object in Result do
				-- Find the current object's position
				local ObjectPosition = CurrentUnion.CFrame:Inverse() * Object.CFrame

				-- If this position is the same or very near from the registered position, select it
				if SplitAt:FuzzyEq(ObjectPosition, 0.01) then
					Result = {Object}

					break
				end
			end

			-- If none of the objects respected this condition, set the first one
			if #Result > 1 then
				Result = { Result[1] }
			end
		end
	else
		-- Set the current union as the result
		Result = {CurrentUnion}
	end

	-- Return the result
	return Result, CurrentCFrame
end

-- Returns a CSG tree from the given Studio unions
function CSGTree.RobloxToCSGTree(Unions: {TriangleMeshPart})
	-- =========================================
	-- PROCEDURE
	-- =========================================

	-- We should do "the same" procedure as when we want to modify a CSGTree union but upside down
	-- So each time we go a step backward, we:

	-- * Sort the parts in that step like this: Parts, Unions, NegativeParts, NegativeUnions
	-- * If there are unions, use plugin:Separate() at them and reproduce step 1
	-- * Once we have managed to only get parts and negative parts, return the table

	-- Compared to a modification, we start from the end and go to the beginning, which is extremely useful
	-- Why? We don't have to try to insert things in each other. We already have the simplest structure when we separate
	
	-- Require the RunService to make sure we're doing this in Studio
	local RunService = game:GetService("RunService")
	
	-- Get the plugin to access the internal APIs
	local Plugin = script:FindFirstAncestorWhichIsA("Plugin")
	
	-- Make sure the function is run in Studio
	assert(not RunService:IsRunMode() and Plugin, "Attempt to convert a Roblox union into a CSGTree union in-game. Please only convert when in Studio.")
	
	-- Create the table where the unions have their data
	local UnionToData = {}
	
	-- Go through each union to extract their data
	for _, Union in Unions do
		
		-- Set up a local function to extract data
		local function ExtractUnionData(Union): CSGHandler?
			-- Clone the sample so the base union isn't impacted
			local Sample = Union:Clone()
			
			-- Determine whether it's an intersection
			local IsIntersection = Union:IsA("IntersectOperation")

			-- Attempt to separate the sample we just made
			local Success, Result = pcall( Plugin.Separate, Plugin, { Sample :: Instance } )
			
			-- If it fails, abort
			if not Success then
				warn("[CSGTREE]: Attempt to perform union extraction on an unsupported object")
				return nil
			end

			-- Sort the result into different categories
			local Parts: {BasePart} = {}
			local Unions: { [TriangleMeshPart]: boolean | CSGLeaf } = {}
			local NegativeParts: {BasePart} = {}
			local NegativeUnions: { [TriangleMeshPart]: boolean | CSGLeaf } = {}
			
			-- Go through each object that resulted from separation
			for _, Part: BasePart in Result do
				if Part:IsA("NegateOperation") then
					-- If it's a NegateOperation, negate it to get its original counterpart
					
					-- Quickly parent this object into workspace to make negation work
					Part.Parent = workspace
					
					-- Negate it to obtain the original sample
					Part = Plugin:Negate( {Part} )[1] :: BasePart
					
					-- Put back the object into nil to prevent issues
					Part.Parent = nil
					
					-- Sort the part
					if Part:IsA("TriangleMeshPart") then
						-- If it's a `TriangleMeshPart`, it's a negative union
						
						NegativeUnions[Part] = true
					else
						-- Otherwise, it's a negative part
						table.insert(NegativeParts, Part)
					end
				elseif Part:HasTag("rbxNegated") then
					-- If it has the rbxNegated tag, just sort it
					if Part:IsA("TriangleMeshPart") then
						-- If it's a `TriangleMeshPart`, it's a negative union
						
						NegativeUnions[Part] = true
					else
						-- Otherwise, it's a negative part
						
						table.insert(NegativeParts, Part)
					end
				else
					-- Else, it's simply a normal part/union we must sort
					
					if Part:IsA("TriangleMeshPart") then
						-- If it's a `TriangleMeshPart`, it's a union
						
						Unions[Part] = true
					else
						-- Otherwise, it's a part
						
						table.insert(Parts, Part)
					end
				end
			end
			
			-- Prepare the tree
			local Tree = CSGTree.CreateTree()

			-- Once done sorting, two things are to be noted:
			-- * For the part scenarios, we can just serialise them
			-- * For unions, we need to call ExtractUnionData on them to try to only get parts
			
			-- Convert the parts and negative parts into leaves
			local PartsLeaf = CSGTree.CreateLeafFromItems(Parts :: {Instance}, Union.CFrame, IsIntersection and 3 or 1)
			local NegativePartsLeaf = CSGTree.CreateLeafFromItems(NegativeParts :: {Instance}, Union.CFrame, 2)
			
			-- Set up a function to extract and adapt the sub-unions' data
			
			-- Returns the 
			local function SetUpUnion(UnionToSetup, Type): CSGLeaf?
				-- Use the function we're currently setting up to extract the data
				local UnionData: CSGHandler? = ExtractUnionData(UnionToSetup)
				
				if not UnionData then
					return nil
				end
				
				-- Make a leaf off the tree we just made
				local UnionLeaf: CSGLeaf = CSGTree.CreateParenthesisWithTree(UnionData, Type)
				
				-- Offset the union to the real one
				CSGTree.OffsetLeafFromUnion(UnionLeaf, UnionToSetup, Union)

				-- Write the properties of the union
				CSGTree.TrackUnionProperties(UnionLeaf, UnionToSetup)
				
				-- Return the new leaf
				return UnionLeaf
			end

			-- Set up the unions
			for Union in Unions do
				Unions[Union] = SetUpUnion(Union, 1)
			end
			
			-- Set up the negative unions
			for Union, Data in NegativeUnions do
				NegativeUnions[Union] = SetUpUnion(Union, 2)
			end
			
			-- Find which method we must use
			local Method = IsIntersection and CSGTree.Intersect or CSGTree.Union
			
			-- Get the tree's data table
			local TreeData = Tree.Data
			
			-- Insert each category of objects in the new tree
			
			-- Insert the unions
			for Union, Data in Unions do
				Method(Tree, Data :: CSGLeaf)
			end
			
			-- Insert the parts
			Method(Tree, PartsLeaf)
			
			-- Insert the negative parts
			CSGTree.Negate(Tree, NegativePartsLeaf)
			
			-- Insert the negative unions
			for Union, Data in NegativeUnions do
				CSGTree.Negate(Tree, Data :: CSGLeaf)
			end
			
			-- The last step is to make sure the correct CFrame is retained
			-- This sadly requires us to build the union to find the required offset
			
			-- Prevent the function from messing up the offsets
			Tree.Pivot = false
			
			-- Build the union where it's supposed to be
			local SampleUnion = CSGTree.CreateUnionFromTree(Tree, Union.CFrame, {})[1]
			
			-- Find the distance between the created union and the real one
			local Distance = SampleUnion.CFrame:ToObjectSpace(Union.CFrame)
			
			-- Set the distance as the new pivot
			Tree.Pivot = CFrameToTable(Distance)

			return Tree
		end

		local Data = ExtractUnionData(Union)

		if not Data then
			continue
		else
			UnionToData[Union] = Data
		end
	end

	return UnionToData
end

-- Add camel case alternatives
CSGTree.createTree = CSGTree.CreateTree
CSGTree.createTreeFromItems = CSGTree.CreateTreeFromItems
CSGTree.createParenthesisWithTree = CSGTree.CreateParenthesisWithTree
CSGTree.createLeafFromItems = CSGTree.CreateLeafFromItems

CSGTree.isAParenthesis = CSGTree.IsAParenthesis
CSGTree.splitFromUnion = CSGTree.SplitFromUnion

CSGTree.offsetLeafFromUnion = CSGTree.OffsetLeafFromUnion
CSGTree.trackUnionProperties = CSGTree.TrackUnionProperties
CSGTree.fixUnionCFrame = CSGTree.FixUnionCFrame

CSGTree.union = CSGTree.Union
CSGTree.intersect = CSGTree.Intersect
CSGTree.negate = CSGTree.Negate

CSGTree.createUnionFromTree = CSGTree.CreateUnionFromTree
CSGTree.createPartsFromTree = CSGTree.CreatePartsFromTree
CSGTree.robloxToCSGTree = CSGTree.RobloxToCSGTree
CSGTree.useGeometryServiceWithOperation = CSGTree.UseGeometryServiceWithOperation

return CSGTree
