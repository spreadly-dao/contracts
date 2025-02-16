module spreadly::staking {
    use sui::package;
    use std::string;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::event;
    use sui::display;

    
    use spreadly::spreadly::{SPREADLY};
    use spreadly::stake_position::{Self, StakePosition};
    use spreadly::staking_pool::{Self, StakingPool};
    use spreadly::revenue_pool::{Self, RevenuePool};

    // === Error Constants ===
    const ERROR_NO_STAKE: u64 = 1;
    const ERROR_INSUFFICIENT_STAKE: u64 = 2;
    const ERROR_UNCLAIMED_REVENUE: u64 = 3;

    // === One Time Witness for Package Initialization ===
    public struct STAKING has drop {}

    // === Events ===
    public struct StakeEvent has copy, drop {
        staker: address,
        position_id: ID,
        amount: u64,
        timestamp: u64
    }

    public struct UnstakeEvent has copy, drop {
        staker: address,
        position_id: ID,
        amount: u64,
        timestamp: u64
    }

    // === Module Initialization ===
    fun init(witness: STAKING, ctx: &mut TxContext) {
        // Get Publisher and create Display for StakePosition NFTs
        let publisher = package::claim(witness, ctx);
        let mut display = display::new<StakePosition>(&publisher, ctx);
        
        // Set up display properties for the NFT
        display::add(&mut display, 
            string::utf8(b"name"), 
            string::utf8(b"Spreadly Stake #{id}")
        );
        display::add(&mut display, 
            string::utf8(b"description"), 
            string::utf8(b"A staking position in Spreadly with {amount} tokens staked")
        );
        display::add(&mut display, 
            string::utf8(b"image_url"), 
            string::utf8(b"https://spreadly.xyz/nft/staking.png")
        );
        
        display::update_version(&mut display);
        
        // Transfer publisher and display to the module publisher
        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::public_transfer(display, tx_context::sender(ctx));
    }

    // === Public Functions ===

    /// Stake SPREADLY tokens and receive an NFT representing the position
    public fun create_stake(
        staking_pool: &mut StakingPool,
        coin: Coin<SPREADLY>,
        clock: &Clock,
        ctx: &mut TxContext
    ): StakePosition {
        let amount = coin::value(&coin);
        assert!(amount > 0, ERROR_NO_STAKE);
        
        let timestamp = clock::timestamp_ms(clock);
        
        // Create new position
        let position = stake_position::new(amount, clock, ctx);
        
        // Deposit tokens into the pool
        staking_pool::deposit(staking_pool, coin::into_balance(coin), clock);
        
        let position_id = object::id(&position);
        
        event::emit(StakeEvent {
            staker: tx_context::sender(ctx),
            position_id,
            amount,
            timestamp,
        });

        position
    }

    public fun stake_more(
        staking_pool: &mut StakingPool,
        revenue_pool: &RevenuePool,
        position: &mut StakePosition,
        coin: Coin<SPREADLY>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let amount = coin::value(&coin);
        assert!(amount > 0, ERROR_NO_STAKE);
        
        let timestamp = clock::timestamp_ms(clock);
        
        // Check for unclaimed revenue before allowing additional stake
        assert!(!revenue_pool::has_unclaimed_revenue(revenue_pool, position), 
            ERROR_UNCLAIMED_REVENUE);
        
        // Increase position amount
        stake_position::increase_amount(position, amount);
        
        // Deposit tokens into the pool
        staking_pool::deposit(staking_pool, coin::into_balance(coin), clock);
        
        event::emit(StakeEvent {
            staker: tx_context::sender(ctx),
            position_id: object::id(position),
            amount,
            timestamp,
        });
    }
    
    /// Unstake tokens from a staking position
    public fun unstake(
        staking_pool: &mut StakingPool,
        revenue_pool: &RevenuePool,
        position: &mut StakePosition,
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<SPREADLY> {
        let current_amount = stake_position::get_amount(position);
        assert!(current_amount >= amount, ERROR_INSUFFICIENT_STAKE);
        
        let timestamp = clock::timestamp_ms(clock);
        
        // Check for unclaimed revenue before allowing unstake
        assert!(!revenue_pool::has_unclaimed_revenue(revenue_pool, position), 
            ERROR_UNCLAIMED_REVENUE);
        
        // Update position amount
        stake_position::decrease_amount(position, amount);
        
        // Withdraw tokens from pool
        let withdrawn_balance = staking_pool::withdraw(
            staking_pool,
            amount,
            clock
        );
        
        event::emit(UnstakeEvent {
            staker: tx_context::sender(ctx),
            position_id: object::id(position),
            amount,
            timestamp,
        });

        coin::from_balance(withdrawn_balance, ctx)
    }

    // === View Functions ===
    
    /// Get total amount staked in the pool
    public fun total_staked(pool: &StakingPool): u64 {
        staking_pool::total_staked(pool)
    }
}