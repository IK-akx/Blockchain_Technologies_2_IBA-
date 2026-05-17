# GameFi Economy Protocol Architecture

## Project Overview

This project is a GameFi economy protocol developed for the Blockchain Technologies 2 final project.

The protocol combines:
- ERC20 governance/resource token
- ERC1155 in-game item economy
- Constant-product AMM marketplace
- ERC4626 tokenized vault
- NFT rental vault
- Loot drop mechanics
- DAO governance
- Layer 2 deployment

---

## Core Contracts

### GameToken.sol
ERC20 governance token with ERC20Votes and ERC20Permit extensions.

### GameItems.sol
ERC1155 contract used for in-game items and inventory management.

### ResourceAMM.sol
Constant-product AMM for swapping fungible game resources.

### RentalVault.sol
NFT rental vault for temporary item lending.

### RentalVault4626.sol
ERC4626 tokenized vault implementation.

### LootDrop.sol
Loot drop contract integrated with randomness mechanics.

### GameFactory.sol
Factory contract for deploying protocol components.

### YulHelper.sol
Yul assembly optimization helper contract.