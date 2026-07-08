local Root = script.Parent.Parent
local Libraries = Root:WaitForChild('Libraries')
local Vendor = Root:WaitForChild('Vendor')
local Support = require(Libraries.SupportLibrary)
local Signal = require(Libraries.Signal)
local Maid = require(Libraries.Maid)

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local fastSpawn = require(Libraries:WaitForChild('fastSpawn'))

-- Roact
local new = Roact.createElement
local NotificationDialog = require(script:WaitForChild('NotificationDialog'))

-- Create component
local Notifications = Roact.PureComponent:extend(script.Name)

function Notifications:init()
	self.Active = true
    self:setState({
       -- ShouldWarnAboutHttpService = false;
		ShouldWarnAboutUpdate = false;
	})
	
	--[[
    fastSpawn(function ()
        local Core = self.props.Core
        local IsHttpServiceDisabled = (Core.Mode == 'Tool') and
            not Core.SyncAPI:Invoke('IsHttpServiceEnabled')
		if self.Active and Core.Options.ShowHttpRequestsWarning == true and Core.Options.EnableAPIs ~= true then
            self:setState({
                ShouldWarnAboutHttpService = IsHttpServiceDisabled;
            })
        end
	end)]]
	fastSpawn(function ()
		local IsOutdated, Version, UpdateText = self.props.Core.IsVersionOutdated(Root.Version.Value)
		if self.Active and self.props.Core.Options.ShowUpdateWarning == true then
			self:setState({
				ShouldWarnAboutUpdate = not _G.FORK3X_ReadUpdate and IsOutdated or false;
				UpdateText = UpdateText and ("\n\nHere are some of the main new features in v<b>" .. Version .. "</b>:\n\n" .. UpdateText) or nil;
			})
		end
	end)
	fastSpawn(function ()
		local Core = self.props.Core
		local IsBeyondLimit = (Core.Mode == 'Tool') and Core.Options.SizeLimit < -4096 and true or false
		if self.Active then
			self:setState({
				ShouldWarnAboutDataStores = IsBeyondLimit;
			})
		end
	end)
end


function Notifications:willUnmount()
    self.Active = false
end

function Notifications:render()
	local Children = {
		Layout = new('UIListLayout', {
			Padding = UDim.new(0, 10);
			FillDirection = Enum.FillDirection.Vertical;
			HorizontalAlignment = Enum.HorizontalAlignment.Left;
			VerticalAlignment = Enum.VerticalAlignment.Center;
			SortOrder = Enum.SortOrder.LayoutOrder;
		});
		HTTPEnabledNotification = (self.state.ShouldWarnAboutHttpService or nil) and new(NotificationDialog, {
			LayoutOrder = 0;
			ThemeColor = Color3.fromRGB(255, 0, 4);
			NoticeText = 'HTTP requests must be <b>enabled</b> for some features of Building Tools to work, including exporting.';
			DetailText = 'Own this place? Edit it in Studio, and toggle on\nHOME > <b>Game Settings</b> > Security > <b>Allow HTTP Requests</b> :-)';
			OnDismiss = function ()
				self:setState({
					ShouldWarnAboutHttpService = false;
				})
			end;
		});
		DataStoreNotification = (self.state.ShouldWarnAboutDataStores or nil) and new(NotificationDialog, {
			LayoutOrder = 0;
			ThemeColor = Color3.fromRGB(255, 0, 4);
			NoticeText = "The current save/load size limit can possibly go beyond 4 MB. This means that builds that go beyond this limit might not get saved completely.";
			DetailText = 'Own this place? Set Options.SizeLimit above -4096 (-4095, -4094) to prevent any data wipe. :-)';
			OnDismiss = function ()
				self:setState({
					ShouldWarnAboutDataStores = false;
				})
			end;
		});
		BetaNotification = (self.state.ShouldWarnAboutBeta or nil) and new(NotificationDialog, {
			LayoutOrder = 1;
			ThemeColor = Color3.fromRGB(255, 0, 150);
			NoticeText = '<b>This version of Fork3X is a public beta!</b> The main ideas are here, but the tools are extremely buggy. Please report any bug you encounter to the creator of Fork3X.';
			DetailText = (
				(self.props.Core.Mode == 'Plugin') and
					'To update plugins, go to\n<b>PLUGINS</b> > <b>Manage Plugins</b> :-)' or
					"Own this place? Simply <b>reinsert</b> the latest Building Tools model from the GitHub/test place in your game. :-)"
			) .. self.state.UpdateText;
			TextXAlignment = Enum.TextXAlignment.Left;
			OnDismiss = function ()
				self:setState({
					ShouldWarnAboutBeta = false;
				})
				_G.FORK3X_BetaWarning = true
			end;
		});
		UpdateNotification = (self.state.ShouldWarnAboutUpdate or nil) and new(NotificationDialog, {
			LayoutOrder = 1;
			ThemeColor = Color3.fromRGB(255, 170, 0);
			NoticeText = '<b>A new version of Fork3X is out!</b> To know some of the main changes and how to update, press <i>"WHAT CAN I DO?"</i>';
			DetailText = (
				(self.props.Core.Mode == 'Plugin') and
				'To update plugins, go to\n<b>PLUGINS</b> > <b>Manage Plugins</b> :-)' or
				"Own this place? Simply <b>reinsert</b> the latest Building Tools model from the GitHub/test place in your game. :-)"
			) .. self.state.UpdateText;
			TextXAlignment = Enum.TextXAlignment.Left;
			OnDismiss = function ()
				self:setState({
					ShouldWarnAboutUpdate = false;
				})
				_G.FORK3X_ReadUpdate = true
			end;
		});
	}

	-- Build buttons for each tool
	for Index, Notification in self.props.Notifications do
		Children[tostring(Index)] = new(NotificationDialog, {
			LayoutOrder = 2 + Index;
			ThemeColor = Notification.ThemeColor;
			NoticeText = Notification.NoticeText;
			DetailText = Notification.DetailText;
			TextXAlignment = Notification.TextXAlignment;
			OnDismiss = function (rbx)
				rbx:Destroy()
				Children[tostring(Index)] = nil
				self.props.Notifications[Index] = nil
			end;
		})
	end
	
    return new('ScreenGui', {}, {
        Container = new('Frame', {
            AnchorPoint = Vector2.new(0.5, 0.5);
            BackgroundTransparency = 1;
            Position = UDim2.new(0.5, 0, 0.5, 0);
			Size = UDim2.new(0, 300, 1, 0);
			[Roact.Children] = Children;
        });
    })
end

return Notifications