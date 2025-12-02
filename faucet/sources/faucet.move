module faucet::faucet;

// === Imports ===
use sui::coin::{Self, Coin};
use sui::balance::{Self, Balance};
use sui::sui::SUI;
use sui::table::{Self, Table};
use sui::event;
// === Errors ===
const EInsufficientBalance: u64 = 0;
const EClaimTooSoon: u64 = 1;
const ENotAdmin: u64 = 2;
// === Constants ===
const CLAIM_AMOUNT: u64 = 10_000_000_000; // 10 SUI 
const COOLDOWN_PERIOD: u64 = 86_400_000; // 24 hours in millis
// === Structs ===
public struct Faucet has key{
    id: UID,
    balance: Balance<SUI>,
    last_claims: Table<address, u64>,
    admin: address,
}
public struct AdminCap has key,store{
    id: UID,
}
// === Events ===
public struct ClaimEvent has copy, drop{
    claimer: address,
    amount: u64,
    timestamp: u64,
}
// ===Init function===
fun init( ctx: &mut TxContext){
    let faucet = Faucet {
        id:object::new(ctx),
        balance: balance::zero(),
        last_claims: table::new(ctx),
        admin: ctx.sender(),
    };
    let admin_cap= AdminCap { id: object::new(ctx) };
    transfer::share_object(faucet);
    transfer::transfer(admin_cap, ctx.sender());
}
// === Method Aliases ===

// === Public Functions ===
public entry fun deposit(faucet: &mut Faucet, coin: Coin<SUI>){
    let coin_balance = coin::into_balance(coin);
    balance::join(&mut faucet.balance, coin_balance);
}

public entry fun claim(faucet: &mut Faucet, clock: &sui::clock::Clock, ctx: &mut TxContext){
    let sender = ctx.sender();
    let current_time= sui::clock::timestamp_ms(clock);
    if (table::contains(&faucet.last_claims, sender)){
        let last_claim = *table::borrow(&faucet.last_claims, sender);
        assert!(current_time >= last_claim + COOLDOWN_PERIOD, EClaimTooSoon);
        table::remove(&mut faucet.last_claims, sender);
    };
    assert!(balance::value(&faucet.balance) >= CLAIM_AMOUNT, EInsufficientBalance);
    table::add(&mut faucet.last_claims, sender, current_time);

    let claim_balance = balance::split(&mut faucet.balance, CLAIM_AMOUNT);
    let claim_coin = coin::from_balance(claim_balance, ctx);
    transfer::public_transfer(claim_coin, sender);

    event::emit(ClaimEvent {
        claimer: sender,
        amount: CLAIM_AMOUNT,
        timestamp: current_time,
    });
}
// === View Functions ===
public fun get_balance(faucet: &Faucet): u64 {
        balance::value(&faucet.balance)
    }

public fun get_claim_amount(): u64 {
    CLAIM_AMOUNT
}

public fun get_cooldown_period(): u64 {
    COOLDOWN_PERIOD
}

public fun has_claimed(faucet: &Faucet, user: address): bool {
    table::contains(&faucet.last_claims, user)
}

public fun get_last_claim_time(faucet: &Faucet, user: address): u64 {
    if (table::contains(&faucet.last_claims, user)) {
        *table::borrow(&faucet.last_claims, user)
    } else {
        0
    }
}

public fun can_claim(
    faucet: &Faucet,
    user: address,
    current_time: u64
): bool {
    if (!table::contains(&faucet.last_claims, user)) {
        return true
    };

    let last_claim = *table::borrow(&faucet.last_claims, user);
    current_time >= last_claim + COOLDOWN_PERIOD
}
// === Admin Functions ===
public entry fun withdraw(_admin_cap: &AdminCap, faucet: &mut Faucet, amount: u64, ctx:&mut TxContext){
    assert!(balance::value(&faucet.balance) >= amount, EInsufficientBalance);
        
    let withdraw_balance = balance::split(&mut faucet.balance, amount);
    let withdraw_coin = coin::from_balance(withdraw_balance, ctx);
    transfer::public_transfer(withdraw_coin, ctx.sender());
}
public entry fun reset_cooldown(_admin_cap: &AdminCap, faucet: &mut Faucet, user: address){
    if(table::contains(&faucet.last_claims, user)){
        table::remove(&mut faucet.last_claims, user);
    };
}
// === Test Functions ===
#[test_only]
public fun init_for_testing(ctx: &mut TxContext) {
        init(ctx);
}
