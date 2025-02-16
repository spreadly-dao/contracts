#[test_only]
module spreadly::revenue_pool_tests {
    // use std::debug;

    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self};
    use sui::clock::{Self, Clock};
    use sui::sui::SUI;
    
    use spreadly::spreadly::{SPREADLY};
    use spreadly::revenue_pool::{Self, RevenuePool};
    use spreadly::staking::{Self};
    use spreadly::stake_position::{StakePosition};
    use spreadly::staking_pool::{Self, StakingPool};

    // Test constants
    const ADMIN: address = @0xAD;
    const TEST_ADDR_1: address = @0x100;
    const TEST_ADDR_2: address = @0x101;
    const TEST_ADDR_3: address = @0x102;
    
    // Time constants (in milliseconds)
    const DAY_IN_MS: u64 = 24 * 60 * 60 * 1000;
    const THIRTY_DAYS_MS: u64 = 30 * DAY_IN_MS;

    // Helper to create clock
    fun create_clock(scenario: &mut Scenario): Clock {
        ts::next_tx(scenario, ADMIN);
        clock::create_for_testing(ts::ctx(scenario))
    }

    fun advance_clock(clock: &mut Clock, duration_ms: u64) {
        clock::increment_for_testing(clock, duration_ms);
    }

    // Helper function to set up test scenario
    fun setup_test(scenario: &mut Scenario, clock: &mut Clock) {
        // Initialize the revenue pool
        ts::next_tx(scenario, ADMIN);
        {
            revenue_pool::test_init(ts::ctx(scenario));
        };

        // Initialize the staking pool (assuming it's needed for tests)
        ts::next_tx(scenario, ADMIN);
        {
            staking_pool::test_init(ts::ctx(scenario));
        };

        // Advance clock to start with non-zero time
        advance_clock(clock, 1000);
    }

        // Helper function to create stake position
    fun create_stake_position(scenario: &mut Scenario, addr: address, amount: u64) {
        let clock = create_clock(scenario);
        ts::next_tx(scenario, addr);
        {
            let mut staking_pool = ts::take_shared<StakingPool>(scenario);
            let stake_coins = coin::mint_for_testing<SPREADLY>(amount, ts::ctx(scenario));
            let position = staking::create_stake(
                &mut staking_pool,
                stake_coins, 
                &clock, 
                ts::ctx(scenario)
            );                        
            transfer::public_transfer(position, addr);
            ts::return_shared(staking_pool);
            clock::destroy_for_testing(clock);

        }
    }

    // Helper function to verify claim amount
    fun verify_claim(scenario: &mut Scenario, addr: address, expected_amount: u64, clock: &Clock) {
        ts::next_tx(scenario, addr);
        {
            let mut pool = ts::take_shared<RevenuePool>(scenario);
            let mut position = ts::take_from_sender<StakePosition>(scenario);

            let claimed = revenue_pool::claim_revenue<SUI>(
                &mut pool,
                &mut position,
                clock,
                ts::ctx(scenario)
            );

            assert!(coin::value(&claimed) == expected_amount, 0);

            
            transfer::public_transfer(position, addr);
            transfer::public_transfer( claimed, addr);
            ts::return_shared(pool);
        }
    }

    // Test basic initialization
    #[test]
    fun test_init() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            // Verify RevenuePool was created and shared
            assert!(ts::has_most_recent_shared<RevenuePool>(), 0);
            
            let pool = ts::take_shared<RevenuePool>(&scenario);
            // Verify initial state
            assert!(revenue_pool::get_current_segment_ts(&pool) == 0, 1);
            ts::return_shared(pool);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // Test revenue deposits and claims
    #[test]
    fun test_deposit_and_claim() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock);

        // Now set up the staking position that will receive revenue
        create_stake_position(&mut scenario, TEST_ADDR_1, 10000);

        // Now we can deposit revenue, knowing the type is properly registered
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pool = ts::take_shared<RevenuePool>(&scenario);
            let staking_pool = ts::take_shared<StakingPool>(&scenario);
            
            let revenue = coin::mint_for_testing<SUI>(1000, ts::ctx(&mut scenario));
            // This will now succeed because we registered the type earlier
            revenue_pool::deposit_revenue(
                &mut pool,
                &staking_pool,
                revenue,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_shared(pool);
            ts::return_shared(staking_pool);
        };
        // Advance clock past epoch duration
        advance_clock(&mut clock, THIRTY_DAYS_MS + 1);

        // Claim revenue
        ts::next_tx(&mut scenario, TEST_ADDR_1);
        {
            let mut pool = ts::take_shared<RevenuePool>(&scenario);
            let mut position = ts::take_from_sender<StakePosition>(&scenario);

            let claimed = revenue_pool::claim_revenue<SUI>(
                &mut pool,
                &mut position,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            // Verify claimed amount
            assert!(coin::value(&claimed) > 0, 0);
            
            // Clean up
            transfer::public_transfer(claimed, TEST_ADDR_1);

            ts::return_shared(pool);
            ts::return_to_sender(&scenario, position);
        };

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }

    // Test multiple stakers revenue distribution
    #[test]
    fun test_multi_staker_distribution() {
        let mut scenario = ts::begin(ADMIN);
        let mut clock = create_clock(&mut scenario);
        setup_test(&mut scenario, &mut clock);

        // Setup three staking positions with different amounts
        let staker1_amount = 100_000;
        let staker2_amount = 200_000;
        let staker3_amount = 300_000;
        
        // Create positions
        create_stake_position(&mut scenario, TEST_ADDR_1, staker1_amount);
        create_stake_position(&mut scenario, TEST_ADDR_2, staker2_amount);
        create_stake_position(&mut scenario, TEST_ADDR_3, staker3_amount);

        // Add revenue type and deposit
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut pool = ts::take_shared<RevenuePool>(&scenario);
            let staking_pool = ts::take_shared<StakingPool>(&scenario);
            
            // Deposit 6000 SUI (should split proportionally)
            let revenue = coin::mint_for_testing<SUI>(6000, ts::ctx(&mut scenario));
            revenue_pool::deposit_revenue(
                &mut pool,
                &staking_pool,
                revenue,
                &clock,
                ts::ctx(&mut scenario)
            );
            
            ts::return_shared(pool);
            ts::return_shared(staking_pool);
        };

        // Advance clock
        advance_clock(&mut clock, THIRTY_DAYS_MS);

        // Have each staker claim and verify proportional amounts
        verify_claim(&mut scenario, TEST_ADDR_3, 3000, &clock); // ~3/6 of 6000
        verify_claim(&mut scenario, TEST_ADDR_2, 2000, &clock); // ~2/6 of 6000
        verify_claim(&mut scenario, TEST_ADDR_1, 1000, &clock); // ~1/6 of 6000

        clock::destroy_for_testing(clock);
        ts::end(scenario);
    }
}