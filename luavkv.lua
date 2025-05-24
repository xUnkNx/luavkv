--- Valve KeyValue format lua parser (mostly for Garry's Mod) / UnkN ©2025
--- @version 1.2
--- Parser is based on info provided at https://developer.valvesoftware.com/wiki/Category:List_of_Shader_Parameters
--- For gmod you may look to util.KeyValuesToTable or util.KeyValuesToTablePreserveOrder functions

local tostring, tonumber, find, type, pairs, Vector, assert, sub, print, error = tostring, tonumber, string.find, type,
	pairs, Vector, assert, string.sub, print, error
local io, file, util = io, file, util

local luavkv = {}

if not Vector then
	--- @class Vector A simple vector class
	--- @field [1] number x
	--- @field [2] number y
	--- @field [3] number z

	--- @param x number
	--- @param y number
	--- @param z number
	--- @returns Vector
	Vector = function(x, y, z)
		return {
			x,
			y,
			z
		}
	end
end

-- interfaces
--- @alias iFile GFile|file*|file_class File interface
--- @alias iKV table<string|number, any> Key value result interface

--- @type fun(path: string, gpath: string?): iFile?
local OpenFile
--- @type fun(filePtr: iFile, blockSize: integer): string?
local ReadBlock
--- @type fun(filePtr: iFile, offset: integer)
local Seek
--- @type fun(filePtr: iFile)
local CloseFile

if file and file.Open then
	-- Garry's mod

	--- @param path string
	--- @param gpath string?
	--- @return iFile?
	OpenFile = function(path, gpath)
		return file.Open(path, "rb", gpath or "GAME")
	end

	--- @param filePtr iFile
	--- @param blockSize integer
	--- @return string?
	ReadBlock = function(filePtr, blockSize)
		return filePtr:Read(blockSize)
	end

	--- @param filePtr iFile
	--- @param offset integer
	Seek = function(filePtr, offset)
		filePtr:Seek(offset)
	end

	--- @param filePtr iFile
	CloseFile = function(filePtr)
		filePtr:Close()
	end
else
	-- lua 5.1

	--- @param path string
	--- @return iFile?
	OpenFile = function(path)
		return io.open(path, "rb")
	end

	--- @param filePtr iFile
	--- @param blockSize integer
	--- @return string?
	ReadBlock = function(filePtr, blockSize)
		return filePtr:read(blockSize)
	end

	--- @param filePtr iFile
	--- @param offset integer
	Seek = function(filePtr, offset)
		filePtr:seek("set", offset)
	end

	CloseFile = io.close
end

local numchars = {
	["."] = true,
	["-"] = true
}

-- string can START from these chars
local strpat = "[%w%d%$<%?\\/_%-]"

for i = 0, 9 do
	numchars[tostring(i)] = true
end

--- @type integer Default block size which will be read from file
local defaultBlockSize = 128
--- @type integer Default read key/value pair count
local defaultIterateCount = 32768
--- Current settings block

--- @type integer Limit of iterations before stopping reading file (may be usefull for big files)
local iterateCount = defaultIterateCount
--- @type integer How much chars should be read from file at time (to process)
local blockSize = defaultBlockSize
--- @type boolean Preserve order of key/value pairs, do not produce key value pairs, only arrays with values
local preserveOrder = false
--- @type integer Minimum value to append on collision
local minFixIndex = 1
--- @type integer Maximum value to append on collision
local maxFixIndex = 999
--- @type boolean If this key already exists in result table, simply appends to key name values from minFixIndex to maxFixIndex
local fixCollisions = true
--- @type boolean On key collision merge if both values are tables, otherwise overwrite
local mergeCollisions = false

--- @param out iKV
--- @param key string|number
local function fixCollision(out, key)
	local newKey = key

	for k = minFixIndex, maxFixIndex do
		if not out[key .. k] then
			newKey = key .. k
			break
		end
	end

	return newKey
end

--- @param dest iKV
--- @param src iKV
local function simpleMerge(dest, src)
	for key, value in pairs(src) do
		-- if them both are tables, merge
		if type(dest[key]) == "table" and type(value) == "table" then
			value = simpleMerge(dest[key], value)
		elseif fixCollisions then
			key = fixCollision(dest, key)
		end
		dest[key] = value
	end
	return dest
end

--- @param filePtr iFile|string
--- @param level integer
--- @param out iKV
--- @param offset integer
--- @return boolean, integer?
local function processKeyValues(filePtr, level, out, offset)
	local keyType, key, keyOffset = luavkv.readValue(filePtr, offset, level, true)
	if not key then return false end

	if keyType == "endtable" and key < level then
		return false, keyOffset
	end

	local _, value, valueOffset = luavkv.readValue(filePtr, keyOffset, level)
	if not value then return false end
	-- failed to read data
	if keyOffset >= valueOffset then return false end

	if preserveOrder then
		out[#out + 1] = {
			key = key,
			value = value
		}
	else
		if type(key) == "string" or type(key) == "number" then
			--- @cast key string|number
			if out[key] then
				-- use preserve order option to disable thisif mergeCollisions then
				if mergeCollisions and type(out[key]) == "table" and type(value) == "table" then
					-- Merge tables if flag is active
					value = simpleMerge(out[key], value)
				elseif fixCollisions then
					-- simple fix of collisions or overwrite to last value
					key = fixCollision(out, key)
				end
			end
			out[key] = value
		else
			-- Seek(filePtr, offset)
			-- print(ReadBlock(filePtr, blockSize))
			print("luavkv warning: Skipping value, because key should be string or number, got " ..
				type(key) .. " from " .. keyType .. " at " .. valueOffset)
		end
	end
	return true, valueOffset
end

--- @param filePtr iFile|string File pointer or buffer to process
--- @param offset integer? Start position to process string/file
--- @param level integer? Recursion level based on table depth
--- @return iKV result, integer endPos
function luavkv.readKeyValues(filePtr, offset, level)
	offset = offset or 0
	level = level or 0
	local out = {}

	-- if iterates limited
	if iterateCount > 0 then
		while iterateCount > 0 do
			iterateCount = iterateCount - 1
			local ret, offsetNew = processKeyValues(filePtr, level, out, offset)
			if offsetNew then
				offset = offsetNew
			end
			if not ret then
				break
			end
		end
	else
		while true do
			local ret, offsetNew = processKeyValues(filePtr, level, out, offset)
			if offsetNew then
				offset = offsetNew
			end
			if not ret then
				break
			end
		end
	end

	return out, offset
end

--- @param str string
--- @param offset number
--- @returns number, number
local function readNumber(str, offset)
	local len = str:len()
	local found = -1

	for i = offset, len do
		local char = str:sub(i, i)

		if numchars[char] then
			if found == -1 then
				found = i
			end
		elseif found ~= -1 then
			return tonumber(str:sub(found, i - 1)), i
		end
	end

	if found ~= -1 then return tonumber(str:sub(found, len)), len end

	return 0, len
end

--- @param vec string
--- @param vecLen number
local function readVector(vec, vecLen)
	local x, offset = readNumber(vec, 1)
	local y, z = 0, 0
	if offset < vecLen then
		y, offset = readNumber(vec, offset)

		if offset < vecLen then
			z = readNumber(vec, offset)
		end
	end

	return Vector(x, y, z)
end

local function isVector(str, strLen)
	for i = 2, strLen - 1 do
		local char = str:sub(i, i)
		-- if string contains [] characters its not vector
		if not numchars[char] and not find(char, "%s") then
			return false
		end
	end
	return true
end

--- @param filePtr iFile|string File pointer or string to process
--- @param offset integer Start position to process from
--- @param level integer Depth of table which is may currently in processing
--- @param isKey boolean? If true reads only integer or string
--- @return string type, iKV|number|string|Vector|GVector|nil result, integer endPos
function luavkv.readValue(filePtr, offset, level, isKey)
	local found, tp, buffer, bufferPos, output = -1, "nil", nil, 2, ''

	if type(filePtr) == "string" then
		buffer = sub(filePtr, offset + 1, offset + blockSize)
	else
		Seek(filePtr, offset)
		-- allocate two bytes in beggining of block to read previous two chars after buffer update
		buffer = ReadBlock(filePtr, blockSize)

		if not buffer then
			return tp, nil, 0
		end
	end

	buffer = "  " .. buffer

	while buffer do
		bufferPos = bufferPos + 1

		-- read more data when current buffer ends
		if bufferPos > blockSize + 1 then
			--- @type string?
			local newBuff = nil

			if type(filePtr) == "string" then
				newBuff = sub(filePtr, offset + 1 + blockSize, offset + blockSize + blockSize)
			else
				newBuff = ReadBlock(filePtr, blockSize)
			end

			if not newBuff then break end
			-- handle difference between buffers
			offset = offset + blockSize
			-- this preserves one char in both directions to check ahead
			newBuff = sub(buffer, -2) .. newBuff
			buffer = newBuff
			bufferPos = 2
		end

		local char, skip = sub(buffer, bufferPos, bufferPos), true
		if char == "" then break end -- EOF

		if tp == "nil" then
			if numchars[char] then
				tp = "number"
				found = bufferPos
				skip = false
			elseif char == "\"" then
				tp = "stringquotes"
				found = bufferPos

				if buffer[bufferPos + 1] == "[" and not isKey then
					tp = "vectorquoted"
				end
			elseif char == "[" then
				tp = "vector"
				found = bufferPos
			elseif char == "{" then
				-- remove leading two bytes from offset
				return "table",
					luavkv.readKeyValues(
						filePtr,
						offset + bufferPos - 2,
						level + 1
					)
			elseif char == "}" then
				return "endtable", level - 1, offset + bufferPos - 2
			elseif find(char, strpat) then
				if char == "/" then
					local nc = sub(buffer, bufferPos + 1, bufferPos + 1)

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
					return tp, tonumber(output), offset + bufferPos - 2
				end
			end

			skip = false
		elseif tp == "stringquotes" then
			if char == "\"" and buffer[bufferPos - 1] ~= "\\" then
				--buffer = buffer:sub(found + 1, bufferPos - 1)
				local num = tonumber(output)

				if num then
					return "number", num, offset + bufferPos - 2
				else
					return tp, output, offset + bufferPos - 2
				end
			end

			skip = false
		elseif tp == "string" then
			-- finish of unescaped string
			if not find(char, strpat) then
				-- buffer = buffer:sub(found, bufferPos - 1)
				local num = tonumber(output)

				if num then
					return "number", num, offset + bufferPos - 2
				else
					return tp, output, offset + bufferPos - 2
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
				return tp, readVector(output, output:len()), offset + bufferPos - 2
			end

			skip = false
		elseif tp == "vectorquoted" then
			if char == "\"" and buffer[bufferPos - 1] ~= "\\" then
				-- check is vector or not
				if not isVector(output, output:len()) then
					tp = "stringquotes"
					local num = tonumber(output)

					if num then
						return "number", num, offset + bufferPos - 2
					else
						return tp, output, offset + bufferPos - 2
					end
				end
				return tp, readVector(output, output:len()), offset + bufferPos - 2
			end

			skip = false
		end

		-- local buffer for output instead of substring from file contents
		if found ~= -1 and not skip then
			output = output .. char
		end
	end

	-- handle numbers and strings which are at EOF
	if tp == "number" or tp == "string" then
		-- buffer = buffer:sub(found)
		local num = tonumber(output) -- also skip some EBNF by lua number parser

		if num then
			return "number", num, offset + bufferPos - 2
		else
			return "string", buffer, offset + bufferPos - 2
		end
	end

	return tp, nil, 0
end

--- @class LuaVKVParams
--- @field bufferSize integer? Size of buffer to read from file at time (Default = 128)
--- @field iterateCount integer? Maximum iterate count to process key value pairs (0 = no limit, Default 32768)
--- @field preserveOrder boolean? Preserve order of key value pairs (true = store in order by array)
--- @field fixCollisions boolean? Simple fix of collision (conflicts with preserveOrder)
--- @field minFixIndex integer? Simple fix minimum index to append to key (used when fixCollisions)
--- @field maxFixIndex integer? Simple fix maximum index to append to key (used when fixCollisions)
--- @field mergeCollisions boolean? Merge tables on collision (conflicts with preserveOrder)
--- @field gpath string? For gmod to specify location of file

--- @param params LuaVKVParams?
function luavkv.setParams(params)
	params = params or {}
	blockSize = params.bufferSize or defaultBlockSize
	assert(
		type(blockSize) == "number" and blockSize >= 4,
		"Too small buffer size to parse VKV"
	)
	iterateCount = params.iterateCount or defaultIterateCount
	assert(type(iterateCount) == "number", "Iterate count should be integer")
	preserveOrder = params.preserveOrder or false
	if not preserveOrder then
		fixCollisions, mergeCollisions = true, false
		if params.fixCollisions ~= nil then
			fixCollisions = params.fixCollisions and true or false
		end
		if fixCollisions then
			minFixIndex = params.minFixIndex or 1
			maxFixIndex = params.maxFixIndex or 999
			assert(type(minFixIndex) == "number", type(maxFixIndex) == "number")
		end
		if params.mergeCollisions ~= nil then
			mergeCollisions = params.mergeCollisions and true or false
		end
	end
	-- print("Params: ", blockSize, iterateCount, preserveOrder, fixCollisions, mergeCollisions, minFixIndex, maxFixIndex)
	return params
end

--- @param path string File path
--- @param params LuaVKVParams?
function luavkv.fileToTable(path, params)
	params = luavkv.setParams(params)
	local filePtr = OpenFile(path, params.gpath)
	if not filePtr then
		error("Failed to open file " .. path)
	end
	local keyvalues = luavkv.stringToTable(filePtr, params)
	CloseFile(filePtr)

	return keyvalues
end

--- @param str iFile|string
--- @param params LuaVKVParams?
--- @return iKV
function luavkv.stringToTable(str, params)
	luavkv.setParams(params)
	local keyValues = luavkv.readKeyValues(str)
	return keyValues
end

if util and util.TableToJSON then
	--- @param path string
	--- @param params LuaVKVParams?
	function luavkv.fileToJSON(path, params)
		return util.TableToJSON(luavkv.fileToTable(path, params))
	end

	--- @param path string
	--- @param params LuaVKVParams?
	function luavkv.stringToJSON(path, params)
		return util.TableToJSON(luavkv.stringToTable(path, params))
	end
end

_G.luavkv = luavkv
