// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IBorrowerOperations} from "../../interfaces/loans/IBorrowerOperations.sol";
import {IEllipsisRouter} from "../../interfaces/IEllipsisRouter.sol";
import {IERC20, IERC20WithDecimals} from "../../interfaces/IERC20WithDecimals.sol";
import {IERC20Wrapper} from "../../interfaces/IERC20Wrapper.sol";
import {IStableSwap} from "../../interfaces/IStableSwap.sol";
import {IUniswapV2Router02} from "../../interfaces/uniswap/IUniswapV2Router02.sol";
import {IZapDepositor} from "../../interfaces/IZapDepositor.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract EPSPegTrader {
    using SafeMath for uint256;

    IERC20WithDecimals public lp;
    IZapDepositor public zap;
    address public pool;

    IERC20Wrapper public arthUsd;
    IERC20WithDecimals public arth;
    IERC20WithDecimals public busd;
    IERC20WithDecimals public wbnb;

    address private me;
    IEllipsisRouter public router;
    IUniswapV2Router02 public pancakeswap;
    IBorrowerOperations borrowerOperations;

    function repegARTHWhenAbovePeg() external {
        // flashloan arth
        uint256 flashloanAmount;

        // we have arth; sell it for busd to bring it back to the peg
        // take the busd profits and convert it into bnb
        // deposit bnb into the trove
        // mint arth and payback flashloan

        uint256 busdToSell;
        router.estimateARTHtoBuy(busdToSell);

        uint256 busdProfits;
        uint256 bnbOutMin;

        address[] memory path = new address[](2);
        path[0] = address(busd);
        path[1] = address(wbnb);

        pancakeswap.swapExactTokensForETH(
            busdProfits,
            bnbOutMin,
            path,
            me,
            block.timestamp
        );

        uint256 _maxFee;
        borrowerOperations.adjustTrove{value: me.balance}(
            _maxFee,
            0,
            flashloanAmount,
            true,
            address(0),
            address(0)
        );
    }

    function repegARTHWhenBelowPeg() external {
        // flashloan arth
        // we have arth; we redeem it for bnb from our loan
        // swap bnb for busd
        // buy arth from the market and bring it back to the peg
        // payback flashloan with arth obtained

        uint256 busdNeeded;
        router.estimateARTHtoSell(busdNeeded);

        uint256 busdProfits;
        uint256 bnbOutMin;

        address[] memory path = new address[](2);
        path[0] = address(busd);
        path[1] = address(wbnb);

        pancakeswap.swapExactTokensForETH(
            busdProfits,
            bnbOutMin,
            path,
            me,
            block.timestamp
        );
    }

    function _flush(address to) internal {
        if (arthUsd.balanceOf(me) > 0) {
            arthUsd.withdraw(arthUsd.balanceOf(me).div(2));
        }

        if (arth.balanceOf(me) > 0) arth.transfer(to, arth.balanceOf(me));
        if (lp.balanceOf(me) > 0) lp.transfer(to, lp.balanceOf(me));
        if (busd.balanceOf(me) > 0) busd.transfer(to, busd.balanceOf(me));
    }
}
