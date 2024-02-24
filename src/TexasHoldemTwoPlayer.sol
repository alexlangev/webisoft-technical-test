// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

contract TexasHoldemTwoPlayers {
    address public immutable  player1;
    address public immutable  player2;
    address public immutable dealer; 
    uint256 public immutable entranceFee;
    uint256 public immutable totalPot;

    address public currentPlayer; // The player that does the next move
    mapping(address => uint) public playerPot; // the amount of eth the player has left to play
    mapping(address => uint) public playerCurrentBid; // the amount of eth the player has invested in the current round

    error CallerNotDealer();
    error InvalidWinner();
    error InvalidPlayer();

    event GameStarted(address indexed player1, address indexed player2, uint256 totalPot);
    event PlayerFolded(address indexed player);
    event PlayerCalled(address indexed player);
    event PlayerRaised(address indexed player, uint256 amount);
    event PlayerWon(address indexed player, uint256 amount);

    enum Phase { Deal, Flop, Turn, River, Showdown }
    Phase public phase;

    modifier onlyDealer() {
        // I'm this pattern since it's cheaper than using require.
        if(msg.sender != dealer) {
            revert CallerNotDealer();
        }
        _;
    }

    modifier onlyPlaying() {
        // I'm this pattern since it's cheaper than using require.
        if(msg.sender != currentPlayer){
            revert InvalidPlayer();
        }

        _;
    }

    // All values that change from game to game like player addresses, fees etc. should be declared in the constructor
    constructor(address payable _player1Address, address payable _player2Address, address _dealerAddress, uint256 _entranceFee) payable {
        require(_entranceFee > 0, "Invalid buy-in amount");
        require(_player1Address != address(0) && _player2Address != address(0),  "Players acan't have the 0 address");
        require(_player1Address != _player2Address, "Players have the same address");
        require(_player1Address != _dealerAddress && _player2Address != _dealerAddress, "Dealer can't be a player");

        player1 = _player1Address;
        player2 = _player2Address;
        entranceFee = _entranceFee;
        dealer = _dealerAddress;
        totalPot = msg.value;
        phase = Phase.Deal;
        currentPlayer = player1; 

        emit GameStarted(_player1Address, _player2Address, msg.value);
    }

    // A function that handles the fold logic.
    function fold() public onlyPlaying {
        address playerFolding = currentPlayer;
        address nextPlayer = NextTurn();

        playerCurrentBid[playerFolding] = 0; 
        playerPot[nextPlayer] += playerCurrentBid[playerFolding];

        emit PlayerFolded(playerFolding);
    }

    // A function that handles the call logic.
    function call() public onlyPlaying {
        address playerCalling = currentPlayer;
        address nextPlayer = NextTurn();
        require(playerPot[playerCalling] >= playerCurrentBid[nextPlayer], "Not enough funds to call");

        uint256 difference = playerCurrentBid[nextPlayer] - playerCurrentBid[playerCalling];
        playerPot[playerCalling] -= difference;
        playerCurrentBid[playerCalling] = playerCurrentBid[nextPlayer]; 

        emit PlayerCalled(playerCalling);
    }

    // A function that handles the raise logic.
    function raise(uint256 _raiseAmount) public onlyPlaying {
        address playerRaising = currentPlayer;
        require(playerPot[playerRaising] >= _raiseAmount, "Not enough funds to raise");
        address nextPlayer = NextTurn();
        require(_raiseAmount > playerCurrentBid[nextPlayer], "Must raise to a bigger amount that the current opponents bid");

        uint256 difference = _raiseAmount - playerCurrentBid[playerRaising];
        playerPot[playerRaising] -= difference;
        playerCurrentBid[playerRaising] = _raiseAmount; 

        emit PlayerRaised(playerRaising, _raiseAmount);
    }

    // Function that handles the distribution of the winnings.
    function endGame(address _winnerAddress) public onlyDealer {
        if(_winnerAddress != player1 && _winnerAddress != player2){
            revert InvalidWinner();
        }
        
        // Does the house take a % of this? If so, transfer the correct amount to the dealer's wallet.
        payable(_winnerAddress).transfer(totalPot); // use address(this).balance instead?
        emit PlayerWon(_winnerAddress, totalPot);
    }

    /**
        Core game loop should be handled here. It currently only changes the current players turns.
        With more time I would have implemented some logic. A quick althought suboptimal solution could be 
        multiple if-else that handles Phase.Flop, Phase.Turn, Phase.River and Phase.Showdown respectively.
    */
    function NextTurn() internal returns (address){
        if(currentPlayer == player1){
            currentPlayer = player2;
            return player2;
        } else {
            currentPlayer = player1;
            return player1;
        }
    }
}

/**
    Things left to implement:
    - complete the core game loop going from one phase to the next.
    - Implement the rake logic. I am not sure if it's calculated every round or only at the end.
    - Set initial bid based of who has the big blind and small blind.
    - A lot more...
 */