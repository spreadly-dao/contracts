module spreadly::governance {
    use sui::clock::{Self, Clock};
    use sui::event::emit;
    use sui::vec_set::{Self, VecSet};
    use std::ascii::{String};

    use spreadly::stake_position::{Self, StakePosition};
    use spreadly::staking_pool::{Self, StakingPool};
    use spreadly::vote_type::{Self, VoteType};

    // === Error Constants ===
    const EINSUFFICIENT_STAKE: u64 = 1;
    const EPROPOSAL_NOT_ACTIVE: u64 = 2;
    const EPROPOSAL_NOT_SUCCEEDED: u64 = 3;
    const ETIMELOCK_NOT_ENDED: u64 = 4;
    const EPROPOSAL_EXPIRED: u64 = 5;
    const EINVALID_THRESHOLD: u64 = 6;
    const ENOT_OTW: u64 = 7;

    // === Constants ===
    const PROPOSAL_STATE_PENDING: u8 = 0;
    const PROPOSAL_STATE_ACTIVE: u8 = 1;
    const PROPOSAL_STATE_CANCELED: u8 = 2;
    const PROPOSAL_STATE_DEFEATED: u8 = 3;
    const PROPOSAL_STATE_SUCCEEDED: u8 = 4;
    const PROPOSAL_STATE_QUEUED: u8 = 5;
    const PROPOSAL_STATE_EXPIRED: u8 = 6;
    const PROPOSAL_STATE_EXECUTED: u8 = 7;

    // === public Structs ===
    /// One Time Witness for the module
    public struct GOVERNANCE has drop {}

    // Governance Config containing protocol params
    public struct GovernanceConfig has key {
        id: UID,
        // Minimum stake required to create a proposal
        proposal_threshold: u64,
        // Minimum percentage of total supply that must vote
        quorum_threshold: u64,
        // Minimum percentage of votes that must be in favor
        vote_threshold: u64,
        // Time delay after proposal creation before voting starts
        voting_delay: u64,
        // Duration of voting period
        voting_period: u64,
        // Time delay before execution after proposal succeeds
        timelock_period: u64,
        // Time window for execution after timelock ends
        execution_period: u64,
        // Minimum SPRD required for bonding curves
        min_bonding_threshold: u64,
        // Management fee rate (in basis points)
        management_fee_rate: u64,
        // Whitelisted assets for investment window
        deposit_window_whitelisted_assets: VecSet<String>,
    }

    public enum ProposalAction has store, copy {
        UpdateThresholds { 
            proposal_threshold: u64,
            quorum_threshold: u64,
            vote_threshold: u64 
        },
        WhitelistAsset { 
            asset_type: String
        },
        UpdateFees { 
            new_fee_rate: u64 
        },
        UpdateVotingParams { 
            voting_delay: u64,
            voting_period: u64 
        },
        UpdateBondingThreshold { 
            new_threshold: u64 
        },
        UpdateTimelock { 
            timelock_period: u64,
            execution_period: u64 
        }
    }

    public struct Proposal has key {
        id: UID,
        // Creator of the proposal
        proposer: address,
        // Proposal metadata
        title: String,
        description: String,
        // Type of action being proposed
        action: ProposalAction,
        // Voting timestamps
        creation_time: u64,
        start_time: u64,
        end_time: u64,
        // Voting results
        for_votes: u64,
        against_votes: u64,
        abstain_votes: u64,
        // Execution details
        executed: bool,
        execution_time: u64,
        canceled: bool
    }

    // === Events ===

    public struct ProposalCreated has copy, drop {
        proposal_id: ID,
        proposer: address,
        title: String,
        description: String,
        start_time: u64,
        end_time: u64
    }

    public struct VoteCast has copy, drop {
        proposal_id: ID,
        voter: address,
        vote: VoteType,
        voting_power: u64
    }

    public struct ProposalExecuted has copy, drop {
        proposal_id: ID,
        execution_time: u64
    }

    fun init(otw: GOVERNANCE, ctx: &mut TxContext) {
        assert!(sui::types::is_one_time_witness(&otw), ENOT_OTW);
        
        let config = GovernanceConfig {
            id: object::new(ctx),
            proposal_threshold: 1_000_000_000, // 1_000 SPRD
            quorum_threshold: 10, // 10%
            vote_threshold: 51, // 51%
            voting_delay: 24 * 60 * 60 * 1000, // 24 hours in milliseconds
            voting_period: 72 * 60 * 60 * 1000, // 72 hours
            timelock_period: 24 * 60 * 60 * 1000, // 24 hours
            execution_period: 48 * 60 * 60 * 1000, // 48 hours
            min_bonding_threshold: 25_000_000_000, // 25_000 SPRD
            management_fee_rate: 500, // 5% in basis points
            deposit_window_whitelisted_assets: vec_set::empty()
        };

        // Share the config object so it can be used by the DAO
        transfer::share_object(config);
    }

    // === Public Functions ===

    public fun create_proposal(
        config: &GovernanceConfig,
        stake_position: &StakePosition,
        title: String,
        description: String,
        action: ProposalAction,
        clock: &Clock,
        ctx: &mut TxContext
    ): Proposal {
        let stake_amount = stake_position::get_amount(stake_position);
        assert!(stake_amount >= config.proposal_threshold, EINSUFFICIENT_STAKE);

        let current_time = clock::timestamp_ms(clock);
        let start_time = current_time + config.voting_delay;
        let end_time = start_time + config.voting_period;

        let proposal = Proposal {
            id: object::new(ctx),
            proposer: tx_context::sender(ctx),
            title,
            description,
            action,
            creation_time: current_time,
            start_time,
            end_time,
            for_votes: 0,
            against_votes: 0,
            abstain_votes: 0,
            executed: false,
            execution_time: 0,
            canceled: false
        };

        emit(ProposalCreated {
            proposal_id: object::id(&proposal),
            proposer: proposal.proposer,
            title: proposal.title,
            description: proposal.description,
            start_time,
            end_time
        });

        proposal
    }

    public fun cast_vote(
        proposal: &mut Proposal,
        stake_position: &mut StakePosition,
        vote: VoteType,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        let current_time = clock::timestamp_ms(clock);
        assert!(
            current_time >= proposal.start_time && current_time <= proposal.end_time,
            EPROPOSAL_NOT_ACTIVE
        );

        let voting_power = stake_position::get_amount(stake_position);
        assert!(voting_power > 0, EINSUFFICIENT_STAKE);

        let proposal_id = object::id(proposal);
        
        // Get previous vote if it exists
        let maybe_prev_vote = stake_position::get_vote_info(stake_position, proposal_id);
        
        // If they've voted before, subtract their previous vote
        if (option::is_some(&maybe_prev_vote)) {
            let prev_vote = option::destroy_some(maybe_prev_vote);
            let prev_vote_type = stake_position::get_vote_type(&prev_vote);
            let prev_voting_power = stake_position::get_voting_power(&prev_vote);
            
            if (vote_type::is_for(&prev_vote_type)) {
                proposal.for_votes = proposal.for_votes - prev_voting_power;
            } else if (vote_type::is_against(&prev_vote_type)) {
                proposal.against_votes = proposal.against_votes - prev_voting_power;
            } else if (vote_type::is_abstain(&prev_vote_type)) {
                proposal.abstain_votes = proposal.abstain_votes - prev_voting_power;
            };
        };

        // Add new vote
        if (vote_type::is_for(&vote)) {
            proposal.for_votes = proposal.for_votes + voting_power;
        } else if (vote_type::is_against(&vote)) {
            proposal.against_votes = proposal.against_votes + voting_power;
        } else if (vote_type::is_abstain(&vote)) {
            proposal.abstain_votes = proposal.abstain_votes + voting_power;
        };

        stake_position::record_vote(stake_position, proposal_id, vote, voting_power);

        emit(VoteCast {
            proposal_id,
            voter: tx_context::sender(ctx),
            vote,
            voting_power
        });
    }

    public fun queue_proposal(
        config: &GovernanceConfig,
        proposal: &mut Proposal,
        staking_pool: &StakingPool,
        clock: &Clock
    ) {
        let current_time = clock::timestamp_ms(clock);
        assert!(current_time > proposal.end_time, EPROPOSAL_NOT_ACTIVE);
        
        let total_votes = proposal.for_votes + proposal.against_votes + proposal.abstain_votes;
        let total_staked = staking_pool::total_staked(staking_pool);
        
        // Check quorum
        assert!(
            (total_votes * 100) >= (total_staked * config.quorum_threshold),
            EPROPOSAL_NOT_SUCCEEDED
        );
        
        // Check vote threshold
        assert!(
            (proposal.for_votes * 100) >= (total_votes * config.vote_threshold),
            EPROPOSAL_NOT_SUCCEEDED
        );

        proposal.execution_time = current_time + config.timelock_period;
    }

    public fun execute_proposal(
        config: &mut GovernanceConfig,
        proposal: &mut Proposal,
        clock: &Clock,
    ) {
        let current_time = clock::timestamp_ms(clock);
        
        // Check timelock has passed
        assert!(current_time >= proposal.execution_time, ETIMELOCK_NOT_ENDED);
        
        // Check not expired
        assert!(
            current_time <= proposal.execution_time + config.execution_period,
            EPROPOSAL_EXPIRED
        );

        // Mark as executed
        proposal.executed = true;

        emit(ProposalExecuted {
            proposal_id: object::id(proposal),
            execution_time: current_time
        });

        // Execute action based on proposal type
        execute_action(proposal, config);
    }

    // === Internal Functions ===

    fun execute_action(
        proposal: &Proposal,
        config: &mut GovernanceConfig
    ) {
        match (proposal.action) {
            ProposalAction::UpdateThresholds { proposal_threshold, quorum_threshold, vote_threshold } => {
                config.proposal_threshold = proposal_threshold;
                config.quorum_threshold = quorum_threshold;
                config.vote_threshold = vote_threshold;
            },
            ProposalAction::WhitelistAsset { asset_type } => {
                vec_set::insert(&mut config.deposit_window_whitelisted_assets, asset_type);
            },
            ProposalAction::UpdateFees { new_fee_rate } => {
                assert!(new_fee_rate <= 10000, EINVALID_THRESHOLD);
                config.management_fee_rate = new_fee_rate;
            },
            ProposalAction::UpdateVotingParams { voting_delay, voting_period } => {
                config.voting_delay = voting_delay;
                config.voting_period = voting_period;
            },
            ProposalAction::UpdateBondingThreshold { new_threshold } => {
                config.min_bonding_threshold = new_threshold;
            },
            ProposalAction::UpdateTimelock { timelock_period, execution_period } => {
                config.timelock_period = timelock_period;
                config.execution_period = execution_period;
            }
        }
    }

    // === View Functions ===

    public fun get_proposal_state(
        proposal: &Proposal,
        config: &GovernanceConfig,
        staking_pool: &StakingPool,
        clock: &Clock
    ): u8 {
        let current_time = clock::timestamp_ms(clock);

        if (proposal.canceled) {
            return PROPOSAL_STATE_CANCELED
        };

        if (proposal.executed) {
            return PROPOSAL_STATE_EXECUTED
        };

        if (current_time < proposal.start_time) {
            return PROPOSAL_STATE_PENDING
        };

        if (current_time <= proposal.end_time) {
            return PROPOSAL_STATE_ACTIVE
        };

        let total_votes = proposal.for_votes + proposal.against_votes;
        let total_staked = staking_pool::total_staked(staking_pool);

        // Check if quorum and vote threshold met
        if ((total_votes * 100) >= (total_staked * config.quorum_threshold) &&
            (proposal.for_votes * 100) >= (total_votes * config.vote_threshold)) {
            
            if (proposal.execution_time == 0) {
                return PROPOSAL_STATE_SUCCEEDED
            };

            if (current_time < proposal.execution_time) {
                return PROPOSAL_STATE_QUEUED
            };

            if (current_time <= proposal.execution_time + config.execution_period) {
                return PROPOSAL_STATE_QUEUED
            };

            return PROPOSAL_STATE_EXPIRED
        };

        PROPOSAL_STATE_DEFEATED
    }
}