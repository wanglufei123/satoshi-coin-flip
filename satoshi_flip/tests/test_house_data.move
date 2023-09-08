// Copyright (c) Mysten Labs, Inc.
// SPDX-License-Identifier: Apache-2.0

#[test_only]
module satoshi_flip::test_house_data {

    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::transfer;
    use sui::test_scenario::{Self, Scenario};

    use satoshi_flip::test_common::{Self as tc};
    use satoshi_flip::single_player_satoshi::{Self as sps};
    use satoshi_flip::house_data::{Self as hd, HouseData};

    const EWrongWithdrawAmount: u64 = 1;
    const EWrongHouseBalanceAfterFund: u64 = 2;
    const EWrongMaxStake: u64 = 3;
    const EWrongMinStake: u64 = 4;

    // ---------- Helper functions ---------

    // Used to initialize the user and house balances.
    fun fund_house(scenario: &mut Scenario, house: address, house_funds: u64) {
        let ctx = test_scenario::ctx(scenario);
        let coinA = coin::mint_for_testing<SUI>(house_funds, ctx);
        transfer::public_transfer(coinA, house);
    }

    // -------------- Sunny Day Tests ----------------
    #[test]
    fun house_withdraws_balance() {
        let house = @0xCAFE;

        let scenario_val = test_scenario::begin(house);
        let scenario = &mut scenario_val;
        {
            fund_house(scenario, house, tc::get_initial_house_balance());
        };

        tc::init_house(scenario, house, true);

        // House withdraws funds.
        test_scenario::next_tx(scenario, house);
        {
            let house_data = test_scenario::take_shared<HouseData>(scenario);
            let ctx = test_scenario::ctx(scenario);
            hd::withdraw(&mut house_data, ctx);
            test_scenario::return_shared(house_data);
        };

        // Check that the HouseData balance has been depleted and that the house's account has been credited.
        test_scenario::next_tx(scenario, house);
        {
            let withdraw_coin = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            assert!(coin::value(&withdraw_coin) == tc::get_initial_house_balance(), EWrongWithdrawAmount);
            test_scenario::return_to_sender(scenario, withdraw_coin);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun house_withdraws_fees() {
        let house = @0xCAFE;
        let player = @0xDECAf;

        let scenario_val = test_scenario::begin(house);
        let scenario = &mut scenario_val;
        {
            tc::fund_addresses(scenario, house, player, tc::get_initial_house_balance(), tc::get_initial_player_balance());
        };

        tc::init_house(scenario, house, true);

        // Player creates his/her counter NFT and the game.
        let game_id = tc::create_counter_nft_and_game(scenario, player, tc::get_min_stake(), false, true);

        // Get the game's fee
        let game_fee = tc::game_fees(scenario, game_id, house);

        // House ends the game.
        tc::end_game(scenario, game_id, house, true);

        // House withdraws fees.
        test_scenario::next_tx(scenario, house);
        {
            let house_data = test_scenario::take_shared<HouseData>(scenario);
            let ctx = test_scenario::ctx(scenario);
            hd::claim_fees(&mut house_data, ctx);
            test_scenario::return_shared(house_data);
        };

        // Check that the HouseData fees balance has been depleted and that the house's account has been credited.
        test_scenario::next_tx(scenario, house);
        {
            let withdraw_coin = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            let fees = sps::fee_amount(tc::get_min_stake()*2, game_fee);
            assert!(coin::value(&withdraw_coin) == fees, EWrongWithdrawAmount);
            test_scenario::return_to_sender(scenario, withdraw_coin);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun house_top_ups() {
        let house = @0xCAFE;

        let scenario_val = test_scenario::begin(house);
        let scenario = &mut scenario_val;
        {
            fund_house(scenario, house, tc::get_initial_house_balance());
        };

        tc::init_house(scenario, house, true);

        // Create fund coin & send it to house.
        test_scenario::next_tx(scenario, house);
        {
            let ctx = test_scenario::ctx(scenario);
            let fund_coin = coin::mint_for_testing<SUI>(tc::get_min_stake(), ctx);
            transfer::public_transfer(fund_coin, house);
        };

        // Top up with fund coin.
        test_scenario::next_tx(scenario, house);
        {
            let house_data = test_scenario::take_shared<HouseData>(scenario);
            let owned_fund_coin = test_scenario::take_from_sender<Coin<SUI>>(scenario);
            let ctx = test_scenario::ctx(scenario);
            hd::top_up(&mut house_data, owned_fund_coin, ctx);
            let house_balance = hd::balance(&house_data);
            assert!(house_balance == tc::get_initial_house_balance() + tc::get_min_stake(), EWrongHouseBalanceAfterFund);
            test_scenario::return_shared(house_data);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun house_updates_max_stake() {
        let house = @0xCAFE;

        let scenario_val = test_scenario::begin(house);
        let scenario = &mut scenario_val;
        {
            fund_house(scenario, house, tc::get_initial_house_balance());
        };

        tc::init_house(scenario, house, true);

        // House address updates max stake.
        test_scenario::next_tx(scenario, house);
        {
            let house_data = test_scenario::take_shared<HouseData>(scenario);
            let ctx = test_scenario::ctx(scenario);
            hd::update_max_stake(&mut house_data, tc::get_max_stake()*2, ctx);
            test_scenario::return_shared(house_data);
        };

        // Check if max stake has been updated.
        test_scenario::next_tx(scenario, house);
        {
            let house_data = test_scenario::take_shared<HouseData>(scenario);
            let max_stake = hd::max_stake(&house_data);
            assert!(max_stake == tc::get_max_stake()*2, EWrongMaxStake);
            test_scenario::return_shared(house_data);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    fun house_updates_min_stake() {
        let house = @0xCAFE;

        let scenario_val = test_scenario::begin(house);
        let scenario = &mut scenario_val;
        {
            fund_house(scenario, house, tc::get_initial_house_balance());
        };

        tc::init_house(scenario, house, true);

        // House address updates min stake.
        test_scenario::next_tx(scenario, house);
        {
            let house_data = test_scenario::take_shared<HouseData>(scenario);
            let ctx = test_scenario::ctx(scenario);
            hd::update_min_stake(&mut house_data, tc::get_min_stake()*2, ctx);
            test_scenario::return_shared(house_data);
        };

        // Check if min stake has been updated.
        test_scenario::next_tx(scenario, house);
        {
            let house_data = test_scenario::take_shared<HouseData>(scenario);
            let min_stake = hd::min_stake(&house_data);
            assert!(min_stake == tc::get_min_stake()*2, EWrongMaxStake);
            test_scenario::return_shared(house_data);
        };

        test_scenario::end(scenario_val);
    }

    // ------------- Rainy day tests -------------

    #[test]
    #[expected_failure(abort_code = hd::ECallerNotHouse)]
    fun caller_not_house_on_withdraw() {
        let house = @0xCAFE;
        let player = @0xDECAF;

        let scenario_val = test_scenario::begin(house);
        let scenario = &mut scenario_val;
        {
            fund_house(scenario, house, tc::get_initial_house_balance());
        };

        tc::init_house(scenario, house, true);

        // Non house address tries to withdraw.
        test_scenario::next_tx(scenario, player);
        {
            let house_data = test_scenario::take_shared<HouseData>(scenario);
            let ctx = test_scenario::ctx(scenario);
            hd::withdraw(&mut house_data, ctx);
            test_scenario::return_shared(house_data);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = hd::ECallerNotHouse)]
    fun caller_not_house_on_claim_fees() {
        let house = @0xCAFE;
        let player = @0xDECAF;

        let scenario_val = test_scenario::begin(house);
        let scenario = &mut scenario_val;
        {
            fund_house(scenario, house, tc::get_initial_house_balance());
        };

        tc::init_house(scenario, house, true);

        // Non house address tries to claim fees.
        test_scenario::next_tx(scenario, player);
        {
            let house_data = test_scenario::take_shared<HouseData>(scenario);
            let ctx = test_scenario::ctx(scenario);
            hd::claim_fees(&mut house_data, ctx);
            test_scenario::return_shared(house_data);
        };

        test_scenario::end(scenario_val);
    }


    #[test]
    #[expected_failure(abort_code = hd::EInsufficientBalance)]
    fun house_wrong_initialization() {
        let house = @0xCAFE;

        let scenario_val = test_scenario::begin(house);
        let scenario = &mut scenario_val;
        {
            fund_house(scenario, house, 0);
        };

        // Should throw because house has no funds.
        tc::init_house(scenario, house, true);

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = hd::ECallerNotHouse)]
    fun caller_not_house_on_update_max_stake() {
        let house = @0xCAFE;
        let player = @0xDECAF;

        let scenario_val = test_scenario::begin(house);
        let scenario = &mut scenario_val;
        {
            fund_house(scenario, house, tc::get_initial_house_balance());
        };

        tc::init_house(scenario, house, true);

        // Non house address tries to update max stake.
        test_scenario::next_tx(scenario, player);
        {
            let house_data = test_scenario::take_shared<HouseData>(scenario);
            let ctx = test_scenario::ctx(scenario);
            hd::update_max_stake(&mut house_data, tc::get_max_stake()*2, ctx);
            test_scenario::return_shared(house_data);
        };

        test_scenario::end(scenario_val);
    }

    #[test]
    #[expected_failure(abort_code = hd::ECallerNotHouse)]
    fun caller_not_house_on_update_min_stake() {
        let house = @0xCAFE;
        let player = @0xDECAF;

        let scenario_val = test_scenario::begin(house);
        let scenario = &mut scenario_val;
        {
            fund_house(scenario, house, tc::get_initial_house_balance());
        };

        tc::init_house(scenario, house, true);

        // Non house address tries to update min stake.
        test_scenario::next_tx(scenario, player);
        {
            let house_data = test_scenario::take_shared<HouseData>(scenario);
            let ctx = test_scenario::ctx(scenario);
            hd::update_min_stake(&mut house_data, tc::get_min_stake()*2, ctx);
            test_scenario::return_shared(house_data);
        };

        test_scenario::end(scenario_val);
    }
}