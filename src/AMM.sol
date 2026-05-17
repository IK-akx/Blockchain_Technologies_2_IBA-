// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract AMM {
    address public tokenA;
    address public tokenB;

    constructor(address _tokenA, address _tokenB) {
        require(_tokenA != address(0), "AMM: zero tokenA");
        require(_tokenB != address(0), "AMM: zero tokenB");
        tokenA = _tokenA;
        tokenB = _tokenB;
    }
}
