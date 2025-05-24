# luavkv
Lua Valve key value structure standalone parser

Parser is based on info provided at https://developer.valvesoftware.com/wiki/Category:List_of_Shader_Parameters
Designed for garry's mod & lua 5.1.

WARNING! Garry's mod already contains special function util.KeyValuesToTable, but its not always parse everything (also doesn't return 0-level keys which in VMT is shadernames).
IMaterial:GetKeyValues returns only correct textures that support game engine.
This can be used to parse valve key value structure with collisions to merge them and etc.

Valve Key Value Structure (EBNF) as i understand (that used to VMT and etc.):
```
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
SPECIAL = "?" | "<" | "$" | "_" | "\" | "/" ;
```

Usage:
```
params = {
	bufferSize = integer?, -- Size of buffer to read from file at time (Default = 128)
	iterateCount = integer?, -- Maximum iterate count to process key value pairs (0 = no limit, Default 32768)
	preserveOrder = boolean?, -- Preserve order of key value pairs (true = store in order by array)
	fixCollisions = boolean?, -- Simple fix of collision (conflicts with preserveOrder)
	minFixIndex = integer?, -- Simple fix minimum index to append to key (used when fixCollisions)
	maxFixIndex = integer?, --  Simple fix maximum index to append to key (used when fixCollisions)
	mergeCollisions = boolean?, -- Merge tables on collision (conflicts with preserveOrder)
	gpath = string? -- For gmod to specify location of file
}

-- Base functions

--- returns table based on VKV format in file
luavkv.stringToTable(FilePointer|string, params)
--- same as above but reads file internally
luavkv.fileToTable(filePath, params)

-- Internal functions

--- sets parameters to internal functions, manually called from functions above
luavkv.setParams(params)
--- reads value from file based on start position (if isKey = true, reads key specific value)
luavkv.readValue(filePointer|string, startPos: integer, depth: integer, isKey: boolean?) 
--- read key values from file or string from startPos counting level
luavkv.readKeyValues(filePointer|string, startPos: integer, level: integer): table result, integer endPos 
```

# luavmt
This repo also contains `luavmt` which is designed for Garry's mod to check materials shaders and textures.
Also this used to tests `luavkv` is working corrent on big count of files.

Usage: 
```
--- get texture list from material vmt file based on gmod whitelist materials
luavmt.getTextures(materialPath: string, gPath: string): string[]
--- returns is path relative to gmod file structure
luavmt.isRelativePath(path: string): boolean
--- tests luavkv based on gmod materials
luavmt.parseTest(materialPath: string, gPath: string): boolean
```

# Testing
Run `luavmt.parseTest("materials/", "GAME")` to test if `luavkv` is working correctly. It will print out the results of parsing all materials in game and will print if something went wrong (but its only counts for textures, so may be false positive).
