local ADB = AuctionDB

function ADB:AHendOfScanCB() end

local function invalidate() ADB:AHendOfScanCB() end
ADB:Listen("SCAN_DATA", invalidate)
ADB:Listen("HISTORY_MERGED", invalidate)
ADB:Listen("LOGIN", invalidate)

function ADB:AHGetAuctionInfoByLink(link)
  local id = tonumber(link and link:match("item:(%d+)"))
  if not id or not self.sv then return end
  local house = self:ViewHouse()
  local h = self:SavedHouse(house)
  if not h then return end
  local p = self:LastPrice(id, house)
  local scan = h.scans[#h.scans]
  if p and p[2] and p[2] > 0 and p[1] >= (scan and scan[1] or 0) then
    return {minBuyout = p[2]}
  end
end
