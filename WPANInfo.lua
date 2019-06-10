-- Existing fields to use as input
local f_wpan_nwksrc64    = Field.new("wpan.src64")
local f_wpan_nwksrc16    = Field.new("wpan.src16")
local f_wpan_nwkdst64    = Field.new("wpan.dst64")
local f_wpan_nwkdst16    = Field.new("wpan.dst16")
local f_zbee_nwksrc64    = Field.new("zbee_nwk.src64")
local f_zbee_nwkdst64    = Field.new("zbee_nwk.dst64")
local f_zbee_nwkdst      = Field.new("zbee_nwk.dst")
local f_zbee_nwksrc      = Field.new("zbee_nwk.src")
local f_protocols        = Field.new("frame.protocols")
local f_zbee_link        = Field.new("zbee_nwk.cmd.link.address")
local f_zbee_linkincost  = Field.new("zbee_nwk.cmd.link.incoming_cost")
local f_zbee_linkoutcost = Field.new("zbee_nwk.cmd.link.outgoing_cost")
local f_zbeecmd          = Field.new("zbee_nwk.cmd.id")
local f_framenr          = Field.new("frame.number")

local enable_map = true

-- our fake protocol
local wpanlookup = Proto("wpanlookup", "WPAN Lookup")

-- our fake fields
local f_srcname = ProtoField.string("wpanlookup.srcname", "SrcName")
local f_src     = ProtoField.string("wpanlookup.src", "Src")
local f_dstname = ProtoField.string("wpanlookup.dstname", "DstName")
local f_dst     = ProtoField.string("wpanlookup.dst", "Dst")
local f_test     = ProtoField.string("wpanlookup.test", "Test")

-- register fields to the protocol
wpanlookup.fields = {
    f_dstname,
    f_dst,
    f_srcname,
    f_src,
    f_test,
}

function GetFileName()
   local str = debug.getinfo(2, "S").source:sub(2)
   return tostring( str:match("(.*)(lua)").."lookup.csv" ) 
end

function GetFileNameMap()
   local str = debug.getinfo(2, "S").source:sub(2)
   return tostring( str:match("(.*)(lua)").."map.txt" ) 
end

function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

function ChangeAddress(address)
    address = string.gsub(string.lower(address), "0x0000", "0x")
    
    if address == "0x" then address="0x0000" end
    return address
end 

function GetLinkStr(src, link, inc, outc)
    local output = ""
    output = '"' .. ChangeAddress(tostring( src )) .. '" -> ' 
    output = output .. '"' .. ChangeAddress(tostring( link ))  .. '"'
    output = output .. ' [color="red" label="' .. tostring( inc ) .. '/' .. tostring( outc ) .. '"]'
    return output
end

function AddNetworkMapDevice()
    local src = f_zbee_nwksrc()
    local dst = f_wpan_nwkdst16()
    local org = {}
    local linktb = {}
    local adddev = true
    
    if file_exists(GetFileNameMap()) then
        for org in io.lines( GetFileNameMap() ) do
            tmp = split(org,'"')
            
            -- device connection already added as dev
            if tmp[2] == ChangeAddress(tostring( src )) and tmp[4] == ChangeAddress(tostring( dst )) and #tmp >= 6 and tmp[6] == "blue" then
                return
            end
            
            -- device added as router?
            if tmp[2] == ChangeAddress(tostring( src )) and tmp[4] == "rounded" then
                adddev = false
            end
            
            -- add only device to array
            if string.find(tostring(org), "0x") ~= nil then
                linktb[#linktb + 1] = org
            end
        end
    end
    
    local file = io.open(GetFileNameMap(), "w")
    
    file:write("digraph G {\n")
    file:write("node[shape=record];\n")

    for i = 1, #linktb do
        file:write(linktb[i] .. "\n")
    end
    
    if adddev == true then
        file:write('"' .. ChangeAddress(tostring( src )) .. '" [style="bold", label="{' .. ChangeAddress(tostring( src )) .. '|' .. GetLookup64(tostring(f_zbee_nwksrc64())) .. '|' .. tostring(f_zbee_nwksrc64()) .. '}"] \n')
    end 
    file:write('  "' .. ChangeAddress(tostring( src )) .. '" -> "' .. ChangeAddress(tostring( dst )) .. '" [color="blue"]\n')
       
    file:write("}\n")
    file:close()

end

function AddNetworkMapLinkState()
    local org = {}
    local linktb = {}
    local src = f_wpan_nwksrc16()
    local link = {f_zbee_link()}
    local incost = {f_zbee_linkincost()}
    local outcost = {f_zbee_linkoutcost()}
    local output = ""
    
    if file_exists(GetFileNameMap()) then
        for org in io.lines( GetFileNameMap() ) do
            if string.find(tostring(org), "0x") ~= nil then
                tmp = split(org,'"')
                if tmp[2] ~= ChangeAddress(tostring( src )) or tmp[6] == "blue" then
                    linktb[#linktb + 1] = org
                end
            end
        end
    end
    
    local file = io.open(GetFileNameMap(), "w")
    
    file:write("digraph G {\n")
    file:write("node[shape=record];\n")
    
    for i = 1, #linktb do
        file:write(linktb[i] .. "\n")
    end
    
    file:write('"' .. ChangeAddress(tostring( src )) .. '" [style="rounded", label="{' .. ChangeAddress(tostring( src )) .. '|' .. GetLookup16(tostring(src)) .. '|' .. tostring(f_zbee_nwksrc64()) .. '}"] \n')
    for i = 1, #link, 1 do
        output = GetLinkStr(ChangeAddress(tostring( src )), tostring( link[i] ), tostring( incost[i] ), tostring( outcost[i] ))
        file:write("  " .. output .. "\n")
    end
    
    file:write("}\n")
    file:close()
end

function ReadLookup()  
    lookup_table = {}
    for line in io.lines( GetFileName() ) do 
        lookup_table[#lookup_table + 1] = split(line,",")
    end
    
    return lookup_table
end

function GetLookup(zbee_address)
    local name = GetLookup64(zbee_address)
    if name == "" then 
        name = GetLookup16(zbee_address) 
    end
    return name
end

function GetLookup64(zbee_address)
    for count = 1, #lookup_table do
        if string.lower(lookup_table[count][1]) == string.lower(zbee_address) then
            return lookup_table[count][3]
        end
    end
    
    return ""
end

function GetLookup16(zbee_address)
    for count = 1, #lookup_table do
        if string.lower(lookup_table[count][2]) == string.lower(zbee_address) or string.lower(lookup_table[count][2]) == string.gsub(string.lower(zbee_address), "0x0000", "0x") then
            return lookup_table[count][3]
        end
    end
    
    return ""
end

os.remove(GetFileNameMap()) 
local lookup = ReadLookup()

function wpanlookup.dissector(tvb, pinfo, tree)
    if string.find(tostring( f_protocols() ), "wpan") ~= 1 then
        return         
    end
      
    -- Add a new protocol tree for out fields
    local subtree = tree:add(wpanlookup)
    
    -- declare fields
    local src = f_zbee_nwksrc64() or f_wpan_nwksrc64() or f_wpan_nwksrc16()
    src = tostring( src )

    local dst = f_zbee_nwkdst64() or f_wpan_nwkdst64() or f_wpan_nwkdst16()
    dst = tostring( dst )

    -- Add the result to the tree
    subtree:add(f_src, ChangeAddress(src) )
    subtree:add(f_srcname, GetLookup(src) )
    subtree:add(f_dst, ChangeAddress(dst) )
    subtree:add(f_dstname, GetLookup(dst) )
        
    if enable_map == true then
        if tostring( f_protocols() ) == "wpan:zbee_nwk" and tostring( f_zbeecmd() ) == "0x00000008" then
            AddNetworkMapLinkState()
        elseif tostring( f_protocols() ) == "wpan:zbee_nwk:zbee_aps:zbee_zcl" then
            AddNetworkMapDevice()
        end
    end  
end

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

-- Ensure that our dissector is invoked after dissection of a packet.
register_postdissector(wpanlookup)