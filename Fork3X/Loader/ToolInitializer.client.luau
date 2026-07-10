if not plugin then
	require(script.Parent)
	script.Parent.Parent:WaitForChild("Options").Destroying:Connect(function()
		script.Parent.Parent:Destroy()
	end)
end