local Tool = script.Parent.Parent
local History = require(script.Parent.History)

local Options = Tool:WaitForChild("Options", 1) and require(Tool.Options)

-- Libraries
local Libraries = Tool:WaitForChild 'Libraries'
local Support = require(Libraries:WaitForChild 'SupportLibrary')
local Signal = require(Libraries:WaitForChild 'Signal')
local Maid = require(Libraries:WaitForChild 'Maid')
local Make = require(Libraries:WaitForChild 'Make')
local InstancePool = require(Libraries:WaitForChild 'InstancePool')

-- Core selection system
Selection = {}
Selection.Items = {}
Selection.ItemIndex = {}
Selection.Parts = {}
Selection.PartIndex = {}
Selection.Models = {}
Selection.ModelIndex = {}
Selection.Attachments = {}
Selection.AttachmentsIndex = {}
Selection.Outlines = {}
Selection.Beams = {}
Selection.HiddenAttachments = {}
Selection.FocusConnections = {}
Selection.Color = BrickColor.new 'Cyan'
Selection.Multiselecting = false
Selection.DisableHighlights = false
Selection.Maid = Maid.new()
Selection.NewDescendantsConnections = {}

-- Events to listen to selection changes
Selection.ItemsAdded = Signal.new()
Selection.ItemsRemoved = Signal.new()
Selection.PartsAdded = Signal.new()
Selection.PartsRemoved = Signal.new()
Selection.AttachmentsAdded = Signal.new()
Selection.AttachmentsRemoved = Signal.new()
Selection.FocusChanged = Signal.new()
Selection.Cleared = Signal.new()
Selection.Changed = Signal.new()
Selection.MultiselectToggle = Signal.new()
Selection.ColorChanged = Signal.new()

function Selection.IsSelected(Item)
	-- Returns whether `Item` is selected or not

	-- Check and return item presence in index
	return Selection.ItemIndex[Item];

end;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in Selection.FocusConnections do
		Connection:Disconnect();
		Selection.FocusConnections[ConnectionKey] = nil;
	end;

end;

--- Adds parts & models found in `Item` to `PartTable` & `ModelTable`.
local function CollectPartsAndModelsAndAttachments(Item, PartTable, ModelTable, AttachmentsTable)

	-- Collect item if it's a part
	if Item:IsA('BasePart') then
		table.insert(PartTable, Item)
	
	elseif Item:IsA('Attachment') then
		
		table.insert(AttachmentsTable, Item)

	else

		-- Collect item if it's a model
		if Item:IsA('Model') then
			table.insert(ModelTable, Item)
		end

		-- Collect parts & models within item
		local Descendants = Item:GetDescendants()
		for i, Descendant in ipairs(Descendants) do
			if Descendant:IsA('BasePart') then
				table.insert(PartTable, Descendant)
			elseif Descendant:IsA('Model') then
				table.insert(ModelTable, Descendant)
			end
		end
	end
end



function Selection.Add(Items, RegisterHistory)
	-- Adds the given items to the selection

	-- Get core API
	local Core = GetCore();
	-- Go through and validate each given item
	
	local SelectableItems = {};
	
	for _, Item in Items do
	--	if i % 400 == 0 then
	--		task.wait(1)
		--	end
		
		local ItemToInspect = Item:IsA("Attachment") and Item.Parent or Item

		-- Make sure each item is valid and not already selected
		if Item.Parent and (not Selection.ItemIndex[Item]) then

			if Item:FindFirstAncestorWhichIsA("Model") and game.Players:GetPlayerFromCharacter(Item:FindFirstAncestorWhichIsA("Model")) then
				if Options.PlayerTolerance == 1 and game.Players:GetPlayerFromCharacter(Item:FindFirstAncestorWhichIsA("Model")) ~= game.Players.LocalPlayer then
					continue
				elseif Options.PlayerTolerance == 2 then
					continue
				end
			elseif Item:IsA("Model") and game.Players:GetPlayerFromCharacter(Item)then
				if Options.PlayerTolerance == 1 and game.Players:GetPlayerFromCharacter(Item) ~= game.Players.LocalPlayer then
					continue
				elseif Options.PlayerTolerance == 2 then
					continue
				end
			end

			if Options.CheckPermission(ItemToInspect, game.Players.LocalPlayer) == true then
				table.insert(SelectableItems, Item);
			end
		end;
		
	end;

	local OldSelection = Selection.Items;

	-- Track parts and models in new selection
	local Parts = {}
	local Models = {}
	local Attachments = {}
	
	if Options.PartSelectionLimit ~= 0 and #SelectableItems + #Selection.Items > Options.PartSelectionLimit then 
		return 
	elseif Options.UseBoxSelectionAt and #SelectableItems + #Selection.Items >= Options.UseBoxSelectionAt then
		Selection.HideOutlines()
		Selection.DisableHighlights = true
	elseif Options.UseBoxSelectionAt and #SelectableItems + #Selection.Items < Options.UseBoxSelectionAt then
		Selection.EnableOutlines()
		Selection.DisableHighlights = false
	end

	-- Go through the valid new selection items
	for i, Item in SelectableItems do
		
		-- Add each valid item to the selection
		Selection.ItemIndex[Item] = true;
		CreateSelectionBoxes(Item)
		if Item:IsA("Attachment") then
			CreateLookDirectionBeam(Item)
			if Item.Visible == false and table.find(Selection.HiddenAttachments, Item) == nil then
			table.insert(Selection.HiddenAttachments, Item)
			Item.Visible = true
			end
		end

		-- Create maid for cleaning up item listeners
		local ItemMaid = Maid.new()
		Selection.Maid[Item] = ItemMaid

		-- Deselect items that are destroyed
		ItemMaid.RemovalListener = Item.AncestryChanged:Connect(function (Object, Parent)
			if Parent == nil then
				Selection.Remove({ Item })
			end
		end)

		-- Find parts and models within item
		CollectPartsAndModelsAndAttachments(Item, Parts, Models, Attachments)

		-- Listen for new parts or models in groups
		local IsGroup = (Item:IsA 'Model' or Item:IsA("Folder")) and true or nil
		ItemMaid.NewPartsOrModels = IsGroup and Item.DescendantAdded:Connect(function (Descendant)
			if Descendant:IsA('PVInstance') then
				if Descendant:IsA('BasePart') then
					local NewRefCount = (Selection.PartIndex[Descendant] or 0) + 1
					Selection.PartIndex[Descendant] = NewRefCount
					Selection.Parts = Support.Keys(Selection.PartIndex)
					if NewRefCount == 1 then
						Selection.PartsAdded:Fire({ Descendant })
					end
				elseif Descendant:IsA('Model') then
					local NewRefCount = (Selection.ModelIndex[Descendant] or 0) + 1
					Selection.ModelIndex[Descendant] = NewRefCount
					Selection.Models = Support.Keys(Selection.ModelIndex)
				elseif Descendant:IsA('Attachment') then
					local NewRefCount = (Selection.AttachmentsIndex[Descendant] or 0) + 1
					Selection.AttachmentsIndex[Descendant] = NewRefCount
					Selection.Attachments = Support.Keys(Selection.AttachmentsIndex)
					if NewRefCount == 1 then
						Selection.AttachmentsAdded:Fire({ Descendant })
					end
				end
			end
		end)
		ItemMaid.RemovingPartsOrModels = IsGroup and Item.DescendantRemoving:Connect(function (Descendant)
			if Selection.PartIndex[Descendant] then
				local NewRefCount = (Selection.PartIndex[Descendant] or 0) - 1
				Selection.PartIndex[Descendant] = (NewRefCount > 0) and NewRefCount or nil
				if NewRefCount == 0 then
					Selection.Parts = Support.Keys(Selection.PartIndex)
					Selection.PartsRemoved:Fire { Descendant }
				end
			elseif Selection.ModelIndex[Descendant] then
				local NewRefCount = (Selection.ModelIndex[Descendant] or 0) - 1
				Selection.ModelIndex[Descendant] = (NewRefCount > 0) and NewRefCount or nil
				if NewRefCount == 0 then
					Selection.Models = Support.Keys(Selection.ModelIndex)
				end
			elseif Selection.AttachmentsIndex[Descendant] then
				local NewRefCount = (Selection.AttachmentsIndex[Descendant] or 0) - 1
				Selection.AttachmentsIndex[Descendant] = (NewRefCount > 0) and NewRefCount or nil
				if NewRefCount == 0 then
					Selection.Attachments = Support.Keys(Selection.AttachmentsIndex)
					Selection.AttachmentsRemoved:Fire({ Descendant })
				end
			end
		end)
	end
	
	-- Update selected item list
	Selection.Items = Support.Keys(Selection.ItemIndex);

	-- Create a history record for this selection change, if requested
	if RegisterHistory and #SelectableItems > 0 then
		TrackSelectionChange(OldSelection);
	end;

	-- Register references to new parts
	local NewParts = {}
	for i, Part in Parts do
		local NewRefCount = (Selection.PartIndex[Part] or 0) + 1
		Selection.PartIndex[Part] = NewRefCount
		if NewRefCount == 1 then
			table.insert(NewParts, Part)
		end
	end
	
	local NewAttachments = {}
	for _, Attachment in Attachments do
		if Attachment == nil then
			return
		end
		local NewRefCount = (Selection.AttachmentsIndex[Attachment] or 0) + 1
		Selection.AttachmentsIndex[Attachment] = NewRefCount
		if NewRefCount == 1 then
			table.insert(NewAttachments, Attachment)
		end
	end

	-- Register references to new models
	local NewModelCount = 0
	for _, Model in Models do
		local NewRefCount = (Selection.ModelIndex[Model] or 0) + 1
		Selection.ModelIndex[Model] = NewRefCount
		if NewRefCount == 1 then
			NewModelCount += 1
		end
	end

	-- Update parts list
	if #NewParts > 0 then
		Selection.Parts = Support.Keys(Selection.PartIndex)
		Selection.PartsAdded:Fire(NewParts)
	end
	
	if #NewAttachments > 0 then
		Selection.Attachments = Support.Keys(Selection.AttachmentsIndex)
		Selection.AttachmentsAdded:Fire(NewAttachments)
	end

	-- Update models list
	if NewModelCount > 0 then
		Selection.Models = Support.Keys(Selection.ModelIndex)
	end

	-- Fire relevant events
	if #SelectableItems > 0 then
		Selection.ItemsAdded:Fire(SelectableItems)
		Selection.Changed:Fire()
	end

end;

function Selection.Remove(Items, RegisterHistory)
	-- Removes the given items from the selection
	
	-- Go through and validate each given item
	local DeselectableItems = {};
	for _, Item in Items do

		-- Make sure each item is actually selected
		if Selection.IsSelected(Item) then
			table.insert(DeselectableItems, Item);
		end;

	end;

	local OldSelection = Selection.Items;

	-- Track parts and models in removing selection
	local Parts = {}
	local Models = {}
	local Attachments = {}

	-- Go through the valid deselectable items
	for _, Item in DeselectableItems do

		-- Remove item from selection
		Selection.ItemIndex[Item] = nil;
		RemoveSelectionBoxes(Item)
		if Item:IsA("Attachment") then
			RemoveLookDirectionBeams(Item)
			if table.find(Selection.HiddenAttachments, Item) then
				Item.Visible = false
				table.remove(Selection.HiddenAttachments, table.find(Selection.HiddenAttachments, Item))
			end
		end

		-- Stop tracking item's parts
		Selection.Maid[Item] = nil

		-- Find parts and models associated with item
		CollectPartsAndModelsAndAttachments(Item, Parts, Models, Attachments)

	end;

	-- Update selected item list
	Selection.Items = Support.Keys(Selection.ItemIndex);

	-- Create a history record for this selection change, if requested
	if RegisterHistory and #DeselectableItems > 0 then
		TrackSelectionChange(OldSelection);
	end;

	-- Clear references to removing parts
	local RemovingParts = {}
	for _, Part in Parts do
		local NewRefCount = (Selection.PartIndex[Part] or 0) - 1
		Selection.PartIndex[Part] = (NewRefCount > 0) and NewRefCount or nil
		if NewRefCount == 0 then
			table.insert(RemovingParts, Part)
		end
	end
	
	local RemovingAttachments = {}
	for _, Attachment in Attachments do
		local NewRefCount = (Selection.AttachmentsIndex[Attachment] or 0) - 1
		Selection.AttachmentsIndex[Attachment] = (NewRefCount > 0) and NewRefCount or nil
		if NewRefCount == 0 then
			table.insert(RemovingAttachments, Attachment)
		end
	end

	-- Clear references to removing models
	local RemovingModelCount = 0
	for _, Model in Models do
		local NewRefCount = (Selection.ModelIndex[Model] or 0) - 1
		Selection.ModelIndex[Model] = (NewRefCount > 0) and NewRefCount or nil
		if NewRefCount == 0 then
			RemovingModelCount += 1
		end
	end

	-- Update parts list
	if #RemovingParts > 0 then
		Selection.Parts = Support.Keys(Selection.PartIndex)
		Selection.PartsRemoved:Fire(RemovingParts)
	end

	if #RemovingAttachments > 0 then
		Selection.Attachments = Support.Keys(Selection.AttachmentsIndex)
		Selection.AttachmentsRemoved:Fire(RemovingParts)
	end


	-- Update models list
	if RemovingModelCount > 0 then
		Selection.Models = Support.Keys(Selection.ModelIndex)
	end

	-- Fire relevant events
	if #DeselectableItems > 0 then
		Selection.ItemsRemoved:Fire(DeselectableItems)
		Selection.Changed:Fire()
	end
	
end;

function Selection.Clear(RegisterHistory)
	-- Clears all items from selection

	-- Remove all selected items
	Selection.Remove(Selection.Items, RegisterHistory);

	-- Fire relevant events
	Selection.Cleared:Fire();

end;

function Selection.Replace(Items, RegisterHistory)
	-- Replaces the current selection with the given new items

	-- Save old selection reference for history
	local OldSelection = Selection.Items;

	-- Find new items
	local NewItems = {}
	for _, Item in ipairs(Items) do
		if not Selection.ItemIndex[Item] then
			table.insert(NewItems, Item)
		end
	end

	-- Find removing items
	local RemovingItems = {}
	local NewItemIndex = Support.FlipTable(Items)
	for _, Item in ipairs(Selection.Items) do
		if not NewItemIndex[Item] then
			table.insert(RemovingItems, Item)
		end
	end

	-- Update selection
	if #RemovingItems > 0 then
		Selection.Remove(RemovingItems, false)
	end
	if #NewItems > 0 then
		Selection.Add(NewItems, false)
	end

	-- Create a history record for this selection change, if requested
	if RegisterHistory then
		TrackSelectionChange(OldSelection);
	end;

end;

local function IsVisible(Item)
	return Item:IsA 'Model' or Item:IsA 'BasePart'
end

local function GetVisibleFocus(Item)
	-- Returns a visible focus representing the item

	-- Return nil if no focus
	if not Item then
		return nil
	end

	-- Return focus if it's visible
	if IsVisible(Item) then
		return Item

	-- Return first visible item within focus if not visible itself
	elseif Item then
		return Item:FindFirstChildWhichIsA('BasePart') or
			Item:FindFirstChildWhichIsA('Model') or
			Item:FindFirstChildWhichIsA('BasePart', true) or
			Item:FindFirstChildWhichIsA('Model', true) or
			Item:IsA("Attachment") and
			Item
	end
end

local FocusHighlightPool

if Options.HighlightFocus then
	FocusHighlightPool = InstancePool.new(60, function ()
		return Make('Highlight')(Options.FocusHighlightMake(GetCore()))
	end)
end

function Selection.SetFocus(Item)
	-- Selects `Item` as the focused selection item

	-- Ensure focus has changed
	local Focus = GetVisibleFocus(Item)
	if Selection.Focus == Focus then
		return
	end

	-- Set new focus item
	Selection.Focus = Focus
	
	if Options.HighlightFocus then
		FocusHighlightPool:ReleaseAll()
	end
	
	ClearConnections()
	
	if Focus and #Selection.Items > 1 then
		if Options.HighlightFocus then
			local Highlight = FocusHighlightPool:Get()
		
			Highlight.Adornee = Focus
			Highlight.Enabled = true
		
			Selection.FocusConnections.Enable = GetCore().Enabling:Connect(function()
				Highlight.Enabled = true
			end)
		
			Selection.FocusConnections.Disable = GetCore().Disabling:Connect(function()
				Highlight.Enabled = false
			end)
		end
	end

	-- Fire relevant events
	Selection.FocusChanged:Fire(Focus)

end

function FocusOnLastSelectedPart()
	-- Sets the last part of the selection as the focus

	-- If selection is empty, clear the focus
	if #Selection.Items == 0 then
		Selection.SetFocus(nil);

	-- Otherwise, focus on the last part in the selection
	else
		Selection.SetFocus(Selection.Items[#Selection.Items]);
	end;

end;

-- Listen for changes to the selection and keep the focus updated
Selection.Changed:Connect(FocusOnLastSelectedPart);

function GetCore()
	-- Returns the core API
	return require(script.Parent);
end;

local function GetVisibleChildren(Item, Table)
	local Table = Table or {}

	-- Search for visible items recursively
	for _, Item in Item:GetChildren() do
		if IsVisible(Item) then
			Table[#Table + 1] = Item
		else
			GetVisibleChildren(Item, Table)
		end
	end

	-- Return visible items
	return Table
end

-- Create target box pool
local SelectionBoxPool = InstancePool.new(60, function ()
	return Make('SelectionBox')(Options.SelectionBoxMake(GetCore()))
end)

local LookDirectionPool = InstancePool.new(60, function ()
	return Make 'LineHandleAdornment' {
		Name = 'BTLookAt',
		Parent = GetCore().UI,
		Length = 100,
		Thickness = 2,
		Transparency = 0,
		Color3 = Color3.new(0, 1, 0)
	}
end)

-- Define target box cleanup routine
function SelectionBoxPool.Cleanup(SelectionBox)
	SelectionBox.Adornee = nil
	SelectionBox.Visible = nil
end

if Options.HighlightFocus then
	function FocusHighlightPool.Cleanup(SelectionBox)
		SelectionBox.Adornee = nil
	end
end
	
function LookDirectionPool.Cleanup(SelectionBox)
	SelectionBox.Adornee = nil
	SelectionBox.Visible = nil
end

function CreateSelectionBoxes(Item)
	-- Creates selection boxes for the given item

	-- Only create selection boxes if in tool mode
	if GetCore().Mode ~= 'Tool' then
		return;
	end;

	-- Ensure selection boxes don't already exist for item
	if Selection.Outlines[Item] or Selection.DisableHighlights then
		return
	end

	-- Get targetable items
	local Items = Support.FlipTable { Item }
	if not IsVisible(Item) then
		Items = Support.FlipTable(GetVisibleChildren(Item))
	end

	-- Create selection box for each targetable item
	local SelectionBoxes = {}
	for Item in Items do

		-- Create the selection box
		
			local SelectionBox = SelectionBoxPool:Get()
			SelectionBox.Adornee = Item
			SelectionBox.Visible = true
		

		-- Register the outline
		SelectionBoxes[Item] = SelectionBox

	end

	-- Register selection boxes for this item
	Selection.Outlines[Item] = SelectionBoxes

end;

function CreateLookDirectionBeam(Item)
	-- Creates selection boxes for the given item

	-- Only create selection boxes if in tool mode
	if GetCore().Mode ~= 'Tool' then
		return;
	end;

	-- Ensure selection boxes don't already exist for item
	if Selection.Beams[Item] then
		return
	end

	-- Get targetable items
	local Items = Support.FlipTable { Item }

	-- Create selection box for each targetable item
	local Beams = {}
	
	for Item in Items do

		-- Create the selection box
		local Beam = LookDirectionPool:Get()
		Beam.Adornee = Item:FindFirstAncestorWhichIsA("BasePart")
		Beam.CFrame = Item.CFrame * CFrame.fromEulerAnglesXYZ(0, math.rad(-90), 0)
		Beam.Visible = true
		
		coroutine.wrap(function()
			
			repeat 
				task.wait(0.1)
			until Selection.Beams[Item]
			
			while Beam and Selection.Beams[Item] do
				Beam.CFrame = Item.CFrame * CFrame.fromEulerAnglesXYZ(0, math.rad(-90), 0)
				task.wait(1 / 30)																	
			end
			
		end)()

		-- Register the outline
		Beams[Item] = Beam  

	end

	-- Register selection boxes for this item
	Selection.Beams[Item] = Beams

end;

function RemoveSelectionBoxes(Item)
	-- Removes the given item's selection boxes

	-- Only proceed if outlines exist for item
	local SelectionBoxes = Selection.Outlines[Item]
	if not SelectionBoxes then
		return
	end

	-- Remove each item's outline
	for _, SelectionBox in SelectionBoxes do
		SelectionBoxPool:Release(SelectionBox)
	end

	-- Clear list of outlines for item
	Selection.Outlines[Item] = nil

end

function RemoveLookDirectionBeams(Item)
	-- Removes the given item's selection boxes

	-- Only proceed if outlines exist for item
	local LookDirectionBeams = Selection.Beams[Item]
	if not LookDirectionBeams then
		return
	end

	-- Remove each item's outline
	for _, Beam in LookDirectionBeams do
		LookDirectionPool:Release(Beam)
	end

	-- Clear list of outlines for item
	Selection.Beams[Item] = nil

end

function Selection.HideHiddenAttachments()
	-- Hides every hidden attachments

	-- Make every hidden attachments invisible
	for _, Item in Selection.HiddenAttachments do
		Item.Visible = false
	end
end

function Selection.ShowHiddenAttachments()
	-- Shows back every hidden attachments

	-- Make every hidden attachments invisible
	for _, Item in Selection.HiddenAttachments do
		Item.Visible = true
	end
end

function Selection.RecolorOutlines(Color)
	-- Updates selection outline colors

	-- Set `Color` as the new color
	Selection.Color = Color;

	-- Recolor existing outlines
	for Outline in SelectionBoxPool.All do
		Outline.Color = Selection.Color;
	end;
	
	Selection.ColorChanged:Fire()

end;

function Selection.RecolorOutline(Item, Color)
	-- Updates outline colors for `Item`

	-- Make sure `Item` has outlines
	local Outlines = Selection.Outlines[Item]
	if not Outlines then
		return
	end

	-- Recolor all outlines for item
	for VisibleItem, Outline in pairs(Outlines) do
		Outline.Color = Color
	end
end

function Selection.FlashOutlines()
	-- Flashes selection outlines for emphasis

	-- Fade in from complete to normal transparency
	for Transparency = 1, 0.5, -0.1 do

		-- Update each outline
		for Outline in pairs(SelectionBoxPool.InUse) do
			Outline.Transparency = Transparency;
		end;

		-- Fade over time
		task.wait(0.1);

	end;

end;

function Selection.EnableMultiselectionHotkeys()
	-- Enables hotkeys for multiselecting

	-- Determine multiselection hotkeys
	local Hotkeys = Support.FlipTable { 'LeftShift', 'RightShift', 'LeftControl', 'RightControl' };

	-- Get core API
	local Core = GetCore();

	-- Listen for matching key presses
	Core.Connections.MultiselectionHotkeys = Support.AddUserInputListener('Began', 'Keyboard', false, function (Input)
		if Hotkeys[Input.KeyCode.Name] then
			Selection.Multiselecting = true;
			Selection.MultiselectToggle:Fire()
		end;
	end);

	-- Listen for matching key releases
	Core.Connections.MultiselectingReleaseHotkeys = Support.AddUserInputListener('Ended', 'Keyboard', true, function (Input)

		-- Get currently pressed keys
		local PressedKeys = Support.GetListMembers(Support.GetListMembers(game:GetService('UserInputService'):GetKeysPressed(), 'KeyCode'), 'Name');

		-- Continue multiselection if a hotkey is still pressed
		for _, PressedKey in pairs(PressedKeys) do
			if Hotkeys[PressedKey] then
				return;
			end;
		end;

		-- Disable multiselection if matching key not found
		Selection.Multiselecting = false;
		Selection.MultiselectToggle:Fire()

	end);

end;

function Selection.EnableOutlines()
	-- Enables selection outlines

	-- Create outlines for each item
	for Item in Selection.ItemIndex do
		CreateSelectionBoxes(Item)
	end
end

function Selection.HideOutlines()
	-- Hides selection outlines

	-- Remove every item's outlines
	for Item in Selection.Outlines do
		RemoveSelectionBoxes(Item)
	end
	
	FocusHighlightPool:ReleaseAll()
end

function Selection.EnableBeams()
	-- Enables selection outlines

	-- Create outlines for each item
	for Item in Selection.AttachmentsIndex do
		CreateLookDirectionBeam(Item)
	end
end

function Selection.HideBeams()
	-- Hides selection outlines

	-- Remove every item's outlines
	for Item in Selection.Beams do
		RemoveLookDirectionBeams(Item)
	end
end

function TrackSelectionChange(OldSelection)
	-- Registers a history record for a change in the selection

	-- Avoid overwriting history for selection actions
	if History.Index ~= #History.Stack then
		return;
	end;

	-- Add the history record
	History.Add({

		Before = OldSelection;
		After = Selection.Items;

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Restore the old selection
			Selection.Replace(HistoryRecord.Before);

		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the new selection
			Selection.Replace(HistoryRecord.After);

		end;
	});

end;

return Selection;
