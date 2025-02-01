module message_board_addr::market {
    // use aptos_framework::fungible_asset::Metadata;
    // use aptos_framework::object::Object;
    // use message_board_addr::cpmm;
    // use message_board_addr::cpmm_utils;
    //
    // public entry fun buy(
    //     account: &signer,
    //     fa_metadata: Object<Metadata>, // market bet type (e.g. APT, USDT, USDC, ...), may be omitted later if we can get the type from the market
    //     predict_yes: bool,
    //     token_value: u64, // for how much does the user want to buy? (e.g. 2 APT)
    // ) {
    //     // let coins = primary_fungible_store::withdraw<fa_metadata>(account)
    //     // market.add_coins(coins);
    //     let metadata_a: Object<Metadata>;
    //     let metadata_b: Object<Metadata>;
    //     let (price_yes, price_no) = cpmm::token_price(metadata_a, metadata_b);
    //     let amount_shares = token_value / if (predict_yes) price_yes else price_no;
    //     // let opposite_shares = mint_shares(!predict_yes)
    //     //let user_shares = cpmm::buy_in(metadata_a, metadata_b, shares);
    //     // send user_shares to user
    // }
    //
    // public entry fun sell(
    //     account: &signer,
    //     fa_metadata: Object<Metadata>, // yes or now shares metadata
    //     token_value: u64,
    // ) {
    //     let metadata_a: Object<Metadata>;
    //     let metadata_b: Object<Metadata>;
    //     let (price_yes, price_no) = cpmm::token_price(metadata_a, metadata_b);
    //     // let shares = priamry_fungible_store::withdraw(account, fa_metadata, token_value);
    //     // let returned_shares = cpmm::buy_in(metadata_a, metadata_b, shares);
    //     // let user_coins = withdraw(market, fungible_asset::amount(returned_shares));
    //     // send user_coins to user
    // }
}
