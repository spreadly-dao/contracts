module spreadly::staking_pool {
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::event;
    
    use spreadly::spreadly::{SPREADLY};
    
    // === Error Constants ===
    const ERROR_INSUFFICIENT_BALANCE: u64 = 1;
    const ERROR_ZERO_AMOUNT: u64 = 2;

    // === Structs ===
    
    /// Manages the pool of staked tokens and administrative functions
    public struct StakingPool has key {
        id: UID,
        /// Total amount of SPREADLY tokens staked in the pool
        total_staked: Balance<SPREADLY>,
    }

    // === Events ===
    
    /// Emitted when tokens are added to the pool
    public struct DepositEvent has copy, drop {
        pool_id: ID,
        amount: u64,
        timestamp: u64
    }

    /// Emitted when tokens are removed from the pool
    public struct WithdrawEvent has copy, drop {
        pool_id: ID,
        amount: u64,
        timestamp: u64
    }

    // === Core Pool Functions ===

    /// Creates a new staking pool and initializes it
    fun init(ctx: &mut TxContext) {
        // Create the staking pool with just the essential fields
        let pool = StakingPool {
            id: object::new(ctx),
            total_staked: balance::zero(),
        };

        transfer::share_object(pool);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx)
    }

    /// Adds tokens to the pool
    public(package) fun deposit(
        pool: &mut StakingPool,
        amount: Balance<SPREADLY>,
        clock: &Clock
    ) {
        let deposit_amount = balance::value(&amount);
        assert!(deposit_amount > 0, ERROR_ZERO_AMOUNT);
        
        balance::join(&mut pool.total_staked, amount);
        
        event::emit(DepositEvent {
            pool_id: object::id(pool),
            amount: deposit_amount,
            timestamp: clock::timestamp_ms(clock)
        });
    }

    /// Removes tokens from the pool
    public(package) fun withdraw(
        pool: &mut StakingPool,
        amount: u64,
        clock: &Clock
    ): Balance<SPREADLY> {
        assert!(amount > 0, ERROR_ZERO_AMOUNT);
        assert!(balance::value(&pool.total_staked) >= amount, ERROR_INSUFFICIENT_BALANCE);
        
        let withdrawn_balance = balance::split(&mut pool.total_staked, amount);
        
        event::emit(WithdrawEvent {
            pool_id: object::id(pool),
            amount,
            timestamp: clock::timestamp_ms(clock)
        });

        withdrawn_balance
    }

    // === View Functions ===

    /// Returns the total amount staked in the pool
    public fun total_staked(pool: &StakingPool): u64 {
        balance::value(&pool.total_staked)
    }
}