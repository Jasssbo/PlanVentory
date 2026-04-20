/// Status indicators for events based on material availability and rental status
enum EventStatus {
  /// Event needs attention - has material shortages without any rentals to cover them
  needsRental,
  
  /// Event has active or pending rentals - materials are being sourced
  hasRental,
  
  /// Event is all good - either has all materials or is completed
  ok,
}
