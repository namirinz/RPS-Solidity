// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

contract RPS {
    uint public numPlayer = 0;
    uint public reward = 0;
    mapping (address => uint) public player_choice; // 0 - Rock, 1 - Paper, 2 - Scissors, 3 - Lizard, 4 - Spock
    mapping(address => bool) public player_not_played;
    address[] public players;

    uint public numInput = 0;

    // Add a mapping to store whitelisted players
    mapping(address => bool) public whitelistedPlayers;

    // Constructor to initialize the whitelist
    constructor() {
        whitelistedPlayers[0x5B38Da6a701c568545dCfcB03FcB875f56beddC4] = true;
        whitelistedPlayers[0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2] = true;
        whitelistedPlayers[0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db] = true;
        whitelistedPlayers[0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB] = true;
    }

    function addPlayer() public payable {
        require(numPlayer < 2);
        require(check_player_can_play(msg.sender));
        if (numPlayer > 0) {
            require(msg.sender != players[0]);
        }
        require(msg.value == 1 ether);
        reward += msg.value;
        player_not_played[msg.sender] = true;
        players.push(msg.sender);
        numPlayer++;
    }

    function input(uint choice) public {
        require(numPlayer == 2);
        require(player_not_played[msg.sender]);
        require(choice >= 0 && choice <= 4);
        player_choice[msg.sender] = choice;
        player_not_played[msg.sender] = false;
        numInput++;
        if (numInput == 2) {
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
        for (uint i = 0; i < players.length; i++) {
            player_not_played[players[i]] = true; // Reset player not played
            player_choice[players[i]] = 0; // Reset player choice
        }
        players = new address[](0); // Reset players
    }

    // Update the check_player_can_play function
    function check_player_can_play(address player) internal view returns (bool) {
        return whitelistedPlayers[player];
    }
}