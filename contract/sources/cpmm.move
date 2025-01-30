module message_board_addr::cpmm {
    use std::signer;
    use aptos_std::math64;
    use aptos_std::smart_table;
    use aptos_framework::fungible_asset;
    use aptos_framework::fungible_asset::{FungibleStore, Metadata, FungibleAsset};
    use aptos_framework::object;
    use aptos_framework::object::{Object, ExtendRef};
    use message_board_addr::cpmm_utils;

    const E_CATCH_ALL: u64 = 87654;

    const MIN_LIQUIDITY: u64 = 1000_0000_0000;

    struct LiquidityPool has key, store {
        token_a_vault: Object<FungibleStore>,
        token_b_vault: Object<FungibleStore>,
        // token_a_mint_cap: fungible_asset::MintRef,
        // token_a_burn_cap: fungible_asset::BurnRef,
        // token_b_mint_cap: fungible_asset::MintRef,
        // token_b_burn_cap: fungible_asset::BurnRef,
    }

    struct AMMGlobalState has key {
        pools: smart_table::SmartTable<vector<u8>, LiquidityPool>,
        extend_ref: ExtendRef,
    }

    fun init_module(account: &signer) {
        let constructor_ref = object::create_object(signer::address_of(account));
        let extend_ref = object::generate_extend_ref(&constructor_ref);
        move_to(account, AMMGlobalState {
            pools: smart_table::new(),
            extend_ref,
        });
    }

    public fun create_liquidity_pool(
        token_a_metadata: Object<Metadata>,
        token_b_metadata: Object<Metadata>,
        token_a: FungibleAsset,
        token_b: FungibleAsset,
    ) acquires AMMGlobalState {
        assert!(object::object_address(&token_a_metadata) != object::object_address(&token_b_metadata), E_CATCH_ALL);
        assert!(fungible_asset::amount(&token_a) == fungible_asset::amount(&token_b) && fungible_asset::amount(&token_a) >= MIN_LIQUIDITY, E_CATCH_ALL);
        let asset_pair_identifier = cpmm_utils::asset_pair_identifier(token_a_metadata, token_b_metadata);
        let global_state = borrow_global_mut<AMMGlobalState>(@amm_address);
        assert!(!smart_table::contains(&global_state.pools, asset_pair_identifier), E_CATCH_ALL);

        let global_state_signer = object::generate_signer_for_extending(&global_state.extend_ref);

        let token_a_store = create_token_store(&global_state_signer, token_a_metadata);
        let token_b_store = create_token_store(&global_state_signer, token_b_metadata);

        fungible_asset::deposit(token_a_store, token_a);
        fungible_asset::deposit(token_b_store, token_b);

        smart_table::add(&mut global_state.pools, asset_pair_identifier, LiquidityPool {
            token_a_vault: token_a_store,
            token_b_vault: token_b_store,
        });
    }

    public fun add_liquidity(
        token_a_metadata: Object<Metadata>,
        token_b_metadata: Object<Metadata>,
        token_a: FungibleAsset,
        token_b: FungibleAsset,
    ) acquires AMMGlobalState {
        let asset_pair_identifier = cpmm_utils::asset_pair_identifier(token_a_metadata, token_b_metadata);
        let global_state = borrow_global_mut<AMMGlobalState>(@amm_address);

        assert!(smart_table::contains(&global_state.pools, asset_pair_identifier), E_CATCH_ALL);
        let liquidity_pool = smart_table::borrow(&global_state.pools, asset_pair_identifier);
        fungible_asset::deposit(liquidity_pool.token_a_vault, token_a);
        fungible_asset::deposit(liquidity_pool.token_b_vault, token_b);
    }

    public fun buy_in(
        token_a_metadata: Object<Metadata>,
        token_b_metadata: Object<Metadata>,
        token_in: FungibleAsset,
    ): FungibleAsset acquires AMMGlobalState {
        assert!(fungible_asset::amount(&token_in) > 0, E_CATCH_ALL);
        let asset_pair_identifier = cpmm_utils::asset_pair_identifier(token_a_metadata, token_b_metadata);
        let global_signer = get_global_signer();

        let global_state = borrow_global_mut<AMMGlobalState>(@amm_address);
        assert!(smart_table::contains(&global_state.pools, asset_pair_identifier), E_CATCH_ALL);
        let liquidity_pool = smart_table::borrow(&global_state.pools, asset_pair_identifier);
        
        let token_in_amount = fungible_asset::amount(&token_in);
        let is_token_a = fungible_asset::metadata_from_asset(&token_in) == token_a_metadata;
        let in_vault = if(is_token_a) liquidity_pool.token_a_vault else liquidity_pool.token_b_vault;
        let out_vault = if(is_token_a) liquidity_pool.token_b_vault else liquidity_pool.token_a_vault;
        
        let in_vault_balance = fungible_asset::balance(in_vault);
        let new_in_vault_balance = in_vault_balance + token_in_amount;

        let token_out = math64::mul_div(fungible_asset::balance(out_vault), token_in_amount, new_in_vault_balance);

        assert!(token_out > 0, E_CATCH_ALL);
        // Perform the swap: update vaults
        fungible_asset::deposit(in_vault, token_in);
        fungible_asset::withdraw(global_signer, out_vault, token_out)
    }

    public fun remove_liquidity(
        token_a_metadata: Object<Metadata>,
        token_b_metadata: Object<Metadata>,
        token_a: FungibleAsset,
        token_b: FungibleAsset,
    ) acquires AMMGlobalState {
        let asset_pair_identifier = cpmm_utils::asset_pair_identifier(token_a_metadata, token_b_metadata);
        let global_state = borrow_global_mut<AMMGlobalState>(@amm_address);

        assert!(smart_table::contains(&global_state.pools, asset_pair_identifier), E_CATCH_ALL);
        let liquidity_pool = smart_table::borrow(&global_state.pools, asset_pair_identifier);
        fungible_asset::deposit(liquidity_pool.token_a_vault, token_a);
        fungible_asset::deposit(liquidity_pool.token_b_vault, token_b);
    }

    inline fun create_token_store(account: &signer, token: Object<Metadata>): Object<FungibleStore> {
        let constructor_ref = &object::create_object_from_object(account);
        fungible_asset::create_store(constructor_ref, token)
    }

    inline fun get_global_signer(): &signer acquires AMMGlobalState {
        let global_state = borrow_global_mut<AMMGlobalState>(@amm_address);
        &object::generate_signer_for_extending(&global_state.extend_ref)
    }

    #[view]
    public fun token_price(
        token_a_metadata: Object<Metadata>,
        token_b_metadata: Object<Metadata>,
    ): (u64, u64) acquires AMMGlobalState {
        let (a_balance, b_balance) = available_shares(token_a_metadata, token_b_metadata);

        let sum_balance = a_balance + b_balance;
        (math64::mul_div(a_balance, 1_0000_0000, sum_balance), math64::mul_div(b_balance, 1_0000_0000, sum_balance))
    }

    #[view]
    public fun available_shares(
        token_a_metadata: Object<Metadata>,
        token_b_metadata: Object<Metadata>,
    ): (u64, u64) acquires AMMGlobalState {
        let asset_pair_identifier = cpmm_utils::asset_pair_identifier(token_a_metadata, token_b_metadata);
        let global_state = borrow_global_mut<AMMGlobalState>(@amm_address);
        assert!(smart_table::contains(&global_state.pools, asset_pair_identifier), E_CATCH_ALL);
        let liquidity_pool = smart_table::borrow(&global_state.pools, asset_pair_identifier);
        let a_balance = fungible_asset::balance(liquidity_pool.token_a_vault);
        let b_balance = fungible_asset::balance(liquidity_pool.token_b_vault);
        (a_balance, b_balance)
    }

    #[test_only]
    public fun init_test(account: &signer) {
        init_module(account);
    }
}
