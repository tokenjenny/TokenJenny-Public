pragma solidity ^0.8.0;
// SPDX-License-Identifier: Unlicensed

library SafeMath {
	function add(uint256 a, uint256 b) internal pure returns (uint256) {uint256 c = a + b; require(c >= a, "SafeMath: addition overflow"); return c;}	
	function sub(uint256 a, uint256 b) internal pure returns (uint256) {return sub(a, b, "SafeMath: subtraction overflow");}
	function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {require(b <= a, errorMessage);uint256 c = a - b;return c;}
	function mul(uint256 a, uint256 b) internal pure returns (uint256) {if (a == 0) {return 0;}uint256 c = a * b;require(c / a == b, "SafeMath: multiplication overflow");return c;}
	function div(uint256 a, uint256 b) internal pure returns (uint256) {return div(a, b, "SafeMath: division by zero");}
	function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {require(b > 0, errorMessage);uint256 c = a / b;return c;}
	function mod(uint256 a, uint256 b) internal pure returns (uint256) {return mod(a, b, "SafeMath: modulo by zero");}
	function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {require(b != 0, errorMessage);return a % b;}
}

interface IUniswapV2Router02 {
	function factory() external pure returns (address);
	function WETH() external pure returns (address);
	function swapExactTokensForTokens( uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline
	) external returns (uint[] memory amounts);
	function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts);
	function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
	function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts);
	function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline) external payable returns (uint[] memory amounts);
	function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
	function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
	function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
	function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
	function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

interface IERC20 {
    function owner() external view returns (address);
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function circSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

contract MatildaSwapper {
    using SafeMath for uint256;

    address public wETH;

    receive() external payable {
        assert(msg.sender == wETH); // only accept ETH via fallback from the WETH contract
    }

    constructor() {
        wETH = IUniswapV2Router02(0xf012702a5f0e54015362cBCA26a26fc90AA832a3).WETH();
    }

    function performSingleSwap(address routerAddress_, uint amountIn_, uint amountOutMin_, address[] calldata path_, address to_, uint deadline_) external payable returns (uint[] memory amounts) {
        IUniswapV2Router02 router02 = IUniswapV2Router02(routerAddress_);
        IERC20 token = IERC20(path_[0]);

        address to = msg.sender;
        if(to_ != address(0x0) && to_ != msg.sender && to_ != address(this)) {
            to = to_;
        }
        
        if(path_[0] == wETH || path_[path_.length.sub(1)] == wETH) {
            if(path_[0] == wETH) {
                require(amountIn_ == msg.value, "ERR: Amount In doesn't equal value to send");

                token.approve(routerAddress_, amountIn_);

                return router02.swapExactETHForTokens{value: amountIn_}(amountOutMin_, path_, to, deadline_);
            } else if(path_[path_.length.sub(1)] == wETH) {
                token.transferFrom(msg.sender, address(this), amountIn_);

                token.approve(routerAddress_, amountIn_);

                return router02.swapExactTokensForETH(amountIn_, amountOutMin_, path_, to, deadline_);
            } else {
                revert("ERR: Unknown");
            }
        } else {
            token.transferFrom(msg.sender, address(this), amountIn_);

            token.approve(routerAddress_, amountIn_);

            return router02.swapExactTokensForTokens(amountIn_, amountOutMin_, path_, to, deadline_);
        }
    }

    /*function performBestSwap(address[] memory routerAddresses_, uint[] memory amountIns_, uint[] memory amountOutMins_, address[] calldata paths0_, address[] calldata paths1_, address[] calldata paths2_, address to_, uint deadline_) external {
        require(routerAddresses_.length <= 3, "ERR: Too many swaps involved, 3 is the max");
        IUniswapV2Router01 router01;
        address wETH;

        address to = msg.sender;
        if(to_ != address(0x0)) {
            to = to_;
        }

        address[] memory pathToUse;
        for(uint i=0; i<3; i++) {
            router01 = IUniswapV2Router01(routerAddresses_[i]);
            wETH = router01.WETH();

            if(i == 0) {
                pathToUse = paths0_;
            } else if(i == 1) {
                pathToUse = paths1_;
            } else if(i == 2) {
                pathToUse = paths2_;
            } else {
                revert("Too many provided.");
            }

            if(pathToUse[0] == wETH) {
                router01.swapExactETHForTokens(amountOutMins_[i], pathToUse, to, deadline_);
            } else if(pathToUse[pathToUse.length.sub(1)] == wETH) {
                router01.swapExactTokensForETH(amountIns_[i], amountOutMins_[i], pathToUse, to, deadline_);
            } else {
                router01.swapExactTokensForTokens(amountIns_[i], amountOutMins_[i], pathToUse, to, deadline_);
            }
        }
    }*/

    function quote(address routerAddress_, uint amountA_, uint reserveIn_, uint reserveOut_) external pure returns (uint amountB) {
        return IUniswapV2Router02(routerAddress_).quote(amountA_, reserveIn_, reserveOut_);
    }

    function getAmountOut(address routerAddress_, uint amountIn_, uint reserveIn_, uint reserveOut_) external pure returns (uint amountOut) {
        return IUniswapV2Router02(routerAddress_).quote(amountIn_, reserveIn_, reserveOut_);
    }
}