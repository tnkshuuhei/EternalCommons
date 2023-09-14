import { ethers } from "hardhat";
import { expect } from "chai";

describe("Contract", () => {
  let owner: any;
  let addr1: any;
  let addr2: any;

  async function deployContract() {
    const ContractFactory = await ethers.getContractFactory("Contract");
    const contract = await ContractFactory.deploy();

    return contract;
  }
  beforeEach(async () => {
    [owner, addr1, addr2] = await ethers.getSigners();
  });

  describe("CreateGrant", () => {
    it("Should create a new grant", async () => {
      const contract = await deployContract();
      await contract.CreateGrant(addr1.address, 1000, "Info");
      expect(await contract.grantListLength()).to.equal(1);
    });
  });

  describe("RegisterApplication", () => {
    it("Should register a new application", async () => {
      const contract = await deployContract();
      await contract.CreateGrant(addr1.address, 1000, "Info");
      await contract.RegisterApplication(
        0,
        addr2.address,
        JSON.stringify({ name: "Project 1" })
      );
      expect(await contract.projectListLength()).to.equal(1);
    });
  });

  describe("ApproveApplication", () => {
    it("Should approve an application", async () => {
      const contract = await deployContract();
      await contract.CreateGrant(addr1.address, 1000, "Info");
      await contract.RegisterApplication(
        0,
        addr2.address,
        JSON.stringify({ name: "Project 1" })
      );
      await contract.ApproveApplication(0, [0]);

      const project = await contract.getProjectDetail(0, 0);
      expect(project.isAccepted).to.equal(true);
    });
  });

  describe("DenyApplication", () => {
    it("Should deny an application", async () => {
      const contract = await deployContract();
      await contract.CreateGrant(addr1.address, 1000, "Info");
      await contract.RegisterApplication(
        0,
        addr2.address,
        JSON.stringify({ name: "Project 1" })
      );
      await contract.ApproveApplication(0, [0]);
      await contract.DenyApplication(0, 0);

      const project = await contract.getProjectDetail(0, 0);
      expect(project.isAccepted).to.equal(false);
    });
  });

  describe("Vote", () => {
    it("Should allow to vote for a project", async () => {
      const contract = await deployContract();
      await contract.CreateGrant(addr1.address, 1000, "Info");
      await contract.RegisterApplication(
        0,
        addr2.address,
        JSON.stringify({ name: "Project 1" })
      );
      await contract._vote(0, 0, "Good project");

      const votes = await contract.getVote(0, 0);
      expect(votes[0].voter).to.equal(owner.address);
      expect(votes[0].message).to.equal("Good project");
    });
  });
});
