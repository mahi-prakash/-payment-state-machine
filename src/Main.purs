module Main where

import Prelude
import Effect (Effect)
import Effect.Console (log)
import Data.Either (Either(..))

-- Phantom type states -- empty types, only exist for the compiler
data Initiated
data Processing
data Failed
data Success
data Refunded
data Disputed

-- ONE Transaction type carrying state as phantom parameter
-- At runtime it's always just { id, amount } -- the state is only in the type
data Transaction (s :: Type) = Transaction { id :: String, amount :: Number }

-- Failure reasons as typed values
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

-- Initiate a transaction
initiate :: String -> Number -> Transaction Initiated
initiate id amount = Transaction { id, amount }

-- Process -- can fail or proceed
process :: Transaction Initiated -> Either FailureReason (Transaction Processing)
process (Transaction tx) =
  if tx.amount > 100000.0
  then Left InsufficientFunds
  else Right (Transaction tx)

-- Authorize -- can fail or succeed
authorize :: Transaction Processing -> Either FailureReason (Transaction Success)
authorize (Transaction tx) =
  if tx.amount > 50000.0
  then Left FraudDetected
  else Right (Transaction tx)

-- Refund -- only accepts Success, impossible to refund anything else
refund :: Transaction Success -> Transaction Refunded
refund (Transaction tx) = Transaction tx

-- Dispute -- only accepts Success
dispute :: Transaction Success -> Transaction Disputed
dispute (Transaction tx) = Transaction tx

-- Full pipeline
runTransaction :: String -> Number -> String
runTransaction id amount =
  case process (initiate id amount) of
    Left reason -> "FAILED [" <> show reason <> "] txId: " <> id
    Right processing ->
      case authorize processing of
        Left reason -> "FAILED [" <> show reason <> "] txId: " <> id
        Right _     -> "SUCCESS txId: " <> id

main :: Effect Unit
main = do
  log "=== Payment State Machine (Phantom Types) ==="
  log ""
  log "--- Valid transaction ---"
  log $ runTransaction "TX001" 5000.0
  log ""
  log "--- Insufficient funds ---"
  log $ runTransaction "TX002" 150000.0
  log ""
  log "--- Fraud detected ---"
  log $ runTransaction "TX003" 75000.0
  log ""
  log "--- Refund flow ---"
  let success = refund (Transaction { id: "TX004", amount: 3000.0 } :: Transaction Success)
  let (Transaction r) = success
  log $ "REFUNDED txId: " <> r.id <> " amount: " <> show r.amount