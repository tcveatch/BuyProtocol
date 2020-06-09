// Bugs found:
//   JtoS?ACCEPTED left out; fixed. 

mtype = { OFFERSELLER, OFFERBUYER, AGREED, RECEIPTQ, ACCEPTED, PAYMENT, NTP, DELIVERING }

chan BtoJ = [1] of {mtype};
chan JtoB = [1] of {mtype};
chan StoJ = [1] of {mtype};
chan JtoS = [1] of {mtype};

init { atomic { run Buyer(); run Seler(); run Judge() } }

proctype Buyer() {
  BtoJ!OFFERSELLER; // 1a Buyer, having found seller/item/terms finds a judge to run it.
  JtoB?AGREED; // 5b Deal is agreed.  No further handshake at this protocol level 
  JtoB?RECEIPTQ;  // 8b time to check operation complete, deliverable acceptable
  // await receiveables.  Receive them.  Inspect them, determine acceptable.
  BtoJ!ACCEPTED; // 9a deliverable is accepted.  Release payment
  BtoJ!PAYMENT    // 10a payment herewith
}

proctype Seler() {
  JtoS?OFFERBUYER; // 3b offer arrives at seller
  StoJ!AGREED; // 4a seller agrees to offer
  JtoS?NTP; // 6b NTP arrives at seller
  // Proceed. When done (shipped, performed, etc.) notify Judge.
  StoJ!DELIVERING; // 7a Operation complete
  JtoS?ACCEPTED; // 9d buyer accepted deliverable.
  JtoS?PAYMENT // 11b receiving payment from seller via judge.
}

proctype Judge() {
  BtoJ?OFFERSELLER;  // 1b
  JtoS!OFFERBUYER;  // 3a passing the offer on.
  StoJ?AGREED; // 4b seller has agreed to offer
  JtoB!AGREED; // 5a tell buyer it's on.
  JtoS!NTP;    // 6a Notice to Proceed: tell seller to deliver
  StoJ?DELIVERING; // 7b seller claims operation complete
  JtoB!RECEIPTQ;  // 8a ask buyer to confirm operation complete, deliverable accepted
  BtoJ?ACCEPTED; // 9b deliverable was accepted, buyer should pay now.
  JtoS!ACCEPTED; // 9c informing seller buyer accepted deliverable.
  BtoJ?PAYMENT;    // 10b receiving buyer payment herewith to forward to seller.
  JtoS!PAYMENT;    // 11a sending payment to seller.
}
