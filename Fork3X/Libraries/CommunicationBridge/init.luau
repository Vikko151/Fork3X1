local module = {}

local HTTPService = game:GetService("HttpService")
local IsHttpServiceEnabled = true

local Webhook = nil

local DidSucceed, Result = pcall(function ()

	local ReturnedAsset = HTTPService:RequestAsync({
		Url = 'https://google.com',
	}) 


	return ReturnedAsset.Success
end)

-- Determine whether HttpService is enabled based on whether request succeeded
if (not DidSucceed) and Result:match('Http requests are not enabled') then
	IsHttpServiceEnabled = false
end

function module.SetWebhook(WebhookURL)
	if IsHttpServiceEnabled == false then return end
	Webhook = WebhookURL
end

function module.Check()
	if IsHttpServiceEnabled == false or Webhook == nil  then return end
	if Webhook == nil then
		error("ERROR | No webhook specified.")
	else
		warn("SYSTEM | Sent a message to channel. If no message is sent, check your URL or use a proxy service.")
		HTTPService:PostAsync(Webhook,
			HTTPService:JSONEncode({
				content = "If you see this message, this means that your webhook is configured properly."
			}))	
	end
end

function module.Send(Message)
	if IsHttpServiceEnabled == false or Webhook == nil then return end
	if Webhook == nil then
		error("ERROR | No webhook specified.")
	end
	HTTPService:PostAsync(Webhook,
		HTTPService:JSONEncode({
			content = Message
		}))
end

function module.Embed(Message, EmbedTitle, EmbedDescription, EmbedHexColorCode)
	if IsHttpServiceEnabled == false or Webhook == nil then return end
	if Webhook == nil then
		error("ERROR | No webhook specified.")
		return
	end
	if Message == nil then
		error('ERROR | Message text cannot be nil. Set Message text as "" if you don\'t want to include a message')
	end
	if EmbedTitle == nil or EmbedTitle == "" then
		EmbedTitle = "Game ID = "..game.PlaceId
	end
	if EmbedDescription == nil or EmbedDescription == "" then
		EmbedDescription = "Unspecified"
	end
	if EmbedHexColorCode == nil or EmbedHexColorCode == "" then
		EmbedHexColorCode = tonumber(0xffffff)
	end
	
	local data = HTTPService:JSONEncode(
		{
			["content"] = Message,
			["embeds"] = {{
				["title"] = tostring(EmbedTitle),
				["description"] = tostring(EmbedDescription),
				["type"] = "rich",
				["color"] = EmbedHexColorCode,
			}}
		})
	
	HTTPService:PostAsync(Webhook, data)
end

return module
