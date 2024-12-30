#[allow(unused_use, unused_const, unused_variable)]
module spreadly::governance {
    use std::string::{Self, String};
    use std::vector;
    use std::option::{Self, Option};
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::url::{Self, Url};
    use sui::table::{Self, Table};
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use spreadly::dao::{Self, DAO};
    use spreadly::treasury::{Self, Treasury};

    // Error constants
    const EINVALID_PROPOSAL_DURATION: u64 = 0;
    const EINVALID_TOKEN_AMOUNT: u64 = 1;
    const EINVALID_START_TIME: u64 = 2;
    const EINVALID_END_TIME: u64 = 3;
    const EINVALID_ACTIONS: u64 = 4;
    const EPROPOSAL_NOT_ACTIVE: u64 = 5;
    const EALREADY_VOTED: u64 = 6;

    // Status constants
    const PROPOSAL_STATUS_ACTIVE: u8 = 0;
    const PROPOSAL_STATUS_SUCCEEDED: u8 = 1;
    const PROPOSAL_STATUS_DEFEATED: u8 = 2;
    const PROPOSAL_STATUS_EXECUTED: u8 = 3;
    const PROPOSAL_STATUS_EXPIRED: u8 = 4;

    // Vote types
    const VOTE_YES: u8 = 0;
    const VOTE_NO: u8 = 1;
    const VOTE_ABSTAIN: u8 = 2;

        // Action types
    const ACTION_UPDATE_CONFIG: u8 = 0;
    const ACTION_MINT_TOKENS: u8 = 1;
    const ACTION_WITHDRAW: u8 = 2;
    const ACTION_BURN: u8 = 3;
    const ACTION_CUSTOM: u8 = 4;

    /// Represents a single action that can be executed if proposal passes
    struct ProposalAction has store, drop {
        action_type: u8,
        target: ID,      // Target object ID (e.g., Treasury, DAO)
        params: vector<u8> // Serialized parameters for the action
    }

    /// Main proposal structure
    struct Proposal<phantom CoinType> has key {
        id: UID,
        dao_id: ID,
        creator: address,
        title: String,
        description: String,
        start_time: u64,
        end_time: u64,
        actions: vector<ProposalAction>,
        executed_actions: vector<bool>,
        yes_votes: u64,
        no_votes: u64,
        abstain_votes: u64,
        voters: Table<address, bool>,
        status: u8
    }

    struct ProposalCreated has copy, drop {
        proposal_id: ID,
        dao_id: ID,
        creator: address,
        title: String,
        start_time: u64,
        end_time: u64
    }

    struct ConfigUpdateParams has store, drop {
        new_name: Option<String>,
        new_description: Option<String>,
        new_logo_url: Option<String>,
        new_support_threshold: Option<u64>,
        new_min_participation: Option<u64>,
        new_min_proposal_duration: Option<u64>,
        new_min_token_for_proposal: Option<u64>
    }

    public fun encode_config_update(
        new_name: Option<String>,
        new_description: Option<String>,
        new_logo_url: Option<String>,
        new_support_threshold: Option<u64>,
        new_min_participation: Option<u64>,
        new_min_proposal_duration: Option<u64>,
        new_min_token_for_proposal: Option<u64>
    ): vector<u8> {
        let params = ConfigUpdateParams {
            new_name,
            new_description,
            new_logo_url,
            new_support_threshold,
            new_min_participation,
            new_min_proposal_duration,
            new_min_token_for_proposal
        };
        
        // Start with empty vector
        let encoded = vector::empty();

        // Encode each field
        if (option::is_some(&params.new_name)) {
            let name = option::borrow(&params.new_name);
            vector::append(&mut encoded, *string::as_bytes(name));
        };
        // ... encode other fields similarly

        encoded
    }

    // Helper function to create an action
    public fun create_action(
        action_type: u8,
        target: ID,
        params: vector<u8>
    ): ProposalAction {
        ProposalAction {
            action_type,
            target,
            params
        }
    }

    public entry fun create_config_update_proposal<CoinType>(
        dao: &DAO<CoinType>,
        title: String,
        description: String,
        start_time: u64,
        duration: u64,
        // Config update parameters
        new_name: Option<String>,
        new_description: Option<String>,
        new_logo_url: Option<String>,
        new_support_threshold: Option<u64>,
        new_min_participation: Option<u64>,
        new_min_proposal_duration: Option<u64>,
        new_min_token_for_proposal: Option<u64>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Create action vectors
        let action_types = vector::singleton(ACTION_UPDATE_CONFIG);
        let action_targets = vector::singleton(object::id(dao));
        
        // Encode config parameters
        let encoded_params = encode_config_update(
            new_name,
            new_description,
            new_logo_url,
            new_support_threshold,
            new_min_participation,
            new_min_proposal_duration,
            new_min_token_for_proposal
        );
        let action_params = vector::singleton(encoded_params);

        create_proposal(
            dao,
            title,
            description,
            start_time,
            duration,
            action_types,
            action_targets,
            action_params,
            clock,
            ctx
        );
    }

    /// Create a new proposal
    public fun create_proposal<CoinType>(
        dao: &DAO<CoinType>,
        title: String,
        description: String,
        start_time: u64,
        duration: u64,
        action_types: vector<u8>,
        action_targets: vector<ID>,
        action_params: vector<vector<u8>>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        // Validate inputs have same length
        let action_count = vector::length(&action_types);
        assert!(
            action_count == vector::length(&action_targets) &&
            action_count == vector::length(&action_params),
            EINVALID_ACTIONS
        );

        // Build actions vector
        let actions = vector::empty();
        let i = 0;
        while (i < action_count) {
            let action = create_action(
                *vector::borrow(&action_types, i),
                *vector::borrow(&action_targets, i),
                *vector::borrow(&action_params, i)
            );
            vector::push_back(&mut actions, action);
            i = i + 1;
        };

        // Validate creator has enough tokens
        let min_tokens = dao::min_token_for_proposal(dao);
        // TODO: Implement token balance check
        
        // Validate timing
        let current_time = clock::timestamp_ms(clock);
        assert!(start_time >= current_time, EINVALID_START_TIME);
        assert!(duration >= dao::min_proposal_duration(dao), EINVALID_PROPOSAL_DURATION);
        
        let end_time = start_time + duration;
        
        // Create proposal object
        let proposal = Proposal<CoinType> {
            id: object::new(ctx),
            dao_id: object::id(dao),
            creator: tx_context::sender(ctx),
            title,
            description,
            start_time,
            end_time,
            actions,
            executed_actions: vector::empty(),
            yes_votes: 0,
            no_votes: 0,
            abstain_votes: 0,
            voters: table::new(ctx),
            status: PROPOSAL_STATUS_ACTIVE
        };

        // Initialize execution tracking
        let i = 0;
        while (i < action_count) {
            vector::push_back(&mut proposal.executed_actions, false);
            i = i + 1;
        };

        // Emit creation event
        event::emit(ProposalCreated {
            proposal_id: object::id(&proposal),
            dao_id: object::id(dao),
            creator: tx_context::sender(ctx),
            title,
            start_time,
            end_time
        });

        transfer::share_object(proposal);
    }

    /// Cast a vote on a proposal
    public entry fun cast_vote<CoinType>(
        proposal: &mut Proposal<CoinType>,
        vote_type: u8,
        voting_power: u64,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let voter = tx_context::sender(ctx);
        
        // Validate proposal is active
        assert!(proposal.status == PROPOSAL_STATUS_ACTIVE, EPROPOSAL_NOT_ACTIVE);
        
        // Check if already voted
        assert!(!table::contains(&proposal.voters, voter), EALREADY_VOTED);
        
        // Check voting period
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time >= proposal.start_time && current_time <= proposal.end_time, EPROPOSAL_NOT_ACTIVE);

        // Record vote
        table::add(&mut proposal.voters, voter, true);
        
        if (vote_type == VOTE_YES) {
            proposal.yes_votes = proposal.yes_votes + voting_power;
        } else if (vote_type == VOTE_NO) {
            proposal.no_votes = proposal.no_votes + voting_power;
        } else if (vote_type == VOTE_ABSTAIN) {
            proposal.abstain_votes = proposal.abstain_votes + voting_power;
        };
    }

    /// Check if a proposal has enough support to pass
    public fun has_passed<CoinType>(
        proposal: &Proposal<CoinType>,
        dao: &DAO<CoinType>
    ): bool {
        let total_votes = proposal.yes_votes + proposal.no_votes + proposal.abstain_votes;
        let participation = (total_votes * 10000) / dao::min_participation(dao);
        
        if (participation < dao::min_participation(dao)) {
            return false
        };

        let support = (proposal.yes_votes * 10000) / (proposal.yes_votes + proposal.no_votes);
        support >= dao::support_threshold(dao)
    }

    // === Getter Functions ===
    public fun proposal_status<CoinType>(proposal: &Proposal<CoinType>): u8 { proposal.status }
    public fun proposal_creator<CoinType>(proposal: &Proposal<CoinType>): address { proposal.creator }
    public fun proposal_start_time<CoinType>(proposal: &Proposal<CoinType>): u64 { proposal.start_time }
    public fun proposal_end_time<CoinType>(proposal: &Proposal<CoinType>): u64 { proposal.end_time }
    public fun proposal_votes<CoinType>(proposal: &Proposal<CoinType>): (u64, u64, u64) {
        (proposal.yes_votes, proposal.no_votes, proposal.abstain_votes)
    }
}