// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PoolContract {
    function _depositETH(
        address _pool,
        uint256 _amount
    ) external returns (uint256) {
        (bool sent, ) = _pool.call{value: _amount}("");
        require(sent, "Failed to send Ether");
        return _amount;
    }

    function _deposit(
        address _pool,
        address _token,
        uint256 _amount
    ) external returns (uint256) {
        bool sent = IERC20(_token).transferFrom(msg.sender, _pool, _amount);
        require(sent, "Failed to Deposit Token");
        // pools[_pool].totalDeposited += _amount;
        return _amount;
    }

    function distribute(
        address _token,
        address[] memory _recipients,
        uint256[] memory _amounts
    ) external returns (bool) {
        require(
            _recipients.length == _amounts.length && _recipients.length > 0,
            "Invalid Input"
        );
        for (uint256 i = 0; i < _recipients.length; i++) {
            IERC20(_token).transfer(_recipients[i], _amounts[i]);
        }
        return true;
    }
}
