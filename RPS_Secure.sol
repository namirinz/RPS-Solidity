// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./CommitReveal.sol";
import "./TimeUnit.sol";

contract RPS {
    uint public numPlayer = 0;
    uint public reward = 0;
    mapping (address => uint) private player_choice; // 0 - Rock, 1 - Paper, 2 - Scissors, 3 - Lizard, 4 - Spock
    mapping(address => bool) private player_not_played;
    address[] public players;

    // Remove our custom commit-reveal implementation and use the imported contract
    CommitReveal public commitReveal;
    mapping(address => bool) public hasRevealed;
    uint public numReveals = 0;

    uint public numInput = 0;

    // Add TimeUnit instance for time tracking
    TimeUnit public timeTracker;
    
    // Add variables for timeout mechanism
    bool public firstPlayerCommitted = false;
    uint public constant COMMIT_TIMEOUT = 7; // 7 seconds

    // Add a mapping to store whitelisted players
    mapping(address => bool) public whitelistedPlayers;

    // Constructor to initialize the whitelist and create CommitReveal instance
    constructor() {
        whitelistedPlayers[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4] = true;
        whitelistedPlayers[0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2] = true;
        whitelistedPlayers[0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db] = true;
        whitelistedPlayers[0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB] = true;

        // Create a new instance of the CommitReveal contract
        commitReveal = new CommitReveal();
        
        // Create a new instance of the TimeUnit contract
        timeTracker = new TimeUnit();
    }

    function addPlayer() public payable {
        require(numPlayer < 2, "Game already has 2 players");
        require(check_player_can_play(msg.sender), "Player not whitelisted");
        if (numPlayer > 0) {
            require(msg.sender != players[0], "You are already in the game");
        }
        require(msg.value == 1 ether, "Must send exactly 1 ether");
        
        reward += msg.value;
        player_not_played[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;
    }

    // Allow player to withdraw their funds in two scenarios:
    // 1. Before a second player joins
    // 2. When the second player hasn't committed in time after first player's commit
    function withdrawFunds() public {
        // Scenario 1: Only one player has joined and wants to withdraw
        if (numPlayer == 1 && msg.sender == players[0]) {
            // Reset game state
            uint refundAmount = reward;
            reward = 0;
            numPlayer = 0;
            firstPlayerCommitted = false;
            delete players;
            
            // Send the funds back to the player
            payable(msg.sender).transfer(refundAmount);
            return;
        }
        
        // Scenario 2: Both players have joined, but the second player didn't commit in time
        require(numPlayer == 2, "Game must have exactly 2 players");
        require(firstPlayerCommitted, "First player hasn't committed yet");
        require(timeTracker.elapsedSeconds() >= COMMIT_TIMEOUT, "Timeout period not yet passed");
        
        // Check if the second player hasn't committed (both players should still be in player_not_played)
        bool player0NotCommitted = player_not_played[players[0]];
        bool player1NotCommitted = player_not_played[players[1]];
        
        // If only one player committed (exactly one of the players didn't commit)
        require(player0NotCommitted != player1NotCommitted, "Either both or no players have committed");
        
        // Return funds to both players
        address payable player0 = payable(players[0]);
        address payable player1 = payable(players[1]);
        
        // Reset the game state
        uint refundAmount = reward / 2;
        reward = 0;
        numPlayer = 0;
        firstPlayerCommitted = false;
        delete players;
        
        // Return the funds
        player0.transfer(refundAmount);
        player1.transfer(refundAmount);
    }

    // Step 1: Players commit their move hashes using the CommitReveal contract
    function commitChoice(bytes32 rawChoice) public {
        require(numPlayer == 2, "Need exactly 2 players");
        require(player_not_played[msg.sender], "Player already played");

        // Call the commit function in the CommitReveal contract directly with secretChoiceData
        // The CommitReveal contract will hash it internally
        commitReveal.commit(commitReveal.getHash(rawChoice));
        
        // If this is the first player to commit, set the timestamp
        if (!firstPlayerCommitted) {
            firstPlayerCommitted = true;
            // Reset and start the timer
            timeTracker.setStartTime();
        }
    }

    // Step 2: Players reveal their moves using the CommitReveal contract
    function revealChoice(bytes32 secretChoiceData) public {
        require(numPlayer == 2, "Need exactly 2 players");
        require(!hasRevealed[msg.sender], "Already revealed");
        
        // Call the reveal function in the CommitReveal contract
        commitReveal.reveal(secretChoiceData);

        // Extract the choice from the last 2 digits of the hex string
        uint choice = uint8(secretChoiceData[31]) % 16; // Get the last digit
        // Validate the choice
        require(choice >= 0 && choice <= 4, "Invalid choice");

        // Record the choice
        player_choice[msg.sender] = choice;
        player_not_played[msg.sender] = false;
        hasRevealed[msg.sender] = true;
        numReveals++;

        // If both players have revealed, determine the winner
        if (numReveals == 2) {
            _checkWinnerAndPay();
        }
    }


    function _checkWinnerAndPay() private {
        uint p0Choice = player_choice[players[0]];
        uint p1Choice = player_choice[players[1]];
        address payable account0 = payable(players[0]);
        address payable account1 = payable(players[1]);

        // Check winning conditions based on the exact rules from the image
        if (p0Choice == p1Choice) {
            // It's a tie
            account0.transfer(reward / 2);
            account1.transfer(reward / 2);
        } else if (
            // Rock crushes Scissors and Lizard
            (p0Choice == 0 && (p1Choice == 2 || p1Choice == 3)) ||
            // Paper covers Rock and disproves Spock
            (p0Choice == 1 && (p1Choice == 0 || p1Choice == 4)) ||
            // Scissors cuts Paper and decapitates Lizard
            (p0Choice == 2 && (p1Choice == 1 || p1Choice == 3)) ||
            // Lizard eats Paper and poisons Spock
            (p0Choice == 3 && (p1Choice == 1 || p1Choice == 4)) ||
            // Spock vaporizes Rock and smashes Scissors
            (p0Choice == 4 && (p1Choice == 0 || p1Choice == 2))
        ) {
            account0.transfer(reward);
        } else {
            account1.transfer(reward);
        }
        _reset();
    }

    function _reset() private {
        numPlayer = 0;
        reward = 0;
        numInput = 0;
        numReveals = 0;
        firstPlayerCommitted = false;
        
        for (uint i = 0; i < players.length; i++) {
            address player = players[i];
            player_not_played[player] = true; // Reset player not played
            player_choice[player] = 0; // Reset player choice
            
            // Reset reveal state
            hasRevealed[player] = false;
        }
        players = new address[](0); // Reset players
        
        // Note: We don't need to reset the commitReveal contract state because
        // each player's commits are stored in a mapping keyed by their address
    }

    // Update the check_player_can_play function
    function check_player_can_play(address player) internal view returns (bool) {
        return whitelistedPlayers[player];
    }
    
    // Helper function to check if timeout has occurred
    function hasCommitTimeoutOccurred() public view returns (bool) {
        if (!firstPlayerCommitted || numPlayer != 2) {
            return false;
        }
        return timeTracker.elapsedSeconds() >= COMMIT_TIMEOUT;
    }
    
}