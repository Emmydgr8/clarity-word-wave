import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensures user can initialize their account",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('word-wave', 'initialize-user', [], wallet1.address)
    ]);
    
    block.receipts[0].result.expectOk();
    
    // Verify user data
    let userData = chain.callReadOnlyFn(
      'word-wave',
      'get-user-data',
      [types.principal(wallet1.address)],
      wallet1.address
    );
    
    assertEquals(userData.result.expectSome().entry_count, types.uint(0));
  },
});

Clarinet.test({
  name: "Can create and retrieve journal entries",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Initialize user first
    chain.mineBlock([
      Tx.contractCall('word-wave', 'initialize-user', [], wallet1.address)
    ]);
    
    // Add a prompt
    let promptBlock = chain.mineBlock([
      Tx.contractCall('word-wave', 'add-prompt', [
        types.utf8("What made you smile today?")
      ], deployer.address)
    ]);
    
    let promptId = promptBlock.receipts[0].result.expectOk();
    
    // Create entry
    let entryBlock = chain.mineBlock([
      Tx.contractCall('word-wave', 'create-entry', [
        types.utf8("Today was a great day!"),
        promptId,
        types.ascii("happy")
      ], wallet1.address)
    ]);
    
    entryBlock.receipts[0].result.expectOk();
    
    // Get entry
    let entry = chain.callReadOnlyFn(
      'word-wave',
      'get-entry',
      [types.principal(wallet1.address), types.uint(1)],
      wallet1.address
    );
    
    entry.result.expectSome();
  },
});

Clarinet.test({
  name: "Only owner can add prompts",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('word-wave', 'add-prompt', [
        types.utf8("What made you smile today?")
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectErr(types.uint(100)); // err-owner-only
  },
});