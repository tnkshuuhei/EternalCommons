// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PoolContract {
    // function _createPool(
    //     address _organizer,
    //     address _token,
    //     uint256 _amount,
    //     string memory _organizationInfo
    // ) internal returns (address pool) {
    //     bytes memory bytecode = type(PoolContract).creationCode;
    //     bytes32 salt = keccak256(
    //         abi.encodePacked(_organizer, _organizationInfo)
    //     );
    //     assembly {
    //         pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
    //     }
    //     Pool memory newPool = Pool({
    //         owner: _organizer,
    //         token: _token,
    //         totalDeposited: 0,
    //         poolAddress: pool
    //     });
    //     pools[pool] = newPool;
    //     allPools.push(pool);
    //     _deposit(pool, _token, _amount);
    //     emit PoolCreated(pool, msg.sender, _token, _amount);
    //     return pool;
    // }

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
