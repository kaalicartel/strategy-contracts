// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IZapDepositor {
  function get_virtual_price() external view returns (uint256);

  function calc_token_amount(
    address pool,
    uint256[4] memory amounts,
    bool _is_deposit
  ) external view returns (uint256);

  function calc_withdraw_one_coin(
    address pool,
    uint256 _burn_amount,
    int128 i
  ) external view returns (uint256);

  function remove_liquidity_one_coin(
    address pool,
    uint256 _burn_amount,
    int128 i,
    uint256 _min_received
  ) external;

  function remove_liquidity_imbalance(
    address pool,
    uint256[4] memory _amounts,
    uint256 _max_burn_amount
  ) external;

  function remove_liquidity(
    address pool,
    uint256 burn_amount,
    uint256[4] memory min_amounts
  ) external;

  function add_liquidity(
    address pool,
    uint256[4] memory _deposit_amounts,
    uint256 min_mint_amount
  ) external;
}