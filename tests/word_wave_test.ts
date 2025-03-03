Clarinet.test({
  name: "Validates entry content and mood properly",
  async fn(chain: Chain, accounts: Map<string, Account>) {
    const wallet1 = accounts.get('wallet_1')!;
    
    // Initialize user
    chain.mineBlock([
      Tx.contractCall('word-wave', 'initialize-user', [], wallet1.address)
    ]);
    
    // Test empty content
    let block = chain.mineBlock([
      Tx.contractCall('word-wave', 'create-entry', [
        types.utf8(""),
        types.uint(1),
        types.ascii("happy")
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectErr(103);
    
    // Test whitespace-only content
    block = chain.mineBlock([
      Tx.contractCall('word-wave', 'create-entry', [
        types.utf8("   "),
        types.uint(1),
        types.ascii("happy")
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectErr(103);
    
    // Test empty mood
    block = chain.mineBlock([
      Tx.contractCall('word-wave', 'create-entry', [
        types.utf8("Valid content"),
        types.uint(1),
        types.ascii("")
      ], wallet1.address)
    ]);
    
    block.receipts[0].result.expectErr(104);
  }
});

// [Additional test cases remain unchanged]
