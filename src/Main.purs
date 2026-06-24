module Main where

import Prelude
import Effect (Effect)
import Effect.Console (log)
import Data.Either (Either(..))

-- Every state is a distinct type
-- The compiler knows exactly what state a transaction is in

data Initiated = Initiated
  { transactionId :: String
  , amount        :: Number
  , cardNumber    :: String
  }

data Processing = Processing
  { transactionId :: String
  , amount        :: Number
  }

data Failed = Failed
  { transactionId :: String
  , reason        :: FailureReason
  }

data Success = Success
  { transactionId :: String
  , amount        :: Number
  , authCode      :: String
  }

data Refunded = Refunded
  { transactionId :: String
  , amount        :: Number
  }

data Disputed = Disputed
  { transactionId :: String
  , reason        :: String
  }

-- Every failure mode is a typed value, not a string or exception
data FailureReason
  = InsufficientFunds
  | FraudDetected
  | BankTimeout
  | InvalidCard

instance showFailureReason :: Show FailureReason where
  show InsufficientFunds = "Insufficient funds"
  show FraudDetected     = "Fraud detected"
  show BankTimeout       = "Bank timeout"
  show InvalidCard       = "Invalid card"

-- TRANSITIONS
-- Each function only accepts the exact state it needs
-- You cannot call process on a Failed transaction -- it won't compile

initiate :: String -> Number -> String -> Initiated
initiate txId amount card = Initiated { transactionId: txId, amount, cardNumber: card }

-- Processing can succeed or fail -- Either encodes this purely
process :: Initiated -> Either Failed Processing
process (Initiated tx) =
  if tx.amount > 100000.0
  then Left  $ Failed    { transactionId: tx.transactionId, reason: InsufficientFunds }
  else Right $ Processing { transactionId: tx.transactionId, amount: tx.amount }

-- Bank authorization -- can succeed or fail
authorize :: Processing -> Either Failed Success
authorize (Processing tx) =
  if tx.amount > 50000.0
  then Left  $ Failed  { transactionId: tx.transactionId, reason: FraudDetected }
  else Right $ Success { transactionId: tx.transactionId, amount: tx.amount, authCode: "AUTH-OK-9x1" }

-- Refund only accepts Success -- refunding a Failed is impossible to even write
refund :: Success -> Refunded
refund (Success tx) = Refunded { transactionId: tx.transactionId, amount: tx.amount }

-- Dispute only accepts Success
dispute :: Success -> String -> Disputed
dispute (Success tx) reason = Disputed { transactionId: tx.transactionId, reason }

-- SIMULATOR
runTransaction :: String -> Number -> String -> String
runTransaction txId amount card =
  let initiated = initiate txId amount card
  in case process initiated of
    Left (Failed f)       -> "FAILED [" <> show f.reason <> "] txId: " <> f.transactionId
    Right processing ->
      case authorize processing of
        Left (Failed f)   -> "FAILED [" <> show f.reason <> "] txId: " <> f.transactionId
        Right _     -> "SUCCESS txId: " <> txId <> " | authCode: AUTH-OK-9x1"

main :: Effect Unit
main = do
  log "=== Payment State Machine ==="
  log ""
  log "--- Valid transaction ---"
  log $ runTransaction "TX001" 5000.0  "4532015112830366"
  log ""
  log "--- Insufficient funds ---"
  log $ runTransaction "TX002" 150000.0 "4532015112830366"
  log ""
  log "--- Fraud detected ---"
  log $ runTransaction "TX003" 75000.0  "4532015112830366"
  log ""
  log "--- Refund flow ---"
  let success = Success { transactionId: "TX004", amount: 3000.0, authCode: "AUTH-OK-9x1" }
  let (Refunded r) = refund success
  log $ "REFUNDED txId: " <> r.transactionId <> " amount: " <> show r.amount