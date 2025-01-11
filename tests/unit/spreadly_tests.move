#[test_only]
module spreadly::spreadly_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin};
    use sui::clock::{Self, Clock};
    use sui::test_utils;
    use sui::sui::SUI;
    use std::string;
    use std::option;
    use sui::tx_context::TxContext;
    
    use spreadly::spreadly::{Self, Distribution, SPREADLY};

    // Test constants
    const ADMIN: address = @0xAD;
    const USER1: address = @0x1;
    const USER2: address = @0x2;
    const USER3: address = @0x3;

    const MIN_CONTRIBUTION: u64 = 1_000_000_000; // 1 SUI
    const MAX_CONTRIBUTION: u64 = 1_000_000_000_000; // 1,000 SUI
    const TEN_SUI: u64 = 10_000_000_000;

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        // Create one-time witness for testing
        spreadly::test_init(ctx);
    }

    // Helper function to set up test scenario
    fun setup_test(scenario: &mut Scenario) {
        // Start with admin account and initialize module
        ts::next_tx(scenario, ADMIN);
        {
            init_for_testing(ts::ctx(scenario));
        };
    }

    // Helper to create clock
    fun create_clock(scenario: &mut Scenario): Clock {
        ts::next_tx(scenario, ADMIN);
        clock::create_for_testing(ts::ctx(scenario))
    }

    fun advance_clock(clock: &mut Clock, duration_ms: u64) {
        clock::increment_for_testing(clock, duration_ms);
    }

    #[test]
    fun test_init() {
        let scenario = ts::begin(ADMIN);
        setup_test(&mut scenario);
        
        // Verify Distribution object was created and shared
        ts::next_tx(&mut scenario, ADMIN);
        {
            assert!(ts::has_most_recent_shared<Distribution>(), 0);
        };
        ts::end(scenario);
    }

    #[test]
    fun test_start_liquidity_phase() {
        let scenario = ts::begin(ADMIN);
        setup_test(&mut scenario);
        let clock = create_clock(&mut scenario);

        // Start liquidity phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_liquidity_phase(&mut distribution, &clock);
            ts::return_shared(distribution);
        };
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_liquidity_phase_max_cap() {
        let scenario = ts::begin(ADMIN);
        setup_test(&mut scenario);
        let clock = create_clock(&mut scenario);

        // Start liquidity phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_liquidity_phase(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Provide max liquidity cap
        ts::next_tx(&mut scenario, USER1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let coin = coin::mint_for_testing<SUI>(spreadly::get_max_sui_cap(), ts::ctx(&mut scenario));
            spreadly::provide_liquidity(&mut distribution, coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Verify phase changed automatically
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            assert!(spreadly::get_phase(&distribution) == spreadly::get_phase_community_registration(), 0);
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_liquidity_phase_time_expiry() {
        let scenario = ts::begin(ADMIN);
        setup_test(&mut scenario);
        let clock = create_clock(&mut scenario);

        // Start liquidity phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_liquidity_phase(&mut distribution, &clock);
            
            // Add some liquidity but not max
            let coin = coin::mint_for_testing<SUI>(TEN_SUI, ts::ctx(&mut scenario));
            spreadly::provide_liquidity(&mut distribution, coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Advance time past 7 days
        advance_clock(&mut clock, spreadly::get_liquidity_period() + 1);

        // End liquidity phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::end_liquidity_period(&mut distribution, &clock);
            assert!(spreadly::get_phase(&distribution) == spreadly::get_phase_community_registration(), 0);
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_immediate_lp_claim() {
        let scenario = ts::begin(ADMIN);
        setup_test(&mut scenario);
        let clock = create_clock(&mut scenario);

        // Setup: Start liquidity and provide tokens
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_liquidity_phase(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // USER1 provides liquidity
        ts::next_tx(&mut scenario, USER1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let coin = coin::mint_for_testing<SUI>(TEN_SUI, ts::ctx(&mut scenario));
            spreadly::provide_liquidity(&mut distribution, coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // End liquidity phase
        advance_clock(&mut clock, spreadly::get_liquidity_period() + 1);
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::end_liquidity_period(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // USER1 claims LP tokens immediately
        ts::next_tx(&mut scenario, USER1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_lp_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_community_claim_timing() {
        let scenario = ts::begin(ADMIN);
        setup_test(&mut scenario);
        let clock = create_clock(&mut scenario);

        // Setup: Complete liquidity phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_liquidity_phase(&mut distribution, &clock);
            let coin = coin::mint_for_testing<SUI>(TEN_SUI, ts::ctx(&mut scenario));
            spreadly::provide_liquidity(&mut distribution, coin, &clock, ts::ctx(&mut scenario));
            advance_clock(&mut clock, spreadly::get_liquidity_period() + 1);
            spreadly::end_liquidity_period(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Register for community allocation
        ts::next_tx(&mut scenario, USER2);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::register_for_community(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Advance past claim period
        advance_clock(&mut clock, spreadly::get_claim_period() + 1);

        // Start distribution and claim tokens
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        ts::next_tx(&mut scenario, USER2);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_community_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
}