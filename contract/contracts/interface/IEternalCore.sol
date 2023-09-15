// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import {IEAS} from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import {ISchemaRegistry} from "@ethereum-attestation-service/eas-contracts/contracts/ISchemaRegistry.sol";

interface IEternalCore {
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
    struct Allocation {
        uint256 projectId;
        uint256 amount;
        uint256 sqrtSumSqared;
    }
    event GrantCreated(
        uint256 grantId,
        address organizer,
        uint256 budget,
        string organizationInfo
    );
    event ProjectCreated(
        uint256 projectId,
        address ownerAddress,
        address payoutAddress,
        string dataJsonStringified
    );
    struct EASInfo {
        IEAS eas;
        ISchemaRegistry schemaRegistry;
        bytes32 schemaUID;
        string schema;
        bool revocable;
    }
    event ProjectApproved(Project project);
    event VoteCreated(
        uint256 grantId,
        uint256 projectId,
        address voter,
        uint256 weight,
        string message
    );
    event BadgeholderCreated(
        uint256 badgeholderId,
        address holderAddress,
        uint256 votingPower
    );
    event AllocationCreated(
        uint256 grantId,
        uint256 projectId,
        uint256 amount,
        uint256 sqrtSumSqared
    );
}
