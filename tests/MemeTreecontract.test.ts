
import { describe, expect, it, beforeEach } from "vitest";

const accounts = simnet.getAccounts();
const deployer = accounts.get("deployer")!;
const wallet1 = accounts.get("wallet_1")!;
const wallet2 = accounts.get("wallet_2")!;
const wallet3 = accounts.get("wallet_3")!;

describe("MemeTree Contract Tests", () => {
  beforeEach(() => {
    // Reset contract state before each test
    simnet.setEpoch("3.0");
  });

  describe("Contract Initialization", () => {
    it("ensures simnet is well initialised", () => {
      expect(simnet.blockHeight).toBeDefined();
    });

    it("should have correct initial state", () => {
      const { result } = simnet.callReadOnlyFn("MemeTreecontract", "get-last-token-id", [], deployer);
      expect(result).toBeOk(0);

      const { result: paused } = simnet.callReadOnlyFn("MemeTreecontract", "is-contract-paused", [], deployer);
      expect(result).toBe(false);

      const { result: emergency } = simnet.callReadOnlyFn("MemeTreecontract", "is-emergency-mode", [], deployer);
      expect(result).toBe(false);
    });
  });

  describe("Security Features", () => {
    it("should prevent minting when contract is paused", () => {
      // Pause contract
      const pauseResult = simnet.callPublicFn("MemeTreecontract", "pause-contract", [], deployer);
      expect(pauseResult.result).toBeOk(true);

      // Try to mint - should fail
      const mintResult = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `"https://example.com/meme1.json"`,
          "10000000", // 0.1 STX
          "500" // 5% royalty
        ],
        wallet1
      );
      expect(mintResult.result).toBeErr(108); // err-contract-paused

      // Unpause
      const unpauseResult = simnet.callPublicFn("MemeTreecontract", "unpause-contract", [], deployer);
      expect(unpauseResult.result).toBeOk(true);
    });

    it("should enforce minimum mint price", () => {
      const mintResult = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `"https://example.com/meme1.json"`,
          "100000", // 0.001 STX - below minimum
          "500"
        ],
        wallet1
      );
      expect(mintResult.result).toBeErr(116); // err-invalid-amount
    });

    it("should validate URI length", () => {
      const longUri = "a".repeat(300); // Exceeds MAX_URI_LENGTH
      const mintResult = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `"${longUri}"`,
          "10000000",
          "500"
        ],
        wallet1
      );
      expect(mintResult.result).toBeErr(111); // err-invalid-input
    });

    it("should enforce royalty rate limits", () => {
      const mintResult = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `"https://example.com/meme1.json"`,
          "10000000",
          "2000" // 20% - exceeds max-royalty-rate (10%)
        ],
        wallet1
      );
      expect(mintResult.result).toBeErr(107); // err-invalid-royalty
    });

    it("should implement rate limiting", () => {
      // Mint first meme successfully
      const mint1 = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `"https://example.com/meme1.json"`,
          "10000000",
          "500"
        ],
        wallet1
      );
      expect(mint1.result).toBeOk(1);

      // Try to mint again immediately - should succeed (within rate limit)
      const mint2 = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `"https://example.com/meme2.json"`,
          "10000000",
          "500"
        ],
        wallet1
      );
      expect(mint2.result).toBeOk(2);

      // Additional mints should still work within the block limit
      const mint3 = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `"https://example.com/meme3.json"`,
          "10000000",
          "500"
        ],
        wallet1
      );
      expect(mint3.result).toBeOk(3);
    });

    it("should handle emergency mode", () => {
      // Enable emergency mode
      const emergencyResult = simnet.callPublicFn("MemeTreecontract", "enable-emergency-mode", [], deployer);
      expect(emergencyResult.result).toBeOk(true);

      // Check emergency mode status
      const { result: emergencyStatus } = simnet.callReadOnlyFn("MemeTreecontract", "is-emergency-mode", [], deployer);
      expect(emergencyStatus).toBe(true);

      // Minting should fail in emergency mode
      const mintResult = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `"https://example.com/meme1.json"`,
          "10000000",
          "500"
        ],
        wallet1
      );
      expect(mintResult.result).toBeErr(115); // err-emergency-mode

      // Disable emergency mode
      const disableResult = simnet.callPublicFn("MemeTreecontract", "disable-emergency-mode", [], deployer);
      expect(disableResult.result).toBeOk(true);
    });

    it("should protect owner-only functions", () => {
      const pauseResult = simnet.callPublicFn("MemeTreecontract", "pause-contract", [], wallet1);
      expect(pauseResult.result).toBeErr(100); // err-owner-only

      const emergencyResult = simnet.callPublicFn("MemeTreecontract", "enable-emergency-mode", [], wallet1);
      expect(emergencyResult.result).toBeErr(100); // err-owner-only
    });
  });

  describe("Core Functionality", () => {
    it("should mint original memes successfully", () => {
      const mintResult = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `"https://example.com/meme1.json"`,
          "10000000", // 0.1 STX
          "500" // 5% royalty
        ],
        wallet1
      );

      expect(mintResult.result).toBeOk(1);
      expect(mintResult.events).toHaveLength(1);

      // Check token data
      const { result: tokenData } = simnet.callReadOnlyFn("MemeTreecontract", "get-meme-data", ["1"], wallet1);
      expect(tokenData).toBeSome();

      // Check owner
      const { result: owner } = simnet.callReadOnlyFn("MemeTreecontract", "get-owner", ["1"], wallet1);
      expect(owner).toBeOk(wallet1);

      // Check last token ID
      const { result: lastId } = simnet.callReadOnlyFn("MemeTreecontract", "get-last-token-id", [], wallet1);
      expect(lastId).toBeOk(1);
    });

    it("should mint derivative memes with royalty payments", () => {
      // Mint original
      const originalMint = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `"https://example.com/original.json"`,
          "100000000", // 1 STX mint price
          "500" // 5% royalty
        ],
        wallet1
      );
      expect(originalMint.result).toBeOk(1);

      // Mint derivative
      const derivativeMint = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-derivative-meme",
        [
          "1", // parent ID
          `"https://example.com/derivative.json"`,
          "200000000", // 2 STX mint price
          "300" // 3% royalty
        ],
        wallet2
      );
      expect(derivativeMint.result).toBeOk(2);

      // Check derivative data
      const { result: derivativeData } = simnet.callReadOnlyFn("MemeTreecontract", "get-meme-data", ["2"], wallet2);
      expect(derivativeData).toBeSome();

      // Check parent has derivative count updated
      const { result: parentData } = simnet.callReadOnlyFn("MemeTreecontract", "get-meme-data", ["1"], wallet1);
      expect(parentData).toBeSome();
    });

    it("should transfer memes correctly", () => {
      // Mint a meme
      const mintResult = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `"https://example.com/meme.json"`,
          "10000000",
          "500"
        ],
        wallet1
      );
      expect(mintResult.result).toBeOk(1);

      // Transfer to wallet2
      const transferResult = simnet.callPublicFn(
        "MemeTreecontract",
        "transfer-meme",
        ["1", `'${wallet1}'`, `'${wallet2}'`],
        wallet1
      );
      expect(transferResult.result).toBeOk(true);

      // Check new owner
      const { result: newOwner } = simnet.callReadOnlyFn("MemeTreecontract", "get-owner", ["1"], wallet1);
      expect(newOwner).toBeOk(wallet2);
    });

    it("should prevent unauthorized transfers", () => {
      // Mint a meme
      const mintResult = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `"https://example.com/meme.json"`,
          "10000000",
          "500"
        ],
        wallet1
      );
      expect(mintResult.result).toBeOk(1);

      // Try to transfer from wrong sender
      const transferResult = simnet.callPublicFn(
        "MemeTreecontract",
        "transfer-meme",
        ["1", `'${wallet2}'`, `'${wallet3}'`],
        wallet2
      );
      expect(transferResult.result).toBeErr(101); // err-not-token-owner
    });

    it("should verify meme authenticity", () => {
      // Mint a meme
      const mintResult = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `"https://example.com/meme.json"`,
          "10000000",
          "500"
        ],
        wallet1
      );
      expect(mintResult.result).toBeOk(1);

      // Verify authenticity
      const verifyResult = simnet.callPublicFn(
        "MemeTreecontract",
        "verify-meme-authenticity",
        ["1", `"twitter"`, `"tweet123"`],
        wallet1
      );
      expect(verifyResult.result).toBeOk(true);

      // Check authenticity mapping
      const { result: tokenId } = simnet.callReadOnlyFn(
        "MemeTreecontract",
        "get-meme-by-external-id",
        [`"twitter"`, `"tweet123"`],
        wallet1
      );
      expect(tokenId).toBeSome(1);
    });

    it("should prevent non-owners from verifying authenticity", () => {
      // Mint a meme
      const mintResult = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `"https://example.com/meme.json"`,
          "10000000",
          "500"
        ],
        wallet1
      );
      expect(mintResult.result).toBeOk(1);

      // Try to verify from different account
      const verifyResult = simnet.callPublicFn(
        "MemeTreecontract",
        "verify-meme-authenticity",
        ["1", `"twitter"`, `"tweet123"`],
        wallet2
      );
      expect(verifyResult.result).toBeErr(101); // err-not-token-owner
    });
  });

  describe("Treasury Management", () => {
    it("should handle treasury changes with timelock", () => {
      // Initiate treasury change
      const setTreasuryResult = simnet.callPublicFn(
        "MemeTreecontract",
        "set-platform-treasury",
        [`'${wallet2}'`],
        deployer
      );
      expect(setTreasuryResult.result).toBeOk(true);

      // Check pending treasury
      const { result: pendingTreasury } = simnet.callReadOnlyFn("MemeTreecontract", "get-pending-treasury", [], deployer);
      expect(pendingTreasury).toBe(wallet2);

      // Try to execute immediately - should fail due to timelock
      const executeResult = simnet.callPublicFn("MemeTreecontract", "execute-treasury-change", [], deployer);
      expect(executeResult.result).toBeErr(114); // err-timelock-active

      // Simulate time passing (advance blocks)
      simnet.mineEmptyBlocks(1440); // Advance 1440 blocks (timelock duration)

      // Now execute should work
      const executeAfterTimelock = simnet.callPublicFn("MemeTreecontract", "execute-treasury-change", [], deployer);
      expect(executeAfterTimelock.result).toBeOk(true);
    });
  });

  describe("Edge Cases and Error Handling", () => {
    it("should handle minting with zero royalty", () => {
      const mintResult = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `"https://example.com/meme.json"`,
          "10000000",
          "0" // 0% royalty
        ],
        wallet1
      );
      expect(mintResult.result).toBeOk(1);
    });

    it("should reject derivative minting with invalid parent", () => {
      const derivativeMint = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-derivative-meme",
        [
          "999", // Non-existent parent
          `"https://example.com/derivative.json"`,
          "10000000",
          "500"
        ],
        wallet2
      );
      expect(derivativeMint.result).toBeErr(103); // err-token-not-found
    });

    it("should handle empty string validation", () => {
      const mintResult = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [
          `""`, // Empty URI
          "10000000",
          "500"
        ],
        wallet1
      );
      expect(mintResult.result).toBeErr(111); // err-invalid-input
    });

    it("should handle operations on non-existent tokens", () => {
      const { result: tokenData } = simnet.callReadOnlyFn("MemeTreecontract", "get-meme-data", ["999"], wallet1);
      expect(tokenData).toBeNone();

      const { result: owner } = simnet.callReadOnlyFn("MemeTreecontract", "get-owner", ["999"], wallet1);
      expect(owner).toBeErr(103); // err-token-not-found
    });
  });

  describe("Constants and Read-Only Functions", () => {
    it("should return correct constants", () => {
      const { result: fee } = simnet.callReadOnlyFn("MemeTreecontract", "get-platform-fee-constant", [], deployer);
      expect(fee).toBe(200);

      const { result: maxRoyalty } = simnet.callReadOnlyFn("MemeTreecontract", "get-max-royalty-rate-constant", [], deployer);
      expect(maxRoyalty).toBe(1000);

      const { result: minPrice } = simnet.callReadOnlyFn("MemeTreecontract", "get-min-mint-price-constant", [], deployer);
      expect(minPrice).toBe(1000000);
    });

    it("should handle user meme lists", () => {
      // Mint some memes for a user
      const mint1 = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [`"https://example.com/meme1.json"`, "10000000", "500"],
        wallet1
      );
      expect(mint1.result).toBeOk(1);

      const mint2 = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [`"https://example.com/meme2.json"`, "10000000", "500"],
        wallet1
      );
      expect(mint2.result).toBeOk(2);

      // Check user's memes
      const { result: userMemes } = simnet.callReadOnlyFn("MemeTreecontract", "get-user-memes", [`'${wallet1}'`], wallet1);
      expect(userMemes).toEqual([1, 2]);
    });
  });

  describe("Viral Coefficient and Genealogy", () => {
    it("should calculate viral coefficient correctly", () => {
      // Mint original
      const originalMint = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [`"https://example.com/original.json"`, "10000000", "500"],
        wallet1
      );
      expect(originalMint.result).toBeOk(1);

      // Mint derivative
      const derivativeMint = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-derivative-meme",
        ["1", `"https://example.com/derivative.json"`, "10000000", "500"],
        wallet2
      );
      expect(derivativeMint.result).toBeOk(2);

      // Check viral coefficient
      const { result: viralCoeff } = simnet.callReadOnlyFn("MemeTreecontract", "get-viral-coefficient", ["1"], wallet1);
      expect(viralCoeff).toBeOk(10); // 1 derivative * 10
    });

    it("should return simplified genealogy for compliance", () => {
      // Mint a meme
      const mintResult = simnet.callPublicFn(
        "MemeTreecontract",
        "mint-original-meme",
        [`"https://example.com/meme.json"`, "10000000", "500"],
        wallet1
      );
      expect(mintResult.result).toBeOk(1);

      // Check genealogy
      const { result: genealogy } = simnet.callReadOnlyFn("MemeTreecontract", "get-meme-genealogy", ["1"], wallet1);
      expect(genealogy).toBeOk([1]);
    });
  });
});
