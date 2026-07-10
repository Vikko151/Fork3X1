local Root = script.Parent.Parent
local Vendor = Root:WaitForChild('Vendor')
local Sounds = Root:WaitForChild("Sounds")
local Support = require(Root:WaitForChild("Libraries"):WaitForChild("SupportLibrary"))

-- Libraries
local Roact = require(Vendor:WaitForChild('Roact'))
local new = function(Type, props, ...)
	props["RBXTAG_Native"] = true

	return Roact.createElement(Type, props, ...)
end
--return ExportDialog

local function GroupDialog(props)
	return new('ScreenGui', {}, {
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
			FirstButton = new('TextButton', {
				AnchorPoint = Vector2.new(0, 1);
				--	BackgroundColor3 = Color3.new(1, 1, 1);
				--	BackgroundTransparency = 0.9;
				Modal = true;
				Position = UDim2.new(0.05, 0, 1, -10);
				Size = UDim2.new(0.4, 0, 0, 23);
				Text = props.Option1;
				--	FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				--Font = Enum.Font.GothamSemibold;
				--	TextColor3 = Color3.fromRGB(255, 255, 255);
				--	TextSize = 11;
				[Roact.Event.Activated] = function (rbx)
					props.Function1()
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
			SecondButton = new('TextButton', {
				AnchorPoint = Vector2.new(1, 1);
				--	BackgroundColor3 = Color3.new(1, 1, 1);
				--	BackgroundTransparency = 0.9;
				Modal = true;
				Position = UDim2.new(0.95, 0, 1, -10);
				Size = UDim2.new(0.4, 0, 0, 23);
				Text = props.Option2;
				--	FontFace = Font.new("rbxassetid://12187365977", Enum.FontWeight.Bold, Enum.FontStyle.Normal),
				--Font = Enum.Font.GothamSemibold;
				--	TextColor3 = Color3.fromRGB(255, 255, 255);
				--	TextSize = 11;
				[Roact.Event.Activated] = function (rbx)
					props.Function2()
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
				Text = "Arrangement";
				--	TextColor3 = Color3.fromRGB(255, 255, 255);
			});
			--[[
			LeftColorBar = new(ColorBar, {
				AnchorPoint = Vector2.new(0, 0.5);
				Position = UDim2.new(0, 0, 0.5, 0);
				Size = UDim2.new(0, 4, 1, 0);
			});]]
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
				[Roact.Ref] = function(rbx)
					if rbx then

						coroutine.wrap(function()
							for i = 1, 2 do
								task.wait(0)
								rbx.Parent.Size = UDim2.new(0, 200, 0, rbx.TextBounds.Y + 23 + 26 + 40)
							end
						end)()
--[[
						local Function = Support.ScheduleRecurringTask(function()
							rbx.Parent.Size = UDim2.new(0, 200, 0, rbx.TextBounds.Y + 23 + 26 + 40)
							
							
							local TextService = game:GetService("TextService")
							local TextSizeParams = Instance.new("GetTextBoundsParams")

							TextSizeParams.Size = rbx:GetStyled("TextSize")
							TextSizeParams.Text = rbx.Text
							TextSizeParams.Font = rbx:GetStyled("FontFace")
							TextSizeParams.Width = rbx.Parent.AbsoluteSize.X - 20
							TextSizeParams.RichText = true
							
							local Size = TextService:GetTextBoundsAsync(TextSizeParams)
							TextService:GetText
							rbx.Parent.Size = UDim2.new(0, 200, 0, Size.Y + 23 + 26 + 40)
						end, 1)
						
						rbx.Destroying:Connect(function()
							Function:Stop()
						end) ]]
					end
				end,
				--[[
				[Roact.Change.TextBounds] = function (rbx)
					rbx.Parent.Size = UDim2.new(0, 200, 0, rbx.TextBounds.Y + 23 + 26 + 40)
				end;]]
			}, {
				--[[
                Padding = new('UIPadding', {
                    PaddingLeft = UDim.new(0, 10);
                    PaddingRight = UDim.new(0, 10);
                });]]
			});
		},  script.Name, {props = props, state = {}});
	})
end

return GroupDialog