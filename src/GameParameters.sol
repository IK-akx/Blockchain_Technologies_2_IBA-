// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract GameParameters is AccessControl {
    bytes32 public constant GOVERNOR_ROLE = keccak256("GOVERNOR_ROLE");

    struct Params {
        uint256 dropRate; // базовый шанс дропа (1e6 = 100%)
        uint256 craftingCostMultiplier; // множитель стоимости крафта
        uint256 maxLootPerDay;
    }

    Params public params;

    event ParamsUpdated(uint256 dropRate, uint256 craftingCostMultiplier, uint256 maxLootPerDay);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        // начальные значения
        params = Params(500000, 100, 10); // 50% шанс, x1.00, 10 лута в день
    }

    function updateParams(Params calldata newParams) external onlyRole(GOVERNOR_ROLE) {
        params = newParams;
        emit ParamsUpdated(newParams.dropRate, newParams.craftingCostMultiplier, newParams.maxLootPerDay);
    }

    function grantGovernorRole(address governor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        _grantRole(GOVERNOR_ROLE, governor);
    }
}
