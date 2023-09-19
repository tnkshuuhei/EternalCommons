// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IEAS, Attestation, AttestationRequest, AttestationRequestData} from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import {ISchemaRegistry, ISchemaResolver, SchemaRecord} from "@ethereum-attestation-service/eas-contracts/contracts/ISchemaRegistry.sol";
import {InvalidEAS, uncheckedInc} from "@ethereum-attestation-service/eas-contracts/contracts/Common.sol";
import {IEternalCore} from "./interface/IEternalCore.sol";
import {IPool} from "./interface/IPool.sol";
import {PoolContract} from "./PoolContract.sol";

contract EternalCore is AccessControl, IEternalCore {
    IEAS public eas;
    EASInfo public easInfo;

    mapping(uint256 => Allocation[]) public allocation; //grantId to Allocation
    mapping(uint256 => EASInfo[]) public grantEASInfo; // grantId to EASInfo
    mapping(uint256 => mapping(uint256 => Vote[])) public votes; // grantId to projectId to votes
    mapping(uint256 => Badgeholder[]) public badgeholder; //grantId to badgeholder
    mapping(uint256 => Project[]) public projects; //map grantId to projects
    mapping(address => Pool) public pools; //map pool address to pool

    Grant[] public grantList;
    uint256 public grantListLength;
    uint256 public projectListLength;

    IERC20 public token;
    address[] public allPools;

    function _createPool(
        address _organizer,
        address _token,
        uint256 _amount,
        string memory _organizationInfo
    ) internal returns (address pool) {
        bytes memory bytecode = type(PoolContract).creationCode;
        bytes32 salt = keccak256(
            abi.encodePacked(_organizer, _organizationInfo)
        );
        assembly {
            pool := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        uint256 deposited;
        if (_token == address(0)) {
            deposited = IPool(pool)._depositETH(pool, _amount);
        } else {
            deposited = IPool(pool)._deposit(pool, _token, _amount);
        }
        Pool memory newPool = Pool({
            owner: _organizer,
            token: _token,
            totalDeposited: deposited,
            poolAddress: pool
        });
        pools[pool] = newPool;
        allPools.push(pool);
        emit PoolCreated(pool, msg.sender, _token, deposited);
        return pool;
    }

    function _initializeEAS(
        IEAS _eas, // EAS contract address
        ISchemaRegistry _schemaRegistry, // public registry address
        bytes32 _schemaUID,
        uint256 _grantId
    ) internal {
        SchemaRecord memory record = _schemaRegistry.getSchema(_schemaUID);
        EASInfo memory newEASInfo = EASInfo({
            eas: _eas,
            schemaRegistry: _schemaRegistry,
            schema: record.schema,
            schemaUID: _schemaUID,
            revocable: record.revocable
        });
        grantEASInfo[_grantId].push(newEASInfo);
    }

    function setUpBadgeholder(
        uint256 _grantId,
        address[] memory _holderAddress,
        uint256[] memory _votingPower
    ) public {
        for (uint256 i = 0; i < _holderAddress.length; i++) {
            Badgeholder memory newBadgeholder = Badgeholder({
                id: badgeholder[_grantId].length,
                holderAddress: _holderAddress[i],
                votingPower: _votingPower[i]
            });
            badgeholder[_grantId].push(newBadgeholder);
        }
    }

    function CreateGrant(
        address _organizer,
        address _token,
        uint256 _budget,
        string memory _organizationInfo
    ) public returns (uint256) {
        address pooladdress = _createPool(
            _organizer,
            _token,
            _budget,
            _organizationInfo
        );
        Grant memory newGrant = Grant({
            id: grantListLength, //tbd
            round: 0, //tbd
            organizer: _organizer,
            budget: _budget,
            organizationInfo: _organizationInfo,
            pool: pooladdress
        });
        grantList.push(newGrant);
        return grantListLength++;
    }

    // fix grantEASInfo
    function _grantEASAttestation(
        address _recipientId,
        uint64 _expirationTime,
        bytes memory _data,
        uint256 _value
    ) internal returns (bytes32) {
        AttestationRequest memory attestationRequest = AttestationRequest(
            easInfo.schemaUID,
            AttestationRequestData({
                recipient: _recipientId,
                expirationTime: _expirationTime,
                revocable: easInfo.revocable,
                refUID: 0, // tbd
                data: _data,
                value: _value
            })
        );
        // return new attestation UID
        return easInfo.eas.attest(attestationRequest);
    }

    function RegisterApplication(
        uint256 _grantId,
        address _payoutAddress,
        string memory _dataJsonStringified
    ) public returns (uint256) {
        Project memory newProject = Project({
            id: projectListLength,
            ownerAddress: msg.sender,
            payoutAddress: _payoutAddress,
            dataJsonStringified: _dataJsonStringified,
            isAccepted: false,
            totalFundReceived: 0
        });
        projects[_grantId].push(newProject);
        return projectListLength++;
    }

    // onlybadgeholder modifier
    function ApproveApplication(
        uint256 _grantId,
        uint256[] memory _projectId
    ) public {
        for (uint256 i = 0; i < _projectId.length; i++) {
            uint256 _id = _projectId[i];
            projects[_grantId][_id].isAccepted = true;
            emit ProjectApproved(projects[_grantId][_id]);
        }
    }

    function DenyApplication(
        uint256 _grantId,
        uint256[] memory _projectId
    ) public {
        for (uint256 i = 0; i < _projectId.length; i++) {
            uint256 _id = _projectId[i];
            projects[_grantId][_id].isAccepted = false;
        }
    }

    // add access control and check if the user is the badgeholder
    function vote(
        uint256 _grantId,
        uint256 _projectId,
        uint256 _voteWeight,
        string memory _message
    ) public {
        // check if msg.sender is the badgeholder
        Vote memory newVote = Vote({
            voter: msg.sender,
            weight: _voteWeight, //tbd
            message: _message,
            createdTimestamp: block.timestamp
        });
        votes[_grantId][_projectId].push(newVote);
    }

    function batchvote(
        uint256 _grantId,
        uint256[] memory _projectId,
        uint256[] memory _voteWeight,
        string[] memory _message
    ) public {
        for (uint256 i = 0; i < _projectId.length; i++) {
            vote(_grantId, _projectId[i], _voteWeight[i], _message[i]);
        }
    }

    function getGrantEAS(
        uint256 _grantId
    ) public view returns (EASInfo[] memory) {
        require(
            grantEASInfo[_grantId].length > 0,
            "No EAS is initialized for this grant"
        );
        return grantEASInfo[_grantId];
    }

    function getVote(
        uint256 _grantId,
        uint256 _projectId
    ) public view returns (Vote[] memory) {
        return votes[_grantId][_projectId];
    }

    function getAllProject(
        uint256 _grantId
    ) public view returns (Project[] memory) {
        return projects[_grantId];
    }

    function getProjectDetail(
        uint256 _grantId,
        uint256 _projectId
    ) public view returns (Project memory) {
        return projects[_grantId][_projectId];
    }

    // get sum of sqrt vote
    // get squared sum of sqrt vote
    // sum of sqrt vote
    // matching pool
    // calculate matching * suquare sum of sqrt vote / total squared sum of sqrt vote

    function sqrt(uint256 x) public pure returns (uint256 y) {
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }

    function calculateSqrtSum(
        uint256 _grantId,
        uint256 _projectId
    ) internal view returns (uint256) {
        uint256 sqrtSum = 0;
        for (uint256 i = 0; i < votes[_grantId][_projectId].length; i++) {
            sqrtSum += sqrt(votes[_grantId][_projectId][i].weight);
        }
        return sqrtSum;
    }

    function _calculateAllocation(
        uint256 _grantpool,
        uint256 _grantId
    ) internal returns (Allocation[] memory) {
        uint256 totalSqrtSumSquared = 0;
        for (uint256 i = 0; i < projects[_grantId].length; i++) {
            totalSqrtSumSquared += calculateSqrtSum(_grantId, i) ** 2;
        }
        uint256 _sqrtSumSqared = 0;
        for (uint256 i = 0; i < projects[_grantId].length; i++) {
            _sqrtSumSqared = calculateSqrtSum(_grantId, i) ** 2;
            Allocation memory newAllocation = Allocation({
                projectId: i,
                amount: (_grantpool * _sqrtSumSqared) / totalSqrtSumSquared,
                sqrtSumSqared: _sqrtSumSqared
            });
            allocation[_grantId].push(newAllocation);
        }
        return allocation[_grantId];
    }

    function allcate(uint256 _grantId) external {
        uint256 grantPool = grantList[_grantId].budget;
        address poolAddress = grantList[_grantId].pool;
        uint256[] memory estAllocation = getMatchingAmount(grantPool, _grantId);
        require(grantPool > 0, "Grant pool must be greater than zero");
        for (uint256 i = 0; i < projects[_grantId].length; i++) {
            uint256 amount = estAllocation[i];
            Project storage project = projects[_grantId][i];
            IPool(poolAddress).distribute(
                poolAddress,
                project.payoutAddress,
                amount
            );
            emit Allocated(_grantId, project.id, amount);
        }
    }

    function getMatchingAmount(
        uint256 _grantId,
        uint256 _grantPool
    ) public view returns (uint256[] memory) {
        uint256 totalSqrtSumSquared = 0;
        uint256[] memory matchingAmounts = new uint256[](
            projects[_grantId].length
        );
        for (uint256 i = 0; i < projects[_grantId].length; i++) {
            totalSqrtSumSquared += calculateSqrtSum(_grantId, i) ** 2;
        }
        for (uint256 i = 0; i < projects[_grantId].length; i++) {
            uint256 _sqrtSumSqared = calculateSqrtSum(_grantId, i) ** 2;
            matchingAmounts[i] =
                (_grantPool * _sqrtSumSqared) /
                totalSqrtSumSquared;
        }
        return matchingAmounts;
    }

    function getAllocation(
        uint256 _grantId
    ) public view returns (Allocation[] memory) {
        return allocation[_grantId];
    }
}
