// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract Contract {
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
    mapping(address => address[]) public badgeholder; //grantId to badgeholder
    mapping(uint256 => Project[]) public projects; //map grantId to project

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
    function ApproveApplication(uint256 _grantId, uint256 _projectId) external {
        projects[_grantId][_projectId].isAccepted = true;
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
    // function Vote(){}
    // function BatchVote(){}
    // function Allocate(){}
    // function CalculateAllocation(){}
}
