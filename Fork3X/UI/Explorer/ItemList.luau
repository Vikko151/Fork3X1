local Root = script.Parent.Parent.Parent
local Libraries = Root:WaitForChild 'Libraries'
local Vendor = Root:WaitForChild 'Vendor'
local UI = Root:WaitForChild 'UI'
local RunService = game:GetService 'RunService'

-- Libraries
local Support = require(Libraries:WaitForChild 'SupportLibrary')
local Roact = require(Vendor:WaitForChild 'Roact')
local Maid = require(Libraries:WaitForChild 'Maid')

-- Roact
local new = Roact.createElement
local Frame = require(UI:WaitForChild 'Frame')
local ScrollingFrame = require(UI:WaitForChild 'ScrollingFrame')
local ItemRow = require(script.Parent:WaitForChild 'ItemRow')

local OldPosition = Vector2.new()

-- Create component
local ItemList = Roact.Component:extend 'ItemList'
ItemList.defaultProps = {
	MaxHeight = 300
}

local function HasMouse()
	return game:GetService("UserInputService").MouseEnabled
end

function ItemList:init(props)
	self:setState {
		Min = 0,
		Max = props.MaxHeight,
		CanvasPosition = props.RevertToOldPosition and OldPosition or Vector2.new(),
		AllowScrolling = false,
	}

	local Count = 0
	self.PreviousPosition = 0

	self.UpdateRef = Roact.createRef()

	if self.Update then
		self.Update:Stop()
	end

	self.LastRefreshAt = 0
	self.LastRefresh = time()
	
	-- Create callback for updating canvas boundaries
	self.UpdateBoundaries = function (rbx, UpdateAnyway)
		if self.Rendering then
			return
		end

		Count += 1
		if self.Mounted and (Count >= 30 or UpdateAnyway) then
			self.DoNotUpdateItems = true


			self:setState {
				CanvasPosition = rbx.CanvasPosition,
				Min = rbx.CanvasPosition.Y - rbx.AbsoluteSize.Y * 0.75,
				Max = rbx.CanvasPosition.Y + rbx.AbsoluteSize.Y * 1.75,
			}
			Count = 0
		end
	end

	self.Revert = props.RevertToOldPosition and 5 or nil
end

function ItemList:didMount()
	self.Mounted = true
end

function ItemList:willUnmount()
	OldPosition = self.state.CanvasPosition
	if self.Update then
		self.Update:Disconnect()
		self.Update = nil
	end
	self.Mounted = false
end

function ItemList:willUpdate(nextProps, nextState)
	if self.props.SearchText ~= nextProps.SearchText then
		self.ScrolledTo = nil
		self.DoNotUpdateItems = false
	end
	
	if nextState.Min == self.state.Min and nextState.Max == self.state.Max then
		local CanvasPosition = nextState.CanvasPosition
		
		nextState.Min = nextState.CanvasPosition.Y - nextProps.MaxHeight * 0.75
		nextState.Max = nextState.CanvasPosition.Y + nextProps.MaxHeight * 1.75
	end
end

function ItemList:didUpdate(previousProps, previousState)
	local IsScrollTargetSet = self.props.ScrollTo and
		(previousProps.ScrollTo ~= self.props.ScrollTo)
	
	local Object = self.UpdateRef:getValue()

	if Object and self.Revert and self.Revert > 0 and OldPosition then
		Object.CanvasPosition = OldPosition
		self.Revert -= 1
	end

	if (previousProps.Scope ~= self.props.Scope) and (not IsScrollTargetSet) then
		self:setState({
			CanvasPosition = Vector2.new(0, 0);
			Min = 0;
			Max = self.props.MaxHeight;
		})
	end
end

function ItemList:render()
	self.Rendering = true
	
	local props = self.props
	local state = self.state

	-- Keep track of how many items are out of view
	local SkippedAbove = 0
	local SkippedBelow = 0
	local TargetCanvasPosition

	-- Declare a button for each item
	local ItemList = table.create(props.MaxHeight // props.RowHeight)
	local VisibleItemCount = 0
	local ItemHeight = props.RowHeight

	-- Go through each item in order
	if self.DoNotUpdateItems ~= true then
		if props.SearchText then
			local IdMap = table.create( Support.CountKeys(props.Items) )

			for Item in props.Items do
				IdMap[Item] = Item
			end

			self.ItemsInMemory = props.BTCore.Options.ExplorerSearchingAlgorithm(props.Items, IdMap, props.SearchText)
		else
			self.ItemsInMemory = props.Items
		end
	end

	self.DoNotUpdateItems = false
	
	local OrderedItems = self.ItemsInMemory

	local CurrentItem = props.StartsWith
	local Count = 0
	
	while CurrentItem ~= nil do
		Count += 1

		-- Get the item's state
		local Item = self.ItemsInMemory[CurrentItem]
		
		if not Item then
			local FollowedBy = props.FollowedBy[CurrentItem]
			
			if FollowedBy then
				CurrentItem = FollowedBy
				continue
			else
				break
			end
		end
		
		-- Get item parent state
		local Parent = CurrentItem.Parent
		local ParentState = Parent and props.Items[Parent]

		-- Determine visibility and depth from ancestors
		local Visible = true
		local Depth = 0

		if Parent then
			local ParentState = ParentState

			while ParentState do

				-- Stop if ancestor not visible
				if not ParentState.Expanded then
					Visible = nil
					break

					-- Count visible ancestors
				else
					Depth += 1
				end

				-- Check next ancestor
				local Parent = ParentState.Parent
				ParentState = props.Items[Parent]

			end
		end

		-- Set canvas position to begin at item if requested and out-of-view
		-- Item.Id
		if (CurrentItem == props.ScrollTo) and (self.ScrolledTo ~= props.ScrollTo) then
			local ItemPosition = VisibleItemCount * props.RowHeight

			-- Setting the value of ScrolledTo here removes rubber banding
			self.ScrolledTo = CurrentItem--Id

			if ItemPosition < state.CanvasPosition.Y or
				ItemPosition > (state.CanvasPosition.Y + props.MaxHeight) then

				TargetCanvasPosition = Vector2.new(0, ItemPosition)
			end
		end
		
		-- Calculate whether item is in view
		if Visible then
			VisibleItemCount = VisibleItemCount + 1
			local ItemTop = (VisibleItemCount - 1) * props.RowHeight
			
			local Max = state.Max == 0 and props.MaxHeight or state.Max

			if ItemTop < state.Min then
				SkippedAbove = SkippedAbove + 1
				Visible = nil
			elseif ItemTop > Max then
				SkippedBelow = SkippedBelow + 1
				Visible = nil
			end
		end

		-- Declare component for item
		ItemList[Count] = Visible and new(ItemRow, Support.Merge({}, Item, {
			Depth = Depth,
			BTCore = props.BTCore,
			ToggleExpand = props.ToggleExpand,
			Height = props.RowHeight,
			Order = Count
		}))

		CurrentItem = props.FollowedBy[CurrentItem]
	end

	self.Rendering = false
	
	return Roact.createFragment({
		ItemList = new("ScrollingFrame", {
			CanvasSize = UDim2.new(1, -2, 0, VisibleItemCount * props.RowHeight),
			Size = UDim2.new(1, 0, 1, 30),
			CanvasPosition = TargetCanvasPosition or state.CanvasPosition,
			LayoutOrder = 3;
			[Roact.Change.CanvasPosition] = function(Object)
				if Object then
					if Object.CanvasPosition.Y == self.PreviousPosition 
						and (Object.CanvasPosition ~= self.state.CanvasPosition
							or time() - self.LastRefresh <= 2) then

						self.UpdateBoundaries(Object, true)
					elseif math.abs(Object.CanvasPosition.Y - self.LastRefreshAt) >= Object.AbsoluteSize.Y * 0.75 then
						self.LastRefreshAt = Object.CanvasPosition.Y

						self.UpdateBoundaries(Object, true)
					end

					self.PreviousPosition = Object.CanvasPosition.Y
				end
			end,
			[Roact.Children] = Support.Merge(ItemList, {
				TopSpacer = new(Frame, {
					Size = UDim2.new(0, 0, 0, SkippedAbove * props.RowHeight),
					LayoutOrder = 0
				}),
				BottomSpacer = new(Frame, {
					Size = UDim2.new(0, 0, 0, SkippedBelow * props.RowHeight),
					LayoutOrder = Count + 20 -- Just to be sure
				}),
				Layout = new('UIListLayout', {
					FillDirection = Enum.FillDirection.Vertical,
					Padding = UDim.new(0, 0),
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					VerticalAlignment = Enum.VerticalAlignment.Top,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				FlexItem = new('UIFlexItem', {
					FlexMode = Enum.UIFlexMode.Shrink
				}),
				SizeConstraint = new('UISizeConstraint', {
					MinSize = Vector2.new(0, 20),
					MaxSize = Vector2.new(math.huge, math.min(props.MaxHeight, VisibleItemCount * props.RowHeight))
				})
			});
			[Roact.Ref] = self.UpdateRef,
		}),
	})
end

return ItemList