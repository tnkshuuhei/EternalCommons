// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Contract is Ownable, AccessControl {
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
    mapping(uint256 => mapping(uint256 => Vote[])) public votes;

    mapping(uint256 => address[]) public badgeholder; //grantId to badgeholder
    mapping(uint256 => Project[]) public projects; //map grantId to projects

    Grant[] public grantList;
    uint256 public grantListLength;
    uint256 public projectListLength;

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

    // onlybadgeholder modifier
    function DenyApplication(uint256 _grantId, uint256 _projectId) external {
        projects[_grantId][_projectId].isAccepted = false;
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

    // add access control and check if the user is the badgeholder
    function _vote(
        uint256 _grantId,
        uint256 _projectId,
        string memory _message
    ) public {
        // check if msg.sender is the badgeholder
        Vote memory newVote = Vote({
            voter: msg.sender,
            weight: 1, //tbd
            message: _message,
            createdTimestamp: block.timestamp
        });
        votes[_grantId][_projectId].push(newVote);
    }

    function batchvote(
        uint256 _grantId,
        uint256[] memory _projectId,
        string[] memory _message
    ) public {
        for (uint256 i = 0; i < _projectId.length; i++) {
            _vote(_grantId, _projectId[i], _message[i]);
        }
    }

    function getVote(
        uint256 _grantId,
        uint256 _projectId
    ) public view returns (Vote[] memory) {
        return votes[_grantId][_projectId];
    }
    // function Allocate(){}
    // function CalculateAllocation(){}
}
