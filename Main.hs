import System.Metrics
import System.Remote.Monitoring.Statsd
import Control.Concurrent (threadDelay)
import Control.Monad (forever)

main :: IO ()
main = do
  store <- newStore
  let opts = defaultStatsdOptions {
      host = "statsd.node.consul"
    , prefix = "scraper"
    , debug = True
    }
  registerGcMetrics store
  _ <- forkStatsd opts store

  forever $ do
    threadDelay 10000000  -- 10s
