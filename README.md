# Spreadly Testnet Addresses

This document provides the essential contract addresses for interacting with Spreadly on the Sui Testnet network.

## Spreadly Core Addresses

```move
// Package address
spreadly_package = "0x60ad85f51976b6c8d29c53d3dd9ea0d96c3c27bb117b68ec52452e49c2aae0c8"

// Distribution contract
distribution = "0x3541468b3777f93b29c0939ebfeb2ecbaa78a864d6a8210e03ddf08b545b4fb9"
```

## Cetus Core Addresses

```move
// Configuration object
global_config = "0x9774e359588ead122af1c7e7f64e14ade261cfeecdb5d0eb4a5b3b4c8ab8bd3e"

// Pools object
pools = "0x50eb61dd5928cec5ea04711a2e9b72e5237e79e9fbcd2ce3d5469dc8708e0ee2"
```

## Token Metadata

```move
// SPRD token metadata
sprd_metadata = "0x3c05eb2a06b59e5328f67c40783b566ecc5d4131eebad67d652615104b4a6290"

// SUI token metadata
sui_metadata = "0x587c29de216efd4219573e08a1f6964d4fa7cb714518c2c8a0f29abfa264327d"
```

## System Objects

```move
// Sui system clock
clock = "0x6"
```

## Payment

Payments are accepted in SUI coins (`Coin<SUI>`). The amount is variable based on the specific operation.

---

**Note**: These addresses are specific to the Sui Testnet.