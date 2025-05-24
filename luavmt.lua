--[[ luavmt is simple lib over luavkv for parsing textures from vmt files and testing luavkv parser for Garry's mod ]]

local luavmt = {}
--- @type table<string, true>
local texturekeys = {}
for _, v in ipairs({
	"ambientoccltexture",
	"basetexture",
	"basetexture2",
	"blendmodulatetexture",
	"blurtexture",   -- shader
	"crackmaterial",
	"fallbackmaterial", -- dxlevel
	"fbtexture",     -- shader
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
	"include", -- include vmt, that can contain texture data
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

--- @param textures table<integer, string>
--- @param vals iKV
local function storeTexture(textures, vals)
	for k, v in pairs(vals) do
		if type(v) == "string" then
			--- @cast v string
			k = tostring(k):lower()
			--- @cast k string

			if (k[1] == "$" or k[1] == "%") then
				k = k:sub(2)
			end

			if texturekeys[k] then
				-- textures are not case sensitive, better to lowercase it, also we should replace windows path to linux like
				textures[#textures + 1] = v:gsub("\\\\?", "/"):lower()
			end
		elseif type(v) == "table" then
			storeTexture(textures, v)
		end
	end
end

--- @param path string Filepath
function luavmt.isRelativePath(path)
	if path:sub(1, 11) == "materials/" then return true end
	local ext = path:sub(-3)
	if ext == "vmt" or ext == "vtf" then return true end
end

--- @param vmtFilePath string Filepath
--- @param gpath string
function luavmt.getTextures(vmtFilePath, gpath)
	local tab = luavkv.fileToTable(vmtFilePath, { gpath = gpath })
	local textures = {}

	for shadername, vals in pairs(tab) do
		if not vals then return textures end
		local ok, err = pcall(storeTexture, textures, vals)

		if not ok then
			print(vmtFilePath, gpath)
			print(err .. "\n")
			if istable(vals) then
				if util and util.TableToJSON then
					print(util.TableToJSON(vals))
				end
			else
				print(vals)
			end
		end
	end

	return textures
end

-- garry's mod required to test VMT read state
if file and file.Find then
	--- @param path string Filepath
	--- @param gpath string Gmod location
	function luavmt.parseTest(path, gpath)
		--- @type string[], string[]
		local files, fold = file.Find(path .. "*", gpath)

		for _, v in pairs(fold) do
			if v ~= "debug" then
				luavmt.parseTest(path .. v .. "/", gpath)
			end
		end

		for _, j in pairs(files) do
			if string.GetExtensionFromFilename(j) == "vmt" then
				--print(path .. j)
				local mounttext = luavmt.getTextures(path .. j, gpath)

				if #mounttext == 0 then
					print(luavkv.fileToJSON(path .. j, { gpath = gpath }))
					print("File " .. path .. j .. " doesn't contain textures, possible bug or texture should be like it.")
				end

				--[[for i, j in pairs(mounttext) do
				materials[j:gsub("^materials/",""):gsub(".vmt",""):gsub(".vtf","")] = false
			end]]
				for k, v in pairs(Material(path .. j .. ".vmt"):GetKeyValues()) do
					if TypeID(v) == TYPE_TEXTURE then
						if k[1] == "$" or k[1] == "%" then
							k = k:sub(2)
						end

						if not texturekeys[k] then
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
	end
end

_G.luavmt = luavmt
