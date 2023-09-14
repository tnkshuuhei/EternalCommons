// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract PoolContract {
    struct Pool {
        address token;
        bytes32 managerRole;
        bytes32 adminRole;
    }

    address payable public pool;

    function createPool(
        address _token,
        bytes32 _managerRole,
        bytes32 _adminRole
    ) external returns (address) {}
}
