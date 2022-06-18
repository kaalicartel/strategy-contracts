// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IEllipsisRouter {
    function sellARTHForExactBUSD(
        uint256 amountArthInMax,
        uint256 amountBUSDOut,
        address to,
        uint256 deadline
    ) external;

    function buyARTHForExactBUSD(
        uint256 amountBUSDIn,
        uint256 amountARTHOutMin,
        address to,
        uint256 deadline
    ) external;

    function sellARTHforToken(
        int128 tokenId, // 1 -> busd, 2 -> usdc, 3 -> usdt
        uint256 amountARTHin,
        address to,
        uint256 deadline
    ) external;

    function estimateARTHtoSell(uint256 busdNeeded)
        external
        view
        returns (uint256);

    function estimateARTHtoBuy(uint256 busdToSell)
        external
        view
        returns (uint256);
}
