#[test_only]
module spreadly::dao_tests {
    use sui::test_scenario::{Self as ts};
    use sui::coin::{Self, Coin};  // Added Coin type explicitly
    use std::string;
    use std::option;
    use sui::tx_context::TxContext;
    
    use spreadly::dao::{Self, DAO};

    // Test token with store ability
    struct TEST_TOKEN has drop, store {}

    // Test constants
    const ADMIN: address = @0xA;
    const BASIS_POINTS: u64 = 10000;
    const MIN_DURATION: u64 = 86400000; // 1 day in milliseconds

    fun create_test_token(amount: u64, ctx: &mut TxContext): Coin<TEST_TOKEN> {
        coin::mint_for_testing<TEST_TOKEN>(amount, ctx)
    }

    #[test]
    fun test_dao_creation() {
        let scenario = ts::begin(ADMIN);
        
        // Setup test parameters
        let name = string::utf8(b"Test DAO");
        let description = string::utf8(b"A test DAO");
        let logo_url = string::utf8(b"https://test.com/logo.png");
        let support_threshold = 5100; // 51%
        let min_participation = 2000; // 20%
        let min_proposal_duration = MIN_DURATION;
        let min_token_for_proposal = 100;
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            // Create initial treasury tokens
            let treasury_tokens = create_test_token(1000, ts::ctx(&mut scenario));

            dao::create_dao<TEST_TOKEN>( // Added explicit type parameter
                name,
                description,
                logo_url,
                support_threshold,
                min_participation,
                min_proposal_duration,
                min_token_for_proposal,
                treasury_tokens,
                ts::ctx(&mut scenario)
            );
        };

        // Verify DAO was created and fields are correct
        ts::next_tx(&mut scenario, ADMIN);
        {
            let dao = ts::take_shared<DAO<TEST_TOKEN>>(&scenario);
            
            assert!(dao::name(&dao) == name, 0);
            assert!(dao::description(&dao) == description, 1);
            assert!(dao::support_threshold(&dao) == support_threshold, 2);
            assert!(dao::min_participation(&dao) == min_participation, 3);
            assert!(dao::min_proposal_duration(&dao) == min_proposal_duration, 4);
            assert!(dao::min_token_for_proposal(&dao) == min_token_for_proposal, 5);
            assert!(option::is_none(&dao::revenue_pool(&dao)), 6);

            ts::return_shared(dao);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = dao::EINVALID_THRESHOLD)]
    fun test_create_dao_invalid_threshold() {
        let scenario = ts::begin(ADMIN);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            let treasury_tokens = create_test_token(1000, ts::ctx(&mut scenario));

            dao::create_dao<TEST_TOKEN>( // Added explicit type parameter
                string::utf8(b"Test DAO"),
                string::utf8(b"Description"),
                string::utf8(b"url"),
                BASIS_POINTS + 1, // Invalid threshold > 100%
                2000,
                MIN_DURATION,
                100,
                treasury_tokens,
                ts::ctx(&mut scenario)
            );
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = dao::EINVALID_PARTICIPATION)]
    fun test_create_dao_invalid_participation() {
        let scenario = ts::begin(ADMIN);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            let treasury_tokens = create_test_token(1000, ts::ctx(&mut scenario));

            dao::create_dao<TEST_TOKEN>( // Added explicit type parameter
                string::utf8(b"Test DAO"),
                string::utf8(b"Description"),
                string::utf8(b"url"),
                5100,
                BASIS_POINTS + 1, // Invalid participation > 100%
                MIN_DURATION,
                100,
                treasury_tokens,
                ts::ctx(&mut scenario)
            );
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = dao::EINVALID_DURATION)]
    fun test_create_dao_invalid_duration() {
        let scenario = ts::begin(ADMIN);
        
        ts::next_tx(&mut scenario, ADMIN);
        {
            let treasury_tokens = create_test_token(1000, ts::ctx(&mut scenario));

            dao::create_dao<TEST_TOKEN>( // Added explicit type parameter
                string::utf8(b"Test DAO"),
                string::utf8(b"Description"),
                string::utf8(b"url"),
                5100,
                2000,
                MIN_DURATION - 1, // Invalid duration < minimum
                100,
                treasury_tokens,
                ts::ctx(&mut scenario)
            );
        };

        ts::end(scenario);
    }
}