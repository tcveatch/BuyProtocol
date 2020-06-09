//
// BUY: a purchase and sale protocol for electronic commerce.
// 

// 0.1: No branching, first draft: offer, agreed, ntp, delivering, accepted, paid
// 0.2: escrow payment at judge required before NTP
// 0.3: clarify: terms negotiation outside of protocol;
//      the seller's offering, description, price, delivery method is brought by buyer to protocol.
//      so we just need buyer to send what they want (already gotten from
//      seller) and seller to confirm that's good with them.
// 0.4: buyer might delay full payment past a deadline and should get order cancelled and
//      a refund.
// 0.5: seller fails to perform, sends UTP to Judge who forwards it and refunds the buyer.
// 0.6: return service requested upon arrival. broken in transit, broken after use, etc.
// 0.?: NOT INCLUDED: warrantee service requested after payment.
//      No, that's not part of the original transaction; let it be later since it is later.

mtype = {
      	  OFFERSELLER, OFFERBUYER, AGREED,     RECEIPTQ,
          ACCEPTED,    PAYMENT,    NSF,        BACKOUT, 
	  REFUND,      NTP,        UTP,        DELIVERING,
	  DEALREJECT,  CANCELLED,  GHOSTED,    REJECTED,
	  RETURNAUTH,  RETURNSHIPPED,          REPLACEMENTSHIPPED
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
  :: JtoB?DEALREJECT;   // Deal is rejected. Done.
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
        do
	:: BtoJ!ACCEPTED; // deliverable is accepted.  Release payment to seller
           break;
        :: BtoJ!REJECTED; // deliverable is broken on arrival (evidence enclosed)
	   		  // return merchandise authorization requested
	   JtoB?RETURNAUTH;
	   BtoJ!RETURNSHIPPED;
	   JtoB?REPLACEMENTSHIPPED;
	od
	break;
     :: JtoB?UTP;      // bad news.  Judge reports seller is Unable To Perform.
        JtoB?REFUND;
	break;
     od
  fi
}

proctype Seler() {
  JtoS?OFFERBUYER;    // Offer arrives at seller
  if
  :: StoJ!DEALREJECT;
  :: StoJ!AGREED;     // seller agrees to offer
     if
     :: JtoS?NTP;        // NTP arrives at seller
        // Proceed. When done (shipped, performed, etc.) notify Judge.
        if
	:: StoJ!UTP;        // unable to perform.
	:: StoJ!DELIVERING; // Operation complete
	   do
           :: JtoS?ACCEPTED;   // buyer accepted deliverable.
              JtoS?PAYMENT     // receiving payment from seller via judge.
	      break;
           :: JtoS?REJECTED;
	      StoJ!RETURNAUTH;
	      JtoS?RETURNSHIPPED;
	      StoJ!REPLACEMENTSHIPPED;
	   od
        fi
     :: JtoS?CANCELLED;  // NSF payment refunded, tx cancelled.
     :: JtoS?GHOSTED;    // NSF payment but ghosted not cancelled.
     fi
  fi
}

proctype Judge() {
  BtoJ?OFFERSELLER;  // Offer opened by buyer.
  JtoS!OFFERBUYER;   // passing the offer on to seller to confirm.
  if
  :: StoJ?DEALREJECT;    // seller rejects offer
     JtoB!DEALREJECT;    // tell buyer it was rejected; we're done.
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
     if
     :: StoJ?UTP;       // seller says, Unable to perform
        JtoB!UTP;       // tell buyer seller is bailing out.
        JtoB!REFUND;    // and refund the buyer's money.  Maybe offer a yelp link to report the seller
     :: StoJ?DELIVERING;// seller claims operation complete
        JtoB!RECEIPTQ;  // ask buyer to confirm operation complete, deliverable accepted
	do
        :: BtoJ?ACCEPTED;  // deliverable was accepted, buyer should pay now.
           JtoS!ACCEPTED;  // informing seller buyer accepted deliverable.
           JtoS!PAYMENT;   // sending payment to seller.
	   break;
	:: BtoJ?REJECTED;
	   JtoS!REJECTED;
	   StoJ?RETURNAUTH;
	   JtoB!RETURNAUTH;
	   BtoJ?RETURNSHIPPED;
	   JtoS!RETURNSHIPPED;
	   StoJ?REPLACEMENTSHIPPED;
	   JtoB!REPLACEMENTSHIPPED;
	od
     fi
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
