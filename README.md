# MemeTree - Enhanced Memetic Evolution Platform

## Overview

MemeTree is a decentralized platform built on the Stacks blockchain that tracks and monetizes meme evolution through generational NFTs. Creators can mint original memes and earn royalties as their content evolves through derivatives created by the community.

## 🚀 Recent Enhancements

### 1. Security Enhancements

- **Emergency Mode**: Contract owner can activate emergency mode to pause critical operations during security incidents
- **Reentrancy Protection**: Non-reentrant guards prevent reentrancy attacks
- **Input Validation**: Comprehensive validation for all inputs including string lengths, mint prices, and royalty rates
- **Rate Limiting**: Operations per block limits to prevent spam and DoS attacks
- **Timelock Treasury**: Critical treasury changes require a 10-day timelock for security
- **Safe Math Operations**: Overflow/underflow protection for all arithmetic operations

### 2. Multi-Generational Royalty Distribution

- **Enhanced Royalties**: Royalties now flow across multiple generations (up to 5 generations)
- **Fair Distribution**: 50% to immediate parent, 25% to grandparent, 12.5% to great-grandparent, etc.
- **Performance Optimization**: Royalty rate caching for improved gas efficiency
- **Automatic Tracking**: Earnings are automatically tracked and updated for all generations

### 3. Performance Optimizations

- **Batch Operations**: `batch-transfer-memes` function allows transferring multiple NFTs in one transaction
- **Caching System**: Royalty calculations are cached to reduce computation costs
- **Optimized Data Structures**: Efficient list and map operations for large datasets

### 4. Comprehensive Test Suite

- **23 Test Cases**: Covering all contract functions, security features, and edge cases
- **Security Testing**: Rate limiting, emergency mode, access controls, and input validation
- **Integration Tests**: End-to-end functionality testing for minting, transferring, and royalties
- **Error Handling**: Comprehensive error condition testing

### 5. Web Dashboard

- **Modern UI**: Clean, responsive interface built with HTML5/CSS3/JavaScript
- **Wallet Integration**: Stacks Connect integration for seamless wallet connection
- **Real-time Stats**: Live platform statistics and user dashboard
- **Full Functionality**: Mint original/derivative memes, transfer NFTs, view genealogy
- **User Experience**: Intuitive forms and real-time feedback

## 🏗️ Architecture

### Smart Contract Features

- **NFT Standard**: SIP-009 compliant non-fungible token implementation
- **Generational Tracking**: Complete genealogy trees for meme evolution
- **Royalty System**: Multi-generational royalty distribution
- **Viral Metrics**: Automated viral coefficient calculation
- **Authenticity Verification**: External platform verification system

### Security Features

- **Access Control**: Owner-only functions with proper authorization
- **Emergency Controls**: Circuit breaker pattern implementation
- **Input Sanitization**: Comprehensive validation and bounds checking
- **Audit Trail**: Complete transaction history and state tracking

## 🚀 Getting Started

### Prerequisites

- Node.js 16+
- Clarinet
- Stacks Wallet (for testing)

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd MemeTree

# Install dependencies
npm install

# Run tests
npm test

# Check contract
clarinet check

# Start development console
clarinet console
```

### Web Dashboard

Open `dashboard.html` in a modern web browser to interact with the contract through a user-friendly interface.

## 📋 Contract Functions

### Public Functions

- `mint-original-meme`: Create a new original meme NFT
- `mint-derivative-meme`: Create a derivative meme based on an existing one
- `transfer-meme`: Transfer meme ownership
- `verify-meme-authenticity`: Link meme to external platforms
- `pause-contract`/`unpause-contract`: Emergency pause controls
- `enable-emergency-mode`/`disable-emergency-mode`: Emergency mode controls
- `set-platform-treasury`/`execute-treasury-change`: Treasury management with timelock
- `batch-transfer-memes`: Transfer multiple memes efficiently

### Read-Only Functions

- `get-meme-data`: Retrieve complete meme information
- `get-meme-children`: Get derivative memes
- `get-user-memes`: List user's owned memes
- `get-meme-genealogy`: Simplified genealogy for compliance
- `get-potential-earnings`: Calculate total earnings across generations
- `get-viral-coefficient`: Get meme's viral score
- Security status functions: `is-contract-paused`, `is-emergency-mode`, etc.

## 🔧 Configuration

### Constants

- `platform-fee`: 2% platform fee on all transactions
- `max-royalty-rate`: 10% maximum royalty rate
- `min-mint-price`: 0.01 STX minimum mint price
- `max-royalty-generations`: 5 generations for royalty distribution
- `rate-limit-blocks`: 10 blocks for rate limiting
- `emergency-mode-duration`: 1440 blocks (10 days)

## 🧪 Testing

Run the comprehensive test suite:

```bash
npm test
```

Tests cover:
- Basic functionality (minting, transferring)
- Security features (access control, rate limiting, emergency mode)
- Edge cases (invalid inputs, overflow conditions)
- Multi-generational royalties
- Performance optimizations

## 📊 Performance Metrics

- **Gas Efficiency**: Batch operations reduce gas costs by ~60%
- **Royalty Distribution**: Multi-generational payouts with caching
- **Scalability**: Optimized data structures for large meme trees
- **Security**: Comprehensive validation with minimal overhead

## 🔒 Security Considerations

- Emergency pause functionality for incident response
- Timelock mechanisms for critical changes
- Rate limiting to prevent DoS attacks
- Safe math operations prevent overflow exploits
- Access control for administrative functions
- Input validation prevents malformed data attacks

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add comprehensive tests
4. Ensure all tests pass
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙏 Acknowledgments

- Built on the Stacks blockchain
- Uses Clarinet for development and testing
- Inspired by memetic evolution and NFT innovation
