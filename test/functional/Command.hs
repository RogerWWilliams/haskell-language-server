{-# LANGUAGE OverloadedStrings #-}
module Command (tests) where

import Control.Lens hiding (List)
import Control.Monad.IO.Class
import qualified Data.Text as T
import Data.Char
import Language.Haskell.LSP.Test
import Language.Haskell.LSP.Types as LSP
import Language.Haskell.LSP.Types.Lens as LSP
import Test.Hls.Util
import Test.Tasty
import Test.Tasty.HUnit
import Test.Hspec.Expectations

tests :: TestTree
tests = testGroup "commands" [
    testCase "are prefixed" $
        runSession hieCommand fullCaps "test/testdata/" $ do
            ResponseMessage _ _ (Just res) Nothing <- initializeResponse
            let List cmds = res ^. LSP.capabilities . executeCommandProvider . _Just . commands
                f x = (T.length (T.takeWhile isNumber x) >= 1) && (T.count ":" x >= 2)
            liftIO $ do
                cmds `shouldSatisfy` all f
                cmds `shouldNotSatisfy` null
    , testCase "get de-prefixed" $
        runSession hieCommand fullCaps "test/testdata/" $ do
            ResponseMessage _ _ _ (Just err) <- request
                WorkspaceExecuteCommand
                (ExecuteCommandParams "1234:package:add" (Just (List [])) Nothing) :: Session ExecuteCommandResponse
            let ResponseError _ msg _ = err
            -- We expect an error message about the dud arguments, but should pickup "add" and "package"
            liftIO $ msg `shouldSatisfy` T.isInfixOf "while parsing args for add in plugin package"
    ]
