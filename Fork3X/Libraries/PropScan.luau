--[[
A library that offers better control over ReflectionService.

Author: Copyright (c) 2026 VikkoMakesStuff, Vikko151
License: MIT License
Github: https://github.com/VikkoMakesStuff/PropScan
]]

local PropScan = {}

local ReflectionService = game:GetService("ReflectionService")

local DefaultPropertiesList = {}
local DefaultPropertiesListWithoutCategories = {}

local DefaultPropertiesSamples = {}

local PropertiesExpectingIDs = {}

-- Use the current capabilities
local EditingSecurityCapabilities = SecurityCapabilities.fromCurrent()

EditingSecurityCapabilities:Remove(SecurityCapabilities.new(Enum.SecurityCapability.CapabilityControl))

local function GetDefaultSampleOfType(Type: string): Instance
	if not DefaultPropertiesSamples[Type] then
		local DefaultSample = Instance.new(Type)
		DefaultPropertiesSamples[Type] = DefaultSample
	end
	
	return DefaultPropertiesSamples[Type]
end

-- Returns a table with every accessible properties on an instance in their respective categories 
function PropScan.GetPropertiesOfClass(Type: string, Categories: boolean): {[string]: {[number]: string}} & {[number]: string}
	
	if not DefaultPropertiesList[Type] then
		local Properties, PropertiesWithoutCategories = {}, {}

		local AccessibleProperties = ReflectionService:GetPropertiesOfClass(Type, { Security = EditingSecurityCapabilities })
		
		assert(AccessibleProperties, "Attempt to extract properties from a class that doesn't exist")
		
		-- Verify whether the property can be modified and isn't deprecated before adding it in its category
		for Index, Data in AccessibleProperties do
			--print(Data.Permits.Write, typeof(Data.Permits.Write))
			
			if Data.Display.DeprecationMessage 
				or not Data.Permits.Write 
				or Data.Permits.Write == SecurityCapabilities.new(Enum.SecurityCapability.CapabilityControl)
				or Data.Name == "Parent" then
				continue
			end

			local Category = Data.Display.Category

			if not Properties[Category] then
				Properties[Category] = {}
			end

			local CategoryTable = Properties[Category]
			
			table.insert(CategoryTable, Data.Name)
			table.insert(PropertiesWithoutCategories, Data.Name)
		end

		DefaultPropertiesList[Type] = Properties
		DefaultPropertiesListWithoutCategories[Type] = PropertiesWithoutCategories
	end
	
	return Categories == false and DefaultPropertiesListWithoutCategories[Type] or DefaultPropertiesList[Type]
end

-- Returns a property's type according to the given class
function PropScan.GetPropertyType(Type: string, PropertyName: string): string
	return typeof( PropScan.GetDefaultValueOfType(Type, PropertyName) )
end

-- Returns the default value of a class property
function PropScan.GetDefaultValueOfType(Type: string, PropertyName: string): any
	local DefaultSample = GetDefaultSampleOfType(Type)
	
	return DefaultSample[PropertyName]
end

-- Returns whether an object's property is set to the default value
function PropScan.IsPropertySetToDefault(Object: Instance, PropertyName: string): boolean
	return PropScan.GetDefaultValueOfType(Object.ClassName, PropertyName) == Object[PropertyName]
end

-- Returns whether an object's property expects an AssetID as a value
function PropScan.DoesPropertyExpectID(Type: string, PropertyName: string): boolean
	if PropertiesExpectingIDs[Type] and PropertiesExpectingIDs[Type][PropertyName] ~= nil then
		return PropertiesExpectingIDs[Type][PropertyName]
	else
		local Properties = ReflectionService:GetPropertiesOfClass(Type, { Security = EditingSecurityCapabilities })

		if not Properties then
			return false
		end
		
		if not PropertiesExpectingIDs[Type] then
			PropertiesExpectingIDs[Type] = {}
		end
		
		for _, Table in Properties do
			if Table.Name == PropertyName then
				PropertiesExpectingIDs[Type][PropertyName] = Table.Type.EngineType == "ContentId"
				
				return Table.Type.EngineType == "ContentId"
			end
		end
		
		PropertiesExpectingIDs[Type][PropertyName] = false
		
		return false
	end
end

-- Returns whether an object's property is set to the default value
function PropScan.AreObjectsTheSame(...): boolean
	local Objects = { ... }
	
	local FirstObject = Objects[1]
	table.remove(Objects, 1)
	
	for _, Object in Objects do
		assert(Object.ClassName == FirstObject.ClassName, "Unable to compare objects of different classes")
	end
	
	local Properties = PropScan.GetPropertiesOfClass(FirstObject.ClassName, false)
	
	for _, Name in Properties do
		if Name == "Parent" then
			continue
		end
		
		local FirstObjectProperty = FirstObject[Name]
		
		for _, Object in Objects do
			if Object[Name] ~= FirstObject[Name] then
				return false
			end
		end
	end
	
	return true
end


local function FlipTable(Table)
	local NewTable = {}

	for Key, Value in Table do
		NewTable[Value] = Key
	end

	return NewTable
end

local function GetKeysFromTable(Table)
	local NewTable = {}

	for Key, Value in Table do
		table.insert(NewTable, Key)
	end

	return NewTable
end

--[[Returns the properties that can be used with every mentioned class]]
function PropScan.GetCommonPropertiesFromClasses(FirstClass, ...): {[string]: string}
	-- Transform the tuple into a table so we can loop through it
	local Classes = {...}

	-- Get the first class's properties
	local Properties = FlipTable( PropScan.GetPropertiesOfClass(FirstClass, false) )

	-- Go through each of the other classes and determine the final common properties
	for _, Class in Classes do
		-- Get the class's properties and flip them to have an easier time comparing
		local ClassProperties = FlipTable( PropScan.GetPropertiesOfClass(Class, false) )

		-- Go through the inital properties and make sure they're also present in the other class
		for PropertyName in Properties do
			-- If the property lacks, remove it
			if not ClassProperties[PropertyName] then
				Properties[PropertyName] = nil
			end
		end

		-- Make sure the reciproque also applies
		local NewProperties = {}

		for PropertyName in ClassProperties do
			if Properties[PropertyName] then
				NewProperties[PropertyName] = true
			end
		end

		Properties = NewProperties
	end

	-- Return the final result
	return GetKeysFromTable(Properties)
end

--[[Returns the name of every properties of an object with values that are different from the default ones.

The returned table can be directly used with CSS-ish methods like StyleRule:SetProperties()]]
function PropScan.GetCustomPropertiesOfObject(Object: Instance): {[string]: string}
	local CustomProperties = {}
	local ObjectClassName = Object.ClassName
	
	local Properties = PropScan.GetPropertiesOfClass(ObjectClassName, false)
	
	for _, Name in Properties do
		if not PropScan.IsPropertySetToDefault(Object, Name) then
			CustomProperties[Name] = Object[Name]
		end
	end
	
	return CustomProperties
end

return PropScan
