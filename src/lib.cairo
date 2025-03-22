use core::starknet::ContractAddress;

// defining the interface
#[starknet::interface]
pub trait IERC20<TContractState> {
    // read functions
    // get the name of the token
    fn get_name(self: @TContractState) -> felt252;
    // get the symbol of the token
    fn get_symbol(self: @TContractState) -> felt252;
    // get the decimals value of the token
    fn get_decimals(self: @TContractState) -> u8;
    // get the total supply of the token
    fn get_total_supply(self: @TContractState) -> u256;
    // get the balance of the token
    fn balance_of(self: @TContractState, account: ContractAddress) -> u256;
    // return the specific account balance of the token
    fn allowance(
        self: @TContractState, owner: ContractAddress, spender: ContractAddress,
    ) -> u256;
    // write functions
    // transfer function to transfer fund to user and also the amount
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: u256);
    // transfer function from sender to reciver and the amount
    fn transfer_from(
        ref self: TContractState,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: u256,
    );
    // fund approved by sender to be spent
    fn approve(ref self: TContractState, spender: ContractAddress, amount: u256);
    // add to what a contract or dapp is permitted to spend
    fn increase_allowance(ref self: TContractState, spender: ContractAddress, added_value: u256);
    // subtract to what a contract or dapp is permitted to spend
    fn decrease_allowance(
        ref self: TContractState, spender: ContractAddress, subtracted_value: u256,
    );
}

// defining the contract
#[starknet::contract]
pub mod erc20 {
    // importing the is non zero function
    use core::num::traits::Zero;
    // importing map, entry, read and write
    use starknet::storage::{
        StoragePathEntry, StoragePointerWriteAccess, Map, StoragePointerReadAccess,
    };
    // import the contract address
    use core::starknet::ContractAddress;
    // imported the get caller address
    use core::starknet::get_caller_address;

    // storage function
    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: u256,
        balances: Map::<ContractAddress, u256>,
        allowances: Map::<(ContractAddress, ContractAddress), u256>,
    }

    // defining event
    #[event]
    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub enum Event {
        Transfer: Transfer,
        Approval: Approval,
    }

    // defining Transfer Event
    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct Transfer {
        pub from: ContractAddress,
        pub to: ContractAddress,
        pub value: u256,
    }

    // defining Approval Event
    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct Approval {
        pub owner: ContractAddress,
        pub spender: ContractAddress,
        pub value: u256,
    }

    // defining constructor
    #[constructor]
    fn constructor(
        ref self: ContractState,
        recipient: ContractAddress,
        name: felt252,
        decimals: u8,
        total_supply: u256,
        symbol: felt252,
    ) {
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        self.total_supply.write(total_supply);
        self.balances.entry(recipient).write(total_supply);
    }

    // function implementation
    #[abi(embed_v0)]
    impl IERC20Impl of super::IERC20<ContractState> {
        fn get_name(self: @ContractState) -> felt252 {
            self.name.read()
        }

        fn get_symbol(self: @ContractState) -> felt252 {
            self.symbol.read()
        }

        fn get_decimals(self: @ContractState) -> u8 {
            self.decimals.read()
        }

        fn get_total_supply(self: @ContractState) -> u256 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            self.balances.entry(account).read()
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> u256 {
            self.allowances.entry((owner, spender)).read()
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: u256) {
            let sender = get_caller_address();
            assert!(!sender.is_zero(), "Cannot call with zero address");
            assert!(!recipient.is_zero(), "Cannot transfer to zero address");
            let sender_balance = self.balances.entry(sender).read();
            let recipient_balance = self.balances.entry(recipient).read();
            assert!(sender_balance >= amount, "Cannot transfer more than what you have");
            self.balances.entry(sender).write(sender_balance - amount);
            self.balances.entry(recipient).write(recipient_balance + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: u256,
        ) {
            assert!(!sender.is_zero(), "Cannot send from zero address");
            assert!(!recipient.is_zero(), "Cannot send to zero address");
            let current_allowances = self.allowances.entry((sender, recipient)).read();
            let new_allowances = current_allowances - amount;
            self.allowances.entry((sender, recipient)).write(new_allowances);
            let sender_balance = self.balances.entry(sender).read();
            let recipient_balance = self.balances.entry(recipient).read();
            assert!(sender_balance >= amount, "Cannot transfer more than what you have");
            self.balances.entry(sender).write(sender_balance - amount);
            self.balances.entry(recipient).write(recipient_balance + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: u256) {
            let owner = get_caller_address();
            assert!(!owner.is_zero(), "Owner should not be zero address");
            assert!(!spender.is_zero(), "Spender should not be zerro address");
            self.allowances.entry((owner, spender)).write(amount);
        }

        fn increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: u256,
        ) {
            let owner = get_caller_address();
            assert!(!owner.is_zero(), "Owner should not be zero address");
            assert!(!spender.is_zero(), "Spender should not be zerro address");
            let owner_balance = self.balances.entry(owner).read();
            let current_allowance =  self.allowances.entry((owner, spender)).read();
            assert!(owner_balance >= added_value, "Cannot increase allowances by more than balance");
            self.balances.entry(owner).write(owner_balance - added_value);
            self.allowances.entry((owner, spender)).write(current_allowance + added_value);
            self.emit(Event::Approval(Approval{
                owner,
                spender,
                value: added_value,
            }));
        }

        fn decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: u256,
        ) {
            let owner = get_caller_address();
            assert!(!owner.is_zero(), "Owner should not be zero address");
            assert!(!spender.is_zero(), "Spender should not be zerro address");
            let owner_balance = self.balances.entry(owner).read();
            let current_allowance =  self.allowances.entry((owner, spender)).read();
            assert!(owner_balance >= subtracted_value, "Cannot deduct allowances by more than balance");
            self.balances.entry(owner).write(owner_balance + subtracted_value);
            self.allowances.entry((owner, spender)).write(current_allowance - subtracted_value);
            self.emit(Event::Approval(Approval{
                owner,
                spender,
                value: subtracted_value,
            }));
        }
    }
}
