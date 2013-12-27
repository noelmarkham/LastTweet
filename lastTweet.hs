{-# LANGUAGE OverloadedStrings #-}
import           Control.Applicative
import           Control.Monad
import           Data.Aeson                   as J
import           Data.ByteString.Base64.Lazy  as B64L
import qualified Data.ByteString.Char8        as B
import qualified Data.ByteString.Lazy.Char8   as BL
import           Data.Maybe
import           Network.HTTP.Conduit
import           Text.Regex
import           Data.List.Split
import           Web.Cookie
import qualified Data.Map as Map

data AuthenticationResponse = AuthenticationResponse { accessToken :: BL.ByteString } deriving Show

instance FromJSON AuthenticationResponse where
   parseJSON (Object v) = AuthenticationResponse <$> v .: "access_token"
   parseJSON _          = mzero

data TwitterResponse = TwitterResponse { text :: BL.ByteString } deriving Show

instance FromJSON TwitterResponse where
   parseJSON (Object v) = TwitterResponse <$> v .: "text"
   parseJSON _          = mzero

main :: IO ()
main = do
    let lookup = readPropertyFromFile "application.properties"
    -- get the key, secret, twitter handle
    foundKey <- lookup "twitter.key"
    let key = BL.pack foundKey
    foundSecret <- lookup "twitter.secret"
    let secret = BL.pack foundSecret
    foundAccount <- lookup "twitter.account"
    let account = BL.pack foundAccount

    -- request the auth token
    authTokenResponse <- requestAuthToken key secret
    token <- maybe (ioError $ userError "Did not receive authentication token") return $ getToken $ responseBody authTokenResponse

    -- make twitter request with the token
    twitterResponse <- fmap responseBody $ twitterRequest token account
    let twitterResponseActualM = getTwitterResponse twitterResponse
    unrolledTwitterResponse <- maybe (ioError $ userError "Twitter request did not have text body") return twitterResponseActualM

    -- print the result
    putStrLn $ format $ text unrolledTwitterResponse

readPropertyFromFile :: String -> String -> IO String
readPropertyFromFile filename property = do
    content <- readFile filename
    let props = lines content
    let propertyMap = propertiesToMap props
    let found = Map.lookup property propertyMap
    maybe (ioError $ userError $ "Property " ++ property ++ " not found: " ++ show propertyMap) return found

propertiesToMap :: [String] -> Map.Map String String
propertiesToMap properties = Map.fromList $ propertiesToPairs properties

propertiesToPairs :: [String] -> [(String, String)]
propertiesToPairs  = foldl (\m -> \s -> m ++ propertyToPair s) []

propertyToPair :: String -> [(String, String)]
propertyToPair property = case splitOn "=" property of
    head : tail : _ -> [(head, tail)]
    _               -> []

toStrict :: BL.ByteString -> B.ByteString
toStrict = B.concat . BL.toChunks

requestAuthToken :: BL.ByteString -> BL.ByteString -> IO (Response BL.ByteString)
requestAuthToken key secret = withManager $ \manager -> httpLbs req manager
        where req = def {
                          host           = "api.twitter.com",
                          port           = 443,
                          secure         = True,
                          requestHeaders = [("Authorization", fullAuthString), ("Content-Type", "application/x-www-form-urlencoded;charset=UTF-8")],
                          requestBody    = RequestBodyBS "grant_type=client_credentials",
                          path           = "/oauth2/token",
                          method         = "POST"
                        }
              fullAuthString = toStrict $ BL.append "Basic " $ B64L.encode $ BL.concat [key, ":", secret]

getToken :: BL.ByteString -> Maybe BL.ByteString
getToken jsonString = fmap accessToken $ J.decode jsonString

-- todo parameterize screen name
twitterRequest :: BL.ByteString -> BL.ByteString -> IO (Response BL.ByteString)
twitterRequest token account = withManager $ \manager -> httpLbs req manager
          where req = def {
                          host           = "api.twitter.com",
                          port           = 443,
                          secure         = True,
                          requestHeaders = [("Authorization", fullToken)],
                          path           = "/1.1/statuses/user_timeline.json",
                          queryString    = B.append "count=1&screen_name=" $ toStrict account,
                          method         = "GET"
                        }
                fullToken = toStrict $ BL.append "Bearer " token

getTwitterResponse :: BL.ByteString -> Maybe TwitterResponse
getTwitterResponse jsonString = J.decode jsonString >>= listToMaybe

-- TODO this should probably be in config?
format :: BL.ByteString -> String
format originalString = foldl replace (BL.unpack originalString) [(mkRegex "http.*", ""), (mkRegex "\xc3\xa2\xc2\x80\xc2\x93", "-")]
--format = BL.unpack

--              acc string -> (regex, replacement) -> new string
replace :: String -> (Regex, String) -> String
replace string (regex, new) = subRegex regex string new


