import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
  name: "Ensures user can initialize their account with achievements",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    let block = chain.mineBlock([
      Tx.contractCall('word-wave', 'initialize-user', [], wallet1.address)
    ]);
    
    block.receipts[0].result.expectOk();
    
    let userData = chain.callReadOnlyFn(
      'word-wave',
      'get-user-data',
      [types.principal(wallet1.address)],
      wallet1.address
    );
    
    let result = userData.result.expectSome();
    assertEquals(result.entry_count, types.uint(0));
    assertEquals(result.achievements.length, 0);
    assertEquals(result.streaks.current, types.uint(0));
  },
});

Clarinet.test({
  name: "User earns achievement after first entry",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Initialize user
    chain.mineBlock([
      Tx.contractCall('word-wave', 'initialize-user', [], wallet1.address)
    ]);
    
    // Add prompt
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
    
    // Check achievements
    let stats = chain.callReadOnlyFn(
      'word-wave',
      'get-user-statistics',
      [types.principal(wallet1.address)],
      wallet1.address
    );
    
    let statsResult = stats.result.expectOk();
    assertEquals(statsResult.achievements.length, 1);
    assertEquals(statsResult.total_entries, types.uint(1));
  },
});

Clarinet.test({
  name: "Tracks writing streaks correctly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const deployer = accounts.get('deployer')!;
    const wallet1 = accounts.get('wallet_1')!;
    
    // Initialize user
    chain.mineBlock([
      Tx.contractCall('word-wave', 'initialize-user', [], wallet1.address)
    ]);
    
    // Add prompt
    let promptBlock = chain.mineBlock([
      Tx.contractCall('word-wave', 'add-prompt', [
        types.utf8("Daily prompt")
      ], deployer.address)
    ]);
    
    let promptId = promptBlock.receipts[0].result.expectOk();
    
    // Create entries on consecutive blocks
    for (let i = 0; i < 3; i++) {
      chain.mineBlock([
        Tx.contractCall('word-wave', 'create-entry', [
          types.utf8("Daily entry"),
          promptId,
          types.ascii("happy")
        ], wallet1.address)
      ]);
    }
    
    let stats = chain.callReadOnlyFn(
      'word-wave',
      'get-user-statistics',
      [types.principal(wallet1.address)],
      wallet1.address
    );
    
    let statsResult = stats.result.expectOk();
    assertEquals(statsResult.current_streak, types.uint(3));
    assertEquals(statsResult.longest_streak, types.uint(3));
  },
});
