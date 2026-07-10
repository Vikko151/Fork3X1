--[[
==============================
NOTE ABOUT FORK3X ADD-ONS
==============================

At the time being, a Fork3X addon is just a module that modifies the options module in order to enhance people's experience

They're meant for NOTHING ELSE. Any setting in Advanced Setup must only return a new value.

MAKE SURE the add-on you're currently using has the Sandboxed property set to "true" and solely has the "Basic" capability on. If this is not the case, it may be a virus!
]]

local Addon = {
	-- Put the name of the settings
	-- You mustn't put them in their categories, else the addon won't work!

	-- This erases the given settings
	Erase = {},

	-- You can use this to assemble settings together
	-- The function gives the current  
	AdvancedSetup = {
		CustomSyncModuleFunctions = function(OriginalValue, IsConflictPossible)
			-- Create the new actions we want to add
			local ExtraActions = {
				['ExtractMeshFromAsset'] = function (SyncModule, AssetId)
					-- Returns the first found mesh in the given asset
					
					-- Get RunService to determine if the action must be done on the server side
					local RunService = game:GetService("RunService")
					
					-- Offload action to server-side if API is running locally
					if RunService:IsClient() and not RunService:IsStudio() then
						return SyncModule.SyncAPI.ServerEndpoint:InvokeServer('ExtractMeshFromAsset', AssetId);
					end;
					
					local function CheckMeshBlacklist(ID)
						local Success, MarketplaceInfo = pcall( 
							game:GetService("MarketplaceService").GetProductInfoAsync,
							game:GetService("MarketplaceService"),
							ID
						)
						
						print(MarketplaceInfo)

						if Success then
							local AssetName = MarketplaceInfo.Name
							local IsPrivate = not MarketplaceInfo.IsPublicDomain
							local IsRoblox = MarketplaceInfo.Creator.CreatorTargetId == 1

							return not (AssetName == "RenderMesh" and IsPrivate == true and not IsRoblox)
						end
						
						return true
					end

					--[[
					if CheckMeshBlacklist(AssetId) == false then
						return {
							success = true,
							meshID = 0
						}
					end]]
					
					local AssetService = game:GetService("AssetService")
					local HttpService = game:GetService("HttpService")
					
					-- Ensure valid asset ID is given
					assert(type(AssetId) == 'number', 'Invalid asset ID');

					local AssetIdWhitelist = {
						4,
						8,
						19,
						40,
						41,
						42,
						43,
						44,
						45,
						46,
						47
					}
					

					-- Track how long it takes to generate the mesh
					-- Most crash meshes take a lot of time to load, hence why this method is efficient
					local FetchingBeginsAt = os.clock()
					
					-- TAKE 1: Attempt to insert the asset.
					local Success, Result = pcall(function()
						local AssetInfo = game:GetService("MarketplaceService"):GetProductInfoAsync(AssetId, Enum.InfoType.Asset)

						if table.find(AssetIdWhitelist, AssetInfo.AssetTypeId) then
							local Mesh

							-- If it's only the mesh, use CreateMeshPartAsync to extract the scale
							if AssetInfo.AssetTypeId == 4 then
								Mesh = AssetService:CreateMeshPartAsync(Content.fromAssetId(AssetId))
							else

								local LoadedAsset = SyncModule.Plugin 
									and game:GetObjects("rbxassetid://" .. AssetId) 
									or AssetService:LoadAssetAsync(AssetId)

								-- Look for a mesh (if it's an accessory)
								Mesh = SyncModule.Support.GetDescendantsWhichAreA(LoadedAsset, "MeshPart")[1] or SyncModule.Support.GetDescendantsWhichAreA(LoadedAsset, "SpecialMesh")[1]
							end
							
							assert(Mesh, "The asset has no mesh.")

							return Mesh:IsA("SpecialMesh") and {
								meshID = Mesh.MeshId:lower():match("%d+"),
								textureID = Mesh.TextureId ~= "" and Mesh.TextureId:lower():match("%d+") or nil,
								tint = Mesh.VertexColor,
								scale = Mesh.Parent:IsA("BasePart") and Mesh.Parent.Size / Mesh.Scale or Mesh.Scale,
								success = true
							} or {
								meshID = Mesh.MeshId:lower():match("%d+"),
								textureID = Mesh.TextureID ~= "" and Mesh.TextureID:lower():match("%d+") or nil,
								tint = vector.one,
								scale = Mesh.Size,
								success = true
							}
						end

						error(tostring(AssetInfo.AssetTypeId) .. " isn't a mesh or an accessory.")
					end)
					
					if not Success and Result:lower():find("Mesh extents size too large")
						or Success and os.clock() - FetchingBeginsAt >= 6 then
						
						return {
							success = true,
							meshID = 0
						}
					end

					-- TAKE 2: Rely on the API
					if not Success and SyncModule.IsHttpServiceEnabled then

						local ReturnedAsset = HttpService:RequestAsync({
							Url = 'http://f3xteam.com/bt/getFirstMeshData/' .. AssetId,
						})

						local FinalResult = HttpService:JSONDecode(ReturnedAsset.Body)

						return FinalResult --HttpService:JSONDecode(ReturnedAsset.Body)
					else
						return Result
					end

					-- Return parsed response from API
					--	return HttpService:JSONDecode(ReturnedAsset.Body) or nil

				end;
			}
			
			-- Merge both options together
			for Name, Value in ExtraActions do
				if OriginalValue[Name] and IsConflictPossible then
					warn("[FORK3X - MESHPARTTODATA]: The action `" .. Name .. "` has already been set by the default Options module or another addon. To avoid conflicts, the addon won't load.\n\nIn order to fix this, you must remove this action in the default Options, or set the Priority attribute to a higher value.")
					return OriginalValue
				end
				
				OriginalValue[Name] = Value
			end

			-- Return the new value
			return OriginalValue
		end,
	},
	
	VariableSettings = {}
}

return Addon
