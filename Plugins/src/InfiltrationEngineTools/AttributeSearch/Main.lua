local ScriptEditorService = game:GetService("ScriptEditorService")

local Actor = require(script.Parent.Parent.Util.Actor)
local Create = Actor.Create
local State = Actor.State
local Derived = Actor.Derived
local DerivedTable = Actor.DerivedTable
local OnChange = Actor.OnChange
local Watch = Actor.Watch

local module = {}

local ROW_HEIGHT = 20

local function trim(str)
	return str:match("^%s*(.-)%s*$")
end

local SearchText = State("")
local SearchResults = Derived(function(text)
	if #text < 3 or not workspace:FindFirstChild("DebugMission") then
		return {}
	end

	local results = {}
	local missionModuleSource = ScriptEditorService:GetEditorSource(workspace.DebugMission.MissionSetup)

	local function searchSource(prefix, source)
		local stack = prefix and {prefix} or {}

		for line, content in ipairs(string.split(source, "\n")) do
			if content == "" then
				continue
			end

			local trimmedContent = trim(content)
			local openKey = content:match("^(.-)%s*=%s*{$")
			if openKey then
				table.insert(stack, trim(openKey))
				continue
			end

			if trimmedContent:match("^}") then
				table.remove(stack)
				continue
			end

			local key = trimmedContent:match("^(.-)%s*=")
			if key and trimmedContent:lower():match(text) then
				key = trim(key)

				local fullPath = table.concat(stack, ".")
				local entry = fullPath ~= "" and (`{fullPath}.{key}`) or key
				table.insert(results, {
					Instance = workspace.DebugMission.MissionSetup,
					Key = entry,
					Content = trimmedContent,
					RawContent = content,
					Line = line,
				})
			end
		end
	end

	searchSource(nil, missionModuleSource)
	for _, instance in workspace.DebugMission:GetDescendants() do
		for k, v in instance:GetAttributes() do
			if v ~= "" and (k:lower() == text or (typeof(v) == "string" and v:lower():match(text))) then
				table.insert(results, {
					Instance = instance,
					Key = k,
					Content = tostring(v),
				})
			end
		end
	end

	if text:lower() == "powerarea" then
		local areaList = {}
		for index, data in results do
			local area = data.Instance:GetAttribute("PowerArea")
			if not area then
				continue
			end
			areaList[area] = (areaList[area] or 0) + 1
		end
		if next(areaList) then
			print("--- POWER AREAS ---")
			for k, v in areaList do
				print(`{k}: {v}`)
			end
			print("-------------------")
		end
	end

	return results
end, SearchText)

local function StringToColor(name)
	if name == "Default" then
		return Color3.new(0, 0, 0)
	end

	local h = 5 ^ 7
	local n = 0
	for i = 1, #name do
		n = (n * 257 + string.byte(name, i, i)) % h
	end
	local color = Color3.fromHSV((n % 1000) / 1000, 0.3, 1)
	return color
end

module.PropMarkers = {}
local function ClearPropMarkers()
	for _, p in module.PropMarkers do
		p:Destroy()
	end
	module.PropMarkers = {}
end
local function UpdatePropMarkers(list)
	ClearPropMarkers()

	for _, entry in ipairs(list) do
		local instance = entry.Instance

		if instance and instance:IsA("BasePart") then
			table.insert(
				module.PropMarkers,
				Create("BillboardGui", {
					Archivable = false,
					Parent = game:GetService("CoreGui"),
					Adornee = instance,
					Size = UDim2.new(0, 20, 0, 20),
					AlwaysOnTop = true,
				}, {
					Create("Frame", {
						Size = UDim2.new(0, 20, 0, 20),
						BorderSizePixel = 0,
						BackgroundColor3 = StringToColor(entry.Content or ""),
					}, {
						Create("UICorner", {
							CornerRadius = UDim.new(0.5, 0),
						}),
					}),
				})
			)
		end
	end
end
Watch(UpdatePropMarkers, SearchResults)

local function Clean(str)
	return string.gsub(string.gsub(str, `\n`, ``), `	`, ``)
end

local function GetFirstNonTabIndex(str)
	local i = string.find(str, "%S")
	return i
end

local previousListedEntry
local function ListEntry(index, entry)
	local instance = entry.Instance
	
	local layoutOrder = 0
	if instance.Name ~= "MissionSetup" then
		layoutOrder = 1000 * string.byte(instance.Name:lower(), 1, 1) + string.byte(instance.Name:lower(), 2, 2)
	end

	local button = Create("TextButton", {
		Size = UDim2.new(0, 400, 0, ROW_HEIGHT),
		Text = "",
		BackgroundTransparency = 0.3,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		LayoutOrder = layoutOrder,

		Activated = function()
			game.Selection:Set({ instance })

			if entry.Line then
				ScriptEditorService:OpenScriptDocumentAsync(instance, {
					HighlightRange = {
						Start = {Line = entry.Line, Character = GetFirstNonTabIndex(entry.RawContent)},
						End = {Line = entry.Line, Character = 999},
					}
				})
			end
		end,
	}, {
		Create("TextLabel", {
			Size = UDim2.new(0, 200, 0, ROW_HEIGHT),
			Position = UDim2.new(0, 0, 0, 0),
			Text = if previousListedEntry and previousListedEntry.Instance == instance then `` else instance.Name,
			BackgroundTransparency = 1,
			TextColor3 = Color3.new(1, 1, 1),
		}),
		Create("TextLabel", {
			Size = UDim2.new(0, 200, 0, ROW_HEIGHT),
			Position = UDim2.new(0, 200, 0, 0),
			Text = Clean(entry.Key),
			TextXAlignment = Enum.TextXAlignment.Right,
			BackgroundTransparency = 1,
			TextColor3 = Color3.new(1, 1, 1),
		}, {
			Create("UIPadding", {
				PaddingRight = UDim.new(0, 10),
			})
		}),
		Create("TextLabel", {
			Size = UDim2.new(0, 0, 0, ROW_HEIGHT),
			Position = UDim2.new(0, 400, 0, 0),
			Text = Clean(entry.Content),
			TextXAlignment = Enum.TextXAlignment.Left,
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundTransparency = 0.6,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
		}, {
			Create("UIPadding", {
				PaddingRight = UDim.new(0, 10),
				PaddingLeft = UDim.new(0, 10),
			}),
		})
	})
	
	previousListedEntry = entry
	return button
end

local lastTextChange = 0
function module.Init(mouse: PluginMouse)
	if module.Active then
		return
	end
	module.Active = true
	UpdatePropMarkers(SearchResults._Value)

	local searchBox
	searchBox = Create("TextBox", {
		Size = UDim2.new(0, 200, 0, ROW_HEIGHT),
		PlaceholderText = "Search Attribute",
		BackgroundTransparency = 0.5,
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(),
		PlaceholderColor3 = Color3.new(0.8, 0.8, 0.8),
		TextColor3 = Color3.new(1, 1, 1),
		Text = SearchText._Value,
		ClearTextOnFocus = false,
		[OnChange("Text")] = function()
			lastTextChange += 1
			local clock = lastTextChange
			task.delay(1, function()
				if clock == lastTextChange then
					SearchText:set(searchBox.Text:lower())
				end
			end)
		end,
		FocusLost = function()
			SearchText:set(searchBox.Text)
		end,
	})

	module.UI = Create("ScreenGui", {
		Parent = game.CoreGui,
		Archivable = false,
	}, {
		Create("Frame", {
			Size = UDim2.new(1, -100, 1, -100),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
		}, {
			searchBox,
			Create("ScrollingFrame", {
				Size = UDim2.new(1, 0, 1, -ROW_HEIGHT * 1.5),
				Position = UDim2.new(0, 0, 1, 0),
				AnchorPoint = Vector2.new(0, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.new(0, 0, 0, 0),
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
			}, {
				Create("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
				DerivedTable(ListEntry, SearchResults),
			}),
		}),
	})
end

function module.Clean()
	module.Active = false
	ClearPropMarkers()
	if module.UI then
		module.UI:Destroy()
		module.UI = nil
	end
end

return module
