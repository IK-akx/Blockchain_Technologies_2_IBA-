// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library YulHelper {
    /// @notice Square root using Newton's method (pure Solidity)
    function sqrtSolidity(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    /// @notice Square root using inline assembly (Yul)
    function sqrtYul(uint256 x) internal pure returns (uint256 y) {
        assembly {
            if iszero(x) { return(0, 0) }
            let z := add(div(x, 2), 1)
            y := x
            for {} lt(z, y) {} {
                y := z
                z := div(add(div(x, z), z), 2)
            }
        }
    }
}
