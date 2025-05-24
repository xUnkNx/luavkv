local tostring, tonumber, find, type, pairs, ipairs, Vector, assert, sub = tostring, tonumber, string.find, type, pairs, ipairs, Vector, assert, string.sub
local io, file, util = io, file, util

module("luavkv")

--[[	Valve KeyValue format lua parser (mostly for Garry's Mod) / UnkN ©2023
Parser is based on info provided at https://developer.valvesoftware.com/wiki/Category:List_of_Shader_Parameters
WARNING! Garry's mod already contains special function util.KeyValuesToTable, but its not always parse everything (also doesn't return 0-level keys which in VMT is shadernames).
F.e. IMaterial:GetKeyValues returns only correct textures that support game engine.

Valve Key Value Structure (EBNF) as i understand (that used to VMT and etc.):

COMMENTLINES = "/*", ? any character - "*/" ?, "*/" ; (* WARNING! Its not supported by VMT, but models/headcrab_classic/headcrabsheet.vmt contains this. *)
COMMENTLINE = "//", ? any character - "\n" ? , "\n" ; (* Not used in terminal symbols below, because it can be anywhere. *)
VMT = QUOTEDKEY | KEY , QUOTEDVALUE | VALUE ;

QUOTEDKEY = '"' , KEY , '"' ;
KEY = NUMBER | STRING ;
QUOTEDVALUE = '"' , VALUE , '"' ;
VALUE = STRING | NUMBER | TABLE | VECTOR ;

TABLE = "{" , KEY , VALUE , "}" , { TABLE } ;
VECTOR = "[" , NUMBER , [ NUMBER ] , [ NUMBER ], "]" ; (* why models/props_combine/combine_tower01b.vmt closes [ with } ??? *)
STRING = { SPECIAL | CHAR | NUMBER } ;
NUMBER = [ "-" ] , [ DIGIT , { DIGIT } ] , [ "." , DIGIT , { DIGIT } ] ;

DIGIT = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9" ;
CHAR = ? Any character based on file system, language and etc. - SPECIAL ? ;
SPECIAL = "?" | "<" | "$" | "_" | "\" | "/";
]]
if not Vector then
	Vector = function(x, y, z)
		return {
			x, y, z, x = x,
			y = y,
			z = z
		}
	end
end

local OpenFile, ReadBlock, Seek, CloseFile

if file and file.Open then
	-- Garry's mod
	OpenFile = function(path, gpath) return file.Open(path, "rb", gpath or "GAME") end
	ReadBlock = function(ptr, blockSize) return ptr:Read(blockSize) end

	Seek = function(ptr, set)
		ptr:Seek(set)
	end

	CloseFile = function(ptr)
		ptr:Close()
	end
else
	-- lua 5.1
	OpenFile = function(path) return io.open(path, "rb") end

	ReadBlock = function(ptr, blockSize)
		ptr:read(blockSize)
	end

	Seek = function(ptr, set) return ptr:seek("set", set) end
	CloseFile = io.close
end

local numchars = {
	["."] = true,
	["-"] = true
}

local strpat = "[%w%d%$<%?\\/_%-]" -- string can START from these chars

for i = 0, 9 do
	numchars[tostring(i)] = true
end

local defaultBlockSize = 128 -- chars, should be more than 3
local defaultIterateCount = 32768 -- key/value pairs to read
local iterateCount, blockSize, preserveOrder, fixCollisions = defaultIterateCount, defaultBlockSize, false, true -- current settings

function readKeyValues(filePtr, offset, level)
	--[[local level, comment, out, buffer, bufferPos = 1, false, {}, '', 0
	local char = buffer[bufferPos]
	if comment then
		if comment == "line" then
			if char == "\n" then
				comment = false
			end
		elseif comment == "lines" then
			if char == "*" and buffer[bufferPos + 1] == "/" then
				comment = false
				bufferPos = bufferPos + 1
			end
		end
	else
		if char == "{" then
			level = level + 1
		elseif char == "}" then
			level = level - 1

			if level == 0 then
				offset = offset + bufferPos
				print("found offset", offset)
				break
			end
		elseif char == "/" then
			local nc = buffer[bufferPos + 1]

			if nc == "/" then
				comment = "line"
			elseif nc == "*" then
				comment = "lines"
			end
		end
	end]]
	offset = offset or 0
	level = level or 0
	local out = {}

	while iterateCount > 0 do
		iterateCount = iterateCount - 1
		local key = readKey(filePtr, offset, level)
		if not key[2] then break end

		if key[1] == "endtable" and key[2] < level then
			offset = key[3]
			break
		end

		local value = readKey(filePtr, key[3], level)
		if not value[2] then break end
		if key[3] >= value[3] then break end -- failed to read data
		offset = value[3]

		if preserveOrder then
			out[#out + 1] = {
				key = key[2],
				value = value[2]
			}
		else
			-- simple fix of collisions, use preserve order option to disable this
			if out[key[2]] and fixCollisions then
				local newKey = key[2]

				for k = 1, 999 do
					if not out[key[2] .. k] then
						newKey = key[2] .. k
						break
					end
				end

				key[2] = newKey
			end

			out[key[2]] = value[2]
		end
	end

	return out, offset
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

	if found then return tonumber(str:sub(found, len)), len end

	return 0, len
end

local function readVector(vec, vecLen)
	local x, y, z = readNumber(vec, 1)

	if y < vecLen then
		y, z = readNumber(vec, y)

		if z < vecLen then
			z = readNumber(vec, z)
		else
			z = 0
		end
	else
		y = 0
	end

	return Vector(x, y, z)
end

function readKey(filePtr, offset, level)
	local found, tp, buffer, bufferPos, output = false, "nil", '', 2, ''

	if type(filePtr) == "string" then
		buffer = sub(filePtr, offset + 1, offset + blockSize)
	else
		Seek(filePtr, offset)
		-- allocate two bytes in beggining of block to read previous two chars after buffer update
		buffer = ReadBlock(filePtr, blockSize)

		if not buffer then
			return {tp, nil}
		end
	end

	buffer = "  " .. buffer

	while buffer do
		bufferPos = bufferPos + 1

		-- read more data when current buffer ends
		if bufferPos > blockSize + 1 then
			local newBuff

			if type(filePtr) == "string" then
				newBuff = sub(filePtr, offset + 1 + blockSize, offset + blockSize + blockSize)
			else
				newBuff = ReadBlock(filePtr, blockSize)
			end

			if not newBuff then break end
			offset = offset + blockSize -- handle difference between buffers
			newBuff = sub(buffer, -2) .. newBuff -- this preserves one char in both directions to check ahead
			buffer = newBuff
			bufferPos = 2
		end

		local char, skip = buffer[bufferPos], true
		if char == "" then break end -- EOF

		if tp == "nil" then
			if numchars[char] then
				tp = "number"
				found = bufferPos
				skip = false
			elseif char == "\"" then
				tp = "stringquotes"
				found = bufferPos

				if buffer[bufferPos + 1] == "[" then
					tp = "vectorquoted"
				end
			elseif char == "[" then
				tp = "vector"
				found = bufferPos
			elseif char == "{" then
				-- remove leading two bytes from offset
				return {"table", readKeyValues(filePtr, offset + bufferPos - 2, level + 1)}
			elseif char == "}" then
				return {"endtable", level - 1, offset + bufferPos - 2}
			elseif find(char, strpat) then
				if char == "/" then
					local nc = buffer[bufferPos + 1]

					if nc == "/" then
						tp = "commentline"
						bufferPos = bufferPos + 1
					elseif nc == "*" then
						tp = "commentlines"
						bufferPos = bufferPos + 1
					end
				else
					tp = "string"
					found = bufferPos
					skip = false
				end
			end
			--[[elseif char == "/" then
				if str[i + 1] == "/" then
					tp = "comment"
					found = i + 2
				end]]
		elseif tp == "number" then
			-- parse number when control char occured
			if not numchars[char] then
				-- check for unescaped string started with number
				if find(char, strpat) then
					tp = "string"
				else
					-- tonumber(buffer:sub(found, bufferPos - 1))
					return {tp, tonumber(output), offset + bufferPos - 2}
				end
			end

			skip = false
		elseif tp == "stringquotes" then
			if char == "\"" and buffer[bufferPos - 1] ~= "\\" then
				--buffer = buffer:sub(found + 1, bufferPos - 1)
				local num = tonumber(output)

				if num then
					return {"number", num, offset + bufferPos - 2}
				else
					return {tp, output, offset + bufferPos - 2}
				end
			end

			skip = false
		elseif tp == "string" then
			-- finish of unescaped string
			if not find(char, strpat) then
				-- buffer = buffer:sub(found, bufferPos - 1)
				local num = tonumber(output)

				if num then
					return {"number", num, offset + bufferPos - 2}
				else
					return {tp, output, offset + bufferPos - 2}
				end
			end

			skip = false
		elseif tp == "commentline" then
			if char == "\n" then
				tp = "nil"
			end
		elseif tp == "commentlines" then
			if char == "*" and buffer[bufferPos + 1] == "/" then
				tp = "nil"
				bufferPos = bufferPos + 1
			end
		elseif tp == "vector" then
			if char == "]" then
				-- buffer:sub(found + 1, bufferPos - 1)
				return {tp, readVector(output, output:len()), offset + bufferPos - 2}
			end

			skip = false
		elseif tp == "vectorquoted" then
			if char == "\"" then
				return {tp, readVector(output, output:len()), offset + bufferPos - 2}
			end

			skip = false
		end

		-- local buffer for output instead of substring from file contents
		if found and not skip then
			output = output .. char
		end
	end

	-- handle numbers and strings which are at EOF
	if tp == "number" or tp == "string" then
		-- buffer = buffer:sub(found)
		local num = tonumber(output) -- also skip some EBNF by lua number parser

		if num then
			return {"number", num, offset + bufferPos - 2}
		else
			return {"string", buffer, offset + bufferPos - 2}
		end
	end

	return {tp, nil}
end

function fileToTable(path, params)
	params = params or {}
	local filePtr = OpenFile(path, params.gpath)
	if not filePtr then return {} end
	local keyvalues = stringToTable(filePtr, params)
	CloseFile(filePtr)

	return keyvalues
end

function stringToTable(str, params)
	params = params or {}
	bufferSize = params.bufferSize or defaultBlockSize
	assert(bufferSize > 4, "Too small buffer size to parse VKV")
	iterateCount = params.iterateCount or defaultIterateCount
	preserveOrder = params.preserveOrder or false
	if not preserveOrder then
		fixCollisions = params.fixCollisions or true
	end
	local keyvalues = readKeyValues(str)

	return keyvalues
end

if util.TableToJSON then
	function fileToJSON(path, params)
		return util.TableToJSON(fileToTable(path, params))
	end
	function stringToJSON(path, params)
		return util.TableToJSON(stringToTable(path, params))
	end
end