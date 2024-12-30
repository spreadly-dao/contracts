#[test_only]
#[allow(unused_use, unused_variable)]
module spreadly::treasury_tests {
    use sui::test_scenario::{Self as ts};
    use sui::coin::{Self, Coin};
    use sui::object::{Self, ID};
    use std::vector;
    use spreadly::treasury::{Self, Treasury, TreasuryVault};

    // Test tokens
    struct GOV_TOKEN has drop, store {}
    struct TEST_TOKEN has drop, store {}

    const ADMIN: address = @0xA;

    #[test]
    fun test_create_treasury() {
        let scenario = ts::begin(ADMIN);
        
        // Create initial governance tokens
        ts::next_tx(&mut scenario, ADMIN);
        {
            let gov_tokens = coin::mint_for_testing<GOV_TOKEN>(1000, ts::ctx(&mut scenario));
            treasury::create_treasury(gov_tokens, ts::ctx(&mut scenario));
        };

        // Verify treasury in a separate transaction
        ts::next_tx(&mut scenario, ADMIN);
        {
            // Verify treasury was created and is shared
            let treasury = ts::take_shared<Treasury>(&scenario);
            assert!(vector::is_empty(treasury::get_vault_ids(&treasury)), 1);
            ts::return_shared(treasury);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_add_vault() {
        let scenario = ts::begin(ADMIN);
        
        // First create treasury with gov tokens
        ts::next_tx(&mut scenario, ADMIN);
        {
            let gov_tokens = coin::mint_for_testing<GOV_TOKEN>(1000, ts::ctx(&mut scenario));
            treasury::create_treasury(gov_tokens, ts::ctx(&mut scenario));
        };

        // Add new token vault
        ts::next_tx(&mut scenario, ADMIN);
        {
            let treasury = ts::take_shared<Treasury>(&scenario);
            let test_tokens = coin::mint_for_testing<TEST_TOKEN>(500, ts::ctx(&mut scenario));
            
            let vault_id = treasury::add_vault(&mut treasury, test_tokens, ts::ctx(&mut scenario));
            
            // Verify vault was added
            let vault_ids = treasury::get_vault_ids(&treasury);
            assert!(vector::length(vault_ids) == 1, 0);
            assert!(*vector::borrow(vault_ids, 0) == vault_id, 1);
            
            ts::return_shared(treasury);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_vault_operations() {
        let scenario = ts::begin(ADMIN);
        
        // Create a treasury first with governance token
        ts::next_tx(&mut scenario, ADMIN);
        {
            let gov_tokens = coin::mint_for_testing<GOV_TOKEN>(1000, ts::ctx(&mut scenario));
            treasury::create_treasury(gov_tokens, ts::ctx(&mut scenario));
        };

        // Add a test token vault
        ts::next_tx(&mut scenario, ADMIN);
        {
            let treasury = ts::take_shared<Treasury>(&scenario);
            let initial_tokens = coin::mint_for_testing<TEST_TOKEN>(1000, ts::ctx(&mut scenario));
            treasury::add_vault(&mut treasury, initial_tokens, ts::ctx(&mut scenario));
            ts::return_shared(treasury);
        };

        // Test deposit
        ts::next_tx(&mut scenario, ADMIN);
        {
            let vault = ts::take_shared<TreasuryVault<TEST_TOKEN>>(&scenario);
            let deposit_tokens = coin::mint_for_testing<TEST_TOKEN>(500, ts::ctx(&mut scenario));
            
            let initial_balance = treasury::vault_balance(&vault);
            treasury::deposit(&mut vault, deposit_tokens);
            
            // Verify balance increased
            assert!(treasury::vault_balance(&vault) == initial_balance + 500, 0);
            
            ts::return_shared(vault);
        };

        // Test withdraw
        ts::next_tx(&mut scenario, ADMIN);
        {
            let vault = ts::take_shared<TreasuryVault<TEST_TOKEN>>(&scenario);
            let initial_balance = treasury::vault_balance(&vault);
            
            let withdrawn = treasury::withdraw(&mut vault, 200, ts::ctx(&mut scenario));
            assert!(coin::value(&withdrawn) == 200, 1);
            assert!(treasury::vault_balance(&vault) == initial_balance - 200, 2);
            
            coin::burn_for_testing(withdrawn);
            ts::return_shared(vault);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = treasury::EINSUFFICIENT_BALANCE)]
    fun test_withdraw_insufficient_balance() {
        let scenario = ts::begin(ADMIN);
        
        // Create treasury with governance token
        ts::next_tx(&mut scenario, ADMIN);
        {
            let gov_tokens = coin::mint_for_testing<GOV_TOKEN>(1000, ts::ctx(&mut scenario));
            treasury::create_treasury(gov_tokens, ts::ctx(&mut scenario));
        };

        // Add test token vault with initial tokens
        ts::next_tx(&mut scenario, ADMIN);
        {
            let treasury = ts::take_shared<Treasury>(&scenario);
            let initial_tokens = coin::mint_for_testing<TEST_TOKEN>(100, ts::ctx(&mut scenario));
            treasury::add_vault(&mut treasury, initial_tokens, ts::ctx(&mut scenario));
            ts::return_shared(treasury);
        };

        // Try to withdraw more than available
        ts::next_tx(&mut scenario, ADMIN);
        {
            let vault = ts::take_shared<TreasuryVault<TEST_TOKEN>>(&scenario);
            let withdrawn = treasury::withdraw(&mut vault, 200, ts::ctx(&mut scenario));
            coin::burn_for_testing(withdrawn);
            ts::return_shared(vault);
        };

        ts::end(scenario);
    }
    
    #[test]
    #[expected_failure(abort_code = treasury::EVAULT_ALREADY_EXISTS)]
    fun test_add_duplicate_vault() {
        let scenario = ts::begin(ADMIN);
        
        // Create treasury
        ts::next_tx(&mut scenario, ADMIN);
        {
            let gov_tokens = coin::mint_for_testing<GOV_TOKEN>(1000, ts::ctx(&mut scenario));
            treasury::create_treasury(gov_tokens, ts::ctx(&mut scenario));
        };

        // Add first vault of TEST_TOKEN type
        ts::next_tx(&mut scenario, ADMIN);
        {
            let treasury = ts::take_shared<Treasury>(&scenario);
            let test_tokens = coin::mint_for_testing<TEST_TOKEN>(500, ts::ctx(&mut scenario));
            treasury::add_vault(&mut treasury, test_tokens, ts::ctx(&mut scenario));
            
            // Try to add another vault of the same token type
            let more_tokens = coin::mint_for_testing<TEST_TOKEN>(500, ts::ctx(&mut scenario));
            // This should fail because a vault for TEST_TOKEN already exists
            treasury::add_vault(&mut treasury, more_tokens, ts::ctx(&mut scenario));
            
            ts::return_shared(treasury);
        };

        ts::end(scenario);
    }
}