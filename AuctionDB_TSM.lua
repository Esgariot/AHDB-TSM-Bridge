local ADB = AuctionDB

local reported = {}
local function report(msg)
  if reported[msg] then return end
  reported[msg] = true
  local version = type(ADB) == "table" and ADB.version or "?"
  print(("|cFFFF8000AHDB TSM bridge:|r %s (AHDB %s)"):format(msg, tostring(version)))
end

local function missingApi()
  if type(ADB) ~= "table" then return "the AuctionDB global" end
  for _, name in ipairs({"Listen", "ViewHouse", "SavedHouse", "HouseKey", "LastPrice"}) do
    if type(ADB[name]) ~= "function" then return "AuctionDB:" .. name .. "()" end
  end
end

local missing = missingApi()
if missing then
  report("disabled, AHDB no longer provides " .. missing)
  return
end

function ADB:AHendOfScanCB() end

local function readBids(self, e)
  local scans = self.scanHouse and self.scanHouse.scans
  local last = scans and scans[#scans]
  local ts = last and last[1]
  if not ts then return nil, "SCAN_DATA without a recorded scan" end
  local key = self:HouseKey(self.scanHouseName)
  if not key then return nil, "SCAN_DATA without an auction house" end
  local bids = {ts = ts}
  for k = 1, e.n do
    local b = e.topBid[k] or e.bid[k]
    if b > 0 then
      local id, u = e.item[k], math.floor(b / e.count[k])
      bids[id] = math.min(bids[id] or u, u)
    end
  end
  return key, bids
end

local function store(key, bids)
  if type(AuctionDB_TSMSaved) ~= "table" then
    if AuctionDB_TSMSaved ~= nil then report("saved bids were not a table, starting over") end
    AuctionDB_TSMSaved = {}
  end
  AuctionDB_TSMSaved[key] = bids
end

ADB:Listen("SCAN_DATA", function(self, e)
  local ok, key, bids = pcall(readBids, self, e)
  if not ok then return report("bids not saved: " .. tostring(key)) end
  if not key then return report("bids not saved: " .. tostring(bids)) end
  store(key, bids)
end)

local function invalidate() ADB:AHendOfScanCB() end
ADB:Listen("SCAN_DATA", invalidate)
ADB:Listen("HISTORY_MERGED", invalidate)
ADB:Listen("LOGIN", invalidate)

local function lookup(self, link)
  local id = tonumber(link and link:match("item:(%d+)"))
  if not id or not self.sv then return end
  local house = self:ViewHouse()
  local h = self:SavedHouse(house)
  if not h then return end
  local p = self:LastPrice(id, house)
  local scan = h.scans[#h.scans]
  local ts = scan and scan[1] or 0
  local sv = AuctionDB_TSMSaved
  local bids = type(sv) == "table" and sv[self:HouseKey(house)]
  local info = {}
  if p and p[2] and p[2] > 0 and p[1] >= ts then info.minBuyout = p[2] end
  if bids and bids.ts == ts then info.minBid = bids[id] end
  if info.minBuyout or info.minBid then return info end
end

function ADB:AHGetAuctionInfoByLink(link)
  local ok, info = pcall(lookup, self, link)
  if ok then return info end
  report("price lookup failed: " .. tostring(info))
end
