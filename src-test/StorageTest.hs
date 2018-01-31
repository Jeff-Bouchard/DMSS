module StorageTest (tests) where

import Test.Tasty
import Test.Tasty.HUnit
--import Test.Tasty.SmallCheck

import DMSS.Storage.Types
import DMSS.Storage.TH
import DMSS.Storage ( storeCheckIn
                    , storeUser
                    , getUserKey
                    , removeUser
                    , listCheckIns
                    )


import Common
import Data.ByteString.Char8 ( pack )

import Crypto.Lithium.Types ( toPlaintext )
import Crypto.Lithium.Unsafe.Password ( PasswordString (..) )
import qualified Database.Persist.Sqlite as P
import Data.List
import Data.Maybe ( fromJust )


tests :: [TestTree]
tests =
  [ testCase "store_user_key_test" storeUserTest
  , testCase "store_check_in_test" storeCheckInTest
  , testCase "remove_user_key_test" removeUserKeyTest
  ]

tempDir :: FilePath
tempDir = "storageTest"


dummyPassHash :: PassHash
--dummyPassHash = PassHash "Password"
dummyPassHash = fromJust $ PassHash . PasswordString <$> (toPlaintext . pack $ "Password")


dummyBoxKeypairStore :: BoxKeypairStore
dummyBoxKeypairStore = BoxKeypairStore (pack "encryptedPrivateKeyCiphertext") (pack "publicKeyText")

storeUserTest :: Assertion
storeUserTest = withTemporaryTestDirectory tempDir ( \_ -> do
    -- Store fake user key
    let n = Name "joe"
    _ <- storeUser n dummyPassHash dummyBoxKeypairStore

    -- Check that the fake user key was stored
    k <- getUserKey (Silent True) n
    case k of
      Nothing -> assertFailure $ "Could not find User based on (" ++ (unName n) ++ ")"
      _       -> return ()
  )

removeUserKeyTest :: Assertion
removeUserKeyTest = withTemporaryTestDirectory tempDir ( \_ -> do
    -- Store fake user key
    let n = Name "deleteMe1234"
    _ <- storeUser n dummyPassHash dummyBoxKeypairStore

    -- Remove key
    removeUser n

    -- Check that the fake user key was stored
    k <- getUserKey (Silent True) n
    case k of
      Nothing -> return ()
      _       -> assertFailure $ "Found UserKey based on (" ++ (unName n) ++ ") but shouldn't have"
  )

storeCheckInTest :: Assertion
storeCheckInTest = withTemporaryTestDirectory tempDir ( \_ -> do
    -- Store a checkin
    let n = Name "joe"
    _ <- storeUser n dummyPassHash dummyBoxKeypairStore
    res <- storeCheckIn n (CheckInProof "MyProof")
    case res of
      (Left s) -> assertFailure s
      _ -> return ()
    -- Get a list of checkins
    l <- listCheckIns n 10
    -- Verify that only one checkin was returned
    case l of
      (_:[])    -> return ()
      x         -> assertFailure $ "Did not find one checkin: " ++ show x

    -- Create another checkin and verify order is correct
    _ <- storeCheckIn n (CheckInProof "More proof")
    _ <- storeCheckIn n (CheckInProof "Even more proof")
    l' <- listCheckIns n 10
    let createdList = map (\x -> checkInCreated $ P.entityVal x) l'
    if createdList == (reverse . sort) createdList
      then return ()
      else assertFailure "CheckIns were not in decending order"
  )
