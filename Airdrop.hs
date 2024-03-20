-- Airdrop.hs
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}

module Airdrop where

import qualified Ledger.Typed.Scripts as Scripts
import Ledger.Contexts
import PlutusTx
import PlutusTx.Prelude hiding (Semigroup(..), unless)
import qualified PlutusTx.AssocMap as M
import Data.Map as Map
import Data.Default (Default(..))

data AirdropDatum = AirdropDatum
    { airdropAmount :: Integer
    , claimed :: Map PubKey Bool
    } deriving Show

PlutusTx.makeLift ''AirdropDatum

{-# INLINABLE mkAirdropValidator #-}
mkAirdropValidator :: AirdropDatum -> () -> ScriptContext -> Bool
mkAirdropValidator dat () ctx =
    traceIfFalse "Value not locked" checkValueLocked &&
    traceIfFalse "Airdrop already claimed" (not $ Map.lookup (txSignedBy $ scriptContextTxInfo ctx) (claimed dat) == Just True)
    where
        checkValueLocked :: Bool
        checkValueLocked = case flattenValue (txInfoForge $ scriptContextTxInfo ctx) of
            [(cur, amt)] -> cur == Ada && amt == airdropAmount dat
            _ -> False

airdropValidator :: Scripts.ValidatorType AirdropDatum
airdropValidator = Scripts.wrapValidator mkAirdropValidator

airdropScript :: Scripts.ScriptInstance AirdropDatum
airdropScript = Scripts.validator @AirdropDatum
    $$(PlutusTx.compile [|| mkAirdropValidator ||])

airdropScriptAddress :: Ledger.Address
airdropScriptAddress = Scripts.validatorAddress airdropScript

data Airdrop
instance Scripts.ValidatorTypes Airdrop where
    type instance DatumType Airdrop = AirdropDatum
    type instance RedeemerType Airdrop = ()

instance Default AirdropDatum where
    def = AirdropDatum 0 Map.empty
