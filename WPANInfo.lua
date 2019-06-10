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
local f_framenr          = Field.new("frame.number")

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
    subtree:add(f_src, src )
    subtree:add(f_srcname, GetLookup(src) )
    subtree:add(f_dst, dst )
    subtree:add(f_dstname, GetLookup(dst) )
end

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

-- Ensure that our dissector is invoked after dissection of a packet.
register_postdissector(wpanlookup)