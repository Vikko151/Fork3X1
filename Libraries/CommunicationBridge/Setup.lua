local Tool = script:FindFirstAncestorWhichIsA("Tool")
local Module = require(script.Parent)

-- You imperatively mustn't leak this to anybody you don't trust.
-- Using HttpService:GetSecret() to fetch the link is excellent practice as there is no way for someone to get the link.
local Webhook = nil

Module.SetWebhook(Webhook)
