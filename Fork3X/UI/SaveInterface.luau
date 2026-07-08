local Root = script.Parent.Parent
local Vendor = Root:WaitForChild('Vendor')
local Libraries = Root:WaitForChild("Libraries")

local CSGTreeV1 = require(Libraries.CSGTreeV1)
local CSGTreeV2 = require(Libraries.CSGTreeV2)

local SerializationModules = {
	V4 = require(Libraries.SerializationV4),
	V5 = require(Libraries.SerializationV5),
	V6 = require(Libraries.SerializationV6)(CSGTreeV1, CSGTreeV2)
}

local Support = require(Libraries.SupportLibrary)

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local Maid = require(Libraries:WaitForChild("Maid"))
local new = function(Type, props, ...)
	if not props then
		props = {}
	end

	props.RBXTAG_Native = true

	return Roact.createElement(Type, props, ...)
end

local ManualText = [[<font weight="900" size="24"><u><i>Save/Load Interface 💾</i></u></font>

Self-explanatory. Lets you save and load a set of parts/models.<br />
<font size="20" transparency="0.3"><u>                     </u></font>

<font size="12" color="rgb(150, 150, 150)"><b>Interface</b></font>

The interface has recently got overhauled and is designed in the following way:
 <font color="rgb(150, 150, 150)">•</font>  The bar at the top indicates the total size of your data and how many slots you created. <b>The limit may vary from one game to another.</b>
 <font color="rgb(150, 150, 150)">•</font>  The slots manager is located on the left. In order to manage a slot, <b>press on it.</b> To create a new slot, <b>press the button at the bottom.</b>
 <font color="rgb(150, 150, 150)">•</font>  The current slot's data is located on the right. You can load it, erase it, or rename it there after pressing it in the slot manager.

<font size="20" transparency="0.3"><u>                     </u></font>

<font size="12" color="rgb(150, 150, 150)"><b>Saving your build</b></font>

As mentioned previously, in order to create a slot, you must:
 <font color="rgb(150, 150, 150)">1.</font>  Press the button at the bottom. This will open a new window.
 <font color="rgb(150, 150, 150)">2.</font>  You will be required to select your build before continuing. Feel free to close the window when doing it; you'll be brought back to where you were after re-opening the menu.
 <font color="rgb(150, 150, 150)">3.</font>  Give a name to your slot so you can identify it easily. Leaving the box blank will give the slot a dummy name.
 <font color="rgb(150, 150, 150)">3.</font>  Choose whether you want to keep your save across servers. <b>If you only save the slot on the server, you won't be able to use it again in another server.</b>
 <font color="rgb(150, 150, 150)">4.</font>  An acute sound should play if your build got successfully saved. 
 <font color="rgb(150, 150, 150)">→</font>  If an error displays, don't worry; press "What can I do?", take a screenshot, and send it to the game developer(s) so they can report it to the creator of Fork3X.
 
 <font size="20" transparency="0.3"><u>                     </u></font>
 
<font size="12" color="rgb(150, 150, 150)"><b>Limitations</b></font>

To ensure optimal storage and due to Roblox's limitations, acknowledge the following:
 <font color="rgb(150, 150, 150)">•</font>  Fork3X only saves <b>what it can change.</b> Any kind of object you cannot make or modify with Fork3X won't be saved.
 <font color="rgb(150, 150, 150)">•</font>  Roblox slightly modifies your save before storing it. Although actively prevented, corruption has to be expected.
 <font color="rgb(150, 150, 150)">→</font>  In case this happens, remember to stay comprehensive with the game developer(s) and the creator of Fork3X. If someone already reported data corruption, don't make a duplicate report.
 <font color="rgb(150, 150, 150)">•</font>  If your save is too big, try to rename your parts to their default name and prefer using folder to find them back easily. This can heavily reduce a save's size.

<font size="20" transparency="0.3"><u>                     </u></font>

<font size="12" color="rgb(150, 150, 150)"><b>KiChar</b></font>

<b>KiChar</b> is a familiar name for another, more complicated size system, KiB Raw. Basically, Fork3X saves your data as text that gets its size heavily reduced afterwards.

As it cannot access this data, the size is estimated with <b>the amount of characters.</b>

This explains why your slot may get bigger more quickly than it should. A solution that allows a better estimation is being considered.]]

local PopUpText = [[<font size="18"><b>This build is outdated</b></font>

A newer saving/loading system is here, which may greatly reduce your save's size. You can update it by pressing the button below, check if everything works fine, and update it to improve your storage.

Please do note that updating is a beta feature that may break. If it does, fret not because you can revert this change.]]

local ConfirmationText = [[<font size="18"><b>Let's see if it works</b></font>

The updated version of your build will be the default one with the current BTools you hold.

- If you are satisfied with the result, you can press the button below to make this change definitive and so improve storage on the long term.
- If something went wrong, don't worry: reset or rejoin the game and you'll get back your previous build.]]

local ManualWindowModule = Root:FindFirstChild("Core") and Root.Core:WaitForChild('ListenForManualWindowTrigger') 
	or Root.Tool.Value.Core:WaitForChild('ListenForManualWindowTrigger')

local ListenForManualWindowTrigger = require(ManualWindowModule)

local SaveInterface = Roact.PureComponent:extend(script.Name)

local InflatedData

local function SetupViewportFrame(ViewportFrame: ViewportFrame, Preview)
	ViewportFrame:ClearAllChildren()

	--local Data = require(script.Oppenheimer)

	-- Find the required serialization module to inflate the build
	local DataVersion = Preview.Version
	local SerializationModule = DataVersion == 6 and SerializationModules.V6 or DataVersion == 5 and SerializationModules.V5 or SerializationModules.V4

	local Success, Build = pcall(SerializationModule.InflateBuildData, Preview)
	
	if not Success then
		warn(Build)
		return
	end

	-- Create a container for our build
	local Container = Instance.new("Model")

	for _, Object in Build do
		Object.Parent = Container
	end

	-- Set the center to the origin
	Container:PivotTo(CFrame.new())

	-- Get the build's size with its bounding box
	local BoundingBoxCFrame, BoundingBoxSize = Container:GetBoundingBox()

	-- Add half the size of each dimension to get the furthest point from the center
	local Extremity = BoundingBoxCFrame * CFrame.new(BoundingBoxSize.X * 0.5, BoundingBoxSize.Y * 0.5, BoundingBoxSize.Z * 0.5) --CFrame.new(BoundingBoxSize.Magnitude, BoundingBoxSize.Magnitude, BoundingBoxSize.Magnitude)

	-- Get the direction of the vector between both points
	local ExtremityDirection = (Extremity.Position - BoundingBoxCFrame.Position).Unit

	-- We will have a FOV of 30°, which means that math.tan(math.rad(31)) = BiggestDimension / Distance (there's one degree in less for comfort)
	-- Find the biggest dimension and find Distance with it

	local BiggestDimension = BoundingBoxSize.Magnitude--math.max(.X, BoundingBoxSize.Y, BoundingBoxSize.Z)
	local Distance = BiggestDimension / math.tan(math.rad(27))

	local ExtremityPosition = ExtremityDirection * Distance

	local DegreesPerPixel = 27 / ViewportFrame.AbsoluteSize.X

	-- Also economise performance by removing parts with a apparent diametre according to the user's quality level
	local Settings = UserSettings().GameSettings

	local MinPixelSize = Settings.SavedQualityLevel.Value <= 2 and 12 or Settings.SavedQualityLevel.Value <= 5 and 6 or 3
	--local MinPartSize = Distance * math.tan(math.rad(DegreesPerPixel * MinPixelSize))

	for _, Part in Container:QueryDescendants("BasePart") do
		local PartDiametre = Part.Size.Magnitude
		local MinPartSize = (ExtremityPosition - Part.Position).Magnitude * math.tan(math.rad(DegreesPerPixel * MinPixelSize))

		-- If it's too small, delete it
		if PartDiametre < MinPartSize then
			Part:Destroy()
		end
	end

	local Camera = Instance.new("Camera")

	Camera.FieldOfView = 30
	Camera.CFrame = CFrame.lookAt(ExtremityPosition, BoundingBoxCFrame.Position)
	Camera.Parent = ViewportFrame

	ViewportFrame.CurrentCamera = Camera
	ViewportFrame.LightDirection = -ExtremityDirection

	Container.Parent = ViewportFrame

end

function SaveInterface:GetButtonsFromOptions(Options: () -> { [string]: {} })
	local RoactChildren = {}

	for Name, Callback in Options() do
		RoactChildren[Name] = new("TextButton", {
			Text = Name,
			[Roact.Event.Activated] = function(rbx)
				self.props.Core.PlaySound("Press")
				
				Callback(rbx)
			end,
			[Roact.Event.MouseEnter] = function()
				self.props.Core.PlaySound("Hover")
			end,
		})
	end

	return RoactChildren
end

function SaveInterface:SaveBuild()
	local Success = false

	local SlotName = self.TextBoxRef:getValue() and self.TextBoxRef:getValue().Text or ""
	local SlotNumber = self.state.CurrentSlotNumber or Support.FindFirstBlankInTable(self.props.Slots)

	local Changes = {}

	if SlotName ~= "" or self.SaveNewParts == true then
		Success, Changes = self.props.Modify(SlotNumber, self.SaveNewParts, SlotName)
	end

	if Success then
		local SlotData = self.props.Slots[SlotNumber]

		if not SlotData then
			self.props.Slots[SlotNumber] = {
				Name = "Slot" .. SlotNumber,
			}

			SlotData = self.props.Slots[SlotNumber]
		end

		for Name, Value in Changes do
			SlotData[Name] = Value
		end
	end

	self:setState({
		NotificationContent = Success and "ConfirmPrompt" or "Error",

		CurrentSlot = self.props.Slots[SlotNumber],
	})
end

function SaveInterface:GetNotificationsTable(props, state)
	local NotificationWindows = {}

	NotificationWindows = {
		SelectionPrompt = {
			Title = "Select the parts you want to save",
			Detail = [[Fork3X will save the parts you're currently selecting on this slot.
		
Feel free to close this window and come back once you selected your build. You'll be brought back here.
		
Note that parts that got unselected or destroyed during the process won't be saved.
		]],
			Buttons = function()
				return {
					Cancel = function()
						self:setState({
							IsNotificationOpen = false,
							NotificationContent = Roact.None
						})
					end,
					Skip = state.CurrentSlot and props.AllowRenaming and function()
						self.SaveNewParts = false

						self:setState({
							NotificationContent = "NamePrompt"
						})
					end or nil,
					Continue = function()
						if #props.Core.Selection.Items == 0 then
							local NewWindow = Support.CloneTable(NotificationWindows.SelectionPrompt, true)

							NewWindow.Detail ..= [[
							
<font color="rgb(255, 0, 0)">You cannot save an empty selection.</font>]]

							self:setState({
								NotificationContent = NewWindow
							})

							return
						end

						self.SaveNewParts = true

						if not props.AllowRenaming then
							self:SaveBuild()
						else
							self:setState({
								NotificationContent = "NamePrompt"
							})
						end
					end,
				}
			end,
		},
		NamePrompt = {
			Title = "It's time to give a name to your slot",
			Detail = [[Think about a short name that allows you to find your slot easily. Max. ]] .. props.CharacterLimit .. [[ characters.
			
If the text box is empty, the slot will keep its original name or be given a dummy name when creating a new slot.]],
			HasTextBox = true,
			Buttons = function()
				return {
					["Go Back"] = function()
						self:setState({
							NotificationContent = NotificationWindows.SelectionPrompt
						})
					end,
					Save = function()
						if self.TextBoxRef:getValue() then
							if #self.TextBoxRef:getValue().Text > props.CharacterLimit then
								local NewWindow = NotificationWindows.SelectionPrompt

								NewWindow.Detail ..= [[
							
<font color="rgb(255, 0, 0)">Your name is too long.</font>]]

								self:setState({
									NotificationContent = NewWindow
								})

								return
							end

							self:SaveBuild()
						end
					end,
				}
			end,
		},
		ConfirmPrompt = {
			Title = "Your slot has been successfully saved!",
			Detail = [[It can now be loaded at anytime. Note Fork3X only saves what it can edit, so some things may not save completely.]],
			Buttons = function()
				return {
					OK = function()
						self:setState({
							IsNotificationOpen = false,
							NotificationContent = Roact.None
						})
					end,
				}
			end,
		},
		Error = {
			Title = "Fork3X couldn't save your build",
			Detail = [[Something didn't go as expected. More information can be found in the notifications window.]],
			Buttons = function()
				return {
					OK = function()
						self:setState({
							IsNotificationOpen = false,
							NotificationContent = Roact.None
						})
					end,
				}
			end,
		},
		Erase = {
			Title = [[<font color="rgb(255, 0, 0)">Are you sure you want to erase this slot?</font>]],
			Detail = [[Once this action is done, <font color="rgb(255, 0, 0)">the slot and its data will be gone.</font>
			
This action cannot be reverted, so please be aware that it's unlikely your slot gets restored.]],
			Buttons = function()
				return {
					Cancel = function()
						self:setState({
							IsNotificationOpen = false,
							NotificationContent = Roact.None
						})
					end,
					Erase = function()
						local Success = props.Erase(state.CurrentSlotNumber)

						if Success then
							props.Slots[state.CurrentSlotNumber] = nil
						end

						self:setState({
							IsNotificationOpen = false,
							NotificationContent = Roact.None,

							CurrentSlot = Roact.None,
							CurrentSlotNumber = Roact.None
						})
					end,
				}
			end,
		}
	}

	return NotificationWindows
end

function SaveInterface:init()
	self.Maid = Maid.new()
	--self.PaneSize, self.SetPaneSize = Roact.createBinding(UDim2.new())

	self.ManualRef = Roact.createRef()
	self.ViewportRef = Roact.createRef()
	self.TextBoxRef = Roact.createRef()

	self.NotificationWindows = self:GetNotificationsTable(self.props, self.state)

	self.ShouldUpdateViewport = true

	self:UpdateSaveLoadState()
	self.Maid.TrackSaveLoad = self.props.Core.SaveLoadVisibilityChanged:Connect(function ()
		self:UpdateSaveLoadState()
	end)
end

function SaveInterface:UpdateSaveLoadState()
	self:setState({
		IsSaveLoadOpen = self.props.Core.SaveLoadVisible;
	})
end

function SaveInterface:willUpdate(nextProps, nextState)
	self.NotificationWindows = self:GetNotificationsTable(nextProps, nextState)
	
	local WasVisibilityToggled = self.state.IsSaveLoadOpen ~= nextState.IsSaveLoadOpen

	if not self.state.IsNotificationOpen and not WasVisibilityToggled
		and (nextState.CurrentSlot == nil or self.state.CurrentSlot == nextState.CurrentSlot) then

		self.ShouldUpdateViewport = false
	end
end

function SaveInterface:didUpdate()

	if self.ViewportRef:getValue() and (self.state.IsSaveLoadOpen == false or not self.state.CurrentSlot.Preview) then
		self.ViewportRef:getValue():ClearAllChildren()
	elseif self.ViewportRef:getValue() and self.state.CurrentSlot.Preview and self.ShouldUpdateViewport == true then
		SetupViewportFrame(self.ViewportRef:getValue(), self.state.CurrentSlot.Preview)
	end

	self.ShouldUpdateViewport = true
end

function SaveInterface:didMount()
	local ManualRefValue = self.ManualRef:getValue()

	ListenForManualWindowTrigger(ManualText, BrickColor.new("Lapis").Color, ManualRefValue, 85 - game:GetService("GuiService"):GetGuiInset().Y)
end

function SaveInterface:render()
	local Slots = {}
	
	local function HoverSound()
		self.props.Core.PlaySound("Hover")
	end
	
	local SlotCount = 0
	
	for SlotNumber, Data in self.props.Slots do
		
		SlotCount += 1
		
		Slots["Slot" .. SlotNumber] = new("ImageButton", {
			RBXTAG_SaveSlot = true,
			LayoutOrder = SlotNumber,
			[Roact.Event.MouseEnter] = HoverSound,
			[Roact.Event.Activated] = function(rbx)
				self.props.Core.PlaySound("Press")
				
				if rbx then
					self:setState({
						CurrentSlot = Data,
						CurrentSlotNumber = SlotNumber,
					})
				end
			end,
		}, {
			SlotButton = new("ImageButton"),
			Label = new("TextLabel", {
				Text = Data.Name
			}),
			Size = new("TextLabel", {
				Text = self.props.Core.Options.SizeLimit > 0 and string.format("(%*/%* KiChar)", 
					Support.Round(Data.Size, 3), 
					self.props.Core.Options.SizeLimit)
					or string.format("(%* KiChar)", Support.Round(Data.Size, 3) :: number )
			}),
		})

		--[[
		new(Slot, {
			SlotName = Name;
			LayoutOrder = TheSlot;
			Size = self.props.Sizes[TheSlot];
			MaxSize = self.props.MaxSize > 0 and self.props.MaxSize or nil;
			AllowRenaming = self.props.AllowRenaming;
			SaveFunction = function()
				self.props.Save(TheSlot, Name)
			end;
			LoadFunction = function()
				self.props.Load(TheSlot, Name)
			end;
			RenameFunction = function(NewName)
				self.props.Rename(TheSlot, NewName)
			end;
		});]]
	end
	
	--print(self.props.Slots)

	if Support.CountKeys(Slots) ~= self.props.Core.Options.NumberOfSaveSlots then
		Slots.Add = new("ImageButton", {
			LayoutOrder = self.props.Core.Options.NumberOfSaveSlots + 1,
			[Roact.Event.MouseEnter] = HoverSound,
			[Roact.Event.Activated] = function(rbx)
				self.props.Core.PlaySound("Press")
				
				if rbx then
					self:setState({
						CurrentSlot = Roact.None,
						CurrentSlotNumber = Roact.None,

						IsNotificationOpen = true,
						NotificationContent = "SelectionPrompt"
					})
				end
			end,
		}, {
			SlotButton = new("ImageButton"),
			Label = new("TextLabel"),
			AddIcon = new("TextLabel"),
		})
	end
	
	local NotificationContent = type(self.state.NotificationContent) == "string" and self.NotificationWindows[self.state.NotificationContent] or self.state.NotificationContent
	
	--print(self.state.CurrentSlot and self.state.CurrentSlot.Preview)
	
	local WindowName = self.state.IsNotificationOpen and "Notification" or "Home"
	local WindowContent = self.state.IsNotificationOpen and new("Frame", {}, {
		Title = new("TextLabel", {
			RichText = true,
			Text = NotificationContent.Title
		}),
		FirstDivider = new("Frame", {
			LayoutOrder = 1,
			RBXTAG_Divider = true,
			RBXTAG_STATE_Horizontal = true,
		}),
		MainText = new("TextLabel", {
			LayoutOrder = 2,
			RichText = true,
			Text = NotificationContent.Detail
		}),
		OptionalTextBox = NotificationContent.HasTextBox and new("TextBox", {
			LayoutOrder = 3,
			Size = UDim2.new(0.5, 0, 0, 26),
			Text = "",
			[Roact.Ref] = self.TextBoxRef
		}) or nil,
		SecondDivider = new("Frame", {
			LayoutOrder = 4,
			RBXTAG_Divider = true,
			RBXTAG_STATE_Horizontal = true,
		}),
		Buttons = new("Frame", {
			LayoutOrder = 5,
			Size = UDim2.new(1, 0, 0.1, 0)
		}, self:GetButtonsFromOptions(NotificationContent.Buttons)),
	}) or new("Frame", {}, {
		Divider = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.4, 10, 0, 0),
			RBXTAG_Divider = true,
			RBXTAG_STATE_Vertical = true,
		}),
		Preview = new("Frame", {}, self.state.CurrentSlot and 
			-- ========================================
			-- IF A SLOT IS SELECTED
			-- ========================================
			{
				Buttons = new("Frame", {}, {
					PrimaryLoad = new("TextButton", {
						Text = self.props.Core.Options.PrimaryLoadingText,
						LayoutOrder = 2,
						[Roact.Event.MouseEnter] = HoverSound,
						[Roact.Event.Activated] = function()
							self.props.Core.PlaySound("Press")
							
							self.props.Load(self.state.CurrentSlotNumber, false)
						end,
					}),
					SecondaryLoad = new("TextButton", {
						Text = self.props.Core.Options.SecondaryLoadingText,
						LayoutOrder = 1,
						[Roact.Event.MouseEnter] = HoverSound,
						[Roact.Event.Activated] = function()
							self.props.Core.PlaySound("Press")
							
							self.props.Load(self.state.CurrentSlotNumber, true)
						end,
					}),
					Save = new("TextButton", {
						Text = "Re-save/Rename",
						LayoutOrder = 0,
						[Roact.Event.MouseEnter] = HoverSound,
						[Roact.Event.Activated] = function()
							self.props.Core.PlaySound("Press")
							
							self:setState({
								IsNotificationOpen = true,
								NotificationContent = "SelectionPrompt"
							})
						end,
					}),
					Erase = new("TextButton", {
						Text = [[<font color="rgb(255, 0, 0)"><u>Erase Save</u></font>]],
						LayoutOrder = 3,
						[Roact.Event.MouseEnter] = HoverSound,
						[Roact.Event.Activated] = function()
							self.props.Core.PlaySound("Press")
							
							self:setState({
								IsNotificationOpen = true,
								NotificationContent = "Erase"
							})
						end,
					}),
				}),
				Outdated = self.state.CurrentSlot.Version ~= 6 and new("Frame", {}, {
					Text = new("ScrollingFrame", {
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						CanvasSize = UDim2.new(0, 0, 0, 0),
						Name = "Text",
						ScrollingDirection = Enum.ScrollingDirection.Y,
					}, {
						Explanation = new("TextLabel", {
							Text = self.state.Updated and self.state.Updated[self.state.CurrentSlotNumber] and ConfirmationText or PopUpText,
							TextWrapped = true,
							AutomaticSize = Enum.AutomaticSize.Y,
							RichText = true
						}),
					}),
					Action = new("TextButton", {
						Text = self.state.Updated and self.state.Updated[self.state.CurrentSlotNumber] and "Confirm" or "Update and Test",
						
						[Roact.Event.MouseEnter] = HoverSound,
						[Roact.Event.Activated] = self.state.Updated and self.state.Updated[self.state.CurrentSlotNumber] and function()
							self.props.Core.PlaySound("Press")
							
							local Success, Changes = self.props.Update(self.state.CurrentSlotNumber, true)
							
							if Success then
								local UpdateSlotsTable = self.state.Updated and table.clone(self.state.Updated) or {}
								
								UpdateSlotsTable[self.state.CurrentSlotNumber] = nil
	
								for Name, Value in Changes do
									self.props.Slots[self.state.CurrentSlotNumber][Name] = Value
								end
								
								self:setState({
									Updated = UpdateSlotsTable
								})
							end
						end or 
						function()
							self.props.Core.PlaySound("Press")
							
							local Success, NewSize = self.props.Update(self.state.CurrentSlotNumber, false)

							if Success then
								local UpdateSlotsTable = self.state.Updated and table.clone(self.state.Updated) or {}

								UpdateSlotsTable[self.state.CurrentSlotNumber] = true
								
								self.props.Slots[self.state.CurrentSlotNumber].Size = NewSize
								
								self:setState({
									Updated = UpdateSlotsTable
								})
							end
						end,
					}),
				}),
				Preview = new("Frame", {}, {
					PreviewViewport = new("ViewportFrame", {
						[Roact.Ref] = self.ViewportRef
					}),
					Error = not self.state.CurrentSlot.Preview and new("TextLabel", {
						Text = "This build has no preview available because it is beyond the preview size limit  (" .. self.props.Core.Options.NoPreviewBeyond .. " KiChar)."
					}) or nil
				}),
				SlotName = new("TextLabel", {
					Text = self.state.CurrentSlot.Name
				}),
			} or 
			-- ========================================
			-- IF THE PLAYER DIDN'T SELECT ANY SLOT
			-- ========================================
			{
				Note = new("TextLabel", {
					RichText = true,
					Size = UDim2.new(1, 0, 0, 60),
					Text = "In order to manage a slot, you need to press it in the list on the left to see the available information and actions here.<br /><br />You can learn more about the save/load interface by clicking the ? button next to the Fork3X logo.",
				}, {
					SizeConstraint = new("UISizeConstraint", {
						MaxSize = Vector2.new(math.huge, 60)
					})
				}),
				SlotName = new("TextLabel", {
					Text = "No slot is selected."
				}),
			}),
		Slots = new("Frame", {}, {
			Divider = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0),
				Name = "Divider",
				Position = UDim2.new(0.5, 0, 0, 28),
				RBXTAG_Divider = true,
				RBXTAG_STATE_Horizontal = true,
			}),
			List = new("ScrollingFrame", {
				Active = true,
				ScrollingDirection = Enum.ScrollingDirection.Y,
				CanvasSize = UDim2.new(1, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y
			}, Slots),
			SearchBox = new("Frame", {
				ZIndex = 2
			}, {
				SearchInput = new("TextBox", {
					Text = "",
					ZIndex = 3
				})
			}),
		})
	})


	return new('ScreenGui', {
		DisplayOrder = -1,
		IgnoreGuiInset = true,
		Enabled = self.state.IsSaveLoadOpen
	}, {
		FrameWithEverthingInside = new('Frame', {
			RBXTAG_SavingLoading = true,
		}, {
			Information = new("Frame", {}, {
				TopDivider = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 1),
					Position = UDim2.new(0.5, 0, 1, 0),
					RBXTAG_Divider = true,
					RBXTAG_STATE_Horizontal = true,
				}),
				BottomDivider = new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0),
					Position = UDim2.new(0.5, 0, 0, 0),
					RBXTAG_Divider = true,
					RBXTAG_STATE_Horizontal = true,
				}),
				Signature = new("TextButton", {
					AnchorPoint = Vector2.new(1, 0.5),
					BackgroundTransparency = 1,
					FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.ExtraBold, Enum.FontStyle.Normal),
					Position = UDim2.new(1, -4, 0.5, 0),
					RichText = true,
					Size = UDim2.new(1, 0, 0, 26),
					Text = [[<font weight="800"><u>FORK</u><br/>3X</font>]],
					TextColor3 = Color3.new(1, 1, 1),
					TextSize = 12,
					TextWrapped = true,
					[Roact.Ref] = self.ManualRef
				}, {
					AspectRatio = new("UIAspectRatioConstraint", {
						AspectRatio = 1.24
					}),
					HelpButton = new("TextButton", {
						ZIndex = 10,
						RBXTAG_SignatureButton = true,
					})
				}),
				Text = new("TextLabel", {
					Text = string.format(self.props.TotalSize / math.abs(self.props.MaxSize) * 100 >= 90 
						and [[<font color="rgb(255, 0, 0)">Total Size: %g / %g KiChar (%g%%)</font>	|	Slots: %g/%g]]
						or [[Total Size: %g / %g KiChar (%g%%)	|	Slots: %g/%g]], 
						self.props.TotalSize, 
						math.abs( Support.Round(self.props.MaxSize, 3) :: number ), 
						Support.Round(self.props.TotalSize / math.abs(self.props.MaxSize) * 100, 3),
						SlotCount,
						self.props.Core.Options.NumberOfSaveSlots
					),
				}),
			}),
			Workspace = new("Frame", {}, {
				[WindowName] = WindowContent
			}),
			Header = new("TextButton", {}, {
				CloseButton = new("ImageButton", {
					[Roact.Event.Activated] = function()
						self.props.Core.SaveLoadVisible = false
						self.props.Core.SaveLoadVisibilityChanged:Fire()
					end,
				})
			}),
		},  script.Name, self);
	})
end

return SaveInterface