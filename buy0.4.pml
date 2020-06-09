// 0.1: No branching, first draft: offer, agreed, ntp, delivering, accepted, paid
// 0.2: escrow payment at judge required before NTP
// 0.3: clarify: terms negotiation outside of protocol;
//      the seller's offering, description, price, delivery method is brought by buyer to protocol.
//      so we just need buyer to send what they want (already gotten from
//      seller) and seller to confirm that's good with them.
// 0.4: buyer might delay full payment past a deadline and should get order cancelled and
//      a refund.

// Bugs found:
//   JtoS?ACCEPTED left out; fixed in 0.1
//   JtoB!AGREED left out; fixed in 0.3
//   Judge declares timeout on receiving full payment, tells Seller we've been ghosted,
//      all before NSF notice got to the buyer, which then proceeded to send PAYMENT
//      which doesn't even arrive before REFUND is returned to buyer.
//      So late/partial payment received late by Judge needs to be received and returned.
//      Fixed in 0.4

mtype = {
      	  OFFERSELLER, OFFERBUYER, AGREED,     RECEIPTQ,
          ACCEPTED,    PAYMENT,    NSF,        BACKOUT, 
	  REFUND,      NTP,        DELIVERING, REJECT,  CANCELLED, GHOSTED
	}

chan BtoJ = [1] of {mtype};
chan JtoB = [1] of {mtype};
chan StoJ = [1] of {mtype};
chan JtoS = [1] of {mtype};

init { atomic { run Buyer(); run Seler(); run Judge() } }

proctype Buyer() {
  // Seller publishes subscribing to protocol, item, params, price, delivery, schedule;
  // Buyer gets something from seller that seller will accept, submits to protocol,
  // and seller should accept it.
  // Buyer also needs to find a willing Judge. Send an open-transaction request to the
  // judge, if the judge responds then the judge agrees to be the Judge for this
  // transaction.
  BtoJ!OFFERSELLER; // Buyer, having found seller/item/terms finds a judge to run it.
  if
  :: JtoB?REJECT;   // Deal is rejected. Done.
  :: JtoB?AGREED;   // Deal is agreed.  No further handshake at this protocol level
     BtoJ!PAYMENT;  // payment herewith
     do
     :: JtoB?NSF;   // Not Sufficient Funds.  Payment rejected as not enough.
        if
        :: BtoJ!PAYMENT; // either pay more
        :: BtoJ!BACKOUT; // or back out of the deal and get a refund.
           JtoB?REFUND;
           break;
        fi
     :: JtoB?REFUND;   // If judge decided we ghosted the deal after insufficient payment,
                       // we could just be getting a refund and be done.
        break;         
     :: JtoB?RECEIPTQ; // time to check operation complete, deliverable acceptable
        // await receiveables.  Receive them.  Inspect them, determine acceptable.
        BtoJ!ACCEPTED; // deliverable is accepted.  Release payment
        break;
     od
  fi
}

proctype Seler() {
  JtoS?OFFERBUYER;    // Offer arrives at seller
  if
  :: StoJ!REJECT;
  :: StoJ!AGREED;     // seller agrees to offer
     if
     :: JtoS?NTP;        // NTP arrives at seller
        // Proceed. When done (shipped, performed, etc.) notify Judge.
	StoJ!DELIVERING; // Operation complete
        JtoS?ACCEPTED;   // buyer accepted deliverable.
        JtoS?PAYMENT     // receiving payment from seller via judge.
     :: JtoS?CANCELLED;  // NSF payment refunded, tx cancelled.
     :: JtoS?GHOSTED;    // NSF payment but ghosted not cancelled.
     fi
  fi
}

proctype Judge() {
  BtoJ?OFFERSELLER;  // Offer opened by buyer.
  JtoS!OFFERBUYER;   // passing the offer on to seller to confirm.
  if
  :: StoJ?REJECT;    // seller rejects offer
     JtoB!REJECT;    // tell buyer it was rejected; we're done.
  :: StoJ?AGREED;    // seller has agreed to offer
     JtoB!AGREED;    // tell buyer it's on, then we're done.

     // PAYMENT phase
     BtoJ?PAYMENT;   // receive buyer payment to hodl in escrow for seller.
     do
     :: break;    // full payment received.
     :: JtoB!NSF; // not sufficient funds recieved
        if
	:: BtoJ?PAYMENT; // good, buyer got the message and sent more money.
	:: BtoJ?BACKOUT; // buyer got the message but decided to back out.
	   JtoS!CANCELLED; 
	   JtoB!REFUND;  // and done
	   goto done;
	:: JtoS!GHOSTED; // Judge declares timeout here, buyer ghosted or didn't get the
	                 // message and respond in time.
	   JtoB!REFUND; // and done. Maybe incomplete refund, less a fee for the annoyance.
   	   goto done;
	fi
     od

     JtoS!NTP;       // Notice to Proceed: tell seller to deliver
     StoJ?DELIVERING;// seller claims operation complete
     JtoB!RECEIPTQ;  // ask buyer to confirm operation complete, deliverable accepted
     BtoJ?ACCEPTED;  // deliverable was accepted, buyer should pay now.
     JtoS!ACCEPTED;  // informing seller buyer accepted deliverable.
     JtoS!PAYMENT;   // sending payment to seller.
  fi
done:
  if
  :: BtoJ?PAYMENT; // buyer could have sent more payment after receiving NSF
                   // but we got it late, here, but we already declared the
		   // deal ghosted.  Maybe it was cancelled though?
     JtoB!REFUND; 
  :: skip
  fi
}
