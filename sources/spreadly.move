module spreadly::spreadly {
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::tx_context::{Self, TxContext};
    use sui::balance::{Self, Balance};
    use sui::object::{Self, UID};
    use sui::clock::{Self, Clock};
    use sui::transfer;
    use sui::table::{Self, Table};
    use sui::vec_set::{Self, VecSet};
    use sui::event;
    use std::option;
    use sui::sui::SUI;

    // Error constants
    const EWRONG_PHASE: u64 = 0;
    const EPERIOD_ENDED: u64 = 1;
    const EMAX_SUI_CAP: u64 = 2;
    const EPERIOD_NOT_COMPLETE: u64 = 3;
    const ESTILL_IN_LIQUIDITY: u64 = 4;
    const ENOT_LP: u64 = 5;
    const EALREADY_CLAIMED: u64 = 6;
    const EALREADY_REGISTERED: u64 = 7;
    const ENOT_REGISTERED: u64 = 8;
    const EMINIMUM_CONTRIBUTION: u64 = 9;
    const EMAX_CONTRIBUTION: u64 = 10;
    const ENO_LIQUIDITY: u64 = 11;
    const EZERO_CLAIMERS: u64 = 12;

    // One-time witness type
    struct SPREADLY has drop {}

    // Constants
    const TOTAL_SUPPLY: u64 = 1_000_000_000_000_000; // 1 quadrillion
    const MAX_SUI_CAP: u64 = 15_000_000_000_000; // 15,000 SUI
    const MIN_SUI_CONTRIBUTION: u64 = 1_000_000_000; // 1 SUI minimum
    const MAX_SUI_CONTRIBUTION: u64 = 1_000_000_000_000; // 1,000 SUI maximum per address
    const LIQUIDITY_PERIOD: u64 = 7 * 24 * 60 * 60 * 1000; // 7 days
    const CLAIM_PERIOD: u64 = 7 * 24 * 60 * 60 * 1000; // 7 days
    const LP_ALLOCATION: u64 = TOTAL_SUPPLY * 40 / 100; // 40% for LPs
    const COMMUNITY_ALLOCATION: u64 = TOTAL_SUPPLY * 40 / 100; // 40% for community
    const DEX_ALLOCATION: u64 = TOTAL_SUPPLY * 20 / 100; // 20% for DEX

    // Distribution phases
    const PHASE_LIQUIDITY: u8 = 0;
    const PHASE_COMMUNITY_REGISTRATION: u8 = 1;
    const PHASE_DISTRIBUTION: u8 = 2;
    const PHASE_COMPLETED: u8 = 3;

    struct Distribution has key {
        id: UID,
        treasury_cap: TreasuryCap<SPREADLY>,
        phase: u8,
        liquidity_start: u64,
        claim_start: u64,
        sui_balance: Balance<SUI>,
        lp_remaining: u64,
        community_remaining: u64,
        dex_remaining: u64,
        liquidity_providers: Table<address, u64>,
        claimed_lp: VecSet<address>,
        registered_claimers: VecSet<address>,
        claimed_community: VecSet<address>,
    }

    struct LiquidityProvided has copy, drop {
        provider: address,
        amount: u64,
        total_sui: u64,
        timestamp: u64
    }

    struct CommunityRegistered has copy, drop {
        claimer: address,
        timestamp: u64
    }

    struct TokensClaimed has copy, drop {
        claimer: address,
        amount: u64,
        claim_type: u8, // 0 for LP, 1 for community
        timestamp: u64
    }

    struct PhaseChanged has copy, drop {
        old_phase: u8,
        new_phase: u8,
        timestamp: u64
    }

    // Initialize distribution
    fun init(witness: SPREADLY, ctx: &mut TxContext) {
        let (treasury_cap, metadata) = coin::create_currency(
            witness, 
            9, 
            b"Spreadly", 
            b"SPREADLY", 
            b"Spreadly DAO Token", 
            option::none(), 
            ctx
        );
        
        let distribution = Distribution {
            id: object::new(ctx),
            treasury_cap,
            phase: PHASE_LIQUIDITY,
            liquidity_start: 0,
            claim_start: 0,
            sui_balance: balance::zero(),
            lp_remaining: LP_ALLOCATION,
            community_remaining: COMMUNITY_ALLOCATION,
            dex_remaining: DEX_ALLOCATION,
            liquidity_providers: table::new(ctx),
            claimed_lp: vec_set::empty(),
            registered_claimers: vec_set::empty(),
            claimed_community: vec_set::empty(),
        };

        transfer::share_object(distribution);
        transfer::public_freeze_object(metadata);
    }

    // Start liquidity phase
    public entry fun start_liquidity_phase(
        distribution: &mut Distribution,
        clock: &Clock,
    ) {
        assert!(distribution.phase == PHASE_LIQUIDITY, EWRONG_PHASE);
        assert!(distribution.liquidity_start == 0, EPERIOD_ENDED);
        
        distribution.liquidity_start = clock::timestamp_ms(clock);
        
        event::emit(PhaseChanged {
            old_phase: distribution.phase,
            new_phase: PHASE_LIQUIDITY,
            timestamp: clock::timestamp_ms(clock)
        });
    }

    // Provide liquidity
    public entry fun provide_liquidity(
        distribution: &mut Distribution,
        payment: Coin<SUI>,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(distribution.phase == PHASE_LIQUIDITY, EWRONG_PHASE);
        assert!(distribution.liquidity_start != 0, EPERIOD_NOT_COMPLETE);
        assert!(!is_liquidity_period_complete(distribution, clock), EPERIOD_ENDED);

        let sui_amount = coin::value(&payment);
        // Minimum contribution check
        assert!(sui_amount >= MIN_SUI_CONTRIBUTION, EMINIMUM_CONTRIBUTION);

        let provider = tx_context::sender(ctx);
        let current_contribution = if (table::contains(&distribution.liquidity_providers, provider)) {
            *table::borrow(&distribution.liquidity_providers, provider)
        } else {
            0
        };

        let total_contribution = current_contribution + sui_amount;
        // Maximum per-address contribution check
        assert!(total_contribution <= MAX_SUI_CONTRIBUTION, EMAX_CONTRIBUTION);

        let total_after = balance::value(&distribution.sui_balance) + sui_amount;
        assert!(total_after <= MAX_SUI_CAP, EMAX_SUI_CAP);

        // Update provider's contribution
        if (current_contribution == 0) {
            table::add(&mut distribution.liquidity_providers, provider, sui_amount);
        } else {
            let current = table::borrow_mut(&mut distribution.liquidity_providers, provider);
            *current = *current + sui_amount;
        };

        balance::join(&mut distribution.sui_balance, coin::into_balance(payment));

        event::emit(LiquidityProvided {
            provider,
            amount: sui_amount,
            total_sui: total_after,  // Now using balance value
            timestamp: clock::timestamp_ms(clock)
        });

        if (total_after >= MAX_SUI_CAP) {
            end_liquidity_period(distribution, clock);
        }
    }

    public entry fun end_liquidity_period(
        distribution: &mut Distribution, 
        clock: &Clock,
    ) {
        assert!(distribution.phase == PHASE_LIQUIDITY, EWRONG_PHASE);
        let total_sui = balance::value(&distribution.sui_balance);
        
        assert!(
            total_sui >= MAX_SUI_CAP || 
            is_liquidity_period_complete(distribution, clock),
            EPERIOD_NOT_COMPLETE
        );
        assert!(total_sui > 0, ENO_LIQUIDITY);

        distribution.phase = PHASE_COMMUNITY_REGISTRATION;
        distribution.claim_start = clock::timestamp_ms(clock);

        event::emit(PhaseChanged {
            old_phase: PHASE_LIQUIDITY,
            new_phase: PHASE_COMMUNITY_REGISTRATION,
            timestamp: clock::timestamp_ms(clock)
        });
    }

    // Register for community allocation
    public entry fun register_for_community(
        distribution: &mut Distribution,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(distribution.phase == PHASE_COMMUNITY_REGISTRATION, EWRONG_PHASE);
        assert!(!is_claim_period_complete(distribution, clock), EPERIOD_ENDED);

        let claimer = tx_context::sender(ctx);
        assert!(!vec_set::contains(&distribution.registered_claimers, &claimer), EALREADY_REGISTERED);

        vec_set::insert(&mut distribution.registered_claimers, claimer);

        event::emit(CommunityRegistered {
            claimer,
            timestamp: clock::timestamp_ms(clock)
        });
    }

    // Start distribution phase
    public entry fun start_distribution(
        distribution: &mut Distribution,
        clock: &Clock
    ) {
        assert!(distribution.phase == PHASE_COMMUNITY_REGISTRATION, EWRONG_PHASE);
        assert!(is_claim_period_complete(distribution, clock), EPERIOD_NOT_COMPLETE);
        assert!(vec_set::size(&distribution.registered_claimers) > 0, EZERO_CLAIMERS);

        distribution.phase = PHASE_DISTRIBUTION;

        event::emit(PhaseChanged {
            old_phase: PHASE_COMMUNITY_REGISTRATION,
            new_phase: PHASE_DISTRIBUTION,
            timestamp: clock::timestamp_ms(clock)
        });
    }

    // Claim LP tokens
    public entry fun claim_lp_tokens(
        distribution: &mut Distribution,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(distribution.phase >= PHASE_COMMUNITY_REGISTRATION, ESTILL_IN_LIQUIDITY);
        
        let provider = tx_context::sender(ctx);
        assert!(table::contains(&distribution.liquidity_providers, provider), ENOT_LP);
        assert!(!vec_set::contains(&distribution.claimed_lp, &provider), EALREADY_CLAIMED);

        let sui_contributed = *table::borrow(&distribution.liquidity_providers, provider);
        let total_sui = balance::value(&distribution.sui_balance);
        let lp_share = (sui_contributed * LP_ALLOCATION) / total_sui;

        distribution.lp_remaining = distribution.lp_remaining - lp_share;
        let tokens = coin::mint(&mut distribution.treasury_cap, lp_share, ctx);
        transfer::public_transfer(tokens, provider);
        vec_set::insert(&mut distribution.claimed_lp, provider);

        event::emit(TokensClaimed {
            claimer: provider,
            amount: lp_share,
            claim_type: 0,
            timestamp: clock::timestamp_ms(clock)
        });
    }

    // Claim community tokens
    public entry fun claim_community_tokens(
        distribution: &mut Distribution,
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(distribution.phase == PHASE_DISTRIBUTION, EWRONG_PHASE);
        
        let claimer = tx_context::sender(ctx);
        assert!(vec_set::contains(&distribution.registered_claimers, &claimer), ENOT_REGISTERED);
        assert!(!vec_set::contains(&distribution.claimed_community, &claimer), EALREADY_CLAIMED);

        let total_claimers = vec_set::size(&distribution.registered_claimers);
        let share = COMMUNITY_ALLOCATION / total_claimers;
        assert!(share <= distribution.community_remaining, EALREADY_CLAIMED);

        distribution.community_remaining = distribution.community_remaining - share;
        let tokens = coin::mint(&mut distribution.treasury_cap, share, ctx);
        transfer::public_transfer(tokens, claimer);
        vec_set::insert(&mut distribution.claimed_community, claimer);

        event::emit(TokensClaimed {
            claimer,
            amount: share,
            claim_type: 1,
            timestamp: clock::timestamp_ms(clock)
        });

        // Check if distribution is complete
        if (vec_set::size(&distribution.claimed_community) == total_claimers) {
            distribution.phase = PHASE_COMPLETED;
            
            event::emit(PhaseChanged {
                old_phase: PHASE_DISTRIBUTION,
                new_phase: PHASE_COMPLETED,
                timestamp: clock::timestamp_ms(clock)
            });
        }
    }

    // Helper functions
    fun is_liquidity_period_complete(distribution: &Distribution, clock: &Clock): bool {
        distribution.liquidity_start != 0 && (
            balance::value(&distribution.sui_balance) >= MAX_SUI_CAP || 
            (clock::timestamp_ms(clock) - distribution.liquidity_start) >= LIQUIDITY_PERIOD
        )
    }

    fun is_claim_period_complete(distribution: &Distribution, clock: &Clock): bool {
        distribution.claim_start != 0 &&
        (clock::timestamp_ms(clock) - distribution.claim_start) >= CLAIM_PERIOD
    }
}