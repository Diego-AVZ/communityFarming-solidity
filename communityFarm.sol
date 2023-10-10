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

    uint public ownerAmountA;
    uint public ownerAmountB;
    uint public totalAmountA;
    uint public totalAmountB;

    function depositOwnerColTokenA(uint amount) public onlyOwner{
        require(tokenA.approve(address(this), amount), "Approval failed");
        require(tokenA.transferFrom(msg.sender, address(this), amount));
        ownerAmountA = ownerAmountA + amount;
        totalAmountA = totalAmountA + amount;
    }

    function depositOwnerColTokenB(uint amount) public onlyOwner{
        require(tokenB.approve(address(this), amount), "Approval failed");
        require(tokenB.transferFrom(msg.sender, address(this), amount));
        ownerAmountB = ownerAmountB + amount;
        totalAmountB = totalAmountB + amount;
    }

    mapping(address => uint) public depositsA;
    mapping(address => uint) public depositsB;
    bool hasDepoA;
    bool hasDepoB;

	function depositTokens(uint amountA, uint amountB) public{
		//Token A
		require(tokenA.approve(address(this), amountA), "Approval failed");
        require(tokenA.transferFrom(msg.sender, address(this), amountA));
        depositsA[msg.sender] = depositsA[msg.sender] + amountA;
        totalAmountA = totalAmountA + amountA;
        hasDepoA = true;

		//Token B
		require(tokenB.approve(address(this), amountB), "Approval failed");
        require(tokenB.transferFrom(msg.sender, address(this), amountB));
        depositsB[msg.sender] = depositsB[msg.sender] + amountB;
        totalAmountB = totalAmountB + amountB;
        hasDepoB = true;

		uint amountAInDol = amountA * uint(getTokenAPrice());

		depositsPerUser memory newDepositsStruct = depositsPerUser(msg.sender, amountAInDol, amountB);
		depositList.push(newDepositsStruct);
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

	struct position {
		uint date;
		int priceA;
		uint percentA;
		uint percentB;
	}

	position[] positions;

	function addLiquidityToUni(uint amountLiqA, uint amountLiqB) public onlyOwner{
		/*
		Lógica para enviar a la  pool de Uniswap
		*/
		//registrar: del 'totalAmountA' y 'totalAmountB' los % que se han usado
		uint percA = amountLiqA*100 / totalAmountA; // Lo que se ha usado en la operación
		uint percB = amountLiqB*100 / totalAmountB;

		position memory newPos = position(block.timestamp, getTokenAPrice(), percA, percB);
		positions.push(newPos);

		//percA y percB son los % que se usan y que se aplicarán a lo usado de cada usuario

	}

	function claimFromUni() public onlyOwner {
		/*
			Lógica para claimear
		*/
		//Registrar la cantidad total de recompensas. se alamacena la recompensa en el contrato
		//se reparten las recompensas entre los usuarios proveedores
		uint totalFeesFromUni;
		//Hay que calcular el porcentaje de liquidez que ha depositado cada usuario respecto al total
		uint totalLiq = calcTotalLiq();
		
		//Repartir por % a Owner, a MyWallet y a cada user
		for(uint i = depositList.length - 1; i > 0; i--) {
			depositsPerUser memory depoPerUser2 = depositList[i];
			uint userPerc = calcPercDepUsers(depoPerUser2.user);
			tokenA.transferFrom(address(this), depoPerUser2.user, totalFeesFromUni*userPerc);
			tokenB.transferFrom(address(this), depoPerUser2.user, totalFeesFromUni*userPerc);
		}

	}

	struct depositsPerUser {
		address user;
		uint amountAInDol;
		uint amountBInDol; // Is Stablecoin
	}

	depositsPerUser public depoPerUser;

	depositsPerUser[] depositList;

	function calcPercDepUsers(address user) public view returns(uint) {
		for (uint32 i = 0; i < depositList.length; i++) {
			if (user == depoPerUser.user){
				uint percent = (uint(depoPerUser.amountAInDol) + uint(depoPerUser.amountBInDol))*100 / calcTotalLiq();
			}
		}
	}

	function calcTotalLiq() public view returns(uint) {
		return(totalAmountA * uint(getTokenAPrice()) + totalAmountB);
	}

	AggregatorV3Interface internal dataFeed;

    function getTokenAPrice() public view returns(int){
        ( , int answer, , ,) = dataFeed.latestRoundData();
        return(answer);
    }

	


}

    /*
    
    - Cada usuario podría retirar su liquidez en cualquier momento con el IL que haya
    - 

    */

    /*

    AggregatorV3Interface internal dataFeed;

    function getTokenAPrice() public view returns(int){
        ( , int answer, , ,) = dataFeed.latestRoundData();
        return(answer);
    }
    
    int priceTokenA;

    function setPriceA() public {
       priceTokenA = getTokenAPrice();
    }

*/

    //poolActionsUniV3 
    /*

    address public uniswapPool; 

    function setPool(address poolAddr) public{
        uniswapPool = poolAddr;
    }

    function addLiquidity(int24 tickLower, int24 tickUpper, uint128 amount) public onlyOwner{
        

        (uint256 amount0, uint256 amount1) = IUniswapV3PoolActions(uniswapPool).mint(
            address(this),
            tickLower,
            tickUpper,
            amount,
            bytes("")
        );

        totalAmountA = totalAmountA - amount0;
        totalAmountB = totalAmountB - amount1;
        
    }
}


//UNISWAP INTERFACE

interface IUniswapV3PoolActions {
    function initialize(uint160 sqrtPriceX96) external;

    function mint( address recipient, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data
    ) external returns (uint256 amount0, uint256 amount1);

    function collect( address recipient, int24 tickLower, int24 tickUpper, uint128 amount0Requested, uint128 amount1Requested
    ) external returns (uint128 amount0, uint128 amount1);

    function burn( int24 tickLower, int24 tickUpper, uint128 amount
    ) external returns (uint256 amount0, uint256 amount1);

}

*/
