#[test_only, allow(unused_const, unused_use)]
module spreadly::spreadly_tests {
    use std::debug;
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::clock::{Self, Clock};
    use sui::test_utils;
    use sui::sui::SUI;
    use std::string;
        
    use cetus_clmm::config::{Self, GlobalConfig, AdminCap};
    use cetus_clmm::factory;
    use cetus_clmm::factory::Pools;

    
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
    const TEST_ADDR_17: address = @0x110;
    const TEST_ADDR_18: address = @0x111;
    const TEST_ADDR_19: address = @0x112;
    const TEST_ADDR_20: address = @0x113;
    const TEST_ADDR_21: address = @0x114;
    const TEST_ADDR_22: address = @0x115;
    const TEST_ADDR_23: address = @0x116;
    const TEST_ADDR_24: address = @0x117;
    const TEST_ADDR_25: address = @0x118;
    const TEST_ADDR_26: address = @0x119;
    const TEST_ADDR_27: address = @0x11A;
    const TEST_ADDR_28: address = @0x11B;
    const TEST_ADDR_29: address = @0x11C;
    const TEST_ADDR_30: address = @0x11D;
    const TEST_ADDR_31: address = @0x11E;
    const TEST_ADDR_32: address = @0x11F;
    const TEST_ADDR_33: address = @0x120;
    const TEST_ADDR_34: address = @0x121;
    const TEST_ADDR_35: address = @0x122;
    const TEST_ADDR_36: address = @0x123;
    const TEST_ADDR_37: address = @0x124;
    const TEST_ADDR_38: address = @0x125;
    const TEST_ADDR_39: address = @0x126;
    const TEST_ADDR_40: address = @0x127;
    const TEST_ADDR_41: address = @0x128;
    const TEST_ADDR_42: address = @0x129;
    const TEST_ADDR_43: address = @0x12A;
    const TEST_ADDR_44: address = @0x12B;
    const TEST_ADDR_45: address = @0x12C;
    const TEST_ADDR_46: address = @0x12D;
    const TEST_ADDR_47: address = @0x12E;
    const TEST_ADDR_48: address = @0x12F;
    const TEST_ADDR_49: address = @0x130;
    const TEST_ADDR_50: address = @0x131;
    const TEST_ADDR_51: address = @0x132;
    const TEST_ADDR_52: address = @0x133;
    const TEST_ADDR_53: address = @0x134;
    const TEST_ADDR_54: address = @0x135;
    const TEST_ADDR_55: address = @0x136;
    const TEST_ADDR_56: address = @0x137;
    const TEST_ADDR_57: address = @0x138;
    const TEST_ADDR_58: address = @0x139;
    const TEST_ADDR_59: address = @0x13A;
    const TEST_ADDR_60: address = @0x13B;

    const MIN_CONTRIBUTION: u64 = 1_000_000_000; // 1 SUI
    const MAX_CONTRIBUTION: u64 = 250_000_000_000; // 1,000 SUI
    const TEN_SUI: u64 = 10_000_000_000;

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

    // #[test_only]
    // fun create_test_pool_dependencies(scenario: &mut Scenario) {
    //     ts::next_tx(scenario, ADMIN);
    //     let ctx = ts::ctx(scenario);
        
    //     // Use their test helpers
    //     let (admin_cap, global_config) = config::new_global_config_for_test(ctx, 10_000);
    //     let pools = factory::new_pools_for_test(ctx);

    //     // Share the objects
    //     transfer::public_transfer(admin_cap, ADMIN);
    //     transfer::public_share_object(global_config);
    //     transfer::public_share_object(pools);
    // }

    // Helper function to set up test scenario
    fun setup_test(scenario: &mut Scenario, clock: &mut Clock) {
        // Start with admin account and initialize module
        
        ts::next_tx(scenario, ADMIN);
        {
            init_for_testing(ts::ctx(scenario));
        };

        // Create and share pool dependencies
        // ts::next_tx(scenario, ADMIN);
        // {
        //     create_test_pool_dependencies(scenario);
        // };

        // Advance clock to start with non-zero time
        advance_clock(clock, 1000);
    }

    fun get_test_addresses(count: u64): vector<address> {
        let mut addresses = vector[
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
            TEST_ADDR_16,
            TEST_ADDR_17,
            TEST_ADDR_18,
            TEST_ADDR_19,
            TEST_ADDR_20,
            TEST_ADDR_21,
            TEST_ADDR_22,
            TEST_ADDR_23,
            TEST_ADDR_24,
            TEST_ADDR_25,
            TEST_ADDR_26,
            TEST_ADDR_27,
            TEST_ADDR_28,
            TEST_ADDR_29,
            TEST_ADDR_30,
            TEST_ADDR_31,
            TEST_ADDR_32,
            TEST_ADDR_33,
            TEST_ADDR_34,
            TEST_ADDR_35,
            TEST_ADDR_36,
            TEST_ADDR_37,
            TEST_ADDR_38,
            TEST_ADDR_39,
            TEST_ADDR_40,
            TEST_ADDR_41,
            TEST_ADDR_42,
            TEST_ADDR_43,
            TEST_ADDR_44,
            TEST_ADDR_45,
            TEST_ADDR_46,
            TEST_ADDR_47,
            TEST_ADDR_48,
            TEST_ADDR_49,
            TEST_ADDR_50,
            TEST_ADDR_51,
            TEST_ADDR_52,
            TEST_ADDR_53,
            TEST_ADDR_54,
            TEST_ADDR_55,
            TEST_ADDR_56,
            TEST_ADDR_57,
            TEST_ADDR_58,
            TEST_ADDR_59,
            TEST_ADDR_60
        ];
        while (vector::length(&addresses) > count) {
            vector::pop_back(&mut addresses);
        };
        addresses
    }
    #[test]
    fun test_core_team_allocation() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
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
    fun contribute_until_cap(
        scenario: &mut Scenario, 
        // config: &GlobalConfig,
        // pools: &mut Pools,
        // sprd_metadata: &CoinMetadata<SPREADLY>,
        // sui_metadata: &CoinMetadata<SUI>,
        clock: &Clock, 
        contribution_amount: u64
    ) {
        let addresses = get_test_addresses(60);
        
        let mut total = 0;
        let max_cap = spreadly::get_max_sui_cap();
        let mut i = 0;
        
        while (total < max_cap) {
            let amount = if (total + contribution_amount > max_cap) {
                max_cap - total
            } else {
                contribution_amount
            };
            
            assert!(i < vector::length(&addresses), 1);
            let test_address = *vector::borrow(&addresses, i);
            
            ts::next_tx(scenario, test_address);
            {
                let mut distribution = ts::take_shared<Distribution>(scenario);
                let mut coin = coin::mint_for_testing<SUI>(amount + (spreadly::get_community_allocation_lock() * 2), ts::ctx(scenario));
                let registration_coin = coin::split(&mut coin, spreadly::get_community_allocation_lock(), ts::ctx(scenario));
                let secondary_registration = coin::split(&mut coin, spreadly::get_community_allocation_lock(), ts::ctx(scenario));
                transfer::public_transfer(registration_coin, test_address);
                transfer::public_transfer(secondary_registration, test_address);
                
                spreadly::test_provide_liquidity(
                    &mut distribution, 
                    coin,
                    clock, 
                    ts::ctx(scenario)
                );
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
            let mut distribution = ts::take_shared<Distribution>(scenario);
            spreadly::start_liquidity_phase(&mut distribution, clock);
            ts::return_shared(distribution);
        };

        // let global_config = ts::take_shared<GlobalConfig>(scenario);
        // let mut pools = ts::take_shared<Pools>(scenario);
        // let sprd_metadata = ts::take_immutable<CoinMetadata<SPREADLY>>(scenario);
        // let sui_metadata = ts::take_shared<CoinMetadata<SUI>>(scenario);

        // Fill up to max cap using multiple contributors
        contribute_until_cap(
            scenario, 
            // &global_config,
            // &mut pools,
            // &sprd_metadata,
            // &sui_metadata,
            clock, 
            MAX_CONTRIBUTION
        );

        // ts::return_shared(global_config);
        // ts::return_shared(pools);
        // ts::return_shared(sprd_metadata);
        // ts::return_shared(sui_metadata);
    }

    #[test]
    fun test_init() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
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
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock);

        // Start liquidity phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
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
    #[expected_failure(abort_code = ::spreadly::spreadly::EMINIMUM_CONTRIBUTION)]
    fun test_liquidity_under_minimum() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock);

        // Start liquidity phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_liquidity_phase(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Try to provide less than minimum
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            // let global_config = ts::take_shared<GlobalConfig>(&scenario);
            // let mut pools = ts::take_shared<Pools>(&scenario);
            // let sprd_metadata = ts::take_immutable<CoinMetadata<SPREADLY>>(&scenario);
            // let sui_metadata = ts::take_immutable<CoinMetadata<SUI>>(&scenario);
            let coin = coin::mint_for_testing<SUI>(MIN_CONTRIBUTION - 1, ts::ctx(&mut scenario));
            spreadly::test_provide_liquidity(
                &mut distribution,
                coin,
                &clock,
                ts::ctx(&mut scenario)
            );
            ts::return_shared(distribution);
            // ts::return_shared(global_config);
            // ts::return_shared(pools);
            // ts::return_shared(sprd_metadata);
            // ts::return_shared(sui_metadata);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ::spreadly::spreadly::EMAX_CONTRIBUTION)]
    fun test_liquidity_over_maximum() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock);

        // Start liquidity phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_liquidity_phase(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Try to provide more than maximum
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            // let global_config = ts::take_shared<GlobalConfig>(&scenario);
            // let mut pools = ts::take_shared<Pools>(&scenario);
            // let sprd_metadata = ts::take_immutable<CoinMetadata<SPREADLY>>(&scenario);
            // let sui_metadata = ts::take_immutable<CoinMetadata<SUI>>(&scenario);

            let coin = coin::mint_for_testing<SUI>(spreadly::get_max_sui_contribution() + 1, ts::ctx(&mut scenario));
            
            spreadly::test_provide_liquidity(
                &mut distribution,
                coin,
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(distribution);
            // ts::return_shared(global_config);
            // ts::return_shared(pools);
            // ts::return_shared(sprd_metadata);
            // ts::return_shared(sui_metadata);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_valid_liqudity_provider() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
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
            let mut distribution = ts::take_shared<Distribution>(&scenario);
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
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            // let global_config = ts::take_shared<GlobalConfig>(&scenario);
            // let mut pools = ts::take_shared<Pools>(&scenario);
            // let sprd_metadata = ts::take_immutable<CoinMetadata<SPREADLY>>(&scenario);
            // let sui_metadata = ts::take_immutable<CoinMetadata<SUI>>(&scenario);
            let coin = coin::mint_for_testing<SUI>(spreadly::get_max_sui_contribution(), ts::ctx(&mut scenario));
            spreadly::test_provide_liquidity(
                &mut distribution,
                coin,
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(distribution);
            // ts::return_shared(global_config);
            // ts::return_shared(pools);
            // ts::return_shared(sprd_metadata);
            // ts::return_shared(sui_metadata);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_liquidity_phase_migration() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock);

        // Start liquidity phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
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
    #[expected_failure(abort_code = ::spreadly::spreadly::ESTILL_IN_LIQUIDITY)]
    fun test_claim_during_liquidity_phase() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock);

        // Start liquidity phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_liquidity_phase(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Provide liquidity
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            // let global_config = ts::take_shared<GlobalConfig>(&scenario);
            // let mut pools = ts::take_shared<Pools>(&scenario);
            // let sprd_metadata = ts::take_immutable<CoinMetadata<SPREADLY>>(&scenario);
            // let sui_metadata = ts::take_immutable<CoinMetadata<SUI>>(&scenario);
            let coin = coin::mint_for_testing<SUI>(TEN_SUI, ts::ctx(&mut scenario));
            spreadly::test_provide_liquidity(
                &mut distribution,
                coin,
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(distribution);
            // ts::return_shared(global_config);
            // ts::return_shared(pools);
            // ts::return_shared(sprd_metadata);
            // ts::return_shared(sui_metadata);
        };

        // Try to claim during liquidity phase (should fail)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_lp_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
 
    #[test]
    fun test_lp_claim_single_provider() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
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
            let mut distribution = ts::take_shared<Distribution>(&scenario);
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
    #[expected_failure(abort_code = ::spreadly::spreadly::ENOT_LP)]
    fun test_claim_by_non_lp() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Address that didn't provide liquidity tries to claim
        ts::next_tx(&mut scenario, @0x999);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_lp_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ::spreadly::spreadly::EALREADY_CLAIMED)]
    fun test_double_claim() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // First claim (should succeed)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_lp_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Second claim (should fail)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_lp_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

        #[test]
    fun test_sequential_lp_claims() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Get all expected claimable amounts first
        let addresses = get_test_addresses(8); // Test with 8 LPs
        let mut expected_amounts = vector::empty();
        let mut i = 0;
        
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
                let mut distribution = ts::take_shared<Distribution>(&scenario);
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
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
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
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_liquidity_phase(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        let contribution1 = MIN_CONTRIBUTION * 2; // 2 SUI
        let contribution2 = MIN_CONTRIBUTION * 3; // 3 SUI
        let contribution3 = MIN_CONTRIBUTION * 5; // 5 SUI

        // First contribution
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            // let global_config = ts::take_shared<GlobalConfig>(&scenario);
            // let mut pools = ts::take_shared<Pools>(&scenario);
            // let sprd_metadata = ts::take_immutable<CoinMetadata<SPREADLY>>(&scenario);
            // let sui_metadata = ts::take_immutable<CoinMetadata<SUI>>(&scenario);
            let coin = coin::mint_for_testing<SUI>(contribution1, ts::ctx(&mut scenario));
            spreadly::test_provide_liquidity(
                &mut distribution,
                coin,
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(distribution);
            // ts::return_shared(global_config);
            // ts::return_shared(pools);
            // ts::return_shared(sprd_metadata);
            // ts::return_shared(sui_metadata);
        };

        // Advance clock
        advance_clock(&mut clock, 100_000);

        // Second contribution
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            // let global_config = ts::take_shared<GlobalConfig>(&scenario);
            // let mut pools = ts::take_shared<Pools>(&scenario);
            // let sprd_metadata = ts::take_immutable<CoinMetadata<SPREADLY>>(&scenario);
            // let sui_metadata = ts::take_immutable<CoinMetadata<SUI>>(&scenario);
            let coin = coin::mint_for_testing<SUI>(contribution2, ts::ctx(&mut scenario));
            spreadly::test_provide_liquidity(
                &mut distribution,
                coin,
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(distribution);
            // ts::return_shared(global_config);
            // ts::return_shared(pools);
            // ts::return_shared(sprd_metadata);
            // ts::return_shared(sui_metadata);
        };

        // Advance clock again
        advance_clock(&mut clock, 200_000);

        // Third contribution
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            // let global_config = ts::take_shared<GlobalConfig>(&scenario);
            // let mut pools = ts::take_shared<Pools>(&scenario);
            // let sprd_metadata = ts::take_immutable<CoinMetadata<SPREADLY>>(&scenario);
            // let sui_metadata = ts::take_immutable<CoinMetadata<SUI>>(&scenario);
            let coin = coin::mint_for_testing<SUI>(contribution3, ts::ctx(&mut scenario));
            spreadly::test_provide_liquidity(
                &mut distribution,
                coin,
                &clock,
                ts::ctx(&mut scenario)
            );

            ts::return_shared(distribution);
            // ts::return_shared(global_config);
            // ts::return_shared(pools);
            // ts::return_shared(sprd_metadata);
            // ts::return_shared(sui_metadata);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    fun test_community_claim_registration() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Try to register with TEST_ADDR_1
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
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
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register single claimer using pre-allocated SUI
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Advance clock past claim period
        advance_clock(&mut clock, spreadly::get_claim_period() + 1000);

        // Start distribution phase
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Claim tokens
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
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
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        let addresses = get_test_addresses(5); // Get 5 test addresses
        let mut i = 0;
        while (i < 5) {
            let addr = *vector::borrow(&addresses, i);
            ts::next_tx(&mut scenario, addr);
            {
                let mut distribution = ts::take_shared<Distribution>(&scenario);
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
    #[expected_failure(abort_code = ::spreadly::spreadly::EINCORRECT_DEPOSIT)]
    fun test_incorrect_deposit_amount() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Try to register with incorrect deposit amount
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            let mut registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
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
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register multiple claimers
        let addresses = get_test_addresses(5); // Get 5 test addresses
        let mut i = 0;
        while (i < 5) {
            let addr = *vector::borrow(&addresses, i);
            ts::next_tx(&mut scenario, addr);
            {
                let mut distribution = ts::take_shared<Distribution>(&scenario);
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
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Have each user claim and verify amount
        i = 0;
        while (i < 5) {
            let addr = *vector::borrow(&addresses, i);
            let mut expected_amount;
            
            // Claim tokens
            ts::next_tx(&mut scenario, addr);
            {
                let mut distribution = ts::take_shared<Distribution>(&scenario);
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
    #[expected_failure(abort_code = ::spreadly::spreadly::EZERO_CLAIMERS)]
    fun test_start_distribution_zero_registrations() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Advance clock past claim period without any registrations
        advance_clock(&mut clock, spreadly::get_claim_period() + 1000);

        // Try to start distribution with no registrations (should fail)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ::spreadly::spreadly::EPERIOD_NOT_COMPLETE)]
    fun test_start_distribution_before_period_ends() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register some users
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Try to start distribution immediately (should fail)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ::spreadly::spreadly::EALREADY_CLAIMED)]
    fun test_double_community_claim() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register multiple users so phase doesn't complete after first claim
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Register second user
        ts::next_tx(&mut scenario, TEST_ADDR_2);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_2);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Advance clock and start distribution
        advance_clock(&mut clock, spreadly::get_claim_period() + 1000);
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // First claim (should succeed)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_community_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Second claim (should fail with EALREADY_CLAIMED)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_community_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ::spreadly::spreadly::ENOT_REGISTERED)]
    fun test_claim_by_unregistered() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register first user
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Advance clock and start distribution
        advance_clock(&mut clock, spreadly::get_claim_period() + 1000);
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Try to claim with unregistered address
        ts::next_tx(&mut scenario, TEST_ADDR_2);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_community_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ::spreadly::spreadly::EWRONG_PHASE)]
    fun test_claim_before_distribution() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register user
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Try to claim before distribution phase starts
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::claim_community_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ::spreadly::spreadly::EALREADY_REGISTERED)]
    fun test_double_registration() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // First registration (should succeed)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Second registration (should fail)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = ::spreadly::spreadly::EWRONG_PHASE)]
    fun test_registration_wrong_phase() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock); // Only sets up, doesn't start liquidity

        // Try to register during initial phase (before liquidity)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
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
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        // This function already sets up the distribution object and puts it in shared storage
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register first user for community (who is also an LP)
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_1);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Register second user for community
        ts::next_tx(&mut scenario, TEST_ADDR_2);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            let registration_coin = ts::take_from_address<Coin<SUI>>(&scenario, TEST_ADDR_2);
            spreadly::register_for_community(&mut distribution, registration_coin, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Get expected LP amount and claim LP tokens
        let expected_lp;
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            expected_lp = spreadly::get_claimable_lp_tokens(&distribution, TEST_ADDR_1);
            spreadly::claim_lp_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Start distribution phase
        advance_clock(&mut clock, spreadly::get_claim_period() + 1000);
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Get expected community amount and claim community tokens
        let expected_community;
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            expected_community = spreadly::get_claimable_community_tokens(&distribution, TEST_ADDR_1);
            spreadly::claim_community_tokens(&mut distribution, &clock, ts::ctx(&mut scenario));
            ts::return_shared(distribution);
        };

        // Verify final amounts
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut lp_coin = ts::take_from_address<Coin<SPREADLY>>(&scenario, TEST_ADDR_1);
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
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_and_fill_liquidity(&mut scenario, &mut clock);

        // Register multiple claimers
        let addresses = get_test_addresses(3);
        let mut i = 0;
        while (i < vector::length(&addresses)) {
            let addr = *vector::borrow(&addresses, i);
            ts::next_tx(&mut scenario, addr);
            {
                let mut distribution = ts::take_shared<Distribution>(&scenario);
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
            let mut distribution = ts::take_shared<Distribution>(&scenario);
            spreadly::start_distribution(&mut distribution, &clock);
            ts::return_shared(distribution);
        };

        // Have all users claim
        i = 0;
        while (i < vector::length(&addresses)) {
            let addr = *vector::borrow(&addresses, i);
            ts::next_tx(&mut scenario, addr);
            {
                let mut distribution = ts::take_shared<Distribution>(&scenario);
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