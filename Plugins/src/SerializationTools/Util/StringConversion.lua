local StringConversion = {}

local B72_CHARACTER_SET = {	
	'b', 'c', 'd', 'f', 'g', 'h', 'j', 'k', 'm', 'p', 'q', 'r', 't', 'v', 'w', 'x', 'y',
	'3', '4', '6', '7', '8', '9', '!', '\"', '#', '$', '%', '&', '\'',	'(', ')', '*', '+', ',', '-', '.', '/',
	':', ';', '<', '=', '>', '?', '@', 'B', 'C', 'D', 'F', 'G', 'H', 'J', 'K', 'M', 'P', 'Q', 'R', 'T', 'V', 'W', 'X', 'Y',
	'[', '\\', ']', '^', '_', '`', '{', '|', '}', '~'
}
local B256_CHARACTER_SET = {}
for i = 0, 255 do
	B256_CHARACTER_SET[i + 1] = string.char(i)
end

local function CreateBaseTable(set)
	local characterKeys = {}
	local characterValues = {}
	for i, v in (set) do
		characterKeys[v] = i - 1;
		characterValues[i - 1] = v;
	end

	local characterCount = #set
	return {characterKeys, characterValues, characterCount}
end

local bases = {
	B256 = CreateBaseTable(B256_CHARACTER_SET),
	B72 = CreateBaseTable(B72_CHARACTER_SET),
}

local function CreateDecoder(specificBase)
	local useBase = specificBase and `B{specificBase}` or `B{StringConversion.Base}`
	local data = bases[useBase]
	local keys, values, count = unpack(data)

	local reader = function(str, cursor, size)
		local total = 0
		for i = cursor, cursor + size - 1 do
			local char = str:sub(cursor, cursor)
			total = total * count + keys[char]
			cursor += 1
		end 
		return total
	end

	return reader
end

local function CreateEncoder(specificBase)
	local useBase = specificBase and `B{specificBase}` or `B{StringConversion.Base}`
	local data = bases[useBase]
	local keys, values, count = unpack(data)
	local getMaxNumber = specificBase and StringConversion[useBase].GetMaxNumber or StringConversion.GetMaxNumber

	local reader = function(number, charCount)
		if math.isinf(number) then
			if math.sign(number) > 0 then
				local max = getMaxNumber(charCount)
				warn(`Converting +Inf to a finite number! Will use maximum representable number ({max}), fix if unintended`)
				number = max
			else
				warn(`Converting -Inf to a finite number! Will use minimum representable number (0), fix if unintended`)
				number = 0
			end
		elseif math.isnan(number) then
			warn("Converting NaN (not a number) to a number! Will use 0, fix if unintended")
			number = 0
		end
		local str = ""
		local iteration = 0
		while number >= 0 and iteration < charCount do
			local value = number % count
			str = values[value] .. str
			number = math.floor(number / count)
			iteration += 1
		end
		return str
	end

	return reader
end

local function CreateMaxNumberFetcher(specificBase)
	local useBase = specificBase and `B{specificBase}` or `B{StringConversion.Base}`
	local data = bases[useBase]
	local keys, values, count = unpack(data)

	return function(charCount)
		return math.pow(count, charCount) - 1
	end
end

local defaultBase = 256
StringConversion.Base = defaultBase
StringConversion.BaseFullName = `B{defaultBase}`
StringConversion.UsedBaseIsOverriden = false
StringConversion.GetMaxNumber = CreateMaxNumberFetcher()
StringConversion.StringToNumber = CreateDecoder()
StringConversion.NumberToString = CreateEncoder()

-- Having a single function for assigning the keys automatically would be nice but it would also break Roblox's intellisense (despite the name it's not very intelligent) so we're doing this instead
StringConversion.B256 = {}
StringConversion.B256.GetMaxNumber = CreateMaxNumberFetcher(256)
StringConversion.B256.StringToNumber = CreateDecoder(256)
StringConversion.B256.NumberToString = CreateEncoder(256)

StringConversion.B72 = {}
StringConversion.B72.GetMaxNumber = CreateMaxNumberFetcher(72)
StringConversion.B72.StringToNumber = CreateDecoder(72)
StringConversion.B72.NumberToString = CreateEncoder(72)

local function RebuildFunctions(setBase, overridenBase) -- Hypotethically instead of recreating the functions we could just move `useBase` inside the returned functions but that would cause a lookup every time the function is ran so I think this is a better approach
	StringConversion.Base = setBase
	StringConversion.BaseFullName = `B{StringConversion.Base}`
	StringConversion.UsedBaseIsOverriden = overridenBase
	StringConversion.GetMaxNumber = CreateMaxNumberFetcher()
	StringConversion.StringToNumber = CreateDecoder()
	StringConversion.NumberToString = CreateEncoder()
end

StringConversion.OverrideBase = function(new)
	if StringConversion.Base == new then return end
	assert(StringConversion[`B{new}`], `B{new} is not a valid base`)
	RebuildFunctions(new, true)
end

StringConversion.ResetBase = function()
	if not StringConversion.UsedBaseIsOverriden then return end
	RebuildFunctions(defaultBase, false)
end

return StringConversion