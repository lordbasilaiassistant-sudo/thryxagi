export const LAUNCHPAD_ABI = [
  "function launch(string name_, string symbol_, uint256 supply_, uint256 obsdSeed_, uint256 poolPercent_, address creatorPayout_) returns (address token, address pool)",
  "function totalLaunches() view returns (uint256)",
  "function launches(uint256) view returns (address token, address pool, address creator, string name, string symbol, uint256 supply, uint256 obsdSeeded, uint256 timestamp)",
  "function getCreatorLaunches(address creator_) view returns (uint256[])",
  "function symbolTaken(string) view returns (bool)",
  "function obsd() view returns (address)",
  "function treasury() view returns (address)",
  "function owner() view returns (address)",
] as const;

export const PLATFORM_ROUTER_ABI = [
  "function quoteETHToChild(address childToken, uint256 ethAmount) view returns (uint256)",
  "function quoteChildToETH(address childToken, uint256 childAmount) view returns (uint256)",
  "function totalETHFees() view returns (uint256)",
  "function PLATFORM_FEE_BPS() view returns (uint256)",
] as const;

export const CREATOR_TOKEN_ABI = [
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function totalSupply() view returns (uint256)",
  "function balanceOf(address) view returns (uint256)",
  "function creator() view returns (address)",
  "function treasury() view returns (address)",
  "function pool() view returns (address)",
  "function totalBurned() view returns (uint256)",
  "function totalOBSDToCreator() view returns (uint256)",
  "function totalOBSDToTreasury() view returns (uint256)",
  "function pendingFees() view returns (uint256)",
  "function getSellTax(address) view returns (uint256)",
  "function holdTime(address) view returns (uint256)",
  "function TOTAL_FEE_BPS() view returns (uint256)",
  "function BURN_FEE_BPS() view returns (uint256)",
  "function CREATOR_FEE_BPS() view returns (uint256)",
  "function TREASURY_FEE_BPS() view returns (uint256)",
] as const;

export const ERC20_ABI = [
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function totalSupply() view returns (uint256)",
  "function balanceOf(address) view returns (uint256)",
  "function decimals() view returns (uint8)",
] as const;
