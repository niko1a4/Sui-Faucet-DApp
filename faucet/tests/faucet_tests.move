#[test_only]
module faucet::faucet_tests {
    use sui::test_scenario::{Self as ts, Scenario};
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
    use sui::clock::{Self, Clock};
    use faucet::faucet::{Self, Faucet, AdminCap};

    const ADMIN: address = @0xAD;
    const USER1: address = @0xA1;
    const USER2: address = @0xA2;

    const CLAIM_AMOUNT: u64 = 10_000_000_000; // 10 SUI (updated to match contract)
    const COOLDOWN_PERIOD: u64 = 86_400_000; // 24 hours in ms

    // Helper function to create a test coin
    fun mint_for_testing(amount: u64, scenario: &mut Scenario): Coin<SUI> {
        coin::mint_for_testing<SUI>(amount, ts::ctx(scenario))
    }

    #[test]
    fun test_init_faucet() {
        let mut scenario = ts::begin(ADMIN);

        // Initialize the faucet
        {
            faucet::init_for_testing(ts::ctx(&mut scenario));
        };

        // Check that faucet was created and shared
        ts::next_tx(&mut scenario, ADMIN);
        {
            let faucet = ts::take_shared<Faucet>(&scenario);
            assert!(faucet::get_balance(&faucet) == 0, 0);
            ts::return_shared(faucet);

            // Check that admin cap was transferred to admin
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            ts::return_to_sender(&scenario, admin_cap);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_deposit_funds() {
        let mut scenario = ts::begin(ADMIN);

        // Initialize faucet
        {
            faucet::init_for_testing(ts::ctx(&mut scenario));
        };

        // Deposit funds
        ts::next_tx(&mut scenario, USER1);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let deposit_coin = mint_for_testing(100_000_000_000, &mut scenario); // 100 SUI
            
            faucet::deposit(&mut faucet, deposit_coin);
            
            ts::return_shared(faucet);
        };

        // Check balance in next transaction
        ts::next_tx(&mut scenario, USER1);
        {
            let faucet = ts::take_shared<Faucet>(&scenario);
            assert!(faucet::get_balance(&faucet) == 100_000_000_000, 0);
            ts::return_shared(faucet);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_successful_claim() {
        let mut scenario = ts::begin(ADMIN);

        // Initialize faucet
        {
            faucet::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::share_for_testing(clock);
        };

        // Deposit funds
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let deposit_coin = mint_for_testing(CLAIM_AMOUNT, &mut scenario);
            faucet::deposit(&mut faucet, deposit_coin);
            ts::return_shared(faucet);
        };

        // User claims tokens (in a new transaction after deposit)
        ts::next_tx(&mut scenario, USER1);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);

            faucet::claim(&mut faucet, &clock, ts::ctx(&mut scenario));

            ts::return_shared(clock);
            ts::return_shared(faucet);
        };

        // Check after claim
        ts::next_tx(&mut scenario, USER1);
        {
            let faucet = ts::take_shared<Faucet>(&scenario);
            
            // Check faucet balance decreased to 0
            assert!(faucet::get_balance(&faucet) == 0, 0);
            
            // Check user has claimed
            assert!(faucet::has_claimed(&faucet, USER1), 1);
            
            ts::return_shared(faucet);

            // Verify user received the tokens
            let claimed_coin = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&claimed_coin) == CLAIM_AMOUNT, 2);
            ts::return_to_sender(&scenario, claimed_coin);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = ts::take_shared<Clock>(&scenario);
            clock::destroy_for_testing(clock);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_multiple_users_can_claim() {
        let mut scenario = ts::begin(ADMIN);

        // Initialize
        {
            faucet::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::share_for_testing(clock);
        };

        // Deposit funds
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let deposit_coin = mint_for_testing(2 * CLAIM_AMOUNT, &mut scenario);
            faucet::deposit(&mut faucet, deposit_coin);
            ts::return_shared(faucet);
        };

        // USER1 claims (in new transaction after deposit)
        ts::next_tx(&mut scenario, USER1);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            faucet::claim(&mut faucet, &clock, ts::ctx(&mut scenario));
            ts::return_shared(clock);
            ts::return_shared(faucet);
        };

        // USER2 claims
        ts::next_tx(&mut scenario, USER2);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            faucet::claim(&mut faucet, &clock, ts::ctx(&mut scenario));
            ts::return_shared(clock);
            ts::return_shared(faucet);
        };

        // Check results
        ts::next_tx(&mut scenario, ADMIN);
        {
            let faucet = ts::take_shared<Faucet>(&scenario);
            
            // Both users should have claimed
            assert!(faucet::has_claimed(&faucet, USER1), 0);
            assert!(faucet::has_claimed(&faucet, USER2), 1);

            // Balance should be 0 after both claims
            assert!(faucet::get_balance(&faucet) == 0, 2);

            ts::return_shared(faucet);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = ts::take_shared<Clock>(&scenario);
            clock::destroy_for_testing(clock);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 1)]
    fun test_cannot_claim_before_cooldown() {
        let mut scenario = ts::begin(ADMIN);

        // Initialize
        {
            faucet::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::share_for_testing(clock);
        };

        // Deposit funds
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let deposit_coin = mint_for_testing(2 * CLAIM_AMOUNT, &mut scenario);
            faucet::deposit(&mut faucet, deposit_coin);
            ts::return_shared(faucet);
        };

        // First claim (in new transaction after deposit)
        ts::next_tx(&mut scenario, USER1);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            faucet::claim(&mut faucet, &clock, ts::ctx(&mut scenario));
            ts::return_shared(clock);
            ts::return_shared(faucet);
        };

        // Try to claim again immediately (should fail with EClaimTooSoon = 1)
        ts::next_tx(&mut scenario, USER1);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            
            faucet::claim(&mut faucet, &clock, ts::ctx(&mut scenario));
            
            ts::return_shared(clock);
            ts::return_shared(faucet);
        };

        abort 1
    }

    #[test]
    fun test_can_claim_after_cooldown() {
        let mut scenario = ts::begin(ADMIN);

        // Initialize
        {
            faucet::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::share_for_testing(clock);
        };

        // Deposit funds
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let deposit_coin = mint_for_testing(2 * CLAIM_AMOUNT, &mut scenario);
            faucet::deposit(&mut faucet, deposit_coin);
            ts::return_shared(faucet);
        };

        // First claim (in new transaction after deposit)
        ts::next_tx(&mut scenario, USER1);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            faucet::claim(&mut faucet, &clock, ts::ctx(&mut scenario));
            ts::return_shared(clock);
            ts::return_shared(faucet);
        };

        // Advance clock past cooldown period
        ts::next_tx(&mut scenario, USER1);
        {
            let mut clock = ts::take_shared<Clock>(&scenario);
            clock::increment_for_testing(&mut clock, COOLDOWN_PERIOD + 1000);
            ts::return_shared(clock);
        };

        // Second claim should succeed
        ts::next_tx(&mut scenario, USER1);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            
            faucet::claim(&mut faucet, &clock, ts::ctx(&mut scenario));
            
            ts::return_shared(clock);
            ts::return_shared(faucet);
        };

        // Check results
        ts::next_tx(&mut scenario, ADMIN);
        {
            let faucet = ts::take_shared<Faucet>(&scenario);
            
            // Should have claimed twice, balance should be 0
            assert!(faucet::get_balance(&faucet) == 0, 0);
            
            ts::return_shared(faucet);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = ts::take_shared<Clock>(&scenario);
            clock::destroy_for_testing(clock);
        };

        ts::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 0)]
    fun test_cannot_claim_with_insufficient_balance() {
        let mut scenario = ts::begin(ADMIN);

        // Initialize
        {
            faucet::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::share_for_testing(clock);
        };

        // Deposit insufficient funds
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let deposit_coin = mint_for_testing(CLAIM_AMOUNT - 1, &mut scenario); // Less than claim amount
            faucet::deposit(&mut faucet, deposit_coin);
            ts::return_shared(faucet);
        };

        // Try to claim (should fail with EInsufficientBalance = 0)
        ts::next_tx(&mut scenario, USER1);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            
            faucet::claim(&mut faucet, &clock, ts::ctx(&mut scenario));
            
            ts::return_shared(clock);
            ts::return_shared(faucet);
        };

        abort 0
    }

    #[test]
    fun test_admin_withdraw() {
        let mut scenario = ts::begin(ADMIN);

        // Initialize
        {
            faucet::init_for_testing(ts::ctx(&mut scenario));
        };

        // Deposit funds
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let deposit_coin = mint_for_testing(100_000_000_000, &mut scenario); // 100 SUI
            faucet::deposit(&mut faucet, deposit_coin);
            ts::return_shared(faucet);
        };

        // Admin withdraws funds (in new transaction after deposit)
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            
            faucet::withdraw(&admin_cap, &mut faucet, 50_000_000_000, ts::ctx(&mut scenario)); // Withdraw 50 SUI
            
            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(faucet);
        };

        // Check balance in next transaction
        ts::next_tx(&mut scenario, ADMIN);
        {
            let faucet = ts::take_shared<Faucet>(&scenario);
            assert!(faucet::get_balance(&faucet) == 50_000_000_000, 0);
            ts::return_shared(faucet);

            // Verify admin received the tokens
            let withdrawn_coin = ts::take_from_sender<Coin<SUI>>(&scenario);
            assert!(coin::value(&withdrawn_coin) == 50_000_000_000, 1);
            ts::return_to_sender(&scenario, withdrawn_coin);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_admin_reset_cooldown() {
        let mut scenario = ts::begin(ADMIN);

        // Initialize
        {
            faucet::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::share_for_testing(clock);
        };

        // Deposit funds
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let deposit_coin = mint_for_testing(2 * CLAIM_AMOUNT, &mut scenario);
            faucet::deposit(&mut faucet, deposit_coin);
            ts::return_shared(faucet);
        };

        // User claims (in new transaction after deposit)
        ts::next_tx(&mut scenario, USER1);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            faucet::claim(&mut faucet, &clock, ts::ctx(&mut scenario));
            ts::return_shared(clock);
            ts::return_shared(faucet);
        };

        // Check claim status
        ts::next_tx(&mut scenario, ADMIN);
        {
            let faucet = ts::take_shared<Faucet>(&scenario);
            assert!(faucet::has_claimed(&faucet, USER1), 0);
            ts::return_shared(faucet);
        };

        // Admin resets cooldown
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let admin_cap = ts::take_from_sender<AdminCap>(&scenario);
            
            faucet::reset_cooldown(&admin_cap, &mut faucet, USER1);
            
            ts::return_to_sender(&scenario, admin_cap);
            ts::return_shared(faucet);
        };

        // Check cooldown was reset
        ts::next_tx(&mut scenario, ADMIN);
        {
            let faucet = ts::take_shared<Faucet>(&scenario);
            // User should be able to claim again immediately
            assert!(!faucet::has_claimed(&faucet, USER1), 1);
            ts::return_shared(faucet);
        };

        // User can claim again immediately
        ts::next_tx(&mut scenario, USER1);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            
            faucet::claim(&mut faucet, &clock, ts::ctx(&mut scenario));
            
            ts::return_shared(clock);
            ts::return_shared(faucet);
        };

        // Check results
        ts::next_tx(&mut scenario, ADMIN);
        {
            let faucet = ts::take_shared<Faucet>(&scenario);
            
            // Balance should be 0 after 2 claims
            assert!(faucet::get_balance(&faucet) == 0, 2);
            
            ts::return_shared(faucet);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = ts::take_shared<Clock>(&scenario);
            clock::destroy_for_testing(clock);
        };

        ts::end(scenario);
    }

    #[test]
    fun test_view_functions() {
        let mut scenario = ts::begin(ADMIN);

        // Initialize
        {
            faucet::init_for_testing(ts::ctx(&mut scenario));
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = clock::create_for_testing(ts::ctx(&mut scenario));
            clock::share_for_testing(clock);
        };

        // Test constants
        ts::next_tx(&mut scenario, ADMIN);
        {
            assert!(faucet::get_claim_amount() == CLAIM_AMOUNT, 0);
            assert!(faucet::get_cooldown_period() == COOLDOWN_PERIOD, 1);
        };

        // Deposit
        ts::next_tx(&mut scenario, ADMIN);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let deposit_coin = mint_for_testing(CLAIM_AMOUNT, &mut scenario);
            faucet::deposit(&mut faucet, deposit_coin);
            ts::return_shared(faucet);
        };

        // Claim (in new transaction after deposit)
        ts::next_tx(&mut scenario, USER1);
        {
            let mut faucet = ts::take_shared<Faucet>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            
            // Check before claim
            assert!(!faucet::has_claimed(&faucet, USER1), 2);
            assert!(faucet::can_claim(&faucet, USER1, clock::timestamp_ms(&clock)), 3);
            
            faucet::claim(&mut faucet, &clock, ts::ctx(&mut scenario));
            
            ts::return_shared(clock);
            ts::return_shared(faucet);
        };

        // Check after claim
        ts::next_tx(&mut scenario, USER1);
        {
            let faucet = ts::take_shared<Faucet>(&scenario);
            let clock = ts::take_shared<Clock>(&scenario);
            
            // Check after claim
            assert!(faucet::has_claimed(&faucet, USER1), 4);
            assert!(!faucet::can_claim(&faucet, USER1, clock::timestamp_ms(&clock)), 5);
            assert!(faucet::get_last_claim_time(&faucet, USER1) == clock::timestamp_ms(&clock), 6);
            
            ts::return_shared(clock);
            ts::return_shared(faucet);
        };

        ts::next_tx(&mut scenario, ADMIN);
        {
            let clock = ts::take_shared<Clock>(&scenario);
            clock::destroy_for_testing(clock);
        };

        ts::end(scenario);
    }
}