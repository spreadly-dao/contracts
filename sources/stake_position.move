module spreadly::stake_position {
    use sui::clock::{Self, Clock};

    const ERROR_INSUFFICIENT_AMOUNT: u64 = 1;
    const ERROR_INVALID_TIMESTAMP: u64 = 2;

    public struct StakePosition has key, store {
        id: UID,
        amount: u64,
        stake_timestamp: u64,
        last_claimed_timestamp: u64,
    }
    
    // Constructor function
    public(package) fun new(
        amount: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ): StakePosition {
        StakePosition {
            id: object::new(ctx),
            amount,
            stake_timestamp: clock::timestamp_ms(clock),  // Get timestamp from clock
            last_claimed_timestamp: 0,
        }
    }

    // Getter functions that provide read-only access to the NFT's state
    public fun get_amount(self: &StakePosition): u64 {
        self.amount
    }

    public fun get_stake_timestamp(self: &StakePosition): u64 {
        self.stake_timestamp
    }

    public fun get_last_claimed_timestamp(self: &StakePosition): u64 {
        self.last_claimed_timestamp
    }

    // A utility function that returns multiple pieces of state at once
    // This can be helpful when you need to read multiple values in one call
    public fun get_position_info(self: &StakePosition): (u64, u64, u64) {
        (self.amount, self.stake_timestamp, self.last_claimed_timestamp)
    }
    
    // Existing modifier functions
    public fun decrease_amount(position: &mut StakePosition, decrease_by: u64) {
        assert!(position.amount >= decrease_by, ERROR_INSUFFICIENT_AMOUNT);
        position.amount = position.amount - decrease_by;
    }

    public fun set_last_claimed_timestamp(
        position: &mut StakePosition, 
        last_claimed_timestamp: u64,
    ) {
        assert!(
            position.last_claimed_timestamp <= last_claimed_timestamp, 
            ERROR_INVALID_TIMESTAMP
        );
        position.last_claimed_timestamp = last_claimed_timestamp;
    }
}