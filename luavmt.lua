local tostring, tonumber, find, type, pairs, ipairs = tostring, tonumber, string.find, type, pairs, ipairs
local util_TableToJSON, file_Read, Vector = util.TableToJSON, file.Read, Vector
--[[Lua Valve key value structure standalone parser for Garry's mod/ UnkN ©2022]]
module("luavmt", package.seeall)

local numchars = {["."] = true, ["-"] = true}
local strpat = "[%w%d%$<%?\\/_%-]"
for i = 0, 9 do
	numchars[tostring(i)] = true
end
local function readNumber(str, offset)
	local len = str:len()
	local found = false
	for i = offset, len do
		local char = str[i]
		if numchars[char] then
			if not found then
				found = i
			end
		elseif found then
			return tonumber(str:sub(found, i - 1)), i
		end
	end
	if found then
		return tonumber(str:sub(found, len)), len
	end
	return 0, len
end
function readKey(str, offset, len)
	local found = false
	local tp = "nil"
	for i = offset or 1, len do
		local char = str[i]
		if tp == "nil" then
			if numchars[char] then
				tp = "number"
				found = i
			elseif char == "\"" then
				tp = "stringquotes"
				found = i
			elseif find(char, strpat) then
				if char == "/" then
					local nc = str[i + 1]
					if nc == "/" then
						tp = "commentline"
						found = i + 2
					elseif nc == "*" then
						tp = "commentlines"
						found = i + 2
					end
				else
					tp = "string"
					found = i
				end
			elseif char == "[" then
				tp = "vector"
				found = i
			elseif char == "{" then
				tp = "table"
				return {tp, readKeyValues(str, i + 1, len)}
			--[[elseif char == "/" then
				if str[i + 1] == "/" then
					tp = "comment"
					found = i + 2
				end]]
			end
		elseif tp == "number" and not numchars[char] then
			if find(char, strpat) then
				tp = "string"
			elseif found then
				return {tp, tonumber(str:sub(found, i - 1)), i + 1}
			end
		elseif tp == "stringquotes" then
			if char == "\"" then
				if found then
					str = str:sub(found + 1, i - 1)
					local num = tonumber(str)
					if num then
						return {"number", num, i + 1}
					else
						return {tp, str, i + 1}
					end
				end
			elseif char == "[" then
				tp = "vectorquoted"
				found = i
			end
		elseif tp == "string" then
			if found and not find(char, strpat) then
				str = str:sub(found, i - 1)
				local num = tonumber(str)
				if num then
					return {"number", num, i + 1}
				else
					return {tp, str, i + 1}
				end
			end
		elseif (tp == "vector" and char == "]") or (tp == "vectorquoted" and char == "\"") then
			if found then
				local vec = str:sub(found + 1, i - 1)
				local x, y, z = readNumber(vec, 1)
				local ln = vec:len()
				if y < ln then
					y, z = readNumber(vec, y)
					if z < ln then
						z = readNumber(vec, z)
					else
						z = 0
					end
				else
					y = 0
				end
				return {tp, Vector(x, y, z), i + 2}
			end
		elseif tp == "commentline" and char == "\n" then
			tp = "nil"
			found = i + 1
		elseif tp == "commentlines" and char == "*" and str[i + 1] == "/" then
			tp = "nil"
			found = i + 1
		end
	end
	if tp == "number" then
		return {tp, tonumber(str:sub(found)), len}
	elseif tp == "string" then
		str = str:sub(found)
		local num = tonumber(str)
		if num then
			return {"number", num, len}
		else
			return {tp, str, len}
		end
	end
	return {tp, nil, len}
end
function readKeyValues(str, prevpos, len)
	len = len or str:len()
	prevpos = prevpos or 1
	local level = 1
	local comment = false
	-- lazy to rewrite this to correct O(n) syntax analyzer, cuz spent much time on fixing bugs
	for k = prevpos, len do
		local char = str[k]
		if comment then
			if comment == "line" then
				if char == "\n" then
					comment = false
				end
			elseif comment == "lines" then
				if char == "*" and str[k + 1] == "/" then
					comment = false
					k = k + 1
				end
			end
		else
			if char == "{" then
				level = level + 1
			elseif char == "}" then
				level = level - 1
				if level == 0 then
					len = k
					break
				end
			elseif char == "/" then
				local nc = str[k + 1]
				if nc == "/" then
					comment = "line"
				elseif nc == "*" then
					comment = "lines"
				end
			end
		end
	end
	local out = {}
	for i = 1, 1000 do -- better than "while true do" if something is bad
		local key = readKey(str, prevpos, len)
		if not key[2] then break end
		local value = readKey(str, key[3], len)
		if not value[2] then break end
		prevpos = value[3]
		out[key[2]] = value[2]
		if prevpos >= len then break end
	end
	return out, prevpos
end
function toTable(vmt, gpath)
	local filec = file_Read(vmt, gpath or "GAME")
	if not filec then return {} end
	--print(filec)
	local keyvalues, len = readKeyValues(filec)
	return keyvalues
end
function toJSON(vmt, gpath)
	return util_TableToJSON(toTable(vmt, gpath))
end
texturekeys = {}
for k, v in ipairs({
	"ambientoccltexture",
	"basetexture",
	"basetexture2",
	"blendmodulatetexture",
	"blurtexture", -- shader
	"crackmaterial",
	"fallbackmaterial", -- dxlevel
	"fbtexture", -- shader
	"bumpmap",
	"bumpmap2",
	"corneatexture",
	"detail",
	"dudvmap",
	"envmap",
	"envmapmask",
	"envmapmask2",
	"flashlighttexture",
	"fresnelrangestexture",
	"include", -- include vmt, that can contain textures
	"iris",
	"lightwarptexture",
	"material", -- proxy
	"modelmaterial",
	"normalmap",
	"notooltexture",
	"phongexponenttexture",
	"phongwarptexture",
	"pixshader", -- shader
	"reflecttexture",
	"refracttexture",
	"refracttinttexture",
	"selfillummask",
	"texture2",
	"tooltexture",
	"woundcutouttexture", -- L4D2
	--[[--CSGO shaders doesn't work in Garry's mod
	"sourcemrtrendertarget",
	"aotexture",
	"exptexture",
	"grungetexture",
	"maskstexture",
	"painttexture",
	"posttexture",
	"surfacetexture",
	"weartexture",
	]]
}) do texturekeys[v] = true end
local function storeTexture(textures, vals)
	for k, v in pairs(vals) do
		if type(v) == "string" then
			k = k:lower()
			if (k[1] == "$" or k[1] == "%") then
				k = k:sub(2)
			end
			if texturekeys[k] then
				textures[#textures + 1] = v:gsub("\\\\?", "/"):lower() -- textures are not case sensitive, better to lowercase it, also we should replace windows path to linux like
			end
		elseif type(v) == "table" then
			storeTexture(textures, v)
		end
	end
end
function isRelativePath(path)
	if path:sub(1, 11) == "materials/" then
		return true
	end
	local ext = path:sub(-3)
	if ext == "vmt" or ext == "vtf" then
		return true
	end
end
function getTextures(vmt, gpath)
	local tab = toTable(vmt, gpath)
	local textures = {}
	for shadername, vals in pairs(tab) do
		if not vals then
			return textures
		end
		local ok, err = pcall(storeTexture, textures, vals)
		if not ok then
			print(vmt, gpath)
			ErrorNoHalt(err .. "\n")
			print(util.TableToJSON(val))
		end
	end
	return textures
end
function test(path, gpath)
	--print(path)
	local files, fold = file.Find(path .. "*", gpath)
	for k,v in pairs(fold) do
		if v == "debug" then
			continue
		end
		test(path .. v .. "/", gpath)
	end
	for i, j in pairs(files) do
		if string.GetExtensionFromFilename(j) ~= "vmt" then
			continue
		else
			j = string.StripExtension(j)
		end
		--print(path .. j)
		local mounttext = luavmt.getTextures(path .. j .. ".vmt", gpath)
		if #mounttext == 0 then
			print(luavmt.toJSON(path .. j .. ".vmt", gpath))
			print("File " .. path .. j .. ".vmt doesn't contain textures, possible bug or texture should be like it.")
		end
		--[[for i, j in pairs(mounttext) do
			materials[j:gsub("^materials/",""):gsub(".vmt",""):gsub(".vtf","")] = false
		end]]
		for k, v in pairs(Material(path .. j  .. ".vmt"):GetKeyValues()) do
			if TypeID(v) == TYPE_TEXTURE then
				if k[1] == "$" or k[1] == "%" then
					k = k:sub(2)
				end
				if not luavmt.texturekeys[k] then
					print(k, "Missing texture key that gmod supports!!!")
				end
			end
			--[[if TypeID(v) == TYPE_STRING and mat ~= fixpath(v) then
				if materials[v] ~= nil then
					materials[v] = true
				else
					PrintTable(materials)
					error(path .. j)
				end
			elseif TypeID(v) == TYPE_TEXTURE and mat ~= v:GetName() then
				if materials[(v:GetName())] ~= nil then
					materials[(v:GetName())] = true
				else
					print(k, v:GetName())
					PrintTable(materials)
					error(path .. j .. "@")
				end
			end]]
		end
		--[[for k, v in pairs(materials) do
			if v == false then
				--PrintTable(materials)
				--error(path .. j)
			end
		end]]
	end
end
-- luavmt.test("materials/", "GAME")