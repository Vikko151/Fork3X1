local Root = script.Parent.Parent
local Libraries = Root:WaitForChild 'Libraries'
local Vendor = Root:WaitForChild 'Vendor'
local UI = Root:WaitForChild 'UI'
local RunService = game:GetService 'RunService'
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Options

-- Libraries
local Support = require(Libraries:WaitForChild 'SupportLibrary')
local Roact = require(Vendor:WaitForChild 'Roact')
local Maid = require(Libraries:WaitForChild 'Maid')
local Signal = require(Libraries:WaitForChild 'Signal')

-- Roact
local new = Roact.createElement
local Frame = require(UI:WaitForChild 'Frame')
local ImageLabel = require(UI:WaitForChild 'ImageLabel')
local ImageButton = require(UI:WaitForChild 'ImageButton')
local TextLabel = require(UI:WaitForChild 'TextLabel')
local ItemList = require(script:WaitForChild 'ItemList')

-- Create component
local Explorer = Roact.PureComponent:extend 'Explorer'

local IsTreeUpdating = false
local TreeUpdated = Signal.new()

function Explorer:init(props)
    self:setState {
        Items = {},
		RowHeight = 18,
		SearchText = nil
	}
	
	self.MaxSize, self.SetMaxSize = Roact.createBinding(Vector2.new())

    -- Update batching data
    self.UpdateQueues = {}
    self.QueueTimers = {}

    -- Item tracking data
    self.LastId = 0
    self.IdMap = {}
	self.PendingParent = {}
	self.FollowedBy = {}
	
	self.ItemOnHold = nil
	self.StartsWith = nil

    -- Define item expanding function
    self.ToggleExpand = function (ItemInstance)
        return self:setState(function (State)
            local Item = State.Items[ItemInstance]
            Item.Expanded = not Item.Expanded
            return { Items = State.Items }
        end)
    end
end

function Explorer:didUpdate(previousProps, previousState)

    -- Trigger a scope change if prop changes
    if previousProps.Scope ~= self.props.Scope then
        self:UpdateScope(self.props.Scope)
    end

end

function Explorer:UpdateScope(Scope)
    local Core = self.props.BTCore
    local Selection = Core.Selection

    -- Clear previous cleanup maid
    if self.ScopeMaid then
        self.ScopeMaid:Destroy()
    end

    -- Create maid for cleanup
    self.ScopeMaid = Maid.new()

    -- Ensure new scope is defined
    if not Scope then
        return
    end

    -- Build initial tree
    coroutine.resume(coroutine.create(function ()
        self:UpdateTree()

        -- Scroll to first selected item
        if #Selection.Items > 0 then
            local FocusedItem = Selection.IsSelected(Selection.Focus) and Selection.Focus or Selection.Items[1]
            self:setState({
                ScrollTo = FocusedItem--self.IdMap[FocusedItem]
            })
        else
            self:setState({
                ScrollTo = Roact.None
            })
        end
    end))

    -- Listen for new and removing items
    local Scope = Core.Targeting.Scope
	self.ScopeMaid.Add = Scope.DescendantAdded:Connect(function (Item)
		IsTreeUpdating = true
		self:UpdateTree()
		IsTreeUpdating = false
		TreeUpdated:Fire()
    end)
	self.ScopeMaid.Remove = Scope.DescendantRemoving:Connect(function (Item)
		IsTreeUpdating = true
		self:UpdateTree()
		IsTreeUpdating = false
		TreeUpdated:Fire()
    end)

    -- Listen for selected items
	self.ScopeMaid.Select = Selection.ItemsAdded:Connect(function (Items)
		-- Defer the connection so new descendants can be taken in account (if the likelihood is high)
		task.wait()
		
		-- and not self.IdMap[Items[1]] 
		if IsTreeUpdating and (#Items == 1) and not ( self.FollowedBy[ Items[1] ] or table.find(self.FollowedBy, Items[1]) ) then
			TreeUpdated:Wait()
		end
		
		self:UpdateSelection(Items)
		
        -- If single item selected, get item state
       -- local ItemId = (#Items == 1) and self.IdMap[Items[1]]
		local Item = Items[1]
		
        -- Expand ancestors leading to item
        self:setState(function (State)
            local Changes = {}
			local ItemState = State.Items[Item]--State.Items[ItemId]
			local Parent = ItemState and ItemState.Parent
			local ParentState = ItemState and State.Items[Parent]--self.IdMap[ItemState.Parent] formerly ParentId
            --local ParentState = ParentId and State.Items[ParentId]

            while ParentState do
				ParentState.Expanded = true
				Changes[Parent] = ParentState
               -- Changes[ParentId] = ParentState
				--ParentId = self.IdMap[ParentState.Parent]
				Parent = ParentState.Parent
				ParentState = State.Items[Parent] -- State.Items[ParentId]
			end
			
            return {
                Items = Support.Merge(State.Items, Changes),
                ScrollTo = Item
            }
        end)
    end)
    self.ScopeMaid.Deselect = Selection.ItemsRemoved:Connect(function (Items)
        self:UpdateSelection(Items)
    end)

end

function Explorer:didMount()

    self.Mounted = true

    -- Create maid for cleanup on unmount
    self.ItemMaid = Maid.new()

    -- Set scope
    self:UpdateScope(self.props.Scope)
end

function Explorer:willUnmount()
    self.Mounted = false

    -- Clean up resources
    self.ScopeMaid:Destroy()
    self.ItemMaid:Destroy()
end

--[[
local function IsTargetable(Item)
	return Item:IsA 'Model' or
		Item:IsA 'BasePart' or
		Item:IsA 'Tool' or
		Item:IsA 'Accessory' or
		Item:IsA 'Accoutrement' or
		Item:IsA 'Attachment'
end

function Explorer.IsItemIndexable(Item)
    return (IsTargetable(Item) and Item.ClassName ~= 'Terrain') or
		Item:IsA 'Folder'
end]]

function Explorer:UpdateTree()
	
    -- Check if queue should be executed
    if not self:ShouldExecuteQueue('Tree') then
        return
	end

    -- Track order of each item
	local IdMap = self.IdMap
	
    -- Perform update to state
	self:setState(function (State)
		
		local NewItems = 1
		
		local Descendants = Options.GetIndexableItemsFunction(self.props.Scope, self.props.BTCore)
		local DescendantMap = Support.FlipTable(Descendants)
		
		-- Use table.create with the absolute difference of descendants
		-- We know we'll add/remove them, so that's welcome extra performance
		local Changes = table.create( math.abs( #Descendants - Support.CountKeys(State.Items) ) )
		
		-- Reset self.StartsWith and self.ItemOnHold to keep things accurate
		self.ItemOnHold = nil
		self.StartsWith = nil

        -- Check all items in scope
        for Index, Item in next, Descendants do
           -- local ItemId = IdMap[Item]
			-- local ItemState = ItemId and State.Items[ItemId]
			
			local ItemState = State.Items[Item]

            -- Update reordered items
			if ItemState then
				-- Store the first item in this list so we know how to itinerate through FollowedBy
				if not self.StartsWith then
					self.StartsWith = Item
				end
				
				-- If an item is on hold, update the hierarchy description
				if self.ItemOnHold and self.FollowedBy[self.ItemOnHold] ~= Item then
					self.FollowedBy[self.ItemOnHold] = Item
				end
				
				-- Put the item on hold so we can track the succession of parts
				-- This makes offsetting unnecessary, which is way better for performance
				self.ItemOnHold = Item
				
				local Parent = ItemState.Parent
				if not State.Items[Parent] then
					self:UpdateItemParent(Item, Changes, State)
				end
				
				--[[
                if ItemState.Order ~= OrderCounter then
                    ItemState = Support.CloneTable(ItemState)
                    ItemState.Order = OrderCounter
                    Changes[ItemId] = ItemState
                end
                OrderCounter = OrderCounter + 1

                -- Update parents in case scope changed
                local ParentId = self.IdMap[ItemState.Parent]
                if not State.Items[ParentId] then
                    self:UpdateItemParent(Item, Changes, State)
                end]]

            -- Introduce new items
            elseif self:BuildItemState(Item, self.props.Scope, DescendantMap, Changes, State) then
                NewItems += 1
			end
			
			if NewItems >= 500 then
				task.wait()
				NewItems = 0
			end
		end
		
		local ItemsRemoved = 0

        -- Remove old items from state
        for Object, Item in State.Items do
			if not DescendantMap[Object] then
				ItemsRemoved += 1

                -- Clear state
				Changes[Object] = Support.Blank --Changes[ItemId] = Support.Blank

				self.FollowedBy[Object] = nil
				
				local PreviousItem = Support.FindTableOccurrence(self.FollowedBy, Object)
				
				-- If there's a previous item, take in account the offset
				if PreviousItem and DescendantMap[ self.FollowedBy[Object] ] then
					
					self.FollowedBy[PreviousItem] = self.FollowedBy[Object]
				elseif PreviousItem then
					
					self.FollowedBy[PreviousItem] = nil
				end
				
                -- Clear ID
               -- IdMap[Object] = nil

                -- Clean up resources
                self.ItemMaid[Object] = nil

				-- Update parent child counter
				local Parent = Item.Parent-- and self.IdMap[Item.Parent]
				local ParentState = self:GetStagedItemState(Parent, Changes, State)
				
				if ParentState then
					ParentState.Children[Object] = nil
					ParentState.Unlocked[Object] = nil
					ParentState.IsLocked = next(ParentState.Children) and not next(ParentState.Unlocked)
					Changes[Parent] = ParentState
					self:PropagateLock(ParentState, Changes, State)
				end
				
				--[[
                local ParentId = Item.Parent and self.IdMap[Item.Parent]
                local ParentState = self:GetStagedItemState(ParentId, Changes, State)
                if ParentState then
                    ParentState.Children[ItemId] = nil
                    ParentState.Unlocked[ItemId] = nil
                    ParentState.IsLocked = next(ParentState.Children) and not next(ParentState.Unlocked)
                    Changes[ParentId] = ParentState
                    self:PropagateLock(ParentState, Changes, State)
                end]]

			end
			
			if ItemsRemoved >= 750 then
				task.wait()
				ItemsRemoved = 0
			end
		end
		
        -- Update state
        return { Items = Support.MergeWithBlanks(State.Items, Changes) }
    end)

end

function Explorer:UpdateSelection(Items)
    local Selection = self.props.BTCore.Selection

    -- Queue changed items
    self:QueueUpdate('Selection', Items)

    -- Check if queue should be executed
    if not self:ShouldExecuteQueue('Selection') then
        return
	end

    -- Perform updates to state
    self:setState(function (State)
        local Changes = {}
		local Queue = self:GetUpdateQueue('Selection')
		
        for Items in pairs(Queue) do
            for _, Item in ipairs(Items) do
               -- local ItemId = self.IdMap[Item]
				if State.Items[Item] then
                    local ItemState = Support.CloneTable(State.Items[Item])
                    ItemState.Selected = Selection.IsSelected(Item)
                    Changes[Item] = ItemState
                end
            end
		end
		
        return { Items = Support.Merge(State.Items, Changes) }
    end)

end

function Explorer:BuildItemState(Item, Scope, DescendantMap, Changes, State)
    local Parent = Item.Parent
    --local ParentId = self.IdMap[Parent]

	-- Check if indexable and visible in hierarchy
	local InHierarchy = State.Items[Parent] or Changes[Parent] or (Parent == Scope)
    if not InHierarchy then
        return nil
    end
	
	-- If it's the first item, set it as self.StartsWith
	if not self.StartsWith then
		self.StartsWith = Item
	end
	
	-- Describe the new item's position
	if self.ItemOnHold then
		self.FollowedBy[self.ItemOnHold] = Item
	end
	
	-- Put that new item on hold
	self.ItemOnHold = Item
	
    -- Assign ID
    --local ItemId = self.LastId + 1
    --self.LastId = ItemId
    --self.IdMap[Item] = ItemId

    -- Check if item is a part
    local IsPart = Item:IsA 'BasePart'

    -- Create maid for cleanup when item is removed
    local ItemMaid = Maid.new()
    self.ItemMaid[Item] = ItemMaid

    -- Prepare item state
    local ItemState = {
        --Id = ItemId,
		Name = Item.Name,
		
		-- CustomName is basically if you want to display something else.
		
		CustomName = Options.CustomNameFunction(Item, game.Players.LocalPlayer),
        IsPart = IsPart,
		IsLocked = IsPart and Item.Locked == true or IsPart and (not Options.CheckPermission(Item, game.Players.LocalPlayer)) or false,
        Class = Item.ClassName,
        Parent = Parent,
        Children = {},
        Unlocked = {},
        --Order = Order,
        Expanded = nil,
        Instance = Item,
        Selected = self.props.BTCore.Selection.IsSelected(Item) or nil
    }

    -- Register item state into changes
    Changes[Item] = ItemState

    -- Update parent children
    local ParentState = self:GetStagedItemState(Parent, Changes, State)
    if ParentState then
        ParentState.Children[Item] = true
        Changes[Parent] = ParentState
    end

    -- Update children
    for PendingChild in pairs(self.PendingParent[Item] or {}) do
        local ChildState = self:GetStagedItemState(PendingChild, Changes, State)
        if ChildState then
            ItemState.Children[PendingChild] = true
            self:PropagateLock(ChildState, Changes, State)
        end
    end

    -- Propagate lock to ancestors
    self:PropagateLock(ItemState, Changes, State)

    -- Listen to name changes
    ItemMaid.Name = Item:GetPropertyChangedSignal('Name'):Connect(function ()

        -- Queue change
        self:QueueUpdate('Name', Item)

        -- Check if queue should be executed
        if not self:ShouldExecuteQueue('Name') then
            return
        end

        -- Perform updates to state
        self:setState(function (State)
            local Changes = {}
            local Queue = self:GetUpdateQueue('Name')
            for Item in pairs(Queue) do
                --local ItemId = self.IdMap[Item]
                local ItemState = Support.CloneTable(State.Items[Item])
				ItemState.Name = Item.Name
				ItemState.CustomName = Item.Name
                Changes[Item] = ItemState
            end
            return { Items = Support.Merge(State.Items, Changes) }
        end)

    end)

    -- Listen to parent changes
    ItemMaid.Parent = Item:GetPropertyChangedSignal('Parent'):Connect(function ()
        if not Item.Parent then
            return
        end

        -- Queue change
        self:QueueUpdate('Parent', Item)

        -- Check if queue should be executed
        if not self:ShouldExecuteQueue('Parent') then
            return
        end

        -- Perform updates to state
        self:setState(function (State)
            local Changes = {}
            local Queue = self:GetUpdateQueue('Parent')
            for Item in pairs(Queue) do
                self:UpdateItemParent(Item, Changes, State)
            end
            return { Items = Support.MergeWithBlanks(State.Items, Changes) }
        end)

        -- Update tree state
        self:UpdateTree()
    end)

    -- Attach part-specific listeners
    if IsPart then
        ItemMaid.Locked = Item:GetPropertyChangedSignal('Locked'):Connect(function ()

            -- Queue change
            self:QueueUpdate('Lock', Item)

            -- Check if queue should be executed
            if not self:ShouldExecuteQueue('Lock') then
                return
            end

            -- Perform updates to state
            self:setState(function (State)
                local Changes = {}
                local Queue = self:GetUpdateQueue('Lock')
                for Item in pairs(Queue) do
                    self:UpdateItemLock(Item, Changes, State)
                end
                return { Items = Support.MergeWithBlanks(State.Items, Changes) }
            end)

		end)
	end

    -- Indicate that item state was created
    return true

end

function Explorer:QueueUpdate(Type, Item)
    self.UpdateQueues[Type] = Support.Merge(self.UpdateQueues[Type] or {}, {
        [Item] = true
    })
end

function Explorer:GetUpdateQueue(Type)

    -- Get queue
    local Queue = self.UpdateQueues[Type]
    self.UpdateQueues[Type] = nil

    -- Return queued items
    return Queue

end

function Explorer:ShouldExecuteQueue(Type)
    local ShouldExecute = self.QueueTimers[Type] or Support.CreateConsecutiveCallDeferrer(0.025)
    self.QueueTimers[Type] = ShouldExecute

    -- Wait until state updatable
    if ShouldExecute() and self.Mounted then
        return true
	end
end

function Explorer:UpdateItemLock(Item, Changes, State)

    -- Get staged item state
    --local ItemId = self.IdMap[Item]
    local ItemState = self:GetStagedItemState(Item, Changes, State)
    if not ItemState then
        return
    end

    -- Update state
    ItemState.IsLocked = Item.Locked
    Changes[Item] = ItemState

    -- Propagate lock state up hierarchy
    self:PropagateLock(ItemState, Changes, State)

end

function Explorer:GetStagedItemState(Item, Changes, State)

    -- Check if item staged yet
    local StagedItemState = Item and Changes[Item]

    -- Ensure item still exists
    if not Item or (StagedItemState == Support.Blank) or
        not (StagedItemState or State.Items[Item]) then
        return
    end

    -- Return staged item state
    return StagedItemState or Support.CloneTable(State.Items[Item])

end

function Explorer:UpdateItemParent(Item, Changes, State)

    -- Get staged item state
    --local ItemId = self.IdMap[Item]
    local ItemState = self:GetStagedItemState(Item, Changes, State)
    if not ItemState then
        return
    end

    -- Get current parent ID
    local PreviousParent = ItemState.Parent-- and self.IdMap[ItemState.Parent]

    -- Set new parent ID
    local Parent = Item.Parent
    --local ParentId = self.IdMap[Parent]
    ItemState.Parent = Parent
    Changes[Item] = ItemState

    -- Queue parenting if parent item valid, but not yet registered
    if not State.Items[Parent] and not (Parent == Scope) then
        if Parent:IsDescendantOf(Scope) then
            self.PendingParent[Parent] = Support.Merge(self.PendingParent[Parent] or {}, { [Item] = true })
        end
    end

    -- Update previous parent
    local PreviousParentState = self:GetStagedItemState(PreviousParent, Changes, State)
    if PreviousParentState then
        PreviousParentState.Children[Item] = nil
        PreviousParentState.Unlocked[Item] = nil
        PreviousParentState.IsLocked = next(PreviousParentState.Children) and not next(PreviousParentState.Unlocked)
        Changes[PreviousParent] = PreviousParentState
    end

    -- Update new parent
    local ParentState = self:GetStagedItemState(Parent, Changes, State)
    if ParentState then
        ParentState.Children[Item] = true
        Changes[Parent] = ParentState
        self:PropagateLock(ItemState, Changes, State)
    end

end

function Explorer:PropagateLock(ItemState, Changes, State)

    -- Continue if upward propagation is possible
    if not ItemState.Parent then
        return
    end

    -- Start propagation from changed item
	-- local ItemId = ItemState.Id
	local ItemState = ItemState
	local Item = ItemState.Instance

    -- Get item's parent state
    repeat
        local Parent = ItemState.Parent
      --  local ParentId = Parent and self.IdMap[Parent]
        local ParentState = self:GetStagedItemState(Parent, Changes, State)
        if ParentState then

            -- Update parent lock state
            ParentState.Unlocked[Item] = (not ItemState.IsLocked) and true or nil
            ParentState.IsLocked = next(ParentState.Children) and not next(ParentState.Unlocked)
            Changes[Parent] = ParentState

            -- Continue propagation upwards in the hierarchy
            Item = Parent
            ItemState = ParentState

        -- Stop propagation if parent being removed
        else
            Item = nil
            ItemState = nil
        end


    -- Stop at highest reachable point in hierarchy
    until
        not ItemState
end

function Explorer:render()
    local props = self.props
	local state = self.state
	
	Options = props.BTCore.Options
	
    -- Display window
    return new("ImageLabel", {
    --    Active = true,
    --    AnchorPoint = Vector2.new(1, 0.5),
	--	Position = UDim2.new(1, -130, 0.6, -380/2),
		--	Size = UDim2.new(0, 145, 0, 0),
		Size = UDim2.new(),
		AutomaticSize = Enum.AutomaticSize.Y,
		RBXTAG_Explorer = true,
	--	Height = 'WRAP_CONTENT',
	--	RBXTAG_Explorer = true
    --    Image = 'rbxassetid://2244248341',
   --     ScaleType = 'Slice',
    --    SliceCenter = Rect.new(4, 4, 12, 12),
    --    ImageTransparency = 1 - 0.4, -- 0.93
		--	ImageColor3 = Color3.new(0, 0, 0) -- 3B3B3B
		[Roact.Ref] = function(rbx)
			if rbx then
				rbx.Size = UDim2.new(0, 0, 0, 1)
				task.wait()
				rbx.Size = UDim2.new(0, 0, 0, 0)
			end
		end,
    },
	{
		Layout = new('UIListLayout', {
			FillDirection = Enum.FillDirection.Vertical,
			Padding = UDim.new(0, 0),
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			--Wraps = true
		}),
		
        -- Window header
        Header = new("TextButton", {
		--	Text = '<font family="rbxassetid://12187365977">  EXPLORER</font>',
		--	Font = Enum.Font.Montserrat,
		--	RichText = true,
        --    TextSize = 9,
        --    Height = UDim.new(0, 14),
        --    TextColor = 'FFFFFF',
			--    TextTransparency = 1 - 0.6/2
			LayoutOrder = 1,
			RBXTAG_Native = true;	
			[Roact.Event.MouseButton1Down] = function (rbx)
				local Dock: ImageLabel = rbx.Parent
				local InitialAbsolutePosition = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
				local InitialPosition = Dock:GetStyled("Position")

				self.DockDragging = UserInputService.InputChanged:Connect(function (Input)
					if (Input.UserInputType.Name == 'MouseMovement') or (Input.UserInputType.Name == 'Touch') then

						-- Suppress activation response if dragging detected
						if (Vector2.new(Input.Position.X, Input.Position.Y) - InitialAbsolutePosition).Magnitude > 3 then
							rbx.Active = false
						end

						-- Reposition dock
						Dock.Position = UDim2.new(
							InitialPosition.X.Scale,
							InitialPosition.X.Offset + (Input.Position.X - InitialAbsolutePosition.X),
							InitialPosition.Y.Scale,
							InitialPosition.Y.Offset + (Input.Position.Y - InitialAbsolutePosition.Y)
						)
					end
				end)

				self.DockDraggingEnd = UserInputService.InputEnded:Connect(function (Input)
					if (Input.UserInputType.Name == 'MouseButton1') or (Input.UserInputType.Name == 'Touch') then
						if self.DockDragging then
							self.DockDragging:Disconnect()
							self.DockDragging = nil
						end
						
						
						if self.DockDraggingEnd then
							self.DockDraggingEnd:Disconnect()
							self.DockDraggingEnd = nil
						end

						rbx.Active = true
					end
				end)
			end;
		},
		
        {
			CloseButton = new("ImageButton", {
			--	Image = 'rbxassetid://2244452978',
			--	ImageRectOffset = Vector2.new(0, 0),
			--	ImageRectSize = Vector2.new(14, 14) * 2,
			--	AspectRatio = 1,
			--	AnchorPoint = Vector2.new(1, 0.5),
			--	Position = UDim2.new(1, 0, 0.5, 0),
				--	ImageTransparency = 1 - 0.34,
				RBXTAG_Native = true;
				[Roact.Event.Activated] = props.Close
			})
		}),
		
		SearchBox = new("Frame", {
			--	Text = '<font family="rbxassetid://12187365977">  EXPLORER</font>',
			--	Font = Enum.Font.Montserrat,
			--	RichText = true,
			--    TextSize = 9,
			--    Height = UDim.new(0, 14),
			--    TextColor = 'FFFFFF',
			--    TextTransparency = 1 - 0.6/2
			LayoutOrder = 2,
			RBXTAG_Native = true;	
		},

		{
			SearchInput = new("TextBox", {
				--	Image = 'rbxassetid://2244452978',
				--	ImageRectOffset = Vector2.new(0, 0),
				--	ImageRectSize = Vector2.new(14, 14) * 2,
				--	AspectRatio = 1,
				--	AnchorPoint = Vector2.new(1, 0.5),
				--	Position = UDim2.new(1, 0, 0.5, 0),
				--	ImageTransparency = 1 - 0.34,
				Text = "";
				RBXTAG_Native = true;
				[Roact.Event.FocusLost] = function(rbx)
					if rbx then
						self:setState({
							SearchText = rbx.Text ~= "" and rbx.Text or Roact.None
						})
					end
				end
			})
		}),

        -- Scrollable item list
        ItemList = new(ItemList, {
            Scope = props.Scope,
            Items = state.Items,
            ScrollTo = state.ScrollTo,
            BTCore = props.BTCore,
			--IdMap = self.IdMap,
			StartsWith = self.StartsWith,
			FollowedBy = self.FollowedBy,
            RowHeight = state.RowHeight,
			ToggleExpand = self.ToggleExpand,
			SearchText = self.state.SearchText,
			RevertToOldPosition = props.RevertToOldPosition
        })
	},  script.Name, self)
end

return Explorer