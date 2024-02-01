import MCSToken "MCSToken.mo";
import Array "mo:base/Array";
import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Float "mo:base/Float";
import Int "mo:base/Int";

actor BlockExplorer {

  public type TokenHolderInfo = {
    owner: Principal;
    balance: Nat;
    percentageOfTotalSupply: Float;
  };

  public type TokenInfoExt = {
    tokenId: Nat;
    owner: Principal;
    metadata: MCSToken.Metadata;
    balance: Nat;
    allowances: [(Principal, Nat)];
  };

  public type TransactionInfoExt = {
    transactionId: Nat;
    from: Principal;
    to: Principal;
    amount: Nat;
    timestamp: Int64;
    transactionType: MCSToken.TransactionType;
    status: MCSToken.TransactionStatus;
  };

  public type AccountDetails = {
    ownedTokens: [TokenInfoExt];
    totalBalance: Nat;
    transactions: [TransactionInfoExt];
  };

  public query func getTotalSupply() : async Nat {
    return await MCSToken.totalSupply();
  }

  public query func getCycles() : async Nat64 {
    return await MCSToken.cycles();
  }
// I have no idea if this actually works
  public query func getTopHolders(limit: Nat = 100) : async [TokenHolderInfo] {
    let totalSupply = await getTotalSupply();
    let allHolders = await MCSToken.getAllTokenHolders();
    let holderInfos = await Array.mapAsync<Principal, TokenHolderInfo>(allHolders, async (holder: Principal) : TokenHolderInfo {
      let balance = await MCSToken.balanceOf(holder);
      let percentage = Float.div(Float.fromNat(balance), Float.fromNat(totalSupply)) * 100.0;
      return { owner = holder, balance = balance, percentageOfTotalSupply = percentage };
    });
    return Array.sort<TokenHolderInfo>(holderInfos, func (x, y) { Nat.compare(y.balance, x.balance) }).take(limit);
  }

  public query func getTokenDetails(tokenId: Nat) : async ?TokenInfoExt {
    let tokenInfo = await MCSToken.getTokenInfo(tokenId);
    if (tokenInfo == null) return null;
    let metadata = await MCSToken.getMetadata(tokenId);
    let balance = await MCSToken.balanceOf(tokenInfo.owner);
    let allowances = await MCSToken.getAllowances(tokenInfo.owner);
    return {
      tokenId = tokenId,
      owner = tokenInfo.owner,
      metadata = metadata,
      balance = balance,
      allowances = allowances
    };
  }

  public query func getTransactionDetails(transactionId: Nat) : async ?TransactionInfoExt {
    let transaction = await MCSToken.getTransaction(transactionId);
    if (transaction == null) return null;
    return {
      transactionId = transactionId,
      from = transaction.from,
      to = transaction.to,
      amount = transaction.amount,
      timestamp = transaction.timestamp,
      transactionType = transaction.transactionType,
      status = transaction.status
    };
  }

  public query func getAccountDetails(accountId: Principal) : async AccountDetails {
    let ownedTokensIds = await MCSToken.getTokensByOwner(accountId);
    let ownedTokens = await Array.mapAsync<Nat, TokenInfoExt>(ownedTokensIds, async (tokenId: Nat) : TokenInfoExt {
      return await getTokenDetails(tokenId);
    });
    let totalBalance = await MCSToken.balanceOf(accountId);
    let transactionIds = await MCSToken.getTransactionsByAccount(accountId);
    let transactions = await Array.mapAsync<Nat, TransactionInfoExt>(transactionIds, async (transactionId: Nat) : TransactionInfoExt {
      return await getTransactionDetails(transactionId);
    });
    return {
      ownedTokens = ownedTokens,
      totalBalance = totalBalance,
      transactions = transactions
    };
  }

  public query func getSystemStats() : async {
    totalSupply: Nat,
    cycles: Nat64,
    topHolders: [TokenHolderInfo]
  } {
    let totalSupply = await getTotalSupply();
    let cycles = await getCycles();
    let topHolders = await getTopHolders(10); // if u wanted to display 10 for some reason idk
    return {
      totalSupply = totalSupply,
      cycles = cycles,
      topHolders = topHolders
    };
  }

}
