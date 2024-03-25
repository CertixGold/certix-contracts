const CertixToken = artifacts.require("CertixToken");
const { deployProxy } = require('@openzeppelin/truffle-upgrades');

contract("CertixToken", accounts => {
  const [deployer, user1, user2] = accounts;
  let certixToken;

    before(async function () {
        const maxSupply = "100000000000000000000000";
        certixToken = await deployProxy(CertixToken, ["CTX", "CTX", maxSupply], { from: deployer, initializer: 'initialize' });
    });


    it("should mint the total supply to the deployer", async () => {
        const totalSupply = await certixToken.totalSupply();
        const deployerBalance = await certixToken.balanceOf(deployer);
        assert.equal(totalSupply.toString(), deployerBalance.toString(), "Total supply was not minted to the deployer");
    });

    it("should transfer & burn tokens between accounts", async () => {
        // Assume deployer has all tokens from the minting in the initialization
        await certixToken.transfer(user1, 1000, { from: deployer });
        const balanceUser1 = await certixToken.balanceOf(user1);//Burn fees = 0.1%
        assert.equal(balanceUser1.toString(), "999", "Transfer did not complete correctly");
    });

    it("should apply skip burn list correctly", async () => {
        // Skip burn fee for user1 for simplicity
        await certixToken.addToSkipBurnFeesList(user1, { from: deployer });

        // Transfer tokens from user1 to user2
        await certixToken.transfer(user2, 999, { from: user1 });
        const balanceUser2 = await certixToken.balanceOf(user2);
        // Assuming no burn due to skip list, else calculate expected with burn rate
        assert.equal(balanceUser2.toString(), "999", "Skip Burn list was not applied correctly");
    });

    it("should not allow blacklisted account to transfer tokens", async () => {
        await certixToken.addToBlacklist(user2, { from: deployer });

        try {
        await certixToken.transfer(user1, 500, { from: user2 });
            assert.fail("Should have thrown an error");
        } catch (error) {
            assert.include(error.message, "blacklisted", "Error should be related to blacklist");
        }

        await certixToken.removeFromBlacklist(user2, { from: deployer });
    });

    it("should block transfers when paused", async function () {
        await certixToken.pause({ from: deployer });
        try {
            await certixToken.transfer(user1, 999, { from: user2 });
            assert.fail("Transfer should not succeed while paused");
        } catch (error) {
            console.log("    ✔ Ok pause works!")
        }
    });

    it("should allow transfers when unpaused", async function () {
        await certixToken.addToSkipBurnFeesList(user2, { from: deployer });
        await certixToken.unpause({ from: deployer });
        await certixToken.transfer(user1, 999, { from: user2 });
        const balance = await certixToken.balanceOf(user1);
        assert.equal(balance.toString(), "999", "Transfer did not succeed after unpausing");
    });

    it("verifies the burn fee based on the user tier & check if supply reduced", async () => {
        const supplyBeforeBurn = parseFloat(web3.utils.fromWei((await certixToken.totalSupply()) + "", "ether")).toFixed(2)
        // Montant du transfert
        const transferAmount = web3.utils.toBN(web3.utils.toWei('40', "ether"));
        // Récupérer le tier de l'utilisateur et le burn fee associé
        const userTier = await certixToken.getUserTier(deployer);
        const burnFeePercentage = userTier.transactionBurnFee; // suppose que c'est en points de base, par exemple, 100 pour 1%
        //console.log("burnFeePercentage "+burnFeePercentage)
        // Calculer le montant attendu à brûler
        const expectedBurnAmount = web3.utils.fromWei(((transferAmount * burnFeePercentage) / 10000)+"", "ether");
        //console.log("expectedBurnAmount : "+expectedBurnAmount)
        
        // Solde initial du receveur
        const initialBalanceReceiver = web3.utils.fromWei(await certixToken.balanceOf(user1), 'ether');
        // Effectuer le transfert
        await certixToken.transfer(user1, transferAmount.toString(), { from: deployer });

        // Solde final du receveur
        const finalBalanceReceiver = parseFloat(web3.utils.fromWei(await certixToken.balanceOf(user1), 'ether')).toFixed(2);
        //console.log("finalBalanceReceiver "+finalBalanceReceiver)

        //40 * 0.1% = 39.96
        assert.equal(finalBalanceReceiver.toString(), "39.96", "The received amount does not match the expected value after burn fee");
        
        const finalSupply =  parseFloat(web3.utils.fromWei((await certixToken.totalSupply()) + "", "ether")).toFixed(2)

        assert.equal(((supplyBeforeBurn - finalSupply).toFixed(2) ).toString(), expectedBurnAmount, "Total supply should have been reduced");
    });
});