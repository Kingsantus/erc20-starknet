use core::starknet::ContractAddress;

// defining the interface
#[starknet::interface]
pub trait IERC20<TContractState> {
    // read functions
    fn get_name(self: @TContractState) -> felt252;
    fn get_symbol(self: @TContractState) -> felt252;
    fn get_decimals(self: @TContractState) -> u8;
    fn get_total_supply(self: @TContractState) -> felt252;
    fn balance_of(self: @TContractState, account: ContractAddress) -> felt252;
    fn allowance(
        self: @TContractState, owner: ContractAddress, spender: ContractAddress,
    ) -> felt252;
    // write functions
    fn transfer(ref self: TContractState, recipient: ContractAddress, amount: felt252);
    fn transfer_from(
        ref self: TContractState,
        sender: ContractAddress,
        recipient: ContractAddress,
        amount: felt252,
    );
    fn approve(ref self: TContractState, spender: ContractAddress, amount: felt252);
    fn increase_allowance(ref self: TContractState, spender: ContractAddress, added_value: felt252);
    fn decrease_allowance(
        ref self: TContractState, spender: ContractAddress, subtracted_value: felt252,
    );
}

// defining the contract
#[starknet::contract]
pub mod erc20 {
    use core::starknet::contract_address_const;
    use core::num::traits::Zero;
    use starknet::storage::{
        StoragePathEntry, StoragePointerWriteAccess, Map, StoragePointerReadAccess,
    };
    use core::starknet::ContractAddress;
    use core::starknet::get_caller_address;

    // storage function
    #[storage]
    struct Storage {
        name: felt252,
        symbol: felt252,
        decimals: u8,
        total_supply: felt252,
        balances: Map::<ContractAddress, felt252>,
        allowances: Map::<(ContractAddress, ContractAddress), felt252>,
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
        pub value: felt252,
    }

    // defining Approval Event
    #[derive(Copy, Drop, Debug, PartialEq, starknet::Event)]
    pub struct Approval {
        pub owner: ContractAddress,
        pub spender: ContractAddress,
        pub value: felt252,
    }

    // Defining errors information
    mod Errors {
        pub const APPROVE_FROM_ZERO: felt252 = 'ERC20: approve from 0';
        pub const APPROVE_TO_ZERO: felt252 = 'ERC20: approve to 0';
        pub const TRANSFER_FROM_ZERO: felt252 = 'ERC20: transfer from 0';
        pub const TRANSFER_TO_ZERO: felt252 = 'ERC20: transfer to 0';
        pub const BURN_FROM_ZERO: felt252 = 'ERC20: burn from 0';
        pub const MINT_TO_ZERO: felt252 = 'ERC20: mint to 0';
    }

    // defining constructor
    #[constructor]
    fn constructor(
        ref self: ContractState,
        recipient: ContractAddress,
        name: felt252,
        decimals: u8,
        initial_supply: felt252,
        symbol: felt252,
    ) {
        self.name.write(name);
        self.symbol.write(symbol);
        self.decimals.write(decimals);
        // self.total_supply.write(initial_supply);
        // self.balances.entry(recipient).write(total_supply);
        self.mint(recipient, initial_supply);
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

        fn get_total_supply(self: @ContractState) -> felt252 {
            self.total_supply.read()
        }

        fn balance_of(self: @ContractState, account: ContractAddress) -> felt252 {
            self.balances.entry(account).read()
        }

        fn allowance(
            self: @ContractState, owner: ContractAddress, spender: ContractAddress,
        ) -> felt252 {
            self.allowances.entry((owner, spender)).read()
        }

        fn transfer(ref self: ContractState, recipient: ContractAddress, amount: felt252) {
            let sender = get_caller_address();
            self._transfer(sender, recipient, amount);
            // let recipient_balance = self.balances.entry(recipient).read();
            // let new_recipient_balance = recipient_balance + amount;
            // self.balances.entry(recipient).write(new_recipient_balance);
        }

        fn transfer_from(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: felt252,
        ) {
            let caller = get_caller_address();
            self.spend_allowance(sender, caller, amount);
            self._transfer(sender, recipient, amount);
            // let recipient_balance = self.balances.entry(recipient).read();
            // let sender_balance = self.balances.entry(sender).read();
            // assert(sender_balance >= amount, "Cannot send more than balances");
            // self.balances.entry(sender).write(sender_balance - amount);
            // self.balances.entry(recipient).write(recipient_balance + amount);
        }

        fn approve(ref self: ContractState, spender: ContractAddress, amount: felt252) {
            let caller = get_caller_address();
            self.approve_helper(caller, spender, amount);
        }

        fn increase_allowance(
            ref self: ContractState, spender: ContractAddress, added_value: felt252,
        ) {
            let caller = get_caller_address();
            self
                .approve_helper(
                    caller, spender, self.allowances.entry((caller, spender)).read() + added_value,
                );
        }

        fn decrease_allowance(
            ref self: ContractState, spender: ContractAddress, subtracted_value: felt252,
        ) {
            let caller = get_caller_address();
            self
                .approve_helper(
                    caller,
                    spender,
                    self.allowances.entry((caller, spender)).read() - subtracted_value,
                );
        }
    }

    #[generate_trait]
    impl InternalImpl of InternalTrait {
        fn _transfer(
            ref self: ContractState,
            sender: ContractAddress,
            recipient: ContractAddress,
            amount: felt252,
        ) {
            assert(sender.is_non_zero(), Errors::TRANSFER_FROM_ZERO);
            assert(recipient.is_non_zero(), Errors::TRANSFER_TO_ZERO);
            self.balances.entry(sender).write(self.balances.entry(sender).read() - amount);
            self.balances.entry(recipient).write(self.balances.entry(recipient).read() + amount);
            self.emit(Transfer { from: sender, to: recipient, value: amount });
        }

        fn spend_allowance(
            ref self: ContractState,
            owner: ContractAddress,
            spender: ContractAddress,
            amount: felt252,
        ) {
            let allowance = self.allowances.entry((owner, spender)).read();
            self.allowances.entry((owner, spender)).write(allowance - amount);
        }

        fn approve_helper(
            ref self: ContractState,
            owner: ContractAddress,
            spender: ContractAddress,
            amount: felt252,
        ) {
            assert(spender.is_non_zero(), Errors::APPROVE_TO_ZERO);
            self.allowances.entry((owner, spender)).write(amount);
            self.emit(Approval { owner, spender, value: amount });
        }

        fn mint(ref self: ContractState, recipient: ContractAddress, amount: felt252) {
            assert(recipient.is_non_zero(), Errors::MINT_TO_ZERO);
            let supply = self.total_supply.read() + amount;
            self.total_supply.write(supply);
            let balance = self.balances.entry(recipient).read() + amount;
            self.balances.entry(recipient).write(balance);
            self
                .emit(
                    Event::Transfer(
                        Transfer {
                            from: contract_address_const::<0>(), to: recipient, value: amount,
                        },
                    ),
                );
        }
    }
}
