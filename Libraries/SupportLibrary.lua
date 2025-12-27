SupportLibrary = {};

-- Returns the positions of instances of `needle` in table/dictionary`haystack`
function SupportLibrary.FindTableOccurrences(Haystack, Needle)

	local Positions = {};

	-- Add any indexes from `Haystack` that are `Needle`
	for Index, Value in Haystack do
		if Value == Needle then
			table.insert(Positions, Index);
		end;
	end;

	return Positions;
end;

--[[ Returns one occurrence of `Needle` in `Haystack`

This method is intended to be used in dictionaries. Prefer `table.find` for tables]]
function SupportLibrary.FindTableOccurrence(Haystack, Needle)

	-- Search for the first instance of `Needle` found and return it
	for Index, Value in Haystack do
		if Value == Needle then
			return Index;
		end;
	end;

	-- If no occurrences exist, return `nil`
	return nil;

end;


-- Returns whether the given `Needle` can be found within table `Haystack`
function SupportLibrary.IsInTable(Haystack, Needle)

	-- Go through every value in `Haystack` and return whether `Needle` is found
	for _, Value in Haystack do
		if Value == Needle then
			return true;
		end;
	end;

	-- If no instances were found, return false
	return false;
end;

--[[ Returns whether the values of tables A and B are the same

REMINDER: table == table will always return false, hence why using this function]]
function SupportLibrary.DoTablesMatch(A, B)

	-- Check B table differences
	for Index in A do
		if A[Index] ~= B[Index] then
			return false;
		end;
	end;

	-- Check A table differences
	for Index in B do
		if B[Index] ~= A[Index] then
			return false;
		end;
	end;

	-- Return true if no differences
	return true;
end;

--[[ Returns `Number` rounded to the given number of decimal places (from lua-users)

To round at one decimal, prefer `math.round`
]]
function SupportLibrary.Round(Number, Places)
	-- Ensure that `Number` is a number
	if type(Number) ~= 'number' then
			return;
	end;

	-- Round the number
	local Multiplier = 10 ^ (Places or 0);
	local RoundedNumber = math.floor(Number * Multiplier + 0.5) / Multiplier;

	-- Return the rounded number
	return RoundedNumber;
end;

--[[ Returns a copy of `Table`

If any problem occurs with the modification of sub-tables, use the `DeepClone` argument by setting it to true.
]]
function SupportLibrary.CloneTable(Table, DeepClone)
	-- Returns a copy of `Table`

	local ClonedTable = {};

	-- Copy all values into `ClonedTable`
	for Key, Value in Table do
		ClonedTable[Key] = DeepClone and type(Value) == "table" and SupportLibrary.CloneTable(Value, true) or Value;
	end;

	return ClonedTable;
end;

--[[ Copies members of the given tables into the specified target table

If two tables have identical indexes, the latest table's value will erase the other's. Consider using `SupportLibrary.Concat` if order doesn't matter and erasure needs to be avoided.
]]
function SupportLibrary.Merge(Target, ...)

	local Tables = { ... }

	-- Copy members from each table into target
	for TableOrder, Table in ipairs(Tables) do
		for Key, Value in Table do
			Target[Key] = Value
		end
	end

	-- Return target
	return Target
end

--Returns a table containing every single values of the given object without sub-tables
function SupportLibrary.ExtractValues(Table)

	local Values = {}

	-- Copy members from each table into target
	for i, Value in Table do
		if type(Value) == "table" then
			local ExtractedValues = SupportLibrary.ExtractValues(Value)
			
			for _, SubValue in ExtractedValues do
				table.insert(Values, SubValue)
			end
		else
			table.insert(Values, Value)
		end
	end

	-- Return target
	return Values
end

-- Create symbol representing a blank value
local Blank = newproxy(true)
SupportLibrary.Blank = Blank
getmetatable(Blank).__tostring = function ()
	return 'Symbol(Blank)'
end

-- Copies members of the given tables into the specified target table, including blank values
function SupportLibrary.MergeWithBlanks(Target, ...)

	local Tables = { ... }

	-- Copy members from each table into target
	for TableOrder, Table in ipairs(Tables) do
		for Key, Value in Table do
			if Value == Blank then
				Target[Key] = nil
			else
				Target[Key] = Value
			end
		end
	end

	-- Return target
	return Target
end

-- Creates a table with the values of the second one at the position of the first one. Useful to whitelist elements of a table without changes concerning indexes
function SupportLibrary.FindEquivalences(Table, Target)
	local First = SupportLibrary.FlipTable(Table)
	
	local Result = {}
	
	for _, Value in Target do
		local Index = First[Value]
		
		if Index then
			Result[Index] = Value
		end
	end
	
	return Result
end

-- Recursively gets all the descendants of `Parent` and returns them
function SupportLibrary.GetAllDescendants(Parent)

	--[[
	local Descendants = {};
	

	for _, Child in pairs(Parent:GetChildren()) do

		-- Add the direct descendants of `Parent`
		table.insert(Descendants, Child);

		-- Add the descendants of each child
		for _, Subchild in pairs(SupportLibrary.GetAllDescendants(Child)) do
			table.insert(Descendants, Subchild);
		end;

	end;]]
	
	-- @Vikko151: this one is worrisome...

	return Parent:GetDescendants()--Descendants;
end;

-- Returns descendants of `Object` which match `Class`
function SupportLibrary.GetDescendantsWhichAreA(Object, Class)
--[[
	local Matches = {}
	
	-- Check each descendant
	for _, Descendant in Object:GetDescendants() do
		if Descendant:IsA(Class) then
			Matches[#Matches + 1] = Descendant
		end
	end

	-- Return matches
	return Matches]]
	
	return Object:QueryDescendants(Class)

end

-- Returns a filtered copy of `Array` based on the filter `Callback`
function SupportLibrary.FilterArray(Array, Callback: (any, number) -> boolean)

	local FilteredArray = {}

	-- Add items from `Array` that `Callback` returns `true` on
	for Key, Value in ipairs(Array) do
		if Callback(Value, Key) then
			table.insert(FilteredArray, Value)
		end
	end

	return FilteredArray
end

-- Returns a filtered copy of `Map` based on the filter `Callback`
function SupportLibrary.FilterMap(Map, Callback)

	local FilteredMap = {}

	-- Add items from `Map` that `Callback` returns `true` on
	for Key, Value in ipairs(Map) do
		if Callback(Value, Key) then
			FilteredMap[Key] = Value
		end
	end

	return FilteredMap
end

-- Recursively gets a count of all the descendants of `Parent` and returns them
function SupportLibrary.GetDescendantCount(Parent)
	--[[
	local Count = 0;

	for _, Child in pairs(Parent:GetChildren()) do

		-- Count the direct descendants of `Parent`
		Count = Count + 1;

		-- Count and add the descendants of each child
		Count = Count + SupportLibrary.GetDescendantCount(Child);

	end;]]

	return #Parent:GetDescendants()--Count;
end;

-- Returns a table of string `String` split by pattern `Delimiter`
function SupportLibrary.SplitString(String, Delimiter)

	local StringParts = {};
	local Pattern = ('([^%s]+)'):format(Delimiter);

	-- Capture each separated part
	String:gsub(Pattern, function (Part)
		table.insert(StringParts, Part);
	end);

	return StringParts;
end;

-- Returns the first child of `Parent` that is of class `ClassName` or nil if it couldn't find any
function SupportLibrary.GetChildOfClass(Parent, ClassName, Inherit)
	
	-- @Vikko151: changed this to FindFirstChildOfClass()
	-- like why this Rude Goldberg machine

	-- Look for a child of `Parent` of class `ClassName` and return it
	
	--[[
	if not Inherit then
		for _, Child in pairs(Parent:GetChildren()) do
			if Child.ClassName == ClassName then
				return Child;
			end;
		end;
	else
		for _, Child in pairs(Parent:GetChildren()) do
			if Child:IsA(ClassName) then
				return Child;
			end;
		end;
	end;]]

	return Inherit and Parent:FindFirstChildOfClass(ClassName) or Parent:FindFirstChildWhichIsA(ClassName)--nil;
end;

-- Returns a table containing the children of `Parent` that are of class `ClassName`
function SupportLibrary.GetChildrenOfClass(Parent, ClassName, Inherit)

	local Matches = {};

	if not Inherit then
		for _, Child in Parent:GetChildren() do
			if Child.ClassName == ClassName then
				table.insert(Matches, Child);
			end;
		end;
	else
		for _, Child in Parent:GetChildren() do
			if Child:IsA(ClassName) then
				table.insert(Matches, Child);
			end;
		end;
	end;

	return Matches;
end;

-- Returns the RGB equivalent of the given HSV-defined color
function SupportLibrary.HSVToRGB(Hue, Saturation, Value)
	-- (adapted from some code found around the web)
	
	-- @Vikko151: Color3.fromHSV() works too.
	
	--[[
	-- If it's achromatic, just return the value
	if Saturation == 0 then
		return Value;
	end;

	-- Get the hue sector
	local HueSector = math.floor(Hue / 60);
	local HueSectorOffset = (Hue / 60) - HueSector;

	local P = Value * (1 - Saturation);
	local Q = Value * (1 - Saturation * HueSectorOffset);
	local T = Value * (1 - Saturation * (1 - HueSectorOffset));

	if HueSector == 0 then
		return Value, T, P;
	elseif HueSector == 1 then
		return Q, Value, P;
	elseif HueSector == 2 then
		return P, Value, T;
	elseif HueSector == 3 then
		return P, Q, Value;
	elseif HueSector == 4 then
		return T, P, Value;
	elseif HueSector == 5 then
		return Value, P, Q;
	end;]]
	
	return Color3.fromHSV(Hue, Saturation, Value)
end;

-- Returns the HSV equivalent of the given RGB-defined color (adapted from some code found around the web, then replaced with Color3:ToHSV)
function SupportLibrary.RGBToHSV(Red, Green, Blue)
	
	-- @Vikko151: superseded by Color3.new():ToHSV()
	
	--[[
	local Hue, Saturation, Value;

	local MinValue = math.min(Red, Green, Blue);
	local MaxValue = math.max(Red, Green, Blue);

	Value = MaxValue;

	local ValueDelta = MaxValue - MinValue;

	-- If the color is not black
	if MaxValue ~= 0 then
		Saturation = ValueDelta / MaxValue;

	-- If the color is purely black
	else
		Saturation = 0;
		Hue = -1;
		return Hue, Saturation, Value;
	end;

	if Red == MaxValue then
		Hue = (Green - Blue) / ValueDelta;
	elseif Green == MaxValue then
		Hue = 2 + (Blue - Red) / ValueDelta;
	else
		Hue = 4 + (Red - Green) / ValueDelta;
	end;

	Hue = Hue * 60;
	if Hue < 0 then
		Hue = Hue + 360;
	end;]]

	return Color3.new(Red, Green, Blue):ToHSV();
end;

-- Returns the common item in table `Items`, or `nil` if they vary
function SupportLibrary.IdentifyCommonItem(Items)
	local CommonItem = nil;

	for ItemIndex, Item in Items do

		-- Set the initial item to compare against
		if ItemIndex == 1 then
			CommonItem = Item;
			
		-- Check if this item is the same as the rest
		else
			-- If it isn't the same, there is no common item, so just stop right here
			if Item ~= CommonItem then
				return nil;
			end;
		end;

	end;

	-- Return the common item
	return CommonItem;
end;

-- Returns the common `Property` value in the instances given in `Items`
function SupportLibrary.IdentifyCommonProperty(Items, Property)
	
	local PropertyVariations = {};
	
	-- Capture all the variations of the property value
	-- @Vikko151: if some values are strange, don't worry. That means that they can bug when normally used, hence why I use some yet strange method for those.
	
	for _, Item in Items do
		if Item:IsA("TextLabel") and Property == "Text" and Item:FindFirstChild("ActualText") then
			table.insert(PropertyVariations, Item:FindFirstChild("ActualText").Value);
		elseif Item:IsA("ParticleEmitter") and Property == "LockedToPart" then
			table.insert(PropertyVariations, Item.LockedToPart);
		elseif Item:IsA("Highlight") and Property == "DepthMode" then -- There are technical issues with DepthMode.
			local Value
			if Item.DepthMode == Enum.HighlightDepthMode.AlwaysOnTop then
				Value = true
			else
				Value = false
			end
			table.insert(PropertyVariations, Value);	
		else
			table.insert(PropertyVariations, Item[Property]);
		end
	end;
	
	-- Return the common property value
	return SupportLibrary.IdentifyCommonItem(PropertyVariations);
end;

-- Returns a table of the given part's corners' CFrames
function SupportLibrary.GetPartCorners(Part)

	-- Make references to functions called a lot for efficiency
	local Insert = table.insert;
	local ToWorldSpace = function(A, B) return A * B end --CFrame.new().toWorldSpace;
	local NewCFrame = CFrame.new;

	-- Get info about the part
	local PartCFrame = Part.CFrame;
	local SizeX, SizeY, SizeZ = Part.Size.X / 2, Part.Size.Y / 2, Part.Size.Z / 2;

	-- Get each corner
	local Corners = {};
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(SizeX, SizeY, SizeZ)));
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(-SizeX, SizeY, SizeZ)));
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(SizeX, -SizeY, SizeZ)));
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(SizeX, SizeY, -SizeZ)));
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(-SizeX, SizeY, -SizeZ)));
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(-SizeX, -SizeY, SizeZ)));
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(SizeX, -SizeY, -SizeZ)));
	Insert(Corners, ToWorldSpace(PartCFrame, NewCFrame(-SizeX, -SizeY, -SizeZ)));

	return Corners;
end;

-- Returns a table containing the part and its respective ancestors (until the `Range` argument)
function SupportLibrary.GetAncestry(Part, Range)
	local Hierarchy = {}
	
	-- Make references to functions called a lot for efficiency
	local Insert = table.insert;
	local Ancestor = Part
	local OutOfRange = false

	repeat
		Insert(Hierarchy, Ancestor)
		
		Ancestor = Ancestor.Parent

		if Ancestor == Range or Ancestor.Parent == Range.Parent or Range:IsDescendantOf(Ancestor) then
			OutOfRange = true
		end
	until OutOfRange == true
	
	return Hierarchy
end

-- Adds references to common services into the calling environment
function SupportLibrary.ImportServices()

	-- Get the calling environment
	local CallingEnvironment = {};

	-- Add the services
	CallingEnvironment.Workspace = game:GetService 'Workspace';
	CallingEnvironment.Players = game:GetService 'Players';
	CallingEnvironment.MarketplaceService = game:GetService 'MarketplaceService';
	CallingEnvironment.ContentProvider = game:GetService 'ContentProvider';
	CallingEnvironment.SoundService = game:GetService 'SoundService';
	CallingEnvironment.UserInputService = game:GetService 'UserInputService';
	CallingEnvironment.SelectionService = game:GetService 'Selection';
	CallingEnvironment.CoreGui = game:GetService 'CoreGui';
	CallingEnvironment.HttpService = game:GetService 'HttpService';
	CallingEnvironment.ChangeHistoryService = game:GetService 'ChangeHistoryService';
	CallingEnvironment.ReplicatedStorage = game:GetService 'ReplicatedStorage';
	CallingEnvironment.GroupService = game:GetService 'GroupService';
	CallingEnvironment.ServerScriptService = game:GetService 'ServerScriptService';
	CallingEnvironment.ServerStorage = game:GetService 'ServerStorage';
	CallingEnvironment.StarterGui = game:GetService 'StarterGui';
	CallingEnvironment.RunService = game:GetService 'RunService';
	
	return CallingEnvironment
end;

-- Gets the given member for each object in the given list table
function SupportLibrary.GetListMembers(List, MemberName)

	local Members = {}

	-- Collect the member values for each item in the list
	for Key, Item in ipairs(List) do
		Members[Key] = Item[MemberName]
	end

	-- Return the members
	return Members

end

-- Maps the given items' specified members to each item
function SupportLibrary.GetMemberMap(List, MemberName)

	local Map = {}

	-- Collect member values
	for Key, Item in ipairs(List) do
		Map[Item] = Item[MemberName]
	end

	-- Return map
	return Map

end

-- Connects to the given user input event and takes care of standard boilerplate code
function SupportLibrary.AddUserInputListener(InputState, InputTypeFilter, CatchAll, Callback)

	-- Create input type whitelist
	local InputTypes = {}
	if type(InputTypeFilter) == 'string' then
		InputTypes[InputTypeFilter] = true
	elseif type(InputTypeFilter) == 'table' then
		InputTypes = SupportLibrary.FlipTable(InputTypeFilter)
	end

	-- Create a UserInputService listener based on the given `InputState`
	return game:GetService('UserInputService')['Input' .. InputState]:Connect(function (Input, GameProcessedEvent)

		-- Make sure this input was not captured by the client (unless `CatchAll` is enabled)
		if GameProcessedEvent and not CatchAll then
			return;
		end;

		-- Make sure this is the right input type
		if not InputTypes[Input.UserInputType.Name] then
			return;
		end;

		-- Make sure any key input did not occur while typing into a UI
		if Input.UserInputType == Enum.UserInputType.Keyboard and game:GetService('UserInputService'):GetFocusedTextBox() then
			return;
		end;

		-- Call back upon passing all conditions
		Callback(Input);

	end);

end;

-- Connects to the given GUI user input event and takes care of standard boilerplate code
function SupportLibrary.AddGuiInputListener(Gui, InputState, InputTypeFilter, CatchAll, Callback)

	-- Create input type whitelist
	local InputTypes = {}
	if type(InputTypeFilter) == 'string' then
		InputTypes[InputTypeFilter] = true
	elseif type(InputTypeFilter) == 'table' then
		InputTypes = SupportLibrary.FlipTable(InputTypeFilter)
	end

	-- Create a UserInputService listener based on the given `InputState`
	return Gui['Input' .. InputState]:Connect(function (Input, GameProcessedEvent)

		-- Make sure this input was not captured by the client (unless `CatchAll` is enabled)
		if GameProcessedEvent and not CatchAll then
			return;
		end;

		-- Make sure this is the right input type
		if not InputTypes[Input.UserInputType.Name] then
			return;
		end;

		-- Call back upon passing all conditions
		Callback(Input);

	end);

end;

-- Returns whether the given keys are pressed
function SupportLibrary.AreKeysPressed(...)

	local RequestedKeysPressed = 0;

	-- Get currently pressed keys
	local PressedKeys = SupportLibrary.GetListMembers(game:GetService('UserInputService'):GetKeysPressed(), 'KeyCode');

	-- Go through each requested key
	for _, Key in pairs({ ... }) do

		-- Count requested keys that are pressed
		if SupportLibrary.IsInTable(PressedKeys, Key) then
			RequestedKeysPressed = RequestedKeysPressed + 1;
		end;

	end;

	-- Return whether all the requested keys are pressed or not
	return RequestedKeysPressed == #{...};

end;

-- Inserts all values from given source tables into target
function SupportLibrary.ConcatTable(TargetTable, ...)
	
	if not TargetTable then return {} end
	
	local SourceTables = { ... }

	-- Insert values from each source table into target
	for TableOrder, SourceTable in ipairs(SourceTables) do
		for Key, Value in ipairs(SourceTable) do
			table.insert(TargetTable, Value)
		end
	end

	-- Return the destination table
	return TargetTable
end

-- Clears out every value in `Table`
function SupportLibrary.ClearTable(Table)
	
	--[[
	-- Clear each index
	for Index in pairs(Table) do
		Table[Index] = nil;
	end;]]
	
	-- Return the given table
	return table.clear(Table)--Table;
end;

-- Returns all the values in the given table
function SupportLibrary.Values(Table, OrderMatters)

	local Values = {};

	-- Go through each key and get each value
	for Index, Value in Table do
		if OrderMatters then
			Values[tonumber(Index)] = Value
		else
			table.insert(Values, Value);
		end
	end;

	-- Return the values
	return Values;
end;

-- Return the table with all number inside strings transformed into number. Perfect to fix problems with JSON encoding.
function SupportLibrary.ToNumeralIndexes(Table, OrderMatters)

	local NewTable = {};

	-- Go through every single keys
	for i, Value in Table do
		if type(Value) == "table" then
			local NumeralTable = SupportLibrary.ToNumeralIndexes(Value)
			
			local NewIndex = tonumber(i)
			
			NewTable[NewIndex or i] = NumeralTable
		else
			local NewIndex = tonumber(i)
			
			NewTable[NewIndex or i] = Value
		end
	end

	-- Return the values
	return NewTable;
end;

-- Returns all the keys in the given table
function SupportLibrary.Keys(Table)

	local Keys = {};

	-- Go through each key and get each value
	for Key in Table do
		table.insert(Keys, Key);
	end;

	-- Return the values
	return Keys;
end;

-- Returns a callback to `Function` with the given arguments
function SupportLibrary.Call(Function, ...)
	local Args = { ... }
	return function (...)
		return Function(unpack(
			SupportLibrary.ConcatTable({}, Args, { ... })
		))
	end
end

-- Returns a trimmed version of `String` (adapted from code from lua-users)
function SupportLibrary.Trim(String)
	return (String:gsub("^%s*(.-)%s*$", "%1"));
end

-- Returns a string without the mentioned item (sub check + gsub) or nil if this item isn't present. The arguments are the same as with `string.sub()`, but with gsub's replacements argument
function SupportLibrary.FindAndRemoveFromString(String, Needle, Init, Replacements)
	local IsInString = string.sub(String, Init, #Needle) == Needle
	
	if IsInString == true then
		return string.gsub(String, Needle, "", Replacements)
	end
		
	return nil;
end

-- Returns function that passes arguments through given functions and returns the final result
function SupportLibrary.ChainCall(...)

	-- Get the given chain of functions
	local Chain = { ... };

	-- Return the chaining function
	return function (...)

		-- Get arguments
		local Arguments = { ... };

		-- Go through each function and store the returned data to reuse in the next function's arguments 
		for _, Function in ipairs(Chain) do
			Arguments = { Function(unpack(Arguments)) };
		end;

		-- Return the final returned data
		return unpack(Arguments);

	end;

end;

-- Returns the number of keys in `Table`
function SupportLibrary.CountKeys(Table)

	local Count = 0;

	-- Count each key
	for _ in Table do
		Count = Count + 1;
	end;

	-- Return the count
	return Count;

end;

-- Returns values from `Start` to `End` in `Table`
function SupportLibrary.Slice(Table, Start, End)

	local Slice = {};

	-- Go through the given indices
	for Index = Start, End do
		table.insert(Slice, Table[Index]);
	end;

	-- Return the slice
	return Slice;

end;

-- Returns a table with keys and values in `Table` swapped
function SupportLibrary.FlipTable(Table)

	local FlippedTable = {};

	-- Flip each key and value
	for Key, Value in Table do
		FlippedTable[Value] = Key;
	end;

	-- Return the flipped table
	return FlippedTable;

end;

-- Repeats `Task` every `Interval` seconds until stopped
function SupportLibrary.ScheduleRecurringTask(TaskFunction, Interval)

	-- Create a task object
	local Task = {

		-- A switch determining if it's running or not
		Running = true;

		-- A function to stop this task
		Stop = function (Task)
			Task.Running = false;
		end;

		-- References to the task function and set interval
		TaskFunction = TaskFunction;
		Interval = Interval;

	};

	coroutine.wrap(function (Task)

		-- Repeat the task
		while task.wait(Task.Interval) and Task.Running do
			Task.TaskFunction();
		end;

	end)(Task);

	-- Return the task object
	return Task;

end;

-- Calls the given function repeatedly at the specified interval until stopped
function SupportLibrary.Loop(Interval, Function, ...)

	local Args = { ... }

	-- Create state
	local Running = true
	local Stop = function ()
		Running = nil
	end

	-- Start loop
	coroutine.wrap(function ()
		while task.wait(Interval) and Running do
			Function(unpack(Args))
		end
	end)()

	-- Return stopping callback
	return Stop
end

-- Returns the given number, clamped according to the provided min/max
function SupportLibrary.Clamp(Number, Minimum, Maximum)
--[[
	-- Clamp the number
	if Minimum and Number < Minimum then
		Number = Minimum;
	elseif Maximum and Number > Maximum then
		Number = Maximum;
	end;]]

	-- Return the clamped number
	return math.clamp(Number, Minimum, Maximum) --Number;

end;

-- Returns a new table with values in the opposite order
function SupportLibrary.ReverseTable(Table)

	local ReversedTable = {};

	-- Copy each value at the opposite key
	for Index, Value in ipairs(Table) do
		ReversedTable[#Table - Index + 1] = Value;
	end;

	-- Return the reversed table
	return ReversedTable;

end;

-- Returns a callback for determining whether to execute consecutive calls
function SupportLibrary.CreateConsecutiveCallDeferrer(MaxInterval)

	local LastCallTime
	local function ShouldExecuteCall()

		-- Mark latest call time
		local CallTime = tick()
		LastCallTime = CallTime

		-- Indicate whether call still latest
		task.wait(MaxInterval)
		return LastCallTime == CallTime

	end

	-- Return callback
	return ShouldExecuteCall

end

return SupportLibrary;
