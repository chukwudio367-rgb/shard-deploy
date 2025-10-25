# ShardDeploy Smart Contract

A Stacks Clarity smart contract for blockchain-powered supply chain management with micro-fragmented verification and dynamic shard allocation.

## Overview

ShardDeploy implements a revolutionary approach to supply chain tracking by creating individual blockchain shards for each shipping component, enabling granular item-level tracking while maintaining enterprise-scale performance.

## Key Features

- **Shipment Management**: Create and track shipments with origin, destination, and delivery estimates
- **Shard-Level Tracking**: Individual blockchain shards for each shipping component
- **Proof-of-Transit**: IoT sensor validation with automatic recording of location and environmental data
- **Trust Score Mechanism**: Incentivizes honest reporting and reliable service performance
- **Validator Authorization**: Controlled access for IoT sensors and authorized nodes
- **Compliance Tracking**: Real-time monitoring of environmental conditions and handling

## Contract Structure

### Data Structures

#### Shipments
```clarity
{
    owner: principal,
    origin: string-ascii,
    destination: string-ascii,
    status: uint,
    created-at: uint,
    updated-at: uint,
    estimated-delivery: uint,
    total-shards: uint,
    trust-score: uint
}
```

#### Shards
```clarity
{
    shipment-id: uint,
    item-description: string-ascii,
    current-location: string-ascii,
    temperature: int,
    humidity: uint,
    last-verified: uint,
    verified-by: principal,
    is-compliant: bool
}
```

#### Transit Records
```clarity
{
    location: string-ascii,
    timestamp: uint,
    validator: principal,
    sensor-data: string-ascii,
    verified: bool
}
```

### Shipment Status Codes

- `status-created (1)`: Shipment initialized
- `status-in-transit (2)`: Shipment en route
- `status-delivered (3)`: Successfully delivered
- `status-delayed (4)`: Experiencing delays
- `status-cancelled (5)`: Shipment cancelled

## Public Functions

### 1. Create Shipment
```clarity
(create-shipment (origin (string-ascii 100)) 
                 (destination (string-ascii 100)) 
                 (estimated-delivery uint))
```
Creates a new shipment with specified origin, destination, and estimated delivery block height.

**Returns**: `(ok shipment-id)`

### 2. Add Shard
```clarity
(add-shard (shipment-id uint) 
           (item-description (string-ascii 200)) 
           (initial-location (string-ascii 100)))
```
Adds a new shard (individual item) to an existing shipment.

**Authorization**: Only shipment owner

**Returns**: `(ok shard-id)`

### 3. Record Transit
```clarity
(record-transit (shard-id uint) 
                (location (string-ascii 100)) 
                (sensor-data (string-ascii 500)) 
                (temperature int) 
                (humidity uint))
```
Records a transit checkpoint with IoT sensor data (Proof-of-Transit).

**Authorization**: Authorized validators only

**Returns**: `(ok checkpoint-id)`

### 4. Update Shipment Status
```clarity
(update-shipment-status (shipment-id uint) (new-status uint))
```
Updates the status of a shipment and automatically adjusts trust scores.

**Authorization**: Shipment owner or authorized validators

**Returns**: `(ok true)`

### 5. Update Shard Compliance
```clarity
(update-shard-compliance (shard-id uint) (is-compliant bool))
```
Updates compliance status for environmental or handling requirements.

**Authorization**: Authorized validators only

**Returns**: `(ok true)`

### 6. Authorize Validator
```clarity
(authorize-validator (validator principal))
```
Grants validator privileges to IoT sensors or trusted nodes.

**Authorization**: Contract owner only

**Returns**: `(ok true)`

### 7. Revoke Validator
```clarity
(revoke-validator (validator principal))
```
Revokes validator privileges.

**Authorization**: Contract owner only

**Returns**: `(ok true)`

## Read-Only Functions

- `(get-shipment (shipment-id uint))` - Retrieve shipment details
- `(get-shard (shard-id uint))` - Retrieve shard details
- `(get-transit-record (shard-id uint) (checkpoint-id uint))` - Get checkpoint data
- `(get-trust-score (participant principal))` - Get trust score for participant
- `(is-validator-authorized (validator principal))` - Check validator status
- `(get-shipment-nonce)` - Get current shipment counter
- `(get-shard-nonce)` - Get current shard counter

## Usage Examples

### Example 1: Create a Shipment
```clarity
(contract-call? .shard-deploy create-shipment 
    "Shanghai Port" 
    "Los Angeles Port" 
    u1000)
;; Returns: (ok u1)
```

### Example 2: Add Items to Shipment
```clarity
(contract-call? .shard-deploy add-shard 
    u1 
    "Electronics - iPhone 15 Pro (50 units)" 
    "Shanghai Warehouse")
;; Returns: (ok u1)

(contract-call? .shard-deploy add-shard 
    u1 
    "Electronics - MacBook Pro (30 units)" 
    "Shanghai Warehouse")
;; Returns: (ok u2)
```

### Example 3: Record Transit Checkpoint
```clarity
(contract-call? .shard-deploy record-transit 
    u1 
    "Pacific Ocean - Container Ship MAERSK-001" 
    "{\"gps\":\"25.0N,140.0E\",\"vessel\":\"MAERSK-001\",\"speed\":\"18knots\"}" 
    22 
    u65)
;; Returns: (ok u1)
```

### Example 4: Update Shipment Status
```clarity
(contract-call? .shard-deploy update-shipment-status u1 u3)
;; Returns: (ok true) - Status changed to delivered
```

## Trust Score System

The trust score mechanism incentivizes reliable performance:

- **Initial Score**: 500 (out of 1000)
- **Successful Delivery**: Increases trust score
- **Delayed Shipment**: Decreases trust score
- **Formula**: `(completed_shipments * 1000) / total_shipments`

Trust scores are automatically updated when shipments are marked as delivered or delayed.

## Error Codes

- `u100`: Owner-only operation
- `u101`: Resource not found
- `u102`: Unauthorized access
- `u103`: Invalid status code
- `u104`: Resource already exists
- `u105`: Invalid input parameters

## Security Features

1. **Role-Based Access Control**: Separate permissions for owners and validators
2. **Input Validation**: All inputs are validated before processing
3. **Immutable Records**: Transit records are permanent once created
4. **Authorized Validators**: Only pre-approved validators can record transit data

## Integration with IoT

The contract is designed to integrate with IoT sensors that act as validator nodes:

1. IoT sensors are authorized by the contract owner
2. Sensors automatically call `record-transit` with real-time data
3. Environmental data (temperature, humidity) is recorded on-chain
4. Location updates provide continuous chain of custody

## Deployment

1. Deploy the contract to Stacks blockchain
2. Contract owner is automatically set as first validator
3. Authorize additional IoT validators using `authorize-validator`
4. Begin creating shipments and tracking items

## Testing Checklist

- [ ] Deploy contract successfully
- [ ] Create shipment with valid parameters
- [ ] Add multiple shards to shipment
- [ ] Authorize validator accounts
- [ ] Record transit checkpoints
- [ ] Update shipment status
- [ ] Verify trust score calculations
- [ ] Test unauthorized access (should fail)
- [ ] Test invalid inputs (should fail)

## Future Enhancements

- Carbon footprint tracking calculations
- Automated insurance claim processing
- Predictive delay detection with ML integration
- Multi-modal shipping support
- ERP system integration APIs
- Enhanced compliance checking rules
