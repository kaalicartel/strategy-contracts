// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import {IEllipsisRouter} from "../interfaces/IEllipsisRouter.sol";
import {IERC20, IERC20WithDecimals} from "../interfaces/IERC20WithDecimals.sol";
import {IERC20Wrapper} from "../interfaces/IERC20Wrapper.sol";
import {IStableSwap} from "../interfaces/IStableSwap.sol";
import {IZapDepositor} from "../interfaces/IZapDepositor.sol";
import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract EllipsisARTHRouter is IEllipsisRouter {
    using SafeMath for uint256;

    IERC20WithDecimals public lp;
    IZapDepositor public zap;
    address public pool;

    IERC20Wrapper public arthUsd;
    IERC20WithDecimals public arth;
    IERC20WithDecimals public busd;

    address private me;

    constructor(
        address _zap,
        address _lp,
        address _pool,
        address _arth,
        address _arthUsd,
        address _busd
    ) {
        pool = _pool;

        arthUsd = IERC20Wrapper(_arthUsd);
        zap = IZapDepositor(_zap);

        lp = IERC20WithDecimals(_lp);
        arth = IERC20WithDecimals(_arth);
        busd = IERC20WithDecimals(_busd);

        me = address(this);
    }

    function sellARTHForExactBUSD(
        uint256 amountArthInMax,
        uint256 amountBUSDOut,
        address to,
        uint256 deadline
    ) external override {
        // convert arth -> arth.usd
        arth.transferFrom(msg.sender, me, amountArthInMax);
        arth.approve(address(arthUsd), amountArthInMax);
        arthUsd.deposit(amountArthInMax);

        arthUsd.approve(address(zap), arthUsd.balanceOf(me));
        uint256[4] memory amountsIn = [arthUsd.balanceOf(me), 0, 0, 0];
        _addLiquidity(amountsIn, 0);

        lp.approve(address(zap), lp.balanceOf(me));

        if (amountBUSDOut > 0) {
            uint256[4] memory amountsOut = [0, amountBUSDOut, 0, 0];
            uint256 burnAmount = zap.calc_token_amount(pool, amountsOut, false);
            _removeLiquidityOneCoin(
                burnAmount.mul(101).div(100),
                1,
                amountBUSDOut
            );
        }

        // if there are some leftover lp tokens we extract it out as arth and send it back
        if (lp.balanceOf(me) > 1e12)
            _removeLiquidityOneCoin(lp.balanceOf(me), 0, 0);

        require(busd.balanceOf(me) >= amountBUSDOut, "not enough busd out");
        require(block.timestamp <= deadline, "swap deadline expired");

        _flush(to);
    }

    function buyARTHForExactBUSD(
        uint256 amountBUSDIn,
        uint256 amountARTHOutMin,
        address to,
        uint256 deadline
    ) external override {
        if (amountBUSDIn > 0) busd.transferFrom(msg.sender, me, amountBUSDIn);

        busd.approve(address(zap), amountBUSDIn);

        uint256[4] memory amountsIn = [0, amountBUSDIn, 0, 0];
        _addLiquidity(amountsIn, 0);

        lp.approve(address(zap), lp.balanceOf(me));
        uint256[4] memory amountsOut = [amountARTHOutMin.mul(2), 0, 0, 0];
        uint256 burnAmount = zap.calc_token_amount(pool, amountsOut, false);

        // todo make this revert properly
        _removeLiquidityOneCoin(
            burnAmount.mul(101).div(100),
            0,
            amountARTHOutMin.mul(2)
        );

        // if there are some leftover lp tokens we extract it out as arth and send it back
        if (lp.balanceOf(me) > 1e12)
            _removeLiquidityOneCoin(lp.balanceOf(me), 0, 0);

        arthUsd.withdraw(arthUsd.balanceOf(me).div(2));
        require(arth.balanceOf(me) >= amountARTHOutMin, "not enough arth out");
        require(block.timestamp <= deadline, "swap deadline expired");

        _flush(to);
    }

    function sellARTHforToken(
        int128 tokenId, // 1 -> busd, 2 -> usdc, 3 -> usdt
        uint256 amountARTHin,
        address to,
        uint256 deadline
    ) external override {
        if (amountARTHin > 0) arth.transferFrom(msg.sender, me, amountARTHin);
        arth.approve(address(arthUsd), amountARTHin);
        arthUsd.deposit(amountARTHin);

        arthUsd.approve(pool, arthUsd.balanceOf(me));
        IStableSwap swap = IStableSwap(pool);

        uint256 amountTokenOut = swap.get_dy_underlying(
            0,
            tokenId,
            amountARTHin
        );
        swap.exchange_underlying(0, tokenId, amountARTHin, amountTokenOut, to);

        require(block.timestamp <= deadline, "swap deadline expired");
    }

    function estimateARTHtoSell(uint256 busdNeeded)
        external
        view
        override
        returns (uint256)
    {
        uint256[4] memory amountsIn = [0, busdNeeded, 0, 0];

        uint256 lpIn = zap.calc_token_amount(pool, amountsIn, false);
        uint256 arthUsdOut = zap.calc_withdraw_one_coin(pool, lpIn, 0);

        // todo: need to divide by GMU
        return arthUsdOut.div(2);
    }

    function estimateARTHtoBuy(uint256 busdToSell)
        external
        view
        override
        returns (uint256)
    {
        uint256[4] memory amountsIn = [0, busdToSell, 0, 0];

        uint256 lpIn = zap.calc_token_amount(pool, amountsIn, true);
        uint256 arthUsdOut = zap.calc_withdraw_one_coin(pool, lpIn, 0);

        // todo: need to divide by GMU
        return arthUsdOut.div(2);
    }

    function _removeLiquidityOneCoin(
        uint256 burnAmount,
        int128 i,
        uint256 minReceived
    ) internal {
        (bool success, ) = address(zap).call(
            abi.encodeWithSignature(
                "remove_liquidity_one_coin(address,uint256,int128,uint256)",
                pool,
                burnAmount,
                i,
                minReceived
            )
        );

        require(
            success,
            "EllipsisARTHRouter: remove_liquidity_one_coin failed"
        );
    }

    function _addLiquidity(
        uint256[4] memory depositAmounts,
        uint256 minMintAmount
    ) internal {
        (bool success, ) = address(zap).call(
            abi.encodeWithSignature(
                "add_liquidity(address,uint256[4],uint256)",
                pool,
                depositAmounts,
                minMintAmount
            )
        );

        require(success, "EllipsisARTHRouter: add_liquidity failed");
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
