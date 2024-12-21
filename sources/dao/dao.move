module spreadly::dao {
    // If you really need to silence "unused variable" warnings globally, uncomment:
    // #![allow(unused_variables)]

    use sui::object::{Self, UID, ID, new, id as object_id};
    use sui::tx_context::{Self, TxContext, sender};
    use sui::transfer;
    use sui::coin::{Self, Coin};
    use sui::event;
    use std::string::{Self, String, utf8};
    // use std::option; // Remove if not used
    // use sui::url::{Self, Url}; // Remove if not used

    /// The core DAO structure.
    /// Note the `<T: store>` so that `DAO<T>` can have `has key`.
    struct DAO<T: store> has key {
        id: UID,
        name: String,
        description: String,
        governance_token: Coin<T>,
    }

    /// Event emitted upon DAO creation.
    struct DAOCreatedEvent has copy, drop {
        dao_id: ID,
        creator: address,
        token_id: ID,
    }

    /// Creates a new DAO object, emits an event, and shares the DAO.
    public entry fun create_dao<T: store>(
        governance_coin: Coin<T>,
        ctx: &mut TxContext
    ) {
        // 1) Get the ID of the governance coin *before* moving it into the DAO
        let token_id = object::id(&governance_coin);

        // 2) Construct the DAO
        let dao = DAO<T> {
            id: new(ctx),                        // Create a fresh object ID
            name: utf8(b"FUCK"),                 // Convert raw bytes to String
            description: utf8(b"YOU"),           // Convert raw bytes to String
            governance_token: governance_coin,   // Move the whole coin here
        };

        // 3) Emit the event
        event::emit(DAOCreatedEvent {
            dao_id: object_id(&dao),
            creator: sender(ctx),
            token_id: token_id,
        });

        // 4) Finally, share the DAO object publicly
        transfer::share_object(dao);
    }
}

// to do

// make integration tests, unit tests for these contracts aren't helpful outside of contained operations

// create token - transaction needs to be executed by the deployer, as it's not something that can be made dynamic due to the 'witness' paradigm for creating tokens
// create dao based off token

