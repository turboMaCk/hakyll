-- | Module providing pattern matching and capturing on 'Identifier's.
--
-- TODO: Documentation
--
module Hakyll.Core.Identifier.Pattern
    ( Pattern
    , parsePattern
    , match
    , doesMatch
    , matches
    ) where

import Data.List (intercalate)
import Control.Monad (msum)
import Data.Maybe (isJust)

import GHC.Exts (IsString, fromString)

import Hakyll.Core.Identifier

-- | One base element of a pattern
--
data PatternComponent = CaptureOne
                      | CaptureMany
                      | Literal String
                      deriving (Eq)

instance Show PatternComponent where
    show CaptureOne = "*"
    show CaptureMany = "**"
    show (Literal s) = s

-- | Type that allows matching on identifiers
--
newtype Pattern = Pattern {unPattern :: [PatternComponent]}
                deriving (Eq)

instance Show Pattern where
    show = intercalate "/" . map show . unPattern

instance IsString Pattern where
    fromString = parsePattern

-- | Parse a pattern from a string
--
parsePattern :: String -> Pattern
parsePattern = Pattern . map toPattern . unIdentifier . parseIdentifier
  where
    toPattern x | x == "*"  = CaptureOne
                | x == "**" = CaptureMany
                | otherwise = Literal x

-- | Match an identifier against a pattern, generating a list of captures
--
match :: Pattern -> Identifier -> Maybe [[String]]
match (Pattern p) (Identifier i) = match' p i

-- | Check if an identifier matches a pattern
--
doesMatch :: Pattern -> Identifier -> Bool
doesMatch p = isJust . match p

-- | Given a list of identifiers, retain only those who match the given pattern
--
matches :: Pattern -> [Identifier] -> [Identifier]
matches p = filter (doesMatch p)

-- | Split a list at every possible point, generate a list of (init, tail) cases
--
splits :: [a] -> [([a], [a])]
splits ls = reverse $ splits' [] ls
  where
    splits' lx ly = (lx, ly) : case ly of
        []       -> []
        (y : ys) -> splits' (lx ++ [y]) ys

-- | Internal verion of 'match'
--
match' :: [PatternComponent] -> [String] -> Maybe [[String]]
match' [] [] = Just []  -- An empty match
match' [] _ = Nothing   -- No match
match' _ [] = Nothing   -- No match
match' (m : ms) (s : ss) = case m of
    -- Take one string and one literal, fail on mismatch
    Literal l -> if s == l then match' ms ss else Nothing
    -- Take one string and one capture
    CaptureOne -> fmap ([s] :) $ match' ms ss
    -- Take one string, and one or many captures
    CaptureMany ->
        let take' (i, t) = fmap (i :) $ match' ms t
        in msum $ map take' $ splits (s : ss)
