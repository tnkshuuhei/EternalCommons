// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IEternalCore} from "./interface/IEternalCore.sol";

contract PoolContract {
    IEternalCore internal immutable corecontract;

    constructor(IEternalCore _corecontract) {
        corecontract = _corecontract;
    }

    modifier onlyCore() {
        require(
            msg.sender == address(corecontract),
            "Only grant owner can call this function"
        );
        _;
    }

    function _depositETH(
        address _pool,
        uint256 _amount
    ) external onlyCore returns (uint256) {
        (bool sent, ) = _pool.call{value: _amount}("");
        require(sent, "Failed to send Ether");
        return _amount;
    }

    function _deposit(
        address _pool,
        address _token,
        uint256 _amount
    ) external onlyCore returns (uint256) {
        bool sent = IERC20(_token).transferFrom(msg.sender, _pool, _amount);
        require(sent, "Failed to Deposit Token");
        // pools[_pool].totalDeposited += _amount;
        return _amount;
    }

    function distribute(
        address _token,
        address _recipients,
        uint256 _amounts
    ) external onlyCore returns (bool sent) {
        require(_recipients != address(0), "Invalid Address");
        sent = IERC20(_token).transferFrom(
            address(this),
            _recipients,
            _amounts
        );
        return sent;
    }
}
