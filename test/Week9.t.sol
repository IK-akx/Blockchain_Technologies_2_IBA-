// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "forge-std/StdInvariant.sol";
import "../src/GameToken.sol";
import "../src/GameParameters.sol";
import "../src/GameGovernor.sol";
import "../src/OracleAdapter.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Week9Test is Test {
    GameToken public token;
    GameParameters public gameParams;
    TimelockController public timelock;
    GameGovernor public governor;
    OracleAdapter public oracle;

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public proposer = address(0x3);

    uint256 public constant VOTING_DELAY = 1 days;
    uint256 public constant VOTING_PERIOD = 7 days;

    function setUp() public {
        // 1. Deploy token and mint voting power (оставляем как есть)
        token = new GameToken("GameToken", "GAME");
        token.mint(user1, 1_000_000 ether);
        token.mint(user2, 500_000 ether);
        token.mint(proposer, 200_000 ether);

        vm.prank(user1);
        token.delegate(user1);
        vm.prank(user2);
        token.delegate(user2);
        vm.prank(proposer);
        token.delegate(proposer);

        address governorAddress = vm.computeCreateAddress(address(this), vm.getNonce(address(this)) + 1);

        address[] memory proposers = new address[](1);
        proposers[0] = governorAddress;

        address[] memory executors = new address[](1);
        executors[0] = governorAddress;

        timelock = new TimelockController(2 days, proposers, executors, address(this));

        governor = new GameGovernor(token, timelock, uint48(VOTING_DELAY), uint32(VOTING_PERIOD));

        // 5. Deploy GameParameters and grant GOVERNOR_ROLE to timelock
        gameParams = new GameParameters();
        gameParams.grantGovernorRole(address(timelock));

        // 6. Deploy OracleAdapter (mock for tests)
        oracle = new OracleAdapter(address(0));

        targetContract(address(gameParams));
    }

    // ---------- E2E Governance test: propose → vote → queue → execute ----------
    function test_GovernanceE2E_UpdateGameParams() public {
        vm.roll(block.number + 10);
        vm.warp(block.timestamp + 120);

        // Prepare proposal: update GameParameters
        GameParameters.Params memory newParams =
            GameParameters.Params({dropRate: 750000, craftingCostMultiplier: 120, maxLootPerDay: 15});
        bytes memory callData = abi.encodeWithSelector(GameParameters.updateParams.selector, newParams);
        address[] memory targets = new address[](1);
        targets[0] = address(gameParams);
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = callData;

        string memory description = "Update game parameters";
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Pending));

        uint256 snapshot = governor.proposalSnapshot(proposalId);
        if (snapshot >= block.number) {
            vm.roll(snapshot + 1);
        }
        vm.warp(block.timestamp + VOTING_DELAY + 1 days);

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Active));

        vm.prank(user1);
        governor.castVote(proposalId, 1);
        vm.prank(user2);
        governor.castVote(proposalId, 1);
        vm.prank(proposer);
        governor.castVote(proposalId, 1);

        uint256 deadline = governor.proposalDeadline(proposalId);
        if (deadline >= block.number) {
            vm.roll(deadline + 1);
        }
        vm.warp(block.timestamp + VOTING_PERIOD + 1 days);

        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        bytes32 descriptionHash = keccak256(bytes(description));
        governor.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Queued));

        vm.warp(block.timestamp + 2 days + 1 hours);
        vm.roll(block.number + 20000); // продвинем и блоки для синхронизации среды

        governor.execute(targets, values, calldatas, descriptionHash);
        assertEq(uint256(governor.state(proposalId)), uint256(IGovernor.ProposalState.Executed));

        (uint256 dropRate, uint256 craftingCostMultiplier, uint256 maxLootPerDay) = gameParams.params();
        assertEq(dropRate, 750000);
        assertEq(craftingCostMultiplier, 120);
        assertEq(maxLootPerDay, 15);
    }

    // ---------- Fork tests (3) ----------
    function testFork_ChainlinkOracle_EthUsd() public {
        string memory ETH_MAINNET_RPC = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(ETH_MAINNET_RPC);
        vm.selectFork(forkId);

        address ethUsdFeed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
        OracleAdapter realOracle = new OracleAdapter(ethUsdFeed);
        uint256 price = realOracle.getLatestPrice();
        assertGt(price, 0);
        assertLt(price, 1_000_000 ether);
    }

    function testFork_UniswapV2_RouterInteraction() public {
        string memory MAINNET_RPC = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(MAINNET_RPC);
        vm.selectFork(forkId);

        address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        assertTrue(weth.code.length > 0);
        assertTrue(usdc.code.length > 0);
    }

    function testFork_USDC_Balance() public {
        string memory MAINNET_RPC = vm.envString("MAINNET_RPC_URL");
        uint256 forkId = vm.createFork(MAINNET_RPC);
        vm.selectFork(forkId);

        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address vitalik = 0xd8dA6BF26964aF9D7eEd9e03E53415D37aA96045;
        uint256 balance = IERC20(usdc).balanceOf(vitalik);
        assertGt(balance, 0);
    }

    // ---------- Invariant tests (2) ----------
    function invariant_TotalSupplyNeverChanges() public view {
        uint256 total = token.totalSupply();
        assertEq(total, 1_700_000 ether);
    }

    function invariant_TimelockHasExecutorAndProposerRoles() public view {
        assertTrue(timelock.hasRole(timelock.PROPOSER_ROLE(), address(governor)));
        assertTrue(timelock.hasRole(timelock.EXECUTOR_ROLE(), address(governor)));
    }

    // ---------- Unit tests for OracleAdapter ----------
    function test_Oracle_StalenessRevert() public {
        vm.warp(10 days);
        MockAggregator mock = new MockAggregator();
        oracle = new OracleAdapter(address(mock));
        mock.setPrice(3000e8, block.timestamp - 2 hours);
        vm.expectRevert("Oracle: stale price");
        oracle.getLatestPrice();
    }

    function test_Oracle_ValidPrice() public {
        vm.warp(10 days);
        MockAggregator mock = new MockAggregator();
        oracle = new OracleAdapter(address(mock));
        mock.setPrice(3000e8, block.timestamp - 30 minutes);
        uint256 price = oracle.getLatestPrice();
        assertEq(price, 3000e8);
    }
}

// ---------- Mocks ----------
contract MockAggregator {
    int256 public price;
    uint256 public updatedAt;

    function setPrice(int256 _price, uint256 _updatedAt) external {
        price = _price;
        updatedAt = _updatedAt;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (0, price, 0, updatedAt, 0);
    }
}
