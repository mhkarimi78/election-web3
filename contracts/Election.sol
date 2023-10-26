// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

contract ElectionContract {
    struct Election {
        uint id;
        string name;
        uint startDate;
        uint endDate;
        address[] participantsArr;
        address[] candidateArr;
        uint numWinners;
        uint minPercentage;
    }

    struct Candidate {
        string name;
        address walletAddress;
        uint electionId;
    }

    struct Participant {
        string name;
        address walletAddress;
        uint electionId;
    }

    mapping(address => Participant) public participants;
    mapping(uint => Election) public elections;
    mapping(address => Candidate) public candidates;
    mapping(address => address[]) public votes;
    mapping(uint => mapping(address => bool)) public electionVotes;
    uint public electionCount;
    uint public voteCost = 0.001 ether;

    address public admin;

    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can perform this action");
        _;
    }

    function createElection(
        string memory name,
        uint startDate,
        uint endDate,
        uint numWinners,
        uint minPercentage
    ) public onlyAdmin {
        electionCount++;
        Election storage newElection = elections[electionCount];
        newElection.id = electionCount;
        newElection.name = name;
        newElection.startDate = startDate;
        newElection.endDate = endDate;
        newElection.numWinners = numWinners;
        newElection.minPercentage = minPercentage;
    }

    function joinAsParticipant(
        string memory name,
        address walletAddress,
        uint electionId
    ) public {
        // require(
        //     elections[electionId].startDate <= block.timestamp &&
        //         elections[electionId].endDate >= block.timestamp,
        //     "Election not active"
        // );
        participants[walletAddress] = Participant(name,walletAddress,electionId);
        Election storage SelectedElection = elections[electionId];
        uint length = SelectedElection.participantsArr.length;
        SelectedElection.participantsArr[length] = walletAddress;
    }

    function addCandidate(
        string memory name,
        address walletAddress,
        uint electionId
    ) public onlyAdmin {
        // require(
        //     elections[electionId].startDate <= block.timestamp &&
        //         elections[electionId].endDate >= block.timestamp,
        //     "Election not active"
        // );
        candidates[walletAddress] = Candidate(name,walletAddress, electionId);
        Election storage SelectedElection = elections[electionId];
        uint length = SelectedElection.candidateArr.length;
        SelectedElection.candidateArr[length] = walletAddress;
    }

    function isParticipant(uint electionId) public view returns(bool){
        Participant storage user = participants[msg.sender];
        if(user.electionId == electionId){
            return true;
        }
        return false;
    }

    function vote(uint electionId,address candidateAddress) public payable {
        // require(
        //     elections[electionId].startDate <= block.timestamp &&
        //         elections[electionId].endDate >= block.timestamp,
        //     "Election not active"
        // );
        require(msg.value >= voteCost, "Not enough ether to vote");
        votes[msg.sender].push(candidateAddress);
        electionVotes[electionId][msg.sender] = true;
    }

    mapping(address => uint) public voteCounts;
    function getWinners(uint electionId) public returns (address[] memory) {
        Election storage election = elections[electionId];
        address[] memory candidates = election.candidateArr;
        uint numWinners = election.numWinners;
        uint minPercentage = election.minPercentage;
        uint totalVotes = 0;
        for (uint i = 0; i < candidates.length; i++) {
            address candidate = candidates[i];
            uint votesReceived = 0;
            for (uint j = 0; j < election.participantsArr.length; j++) {
                address participant = election.participantsArr[j];
                for (uint k = 0; k < votes[participant].length; k++) {
                    if (votes[participant][k] == candidate) {
                        votesReceived++;
                    }
                }
            }
            voteCounts[candidate] = votesReceived;
            totalVotes += votesReceived;
        }
        address[] memory winners = new address[](numWinners);
        uint winnerIndex = 0;
        for (uint i = 0; i < numWinners; i++) {
            address winner = address(0);
            uint highestVotes = 0;
            for (uint j = 0; j < candidates.length; j++) {
                address candidate = candidates[j];
                uint votesReceived = voteCounts[candidate];
                uint percentage = (votesReceived * 100) / totalVotes;
                if (votesReceived > highestVotes && percentage >= minPercentage) {
                    winner = candidate;
                    highestVotes = votesReceived;
                }
            }
            if (winner != address(0)) {
                winners[winnerIndex] = winner;
                winnerIndex++;
                totalVotes -= highestVotes;
                candidates = removeAddressFromArray(candidates, winner);
            }
        }
        return winners;
    }

    function removeAddressFromArray(address[] memory array, address element) private pure returns (address[] memory) {
        uint index = findAddressIndexInArray(array, element);
        if (index >= array.length) return array;
        for (uint i = index; i < array.length - 1; i++) {
            array[i] = array[i + 1];
        }
        delete array[array.length - 1];
        return array;
    }

    function findAddressIndexInArray(address[] memory array, address element) private pure returns (uint) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == element) {
                return i;
            }
        }
        return array.length;
    }

    function editElection(
        uint electionId,
        uint startDate,
        uint endDate,
        uint numWinners,
        uint minPercentage
    ) public onlyAdmin {
        elections[electionId].startDate = startDate;
        elections[electionId].endDate = endDate;
        elections[electionId].numWinners = numWinners;
        elections[electionId].minPercentage = minPercentage;
    }

    function withdraw() public onlyAdmin {
        payable(admin).transfer(address(this).balance);
    }

    function getElectionById(
        uint electionId
    )
        public
        view
        returns (uint, string memory, uint, uint, address[] memory,address[] memory, uint, uint)
    {
        Election storage election = elections[electionId];
        return (
            election.id,
            election.name,
            election.startDate,
            election.endDate,
            election.participantsArr,
            election.candidateArr,
            election.numWinners,
            election.minPercentage
        );
    }

    function getMyElection() public view returns (uint[] memory) {
        uint count = 0;
        for (uint i = 1; i <= electionCount; i++) {
            if (elections[i].participantsArr[i] == msg.sender) {
                count++;
            }
        }
        uint[] memory myElections = new uint[](count);
        uint index = 0;
        for (uint i = 1; i <= electionCount; i++) {
            if (elections[i].participantsArr[i] == msg.sender) {
                myElections[index] = elections[i].id;
                index++;
            }
        }
        return myElections;
    }


    function getAllElection() public view returns (uint[] memory) {
        uint[] memory allElections = new uint[](electionCount);
        for (uint i = 0; i < electionCount; i++) {
            allElections[i] = elections[i].id;
        }
        return allElections;
    }

    function myVotes() public view returns (address[] memory) {
        return votes[msg.sender];
    }
}
