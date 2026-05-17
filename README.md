# GameFi Economy — Option B

Blockchain Technologies 2 — Final Project

## Team

| Role | Name |
|------|------|
| Smart Contract Lead | [Имя] |
| Testing & Security Lead | [Имя] |
| Frontend & Subgraph Lead | [Имя] |

## Scenario

**Option B — GameFi Economy**: ERC-1155 items, crafting, AMM for resources, NFT rental vault, Chainlink VRF, DAO governance, L2 deployment.

## Tech Stack

- Foundry (Solidity 0.8.24)
- OpenZeppelin contracts
- Chainlink VRF + Price Feeds
- The Graph
- React + Wagmi/Viem
- L2: Arbitrum Sepolia

## Project Structure
src/ # smart contracts
test/ # forge tests (unit, fuzz, invariant, fork)
script/ # deployment scripts
frontend/ # dApp (to be added)
subgraph/ # The Graph configuration
docs/ # architecture, audit, gas reports


## Setup

```bash
forge install
forge build
forge test
```

## CI
GitHub Actions runs:
- forge build
- forge test
- forge fmt --check
- solhint
- forge coverage

