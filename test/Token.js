const { BN, ether, balance } = require('openzeppelin-test-helpers');
const { expect } = require('chai');

const ShibaGalaxy = artifacts.require('ShibaGalaxy')

// const OneDoge = artifacts.require('OneDoge');
// const shibaGalaxyABI = require('./abi/shibaGalaxy');
// const shibaGalaxyAddress = '0xbECf3913f514950Cc7d4e11E1D7B792Ae63E4D2E';
// const tokenContract = new web3.eth.Contract(shibaGalaxyABI, shibaGalaxyAddress);

// const uniswapV2RouterABI = require('./abi/uniswapV2Router');
// const uniswapV2RouterAddress = '0x10ED43C718714eb63d5aA57B78B54704E256024E';
// const routerContract = new web3.eth.Contract(uniswapV2RouterABI, uniswapV2RouterAddress);
const owner = '0x67926b0C4753c42b31289C035F8A656D800cD9e7';

contract('test ShibaGalaxy', async([alice, bob, admin, dev, minter]) => {

    before(async () => {
        
    });

    it('token test', async() => {
        this.shibaGalaxy = await ShibaGalaxy.new(alice, {
            from: alice
        });

        // this.oneDoge = await OneDoge.new({from: alice});
        // await this.shibaGalaxy.setFeeActive(true,{from: tokenOwner});
        // await this.shibaGalaxy.setCooldownEnabled(true,{from: tokenOwner});

        // await routerContract.methods.addLiquidityETH(this.shibaGalaxy.address, "500000000000000000000000000", 0 , 0, owner, Date.now()).send({from: owner, value: "1000000000000000000"});
    })
})