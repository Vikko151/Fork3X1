local Tool = script.Parent.Parent.Parent
local Core = require(Tool.Core)

local function TranslatePartsRelativeToPart(BasePart, InitialPartStates, InitialModelStates, InitialAttachmentsStates)
	-- Moves the given parts in `InitialStates` to BasePart's current position, with their original offset from i
	-- @Vikko151 - This function has been made to now work with BulkMoveTo(), hence improving performance

	-- Get focused part's position for offsetting
	local RelativeTo = InitialPartStates[BasePart].CFrame:Inverse()
	
	local Parts = {}
	local CFrames = {}

	-- Calculate offset and move each part
	for Part, InitialState in pairs(InitialPartStates) do

		table.insert(Parts, Part)
		-- Calculate how far apart we should be from the focused part
		
		local Offset = RelativeTo * InitialState.CFrame
		
		table.insert(CFrames, BasePart.CFrame * Offset)

	end

	for Model, InitialState in pairs(InitialModelStates) do
		local Offset = RelativeTo * InitialState.Pivot
		Model.WorldPivot = BasePart.CFrame * Offset
	end
	
	for Attachment, InitialState in pairs(InitialAttachmentsStates) do
		local Offset = RelativeTo * InitialState.WorldCFrame
		Attachment.WorldCFrame = Attachment.WorldCFrame * Offset
	end
	
	game.Workspace:BulkMoveTo(Parts, CFrames)
end

local function GetIncrementMultiple(Number, Increment)

	-- Get how far the actual distance is from a multiple of our increment
	local MultipleDifference = Number % Increment

	-- Identify the closest lower and upper multiples of the increment
	local LowerMultiple = Number - MultipleDifference
	local UpperMultiple = Number - MultipleDifference + Increment

	-- Calculate to which of the two multiples we're closer
	local LowerMultipleProximity = math.abs(Number - LowerMultiple)
	local UpperMultipleProximity = math.abs(Number - UpperMultiple)

	-- Use the closest multiple of our increment as the distance moved
	if LowerMultipleProximity <= UpperMultipleProximity then
		Number = LowerMultiple
	else
		Number = UpperMultiple
	end

	return Number
end

return {
    TranslatePartsRelativeToPart = TranslatePartsRelativeToPart;
    GetIncrementMultiple = GetIncrementMultiple;
}
