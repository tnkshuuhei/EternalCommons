// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IPool {
    function _deposit(
        address _pool,
        address _token,
        uint256 _amount
    ) external returns (uint256);

    function _depositETH(
        address _pool,
        uint256 _amount
    ) external returns (uint256);

    function distribute(
        address _token,
        address[] memory _recipients,
        uint256[] memory _amounts
    ) external returns (bool);
}
