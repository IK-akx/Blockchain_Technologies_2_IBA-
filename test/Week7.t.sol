// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/GameToken.sol";
import "../src/GameItems.sol";
import "../src/GameFactory.sol";
import "../src/RentalVault.sol";
import "../src/AMM.sol";

contract Week7Test is Test {
    GameToken public token;
    GameItems public items;
    GameFactory public factory;
    RentalVault public vault;
    AMM public amm;

    address owner = address(0x123);
    address user = address(0x456);

    function setUp() public {
        vm.startPrank(owner);
        token = new GameToken("GameToken", "GAME");
        items = new GameItems();
        factory = new GameFactory();
        vm.stopPrank();
    }

    function test_GameTokenMint() public {
        vm.prank(owner);
        token.mint(user, 1000 ether);
        assertEq(token.balanceOf(user), 1000 ether);
    }

    function test_GameTokenTransferAndVotes() public {
        vm.prank(owner);
        token.mint(user, 1000 ether);
        vm.prank(user);
        token.transfer(owner, 500 ether);
        assertEq(token.balanceOf(user), 500 ether);
        // check voting power (delegates to self by default after transfer)
        vm.prank(user);
        token.delegate(user);
        assertEq(token.getVotes(user), 500 ether);
    }

    function test_GameItemsCreateAndMint() public {
        vm.prank(owner);
        uint256 itemId = items.createItem("ipfs://test", 100);
        vm.prank(owner);
        items.mintItem(user, itemId, 10);
        assertEq(items.balanceOf(user, itemId), 10);
        (string memory uri, uint256 maxSupply, uint256 currentSupply, bool exists) = items.itemInfo(itemId);
        assertEq(uri, "ipfs://test");
        assertEq(maxSupply, 100);
        assertEq(currentSupply, 10);
        assertTrue(exists);
    }

    function test_FactoryCreateAMM() public {
        address tokenA = address(0xAAA);
        address tokenB = address(0xBBB);
        vm.prank(user);
        address ammAddr = factory.createAMM(tokenA, tokenB);
        amm = AMM(ammAddr);
        assertEq(amm.tokenA(), tokenA);
        assertEq(amm.tokenB(), tokenB);
    }

    function test_FactoryCreate2Vault() public {
        bytes32 salt = keccak256("test_salt");
        vm.prank(user);
        address vaultAddr = factory.createVaultDeterministic(salt, user);
        assertTrue(vaultAddr != address(0));
        vault = RentalVault(vaultAddr);
        assertEq(vault.version(), 1);
        assertEq(vault.owner(), user);
    }
}