import System.Metrics
import System.Remote.Monitoring.Statsd
import Control.Monad (void)
import Data.String.Conversions (cs)
import Data.Text hiding (length)
import Data.Monoid ( (<>) )

import Crypto.Hash.MD5 (hash)
import Network.HTTP hiding (host)
import qualified Network.AMQP as AMQP

import qualified System.Metrics.Label as L
import qualified System.Metrics.Gauge as G

main :: IO ()
main = do
  store <- newStore
  let opts = defaultStatsdOptions {
      host = "statsd.node.consul"
    , prefix = "scraper"
    }
  _ <- forkStatsd opts store

  amqpConnection <- AMQP.openConnection "rabbitmq.node.consul" "/" "guest" "guest"
  amqpChannel <- AMQP.openChannel amqpConnection
  _ <- AMQP.declareQueue amqpChannel $
    AMQP.newQueue { AMQP.queueName = "downloads" }
  AMQP.declareExchange amqpChannel $
    AMQP.newExchange { AMQP.exchangeName = "microservice"
                     , AMQP.exchangeType = "direct" }
  AMQP.bindQueue amqpChannel "downloads" "microservice" "downloads"
  void $ AMQP.consumeMsgs amqpChannel "downloads" AMQP.Ack $ download store

download :: Store -> (AMQP.Message, AMQP.Envelope) -> IO ()
download store (m, env) = do
  let url = cs $ AMQP.msgBody m
      md5 = cs $ hash url

  lblUrl    <- createLabel (intercalate "." ["http",md5,"url"])    store
  lblStatus <- createLabel (intercalate "." ["http",md5,"status"]) store
  lblLength <- createGauge (intercalate "." ["http",md5,"length"]) store

  L.set lblUrl (cs url)

  resp    <- simpleHTTP $ getRequest (cs url)
  payload <- getResponseBody resp
  code    <- getResponseCode resp

  G.set lblLength $ fromIntegral $ length payload
  L.set lblStatus $ codeText code

  case code of
       (2,_,_) -> AMQP.ackEnv env
       _ -> return ()

codeText :: ResponseCode -> Text
codeText (a,b,c) = cs $ show a <> show b <> show c
