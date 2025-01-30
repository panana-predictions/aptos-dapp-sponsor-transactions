module message_board_addr::cpmm_test {
    #[test_only]
    use std::option;
    #[test_only]
    use std::string::utf8;
    #[test_only]
    use std::vector;
    #[test_only]
    use aptos_std::debug;
    #[test_only]
    use aptos_framework::fungible_asset;
    #[test_only]
    use aptos_framework::fungible_asset::{MintRef, TransferRef, BurnRef};
    #[test_only]
    use aptos_framework::object;
    #[test_only]
    use aptos_framework::primary_fungible_store;
    #[test_only]
    use message_board_addr::cpmm;


    const ASSET_NAME_A: vector<u8> = b"Yes";
    const ASSET_SYMBOL_A: vector<u8> = b"YES";


    const ASSET_NAME_B: vector<u8> = b"No";
    const ASSET_SYMBOL_B: vector<u8> = b"NO";

    #[test(amm_address = @amm_address)]
    public fun test_create_liquidity_pool(amm_address: &signer) {
        cpmm::init_test(amm_address);
        let (mint_a, _, _, mint_b, _, _) = init_tokens(amm_address);
        let metadata_a = fungible_asset::mint_ref_metadata(&mint_a);
        let metadata_b = fungible_asset::mint_ref_metadata(&mint_b);

        let initial_a_liquidity = fungible_asset::mint(&mint_a, 1000_0000_0000);
        let initial_b_liquidity = fungible_asset::mint(&mint_b, 1000_0000_0000);

        cpmm::create_liquidity_pool(metadata_a, metadata_b, initial_a_liquidity, initial_b_liquidity);

        let (price_a, price_b) = cpmm::token_price(metadata_a, metadata_b);
        assert!(price_a == 5000_0000, 0);
        assert!(price_b == 5000_0000, 0);

        let (shares_a, shares_b) = cpmm::available_shares(metadata_a, metadata_b);
        assert!(shares_a == 1000_0000_0000, 0);
        assert!(shares_b == 1000_0000_0000, 0);
    }

    struct BuyInCase has drop {
        amount: u64,
        is_token_b: bool,
        expected_shares_a: u64,
        expected_shares_b: u64,
    }

    #[test(amm_address = @amm_address)]
    public fun test_buy_in(amm_address: &signer) {
        cpmm::init_test(amm_address);
        let (mint_a, _, burn_a, mint_b, _, burn_b) = init_tokens(amm_address);
        let metadata_a = fungible_asset::mint_ref_metadata(&mint_a);
        let metadata_b = fungible_asset::mint_ref_metadata(&mint_b);

        // Initialize liquidity pool
        let initial_a_liquidity = fungible_asset::mint(&mint_a, 1000_0000_0000);
        let initial_b_liquidity = fungible_asset::mint(&mint_b, 1000_0000_0000);
        cpmm::create_liquidity_pool(metadata_a, metadata_b, initial_a_liquidity, initial_b_liquidity);



        // Define buy-in test cases (amount in A or B, expected shares_a, expected shares_b)
        // Define buy-in test cases
        let buy_in_cases: vector<BuyInCase> = vector[
            BuyInCase { amount: 10_0000_0000, is_token_b: false, expected_shares_a: 1010_0000_0000, expected_shares_b: 990_0990_0991 },
            BuyInCase { amount: 100_0000_0000, is_token_b: true, expected_shares_a: 917_3478_6558, expected_shares_b: 1090_0990_0991 },
            BuyInCase { amount: 20_0000_0000, is_token_b: false, expected_shares_a: 937_3478_6558, expected_shares_b: 1066_8397_8994 },
            BuyInCase { amount: 200_0000_0000, is_token_b: true, expected_shares_a: 789_3657_9666, expected_shares_b: 1266_8397_8994 },
            BuyInCase { amount: 50_0000_0000, is_token_b: false, expected_shares_a: 839_3657_9666, expected_shares_b: 1191_3756_8389 },
            BuyInCase { amount: 500_0000_0000, is_token_b: true, expected_shares_a: 591_2347_0295, expected_shares_b: 1691_3756_8389 },
            BuyInCase { amount: 30_0000_0000, is_token_b: false, expected_shares_a: 621_2347_0295, expected_shares_b: 1609_6975_8337 },
            BuyInCase { amount: 300_0000_0000, is_token_b: true, expected_shares_a: 523_6431_1960, expected_shares_b: 1909_6975_8337 },
        ];

        let i = 0;
        while (i < buy_in_cases.length()) {
            let BuyInCase{amount, is_token_b, expected_shares_a, expected_shares_b} = buy_in_cases.borrow(i);

            if (*is_token_b) {
                let buy_in = fungible_asset::mint(&mint_b, *amount);
                let yes_shares = cpmm::buy_in(metadata_a, metadata_b, buy_in);
                fungible_asset::burn(&burn_a, yes_shares);
            } else {
                let buy_in = fungible_asset::mint(&mint_a, *amount);
                let no_shares = cpmm::buy_in(metadata_a, metadata_b, buy_in);
                fungible_asset::burn(&burn_b, no_shares);
            };

            // Get updated shares
            let (shares_a, shares_b) = cpmm::available_shares(metadata_a, metadata_b);

            // Validate expected shares
            assert!(shares_a == *expected_shares_a, 0);
            assert!(shares_b == *expected_shares_b, 0);

            i = i + 1;
        }
    }


    #[test_only]
    fun init_tokens(account: &signer): (MintRef, TransferRef, BurnRef, MintRef, TransferRef, BurnRef) {
        let (mint_a, transfer_a, burn_a) = create_token(account, ASSET_NAME_A, ASSET_SYMBOL_A);
        let (mint_b, transfer_b, burn_b) = create_token(account, ASSET_NAME_B, ASSET_SYMBOL_B);

        (mint_a, transfer_a, burn_a, mint_b, transfer_b, burn_b)
    }

    #[test_only]
    fun create_token(
        account: &signer,
        asset_name: vector<u8>,
        asset_symbol: vector<u8>
    ): (MintRef, TransferRef, BurnRef) {
        let constructor_ref = &object::create_named_object(account, asset_name);
        primary_fungible_store::create_primary_store_enabled_fungible_asset(
            constructor_ref,
            option::none(),
            utf8(asset_name),
            utf8(asset_symbol),
            8,
            utf8(b"http://example.com/favicon.ico"),
            utf8(b"http://example.com"),
        );

        let mint_ref = fungible_asset::generate_mint_ref(constructor_ref);
        let burn_ref = fungible_asset::generate_burn_ref(constructor_ref);
        let transfer_ref = fungible_asset::generate_transfer_ref(constructor_ref);
        (mint_ref, transfer_ref, burn_ref)
    }
}
