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
