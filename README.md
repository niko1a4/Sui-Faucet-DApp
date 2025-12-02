# SUI Faucet DApp

A decentralized application built on the Sui blockchain that allows users to claim free SUI tokens every 24 hours. Users can also contribute to the faucet by depositing their own SUI tokens.

# App Display

![](images/Screenshot%202025-12-02%20193610.png)
Welcome to the Faucet app. Click on Connect wallet to connect your Slush wallet.
![](images/Screenshot%202025-12-02%20194000.png)
Deposit some tokens if you want (or if faucet is empty). <br>
Click on Claim to claim your faucet tokens.
![](images/Screenshot%202025-12-02%20194022.png)


## Features

- **Claim Tokens**: Claim 10 SUI every 24 hours
- **Deposit Funds**: Help fund the faucet for the community
- **Real-time Stats**: View faucet balance and claim status
- **Cooldown Timer**: See exactly when you can claim next
- **Wallet Integration**: Connect with any Sui-compatible wallet

## Tech Stack

### Smart Contract
- **Move**: Smart contract language for Sui blockchain
- **Sui Framework**: Built on Sui's core libraries

### Frontend
- **React**: UI library
- **TypeScript**
- **Vite**: Build tool and dev server
- **@mysten/dapp-kit**: Sui wallet integration
- **@mysten/sui**: Sui blockchain interaction
- **@tanstack/react-query**: Data fetching and caching

## Prerequisites

- Node.js (v16 or higher)
- npm or yarn
- Sui Wallet (browser extension)
- Sui CLI (for contract deployment)

## Installation

### 1. Clone the Repository
```bash
git clone <your-repo-url>
cd faucet-frontend
```

### 2. Install Dependencies
```bash
npm install
```

### 3. Configure Environment

Create a `.env` file in the root directory:
```env
VITE_PACKAGE_ID=your_package_id_here
VITE_FAUCET_OBJECT_ID=your_faucet_object_id_here
```

Or update the values directly in `src/constants/config.ts`.

## Smart Contract Deployment

### 1. Build the Contract
```bash
cd faucet
sui move build
```

### 2. Deploy to Testnet
```bash
sui client switch --env testnet
sui client publish 
```

### 3. Save the Addresses

After deployment, note down:
- **PackageID**: The published package address
- **Faucet Object ID**: The shared Faucet object (look for `Owner: Shared`)

Update these in your `.env` file or `src/constants/config.ts`.

## Running the Application

### Development Mode
```bash
npm run dev
```

The application will be available at `http://localhost:5173`

### Production Build
```bash
npm run build
npm run preview
```

## Project Structure
```
token-faucet-dapp/
├── faucet/                  # Move smart contract
│   ├── sources/
│   │   └── faucet.move
│   ├── Move.toml
│   └── tests/faucet_tests.move
├── faucet-frontend/         # React frontend application
│   ├── src/
│   │   ├── components/      # React components
│   │   │   ├── Header.tsx
│   │   │   ├── ConnectPrompt.tsx
│   │   │   ├── Message.tsx
│   │   │   ├── StatsGrid.tsx
│   │   │   ├── ClaimSection.tsx
│   │   │   └── DepositSection.tsx
│   │   ├── styles/          # Component styles
│   │   │   ├── Header.css
│   │   │   ├── ConnectPrompt.css
│   │   │   ├── Message.css
│   │   │   ├── StatsGrid.css
│   │   │   ├── ClaimSection.css
│   │   │   └── DepositSection.css
│   │   ├── constants/       # Configuration
│   │   │   └── config.ts
│   │   ├── types/           # TypeScript types
│   │   │   └── index.ts
│   │   ├── utils/           # Utility functions
│   │   │   └── formatTime.ts
│   │   ├── App.tsx          # Main application component
│   │   ├── App.css          # Global styles
│   │   ├── main.tsx         # Application entry point
│   │   └── index.css        # Base styles
│   ├── .env                 # Environment variables
│   ├── package.json
│   ├── tsconfig.json
│   └── vite.config.ts
└── README.md
```

## Smart Contract Overview

### Main Functions

- **`claim()`**: Claim 10 SUI tokens (24-hour cooldown)
- **`deposit()`**: Deposit SUI tokens into the faucet
- **`withdraw()`**: Admin-only function to withdraw funds
- **`reset_cooldown()`**: Admin-only function to reset user cooldown

### View Functions

- **`get_balance()`**: Get current faucet balance
- **`get_claim_amount()`**: Get the claim amount (10 SUI)
- **`get_cooldown_period()`**: Get cooldown period (24 hours)
- **`has_claimed()`**: Check if user has claimed before
- **`get_last_claim_time()`**: Get user's last claim timestamp
- **`can_claim()`**: Check if user can claim now

## Usage

### Connect Wallet

1. Click the "Connect Wallet" button
2. Select your Sui wallet
3. Approve the connection

### Claim Tokens

1. Ensure you're connected to the correct network (devnet)
2. Wait for the cooldown period to expire (if you've claimed before)
3. Click "Claim 10 SUI"
4. Approve the transaction in your wallet

### Deposit Tokens

1. Enter the amount of SUI you want to deposit
2. Click "Deposit"
3. Approve the transaction in your wallet

## Network Configuration

The application is configured to work on Sui Devnet by default. To change networks:

Edit `src/main.tsx`:
```typescript
<SuiClientProvider networks={networks} defaultNetwork="devnet">
```

Available networks: `testnet`, `mainnet`, `devnet`

**Important**: Make sure your wallet is connected to the same network as your deployed contract!

## Configuration

### Constants (`src/constants/config.ts`)
```typescript
export const PACKAGE_ID = 'your_package_id';
export const FAUCET_OBJECT_ID = 'your_faucet_object_id';
export const CLOCK_OBJECT_ID = '0x6';
export const CLAIM_AMOUNT = 10;
export const COOLDOWN_HOURS = 24;
export const REFRESH_INTERVAL = 10000; // 10 seconds
```

## License

MIT
