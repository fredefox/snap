{-# LANGUAGE OverloadedStrings   #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE PackageImports      #-}
{-# LANGUAGE TemplateHaskell     #-}

module Snap.Snaplet.Auth.App
  ( App(..)
  , auth
  , heist
  , authInit
  , appInit
  ) where


------------------------------------------------------------------------------
import           Control.Lens
import           Control.Monad.Trans (lift)
import           Data.Monoid
------------------------------------------------------------------------------
import           Data.Map.Syntax
import           Heist
import qualified Heist.Compiled as C
import           Snap.Core                                    (pass)
import           Snap.Snaplet
import           Snap.Snaplet.Auth
import           Snap.Snaplet.Session
import           Snap.Snaplet.Auth.Backends.JsonFile
import           Snap.Snaplet.Session.Backends.CookieSession
import           Snap.Snaplet.Heist

------------------------------------------------------------------------------
data App = App
    { _sess  :: Snaplet SessionManager
    , _auth  :: Snaplet (AuthManager App)
    , _heist :: Snaplet (Heist App)
    }
$(makeLenses ''App)

instance HasHeist App where
  heistLens = subSnaplet heist

compiledSplices :: Splices (C.Splice (Handler App App))
compiledSplices = do
  "userSplice" #! C.withSplices C.runChildren userCSplices $
    lift $ maybe pass return =<< with auth currentUser

------------------------------------------------------------------------------
appInit :: SnapletInit App App
appInit = makeSnaplet "app" "Test application" Nothing $ do

    h <- nestSnaplet "heist" heist $
           heistInit'
           "templates"
           (mempty {hcCompiledSplices = compiledSplices})

  
    s <- nestSnaplet "sess" sess $
           initCookieSessionManager "site_key.txt" "sess" (Just 3600)

    a <- nestSnaplet "auth" auth authInit

    addAuthSplices h auth

    return $ App s a h


------------------------------------------------------------------------------
authInit :: SnapletInit App (AuthManager App)
authInit = initJsonFileAuthManager
           defAuthSettings { asLockout = Just (3, 1) }
           sess "users.json"
