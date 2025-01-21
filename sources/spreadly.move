module spreadly::spreadly {
    use std::ascii;
    use sui::url;
    use sui::coin::{Self, Coin, TreasuryCap};
    use sui::balance::{Self, Balance};
    use sui::clock::{Self, Clock};
    use sui::table::{Self, Table};
    use sui::vec_set::{Self, VecSet};
    use sui::event;
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
    const EINCORRECT_DEPOSIT: u64 = 13;

    // One-time witness type
    public struct SPREADLY has drop {}

    // Constants
    // const TOTAL_SUPPLY: u64 = 1_000_000_000_000_000_000;
    const MAX_SUI_CAP: u64 = 15_000_000_000_000; // 15,000 SUI
    const MIN_SUI_CONTRIBUTION: u64 = 1_000_000_000; // 1 SUI minimum
    const MAX_SUI_CONTRIBUTION: u64 = 250_000_000_000; // 250 SUI maximum per address
    const LIQUIDITY_PERIOD: u64 = 7 * 24 * 60 * 60 * 1000; // 7 days
    const CLAIM_PERIOD: u64 = 7 * 24 * 60 * 60 * 1000; // 7 days
    const LP_ALLOCATION: u64 = 450_000_000_000_000_000; // 45% for LPs
    const COMMUNITY_ALLOCATION: u64 = 350_000_000_000_000_000; // 35% for community
    const COMMUNITY_ALLOCATION_LOCK: u64 = 5_000_000_000; // 5 SUI lock
    const DEX_ALLOCATION: u64 = 150_000_000_000_000_000; // 15% for DEX
    const CORE_ALLOCATION: u64 = 50_000_000_000_000_000; // 5% for core team

    // Distribution phases
    const PHASE_LIQUIDITY: u8 = 0;
    const PHASE_COMMUNITY_REGISTRATION: u8 = 1;
    const PHASE_DISTRIBUTION: u8 = 2;
    const PHASE_COMPLETED: u8 = 3;

    public struct Distribution has key {
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
        community_claim_sui: Balance<SUI>,
    }

    public struct LiquidityProvided has copy, drop {
        provider: address,
        amount: u64,
        total_sui: u64,
        timestamp: u64
    }

    public struct CommunityRegistered has copy, drop {
        claimer: address,
        timestamp: u64
    }

    public struct TokensClaimed has copy, drop {
        claimer: address,
        amount: u64,
        claim_type: u8, // 0 for LP, 1 for community
        timestamp: u64
    }

    public struct PhaseChanged has copy, drop {
        old_phase: u8,
        new_phase: u8,
        timestamp: u64
    }

    // Initialize distribution
    fun init(witness: SPREADLY, ctx: &mut TxContext) {
        let (mut treasury_cap, metadata) = coin::create_currency(
            witness, 
            9, 
            b"SPRD",
            b"Spreadly",
            b"Spreadly DAO Token",
            option::some(url::new_unsafe(ascii::string(b"https://www.spreadly.xyz/spreadly.svg"))),
            ctx
        );
        
        // Mint core team allocation and transfer to deployer
        let deployer = tx_context::sender(ctx);
        let core_tokens = coin::mint(&mut treasury_cap, CORE_ALLOCATION, ctx);
        transfer::public_transfer(core_tokens, deployer);
        
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
            community_claim_sui: balance::zero(),
        };

        transfer::share_object(distribution);
        transfer::public_freeze_object(metadata);
    }

    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(SPREADLY {}, ctx)
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
        // asserts no overflow of max cap
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
        payment: Coin<SUI>,  // New parameter to accept SUI deposit
        clock: &Clock,
        ctx: &mut TxContext
    ) {
        assert!(distribution.phase == PHASE_COMMUNITY_REGISTRATION, EWRONG_PHASE);
        assert!(!is_claim_period_complete(distribution, clock), EPERIOD_ENDED);

        let claimer = tx_context::sender(ctx);
        assert!(!vec_set::contains(&distribution.registered_claimers, &claimer), EALREADY_REGISTERED);

        assert!(coin::value(&payment) == COMMUNITY_ALLOCATION_LOCK, EINCORRECT_DEPOSIT);

        balance::join(&mut distribution.community_claim_sui, coin::into_balance(payment));
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

    // helper to calculate accurate share
    fun calculate_share_ratio(sui_contributed: u64, total_sui: u64): u64 {
        // Cast to u128 first to avoid overflow in multiplication
        let bps_contributed = (((sui_contributed as u128)) * 10000) / ((total_sui as u128));
        
        // Apply that percentage to the allocation
        let result = (bps_contributed * ((LP_ALLOCATION as u128))) / 10000;
        
        // Cast back to u64 for return
        (result as u64)
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
        let lp_share = calculate_share_ratio(sui_contributed, total_sui);

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


        // Mint and transfer SPRD tokens
        distribution.community_remaining = distribution.community_remaining - share;
        let tokens = coin::mint(&mut distribution.treasury_cap, share, ctx);
        transfer::public_transfer(tokens, claimer);
        vec_set::insert(&mut distribution.claimed_community, claimer);

        // Return the SUI deposit
        let deposit_return = coin::from_balance(balance::split(&mut distribution.community_claim_sui, COMMUNITY_ALLOCATION_LOCK), ctx);
        transfer::public_transfer(deposit_return, claimer);
        
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

    // getters
    public fun get_claimable_lp_tokens(
        distribution: &Distribution,
        provider: address,
    ): u64 {
        if (distribution.phase < PHASE_COMMUNITY_REGISTRATION) {
            return 0
        };
        
        if (!table::contains(&distribution.liquidity_providers, provider) || 
            vec_set::contains(&distribution.claimed_lp, &provider)) {
            return 0
        };

        let sui_contributed = *table::borrow(&distribution.liquidity_providers, provider);
        let total_sui = balance::value(&distribution.sui_balance);
        
        (calculate_share_ratio(sui_contributed, total_sui))
    }

    public fun get_lp_info(
        distribution: &Distribution,
        provider: address,
    ): (u64, u64, bool) {
        let sui_contributed = if (table::contains(&distribution.liquidity_providers, provider)) {
            *table::borrow(&distribution.liquidity_providers, provider)
        } else {
            0
        };

        let claimable = get_claimable_lp_tokens(distribution, provider);
        let has_claimed = vec_set::contains(&distribution.claimed_lp, &provider);

        (sui_contributed, claimable, has_claimed)
    }

    public fun get_distribution_info(
        distribution: &Distribution,
        clock: &Clock
    ): (u8, u64, u64, u64, u64, u64, u64) {
        let lp_time_remaining = if (distribution.phase == PHASE_LIQUIDITY && distribution.liquidity_start != 0) {
            let elapsed = clock::timestamp_ms(clock) - distribution.liquidity_start;
            if (elapsed >= LIQUIDITY_PERIOD) {
                0
            } else {
                LIQUIDITY_PERIOD - elapsed
            }
        } else {
            0
        };

        let claim_time_remaining = if (distribution.phase == PHASE_COMMUNITY_REGISTRATION && distribution.claim_start != 0) {
            let elapsed = clock::timestamp_ms(clock) - distribution.claim_start;
            if (elapsed >= CLAIM_PERIOD) {
                0
            } else {
                CLAIM_PERIOD - elapsed
            }
        } else {
            0
        };

        (
            distribution.phase,
            balance::value(&distribution.sui_balance),
            distribution.lp_remaining,
            distribution.community_remaining,
            distribution.dex_remaining,
            lp_time_remaining,
            claim_time_remaining
        )
    }

    public fun get_claimable_community_tokens(
        distribution: &Distribution,
        claimer: address,
    ): u64 {
        if (distribution.phase != PHASE_DISTRIBUTION) {
            return 0
        };
        
        if (!vec_set::contains(&distribution.registered_claimers, &claimer) || 
            vec_set::contains(&distribution.claimed_community, &claimer)) {
            return 0
        };

        let total_claimers = vec_set::size(&distribution.registered_claimers);
        COMMUNITY_ALLOCATION / total_claimers
    }

    public fun get_total_sui_raised(distribution: &Distribution): u64 {
        balance::value(&distribution.sui_balance)
    }

    public fun get_total_registered_claimers(distribution: &Distribution): u64 {
        vec_set::size(&distribution.registered_claimers)
    }

    public fun get_total_claimed_community(distribution: &Distribution): u64 {
        vec_set::size(&distribution.claimed_community)
    }
    
    public fun get_phase(distribution: &Distribution): u8 {
        distribution.phase
    }

    public fun get_liquidity_period(): u64 {
        LIQUIDITY_PERIOD
    }

    public fun get_claim_period(): u64 {
        CLAIM_PERIOD
    }

    public fun get_max_sui_cap(): u64 {
        MAX_SUI_CAP
    }

    public fun get_phase_community_registration(): u8 {
        PHASE_COMMUNITY_REGISTRATION
    }

    public fun get_phase_completed(): u8 {
        PHASE_COMPLETED
    }

    public fun get_liquidity_start(distribution: &Distribution): u64 {
        distribution.liquidity_start
    }

    public fun get_max_sui_contribution(): u64 {
        MAX_SUI_CONTRIBUTION 
    }

    public fun get_phase_liquidity(): u8 {
        PHASE_LIQUIDITY
    }

    public fun get_community_allocation(): u64 {
        COMMUNITY_ALLOCATION
    }

    public fun get_core_allocation(): u64 {
        CORE_ALLOCATION
    }

    public fun get_community_allocation_lock(): u64 {
        COMMUNITY_ALLOCATION_LOCK
    }
}