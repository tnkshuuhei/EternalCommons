// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {IEAS, Attestation, AttestationRequest, AttestationRequestData} from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import {ISchemaRegistry, ISchemaResolver, SchemaRecord} from "@ethereum-attestation-service/eas-contracts/contracts/ISchemaRegistry.sol";
import {InvalidEAS, uncheckedInc} from "@ethereum-attestation-service/eas-contracts/contracts/Common.sol";

/* TODO List
- access control
- verify badgeholder function
- onlybadgeholder modifier
- allocate function
- calculate allocation
- create pool -> poolcontract
 */

contract EternalCore is Ownable, AccessControl {
    struct Grant {
        uint256 id;
        uint16 round;
        address organizer;
        uint256 budget;
        string organizationInfo;
    }
    struct Project {
        uint256 id;
        address ownerAddress;
        address payoutAddress;
        string dataJsonStringified;
        bool isAccepted;
        uint256 totalFundReceived;
    }
    struct Vote {
        address voter;
        uint256 weight;
        string message;
        uint256 createdTimestamp;
    }
    struct Badgeholder {
        uint256 id;
        address holderAddress;
        uint256 votingPower;
    }
    IEAS public eas;
    struct EASInfo {
        IEAS eas;
        ISchemaRegistry schemaRegistry;
        bytes32 schemaUID;
        string schema;
        bool revocable;
    }
    EASInfo public easInfo;
    mapping(uint256 => EASInfo[]) public grantEASInfo; // grantId to EASInfo
    mapping(uint256 => mapping(uint256 => Vote[])) public votes; // grantId to projectId to votes
    mapping(uint256 => Badgeholder[]) public badgeholder; //grantId to badgeholder
    mapping(uint256 => Project[]) public projects; //map grantId to projects

    Grant[] public grantList;
    uint256 public grantListLength;
    uint256 public projectListLength;

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
        uint256 _budget,
        string memory _organizationInfo
    ) public returns (uint256) {
        Grant memory newGrant = Grant({
            id: grantListLength, //tbd
            round: 0, //tbd
            organizer: _organizer,
            budget: _budget,
            organizationInfo: _organizationInfo
            // budgeholder: budgeholder
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
}