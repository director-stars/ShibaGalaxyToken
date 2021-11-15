// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/SafeCast.sol";

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Pair {
    function sync() external;
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
      address token,
      uint liquidity,
      uint amountTokenMin,
      uint amountETHMin,
      address to,
      uint deadline
    ) external returns (uint amountETH);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
}

contract Wallet {}

contract ShibaGalaxy is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;
    using SafeCast for int256;
  
    string private _name = "ShibaGalaxy";
    string private _symbol = "SHIBGX";
    uint8 private _decimals = 18;

    mapping(address => uint256) internal _reflectionBalance;
    mapping(address => uint256) internal _tokenBalance;
    mapping(address => mapping(address => uint256)) internal _allowances;

    uint256 private constant MAX = ~uint256(0);
    uint256 internal _tokenTotal = 1_000_000_000e18;
    uint256 internal _reflectionTotal = (MAX - (MAX % _tokenTotal));

    mapping(address => bool) blacklist;
    mapping(address => bool) isTaxless;
    mapping(address => bool) internal _isExcluded;
    address[] internal _excluded;
        
    //all fees
    uint256 public feeDecimal = 2;
    uint256 public liquidityFee = 100;
    uint256 public marketingFee = 100;
    uint256 public buyBackFee = 200;
    uint256 public vaultFee = 400;
   
    uint256 public liquidityFeeTotal;
    uint256 public marketingFeeTotal;
    uint256 public buybackTotal;
    uint256 public vaultFeeTotal;
    
    uint256 public tradingVolume;
    uint256 public lastVolumnTrack;
    uint256 public lastVaultSwapTrack;

    address public marketingWallet;
    address public admin;
    address public buybackWallet;
    address public vaultWallet;
    address public bnbVaultWallet;
    
    bool private inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public isFeeActive = false; // should be true, after listing
    
    uint256 public maxTxAmount = _tokenTotal.mul(5).div(1000);// 0.5%
    uint256 public maxSwapAmount = _tokenTotal.mul(1).div(1000);// 0.1%
    uint256 public minTokensBeforeSwap = 100_000e18;
    
    bool public cooldownEnabled = false; // should be true, after listing
        
    mapping(address => uint256) public transferAmounts;
    mapping(address => uint256) public lastCooldownCycleStart;
    mapping(address => uint256) public cooldown;
    uint256 public cooldownTime = 4 hours;
    uint256 public vaultSwapCooldownTime = 1 hours;
    uint256 public cooldownAmount = _tokenTotal.mul(5).div(1000); // 0.5%

    uint256 public disruptiveTransferFee = 2 ether;
    bool public disruptiveTransferEnabled = true;

    IUniswapV2Router02 public  uniswapV2Router;
    address public  uniswapV2Pair;
    
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(uint256 tokensSwapped,uint256 ethReceived, uint256 tokensIntoLiqudity);

    modifier lockTheSwap {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    modifier onlyOwnerAndAdmin() {
        require(owner() == _msgSender() || _msgSender() == admin, "Ownable: caller is not the owner or admin");
        _;
    }

    constructor() public {
        // IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E); // Pancakeswap Router
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0xf946634f04aa0eD1b935C8B876a0FD535F993D43); // Pancakeswap Router
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;
       
        buybackWallet = address(new Wallet());
        vaultWallet = address(new Wallet());
        
        address _owner = 0x67926b0C4753c42b31289C035F8A656D800cD9e7;
        marketingWallet = 0x67926b0C4753c42b31289C035F8A656D800cD9e7;
        admin = 0x67926b0C4753c42b31289C035F8A656D800cD9e7;
        bnbVaultWallet = 0x67926b0C4753c42b31289C035F8A656D800cD9e7;

        // address _owner = 0xb35869eCfB96c27493cA281133edd911e479d0D9;
        // marketingWallet = 0xe234Adb58788EE9F02fCA8B5DB6593a26ab4FF47;
        // admin = 0x67926b0C4753c42b31289C035F8A656D800cD9e7;
        // bnbVaultWallet = 0x66E5c73F9c0197b18C0876f2e132b164ebC4BBBb;
        
        isTaxless[_owner] = true;
        isTaxless[admin] = true;
        isTaxless[marketingWallet] = true;

        _isExcluded[uniswapV2Pair] = true;
        _excluded.push(uniswapV2Pair);
        _isExcluded[0x000000000000000000000000000000000000dEaD] = true;
        _excluded.push(0x000000000000000000000000000000000000dEaD);
        _isExcluded[0x0000000000000000000000000000000000000000] = true;
        _excluded.push(0x0000000000000000000000000000000000000000);
      
        _reflectionBalance[_owner] = _reflectionTotal;
        _tokenBalance[_owner] = _tokenTotal;
        emit Transfer(address(0), _owner, _tokenTotal);
        
        transferOwnership(_owner);
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    function totalSupply() public override view returns (uint256) {
        return _tokenTotal;
    }

    function balanceOf(address account) public override view returns (uint256) {
        if (_isExcluded[account]) return _tokenBalance[account];
        return tokenFromReflection(_reflectionBalance[account]);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        virtual
        returns (bool)
    {
       _transfer(_msgSender(),recipient,amount);
        return true;
    }
    
    function disruptiveTransfer(address recipient, uint256 amount)
        public
        payable
        returns (bool)
    {
       _transfer(_msgSender(),recipient,amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        override
        view
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override virtual returns (bool) {
        _transfer(sender,recipient,amount);
               
        _approve(sender,_msgSender(),_allowances[sender][_msgSender()].sub( amount,"ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    function isExcluded(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    function reflectionFromToken(uint256 tokenAmount)
        public
        view
        returns (uint256)
    {
        require(tokenAmount <= _tokenTotal, "Amount must be less than supply");
        return tokenAmount.mul(_getReflectionRate());
    }

    function tokenFromReflection(uint256 reflectionAmount)
        public
        view
        returns (uint256)
    {
        require(reflectionAmount <= _reflectionTotal, "Amount must be less than total reflections");
        return reflectionAmount.div(_getReflectionRate());
    }

    function excludeAccount(address account) external onlyOwner() {
        require(
            account != address(uniswapV2Router),
            "TOKEN: We can not exclude Uniswap router."
        );
        
        require(!_isExcluded[account], "TOKEN: Account is already excluded");
        if (_reflectionBalance[account] > 0) {
            _tokenBalance[account] = tokenFromReflection(
                _reflectionBalance[account]
            );
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeAccount(address account) external onlyOwner() {
        require(_isExcluded[account], "TOKEN: Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tokenBalance[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        require(
            isTaxless[sender] 
            || isTaxless[recipient] 
            || sender == uniswapV2Pair // only apply fee to sell
            || (msg.value >= disruptiveTransferFee && disruptiveTransferEnabled)
            || amount <= maxTxAmount,
            "Max Transfer Limit Exceeds!"
        );
        
        require(!blacklist[sender], "Banned!");
        
        if(lastVolumnTrack + 1 days < block.timestamp){
            tradingVolume = 0;
            lastVolumnTrack = block.timestamp;
        }
        tradingVolume = tradingVolume.add(amount);
        
        // cooldown for sell and p2p
        if(cooldownEnabled && sender != uniswapV2Pair && msg.value == 0 && !isTaxless[sender]) {
            if(lastCooldownCycleStart[sender] + cooldownTime < block.timestamp){
                lastCooldownCycleStart[sender] = block.timestamp;
                transferAmounts[sender] = 0;
            }
            transferAmounts[sender] = transferAmounts[sender].add(amount);
            require(transferAmounts[sender] <= cooldownAmount, "Err: Sell Cooldown");
        }
        
        uint256 transferAmount = amount;
        uint256 rate = _getReflectionRate();
        
        if(msg.value > 0) {
            buyAndBurnToken();
        } else {
            //swapAndLiquify
            uint256 contractTokenBalance = balanceOf(address(this));
            if (swapAndLiquifyEnabled && !inSwapAndLiquify && sender != uniswapV2Pair && contractTokenBalance >= minTokensBeforeSwap) {
                swapAndLiquify(contractTokenBalance);
            }
        }
        
        if(isFeeActive && !isTaxless[sender] && !isTaxless[recipient] && !inSwapAndLiquify) {
            transferAmount = collectFee(sender,recipient,amount,rate);
        }

        //transfer reflection
        _reflectionBalance[sender] = _reflectionBalance[sender].sub(amount.mul(rate));
        _reflectionBalance[recipient] = _reflectionBalance[recipient].add(transferAmount.mul(rate));

        //if any account belongs to the excludedAccount transfer token
        if (_isExcluded[sender]) {
            _tokenBalance[sender] = _tokenBalance[sender].sub(amount);
        }
        if (_isExcluded[recipient]) {
            _tokenBalance[recipient] = _tokenBalance[recipient].add(transferAmount);
        }

        emit Transfer(sender, recipient, transferAmount);
    }
   
    function collectFee(address account, address to, uint256 amount, uint256 rate) private returns (uint256) {
        uint256 transferAmount = amount;

        // @dev market fee
        if(marketingFee != 0){
            uint256 _marketingFee = amount.mul(marketingFee).div(10**(feeDecimal + 2));
            transferAmount = transferAmount.sub(_marketingFee);
            _reflectionBalance[marketingWallet] = _reflectionBalance[marketingWallet].add(_marketingFee.mul(rate));
            if (_isExcluded[marketingWallet]) {
                _tokenBalance[marketingWallet] = _tokenBalance[marketingWallet].add(_marketingFee);
            }
            marketingFeeTotal = marketingFeeTotal.add(_marketingFee);
            emit Transfer(account,marketingWallet,_marketingFee);
        }

        // @dev buyBack fee
        if(buyBackFee != 0){
            uint256 _buyBackFee = amount.mul(buyBackFee).div(10**(feeDecimal + 2));
            transferAmount = transferAmount.sub(_buyBackFee);
            buybackTotal = buybackTotal.add(_buyBackFee);
            _tokenTotal = _tokenTotal.sub(_buyBackFee);
            _reflectionTotal = _reflectionTotal.sub(_buyBackFee.mul(rate));
            emit Transfer(account, address(0), _buyBackFee);
        }
  
        // @dev liquidity fee
        if(liquidityFee != 0){
            uint256 _liquidityFee = amount.mul(liquidityFee).div(10**(feeDecimal + 2));
            transferAmount = transferAmount.sub(_liquidityFee);
            _reflectionBalance[address(this)] = _reflectionBalance[address(this)].add(_liquidityFee.mul(rate));
            if (_isExcluded[address(this)]) {
                _tokenBalance[address(this)] = _tokenBalance[address(this)].add(_liquidityFee);
            }
            liquidityFeeTotal = liquidityFeeTotal.add(_liquidityFee);
            emit Transfer(account,address(this),_liquidityFee);
        }
        
        // @dev vault fee
        if(vaultFee != 0 && to == uniswapV2Pair){
            uint256 _vaultFee = amount.mul(vaultFee).div(10**(feeDecimal + 2));
            transferAmount = transferAmount.sub(_vaultFee);

            _reflectionBalance[address(vaultWallet)] = _reflectionBalance[address(vaultWallet)].add(_vaultFee.mul(rate));
            if (_isExcluded[address(vaultWallet)]) {
                _tokenBalance[address(vaultWallet)] = _tokenBalance[address(vaultWallet)].add(_vaultFee);
            }
            vaultFeeTotal = vaultFeeTotal.add(_vaultFee);

            if(lastVaultSwapTrack + vaultSwapCooldownTime < block.timestamp){
                uint256 swapAmount = balanceOf(address(vaultWallet));
                if(swapAmount > maxSwapAmount)
                    swapAmount = maxSwapAmount;
                vaultSwap(swapAmount, rate);
                lastVaultSwapTrack = block.timestamp;

            }
            emit Transfer(account,address(vaultWallet),_vaultFee);
        }

        return transferAmount;
    }

    function _getReflectionRate() private view returns (uint256) {
        uint256 reflectionSupply = _reflectionTotal;
        uint256 tokenSupply = _tokenTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _reflectionBalance[_excluded[i]] > reflectionSupply ||
                _tokenBalance[_excluded[i]] > tokenSupply
            ) return _reflectionTotal.div(_tokenTotal);
            reflectionSupply = reflectionSupply.sub(
                _reflectionBalance[_excluded[i]]
            );
            tokenSupply = tokenSupply.sub(_tokenBalance[_excluded[i]]);
        }
        if (reflectionSupply < _reflectionTotal.div(_tokenTotal))
            return _reflectionTotal.div(_tokenTotal);
        return reflectionSupply.div(tokenSupply);
    }
    
     function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
         if(contractTokenBalance > maxSwapAmount)
            contractTokenBalance = maxSwapAmount;
            
        // split the contract balance into halves
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        // capture the contract's current ETH balance.
        // this is so that we can capture exactly the amount of ETH that the
        // swap creates, and not make the liquidity event include any ETH that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        swapTokensForEth(half, address(this)); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(initialBalance);

        // add liquidity to uniswap
        addLiquidity(otherHalf, newBalance);
        
        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function vaultSwap(uint256 swapAmount, uint256 rate) private lockTheSwap {
        swapTokensForEthOnVault(swapAmount, bnbVaultWallet, rate);
    }

    function swapTokensForEthOnVault(uint256 tokenAmount, address receiver, uint256 rate) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _reflectionBalance[address(vaultWallet)] = _reflectionBalance[address(vaultWallet)].sub(tokenAmount.mul(rate));
        if (_isExcluded[address(vaultWallet)]) {
            _tokenBalance[address(vaultWallet)] = _tokenBalance[address(vaultWallet)].sub(tokenAmount);
        }

        _reflectionBalance[address(this)] = _reflectionBalance[address(this)].add(tokenAmount.mul(rate));
        if (_isExcluded[address(this)]) {
            _tokenBalance[address(this)] = _tokenBalance[address(this)].add(tokenAmount);
        }

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            receiver,
            block.timestamp
        );
    }

    function swapTokensForEth(uint256 tokenAmount, address receiver) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            receiver,
            block.timestamp
        );
    }
   
    function swapEthForTokens() private {
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: address(this).balance}(
                0,
                path,
                address(buybackWallet),
                block.timestamp
            );
    }
   
    function buyAndBurnToken() private lockTheSwap {
        //@dev Uniswap doesn't allow for a token to buy itself, so we have to use an external account
        swapEthForTokens();

        //@dev How much tokens we swaped into
        uint256 swapedTokens = balanceOf(address(buybackWallet));

        uint256 rate =  _getReflectionRate();

        _reflectionBalance[address(buybackWallet)] = 0;
        if (_isExcluded[address(buybackWallet)]) {
            _tokenBalance[address(buybackWallet)] = 0;
        }
        
        buybackTotal = buybackTotal.add(swapedTokens);
        _tokenTotal = _tokenTotal.sub(swapedTokens);
        _reflectionTotal = _reflectionTotal.sub(swapedTokens.mul(rate));
        
        emit Transfer(address(buybackWallet), address(0), swapedTokens);
    }
   
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }
   
    function setTaxless(address account, bool value) external onlyOwnerAndAdmin {
        isTaxless[account] = value;
    }
    
    function setBlacklist(address account, bool value) external onlyOwnerAndAdmin {
        blacklist[account] = value;
    }
    
    function setSwapAndLiquifyEnabled(bool enabled) external onlyOwnerAndAdmin {
        swapAndLiquifyEnabled = enabled;
        SwapAndLiquifyEnabledUpdated(enabled);
    }
    
    function setFeeActive(bool value) external onlyOwnerAndAdmin {
        isFeeActive = value;
    }
    
    function setLiquidityFee(uint256 fee) external onlyOwnerAndAdmin {
        liquidityFee = fee;
    }
    
    function setMarketingFee(uint256 fee) external onlyOwnerAndAdmin {
        marketingFee = fee;
    }
    
    function setMarketingWallet(address wallet) external onlyOwnerAndAdmin {
        marketingWallet = wallet;
    }

    function setVaultFee(uint256 fee) external onlyOwnerAndAdmin {
        vaultFee = fee;
    }

    function setBnbVaultWallet(address wallet) external onlyOwnerAndAdmin {
        bnbVaultWallet = wallet;
    }
    
    function setAdmin(address account) external onlyOwner {
        admin = account;
    }

    function setMaxTransferAmount(uint256 maxAmount) external onlyOwnerAndAdmin {
        maxTxAmount = maxAmount;
    }

    function setMaxSwapAmount(uint256 maxAmount) external onlyOwnerAndAdmin {
        maxSwapAmount = maxAmount;
    }
    
    function setMinTokensBeforeSwap(uint256 amount) external onlyOwnerAndAdmin {
        minTokensBeforeSwap = amount;
    }
    
    function setCooldownEnabled(bool value) external onlyOwnerAndAdmin {
        cooldownEnabled = value;
    }
    
    function setCooldown(uint256 interval, uint256 amount) external onlyOwnerAndAdmin {
        cooldownTime = interval;
        cooldownAmount = amount;
    }

    function setVaultSwapCooldownTime(uint256 interval) external onlyOwnerAndAdmin {
        vaultSwapCooldownTime = interval;
    }
    
    function setDisruptiveTransfer(uint256 _fee, bool _enabled) external onlyOwnerAndAdmin {
        disruptiveTransferFee = _fee;
        disruptiveTransferEnabled = _enabled;
    }
    
    receive() external payable {}
}