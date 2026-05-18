// abis.js - All ABIs needed for the frontend

export const GAME_ITEMS_ABI = [
    "function balanceOf(address account, uint256 id) view returns (uint256)",
    "function mintItem(address to, uint256 itemId, uint256 amount)",
    "function createItem(string uri, uint256 maxSupply) returns (uint256)"
];

export const GAME_TOKEN_ABI = [
    "function balanceOf(address) view returns (uint256)",
    "function approve(address spender, uint256 amount) returns (bool)"
];

export const LOOT_DROP_ABI = [
    "function requestLoot()"
];

export const ETH_AMM_ABI = [
    "function swapEthForToken(uint256 minTokenOut) payable returns (uint256)",
    "function swapTokenForEth(uint256 tokenIn, uint256 minEthOut) returns (uint256)",
    "function getReserves() view returns (uint256, uint256)",
    "function getTokenOutForEthIn(uint256 ethIn) view returns (uint256)",
    "function getEthOutForTokenIn(uint256 tokenIn) view returns (uint256)"
];

// Keep these even if not used yet to avoid errors
export const RENTAL_VAULT_ABI = [
    "function deposit(uint256 assets, address receiver) returns (uint256)",
    "function withdraw(uint256 assets, address receiver, address owner) returns (uint256)",
    "function totalAssets() view returns (uint256)",
    "function convertToShares(uint256 assets) view returns (uint256)",
    "function rentItem(uint256 itemId, uint256 daysToRent)",
    "function setRentalPrice(uint256 itemId, uint256 pricePerDay)",
    "function rentalPrice(uint256) view returns (uint256)",
    "function activeRentals(uint256, address) view returns (uint256 expiry, uint256 itemId)",
    "function asset() view returns (address)",
    "function balanceOf(address) view returns (uint256)"
];

// Add to abis.js
export const GOVERNOR_ABI = [
    "function propose(address[] targets, uint256[] values, bytes[] calldatas, string description) returns (uint256)",
    "function castVote(uint256 proposalId, uint8 support)",
    "function state(uint256 proposalId) view returns (uint8)",
    "function proposalVotes(uint256 proposalId) view returns (uint256 againstVotes, uint256 forVotes, uint256 abstainVotes)",
    "function proposalCount() view returns (uint256)",
    "function quorum(uint256 blockNumber) view returns (uint256)",
    "function getDescription(uint256 proposalId) view returns (string)",
    "event ProposalCreated(uint256 indexed proposalId, address proposer, address[] targets, uint256[] values, string[] signatures, bytes[] calldatas, uint256 startBlock, uint256 endBlock, string description)"
];