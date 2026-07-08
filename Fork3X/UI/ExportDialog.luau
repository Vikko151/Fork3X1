local Root = script.Parent.Parent
local Vendor = Root:WaitForChild('Vendor')

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local new = function(Type, props, ...)
	props["RBXTAG_Native"] = true

	return Roact.createElement(Type, props, ...)
end


--[[
local function ExportDialog(props)
	return new('ScreenGui', {}, {
		Dialog = new('Frame', {
			AnchorPoint = Vector2.new(0.5, 0.5);
			BackgroundColor3 = Color3.new(0, 0, 0);
			BackgroundTransparency = 0.6;
			BorderSizePixel = 0;
			Position = UDim2.new(0.5, 0, 0.5, 0);
			Size = UDim2.new(0, 200, 0, 0);
		}, {
			Corners = new('UICorner', {
				CornerRadius = UDim.new(0, 4);
			});
			CloseButton = new('TextButton', {
				AnchorPoint = Vector2.new(0.5, 1);
				BackgroundColor3 = Color3.new(1, 1, 1);
				BackgroundTransparency = 0.9;
				Modal = true;
				Position = UDim2.new(0.5, 0, 1, -10);
				Size = UDim2.new(0.5, 0, 0, 23);
				Text = 'Ok';
				FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				--Font = Enum.Font.GothamSemibold;
				TextColor3 = Color3.fromRGB(255, 255, 255);
				TextSize = 11;
				[Roact.Event.Activated] = function (rbx)
					props.OnDismiss()
				end;
			}, {
				Corners = new('UICorner', {
					CornerRadius = UDim.new(0, 4);
				});
				Stroke = new('UIStroke', {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
					Transparency = 0.9;
					Thickness = 2;
					Color = Color3.new(0, 0, 0);
				});
			});
			Title = new('TextLabel', {
				BackgroundTransparency = 1;
				Size = UDim2.new(0, 200, 0, 30);
				Position = UDim2.fromOffset(0, 5);
				FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				TextScaled = true,
				Text = "Export";
				TextColor3 = Color3.fromRGB(255, 255, 255);
			});
			LeftColorBar = new(ColorBar, {
				AnchorPoint = Vector2.new(0, 0.5);
				Position = UDim2.new(0, 0, 0.5, 0);
				Size = UDim2.new(0, 4, 1, 0);
			});
			Text = new('TextLabel', {
				BackgroundTransparency = 1;
				Size = UDim2.new(1, 0, 1, -23);
				FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
				RichText = true;
				Text = props.Text;
				TextColor3 = Color3.fromRGB(255, 255, 255);
				TextSize = 14;
				TextWrapped = true;
				[Roact.Change.TextBounds] = function (rbx)
					rbx.Parent.Size = UDim2.new(0, 200, 0, rbx.TextBounds.Y + 23 + 26 + 40)
				end;
			}, {
				Padding = new('UIPadding', {
					PaddingLeft = UDim.new(0, 10);
					PaddingRight = UDim.new(0, 10);
				});
			});
		});
	})
end]]

local function ExportDialog(props)
	local Dialog = new('ScreenGui', {}, {
		Dialog = new('Frame', {
			AnchorPoint = Vector2.new(0.5, 0.5);
			--    BackgroundColor3 = Color3.new(0, 0, 0);
			--    BackgroundTransparency = 0.6;
			--    BorderSizePixel = 0;
			Position = UDim2.new(0.5, 0, 0.5, 0);
			Size = UDim2.new(0, 200, 0, 0);
			RBXTAG_Window = true;
		}, {
			--[[
            Corners = new('UICorner', {
                CornerRadius = UDim.new(0, 4);
            });]]
			CloseButton = new('TextButton', {
				AnchorPoint = Vector2.new(0.5, 1);
				--    BackgroundColor3 = Color3.new(1, 1, 1);
				--    BackgroundTransparency = 0.9;
				Modal = true;
				Position = UDim2.new(0.5, 0, 1, -10);
				Size = UDim2.new(0.5, 0, 0, 23);
				Text = 'Ok';
				--	FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				--Font = Enum.Font.GothamSemibold;
				--    TextColor3 = Color3.fromRGB(255, 255, 255);
				--    TextSize = 11;
				[Roact.Event.Activated] = function (rbx)
					props.OnDismiss()
				end;
			}, {
				--[[
                Corners = new('UICorner', {
                    CornerRadius = UDim.new(0, 4);
				});
				Stroke = new('UIStroke', {
					ApplyStrokeMode = Enum.ApplyStrokeMode.Border;
					Transparency = 0.9;
					Thickness = 2;
					Color = Color3.new(0, 0, 0);
				});]]
			});
			Title = new('TextLabel', {
				--	BackgroundTransparency = 1;
				Size = UDim2.new(1, 0, 0, 30);
				Position = UDim2.fromOffset(0, 5);
				--	FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				--	TextScaled = true,
				Text = "Export";
				--	TextColor3 = Color3.fromRGB(255, 255, 255);
			});
			--[[
			LeftColorBar = new(ColorBar, {
				AnchorPoint = Vector2.new(0, 0.5);
				Position = UDim2.new(0, 0, 0.5, 0);
				Size = UDim2.new(0, 4, 1, 0);
			});]]
			Text = new('TextLabel', {
				--    BackgroundTransparency = 1;
				Size = UDim2.new(1, 0, 1, -23);
				--	FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Medium, Enum.FontStyle.Normal),
				RichText = true;
				Text = props.Text;
				--    TextColor3 = Color3.fromRGB(255, 255, 255);
				--    TextSize = 14;
				--    TextWrapped = true;
				[Roact.Change.TextBounds] = function (rbx)
					rbx.Parent.Size = UDim2.new(0, 200, 0, rbx.TextBounds.Y + 23 + 26 + 40)
				end;
			}, {
				--[[
                Padding = new('UIPadding', {
                    PaddingLeft = UDim.new(0, 10);
                    PaddingRight = UDim.new(0, 10);
                });]]
			});
		},  script.Name, {props = props, state = {}});
	})
	
	return Dialog
end

return ExportDialog