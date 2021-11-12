const ShibaGalaxy = artifacts.require("ShibaGalaxy")
module.exports = async function(deployer) {
  await deployer.deploy(ShibaGalaxy);
};