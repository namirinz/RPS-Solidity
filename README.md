# Rock Paper Scissors Secure (RPS_Secure.sol)
## Overview

RPS_Secure extends the basic functionality of the original RPS contract with several security mechanisms:
- **Commit-Reveal Pattern**: Prevents players from seeing each other's moves
- **Timeout Mechanism**: Ensures the game doesn't stall indefinitely  
- **Withdrawal System**: Allows players to recover funds in specific scenarios

## Security Enhancements

### 1. Commit-Reveal Pattern

The original RPS contract had a critical flaw: players could see each other's choices before making their own, allowing the second player to always win. RPS_Secure fixes this using the commit-reveal pattern:

```solidity
CommitReveal public commitReveal;
mapping(address => bool) public hasRevealed;
uint public numReveals = 0;
```

The game now follows a two-step process:
1. **Commit Phase**: Players submit a hash of their choice (not the actual choice)
   ```solidity
   function commitChoice(bytes32 rawChoice) public {
       // Players commit a hashed version of their choice
       commitReveal.commit(commitReveal.getHash(rawChoice));
       // ...
   }
   ```

2. **Reveal Phase**: After both players have committed, they reveal their actual choices
   ```solidity
   function revealChoice(bytes32 secretChoiceData) public {
       // Players reveal their actual choice
       commitReveal.reveal(secretChoiceData);
       // Extract and validate the choice
       // ...
   }
   ```

This prevents either player from seeing the opponent's choice before making their own.

### 2. Timeout Mechanism

To prevent the game from stalling indefinitely, RPS_Secure implements a timeout mechanism:

```solidity
TimeUnit public timeTracker;
bool public firstPlayerCommitted = false;
uint public constant COMMIT_TIMEOUT = 7; // 7 seconds
```

Key features:
- Time tracking starts when the first player commits
- If the second player doesn't commit within 7 seconds, the first player can withdraw

```solidity
function hasCommitTimeoutOccurred() public view returns (bool) {
    if (!firstPlayerCommitted || numPlayer != 2) {
        return false;
    }
    return timeTracker.elapsedSeconds() >= COMMIT_TIMEOUT;
}
```

### 3. Withdrawal System

RPS_Secure adds a withdrawal function that allows players to recover their funds in two scenarios:

```solidity
function withdrawFunds() public {
    // Scenario 1: Only one player has joined and wants to withdraw
    if (numPlayer == 1 && msg.sender == players[0]) {
        // Reset game state and return funds
        // ...
    }
    
    // Scenario 2: Both players have joined, but the second player didn't commit in time
    require(numPlayer == 2, "Game must have exactly 2 players");
    require(firstPlayerCommitted, "First player hasn't committed yet");
    require(timeTracker.elapsedSeconds() >= COMMIT_TIMEOUT, "Timeout period not yet passed");
    
    // Additional checks and fund return logic
    // ...
}
```

This system prevents funds from being locked in the contract indefinitely.

## Example Game Flow

A step-by-step walkthrough of how a typical game would proceed with the security mechanisms in place:

### Normal Game Flow

1. **Player 1 Joins**
   - Player 1 calls `addPlayer()` and sends 1 ETH
   - The contract records Player 1's address and updates `numPlayer` to 1

2. **Player 2 Joins**
   - Player 2 calls `addPlayer()` and sends 1 ETH
   - The contract records Player 2's address and updates `numPlayer` to 2
   - Total reward is now 2 ETH

3. **Player 1 Commits**
   - Player 1 chooses their move (e.g., Rock - 0)
   - Player 1 calls `commitChoice()` with a hashed version of their choice
   - The `CommitReveal` contract stores the hash
   - The `firstPlayerCommitted` flag is set to true
   - The `timeTracker` starts counting

4. **Player 2 Commits**
   - Player 2 chooses their move (e.g., Paper - 1)
   - Player 2 calls `commitChoice()` with a hashed version of their choice
   - The `CommitReveal` contract stores the hash
   - Both players have now committed their choices

5. **Player 1 Reveals**
   - Player 1 calls `revealChoice()` with their original choice data
   - The contract verifies that the hash matches what was committed
   - Player 1's choice is recorded and `hasRevealed[player1]` is set to true
   - `numReveals` is incremented to 1

6. **Player 2 Reveals**
   - Player 2 calls `revealChoice()` with their original choice data
   - The contract verifies that the hash matches what was committed
   - Player 2's choice is recorded and `hasRevealed[player2]` is set to true
   - `numReveals` is incremented to 2

7. **Winner Determination**
   - Since both players have revealed, `_checkWinnerAndPay()` is automatically called
   - The contract determines that Paper (1) beats Rock (0)
   - Player 2 receives the entire 2 ETH reward
   - The contract resets for a new game

### Alternative Flows

#### Scenario: Player 2 Doesn't Commit in Time

1. Player 1 joins and commits their choice
2. Player 2 joins but doesn't commit within 7 seconds
3. Player 1 or Player 2 calls `withdrawFunds()`
4. The contract verifies that:
   - There are 2 players
   - The first player has committed
   - At least 7 seconds have passed since the first commit
   - Only one player has committed
5. Each player receives their 1 ETH back
6. The game state resets

#### Scenario: Player 1 Wants to Leave Before Player 2 Joins

1. Player 1 joins and sends 1 ETH
2. No second player joins
3. Player 1 calls `withdrawFunds()`
4. The contract verifies that:
   - Only 1 player has joined
   - The caller is that player
5. Player 1 receives their 1 ETH back
6. The game state resets

These flows demonstrate how the security mechanisms ensure fairness and prevent funds from being locked in various scenarios.

### 4. Additional Improvements

- **Improved State Management**: Better handling of game states and transitions
- **Enhanced Reset Function**: More comprehensive reset functionality that covers the new commit-reveal state
- **Clear Error Messages**: More detailed error messages for easier troubleshooting

## Security Principles Demonstrated

1. **Fairness**: The commit-reveal pattern ensures both players have equal opportunities
2. **Liveness**: The timeout mechanism prevents the game from stalling
3. **Fund Safety**: The withdrawal system prevents funds from being locked in the contract
4. **State Integrity**: Improved state management prevents inconsistent game states

These enhancements make RPS_Secure a more robust and secure implementation of the Rock Paper Scissors Lizard Spock game compared to the original RPS contract.

