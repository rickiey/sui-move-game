module game::dice {
    use sui::object::{Self, UID};
    use sui::event;
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};
    use sui::sui::{SUI};
    use sui::coin::{Self,Coin};
    use sui::clock::{Self, Clock};

    use sui::balance::{Self, Balance};

    const StartFund:u64 = 512_000_000;
    // const StepFund:u64 = 256_000_000;


    const INVALID_OWNER_ERROR:u64 = 403;
    const Insufficient_Balance_ERROR:u64 = 400;
    const Insufficient_POOL_Balance_ERROR:u64 = 888;


    struct DICE has drop {}

    // struct FundPool Coin<SUI>;
    struct PlayEvent has copy,drop {
        palyer: address,
        palyer_dice: u64,
        random_dice: u64,
    }

    // 资金池
    struct FundPool has key {
        id: UID,
        balance: Balance<SUI>,
        owner:address,
    }

    fun init(_:DICE, ctx: &mut TxContext){
        let  sender =  tx_context::sender(ctx);

        let fundPool = FundPool{
            id: object::new(ctx),
            balance: balance::zero<SUI>(),
            owner: sender,
        };
        transfer::share_object(fundPool);
    }
    public entry fun Withdraw(fundPool: &mut FundPool, ctx: &mut TxContext) {
        let  sender =  tx_context::sender(ctx);
        assert!(sender == fundPool.owner, INVALID_OWNER_ERROR);

        let halfFund = balance::value<SUI>(&fundPool.balance)/2;
        let wblanace = coin::take(&mut fundPool.balance,halfFund,ctx);
        transfer::public_transfer(wblanace,sender);
    }
    

    public entry fun PlayDice(fundPool: &mut FundPool, palyDice : u64,clc : &Clock, pledge: &mut Coin<SUI>,ctx: &mut TxContext) {

        // let c = ctx.ids_created;

        // let c = clock::Clock{
        //     id: object::SUI_CLOCK_OBJECT_ID,
        //     timestamp_ms:0,
        // };
        // let pool = fundPool.balance;

        let quarter_fund =balance::value<SUI>(&fundPool.balance)/4;

        // 赢了拿一半
        let reward = balance::value<SUI>(&fundPool.balance)/2;

        // 使用的资金必须大于资金池的 1/4
        let suibalance = coin::value<SUI>(pledge);
        assert!(suibalance >= quarter_fund , Insufficient_Balance_ERROR);

        
        let curTs = clock::timestamp_ms(clc);
        let random_num = curTs % 6;

        let  sender =  tx_context::sender(ctx);
        // 如果输了：付出资金池 1/4 的代价
        if (palyDice%6 != random_num) {

            if (quarter_fund== 0) {
                quarter_fund = StartFund;
            };
            let penaltyFund= balance::split(coin::balance_mut(pledge),quarter_fund);
            let penaltyCoin = coin::from_balance(penaltyFund,ctx);
            coin::put(&mut fundPool.balance,penaltyCoin);
        // 赢了拿走资金池 1/2 
        }else {
            // 开始资金池没钱
            assert!(reward!= 0, Insufficient_POOL_Balance_ERROR);
            let winReward = coin::take(&mut fundPool.balance,reward,ctx);
            transfer::public_transfer(winReward,tx_context::sender(ctx));

        };
        let evt = PlayEvent { 
            palyer: sender,
            palyer_dice:palyDice%6,
            random_dice: random_num,
        };
        event::emit(evt);
    }

}