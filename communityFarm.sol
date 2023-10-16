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

/*_____________________________*/


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
        require(msg.sender == owner, "not Owner of this Contract");
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

	struct depositsPerUser {
		address user;
		uint amountAInDol;
		uint amountBInDol; // Is Stablecoin
	}

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

    

		// PARA RETIROS
			// userWithdrawFromUni() -> El usuario interactua con UNI y puede retirar al contrato lo que le corresponde de liquidez
			// userWithdrawFromContract() -> si hay posición abierta, llama a la primera función y después El usuario retira toda la liquidez que le corresponde de este contrato
			// haz otra f() en la que El owner cierra la posición y los usuarios pueden retirar con userWithdrawFromContract()

	function userWithdrawFromUni() public {
		require(hasDepoA || hasDepoB);
		require(positionOpened == true);
		
		// Se llama a la función de 'retirar liquidez' de UNISWAP con el % que ha aportado el user

		position memory lastPosition = positions[positions.length -1];
		uint percA = lastPosition.percentA; // % que se ha usado en la lastPosition, esto es = lo que se ha usado de total deositado por msg.sender
		uint percB = lastPosition.percentB;

		uint usedAmountA = depositsA[msg.sender] * percA; // cantidad usada en la posición
		uint usedAmountB = depositsB[msg.sender] * percB;
		uint unUsedAmountA = depositsA[msg.sender] - usedAmountA;
		uint unUsedAmountB = depositsB[msg.sender] - usedAmountB;

		//Lo que queda en uniswap TRAS el IL
		uint actualUniLiqA; // No se como obtenerlo
		uint actualUniLiqB;
		// cantidad que tiene ahora el usuario:
		uint userActualAmountA = actualUniLiqA * percA; // Lo que hay que devolver al usuario
		uint userActualAmountB = actualUniLiqB * percB;

		require(tokenA.transferFrom(address(uniswap), address(this), userActualAmountA)); // Algo así
		require(tokenB.transferFrom(address(uniswap), address(this), userActualAmountB));

		// Una vez trasferidos los tokens a este contrato, se actualiza la cantidad depositada
		// es la cantidad no usada en la posición + lo que habia en uniswap y que correspondía al usuario
		depositsA[msg.sender] = unUsedAmountA + userActualAmountA; 
		depositsB[msg.sender] = unUsedAmountB + userActualAmountB;

		// Las userActualAmount estarán en este contrato y el usuario puede retirar todo = userActualAmountA y unUsedAmount
		
	
	}

	function userWithdrawFromContract() public {
		require(hasDepoA || hasDepoB);
		if(positionOpened == true){
			userWithdrawFromUni();
		}

		totalAmountA = totalAmountA - depositsA[msg.sender];
        	totalAmountB = totalAmountB - depositsB[msg.sender]; // Se resta lo que habían depositado
		
		require(tokenA.transferFrom(address(this), msg.sender, depositsA[msg.sender]));
		require(tokenB.transferFrom(address(this), msg.sender, depositsB[msg.sender]));

		depositsA[msg.sender] = 0;                           // Despues se iguala a 0
       		depositsB[msg.sender] = 0;
		
	}

	struct position {
		uint date;
		int priceA;
		uint percentA;
		uint percentB;
	
	}

	bool public positionOpened;

	position[] positions;

	function addLiquidityToUni(uint amountLiqA, uint amountLiqB) public onlyOwner{
		require(positionOpened == false, "Close Position, then open a new Position");
		/*
		Lógica para enviar a la  pool de Uniswap
		*/
		uint percA = amountLiqA * 100 / totalAmountA; // Lo que se ha usado en la operación
		uint percB = amountLiqB * 100 / totalAmountB;

		position memory newPos = position(block.timestamp, getTokenAPrice(), percA, percB);
		positions.push(newPos);

		
		positionOpened = true;

	}

	function withdrawUniLiquidity() public onlyOwner {
		positionOpened = false;
	}

	address protocolAddress = 0x3fE959Dc78ed8948831df6a5453f32fD8AEDA8de4 ;

	function claimFromUni() public onlyOwner {
		/*
			Lógica UNI para claim
		*/
		
		uint tokenAFeesFromUni;
		uint tokenBFeesFromUni;
		uint totalLiq = calcTotalLiqA() + calcTotalLiqB() ;
		uint userFee = 1 / 2;       // 50%
		uint ownerFee = 9 / 20 ;     // 45%
		uint protocolFee = 1 / 20 ;   // 5%

		for(uint i = depositList.length - 1; i > 0; i--) {
			depositsPerUser memory depoPerUser2 = depositList[i];
			uint userPercA = calcPercDepUsersA(depoPerUser2.user);
			uint userPercB = calcPercDepUsersB(depoPerUser2.user);
			tokenA.transferFrom(address(this), depoPerUser2.user, tokenAFeesFromUni * userPercA * userFee);
			tokenB.transferFrom(address(this), depoPerUser2.user, tokenBFeesFromUni * userPercB * userFee);
		}

		tokenA.transferFrom(address(this), owner, tokenAFeesFromUni * ownerFee);
		tokenB.transferFrom(address(this), owner, tokenBFeesFromUni * ownerFee);

		tokenA.transferFrom(address(this), protocolAddress, tokenAFeesFromUni * protocolFee);
		tokenB.transferFrom(address(this), protocolAddress, tokenBFeesFromUni * protocolFee);

	}

	depositsPerUser public depoPerUser;

	depositsPerUser[] depositList;

	function calcPercDepUsersA(address user) public view returns(uint) {
		for (uint32 i = 0; i < depositList.length; i++) {
			if (user == depoPerUser.user){
				return(uint(depoPerUser.amountAInDol)*100 / calcTotalLiqA());
			}
		}
	}

	function calcPercDepUsersB(address user) public view returns(uint) {
		for (uint32 i = 0; i < depositList.length; i++) {
			if (user == depoPerUser.user){
				uint percent = uint(depoPerUser.amountBInDol)*100 / calcTotalLiqB();
			}
		}
	}

	function calcTotalLiqA() public view returns(uint) {
		return(totalAmountA * uint(getTokenAPrice())); // $ totales depositados de A
	}

	function calcTotalLiqB() public view returns(uint) {
		return(totalAmountB); // $ totales depositados de B
	}

	AggregatorV3Interface internal dataFeed;

    function getTokenAPrice() public view returns(int){
        ( , int answer, , ,) = dataFeed.latestRoundData();
        return(answer);
    }

	


}

//Considera añadir una función de seguro de IL donde el owner deposita un colateral que se hace cargo del IL de los usuarios con un incentivo de fee


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
