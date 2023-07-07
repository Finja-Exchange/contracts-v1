// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

contract PaymentMethodsContract is Ownable {

    struct PaymentMethod {
        string name;
        string description;
        string region;
        bool active;
    }
    
    PaymentMethod[] public paymentMethods;

    function addPaymentMethod(string memory name, string memory description, string memory region) public onlyOwner {
        require(bytes(name).length > 0, "Name must not be empty");
        paymentMethods.push(PaymentMethod({name: name, description: description, active: true, region: region}));
    }

    function deactivatePaymentMethod(uint256 paymentMethodId) public onlyOwner {
        require(paymentMethodId < paymentMethods.length, "Payment method does not exist");
        paymentMethods[paymentMethodId].active = false;
    }

    function reactivatePaymentMethod(uint256 paymentMethodId) public onlyOwner {
    require(paymentMethodId < paymentMethods.length, "Payment method does not exist");
    paymentMethods[paymentMethodId].active = true;
}

    function updatePaymentMethod(uint256 paymentMethodId, string memory name, string memory description, string memory region) public onlyOwner {
    require(paymentMethodId < paymentMethods.length, "Payment method does not exist");
    require(bytes(name).length > 0, "Name must not be empty");
    paymentMethods[paymentMethodId].name = name;
    paymentMethods[paymentMethodId].description = description;
    paymentMethods[paymentMethodId].region = region;
}

    
    function getPaymentMethod(uint256 paymentMethodId) public view returns (string memory, string memory, string memory, bool) {
        require(paymentMethodId < paymentMethods.length, "Payment method does not exist");
        return (paymentMethods[paymentMethodId].name, paymentMethods[paymentMethodId].description, paymentMethods[paymentMethodId].region, paymentMethods[paymentMethodId].active);
    }

    function getPaymentMethodCount() public view returns (uint256) {
        return paymentMethods.length;
    }

    
}
