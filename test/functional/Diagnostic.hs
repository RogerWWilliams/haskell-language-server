{-# LANGUAGE OverloadedStrings #-}

module Diagnostic (tests) where

import Control.Applicative.Combinators
import           Control.Lens hiding (List)
import           Control.Monad.IO.Class
import           Data.Aeson (toJSON)
import qualified Data.Text as T
import qualified Data.Default
import           Ide.Logger
import           Ide.Plugin.Config
import           Language.Haskell.LSP.Test hiding (message)
import           Language.Haskell.LSP.Types
import qualified Language.Haskell.LSP.Types.Lens as LSP
import           Test.Hls.Util
import           Test.Tasty
import           Test.Tasty.HUnit
import           Test.Hspec.Expectations

-- ---------------------------------------------------------------------

tests :: TestTree
tests = testGroup "diagnostics providers" [
        saveTests
        , triggerTests
        , errorTests
        , warningTests
    ]


triggerTests :: TestTree
triggerTests = testGroup "diagnostics triggers" [
    testCase "runs diagnostics on save" $
        runSession hieCommandExamplePlugin codeActionSupportCaps "test/testdata" $ do
            logm "starting DiagnosticSpec.runs diagnostic on save"
            doc <- openDoc "ApplyRefact2.hs" "haskell"

            diags@(reduceDiag:_) <- waitForDiagnostics

            liftIO $ do
                length diags `shouldBe` 2
                reduceDiag ^. LSP.range `shouldBe` Range (Position 1 0) (Position 1 12)
                reduceDiag ^. LSP.severity `shouldBe` Just DsInfo
                reduceDiag ^. LSP.code `shouldBe` Just (StringValue "Eta reduce")
                reduceDiag ^. LSP.source `shouldBe` Just "hlint"

            diags2a <- waitForDiagnostics

            liftIO $ length diags2a `shouldBe` 2

            sendNotification TextDocumentDidSave (DidSaveTextDocumentParams doc)

            diags3@(d:_) <- waitForDiagnosticsSource "eg2"

            liftIO $ do
                length diags3 `shouldBe` 1
                d ^. LSP.range `shouldBe` Range (Position 0 0) (Position 1 0)
                d ^. LSP.severity `shouldBe` Nothing
                d ^. LSP.code `shouldBe` Nothing
                d ^. LSP.message `shouldBe` T.pack "Example plugin diagnostic, triggered byDiagnosticOnSave"
    ]

errorTests :: TestTree
errorTests = testGroup  "typed hole errors" [
    testCase "is deferred" $
        runSession hieCommand fullCaps "test/testdata" $ do
            _ <- openDoc "TypedHoles.hs" "haskell"
            [diag] <- waitForDiagnosticsSource "bios"
            liftIO $ diag ^. LSP.severity `shouldBe` Just DsWarning
    ]

warningTests :: TestTree
warningTests = testGroup  "Warnings are warnings" [
    testCase "Overrides -Werror" $
        runSession hieCommand fullCaps "test/testdata/wErrorTest" $ do
            _ <- openDoc "src/WError.hs" "haskell"
            [diag] <- waitForDiagnosticsSource "bios"
            liftIO $ diag ^. LSP.severity `shouldBe` Just DsWarning
    ]

saveTests :: TestTree
saveTests = testGroup  "only diagnostics on save" [
    testCase "Respects diagnosticsOnChange setting" $
        runSession hieCommandExamplePlugin codeActionSupportCaps "test/testdata" $ do
            let config = Data.Default.def { diagnosticsOnChange = False } :: Config
            sendNotification WorkspaceDidChangeConfiguration (DidChangeConfigurationParams (toJSON config))
            doc <- openDoc "Hover.hs" "haskell"
            diags <- waitForDiagnostics

            liftIO $ do
                length diags `shouldBe` 0

            let te = TextEdit (Range (Position 0 0) (Position 0 13)) ""
            _ <- applyEdit doc te
            skipManyTill loggingNotification noDiagnostics

            sendNotification TextDocumentDidSave (DidSaveTextDocumentParams doc)
            diags2 <- waitForDiagnostics
            liftIO $
                length diags2 `shouldBe` 1
    ]
