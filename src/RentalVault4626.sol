// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title RentalVault
 * @notice ERC4626 vault that accepts GameToken (asset) and allows renting ERC1155 items.
 *         Rent fees are distributed to depositors.
 */
contract RentalVault4626 is ERC4626, Ownable, ReentrancyGuard, ERC1155Holder {
    using SafeERC20 for IERC20;
    IERC1155 public immutable nftContract;
    mapping(uint256 => uint256) public rentalPrice; // per itemId per day (in asset)
    mapping(uint256 => mapping(address => Rental)) public activeRentals;

    struct Rental {
        uint256 expiry;
        uint256 itemId;
    }

    event ItemRented(address indexed renter, uint256 indexed itemId, uint256 expiry, uint256 fee);
    event RentalPriceSet(uint256 indexed itemId, uint256 price);

    constructor(IERC20 _asset, IERC1155 _nftContract)
        ERC4626(_asset)
        ERC20("Rental Vault Share", "rVS")
        Ownable(msg.sender)
    {
        nftContract = _nftContract;
    }

    // ---- ERC4626 overrides (rounding invariants) ----
    // OpenZeppelin implementation already follows rounding rules.
    // We add no custom rounding.

    // ---- rent functionality ----
    function setRentalPrice(uint256 itemId, uint256 pricePerDay) external onlyOwner {
        rentalPrice[itemId] = pricePerDay;
        emit RentalPriceSet(itemId, pricePerDay);
    }

    function rentItem(uint256 itemId, uint256 daysToRent) external nonReentrant {
        require(rentalPrice[itemId] > 0, "RentalVault: price not set");
        uint256 fee = rentalPrice[itemId] * daysToRent;
        require(IERC20(asset()).balanceOf(msg.sender) >= fee, "RentalVault: insufficient balance");
        require(activeRentals[itemId][msg.sender].expiry < block.timestamp, "RentalVault: already renting");

        IERC20(asset()).safeTransferFrom(msg.sender, address(this), fee);
        activeRentals[itemId][msg.sender] = Rental(block.timestamp + daysToRent * 1 days, itemId);

        nftContract.safeTransferFrom(address(this), msg.sender, itemId, 1, "");
        emit ItemRented(msg.sender, itemId, block.timestamp + daysToRent * 1 days, fee);
    }

    function returnItem(uint256 itemId) external {
        Rental memory rental = activeRentals[itemId][msg.sender];
        require(rental.expiry > 0, "RentalVault: not rented");
        require(block.timestamp <= rental.expiry, "RentalVault: expired already");
        delete activeRentals[itemId][msg.sender];
        nftContract.safeTransferFrom(msg.sender, address(this), itemId, 1, "");
    }

    // --- ensure rounding invariants are met (tested separately) ---
}
