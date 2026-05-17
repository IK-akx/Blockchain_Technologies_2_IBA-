# Factory Patterns Justification

## CREATE
Used in `createAMM` – each AMM instance is unique and does not need deterministic address. Simple and cheap.

## CREATE2
Used in `createVaultDeterministic` – allows precomputation of vault address before deployment. Useful for:
- Cross-chain deployments (same address on L2)
- Upgradable meta-transactions
- Counterfactual instantiation