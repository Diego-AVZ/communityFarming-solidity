//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract factory{

    mapping(string => address) public searchContractName;
    

    function createYourContractBTC_USDT(string memory contractName) public {
        address newContractOwner = msg.sender;
        communityFarm newSocialFarming = new communityFarm(
            newContractOwner,
            contractName, 
            0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9 /*USDT*/, 
            0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f /*wBTC*/
        );
        searchContractName[contractName] = address(newSocialFarming);
    }
}


import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";



contract communityFarm {

    string public contractName;
    IERC20 public tokenA;
    IERC20 public tokenB;

    constructor (address _owner, string memory _contractName, address _tokenA, address _tokenB) {
        owner = _owner;
        contractName = _contractName;
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        dataFeed = AggregatorV3Interface(
            0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43
        );
    }

    address public owner;

    modifier onlyOwner() {
        require(msg.sender == owner, "not Owner of this C0ntract");
        _;
    }

    uint public ownerColateralA;
    uint public ownerColateralB;
    uint public totalAmountA;
    uint public totalAmountB;

    function depositOwnerColTokenA(uint amount) public onlyOwner{
        require(tokenA.approve(address(this), amount), "Approval failed");
        require(tokenA.transferFrom(msg.sender, address(this), amount));
        ownerColateralA = ownerColateralA + amount;
        totalAmountA = totalAmountA + amount;
    }

    function depositOwnerColTokenB(uint amount) public onlyOwner{
        require(tokenB.approve(address(this), amount), "Approval failed");
        require(tokenB.transferFrom(msg.sender, address(this), amount));
        ownerColateralB = ownerColateralB + amount;
        totalAmountB = totalAmountB + amount;
    }

    uint public timeLocked;

    function setLockTime(uint _timelocked) public {
        timeLocked = _timelocked * 1 days;
    }

    mapping(address => uint) public depositsA;
    mapping(address => uint) public depositsB;
    bool hasDepoA;
    bool hasDepoB;

    function depositTokenA(uint amount) public{
        require(hasDepoA == false);
        require(tokenA.approve(address(this), amount), "Approval failed");
        require(tokenA.transferFrom(msg.sender, address(this), amount));
        depositsA[msg.sender] = depositsA[msg.sender] + amount;
        totalAmountA = totalAmountA + amount;
        hasDepoA = true;
    }

    function depositTokenB(uint amount) public{
        require(hasDepoB == false);
        require(tokenB.approve(address(this), amount), "Approval failed");
        require(tokenB.transferFrom(msg.sender, address(this), amount));
        depositsB[msg.sender] = depositsB[msg.sender] + amount;
        totalAmountB = totalAmountB + amount;
        hasDepoB = true;
    }

    function withdrawAllDeposits() public { // Dependiendo de la opcion elegida, aqui habría que calcular el IL
        require(hasDepoA || hasDepoB);
        require(tokenA.transferFrom(address(this), msg.sender, depositsA[msg.sender]));
        require(tokenB.transferFrom(address(this), msg.sender, depositsB[msg.sender]));
        depositsA[msg.sender] = 0;
        depositsB[msg.sender] = 0;
        totalAmountA = totalAmountA - depositsA[msg.sender];
        totalAmountB = totalAmountB - depositsB[msg.sender];
        hasDepoB = false; hasDepoA = false;
    }

    AggregatorV3Interface internal dataFeed;

    function getTokenAPrice() public view returns(int){
        ( , int answer, , ,) = dataFeed.latestRoundData();
        return(answer);
    }
    
    int priceTokenA;

    function setPriceA() public {
       priceTokenA = getTokenAPrice();
    }
}
