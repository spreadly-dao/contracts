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

    // === Error Constants ===
    const ERROR_NO_STAKE: u64 = 1;
    const ERROR_INSUFFICIENT_STAKE: u64 = 2;

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
    public fun stake(
        pool: &mut StakingPool,
        coin: Coin<SPREADLY>,
        clock: &Clock,
        ctx: &mut TxContext
    ): StakePosition {
        let amount = coin::value(&coin);  // Cast to u64
        assert!(amount > 0, ERROR_NO_STAKE);
        
        let timestamp = clock::timestamp_ms(clock);
        
        // Deposit tokens into the pool using staking_pool module
        staking_pool::deposit(pool, coin::into_balance(coin), clock);
        
        // Create stake position NFT
        let position = stake_position::new(amount, clock, ctx);
        
        let position_id = object::id(&position);
        
        event::emit(StakeEvent {
            staker: tx_context::sender(ctx),
            position_id,
            amount,
            timestamp,
        });

        position
    }
    
    /// Unstake tokens from a staking position
    public fun unstake(
        pool: &mut StakingPool,
        position: &mut StakePosition,
        amount: u64,  // Changed to u64
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<SPREADLY> {
        let current_amount = stake_position::get_amount(position);
        assert!(current_amount >= amount, ERROR_INSUFFICIENT_STAKE);
        
        // Update position amount through stake_position module
        stake_position::decrease_amount(position, amount);
        
        // Withdraw tokens from pool using staking_pool module
        let withdrawn_balance = staking_pool::withdraw(
            pool,
            amount,
            clock
        );
        
        event::emit(UnstakeEvent {
            staker: tx_context::sender(ctx),
            position_id: object::id(position),
            amount,
            timestamp: clock::timestamp_ms(clock),
        });

        // Convert balance back to coin for return
        coin::from_balance(withdrawn_balance, ctx)
    }

    // === View Functions ===
    
    /// Get total amount staked in the pool
    public fun total_staked(pool: &StakingPool): u64 {
        staking_pool::total_staked(pool)
    }
}