module spreadly::token_factory {
    use std::option::{Self, Option};
    use std::string::{String, utf8};
    use sui::coin::{Self};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::event;
    use sui::url::{Self, Url};
    use sui::package;

    /// Capability for creating new tokens
    struct TokenFactoryCap has key {
        id: UID
    }

    /// Event emitted when a new token is created
    struct TokenCreatedEvent has copy, drop {
        name: String,
        symbol: String,
        decimals: u8,
        description: String,
        icon_url: Option<Url>
    }

    /// One-time witness - note the name matches module name in uppercase
    struct TOKEN_FACTORY has drop {}

    fun init(witness: TOKEN_FACTORY, ctx: &mut TxContext) {
        // Claim the publisher
        let publisher = package::claim(witness, ctx);
        
        // Create the factory capability
        let cap = TokenFactoryCap {
            id: object::new(ctx)
        };

        // Transfer the publisher and capability
        transfer::public_transfer(publisher, tx_context::sender(ctx));
        transfer::transfer(cap, tx_context::sender(ctx));
    }

    /// Creates a new token with the specified parameters
    public entry fun create_token(
        _cap: &TokenFactoryCap,
        name: vector<u8>,
        symbol: vector<u8>,
        description: vector<u8>,
        decimals: u8,
        icon_url: vector<u8>,
        ctx: &mut TxContext
    ) {
        let url_option = if (icon_url == b"") {
            option::none()
        } else {
            option::some(url::new_unsafe_from_bytes(icon_url))
        };

        // Create new type for the token
        let (treasury_cap, metadata) = coin::create_currency(
            TOKEN_FACTORY {},  // Create new instance of witness
            decimals,
            symbol,
            name,
            description,
            url_option,
            ctx
        );

        // Emit creation event
        event::emit(TokenCreatedEvent {
            name: utf8(name),
            symbol: utf8(symbol),
            decimals,
            description: utf8(description),
            icon_url: url_option
        });

        // Transfer treasury cap to creator and share metadata
        transfer::public_transfer(treasury_cap, tx_context::sender(ctx));
        transfer::public_share_object(metadata);
    }
}