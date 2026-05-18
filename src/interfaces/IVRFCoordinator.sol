// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface VRFCoordinatorV2Interface {
    function requestRandomWords(
        bytes32 keyHash,
        uint256 subId,
        uint16 confirmations,
        uint32 callbackGasLimit,
        uint32 numWords
    ) external returns (uint256 requestId);
}