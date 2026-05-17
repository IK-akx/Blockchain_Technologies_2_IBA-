// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./AMM.sol";
import "./RentalVault.sol";

contract GameFactory {
    event AMMCreated(address indexed ammAddress, address indexed creator);
    event VaultCreated(address indexed vaultAddress, bytes32 salt);

    function createAMM(address tokenA, address tokenB) external returns (address) {
        AMM newAMM = new AMM(tokenA, tokenB);
        emit AMMCreated(address(newAMM), msg.sender);
        return address(newAMM);
    }

    function createVaultDeterministic(bytes32 salt, address owner) external returns (address) {
        RentalVault vault = new RentalVault{salt: salt}(owner);
        emit VaultCreated(address(vault), salt);
        return address(vault);
    }

    function predictVaultAddress(bytes32 salt) external view returns (address) {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(abi.encodePacked(type(RentalVault).creationCode, abi.encode(address(0)))) // owner placeholder
            )
        );
        return address(uint160(uint256(hash)));
    }
}
