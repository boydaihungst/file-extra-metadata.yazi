#!/usr/bin/env lua

local FLAGS = {uappnd=1,sappnd=1,arch=2,compressed=3,nodump=4,hidden=8,uchg=9,schg=9,opaque=10,tracked=14,restricted=15}
local CHARS = {"-","a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","v"}

local function parse_flags(f)
    local a = string.rep("-", 22)
    if f == "-" or f == "" then return a end
    for flag in f:gmatch("[^,]+") do
        local pos = FLAGS[flag:match("^%s*(.-)%s*$")]
        if pos then a = a:sub(1,pos-1) .. (CHARS[pos] or "-") .. a:sub(pos+1) end
    end
    return a
end

local file = arg[1]
if not file then print("Usage: lsattr_macos.lua [file]"); os.exit(1) end

local h = io.popen(string.format("ls -lO '%s' 2>/dev/null", file:gsub("'", "'\\''")))
local line = h:read("*a"):match("[^\n]+")
h:close()

if not line then print("Error reading file"); os.exit(1) end

local parts = {}
for w in line:gmatch("%S+") do table.insert(parts, w) end

print(parse_flags(parts[5] or "-") .. " " .. table.concat(parts, " ", #parts-2))

