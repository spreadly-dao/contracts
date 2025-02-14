module spreadly::stake_position {
    use sui::clock::{Self, Clock};
    use sui::linked_table::{Self, LinkedTable};
    use std::ascii::{String};

    const ERROR_INSUFFICIENT_AMOUNT: u64 = 1;
    const ERROR_INVALID_TIMESTAMP: u64 = 2;

    public struct StakePosition has key, store {
        id: UID,
        amount: u64,
        stake_timestamp: u64,
        last_claimed_timestamp: LinkedTable<String, u64>,
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
            last_claimed_timestamp: linked_table::new(ctx),
        }
    }

    // Getter functions that provide read-only access to the NFT's state
    public fun get_amount(self: &StakePosition): u64 {
        self.amount
    }

    public fun get_stake_timestamp(self: &StakePosition): u64 {
        self.stake_timestamp
    }

    public fun get_last_claimed_timestamp(
        self: &StakePosition, 
        reward_type: &String
    ): u64 {
        if (linked_table::contains(&self.last_claimed_timestamp, *reward_type)) {
            *linked_table::borrow(&self.last_claimed_timestamp, *reward_type)
        } else {
            0 // Return 0 if no claim has been made for this reward type
        }
    }
    
    // Existing modifier functions
    public fun decrease_amount(position: &mut StakePosition, decrease_by: u64) {
        assert!(position.amount >= decrease_by, ERROR_INSUFFICIENT_AMOUNT);
        position.amount = position.amount - decrease_by;
    }

    public fun set_last_claimed_timestamp(
        position: &mut StakePosition, 
        reward_type: String,
        new_timestamp: u64,
    ) {
        if (linked_table::contains(&position.last_claimed_timestamp, reward_type)) {
            let current_timestamp = linked_table::borrow(&position.last_claimed_timestamp, reward_type);
            assert!(
                *current_timestamp <= new_timestamp, 
                ERROR_INVALID_TIMESTAMP
            );
            *linked_table::borrow_mut(&mut position.last_claimed_timestamp, reward_type) = new_timestamp;
        } else {
            linked_table::push_back(&mut position.last_claimed_timestamp, reward_type, new_timestamp);
        }
    }

    public fun get_all_claim_timestamps(
        table: &LinkedTable<String, u64>
    ): (vector<String>, vector<u64>) {
        let mut types = vector::empty();
        let mut timestamps = vector::empty();
        
        // Get the first key
        let mut maybe_key = linked_table::front(table);
        
        // While we have a key
        while (option::is_some(maybe_key)) {
            let key = *option::borrow(maybe_key);
            
            // Get the value for this key
            let timestamp = *linked_table::borrow(table, key);
            
            // Store the key-value pair
            vector::push_back(&mut types, key);
            vector::push_back(&mut timestamps, timestamp);
            
            // Get the next key
            maybe_key = linked_table::next(table, key);
        };
        
        (types, timestamps)
    }
}