{- git-annex branch state management
 -
 - Runtime state about the git-annex branch, including a small read cache.
 -
 - Copyright 2011 Joey Hess <joey@kitenet.net>
 -
 - Licensed under the GNU GPL version 3 or higher.
 -}

module Annex.BranchState where

import Common.Annex
import Types.BranchState
import qualified Annex

getState :: Annex BranchState
getState = Annex.getState Annex.branchstate

setState :: BranchState -> Annex ()
setState state = Annex.changeState $ \s -> s { Annex.branchstate = state }

setCache :: FilePath -> String -> Annex ()
setCache file content = do
	state <- getState
	setState state { cachedFile = Just file, cachedContent = content }

getCache :: FilePath -> Annex (Maybe String)
getCache file = getState >>= go
	where
		go state
			| cachedFile state == Just file =
				return $ Just $ cachedContent state
			| otherwise = return Nothing

invalidateCache :: Annex ()
invalidateCache = do
	state <- getState
	setState state { cachedFile = Nothing, cachedContent = "" }

{- Runs an action to update the branch, if it's not been updated before
 - in this run of git-annex. -}
runUpdateOnce :: Annex () -> Annex ()
runUpdateOnce a = unlessM (branchUpdated <$> getState) $ do
	a
	disableUpdate

{- Avoids updating the branch. A useful optimisation when the branch
 - is known to have not changed, or git-annex won't be relying on info
 - from it. -}
disableUpdate :: Annex ()
disableUpdate = Annex.changeState setupdated
	where
		setupdated s = s { Annex.branchstate = new }
			where
				new = old { branchUpdated = True }
				old = Annex.branchstate s