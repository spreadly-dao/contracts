module spreadly::stake_position {
    use sui::clock::{Self, Clock};
    use sui::linked_table::{Self, LinkedTable};
    use sui::table::{Self, Table};
    use std::ascii::{String};

    use spreadly::vote_type::{VoteType};

    const ERROR_INSUFFICIENT_AMOUNT: u64 = 1;
    const ERROR_INVALID_TIMESTAMP: u64 = 2;

    public struct VoteInfo has store, copy, drop {
        voting_power: u64,
        vote: VoteType
    }

    public struct StakePosition has key, store {
        id: UID,
        amount: u64,
        stake_timestamp: u64,
        last_claimed_timestamp: LinkedTable<String, u64>,
        votes: Table<ID, VoteInfo>, // Maps proposal ID to vote direction
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
            votes: table::new(ctx),
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
    public(package) fun decrease_amount(position: &mut StakePosition, decrease_by: u64) {
        assert!(position.amount >= decrease_by, ERROR_INSUFFICIENT_AMOUNT);
        position.amount = position.amount - decrease_by;
    }

    public(package) fun increase_amount(position: &mut StakePosition, increase_by: u64) {
        position.amount = position.amount + increase_by;
    }

    public(package) fun set_last_claimed_timestamp(
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

    public fun get_vote_info(
        position: &StakePosition, 
        proposal_id: ID
    ): Option<VoteInfo> {
        if (table::contains(&position.votes, proposal_id)) {
            option::some(*table::borrow(&position.votes, proposal_id))
        } else {
            option::none()
        }
    }

    // Accessor function to get vote type from VoteInfo
    public fun get_vote_type(vote_info: &VoteInfo): VoteType {
        vote_info.vote
    }

    // Accessor function to get voting power from VoteInfo
    public fun get_voting_power(vote_info: &VoteInfo): u64 {
        vote_info.voting_power
    }

    public(package) fun record_vote(
        position: &mut StakePosition, 
        proposal_id: ID, 
        vote: VoteType,
        voting_power: u64
    ) {
        let vote_info = VoteInfo {
            voting_power,
            vote
        };

        if (table::contains(&position.votes, proposal_id)) {
            let _ = table::remove(&mut position.votes, proposal_id);
        };
        table::add(&mut position.votes, proposal_id, vote_info);
    }

    public fun get_all_claim_timestamps(
        table: &LinkedTable<String, u64>
    ): (vector<String>, vector<u64>) {
        let mut types = vector::empty();
        let mut timestamps = vector::empty();
        
        let mut maybe_key = linked_table::front(table);
        
        while (option::is_some(maybe_key)) {
            let key = *option::borrow(maybe_key);
            
            let timestamp = *linked_table::borrow(table, key);
            
            vector::push_back(&mut types, key);
            vector::push_back(&mut timestamps, timestamp);
            
            maybe_key = linked_table::next(table, key);
        };
        
        (types, timestamps)
    }
}