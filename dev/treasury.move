#[allow(unused_use, unused_const)]
module spreadly::treasury {
    use sui::object::{Self, ID, UID};
    use sui::balance::{Self, Balance};
    use sui::coin::{Self, Coin};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use std::vector;
    use std::type_name::{Self, TypeName};

    // Error codes
    const EVAULT_NOT_FOUND: u64 = 0;
    const EINSUFFICIENT_BALANCE: u64 = 1;
    const EVAULT_ALREADY_EXISTS: u64 = 2;

    struct TreasuryVault<phantom T> has key, store {
        id: UID,
        balance: Balance<T>,
        vault_type: TypeName,
    }

    struct Treasury has key {
        id: UID,
        governance_vault: ID,  // Main governance token vault
        token_vaults: vector<ID>,  // Vector of other vault IDs
        token_types: vector<TypeName>,  // Vector of token types
    }

    // === Vault Creation and Management ===
    
    fun new_vault<T>(
        coin: Coin<T>,
        ctx: &mut TxContext
    ): ID {
        let vault = TreasuryVault {
            id: object::new(ctx),
            balance: coin::into_balance(coin),
            vault_type: type_name::get<T>()
        };
        let vault_id = object::id(&vault);
        transfer::share_object(vault);
        vault_id
    }

    public fun create_treasury<GovToken>(
        gov_token: Coin<GovToken>,
        ctx: &mut TxContext
    ): ID {
        let gov_vault_id = new_vault(gov_token, ctx);
        
        let treasury = Treasury {
            id: object::new(ctx),
            governance_vault: gov_vault_id,
            token_vaults: vector::empty(),
            token_types: vector::singleton(type_name::get<GovToken>())
        };
        let treasury_id = object::id(&treasury);
        transfer::share_object(treasury);
        treasury_id
    }

    public fun add_vault<T>(
        treasury: &mut Treasury,
        coin: Coin<T>,
        ctx: &mut TxContext
    ): ID {
        let new_type = type_name::get<T>();
        
        // Check if type already exists
        let i = 0;
        let len = vector::length(&treasury.token_types);
        while (i < len) {
            let existing_type = vector::borrow(&treasury.token_types, i);
            assert!(*existing_type != new_type, EVAULT_ALREADY_EXISTS);
            i = i + 1;
        };
        
        // Create and share new vault
        let vault_id = new_vault(coin, ctx);
        vector::push_back(&mut treasury.token_vaults, vault_id);
        vector::push_back(&mut treasury.token_types, new_type);
        vault_id
    }
    // === Vault Operations ===

    public fun deposit<T>(vault: &mut TreasuryVault<T>, coin: Coin<T>) {
        let coin_balance = coin::into_balance(coin);
        balance::join(&mut vault.balance, coin_balance);
    }

    public fun withdraw<T>(
        vault: &mut TreasuryVault<T>, 
        amount: u64,
        ctx: &mut TxContext
    ): Coin<T> {
        assert!(balance::value(&vault.balance) >= amount, EINSUFFICIENT_BALANCE);
        let withdrawn = balance::split(&mut vault.balance, amount);
        coin::from_balance(withdrawn, ctx)
    }

    // === Getters ===

    public fun vault_balance<T>(vault: &TreasuryVault<T>): u64 {
        balance::value(&vault.balance)
    }

    public fun vault_type<T>(vault: &TreasuryVault<T>): TypeName {
        vault.vault_type
    }

    public fun governance_vault_id(treasury: &Treasury): ID {
        treasury.governance_vault
    }

    public fun get_vault_ids(treasury: &Treasury): &vector<ID> {
        &treasury.token_vaults
    }
}