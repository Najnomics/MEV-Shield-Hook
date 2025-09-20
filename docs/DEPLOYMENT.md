# MEV Shield Hook Deployment Guide

## Prerequisites

1. **Foundry Installation**
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Environment Setup**
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. **Dependencies**
   ```bash
   make install
   ```

## Deployment Networks

### Local Development (Anvil)
```bash
# Start Anvil
anvil

# Deploy to Anvil
make deploy-anvil
```

### Fhenix Testnet
```bash
# Deploy to testnet
make deploy-testnet
```

### Fhenix Mainnet
```bash
# Deploy to mainnet (requires confirmation)
make deploy-mainnet
```

## Post-Deployment

1. **Verify Contracts**
   ```bash
   make verify
   ```

2. **Initialize Components**
   - Configure protection parameters
   - Set up monitoring
   - Initialize metrics tracking

## Configuration

### Protection Settings
- `DEFAULT_PROTECTION_THRESHOLD`: Risk score threshold (default: 75)
- `DEFAULT_MAX_SLIPPAGE_BUFFER`: Maximum slippage buffer (default: 500 = 5%)
- `DEFAULT_MAX_EXECUTION_DELAY`: Maximum execution delay in blocks (default: 2)

### Detection Settings
- `DETECTION_SENSITIVITY`: Detection sensitivity level (default: 80)

## Monitoring

After deployment, monitor:
- Protection success rate
- Gas usage patterns
- Detection accuracy
- System performance metrics
