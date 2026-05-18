// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract LPToken is IERC20, Ownable {
    using SafeERC20 for IERC20;

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    address public minter;

    modifier onlyMinter() {
        require(msg.sender == minter, "LPToken: not minter");
        _;
    }

    constructor(address _minter, string memory _name, string memory _symbol) Ownable(msg.sender) {
        minter = _minter;
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external onlyMinter {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function burn(address from, uint256 amount) external onlyMinter {
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
        return true;
    }
}

contract ETHAMM is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable token;
    uint256 public reserveToken;
    uint256 public reserveETH;
    uint256 public constant FEE = 30; // 0.3% (30 / 10000)
    
    LPToken public lpToken;

    event LiquidityAdded(address indexed provider, uint256 tokenAmount, uint256 ethAmount, uint256 lpMinted);
    event LiquidityRemoved(address indexed provider, uint256 tokenAmount, uint256 ethAmount, uint256 lpBurned);
    event Swap(address indexed user, bool tokenToEth, uint256 amountIn, uint256 amountOut);

    constructor(address _token) Ownable(msg.sender) {
        require(_token != address(0), "AMM: zero token address");
        token = IERC20(_token);
        lpToken = new LPToken(address(this), "ETHAMM LP Token", "EALP");
    }

    // Add liquidity - send tokens and ETH
    function addLiquidity(uint256 tokenAmount, uint256 minLp) 
        external 
        payable 
        nonReentrant 
        returns (uint256 lpMinted) 
    {
        require(tokenAmount > 0, "AMM: token amount must be > 0");
        require(msg.value > 0, "AMM: ETH amount must be > 0");
        
        // Transfer tokens from user
        token.safeTransferFrom(msg.sender, address(this), tokenAmount);
        
        if (reserveToken == 0 && reserveETH == 0) {
            // First deposit: lp = sqrt(tokenAmount * ethAmount)
            lpMinted = _sqrt(tokenAmount * msg.value);
        } else {
            uint256 lpSupply = lpToken.totalSupply();
            uint256 mintByToken = (lpSupply * tokenAmount) / reserveToken;
            uint256 mintByEth = (lpSupply * msg.value) / reserveETH;
            lpMinted = mintByToken < mintByEth ? mintByToken : mintByEth;
        }
        
        require(lpMinted >= minLp, "AMM: insufficient LP received");
        
        reserveToken += tokenAmount;
        reserveETH += msg.value;
        lpToken.mint(msg.sender, lpMinted);
        
        emit LiquidityAdded(msg.sender, tokenAmount, msg.value, lpMinted);
        
        return lpMinted;
    }

    // Remove liquidity
    function removeLiquidity(uint256 lpAmount, uint256 minToken, uint256 minEth) 
        external 
        nonReentrant 
        returns (uint256 tokenAmount, uint256 ethAmount) 
    {
        require(lpAmount > 0, "AMM: LP amount must be > 0");
        
        uint256 lpSupply = lpToken.totalSupply();
        tokenAmount = (lpAmount * reserveToken) / lpSupply;
        ethAmount = (lpAmount * reserveETH) / lpSupply;
        
        require(tokenAmount >= minToken, "AMM: insufficient token output");
        require(ethAmount >= minEth, "AMM: insufficient ETH output");
        
        reserveToken -= tokenAmount;
        reserveETH -= ethAmount;
        lpToken.burn(msg.sender, lpAmount);
        
        token.safeTransfer(msg.sender, tokenAmount);
        payable(msg.sender).transfer(ethAmount);
        
        emit LiquidityRemoved(msg.sender, tokenAmount, ethAmount, lpAmount);
        
        return (tokenAmount, ethAmount);
    }

    // Swap ETH for Token
    function swapEthForToken(uint256 minTokenOut) 
        external 
        payable 
        nonReentrant 
        returns (uint256 tokenOut) 
    {
        require(msg.value > 0, "AMM: zero ETH input");
        
        uint256 ethIn = msg.value;
        uint256 fee = (ethIn * FEE) / 10000;
        uint256 ethInAfterFee = ethIn - fee;
        
        tokenOut = (ethInAfterFee * reserveToken) / (reserveETH + ethInAfterFee);
        require(tokenOut >= minTokenOut, "AMM: slippage");
        require(tokenOut <= reserveToken, "AMM: insufficient liquidity");
        
        reserveETH += ethIn;
        reserveToken -= tokenOut;
        
        token.safeTransfer(msg.sender, tokenOut);
        emit Swap(msg.sender, false, ethIn, tokenOut);
        
        return tokenOut;
    }

    // Swap Token for ETH
    function swapTokenForEth(uint256 tokenIn, uint256 minEthOut) 
        external 
        nonReentrant 
        returns (uint256 ethOut) 
    {
        require(tokenIn > 0, "AMM: zero token input");
        
        token.safeTransferFrom(msg.sender, address(this), tokenIn);
        
        uint256 fee = (tokenIn * FEE) / 10000;
        uint256 tokenInAfterFee = tokenIn - fee;
        
        ethOut = (tokenInAfterFee * reserveETH) / (reserveToken + tokenInAfterFee);
        require(ethOut >= minEthOut, "AMM: slippage");
        require(ethOut <= reserveETH, "AMM: insufficient liquidity");
        
        reserveToken += tokenIn;
        reserveETH -= ethOut;
        
        payable(msg.sender).transfer(ethOut);
        emit Swap(msg.sender, true, tokenIn, ethOut);
        
        return ethOut;
    }

    // Get expected token out for ETH in
    function getTokenOutForEthIn(uint256 ethIn) external view returns (uint256) {
        if (reserveETH == 0) return 0;
        uint256 fee = (ethIn * FEE) / 10000;
        uint256 ethInAfterFee = ethIn - fee;
        return (ethInAfterFee * reserveToken) / (reserveETH + ethInAfterFee);
    }

    // Get expected ETH out for token in
    function getEthOutForTokenIn(uint256 tokenIn) external view returns (uint256) {
        if (reserveToken == 0) return 0;
        uint256 fee = (tokenIn * FEE) / 10000;
        uint256 tokenInAfterFee = tokenIn - fee;
        return (tokenInAfterFee * reserveETH) / (reserveToken + tokenInAfterFee);
    }

    // Get reserves
    function getReserves() external view returns (uint256, uint256) {
        return (reserveToken, reserveETH);
    }

    // Internal sqrt function
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