# Payment State Machine

A type-safe payment transaction engine built in **PureScript**, implementing
phantom types and Railway Oriented Programming.

## The Core Idea

Most payment backends track transaction state as a string or enum in a database.
Nothing in the language stops you from calling `refund()` on a failed transaction.
These bugs reach production because the type system has no opinion about state.

This project encodes transaction state directly into the type system using
**phantom types** — a technique where a type parameter exists solely for the
compiler, with zero runtime overhead.

## Phantom Types vs Separate Types

**Naive approach — separate types for each state:**
```purescript
data InitiatedTransaction = InitiatedTransaction { id :: String, amount :: Number }
data SuccessTransaction    = SuccessTransaction   { id :: String, amount :: Number }
```
Works, but duplicates data definitions across every state.

**Phantom type approach — one type, state tracked by compiler:**
```purescript
data Transaction (s :: Type) = Transaction { id :: String, amount :: Number }

-- These are completely different types to the compiler
-- but identical at runtime
tx1 :: Transaction Initiated
tx2 :: Transaction Success
```

## Why This Matters

`refund` only accepts `Transaction Success`:

```purescript
refund :: Transaction Success -> Transaction Refunded
```

Attempting to refund a failed transaction:

```purescript
let failed = Transaction { id: "TX001", amount: 100.0 } :: Transaction Failed
refund failed -- COMPILE ERROR -- type mismatch
```

This is not a runtime check. The program cannot be compiled in this invalid state.
The illegal state is **unrepresentable**.

## State Lifecycle
Transaction Initiated

│

▼

Transaction Processing ──── InsufficientFunds ──► FailureReason

│

▼

Transaction Success ──────── FraudDetected ──────► FailureReason

│

├──► Transaction Refunded

└──► Transaction Disputed

## Failure Modes

Every failure is a typed value, not a thrown exception:

- `InsufficientFunds`
- `FraudDetected`
- `BankTimeout`
- `InvalidCard`

The compiler forces explicit handling of every case.

## Run it

```bash
npm install -g purescript spago
spago install
spago run
```

## Why PureScript

At Juspay's scale of 7.5M+ transactions per day, a single unhandled state
transition bug means money moving incorrectly. Pure FP eliminates this class
of bug by making invalid states impossible to express, not just unlikely to occur.

This project was built to deeply understand the engineering philosophy behind
Juspay's choice of PureScript over conventional backend languages.