// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IEAS, Attestation, AttestationRequest, AttestationRequestData} from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import {ISchemaRegistry, ISchemaResolver, SchemaRecord} from "@ethereum-attestation-service/eas-contracts/contracts/ISchemaRegistry.sol";
import {InvalidEAS, uncheckedInc} from "@ethereum-attestation-service/eas-contracts/contracts/Common.sol";
import {SchemaResolver} from "./SchemaResolver.sol";
import {IEternalCore} from "./interface/IEternalCore.sol";
import {IPool} from "./interface/IPool.sol";
import {PoolContract} from "./PoolContract.sol";

contract EternalCore is IEternalCore, SchemaResolver, AccessControl {
    IEAS public eas;
    EASInfo public easInfo;
    IERC20 public token;

    // grantId -> Allocation list
    mapping(uint256 => Allocation[]) public grantIdToAllocations;

    // grantId -> EASInfo list
    mapping(uint256 => EASInfo[]) public grantIdToEASInfo;

    // grantId -> projectId -> Vote list
    mapping(uint256 => mapping(uint256 => Vote[]))
        public grantIdToProjectIdToVotes;

    // grantId -> Badgeholder list
    mapping(uint256 => Badgeholder[]) public grantIdToBadgeholders;

    // grantId -> Project list
    mapping(uint256 => Project[]) public grantIdToProjects;

    // Pool address -> Pool info
    mapping(address => Pool) public addressToPool;

    // List of all grants
    Grant[] public grantList;

    // Total number of grants
    uint256 public grantListLength;

    // Total number of projects
    uint256 public projectListLength;

    // List of all pool addresses
    address[] public allPools;

    function setUpBadgeholder(
        uint256 _grantId,
        address[] memory _holderAddress,
        uint256[] memory _votingPower
    ) public {
        for (uint256 i = 0; i < _holderAddress.length; i++) {
            Badgeholder memory newBadgeholder = Badgeholder({
                id: grantIdToBadgeholders[_grantId].length,
                holderAddress: _holderAddress[i],
                votingPower: _votingPower[i]
            });
            grantIdToBadgeholders[_grantId].push(newBadgeholder);
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
        grantIdToProjects[_grantId].push(newProject);
        return projectListLength++;
    }

    // onlybadgeholder modifier
    function ApproveApplication(
        uint256 _grantId,
        uint256[] memory _projectId
    ) public {
        for (uint256 i = 0; i < _projectId.length; i++) {
            uint256 _id = _projectId[i];
            grantIdToProjects[_grantId][_id].isAccepted = true;
            emit ProjectApproved(grantIdToProjects[_grantId][_id]);
        }
    }

    function DenyApplication(
        uint256 _grantId,
        uint256[] memory _projectId
    ) public {
        for (uint256 i = 0; i < _projectId.length; i++) {
            uint256 _id = _projectId[i];
            grantIdToProjects[_grantId][_id].isAccepted = false;
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
        grantIdToProjectIdToVotes[_grantId][_projectId].push(newVote);
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
        addressToPool[pool] = newPool;
        allPools.push(pool);
        emit PoolCreated(pool, msg.sender, _token, deposited);
        return pool;
    }

    // Creates an EASInfo instance based on provided inputs.
    function _createEASInfo(
        IEAS _eas,
        ISchemaRegistry _schemaRegistry,
        bytes32 _schemaUID
    ) internal view returns (EASInfo memory) {
        require(address(_eas) != address(0), "Invalid EAS address");

        SchemaRecord memory record = _schemaRegistry.getSchema(_schemaUID);

        return
            EASInfo({
                eas: _eas,
                schemaRegistry: _schemaRegistry,
                schemaUID: _schemaUID,
                schema: record.schema,
                revocable: record.revocable
            });
    }

    // Initializes the EAS with the provided grant and payment schema UIDs.
    function _initializeEAS(
        IEAS _eas,
        ISchemaRegistry _schemaRegistry,
        bytes32 _grantschemaUID,
        bytes32 _paymentschemaUID,
        uint256 _grantId
    ) internal {
        __SchemaResolver_init(_eas);
        grantIdToEASInfo[_grantId].push(
            _createEASInfo(_eas, _schemaRegistry, _grantschemaUID)
        );
        grantIdToEASInfo[_grantId].push(
            _createEASInfo(_eas, _schemaRegistry, _paymentschemaUID)
        );
    }

    // Grants an attestation based on the EAS information associated with a specific grantId.
    function _grantEASAttestation(
        uint256 _grantId,
        address _recipient,
        bytes memory _data,
        uint256 _value,
        uint256 _index // Expected: 0 for grant, 1 for payment
    ) internal returns (bytes32) {
        require(
            grantIdToEASInfo[_grantId].length > _index,
            "Invalid index or no EASInfo found for given grantId"
        );

        EASInfo memory info = grantIdToEASInfo[_grantId][_index];

        AttestationRequest memory request = AttestationRequest(
            info.schemaUID,
            AttestationRequestData({
                recipient: _recipient,
                expirationTime: 0, // This could be an input or derived value in future.
                revocable: info.revocable,
                refUID: 0, // Placeholder; needs clarification.
                data: _data,
                value: _value
            })
        );

        return IEAS(info.eas).attest(request);
    }

    function getVote(
        uint256 _grantId,
        uint256 _projectId
    ) public view returns (Vote[] memory) {
        return grantIdToProjectIdToVotes[_grantId][_projectId];
    }

    function getAllProject(
        uint256 _grantId
    ) public view returns (Project[] memory) {
        return grantIdToProjects[_grantId];
    }

    function getProjectDetail(
        uint256 _grantId,
        uint256 _projectId
    ) public view returns (Project memory) {
        return grantIdToProjects[_grantId][_projectId];
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
        for (
            uint256 i = 0;
            i < grantIdToProjectIdToVotes[_grantId][_projectId].length;
            i++
        ) {
            sqrtSum += sqrt(
                grantIdToProjectIdToVotes[_grantId][_projectId][i].weight
            );
        }
        return sqrtSum;
    }

    function _calculateAllocation(
        uint256 _grantpool,
        uint256 _grantId
    ) internal returns (Allocation[] memory) {
        uint256 totalSqrtSumSquared = 0;
        for (uint256 i = 0; i < grantIdToProjects[_grantId].length; i++) {
            totalSqrtSumSquared += calculateSqrtSum(_grantId, i) ** 2;
        }
        uint256 _sqrtSumSqared = 0;
        for (uint256 i = 0; i < grantIdToProjects[_grantId].length; i++) {
            _sqrtSumSqared = calculateSqrtSum(_grantId, i) ** 2;
            Allocation memory newAllocation = Allocation({
                projectId: i,
                amount: (_grantpool * _sqrtSumSqared) / totalSqrtSumSquared,
                sqrtSumSqared: _sqrtSumSqared
            });
            grantIdToAllocations[_grantId].push(newAllocation);
        }
        return grantIdToAllocations[_grantId];
    }

    function allcate(uint256 _grantId) external {
        uint256 grantPool = grantList[_grantId].budget;
        address poolAddress = grantList[_grantId].pool;
        uint256[] memory estAllocation = getMatchingAmount(grantPool, _grantId);
        require(grantPool > 0, "Grant pool must be greater than zero");
        for (uint256 i = 0; i < grantIdToProjects[_grantId].length; i++) {
            uint256 amount = estAllocation[i];
            Project storage project = grantIdToProjects[_grantId][i];
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
            grantIdToProjects[_grantId].length
        );
        for (uint256 i = 0; i < grantIdToProjects[_grantId].length; i++) {
            totalSqrtSumSquared += calculateSqrtSum(_grantId, i) ** 2;
        }
        for (uint256 i = 0; i < grantIdToProjects[_grantId].length; i++) {
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
        return grantIdToAllocations[_grantId];
    }

    /// @notice Returns if this contract is payable or not
    /// @return True if the attestation is payable, false otherwise
    function isPayable() public pure override returns (bool) {
        return true;
    }

    function onAttest(
        Attestation calldata,
        uint256
    ) internal pure override returns (bool) {
        return true;
    }

    function onRevoke(
        Attestation calldata,
        uint256
    ) internal pure override returns (bool) {
        return true;
    }
}
