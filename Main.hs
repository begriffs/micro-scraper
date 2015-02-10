import System.Metrics
import System.Remote.Monitoring.Statsd
import Control.Concurrent (threadDelay)

main :: IO ()
main = do
  store <- newStore
  let opts = defaultStatsdOptions {
      host = "statsd.node.consul"
    , prefix = "scraper"
    , debug = True
    }
  _ <- forkStatsd opts store

  threadDelay 86400000000
