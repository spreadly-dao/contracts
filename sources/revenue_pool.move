module spreadly::revenue_pool {
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::bag::{Self, Bag};
    use sui::linked_table::{Self, LinkedTable};
    use sui::table::{Self, Table};
    use sui::event;
    use std::ascii::{String};
    use std::type_name::{into_string};

    use spreadly::stake_position::{Self, StakePosition};
    use spreadly::staking_pool::{Self, StakingPool};

    // === Error Constants ===
    const EINVALID_EPOCH_DURATION: u64 = 1;
    const ENO_STAKE: u64 = 2;
    const EINSUFFICIENT_STAKE: u64 = 3;
    const EALREADY_CLAIMED: u64 = 4;
    const EZERO_TOTAL_STAKE: u64 = 5;
    const EINACTIVE_REVENUE_TYPE: u64 = 6;
    const EDUPLICATE_REVENUE_TYPE: u64 = 7;
    const EREVENUE_TYPE_NOT_FOUND: u64 = 8;

    // === public Structs ===

    public struct RevenueType has store {
        name: String,
        active: bool,
        added_at: u64
    }
    
    /// Represents a single epoch for revenue distribution
    public struct Epoch has store {
        start_timestamp: u64,
        end_timestamp: u64,
        total_stake: u64,
        revenues: Bag,
        total_revenues: Table<String, u64>
    }

    /// Modified EpochSegment to include epochs
    public struct EpochSegment has store {
        start_timestamp: u64,
        end_timestamp: Option<u64>,
        epoch_duration: u64,
        epochs: LinkedTable<u64, Epoch>
    }

    /// Global revenue pool state
    public struct RevenuePool has key {
        id: UID,
        segments: LinkedTable<u64, EpochSegment>,
        current_segment_ts: u64,
        revenue_types: LinkedTable<String, RevenueType>
    }

    // === Events ===
    
    public struct NewEpochSegmentEvent has copy, drop {
        start_timestamp: u64,
        epoch_duration: u64,
        total_stake: u64
    }

    public struct RevenueDepositEvent has copy, drop {
        asset_type: String,
        amount: u64,
        timestamp: u64
    }

    public struct RevenueClaimEvent has copy, drop {
        staker: address,
        segment_start: u64,
        segment_end: u64,
        assets: vector<String>
    }


    public struct RevenueTypeAddedEvent has copy, drop {
        type_name: String,
        timestamp: u64
    }

    public struct RevenueTypeStatusChangeEvent has copy, drop {
        type_name: String,
        active: bool,
        timestamp: u64
    }
    // === Core Functions ===

    /// Initialize the revenue pool with zero timestamp
    fun init(ctx: &mut TxContext) {
        // Create a new RevenuePool with initial values
        let pool = RevenuePool {
            id: object::new(ctx),
            segments: linked_table::new(ctx),
            current_segment_ts: 0,
            revenue_types: linked_table::new(ctx)
        };
    
        // Share revenue pool object
        transfer::share_object(pool)
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx)
    }

    /// Initialize if needed with real timestamp
    fun initialize_if_needed(pool: &mut RevenuePool, clock: &Clock, ctx: &mut TxContext) {
        // Only initialize if this is the first time (genesis_timestamp is 0)
        if (pool.current_segment_ts == 0) {
            let timestamp = clock::timestamp_ms(clock);

            pool.current_segment_ts = timestamp;
            
            // Create initial epoch segment
            let initial_segment = EpochSegment {
                start_timestamp: timestamp,
                end_timestamp: option::none(),
                epoch_duration: 30 * 24 * 60 * 60 * 1000, // 30 days in milliseconds
                epochs: linked_table::new(ctx)
            };
            
            // Add initial segment to pool
            linked_table::push_back(&mut pool.segments, timestamp, initial_segment);
        }
    } 

    // required governance
    public(package) fun add_revenue_type(
        pool: &mut RevenuePool,
        type_name: String,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Ensure pool is initialized before we add any revenue types
        initialize_if_needed(pool, clock, ctx);
        
        let timestamp = clock::timestamp_ms(clock);
        
        // Check if this revenue type already exists in the pool's global revenue types
        assert!(!linked_table::contains(&pool.revenue_types, type_name), EDUPLICATE_REVENUE_TYPE);
        
        // Create the new revenue type with initial configuration
        let revenue_type = RevenueType {
            name: type_name,
            active: true,
            added_at: timestamp
        };

        // Add the revenue type to the pool's global revenue types table
        linked_table::push_back(&mut pool.revenue_types, type_name, revenue_type);
        
        // Emit event to notify listeners about the new revenue type
        event::emit(RevenueTypeAddedEvent {
            type_name,
            timestamp
        });
    }

    // required governance
    public(package) fun deactivate_revenue_type(
        pool: &mut RevenuePool,
        type_name: String,
        clock: &Clock
    ) {
        let timestamp = clock::timestamp_ms(clock);
        
        assert!(linked_table::contains(&pool.revenue_types, type_name), EREVENUE_TYPE_NOT_FOUND);
        
        let revenue_type = linked_table::borrow_mut(&mut pool.revenue_types, type_name);
        revenue_type.active = false;

        event::emit(RevenueTypeStatusChangeEvent {
            type_name,
            active: false,
            timestamp
        });
    }

    // required governance
    public(package) fun activate_revenue_type(
        pool: &mut RevenuePool,
        type_name: String,
        clock: &Clock
    ) {
        let timestamp = clock::timestamp_ms(clock);
        assert!(linked_table::contains(&pool.revenue_types, type_name), EREVENUE_TYPE_NOT_FOUND);
        
        let revenue_type = linked_table::borrow_mut(&mut pool.revenue_types, type_name);
        revenue_type.active = true;

        event::emit(RevenueTypeStatusChangeEvent {
            type_name,  
            active: true,
            timestamp
        });
    }

    /// Deposit revenue into the pool
    public fun deposit_revenue<T>(
        pool: &mut RevenuePool,
        staking_pool: &StakingPool,
        revenue: Coin<T>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        initialize_if_needed(pool, clock, ctx);
        
        let timestamp = clock::timestamp_ms(clock);
        let amount = coin::value(&revenue);
        let type_name = get_coin_type_name<T>();

        // Verify revenue type exists and is active in the pool's global config
        assert!(linked_table::contains(&pool.revenue_types, type_name), EREVENUE_TYPE_NOT_FOUND);
        let revenue_type = linked_table::borrow(&pool.revenue_types, type_name);
        assert!(revenue_type.active, EINACTIVE_REVENUE_TYPE);
        
        // Get current segment and then the current epoch within it
        let current_epoch = get_current_epoch_mut(pool, staking_pool, timestamp, ctx);
        
        // Initialize the revenue bag for this type if it doesn't exist
        if (!bag::contains(&current_epoch.revenues, type_name)) {
            bag::add(&mut current_epoch.revenues, type_name, balance::zero<T>());
            
            // Initialize the total revenue entry in the table
            if (!table::contains(&current_epoch.total_revenues, type_name)) {
                table::add(&mut current_epoch.total_revenues, type_name, 0);
            };
        };
        
        // Add the revenue to the epoch's revenue bag
        let balance = bag::borrow_mut(&mut current_epoch.revenues, type_name);
        balance::join(balance, coin::into_balance(revenue));
        
        // Update the total revenue for this type
        let current_total = table::borrow_mut(&mut current_epoch.total_revenues, type_name);
        *current_total = *current_total + amount;
        
        event::emit(RevenueDepositEvent {
            asset_type: type_name,
            amount,
            timestamp,
        });
    }

    /// Claim revenue for a stake position
    public fun claim_revenue<T>(
        pool: &mut RevenuePool,
        position: &mut StakePosition,
        clock: &Clock,
        ctx: &mut TxContext
    ): Coin<T> {
        let sender = tx_context::sender(ctx);
        initialize_if_needed(pool, clock, ctx);
        
        let current_ts = clock::timestamp_ms(clock);
        assert!(stake_position::get_last_claimed_timestamp(position) < current_ts, EALREADY_CLAIMED);

        assert!(stake_position::get_amount(position) > 0, ENO_STAKE);

        let last_claimed = stake_position::get_last_claimed_timestamp(position);
        
        // Verify revenue type exists and is active
        let type_name = get_coin_type_name<T>();
        assert!(linked_table::contains(&pool.revenue_types, type_name), EREVENUE_TYPE_NOT_FOUND);
        let revenue_type = linked_table::borrow(&pool.revenue_types, type_name);
        assert!(revenue_type.active, EINACTIVE_REVENUE_TYPE);
        
        let balance = get_claimable_amount<T>(
            pool,
            position,
            last_claimed,
            current_ts
        );
        
        if (balance::value(&balance) > 0) {
            stake_position::set_last_claimed_timestamp(position, current_ts);
            
            event::emit(RevenueClaimEvent {
                staker: sender,
                segment_start: last_claimed,
                segment_end: current_ts,
                assets: vector[type_name]
            });
        };
        
        coin::from_balance(balance, ctx)
    }

    /// through governance
    public(package) fun update_epoch_duration(
        pool: &mut RevenuePool,
        staking_pool: &StakingPool,
        new_duration: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        initialize_if_needed(pool, clock, ctx);
        
        assert!(new_duration > 0, EINVALID_EPOCH_DURATION);
        
        let timestamp = clock::timestamp_ms(clock);
        
        // Close current segment
        close_current_segment(pool, timestamp);
        
        // Start new segment
        let new_segment = EpochSegment {
            start_timestamp: timestamp,
            end_timestamp: option::none(),
            epoch_duration: new_duration,
            epochs: linked_table::new(ctx)
        };
        
        linked_table::push_back(&mut pool.segments, timestamp, new_segment);
        pool.current_segment_ts = timestamp;
        
        event::emit(NewEpochSegmentEvent {
            start_timestamp: timestamp,
            epoch_duration: new_duration,
            total_stake: staking_pool::total_staked(staking_pool),
        });
    }

    public(package) fun update_epoch_stake(
        pool: &mut RevenuePool,
        staking_pool: &StakingPool,
        timestamp: u64,
        amount: u64,
        is_increase: bool,
        ctx: &mut TxContext
    ) {
        let epoch = get_current_epoch_mut(pool, staking_pool, timestamp, ctx);
        
        if (is_increase) {
            epoch.total_stake = epoch.total_stake + amount;
        } else {
            assert!(epoch.total_stake >= amount, EINSUFFICIENT_STAKE);
            epoch.total_stake = epoch.total_stake - amount;
        };
    }


    // === Helper Functions ===

    public fun get_coin_type_name<T>(): String {
        let type_name = std::type_name::get<T>();
        into_string(type_name)
    }

    fun get_current_epoch_mut(
        pool: &mut RevenuePool,
        staking_pool: &StakingPool, 
        timestamp: u64,
        ctx: &mut TxContext
    ): &mut Epoch {
        let segment = linked_table::borrow_mut(&mut pool.segments, pool.current_segment_ts);
        // For a new segment with no epochs, create the first one
        if (linked_table::is_empty(&segment.epochs)) {
            let new_epoch = Epoch {
                start_timestamp: timestamp,
                end_timestamp: timestamp + segment.epoch_duration,
                total_stake: staking_pool::total_staked(staking_pool),
                revenues: bag::new(ctx),
                total_revenues: table::new(ctx)
            };
            linked_table::push_back(&mut segment.epochs, timestamp, new_epoch);
            return linked_table::borrow_mut(&mut segment.epochs, timestamp)
        };
        
        // Since we know epochs exist, we can safely get the last timestamp
        let last_epoch_ts = *option::borrow(linked_table::back(&segment.epochs));
        let last_epoch = linked_table::borrow(&segment.epochs, last_epoch_ts);
        
        // If we're beyond the current epoch's end time, create a new one
        if (timestamp >= last_epoch.end_timestamp) {
            let new_start = last_epoch.end_timestamp;
            let new_epoch = Epoch {
                start_timestamp: new_start,
                end_timestamp: new_start + segment.epoch_duration,
                total_stake: staking_pool::total_staked(staking_pool),
                revenues: bag::new(ctx),
                total_revenues: table::new(ctx)
            };
            linked_table::push_back(&mut segment.epochs, new_start, new_epoch);
            return linked_table::borrow_mut(&mut segment.epochs, new_start)
        };
        
        // Return the current epoch
        linked_table::borrow_mut(&mut segment.epochs, last_epoch_ts)
    }

    fun get_claimable_amount<T>(
        pool: &mut RevenuePool,
        position: &StakePosition,
        start_ts: u64,
        end_ts: u64
    ): Balance<T> {
        let mut claimable = balance::zero<T>();
        
        // Start from the most recent segment
        let last_segment_ts = linked_table::back(&pool.segments);
        if (option::is_none(last_segment_ts)) {
            return claimable
        };
        
        let mut current_segment_ts = *option::borrow(last_segment_ts);
        
        // Work backwards through segments until we're before the start time
        // or we've processed all segments
        while (current_segment_ts >= start_ts) {
            let segment = linked_table::borrow_mut(&mut pool.segments, current_segment_ts);
            
            if (!linked_table::is_empty(&segment.epochs)) {
                // Start from the most recent epoch in this segment
                let last_epoch_ts = linked_table::back(&segment.epochs);
                if (option::is_some(last_epoch_ts)) {
                    let mut epoch_ts = *option::borrow(last_epoch_ts);
                    
                    // Process epochs in reverse until we're before start_ts
                    while (epoch_ts >= start_ts) {
                        let epoch = linked_table::borrow_mut(&mut segment.epochs, epoch_ts);
                        
                        // First check if we should process this epoch at all
                        if (epoch.end_timestamp <= end_ts &&
                            epoch.start_timestamp >= start_ts &&
                            stake_position::get_stake_timestamp(position) <= epoch.start_timestamp) {
                            
                            process_epoch_revenue<T>(epoch, position, &mut claimable);
                        };
                        
                        // Move to previous epoch if it exists
                        if (option::is_some(linked_table::prev(&segment.epochs, epoch_ts))) {
                            epoch_ts = *option::borrow(linked_table::prev(&segment.epochs, epoch_ts));
                        } else {
                            break
                        };
                    }
                }
            };
            
            // Move to previous segment if it exists
            if (option::is_some(linked_table::prev(&pool.segments, current_segment_ts))) {
                current_segment_ts = *option::borrow(linked_table::prev(&pool.segments, current_segment_ts));
            } else {
                break
            };
        };
        
        claimable
    }

    // Helper function to process revenue for a single epoch
    fun process_epoch_revenue<T>(
        epoch: &mut Epoch,
        position: &StakePosition,
        claimable: &mut Balance<T>
    ) {
        assert!(epoch.total_stake > 0, EZERO_TOTAL_STAKE);
        
        let share = (stake_position::get_amount(position) as u128) * 
                    (1u128 << 64) / (epoch.total_stake as u128);
        
        let type_name = get_coin_type_name<T>();
        if (bag::contains(&epoch.revenues, type_name)) {
            let epoch_revenue = bag::borrow_mut(&mut epoch.revenues, type_name);
            let amount = (balance::value(epoch_revenue) as u128) * 
                        share / (1u128 << 64);
            if (amount > 0) {
                balance::join(claimable, 
                    balance::split(epoch_revenue, (amount as u64)));
            }
        }
    }

    fun close_current_segment(pool: &mut RevenuePool, end_timestamp: u64) {
        let segment = linked_table::borrow_mut(&mut pool.segments, pool.current_segment_ts);
        segment.end_timestamp = option::some(end_timestamp);
    }

    // getters

    public fun get_current_segment_ts(pool: &RevenuePool): u64 {
        pool.current_segment_ts
    }

    /// Checks if a given revenue type exists and is active
    public fun is_revenue_type_active(pool: &RevenuePool, type_name: String): bool {
        // First check if the type exists
        if (!linked_table::contains(&pool.revenue_types, type_name)) {
            return false
        };
        
        // Get the revenue type and check its active status
        let revenue_type = linked_table::borrow(&pool.revenue_types, type_name);
        revenue_type.active
    }
}