pragma solidity 0.4.15;


//This contract is meant as a "singleton" forwarding contract.
//Eventually, it will be able to forward any transaction to
//Any contract that is built to accept it.
contract TxRelay {

    // Note: This is a local nonce.
    // Different from the nonce defined w/in protocol.
    mapping(address => uint) nonce;

    mapping(uint => mapping(address => bool)) public whitelist;
    mapping(uint => address) public listOwner;

    /*
     * @dev Relays meta transactions
     * @param sigV, sigR, sigS ECDSA signature on some data to be forwarded
     * @param destination Location the meta-tx should be forwarded to
     * @param data The bytes necessary to call the function in the destination contract.
     Note, the first encoded argument in data must be address of the signer
     */
    function relayMetaTx(
        uint8 sigV,
        bytes32 sigR,
        bytes32 sigS,
        address destination,
        bytes data,
        uint listNum
    ) public {

        // only allow senders from the whitelist specified by the user,
        // 0 means no whitelist.
        require(listNum == 0 || whitelist[listNum][msg.sender]);

        address claimedSender = getAddress(data);
        // relay :: whitelist :: nonce :: destination :: data
        bytes32 h = keccak256(this, listNum, nonce[claimedSender], destination, data);
        address addressFromSig = ecrecover(h, sigV, sigR, sigS);

        require(claimedSender == addressFromSig);

        nonce[claimedSender]++; //if we are going to do tx, update nonce

        require(destination.call(data));
    }

    /*
     * @dev Gets an address encoded as the first argument in transaction data
     * @param b The byte array that should have an address as first argument
     * @returns a The address retrieved from the array
     (Optimization based on work by tjade273)
     */
    function getAddress(bytes b) public constant returns (address a) {
        if (b.length < 36) return address(0);
        assembly {
            let mask := 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
            a := and(mask, mload(add(b, 36)))
            //36 is the offset of the first param of the data, if encoded properly.
            //4 bytes for the function signature, and 32 for the addess.
        }
    }

    /*
     * @dev Returns the local nonce of an account.
     * @param add The address to return the nonce for.
     * @return The specific-to-this-contract nonce of the address provided
     */
    function getNonce(address add) public constant returns (uint) {
        return nonce[add];
    }

    /*
     * @dev Adds a number of addresses to a specific whitelist. Only
     * the owner of a whitelist can add to it.
     * @param listNum The list number
     * @param sendersToUpdate the addresses to add to the whitelist
     */
    function addToWhitelist(uint listNum, address[] sendersToUpdate) public {
        if (listOwner[listNum] == 0x0) {
            listOwner[listNum] = msg.sender;
        }
        updateWhitelist(listNum, sendersToUpdate, true);
    }

    /*
     * @dev Removes a number of addresses from a specific whitelist. Only
     * the owner of a whitelist can remove from it.
     * @param listNum The list number
     * @param sendersToUpdate the addresses to add to the whitelist
     */
    function removeFromWhitelist(uint listNum, address[] sendersToUpdate) public {
        updateWhitelist(listNum, sendersToUpdate, false);
    }

    /*
     * @dev Internal logic to update a whitelist
     * @param listNum The list number
     * @param sendersToUpdate the addresses to add to the whitelist
     * @param newStatus whether to add or remove addresses
     */
    function updateWhitelist(uint listNum, address[] sendersToUpdate, bool newStatus) private {
        // list 0 can not be owned
        require(listNum != 0);
        // list must be owned by msg.sender
        require(listOwner[listNum] == msg.sender);

        for (uint i = 0; i < sendersToUpdate.length; i++) {
            whitelist[listNum][sendersToUpdate[i]] = newStatus;
        }
    }
}
