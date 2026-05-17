// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title ResourceAMM
 * @notice Constant product AMM (x*y=k) for two fungible resources.
 *         Fee = 0.3%, LP tokens represent share of the pool.
 */
contract ResourceAMM is Ownable {
    using SafeERC20 for ERC20;

    ERC20 public immutable token0;
    ERC20 public immutable token1;
    uint256 public reserve0;
    uint256 public reserve1;
    uint256 public constant FEE = 3; // 0.3% (3 / 1000)

    // LP token (ERC20) – simple implementation
    LPToken public lpToken;

    event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1, uint256 lpMinted);
    event LiquidityRemoved(address indexed provider, uint256 amount0, uint256 amount1, uint256 lpBurned);
    event Swap(address indexed user, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);

    constructor(address _token0, address _token1) Ownable(msg.sender) {
        require(_token0 != address(0) && _token1 != address(0), "AMM: zero address");
        require(_token0 != _token1, "AMM: same token");
        token0 = ERC20(_token0);
        token1 = ERC20(_token1);
        // FIX: minter должен быть сам AMM (address(this)), а не msg.sender
        lpToken = new LPToken(address(this), "ResourceAMM LP", "RAML");
    }

    // ---- core ----

    function addLiquidity(uint256 amount0, uint256 amount1, uint256 minLp) external returns (uint256 lpMinted) {
        require(amount0 > 0 && amount1 > 0, "AMM: zero amounts");
        token0.safeTransferFrom(msg.sender, address(this), amount0);
        token1.safeTransferFrom(msg.sender, address(this), amount1);

        if (reserve0 == 0 && reserve1 == 0) {
            // initial mint – lp = sqrt(amount0 * amount1)
            lpMinted = _sqrt(amount0 * amount1);
        } else {
            uint256 lpSupply = lpToken.totalSupply();
            uint256 mint0 = (lpSupply * amount0) / reserve0;
            uint256 mint1 = (lpSupply * amount1) / reserve1;
            lpMinted = mint0 < mint1 ? mint0 : mint1;
        }
        require(lpMinted >= minLp, "AMM: insufficient LP received");

        reserve0 += amount0;
        reserve1 += amount1;
        lpToken.mint(msg.sender, lpMinted);
        emit LiquidityAdded(msg.sender, amount0, amount1, lpMinted);
    }

    function removeLiquidity(uint256 lpAmount, uint256 minAmount0, uint256 minAmount1)
        external
        returns (uint256 amount0, uint256 amount1)
    {
        require(lpAmount > 0, "AMM: zero LP");
        uint256 lpSupply = lpToken.totalSupply();
        amount0 = (lpAmount * reserve0) / lpSupply;
        amount1 = (lpAmount * reserve1) / lpSupply;
        require(amount0 >= minAmount0 && amount1 >= minAmount1, "AMM: slippage");

        reserve0 -= amount0;
        reserve1 -= amount1;
        lpToken.burn(msg.sender, lpAmount);
        token0.safeTransfer(msg.sender, amount0);
        token1.safeTransfer(msg.sender, amount1);
        emit LiquidityRemoved(msg.sender, amount0, amount1, lpAmount);
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut)
        external
        returns (uint256 amountOut)
    {
        require(amountIn > 0, "AMM: zero input");
        require(tokenIn == address(token0) || tokenIn == address(token1), "AMM: invalid tokenIn");
        require(tokenOut == address(token0) || tokenOut == address(token1), "AMM: invalid tokenOut");
        require(tokenIn != tokenOut, "AMM: same token");

        (ERC20 inToken, uint256 reserveIn, uint256 reserveOut) =
            tokenIn == address(token0) ? (token0, reserve0, reserve1) : (token1, reserve1, reserve0);

        inToken.safeTransferFrom(msg.sender, address(this), amountIn);
        // amountOut = (amountIn * reserveOut * (1000 - FEE)) / (reserveIn * 1000 + amountIn * (1000 - FEE))
        uint256 numerator = amountIn * reserveOut * (1000 - FEE);
        uint256 denominator = reserveIn * 1000 + amountIn * (1000 - FEE);
        amountOut = numerator / denominator;
        require(amountOut >= minAmountOut, "AMM: slippage");

        if (tokenOut == address(token0)) {
            token0.safeTransfer(msg.sender, amountOut);
            reserve0 -= amountOut;
            reserve1 += amountIn;
        } else {
            token1.safeTransfer(msg.sender, amountOut);
            reserve1 -= amountOut;
            reserve0 += amountIn;
        }
        emit Swap(msg.sender, tokenIn, tokenOut, amountIn, amountOut);
    }

    // ---- helpers ----
    function _sqrt(uint256 y) internal pure returns (uint256 z) {
        if (y > 3) {
            z = y;
            uint256 x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}

// ---- simple ERC20 for LP ----
contract LPToken is ERC20 {
    address public minter;
    modifier onlyMinter() {
        require(msg.sender == minter, "LPToken: not minter");
        _;
    }

    constructor(address _minter, string memory name, string memory symbol) ERC20(name, symbol) {
        minter = _minter;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyMinter {
        _burn(from, amount);
    }
}
