#[test_only, allow(unused_const, unused_use)]
module spreadly::spreadly_tests {
    use std::vector;
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::transfer;
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

    fun get_test_addresses(count: u64): vector<address> {
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
        while (vector::length(&addresses) > count) {
            vector::pop_back(&mut addresses);
        };
        addresses
    }
    #[test]
    fun test_core_team_allocation() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock);
        
        // Check that deployer (ADMIN) received their allocation
        ts::next_tx(&mut scenario, ADMIN);
        {
            let coin = ts::take_from_address<Coin<SPREADLY>>(&scenario, ADMIN);
            
            let expected_amount = spreadly::get_core_allocation();
            
            // Verify the amount matches expected allocation
            assert!(coin::value(&coin) == expected_amount, 0);
            
            ts::return_to_address(ADMIN, coin);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // Add a helper function for dynamic account creation and contribution
    fun contribute_until_cap(scenario: &mut Scenario, clock: &Clock, contribution_amount: u64) {
        let addresses = get_test_addresses(16);
        
        let total = 0;
        let max_cap = spreadly::get_max_sui_cap();
        let i = 0;
        
        while (total < max_cap) {
            let amount = if (total + contribution_amount > max_cap) {
                max_cap - total
            } else {
                contribution_amount
            };
            
            assert!(i < vector::length(&addresses), 1);
            let test_address = *vector::borrow(&addresses, i);
            
            // Give extra SUI for community registration
            ts::next_tx(scenario, test_address);
            {
                let distribution = ts::take_shared<Distribution>(scenario);
                // Mint 11 SUI (1 extra for community registration)
                let coin = coin::mint_for_testing<SUI>(amount + (spreadly::get_community_allocation_lock() * 2), ts::ctx(scenario));
                // Split off the community registration amount
                let registration_coin = coin::split(&mut coin, spreadly::get_community_allocation_lock(), ts::ctx(scenario));
                let secondary_registration = coin::split(&mut coin, spreadly::get_community_allocation_lock(), ts::ctx(scenario));
                // Save it in test scenario for later
                transfer::public_transfer(registration_coin, test_address);
                transfer::public_transfer(secondary_registration, test_address);
                // Use remaining amount for liquidity
                spreadly::provide_liquidity(&mut distribution, coin, clock, ts::ctx(scenario));
                ts::return_shared(distribution);
            };
            
            total = total + amount;
            i = i + 1;
        }
    }

    // Helper to setup distribution and move to community registration phase
    fun setup_and_fill_liquidity(scenario: &mut Scenario, clock: &mut Clock) {
        setup_test(scenario, clock);

        // Start liquidity phase
        ts::next_tx(scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(scenario);
            spreadly::start_liquidity_phase(&mut distribution, clock);
            ts::return_shared(distribution);
        };

        // Fill up to max cap using multiple contributors
        contribute_until_cap(scenario, clock, MAX_CONTRIBUTION);
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

        setup_and_fill_liquidity(&mut scenario, &mut clock);

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

    #[test]
    #[expected_failure(abort_code = spreadly::spreadly::ESTILL_IN_LIQUIDITY)]
    fun test_claim_during_liquidity_phase() {
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

        // Provide liquidity
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let coin = coin::mint_for_testing<SUI>(TEN_SUI, ts::ctx(&mut scenario));
            spreadly::provide_liquidity(&mut distribution, coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Try to claim during liquidity phase (should fail)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_lp_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_lp_claim_single_provider() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Check expected claimable amount
        let expected_amount;
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            expected_amount = spreadly::get_claimable_lp_tokens(&distribution, TEST_ADDR_1);
            assert!(expected_amount > 0, 0);
            ts::return_shared(distribution);
        };

        // First LP claims their tokens
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_lp_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Verify they received the expected amount
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let coin = ts::take_from_address<Coin<SPREADLY>>(&scenario, TEST_ADDR_1);
            assert!(coin::value(&coin) == expected_amount, 0);
            ts::return_to_address(TEST_ADDR_1, coin);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = spreadly::spreadly::ENOT_LP)]
    fun test_claim_by_non_lp() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Address that didn't provide liquidity tries to claim
        ts::next_tx(&mut scenario, @0x999);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_lp_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = spreadly::spreadly::EALREADY_CLAIMED)]
    fun test_double_claim() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // First claim (should succeed)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_lp_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Second claim (should fail)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_lp_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

        #[test]
    fun test_sequential_lp_claims() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Get all expected claimable amounts first
        let addresses = get_test_addresses(8); // Test with 8 LPs
        let expected_amounts = vector::empty();
        let i = 0;
        
        while (i < vector::length(&addresses)) {
            let addr = *vector::borrow(&addresses, i);
            ts::next_tx(&mut scenario, addr);
            {
                let distribution = ts::take_shared<Distribution>(&scenario);
                let expected = spreadly::get_claimable_lp_tokens(&distribution, addr);
                assert!(expected > 0, 0); // Ensure each LP has tokens to claim
                vector::push_back(&mut expected_amounts, expected);
                ts::return_shared(distribution);
            };
            i = i + 1;
        };

        // Now have each LP claim and verify
        i = 0;
        while (i < vector::length(&addresses)) {
            let addr = *vector::borrow(&addresses, i);
            let expected = *vector::borrow(&expected_amounts, i);

            // Claim tokens
            ts::next_tx(&mut scenario, addr);
            {
                let distribution = ts::take_shared<Distribution>(&scenario);
                spreadly::claim_lp_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
                ts::return_shared(distribution);
            };

            // Verify claimed amount
            ts::next_tx(&mut scenario, addr);
            {
                let coin = ts::take_from_address<Coin<SPREADLY>>(&scenario, addr);
                assert!(coin::value(&coin) == expected, 0);
                ts::return_to_address(addr, coin);
            };
            
            i = i + 1;
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_multi_contribution_provider() {
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
            spreadly::start_liquidity_phase(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        let contribution1 = MIN_CONTRIBUTION * 2; // 2 SUI
        let contribution2 = MIN_CONTRIBUTION * 3; // 3 SUI
        let contribution3 = MIN_CONTRIBUTION * 5; // 5 SUI

        // First contribution
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let coin = coin::mint_for_testing<SUI>(contribution1, ts::ctx(&mut scenario));
            spreadly::provide_liquidity(&mut distribution, coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Advance clock
        advance_clock(&mut clock, 100_000);

        // Second contribution
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let coin = coin::mint_for_testing<SUI>(contribution2, ts::ctx(&mut scenario));
            spreadly::provide_liquidity(&mut distribution, coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Advance clock again
        advance_clock(&mut clock, 200_000);

        // Third contribution
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let coin = coin::mint_for_testing<SUI>(contribution3, ts::ctx(&mut scenario));
            spreadly::provide_liquidity(&mut distribution, coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_community_claim_registration() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Try to register with TEST_ADDR_1
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            // Use the pre-allocated SUI from contribute_until_cap
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_single_community_claimer_amount() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register single claimer using pre-allocated SUI
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Advance clock past claim period
        advance_clock(&mut clock, spreadly::get_claim_period() + 1000);

        // Start distribution phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Claim tokens
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_community_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Verify received amount equals full community allocation (since single claimer)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            // Check SPRD tokens
            let sprd_coin = ts::take_from_address<Coin<SPREADLY>>(&scenario, TEST_ADDR_1);
            assert!(coin::value(&sprd_coin) == spreadly::get_community_allocation(), 0);
            ts::return_to_address(TEST_ADDR_1, sprd_coin);

            // Check returned SUI deposit
            let sui_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            assert!(coin::value(&sui_coin) == spreadly::get_community_allocation_lock(), 1);
            ts::return_to_address(TEST_ADDR_1, sui_coin);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_multi_community_claim_registration() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        let addresses = get_test_addresses(5); // Get 5 test addresses
        let i = 0;
        while (i < 5) {
            let addr = *vector::borrow(&addresses, i);
            ts::next_tx(&mut scenario, addr);
            {
                let distribution = ts::take_shared<Distribution>(&scenario);
                let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, addr);
                spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
                ts::return_shared(distribution);
            };
            i = i + 1;
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = spreadly::spreadly::EINCORRECT_DEPOSIT)]
    fun test_incorrect_deposit_amount() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Try to register with incorrect deposit amount
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            // Split to create an incorrect amount
            let incorrect_coin = coin::split(&mut registration_coin, spreadly::get_community_allocation_lock() / 2, ts::ctx(&mut scenario));
            spreadly::register_for_community(&mut distribution, incorrect_coin, &clock, ts::ctx(&mut scenario));
            
            // Return the remaining coin to clean up
            ts::return_to_address(TEST_ADDR_1, registration_coin);
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_multi_community_claimer_amount() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register multiple claimers
        let addresses = get_test_addresses(5); // Get 5 test addresses
        let i = 0;
        while (i < 5) {
            let addr = *vector::borrow(&addresses, i);
            ts::next_tx(&mut scenario, addr);
            {
                let distribution = ts::take_shared<Distribution>(&scenario);
                let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, addr);
                spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
                ts::return_shared(distribution);
            };
            i = i + 1;
        };

        // Advance clock past claim period
        advance_clock(&mut clock, spreadly::get_claim_period() + 1000);

        // Start distribution phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Have each user claim and verify amount
        i = 0;
        while (i < 5) {
            let addr = *vector::borrow(&addresses, i);
            let expected_amount;
            
            // Claim tokens
            ts::next_tx(&mut scenario, addr);
            {
                let distribution = ts::take_shared<Distribution>(&scenario);
                expected_amount = spreadly::get_claimable_community_tokens(&distribution, addr);
                spreadly::claim_community_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
                ts::return_shared(distribution);
            };

            // Verify claimed amounts (both SPRD and returned SUI)
            ts::next_tx(&mut scenario, addr);
            {
                // Check SPRD tokens
                let sprd_coin = ts::take_from_address<Coin<SPREADLY>>(&scenario, addr);
                assert!(coin::value(&sprd_coin) == expected_amount, 0);
                ts::return_to_address(addr, sprd_coin);

                // Check returned SUI deposit
                let sui_coin = ts::take_from_address<Coin<SUI>>(&scenario, addr);
                assert!(coin::value(&sui_coin) == spreadly::get_community_allocation_lock(), 1);
                ts::return_to_address(addr, sui_coin);
            };

            i = i + 1;
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = spreadly::spreadly::EZERO_CLAIMERS)]
    fun test_start_distribution_zero_registrations() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Advance clock past claim period without any registrations
        advance_clock(&mut clock, spreadly::get_claim_period() + 1000);

        // Try to start distribution with no registrations (should fail)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = spreadly::spreadly::EPERIOD_NOT_COMPLETE)]
    fun test_start_distribution_before_period_ends() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register some users
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Try to start distribution immediately (should fail)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = spreadly::spreadly::EALREADY_CLAIMED)]
    fun test_double_community_claim() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register multiple users so phase doesn't complete after first claim
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Register second user
        ts::next_tx(&mut scenario, TEST_ADDR_2);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_2);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Advance clock and start distribution
        advance_clock(&mut clock, spreadly::get_claim_period() + 1000);
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // First claim (should succeed)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_community_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Second claim (should fail with EALREADY_CLAIMED)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_community_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = spreadly::spreadly::ENOT_REGISTERED)]
    fun test_claim_by_unregistered() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register first user
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Advance clock and start distribution
        advance_clock(&mut clock, spreadly::get_claim_period() + 1000);
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Try to claim with unregistered address
        ts::next_tx(&mut scenario, TEST_ADDR_2);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_community_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = spreadly::spreadly::EWRONG_PHASE)]
    fun test_claim_before_distribution() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register user
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Try to claim before distribution phase starts
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_community_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = spreadly::spreadly::EALREADY_REGISTERED)]
    fun test_double_registration() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // First registration (should succeed)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Second registration (should fail)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = spreadly::spreadly::EWRONG_PHASE)]
    fun test_registration_wrong_phase() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock); // Only sets up, doesn't start liquidity

        // Try to register during initial phase (before liquidity)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = coin::mint_for_testing<SUI>(
                spreadly::get_community_allocation_lock(), 
                ts::ctx(&mut scenario)
            );
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_lp_and_community_claim_interaction() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        // This function already sets up the distribution object and puts it in shared storage
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register first user for community (who is also an LP)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Register second user for community
        ts::next_tx(&mut scenario, TEST_ADDR_2);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_2);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Get expected LP amount and claim LP tokens
        let expected_lp;
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            expected_lp = spreadly::get_claimable_lp_tokens(&distribution, TEST_ADDR_1);
            spreadly::claim_lp_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Start distribution phase
        advance_clock(&mut clock, spreadly::get_claim_period() + 1000);
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Get expected community amount and claim community tokens
        let expected_community;
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            expected_community = spreadly::get_claimable_community_tokens(&distribution, TEST_ADDR_1);
            spreadly::claim_community_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Verify final amounts
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let lp_coin = ts::take_from_address<Coin<SPREADLY>>(&scenario, TEST_ADDR_1);
            let community_coin = ts::take_from_address<Coin<SPREADLY>>(&scenario, TEST_ADDR_1);
            coin::join(&mut lp_coin, community_coin); // Merge the coins
            assert!(coin::value(&lp_coin) == expected_lp + expected_community, 0);
            ts::return_to_address(TEST_ADDR_1, lp_coin);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_completion_state() {
        let scenario = ts::begin(ADMIN);
        let clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register multiple claimers
        let addresses = get_test_addresses(3);
        let i = 0;
        while (i < vector::length(&addresses)) {
            let addr = *vector::borrow(&addresses, i);
            ts::next_tx(&mut scenario, addr);
            {
                let distribution = ts::take_shared<Distribution>(&scenario);
                let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, addr);
                spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
                ts::return_shared(distribution);
            };
            i = i + 1;
        };

        // Start distribution
        advance_clock(&mut clock, spreadly::get_claim_period() + 1000);
        ts::next_tx(&mut scenario, ADMIN);
        {
            let distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Have all users claim
        i = 0;
        while (i < vector::length(&addresses)) {
            let addr = *vector::borrow(&addresses, i);
            ts::next_tx(&mut scenario, addr);
            {
                let distribution = ts::take_shared<Distribution>(&scenario);
                spreadly::claim_community_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
                
                // After last claim, verify final state
                if (i == vector::length(&addresses) - 1) {
                    assert!(spreadly::get_phase(&distribution) == spreadly::get_phase_completed(), 0);
                    // Could add more completion state verifications here
                };
                ts::return_shared(distribution);
            };
            i = i + 1;
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
}