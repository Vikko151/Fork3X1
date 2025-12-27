--[[This module converts and manipulates parts with basic sets expressions
Example: A U (B / C) will become: {
	[1] = A,
	[2] = 0,
	[3] = {
		[1] = B,
		[2] = 2,
		[3] = C,
	},
}

INDEX:

- Sub-tables will be initialised first. Think of it like a mathematical operation.
- 1 is for union (U).
- 2 is for negation (/).
- 3 is for intersection (n).
- Complements don't exist directly. You can't perform boundless operation in CSG.

Note that we cannot simplify the operations due to it being risky with part-to-part relations.

Example: if the operation tree has a part with the parent property set at 3, merging it will cause the parent to not be at 3.]]

local CSGTree = {}
CSGTree.AllowSimplification = true

local HttpService = game:GetService("HttpService")
local GeometryService = game:GetService("GeometryService")

local SerializationV6 = require(script.Parent.SerializationV6)()
local Support = require(script.Parent.SupportLibrary)


--------------------------------
-- READING
--------------------------------

-- Returns the first sample of the tree with a CFrame in it
function CSGTree.GetOffsetFromTree(Tree)
	local Parenthesis = CSGTree.GetParenthesesInOrder(Tree)

	return Parenthesis and Parenthesis[1] and CFrame.new(table.unpack(Parenthesis[1][1].Relative)) or 
		Tree[1] and CFrame.new(table.unpack(Tree[1].Offset)) or
		CFrame.new(0, 0, 0)
end

-- Returns whether the tree only has operations with [Operations] and no sub-tables
function CSGTree.IsTreeSimple(Tree, ...)
	local Whitelist = {...}

	for _, Leave in Tree do
		-- Is there a table that's not a serialization?
		if type(Leave) == "table" and not Leave.Version then
			return false
		end
		-- Is the operation the same as requested?
		if type(Leave) == "number" and not table.find(Whitelist, Leave) then
			return false
		end
	end

	-- Return true if every checks have passed
	return true
end

-- Returns the parenthesis that has to be serialized at the [Number]th step
function CSGTree.GetParenthesesInOrder(Tree, Hierarchy, TableToPart, InstancesHierarchy) 
	local TreeHierarchy = Hierarchy

	print(TreeHierarchy)

	-- STEP 1: Check for parentheses
	for i, Leave in Tree do
		-- Is it a table that's a parenthesis? If yes, investigate inside
		if type(Leave) == "table" and not Leave.Version and (Tree[i - 1] == nil or Tree[i - 1] <= 3) then
			local SubHierarchy = {}
			-- Add the current step atop the sub-hierarchy
			table.insert(SubHierarchy, Leave)
			SubHierarchy = Support.ReverseTable(CSGTree.GetParenthesesInOrder(Leave, SubHierarchy))
			TreeHierarchy = Support.ConcatTable(TreeHierarchy, SubHierarchy)
		end
	end
	
	if TableToPart and InstancesHierarchy then
		for Index, Parenthesis in TreeHierarchy do
			local Part = table.find(TableToPart, HttpService:JSONEncode(Parenthesis))
			
			if Part then
				InstancesHierarchy[Index] = Part
				table.remove(TreeHierarchy, Parenthesis)
			end
		end
	end

	return TreeHierarchy
end

--------------------------------
-- WRITING
--------------------------------

-- Converts every operators in a simple tree into the desired one
function CSGTree.UniformizeTree(ConcernedTree, Operation)
	local Tree = ConcernedTree

	-- Look whether parenthesis are useful in the scenario
	for Index, Object in Tree do
		if type(Object) == "number" then
			Tree[Index] = Operation
		end
	end

	return Tree
end

-- Removes blanks inside a tree
function CSGTree.RemoveBlanks(ConcernedTree)
	local Tree = ConcernedTree

	-- Look whether parenthesis are useful in the scenario
	for Index, Object in Tree do
		if type(Object) == "table" and Object.Items and #Object.Items == 0 then
			table.remove(Tree, Index)
			if Index == 1 then
				table.remove(Tree, 1)
			else
				table.remove(Tree, Index - 1)
			end
		end
	end

	return Tree
end

-- Adds an union between a set of part and the given tree
function CSGTree.AddUnion(ConcernedTree, OperationTree, Simplify)
	local Tree = ConcernedTree

	-- Look whether parenthesis are useful in the scenario
	if CSGTree.AllowSimplification and Simplify and CSGTree.IsTreeSimple(OperationTree) then
		-- Just add the operation inside the tree
		table.insert(Tree, 1)
		Tree = Support.ConcatTable(Tree, OperationTree)
	else
		table.insert(Tree, 1)
		table.insert(Tree, OperationTree)
	end

	return CSGTree.RemoveBlanks(Tree)
end

-- Adds a negation between a set of part and the given tree
function CSGTree.AddNegation(ConcernedTree, OperationTree, Simplify)
	local Tree = ConcernedTree

	if CSGTree.AllowSimplification and Simplify and CSGTree.IsTreeSimple(OperationTree) then
		-- Just add the operation inside the tree
		table.insert(Tree, 2)
		Tree = Support.ConcatTable(Tree, OperationTree)
	else
		table.insert(Tree, 2)
		table.insert(Tree, OperationTree)
	end

	return CSGTree.RemoveBlanks(Tree)
end

-- Adds an intersection between a set of part and the given tree
function CSGTree.AddIntersection(ConcernedTree, OperationTree, Simplify)
	local Tree = ConcernedTree

	if CSGTree.AllowSimplification and Simplify and CSGTree.IsTreeSimple(OperationTree) then
		-- Just add the operation inside the tree
		table.insert(Tree, 3)
		Tree = Support.ConcatTable(Tree, OperationTree)
	else
		table.insert(Tree, 3)
		table.insert(Tree, OperationTree)
	end

	return CSGTree.RemoveBlanks(Tree)
end

-- Splits the tree's final result from the given bit
function CSGTree.Split(ConcernedTree, MainCFrame, Part)
	local Tree = ConcernedTree

	local BoundingBox = {(MainCFrame:Inverse() * Part.CFrame):GetComponents()}

	BoundingBox[13] = Part.Size.X
	BoundingBox[14] = Part.Size.Y
	BoundingBox[15] = Part.Size.Z

	return CSGTree.RemoveBlanks(Tree)
end

-- Returns a tree with the last leave removed, whether the leave is negative or not, and the leave itself
function CSGTree.Separate(Tree)
	local NewTree = table.clone(Tree)
	local RemovedLeave --= NewTree[#NewTree]

	local IsLeaveNegative = #NewTree ~= 1 and NewTree[#NewTree - 1] == 2 and true or false

	local Offset = -1

	repeat

		if NewTree[#NewTree + Offset] and NewTree[#NewTree + Offset] <= 3 then
			RemovedLeave = NewTree[#NewTree]

		elseif NewTree[#NewTree + Offset] and NewTree[#NewTree + Offset] == 4 then
			Offset -= 2

		else
			for i = 1, 2 do
				if #NewTree == 0 then
					break
				end
				table.remove(NewTree, #NewTree + Offset)
			end
		end

	until RemovedLeave or -Offset >= #NewTree

	if not RemovedLeave then
		return Tree[1], false, {}
	end

	local RemovedLeaveIndex = table.find(NewTree, RemovedLeave) - 1

	for i = 1, 2 do
		if #NewTree == 0 then
			break
		end
		table.remove(NewTree, RemovedLeaveIndex)
	end

	local FinalRemovedLeave = Support.CloneTable(RemovedLeave, true)
	local Done = false
	
	if FinalRemovedLeave and not FinalRemovedLeave.Version then
		print(FinalRemovedLeave[1])
		local ConcernedLeave = FinalRemovedLeave[1]
		local Done = false
		
		repeat

			if ConcernedLeave[#ConcernedLeave - 1] and ConcernedLeave[#ConcernedLeave - 1] <= 3 then
				Done = true

			else
				for i = 1, 2 do
					if #ConcernedLeave == 0 then
						break
					end
					table.remove(ConcernedLeave, #ConcernedLeave)
					task.wait(0.1)
					print(ConcernedLeave)
				end
			end

		until Done == true or #ConcernedLeave <= 1
	end

	--local Offsets = Support.Slice(NewTree, RemovedLeaveIndex, #NewTree)

	--if #Offsets ~= 0 then
	--	for _, Offset in Offsets do
	--		table.insert(RemovedLeave, Offset)
	--	end
	--end
	
	print(RemovedLeave)

	return NewTree, IsLeaveNegative, RemovedLeave, FinalRemovedLeave--, #Offsets
end

-- Offsets a tree's parts. Useful when assembling unions
function CSGTree.AddPropertiesToTree(ConcernedTree, Union)
	if not Union then return ConcernedTree end

	local Tree = ConcernedTree

	local UnionProperties = {}

	UnionProperties[1] = Union.Size.X
	UnionProperties[2] = Union.Size.Y
	UnionProperties[3] = Union.Size.Z
	UnionProperties[4] = Union.UsePartColor
	UnionProperties[5] = Union.Color.R
	UnionProperties[6] = Union.Color.G
	UnionProperties[7] = Union.Color.B
	UnionProperties[8] = Union.Material.Value
	UnionProperties[9] = Union.MaterialVariant or ""


	table.insert(Tree, 5)
	table.insert(Tree, UnionProperties)

	return Tree
end

--------------------------------
-- CONVERTING
--------------------------------

-- Returns an union from the given operation number and properties (similar to Union/Negate/Intersect|Async)
function CSGTree.TransformFromOperation(Operation, ...)
	--print(Operation)
	if Operation == 1 then
		return GeometryService:UnionAsync(...)
	elseif Operation == 2 then
		return GeometryService:SubtractAsync(...)
	else
		return GeometryService:IntersectAsync(...)
	end
end

-- Offsets a tree's parts. Useful when assembling unions
function CSGTree.OffsetTreeParts(ConcernedTree, Offset)

	local Tree = ConcernedTree
	local TreeParentheses = {}

	-- Get every single parentheses
	TreeParentheses = CSGTree.GetParenthesesInOrder(Tree, TreeParentheses)

	-- Find serialized parts and offset them
	for i, Tree in TreeParentheses do
		table.insert(Tree, 4)
		table.insert(Tree, {Offset:GetComponents()})
	end

	-- Offset the main tree
	table.insert(Tree, 4)
	table.insert(Tree, {Offset:GetComponents()})
	--[[
	for i = 1, #Tree, 2 do
		if type(Tree[i]) == "table" and Tree[i].Version ~= nil then
			--SerializationV6.OffsetBuild(Tree[i], Offset)
			Tree[i].Offset = {Offset:GetComponents()}
		end
	end]]

	return Tree
end

-- Returns an union from the given tree
function CSGTree.CreateFromTree(Tree, Parameters, DesiredPosition, TableToPart)
	-- Check if the tree is simple to reduce the number of checks
	--local IsTreeSimple = CSGTree.IsTreeSimple(Tree, 1, 2, 3)

	--	if IsTreeSimple then
	--	return Tree
	--	end
	local TreeHierarchy = {}
	local InstancesHierarchy = {}

	-- Get the parenthesis order
	TreeHierarchy = CSGTree.GetParenthesesInOrder(Tree, TreeHierarchy, TableToPart, InstancesHierarchy)

	print(TreeHierarchy)

	-- Add the main parenthesis at the very end
	table.insert(TreeHierarchy, Tree)
	--	table.insert(JSONHierarchy, HttpService:JSONEncode(Tree))

	-- Now, just build the unions step by step
	--	local BuiltParenthesises = {}

	local OperationsParameters = Parameters
	OperationsParameters.SplitApart = false

	local Relative

	local FinalResult

	--	print(Tree)

	for i, Tree in TreeHierarchy do
		local Parts = {}

		local ResultOnHold

		local Offsets = Support.FindTableOccurrences(Tree, 4)
		--local Properties = Support.FindTableOccurrences(Tree, 5)
		--local BlankIntersections = Support.FindTableOccurrences(Tree, 6)

		print(Offsets)

		for i = 1, #Tree, 2 do

			if type(Tree[i]) == "table" and Tree[i].Version ~= nil then
				local Offset = CFrame.new()
				--local AppliedOffsets = Support.Slice(Offsets, 1, i)

				for _, AppliedOffset in Offsets do

					if AppliedOffset <= i + 1 then

						local OffsetCFrame = Tree[AppliedOffset + 1]

						print(OffsetCFrame)

						if OffsetCFrame then

							Offset *= CFrame.new(table.unpack(OffsetCFrame))
						end
					end
				end

				print(DesiredPosition, Offset)

				Parts[i] = SerializationV6.InflateBuildData(Tree[i], true, DesiredPosition * Offset)

			elseif type(Tree[i]) == "table" and (Tree[i - 1] == nil or Tree[i - 1] <= 3) then
				for Index, Parenthesis in TreeHierarchy do
					if Support.DoTablesMatch(Parenthesis, Tree[i]) and InstancesHierarchy[Index] then
						Parts[i] = {InstancesHierarchy[Index]}
					end
				end

				--Parts[i] = {ResultOnHold}
			end
		end

		for i = 1, #Tree, 2 do

			local SerializedParts = Parts[i]
			local PreviousOperation = Tree[i - 1]

			if SerializedParts and SerializedParts[1] == ResultOnHold then
				continue
			elseif SerializedParts and PreviousOperation and PreviousOperation <= 3 and ResultOnHold then
				local Result = CSGTree.TransformFromOperation(PreviousOperation, ResultOnHold, SerializedParts, OperationsParameters)[1]

				if Result then
					ResultOnHold = Result
				end

			elseif PreviousOperation == 5 and ResultOnHold then
				local PropertiesChange = Tree[i]

				ResultOnHold.Size = vector.create(table.unpack(Support.Slice(PropertiesChange, 1, 3)))
				ResultOnHold.UsePartColor = PropertiesChange[4]
				ResultOnHold.Color = Color3.new(table.unpack(Support.Slice(PropertiesChange, 5, 7)))
				ResultOnHold.Material = Enum.Material:FromValue(PropertiesChange[8])
				ResultOnHold.MaterialVariant = PropertiesChange[9]

			elseif PreviousOperation == 6 and ResultOnHold then
				local BoundingBox = Tree[i]

				local BoundingBoxCFrame = CFrame.new(table.unpack(Support.Slice(BoundingBox, 1, 12)))
				local BoundingBoxSize = vector.create(table.unpack(Support.Slice(BoundingBox, 13, 15)))

				local BlankIntersection = Instance.new("Part")
				BlankIntersection.CFrame = ResultOnHold.CFrame * BoundingBoxCFrame
				BlankIntersection.Size = BoundingBoxSize

				BlankIntersection.UsePartColor = ResultOnHold.UsePartColor
				BlankIntersection.Color = ResultOnHold.Color
				BlankIntersection.Material = ResultOnHold.Material
				BlankIntersection.MaterialVariant = ResultOnHold.MaterialVariant

				ResultOnHold = GeometryService:IntersectAsync(ResultOnHold, {BlankIntersection}, Parameters)[1]

			elseif type(SerializedParts) == "table" then
				local PartsWithoutFirst = table.clone(SerializedParts)

				table.remove(PartsWithoutFirst, 1)

				local Success, Content = pcall(function()
					ResultOnHold = GeometryService:UnionAsync(SerializedParts[1], PartsWithoutFirst, Parameters)[1]
				end)

				print(Success, ResultOnHold)

				if not Success then
					ResultOnHold = SerializedParts[1]
				end

			elseif SerializedParts ~= nil then
				ResultOnHold = SerializedParts
			end
		end
		--[[
		if not Relative and ResultOnHold then
			Relative = ResultOnHold.CFrame
		end]]

		if ResultOnHold then
			InstancesHierarchy[i] = ResultOnHold
			FinalResult = ResultOnHold
		end
	end

	--	print(ResultOnHold, gsdf)

	--[[
	if ResultOnHold and ResultOnHold ~= nil and DesiredPosition then
		ResultOnHold.CFrame = DesiredPosition
	end]]

	return FinalResult
end

-- Provides a new tree from the given parts and negative parts
function CSGTree.CreateTreeFromParts(Parts, NegativeParts, Intersect: boolean, Referential: CFrame)
	local Tree = {}

	-- We have four situations.
	-- / Only parts -> Just submit them as the first argument
	-- / Parts and negative parts -> Parts 2 NegativeParts
	-- / Parts and intersection -> Parts.Items[1] 3 (Parts.Items / Parts.Items[1])
	-- / Parts, intersection, and negative parts -> Same as previously, but with 2 NegativeParts then

	local SerializedParts = {}
	local SerializedNegativeParts = {}
	local SerializedIsolatedPart = {}

	-- If there are only parts, just serialize them
	if #Parts ~= 0 and #NegativeParts == 0 and Intersect ~= true then

		--print(Parts[1], Parts[1].CFrame)
		SerializedParts = SerializationV6.SerializeModel(Parts, Referential or Parts[1] and Parts[1].CFrame)

		Tree = {[1] = SerializedParts}

		--return Tree, Referential or Parts[1] and Parts[1].CFrame or CFrame.new(0, 0, 0)
	else
		-- Proceed to isolation when proceeding to an intersection
		if Intersect == true then
			local IsolatedPart = Parts[1]
			local PartsAfterIsolation = table.clone(Parts)
			table.remove(PartsAfterIsolation, 1)

			SerializedParts = SerializationV6.SerializeModel(PartsAfterIsolation, Referential or IsolatedPart.CFrame)
			SerializedIsolatedPart = SerializationV6.SerializeModel({IsolatedPart}, Referential or IsolatedPart.CFrame)

			-- Now, insert the parts inside the tree.
			Tree[1] = SerializedIsolatedPart
			Tree[2] = 3
			Tree[3] = SerializedParts
		else
			SerializedParts = SerializationV6.SerializeModel(Parts, Referential or Parts[1] and Parts[1].CFrame)
			Tree[1] = SerializedParts
		end

		-- Add the negation to the previous result
		--print(#NegativeParts)

		if #NegativeParts ~= 0 then
			SerializedNegativeParts = SerializationV6.SerializeModel(NegativeParts, Referential or Parts[1] and Parts[1].CFrame)
			table.insert(Tree, 2)
			table.insert(Tree, SerializedNegativeParts)
		end
	end

	-- Return the tree
	return Tree, Referential or Parts[1] and Parts[1].CFrame or CFrame.new(0, 0, 0)
end

return CSGTree
