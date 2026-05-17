// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "forge-std/console.sol"; // убедитесь, что импорт есть вверху файла
import "../src/ResourceAMM.sol";
import "../src/YulHelper.sol";
import "../src/GameToken.sol";
import "../src/GameItems.sol";
import "../src/RentalVault4626.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Week8Test is Test {
    ResourceAMM public amm;
    RentalVault4626 public vault;
    GameToken public gameToken;
    GameItems public gameItems;
    ERC20Fixed public token0;
    ERC20Fixed public token1;

    address alice = address(0x123);
    address bob = address(0x456);
    address owner = address(0x789);

    function setUp() public {
        vm.startPrank(owner);

        // Deploy GameToken
        gameToken = new GameToken("GameToken", "GAME");
        gameToken.mint(alice, 10000 ether);
        gameToken.mint(bob, 10000 ether);

        // Deploy GameItems
        gameItems = new GameItems();
        gameItems.createItem("ipfs://test1", 1000);
        gameItems.createItem("ipfs://test2", 1000);

        // Deploy test ERC20 tokens for AMM
        token0 = new ERC20Fixed("T0", "T0", 18);
        token1 = new ERC20Fixed("T1", "T1", 18);

        token0.mint(alice, 10000 ether);
        token0.mint(bob, 10000 ether);
        token1.mint(alice, 10000 ether);
        token1.mint(bob, 10000 ether);

        // Deploy AMM
        amm = new ResourceAMM(address(token0), address(token1));

        // Deploy vault
        vault = new RentalVault4626(IERC20(address(gameToken)), IERC1155(address(gameItems)));

        vm.stopPrank();
    }

    // -------------------- Unit tests --------------------
    function test_AddLiquidity() public {
        vm.startPrank(alice);
        token0.approve(address(amm), 100 ether);
        token1.approve(address(amm), 100 ether);

        uint256 lp = amm.addLiquidity(100 ether, 100 ether, 0);

        assertGt(lp, 0);
        assertEq(amm.lpToken().balanceOf(alice), lp);
        assertEq(amm.reserve0(), 100 ether);
        assertEq(amm.reserve1(), 100 ether);
        vm.stopPrank();
    }

    function test_RemoveLiquidity() public {
        vm.startPrank(alice);
        token0.approve(address(amm), 100 ether);
        token1.approve(address(amm), 100 ether);

        uint256 lp = amm.addLiquidity(100 ether, 100 ether, 0);
        uint256 balanceBefore0 = token0.balanceOf(alice);
        uint256 balanceBefore1 = token1.balanceOf(alice);

        (uint256 amount0, uint256 amount1) = amm.removeLiquidity(lp, 0, 0);

        assertGt(amount0, 0);
        assertGt(amount1, 0);
        assertEq(token0.balanceOf(alice), balanceBefore0 + amount0);
        assertEq(token1.balanceOf(alice), balanceBefore1 + amount1);
        vm.stopPrank();
    }

    function test_Swap() public {
        vm.startPrank(alice);
        token0.approve(address(amm), 100 ether);
        token1.approve(address(amm), 100 ether);
        amm.addLiquidity(100 ether, 100 ether, 0);

        uint256 balanceBefore = token1.balanceOf(alice);
        token0.approve(address(amm), 10 ether);

        uint256 out = amm.swap(address(token0), address(token1), 10 ether, 0);

        assertGt(out, 0);
        assertEq(token1.balanceOf(alice), balanceBefore + out);
        vm.stopPrank();
    }

    function test_SwapRevertInsufficientOutput() public {
        vm.startPrank(alice);
        token0.approve(address(amm), 100 ether);
        token1.approve(address(amm), 100 ether);
        amm.addLiquidity(100 ether, 100 ether, 0);

        token0.approve(address(amm), 10 ether);

        vm.expectRevert("AMM: slippage");
        amm.swap(address(token0), address(token1), 10 ether, 1000 ether);
        vm.stopPrank();
    }

    function test_SwapRevertInvalidToken() public {
        vm.startPrank(alice);
        token0.approve(address(amm), 100 ether);
        token1.approve(address(amm), 100 ether);
        amm.addLiquidity(100 ether, 100 ether, 0);

        vm.expectRevert("AMM: invalid tokenIn");
        amm.swap(address(0x999), address(token1), 10 ether, 0);
        vm.stopPrank();
    }

    function test_VaultDepositWithdraw() public {
        vm.startPrank(alice);
        gameToken.approve(address(vault), 100 ether);

        uint256 shares = vault.deposit(100 ether, alice);
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.totalAssets(), 100 ether);

        uint256 assets = vault.redeem(shares, alice, alice);
        assertEq(assets, 100 ether);
        assertEq(vault.balanceOf(alice), 0);
        vm.stopPrank();
    }

    function test_VaultDepositWithdrawPartial() public {
        vm.startPrank(alice);
        gameToken.approve(address(vault), 100 ether);

        uint256 shares = vault.deposit(100 ether, alice);
        uint256 halfShares = shares / 2;

        uint256 assets = vault.redeem(halfShares, alice, alice);
        assertApproxEqAbs(assets, 50 ether, 1); // Allow rounding differences
        assertGt(vault.balanceOf(alice), 0);
        vm.stopPrank();
    }

    function test_VaultRentItem() public {
        vm.startPrank(owner);
        gameItems.mintItem(address(vault), 0, 10);
        vault.setRentalPrice(0, 1 ether); // 1 токен в день
        vm.stopPrank();

        vm.startPrank(alice);
        gameToken.approve(address(vault), 5 ether);

        uint256 balanceBefore = gameToken.balanceOf(alice);

        uint256 rentStart = block.timestamp;

        vault.rentItem(0, 2);

        assertEq(gameItems.balanceOf(alice, 0), 1);
        assertEq(gameToken.balanceOf(alice), balanceBefore - 2 ether);
        vm.stopPrank();

        // Было: vm.warp(rentStart + 2 days + 1);
        // Надо: перематываем на 1 день (время аренды еще не истекло)
        vm.warp(rentStart + 1 days); // Время аренды ещё активно

        vm.startPrank(alice);
        // Добавляем одобрение: Алиса разрешает хранилищу забрать NFT назад
        gameItems.setApprovalForAll(address(vault), true);

        vault.returnItem(0);
        vm.stopPrank();

        assertEq(gameItems.balanceOf(address(vault), 0), 10);
    }

    function test_VaultRentItemExpired() public {
        vm.startPrank(owner);
        gameItems.mintItem(address(vault), 0, 10);
        vault.setRentalPrice(0, 1 ether);
        vm.stopPrank();

        vm.startPrank(alice);
        gameToken.approve(address(vault), 5 ether);
        vault.rentItem(0, 1);

        vm.warp(block.timestamp + 2 days);

        vm.expectRevert("RentalVault: expired already");
        vault.returnItem(0);
        vm.stopPrank();
    }

    // -------------------- Fuzz tests --------------------
    function testFuzz_SwapNoArbitrage(uint256 amount0, uint256 amount1, uint256 swapAmount) public {
        amount0 = bound(amount0, 1 ether, 100 ether);
        amount1 = bound(amount1, 1 ether, 100 ether);
        swapAmount = bound(swapAmount, 0.01 ether, amount0 / 2);

        vm.startPrank(alice);

        ResourceAMM testAmm = new ResourceAMM(address(token0), address(token1));

        token0.mint(alice, amount0 + swapAmount);
        token1.mint(alice, amount1);

        token0.approve(address(testAmm), amount0);
        token1.approve(address(testAmm), amount1);
        testAmm.addLiquidity(amount0, amount1, 0);

        uint256 kBefore = testAmm.reserve0() * testAmm.reserve1();

        token0.approve(address(testAmm), swapAmount);
        testAmm.swap(address(token0), address(token1), swapAmount, 0);

        uint256 kAfter = testAmm.reserve0() * testAmm.reserve1();
        assertGe(kAfter, kBefore);

        vm.stopPrank();
    }

    function testFuzz_VaultDepositWithdrawRoundTrip(uint256 amount) public {
        vm.assume(amount >= 0.01 ether && amount <= 10000 ether);

        vm.startPrank(alice);
        gameToken.approve(address(vault), amount);

        uint256 shares = vault.deposit(amount, alice);
        assertGt(shares, 0);

        uint256 assets = vault.redeem(shares, alice, alice);
        assertApproxEqAbs(assets, amount, 1); // Allow 1 wei rounding error
        vm.stopPrank();
    }

    function testFuzz_DelegateVoting(address delegatee) public {
        vm.assume(delegatee != address(0));
        vm.assume(delegatee != alice);

        vm.prank(alice);
        gameToken.delegate(delegatee);
        assertEq(gameToken.delegates(alice), delegatee);
    }

    // -------------------- Invariant tests --------------------
    function invariant_TotalAssetsGeTotalSupply() public view {
        if (address(vault) != address(0)) {
            assertGe(vault.totalAssets(), vault.totalSupply());
        }
    }

    function invariant_ReservesNonNegative() public view {
        if (address(amm) != address(0)) {
            assertGe(amm.reserve0(), 0);
            assertGe(amm.reserve1(), 0);
        }
    }

    // -------------------- Benchmark test --------------------
    function test_GasBenchmark() public {
        uint256 x = 12345678901234567890;
        uint256 y1;
        uint256 y2;

        uint256 gasStart = gasleft();
        y1 = YulHelper.sqrtSolidity(x);
        uint256 gasSol = gasStart - gasleft();

        gasStart = gasleft();
        y2 = YulHelper.sqrtYul(x);
        uint256 gasYul = gasStart - gasleft();

        assertEq(y1, y2);

        emit log_named_uint("Gas Solidity sqrt", gasSol);
        emit log_named_uint("Gas Yul sqrt", gasYul);
        emit log_named_uint("Gas saved (Yul better)", gasSol - gasYul);
    }
}

// Helper ERC20 for testing
contract ERC20Fixed is ERC20 {
    uint8 private _decimals;

    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
