Tool = script.Parent.Parent;
Core = require(Tool.Core);
Sounds = Tool:WaitForChild("Sounds");

-- Libraries
local ListenForManualWindowTrigger = require(Tool.Core:WaitForChild('ListenForManualWindowTrigger'))

-- Import relevant references
Selection = Core.Selection;
Support = Core.Support;
Security = Core.Security;

local NegateHighlight = script:WaitForChild("NegateHighlight")
local HighlightsFolder = script:WaitForChild("Highlights")
local BoundingBox = require(Tool.Core.BoundingBox)

local Roact = require(Tool.Vendor.Roact)
local NotificationDialog = require(Tool.UI.GroupDialog)
local Signal = require(Tool.Libraries.Signal)

-- Initialize the tool
local TransformationTool = {
	Name = 'Transformation Tool';
	Color = BrickColor.new 'Bright orange';
	
	Split = false;
}

local NegativeParts = {}

TransformationTool.ManualText = [[<font weight="900" size="24"><u><i>Union Tool  ??</i></u></font>
Allows you to create unions with this tool.<font size="6"><br /></font>

<font size="12" color="rgb(150, 150, 150)"><b>Negate</b></font>

When pressing the negate button, every selected parts will turn slightly red. This means that once the union will be created, every other non-negative selected parts in the negative parts will get truncated. 

<font size="12" color="rgb(150, 150, 150)"><b>Union</b></font>

Once the union button is pressed, every parts selected will be put together. Negative parts will turn what they intersect into void. There is only <b>one</b> final object.

<font size="12" color="rgb(150, 150, 150)"><b>Separate</b></font>

The separation is useful to revert an union. This will revert the part to its original state, perfect if you want to change something afterwards.

<b>NOTE:</b> Separating multiple assemblies (part created when clicking the assemble button) might create duplicate parts!

]]

local Connections = {};

function TransformationTool.Equip()
	-- Enables the tool's equipped functionality

	-- Start up our interface
	ShowUI();
	if Selection.DisableHighlights then
		BoundingBox.StartBoundingBox(function () end)
	end

	Connections.BoundingBox = Selection.Changed:Connect(function()
		if Selection.DisableHighlights and not BoundingBox.GetBoundingBox() then
			BoundingBox.StartBoundingBox(function () end)
		elseif not Selection.DisableHighlights and BoundingBox.GetBoundingBox() then
			BoundingBox.ClearBoundingBox()
		end
	end)

end;

function TransformationTool.Unequip()
	-- Disables the tool's equipped functionality

	-- Clear unnecessary resources
	HideUI();
	ClearConnections()
	BoundingBox.ClearBoundingBox();

end;

function ClearConnections()
	-- Clears out temporary connections

	for ConnectionKey, Connection in pairs(Connections) do
		Connection:Disconnect();
		Connections[ConnectionKey] = nil;
	end;

end;

function ShowUI()
	-- Creates and reveals the UI

	-- Reveal UI if already created
	if TransformationTool.UI and TransformationTool.UI.Parent ~= nil then

		-- Reveal the UI
		UI.Visible = true;


		UIUpdater = Support.ScheduleRecurringTask(UpdateNegativePartsDisplay, 0.1);
		-- Skip UI creation
		return;

	end;
	
	if TransformationTool.UI then
		TransformationTool.UI:Destroy()
	end

	-- Create the UI
	UI = Core.Interfaces.BTTransformationToolGUI:Clone();
	UI.Parent = Core.UI;
	UI.Visible = true;
	
	TransformationTool.UI = UI
	
	-- Apply changes for deprecated UIs (if the difference doesn't seem intentional)
	if UI:FindFirstChild("Warning") and Core.Options.UseOldUnionSystem then
		UI.Warning.Position = UDim2.new(0, 10, 1, 0)
		UI.Warning.Text = "WARNING: Fork3X is set to use the old union system. Saving and separating aren't available."
	end
	
	if Core.Options.UseOldUnionSystem then
		UI.Interface.SeparateButton.Visible = false
		UI.Interface.IntersectButton.Position = UI.Interface.SeparateButton.Position
		UI.Interface.IntersectButton.AnchorPoint = UI.Interface.SeparateButton.AnchorPoint
	end
	
	if UI.Interface.Size == UDim2.new(1, -10, 0, 25) then
		UI.Interface.Size = UDim2.new(1, -10, 0, 91)
	end
	if UI.Size == UDim2.new(0, 220, 0, 220) then
		UI.Size = UDim2.new(0, 225, 0, 133)
	end
	if UI.Changes.Position == UDim2.new(0, 5, 0, 100) then
		UI.Changes.Position = UDim2.new(0, 5, 1, 0)
	end	

	-- Hook up the buttons
	UI.Interface.NegateButton.Activated:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		NegateParts()
		end);
	UI.Interface.NegateButton.MouseEnter:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);
	
	UI.Interface.UnionButton.Activated:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		CreateUnion(false)
	end);
	UI.Interface.UnionButton.MouseEnter:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);
	
	UI.Interface.SeparateButton.Activated:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		SeparateUnion()
	end);
	UI.Interface.SeparateButton.MouseEnter:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);
	
	UI.Interface.IntersectButton.Activated:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Press"))
		CreateUnion(true)
	end);
	UI.Interface.IntersectButton.MouseEnter:Connect(function()
		game:GetService("SoundService"):PlayLocalSound(Sounds:WaitForChild("Hover"))
	end);

	local SplitToggle = TransformationTool.UI.SplitOption.Check

	SplitToggle.Activated:Connect(function()
		TransformationTool.Split = not TransformationTool.Split
		UpdateToggleInput(SplitToggle, TransformationTool.Split)
	end)

	UpdateToggleInput(SplitToggle, TransformationTool.Split)
	
	-- Hook up manual triggering
	local SignatureButton = UI:WaitForChild('Title'):WaitForChild('Signature')
	ListenForManualWindowTrigger(TransformationTool.ManualText, TransformationTool.Color.Color, SignatureButton)

	UIUpdater = Support.ScheduleRecurringTask(UpdateNegativePartsDisplay, 0.1);
end;

function UpdateToggleInput(Toggle, Data)
	-- Updates the data in the given buttons

	-- Go through the inputs and data
	if Data == true then
		-- Clear every UI tags
		Toggle:AddTag("STATE_True")
		Toggle:RemoveTag("STATE_Multiple")

		--			ShadowsCheckbox.Image = Core.Assets.CheckedCheckbox;
	elseif Data == false then
		-- Clear every UI tags
		Toggle:RemoveTag("STATE_True")
		Toggle:RemoveTag("STATE_Multiple")

		--			ShadowsCheckbox.Image = Core.Assets.UncheckedCheckbox;
	elseif Data == nil then
		-- Clear every UI tags
		Toggle:RemoveTag("STATE_True")
		Toggle:AddTag("STATE_Multiple")

		--			ShadowsCheckbox.Image = Core.Assets.SemicheckedCheckbox;
	end;

end;

function HideUI()
	-- Hides the tool UI

	-- Make sure there's a UI
	if not UI then
		return;
	end;

	-- Hide the UI
	UI.Visible = false;
	
	UIUpdater:Stop();
	
	for _, Highlight in pairs(script.Highlights:GetChildren()) do
		Highlight.Enabled = false
	end

end;

function CreateUnion(Intersect)
	local NormalParts = {}
	local Negative = {}
	
	for _, Part in pairs(Selection.Parts) do								-- Let's class parts in two sections: Negative ones and normal ones.
		if table.find(NegativeParts, Part) then
			table.insert(Negative, Part)
		else
			table.insert(NormalParts, Part)
		end
	end
	
	print(NormalParts, Negative)
	
	local ActionName = Core.Options.UseOldUnionSystem and 'OldCreateUnion' or 'CreateUnion'
	
	local Unions = Core.SyncAPI:Invoke(ActionName, NormalParts, Negative, TransformationTool.Split, Intersect)
	
	print(Unions)
	
	if type(Unions) == "table" then
		for _, Union in pairs(Unions) do
			if NormalParts[Union] then
				NormalParts[Union] = nil
			end
		end
	elseif Unions ~= nil then
		if NormalParts[Unions] then
			NormalParts[Unions] = nil
		end
	end
	
	local HistoryRecord = {
		Unions = type(Unions) == "table" and Unions or {Unions};
		NormalParts = NormalParts;
		Negative = Negative;
		
		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Remove the welds
			Core.SyncAPI:Invoke('Remove', HistoryRecord.Unions);
			Core.SyncAPI:Invoke('UndoRemove', HistoryRecord.NormalParts);
			Core.SyncAPI:Invoke('UndoRemove', HistoryRecord.Negative);
			
			Selection.Replace(Support.Merge(table.clone(HistoryRecord.NormalParts), HistoryRecord.Negative));
			
			NegateParts(HistoryRecord.Negative)
		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the welds
			Core.SyncAPI:Invoke('UndoRemove', HistoryRecord.Unions);
			Core.SyncAPI:Invoke('Remove', HistoryRecord.NormalParts);
			Core.SyncAPI:Invoke('Remove', HistoryRecord.Negative);
			
			Selection.Replace(HistoryRecord.Unions);
		end;

	};
	
	Core.History.Add(HistoryRecord);
	
	Core.SyncAPI:Invoke('Remove', Negative);
	Core.SyncAPI:Invoke('Remove', NormalParts);
	
	UI.Changes.Text.Text = "The union has been successfully created."
	
	Selection.Replace(type(Unions) == "table" and Unions or {Unions});
	
	table.clear(NegativeParts)
end

function SeparateUnion()
	
	local Unions = {}

	for _, Part in pairs(Selection.Parts) do								-- Let's class parts in two sections: Negative ones and normal ones.
		if Part:IsA("PartOperation") then
			table.insert(Unions, Part)
		end
	end

	local Parts, TheNegativeParts = Core.SyncAPI:Invoke('SeparateUnion', Unions);

	local HistoryRecord = {
		Unions = Unions;
		Parts = Parts;
		NegativeParts = TheNegativeParts;

		Unapply = function (HistoryRecord)
			-- Reverts this change

			-- Remove the welds
			Core.SyncAPI:Invoke('UndoRemove', HistoryRecord.Unions);
			Core.SyncAPI:Invoke('Remove', HistoryRecord.Parts);
			
			Selection.Replace(HistoryRecord.Unions);
		end;

		Apply = function (HistoryRecord)
			-- Reapplies this change

			-- Restore the welds
			Core.SyncAPI:Invoke('Remove', HistoryRecord.Unions);
			Core.SyncAPI:Invoke('UndoRemove', HistoryRecord.Parts);
			
			Selection.Replace(HistoryRecord.Parts);
			
			NegateParts(HistoryRecord.NegativeParts)
		end;

	};
	
	if Parts ~= {} then
		UI.Changes.Text.Text = "The union has been successfully separated."
		
		Core.History.Add(HistoryRecord);
		
		Core.SyncAPI:Invoke('Remove', Unions);
		
		Selection.Replace(Parts, false);
		
		Selection.Add(TheNegativeParts, false);
		
		table.clear(NegativeParts)
		
		NegateParts(TheNegativeParts)
	else
		UI.Changes.Text.Text = "The selection doesn't have any union or you're not allowed to separate unions (you should use the built-in tools in Studio)."
	end
end

function NegateParts(Parts)
	
	for _, Part in pairs(Parts or Selection.Parts) do
		if Support.GetChildOfClass(Part, "SpecialMesh") then continue end
		if table.find(NegativeParts, Part) then
			table.remove(NegativeParts, table.find(NegativeParts, Part))
			for _, Highlight in pairs(script.Highlights:GetChildren()) do
				if Highlight.Adornee == Part then
					Highlight:Destroy()
				end
			end
			continue
		end
		table.insert(NegativeParts, Part)
		local PartHighlight = NegateHighlight:Clone()
		PartHighlight.Adornee = Part
		PartHighlight.Parent = HighlightsFolder
	end;
end

function UpdateNegativePartsDisplay()
	for i, Part in pairs(NegativeParts) do
		if Support.GetChildOfClass(Part, "SpecialMesh") or Part.Parent == nil or Part == nil then
			table.remove(NegativeParts, table.find(NegativeParts, Part))
			for _, Highlight in pairs(script.Highlights:GetChildren()) do
				if Highlight.Adornee == Part then
					Highlight:Destroy()
				end
			end
			continue
		end
		for _, Highlight in pairs(script.Highlights:GetChildren()) do
			if Highlight.Adornee == Part then
				Highlight.Enabled = true
			elseif Highlight.Adornee == nil or Highlight.Adornee.Parent == nil or not table.find(NegativeParts, Highlight.Adornee) then
				Highlight:Destroy()
			end
		end
	end
	for _, Highlight in pairs(script.Highlights:GetChildren()) do
		if Highlight.Adornee == nil or Highlight.Adornee.Parent == nil or not table.find(NegativeParts, Highlight.Adornee) then
			Highlight:Destroy()
		end
	end
end

-- Return the tool
return TransformationTool;