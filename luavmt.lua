local istable = istable
--[[ luavmt is simple lib over luavkv for parsing textures from vmt files and testing luavkv parser]]
module("luavmt", package.seeall)

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
	if path:sub(1, 11) == "materials/" then return true end
	local ext = path:sub(-3)
	if ext == "vmt" or ext == "vtf" then return true end
end

function getTextures(vmt, gpath)
	local tab = luavkv.fileToTable(vmt, {gpath = gpath})
	local textures = {}

	for shadername, vals in pairs(tab) do
		if not vals then return textures end
		local ok, err = pcall(storeTexture, textures, vals)

		if not ok then
			print(vmt, gpath)
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
if file.Find then
	function ParseTest(path, gpath)
		--print(path)
		local files, fold = file.Find(path .. "*", gpath)

		for k, v in pairs(fold) do
			if v ~= "debug" then
				VMTParseTest(path .. v .. "/", gpath)
			end
		end

		for i, j in pairs(files) do
			if string.GetExtensionFromFilename(j) == "vmt" then
				--print(path .. j)
				local mounttext = getVMTTextures(path .. j .. ".vmt", gpath)

				if #mounttext == 0 then
					print(toJSON(path .. j .. ".vmt", gpath))
					print("File " .. path .. j .. ".vmt doesn't contain textures, possible bug or texture should be like it.")
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