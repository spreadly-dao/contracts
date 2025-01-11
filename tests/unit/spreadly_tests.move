#[test_only, allow(unused_const, unused_use)]
module spreadly::spreadly_tests {
    use std::vector;
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
    const TEST_ADDR_1: address = @0x100;
    const TEST_ADDR_2: address = @0x101;
    const TEST_ADDR_3: address = @0x102;
    const TEST_ADDR_4: address = @0x103;
    const TEST_ADDR_5: address = @0x104;
    const TEST_ADDR_6: address = @0x105;
    const TEST_ADDR_7: address = @0x106;
    const TEST_ADDR_8: address = @0x107;
    const TEST_ADDR_9: address = @0x108;
    const TEST_ADDR_10: address = @0x109;
    const TEST_ADDR_11: address = @0x10A;
    const TEST_ADDR_12: address = @0x10B;
    const TEST_ADDR_13: address = @0x10C;
    const TEST_ADDR_14: address = @0x10D;
    const TEST_ADDR_15: address = @0x10E;
    const TEST_ADDR_16: address = @0x10F;

    const MIN_CONTRIBUTION: u64 = 1_000_000_000; // 1 SUI
    const MAX_CONTRIBUTION: u64 = 1_000_000_000_000; // 1,000 SUI
    const TEN_SUI: u64 = 10_000_000_000;

    // Helper to create clock
    fun create_clock(scenario: &mut Scenario): Clock {
        ts::next_tx(scenario, ADMIN);
        clock::create_for_testing(ts::ctx(scenario))
    }

    fun advance_clock(clock: &mut Clock, duration_ms: u64) {
        clock::increment_for_testing(clock, duration_ms);
    }

    #[test_only]
    public fun init_for_testing(ctx: &mut TxContext) {
        // Create one-time witness for testing
        spreadly::test_init(ctx);
    }

    // Helper function to set up test scenario
    fun setup_test(scenario: &mut Scenario, clock: &mut Clock) {
        // Start with admin account and initialize module
        ts::next_tx(scenario, ADMIN);
        {
            init_for_testing(ts::ctx(scenario));
        };

        // Advance clock to start with non-zero time
        advance_clock(clock, 1000);
    }

    // Add a helper function for dynamic account creation and contribution
    fun contribute_until_cap(scenario: &mut Scenario, clock: &Clock, contribution_amount: u64) {
        let addresses = vector[
            TEST_ADDR_1,
            TEST_ADDR_2,
            TEST_ADDR_3,
            TEST_ADDR_4,
            TEST_ADDR_5,
            TEST_ADDR_6,
            TEST_ADDR_7,
            TEST_ADDR_8,
            TEST_ADDR_9,
            TEST_ADDR_10,
            TEST_ADDR_11,
            TEST_ADDR_12,
            TEST_ADDR_13,
            TEST_ADDR_14,
            TEST_ADDR_15,
            TEST_ADDR_16
        ];
        
        let total = 0;
        let max_cap = spreadly::get_max_sui_cap();
        let i = 0;
        
        while (total < max_cap) {
            let amount = if (total + contribution_amount > max_cap) {
                max_cap - total
            } else {
                contribution_amount
            };
            
            assert!(i < vector::length(&addresses), 1); // Ensure we have enough addresses
            let test_address = *vector::borrow(&addresses, i);
            
            ts::next_tx(scenario, test_address);
            {
                let distribution = ts::take_shared<Distribution>(scenario);
                let coin = coin::mint_for_testing<SUI>(amount, ts::ctx(scenario));
                spreadly::provide_liquidity(&mut distribution, coin, clock, ts::ctx(scenario));
                ts::return_shared(distribution);
            };
            
            total = total + amount;
            i = i + 1;
        }
    }

    #[test]
    fun test_init() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock);
        
        // Verify Distribution object was created and shared
        ts::next_tx(&mut scenario, ADMIN);
        {
            assert!(ts::has_most_recent_shared<Distribution>(), 0);
        };
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_start_liquidity_phase() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock);

        // Start liquidity phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let timestamp_before = clock::timestamp_ms(&clock);
            spreadly::start_liquidity_phase(&mut distribution, &clock);
            
            // Verify liquidity_start is set to current timestamp
            assert!(spreadly::get_liquidity_start(&distribution) == timestamp_before, 0);
            
            ts::return_shared(distribution);
        };
        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = spreadly::spreadly::EMINIMUM_CONTRIBUTION)]
    fun test_liquidity_under_minimum() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock);

        // Start liquidity phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_liquidity_phase(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Try to provide less than minimum
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let coin = coin::mint_for_testing<SUI>(MIN_CONTRIBUTION - 1, ts::ctx(&mut scenario));
            spreadly::provide_liquidity(&mut distribution, coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = spreadly::spreadly::EMAX_CONTRIBUTION)]
    fun test_liquidity_over_maximum() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock);

        // Start liquidity phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_liquidity_phase(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Try to provide more than maximum
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let coin = coin::mint_for_testing<SUI>(spreadly::get_max_sui_contribution() + 1, ts::ctx(&mut scenario));
            spreadly::provide_liquidity(&mut distribution, coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_valid_liqudity_provider() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock);

        // Verify initial state
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            assert!(spreadly::get_phase(&distribution) == 0, 0);
            assert!(spreadly::get_liquidity_start(&distribution) == 0, 1);
            ts::return_shared(distribution);
        };

        // Start liquidity phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let timestamp_before = clock::timestamp_ms(&clock);
            spreadly::start_liquidity_phase(&mut distribution, &clock);
            // Verify liquidity_start was set
            assert!(spreadly::get_liquidity_start(&distribution) == timestamp_before, 2);
            ts::return_shared(distribution);
        };

        // Advance clock a bit
        advance_clock(&mut clock, 1000);

        // Provide max liquidity cap
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let coin = coin::mint_for_testing<SUI>(spreadly::get_max_sui_contribution(), ts::ctx(&mut scenario));
            spreadly::provide_liquidity(&mut distribution, coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_liquidity_phase_migration() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock);

        // Start liquidity phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_liquidity_phase(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Have multiple users contribute until we hit the cap
        // Start from address 1000 to avoid conflicts with our test constants
        contribute_until_cap(&mut scenario, &clock, spreadly::get_max_sui_contribution());

        // Verify phase changed after reaching cap
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            assert!(spreadly::get_phase(&distribution) == spreadly::get_phase_community_registration(), 1);
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // #[test]
    // fun test_liquidity_phase_time_expiry() {
    //     let scenario = ts::begin(ADMIN);
    //     setup_test(&mut scenario);
    //     let clock = create_clock(&mut scenario);

    //     // Start liquidity phase
    //     ts::next_tx(&mut scenario, ADMIN);
    //     {
    //         let distribution = ts::take_shared<Distribution>(&scenario);
    //         spreadly::start_liquidity_phase(&mut distribution, &clock);
            
    //         // Add some liquidity but not max
    //         let coin = coin::mint_for_testing<SUI>(TEN_SUI, ts::ctx(&mut scenario));
    //         spreadly::provide_liquidity(&mut distribution, coin, &clock, ts::ctx(&mut scenario));
    //         ts::return_shared(distribution);
    //     };

    //     // Advance time past 7 days
    //     advance_clock(&mut clock, spreadly::get_liquidity_period() + 1);

    //     // End liquidity phase
    //     ts::next_tx(&mut scenario, ADMIN);
    //     {
    //         let distribution = ts::take_shared<Distribution>(&scenario);
    //         spreadly::end_liquidity_period(&mut distribution, &clock);
    //         assert!(spreadly::get_phase(&distribution) == spreadly::get_phase_community_registration(), 0);
    //         ts::return_shared(distribution);
    //     };

    //     clock::destroy_for_testing(clock);
    //     ts::end(scenario);
    // }

    // #[test]
    // fun test_immediate_lp_claim() {
    //     let scenario = ts::begin(ADMIN);
    //     setup_test(&mut scenario);
    //     let clock = create_clock(&mut scenario);

    //     // Setup: Start liquidity and provide tokens
    //     ts::next_tx(&mut scenario, ADMIN);
    //     {
    //         let distribution = ts::take_shared<Distribution>(&scenario);
    //         spreadly::start_liquidity_phase(&mut distribution, &clock);
    //         ts::return_shared(distribution);
    //     };

    //     // TEST_ADDR_1 provides liquidity
    //     ts::next_tx(&mut scenario, TEST_ADDR_1);
    //     {
    //         let distribution = ts::take_shared<Distribution>(&scenario);
    //         let coin = coin::mint_for_testing<SUI>(TEN_SUI, ts::ctx(&mut scenario));
    //         spreadly::provide_liquidity(&mut distribution, coin, &clock, ts::ctx(&mut scenario));
    //         ts::return_shared(distribution);
    //     };

    //     // End liquidity phase
    //     advance_clock(&mut clock, spreadly::get_liquidity_period() + 1);
    //     ts::next_tx(&mut scenario, ADMIN);
    //     {
    //         let distribution = ts::take_shared<Distribution>(&scenario);
    //         spreadly::end_liquidity_period(&mut distribution, &clock);
    //         ts::return_shared(distribution);
    //     };

    //     // TEST_ADDR_1 claims LP tokens immediately
    //     ts::next_tx(&mut scenario, TEST_ADDR_1);
    //     {
    //         let distribution = ts::take_shared<Distribution>(&scenario);
    //         spreadly::claim_lp_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
    //         ts::return_shared(distribution);
    //     };

    //     clock::destroy_for_testing(clock);
    //     ts::end(scenario);
    // }

    // #[test]
    // fun test_community_claim_timing() {
    //     let scenario = ts::begin(ADMIN);
    //     setup_test(&mut scenario);
    //     let clock = create_clock(&mut scenario);

    //     // Setup: Complete liquidity phase
    //     ts::next_tx(&mut scenario, ADMIN);
    //     {
    //         let distribution = ts::take_shared<Distribution>(&scenario);
    //         spreadly::start_liquidity_phase(&mut distribution, &clock);
    //         let coin = coin::mint_for_testing<SUI>(TEN_SUI, ts::ctx(&mut scenario));
    //         spreadly::provide_liquidity(&mut distribution, coin, &clock, ts::ctx(&mut scenario));
    //         advance_clock(&mut clock, spreadly::get_liquidity_period() + 1);
    //         spreadly::end_liquidity_period(&mut distribution, &clock);
    //         ts::return_shared(distribution);
    //     };

    //     // Register for community allocation
    //     ts::next_tx(&mut scenario, USER2);
    //     {
    //         let distribution = ts::take_shared<Distribution>(&scenario);
    //         spreadly::register_for_community(&mut distribution, &clock, ts::ctx(&mut scenario));
    //         ts::return_shared(distribution);
    //     };

    //     // Advance past claim period
    //     advance_clock(&mut clock, spreadly::get_claim_period() + 1);

    //     // Start distribution and claim tokens
    //     ts::next_tx(&mut scenario, ADMIN);
    //     {
    //         let distribution = ts::take_shared<Distribution>(&scenario);
    //         spreadly::start_distribution(&mut distribution, &clock);
    //         ts::return_shared(distribution);
    //     };

    //     ts::next_tx(&mut scenario, USER2);
    //     {
    //         let distribution = ts::take_shared<Distribution>(&scenario);
    //         spreadly::claim_community_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
    //         ts::return_shared(distribution);
    //     };

    //     clock::destroy_for_testing(clock);
    //     ts::end(scenario);
    // }
}