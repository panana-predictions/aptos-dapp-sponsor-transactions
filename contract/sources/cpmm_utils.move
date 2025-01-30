module message_board_addr::cpmm_utils {
    use std::bcs;
    use std::vector;
    use aptos_std::comparator;
    use aptos_framework::fungible_asset;
    use aptos_framework::fungible_asset::Metadata;
    use aptos_framework::object::{Object, object_address};

    public fun asset_pair_identifier(
        token_a_metadata: Object<Metadata>,
        token_b_metadata: Object<Metadata>,
    ): vector<u8> {
        let (first_token_metadata, second_token_metadata) = order_tokens(token_a_metadata, token_b_metadata);
        let identifier = vector::empty<u8>();
        vector::append(
            &mut identifier,
            bcs::to_bytes(&object_address(&first_token_metadata))
        );
        vector::append(
            &mut identifier,
            bcs::to_bytes(&object_address(&second_token_metadata))
        );

        identifier
    }

    public fun order_tokens(
        token_a_metadata: Object<Metadata>,
        token_b_metadata: Object<Metadata>,
    ): (Object<Metadata>, Object<Metadata>) {
        let token_a_symbol = fungible_asset::symbol(token_a_metadata);
        let token_b_symbol = fungible_asset::symbol(token_b_metadata);
        if (comparator::is_smaller_than(&(comparator::compare(&token_a_symbol, &token_b_symbol)))) {
            return (token_a_metadata, token_b_metadata)
        };
        return (token_b_metadata, token_a_metadata)
    }
}
