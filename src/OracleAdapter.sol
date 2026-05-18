// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract OracleAdapter {
    AggregatorV3Interface public priceFeed;
    uint256 public constant STALENESS_THRESHOLD = 1 hours;

    event PriceFetched(uint256 price, uint256 timestamp);

    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function getLatestPrice() public view returns (uint256) {
        (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();
        require(price > 0, "Oracle: invalid price");
        require(block.timestamp - updatedAt <= STALENESS_THRESHOLD, "Oracle: stale price");
        require(updatedAt != 0, "Oracle: no round data");
        return uint256(price);
    }
}
