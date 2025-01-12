#[allow(unused_use, unused_const)]

module spreadly::dao {
    use std::ascii::{Self, String as AsciiString};
    use std::string::{Self, String};
    use std::vector;
    use std::option::{Self, Option};
    use sui::object::{Self, ID, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use sui::url::{Self, Url};
    use sui::table::{Self, Table};
    use sui::event;
    use sui::coin::{Self, Coin};
    use std::type_name::{Self, TypeName};
    use spreadly::treasury::{Self, Treasury};

    // Errors
    const EINVALID_THRESHOLD: u64 = 0;
    const EINVALID_PARTICIPATION: u64 = 1;
    const EINVALID_DURATION: u64 = 2;
    const EINVALID_TOKEN_AMOUNT: u64 = 3;

    // Constants 
    const BASIS_POINTS: u64 = 10000;
    const MIN_DURATION: u64 = 86400000; // 1 day in milliseconds

    struct DAO<phantom CoinType> has key, store {
        id: UID,
        name: String,
        description: String,
        logo_url: Url,
        support_threshold: u64,        // Percentage in basis points (e.g., 5100 = 51%)
        min_participation: u64,        // Minimum participation in basis points
        min_proposal_duration: u64,    // Minimum duration in milliseconds
        min_token_for_proposal: u64,   // Minimum tokens needed to create proposal
        treasury: ID,          // ID of the treasury object that will hold tokens
        revenue_pool: Option<ID>,      // ID of the revenue pool
    }

    /// Event emitted when a new DAO is created
    /// The token type is included in the event for indexing purposes
    struct DAOCreated has copy, drop {
        dao_id: ID,
        name: String,
        creator: address,
        treasury_id: ID,
        token_type: TypeName,
    }

    /// Create a new DAO with the specified governance token type
    public entry fun create_dao<CoinType>(
        name: String,
        description: String,
        logo_url: String,
        support_threshold: u64,
        min_participation: u64,
        min_proposal_duration: u64,
        min_token_for_proposal: u64,
        treasury_tokens: Coin<CoinType>,
        ctx: &mut TxContext
    ) {
        assert!(support_threshold <= BASIS_POINTS, EINVALID_THRESHOLD);
        assert!(min_participation <= BASIS_POINTS, EINVALID_PARTICIPATION);
        assert!(min_proposal_duration >= MIN_DURATION, EINVALID_DURATION);

        let logo_bytes = *string::as_bytes(&logo_url);
        let logo_ascii = ascii::string(logo_bytes);

        // Create treasury first with initial tokens
        let treasury_id = treasury::create_treasury(treasury_tokens, ctx);

        let dao = DAO<CoinType> {
            id: object::new(ctx),
            name,
            description,
            logo_url: url::new_unsafe(logo_ascii),
            support_threshold,
            min_participation,
            min_proposal_duration,
            min_token_for_proposal,
            treasury: treasury_id,
            revenue_pool: option::none(),
        };

        let dao_id = object::id(&dao);
        
        // Emit event with type information for indexing
        event::emit(DAOCreated {
            dao_id,
            name,
            creator: tx_context::sender(ctx),
            treasury_id,
            token_type: type_name::get<CoinType>(),
        });

        transfer::share_object(dao);
    }

    // === Getter Functions ===
    
    /// Get the name of the DAO
    public fun name<CoinType>(dao: &DAO<CoinType>): String { dao.name }
    
    /// Get the description of the DAO
    public fun description<CoinType>(dao: &DAO<CoinType>): String { dao.description }
    
    /// Get the support threshold (in basis points)
    public fun support_threshold<CoinType>(dao: &DAO<CoinType>): u64 { dao.support_threshold }
    
    /// Get the minimum participation requirement (in basis points)
    public fun min_participation<CoinType>(dao: &DAO<CoinType>): u64 { dao.min_participation }
    
    /// Get the minimum duration for proposals
    public fun min_proposal_duration<CoinType>(dao: &DAO<CoinType>): u64 { dao.min_proposal_duration }
    
    /// Get the minimum token amount required for creating proposals
    public fun min_token_for_proposal<CoinType>(dao: &DAO<CoinType>): u64 { dao.min_token_for_proposal }
    
    /// Get the governance token type
    public fun governance_token_type<CoinType>(): TypeName { 
        type_name::get<CoinType>() 
    }
    
    /// Get the treasury ID if set
    public fun treasury<CoinType>(dao: &DAO<CoinType>): ID { dao.treasury }
    
    /// Get the revenue pool ID if set
    public fun revenue_pool<CoinType>(dao: &DAO<CoinType>): Option<ID> { dao.revenue_pool }

    // === Setter Functions ===
    
    /// Set the revenue pool ID for the DAO
    public fun set_revenue_pool<CoinType>(dao: &mut DAO<CoinType>, pool_id: ID) {
        option::fill(&mut dao.revenue_pool, pool_id);
    }
}