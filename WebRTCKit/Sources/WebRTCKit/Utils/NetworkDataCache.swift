import Foundation

private enum Constants {
    
    /// Tolerance in seconds for data points when retrieving the loss rate.
    static let timeTolerance: TimeInterval = 0.5
    
    /// The maximum number of data points that are stored.
    static let maxDataPoints = 10
}

/// The NetworkDataCache protocol provides the interface for caching network data points
/// and computing packet loss rate over a specified time interval.
protocol NetworkDataCache: Actor {
    
    /// Add a data point. Should be called every second.
    /// - Parameter dataPoint: The data point to add.
    func addDataPoint(_ dataPoint: NetworkDataPoint)
    
    /// Get the packet loss rate.
    /// - Parameter seconds: The number of seconds in the past for the calculation.
    /// - Returns: The packet loss rate within the given time interval.
    func getPacketLossRate(overLast seconds: TimeInterval) -> Double?
    
    /// Delete all the data points.
    func deleteAllData()
}

actor NetworkDataCacheImpl: NetworkDataCache {
    
    private var dataPoints: [NetworkDataPoint] = []
    
    private let log = Logger(caller: "NetworkDataCache")
    
    func addDataPoint(_ dataPoint: NetworkDataPoint) {
        dataPoints.append(dataPoint)
        removeOldDataPoints()
    }
    
    func getPacketLossRate(overLast seconds: TimeInterval) -> Double? {
        let secondsWithTolerance = seconds + Constants.timeTolerance
        let cutoffDate = Date().addingTimeInterval(-secondsWithTolerance)
        
        guard
            let pointOfInterest = dataPoints.first(where: { $0.timestamp >= cutoffDate }),
            let lastPoint = dataPoints.last,
            // make sure we have at least the data of the requested amount of seconds
            abs(pointOfInterest.timestamp.distance(to: cutoffDate)) < 1.0
        else {
            // Not enough data points collected yet to calculate the packet loss over the last x seconds
            return nil
        }
        
        let packetsSent: Int
        let packetsLost: Int
        
        if lastPoint == pointOfInterest {
            // only one point in the time interval found
            
            // make sure we have at least 2 points for calculation
            guard dataPoints.count > 1 else {
                log.info("Not enough data points collected yet to calculate packet loss.")
                return nil
            }
            let pointBeforeLast = dataPoints[dataPoints.count - 2]
            packetsSent = lastPoint.packetsSent - pointBeforeLast.packetsSent
            packetsLost = lastPoint.packetsLost - pointBeforeLast.packetsLost
            
        } else {
            packetsSent = lastPoint.packetsSent - pointOfInterest.packetsSent
            packetsLost = lastPoint.packetsLost - pointOfInterest.packetsLost
        }
        
        guard packetsSent > 0 else {
            log.info("No packets sent in the given time interval.")
            return 1
        }
        
        let packetLossRate = Double(packetsLost) / Double(packetsSent + packetsLost)
        
        return packetLossRate
    }
    
    func deleteAllData() {
        dataPoints.removeAll()
    }
}

// MARK: - Private functions

private extension NetworkDataCacheImpl {
    
    func removeOldDataPoints() {
        if dataPoints.count > Constants.maxDataPoints {
            dataPoints.removeFirst(dataPoints.count - Constants.maxDataPoints)
        }
    }
}
