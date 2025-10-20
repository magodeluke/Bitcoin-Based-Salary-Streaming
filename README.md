# 💰 Bitcoin-Based Salary Streaming

🚀 **Real-time salary payments on the Stacks blockchain** - Pay employees by the second, not by the month!

## 📋 Overview

This smart contract enables employers to stream salaries to employees in real-time using STX tokens. Instead of traditional monthly payments, employees can withdraw their earned wages at any time based on how much time has passed.

## ✨ Features

- ⏰ **Real-time streaming**: Employees earn salary every second
- 💸 **Instant withdrawals**: Access earned wages anytime
- 🔒 **Secure funding**: Employers can fund streams with any amount
- 🛑 **Stream control**: Employers can stop streams and handle emergencies
- 📊 **Status tracking**: Monitor earnings, balances, and withdrawals
- 🔍 **Multi-stream support**: Handle multiple salary streams per user
- 🎯 **Delegated withdrawals**: Set beneficiaries for automated or emergency access
- 📝 **Salary adjustments**: Propose and approve salary rate changes

## 🎯 Core Functions

### For Employers

#### `create-salary-stream`
Create a new salary stream for an employee
```clarity
(create-salary-stream employee-principal salary-rate-per-second start-time initial-funding)
```

#### `fund-stream`
Add more STX to an existing stream
```clarity
(fund-stream stream-id amount)
```

#### `stop-stream`
Stop an active salary stream
```clarity
(stop-stream stream-id)
```

#### `emergency-withdraw`
Settle a stopped stream and return unused funds
```clarity
(emergency-withdraw stream-id)
```

### For Employees

#### `withdraw-salary`
Withdraw earned salary from a stream
```clarity
(withdraw-salary stream-id)
```

#### `set-stream-beneficiary`
Designate a beneficiary who can withdraw on your behalf
```clarity
(set-stream-beneficiary stream-id (some beneficiary-principal))
;; Remove beneficiary
(set-stream-beneficiary stream-id none)
```

### Read-Only Functions

#### `get-withdrawable-amount`
Check how much can be withdrawn from a stream
```clarity
(get-withdrawable-amount stream-id)
```

#### `get-stream-status`
Get complete information about a stream
```clarity
(get-stream-status stream-id)
```

#### `get-stream-beneficiary`
Check if a stream has a designated beneficiary
```clarity
(get-stream-beneficiary stream-id)
```

## 📖 Usage Examples

### 1. 👔 Employer Creates Salary Stream

```clarity
;; Create stream paying 1 STX per hour (277777 microSTX per second)
;; Starting now, with 1000 STX initial funding
(create-salary-stream 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u277777 u1640995200 u1000000000)
```

### 2. 💰 Employee Withdraws Salary

```clarity
;; Withdraw earned salary from stream #1
(withdraw-salary u1)
```

### 3. 📈 Check Stream Status

```clarity
;; Get detailed status of stream #1
(get-stream-status u1)
```

### 4. 💸 Employer Adds Funding

```clarity
;; Add 500 STX to stream #1
(fund-stream u1 u500000000)
```

### 5. 🎯 Employee Sets Beneficiary

```clarity
;; Designate a beneficiary for automated withdrawals
(set-stream-beneficiary u1 (some 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE))
```

## 🔧 Technical Details

- **Precision**: Uses microsecond precision for salary calculations
- **Time-based**: Earnings calculated using Stacks block timestamps
- **Gas-efficient**: Optimized for minimal transaction costs
- **Error handling**: Comprehensive error codes for all edge cases

## 🛠️ Development

### Prerequisites
- Clarinet CLI installed
- Node.js and npm

### Setup
```bash
git clone <repository-url>
cd Bitcoin-Based-Salary-Streaming
npm install
```

### Testing
```bash
clarinet check
clarinet test
```

## 🔐 Security Features

- Only employers can create and fund streams
- Employees and designated beneficiaries can withdraw from streams
- Automatic balance tracking prevents double-spending
- Emergency functions for dispute resolution
- Employees maintain full control over beneficiary designations

## 📊 Error Codes

| Code | Description |
|------|-------------|
| 401  | Unauthorized access |
| 404  | Stream not found |
| 400  | Invalid amount |
| 402  | Insufficient funds |
| 409  | Stream already exists |
| 410  | Stream not active |
| 411  | Stream already stopped |
|| 412  | Future start time invalid |
|| 413  | Adjustment not found |
|| 414  | Adjustment already processed |
|| 415  | Adjustment expired |
|| 416  | Invalid adjustment |

## 🚀 Deployment

Deploy to Stacks testnet:
```bash
clarinet deploy --testnet
```

Deploy to Stacks mainnet:
```bash
clarinet deploy --mainnet
```

## 💡 Use Cases

- 🏢 **Freelance payments**: Pay contractors by the hour automatically
- 👨‍💻 **Employee salaries**: Modern payroll with instant access
- 🎮 **Gaming rewards**: Stream tokens to players based on playtime
- 📚 **Educational stipends**: Pay students for learning time
- 🔬 **Research grants**: Distribute funding over time periods
- 💼 **Automated treasury**: Route salary to smart contracts for automatic processing
- 🚨 **Emergency access**: Designate trusted contacts for fund access

## 🤝 Contributing

Feel free to submit issues and pull requests to improve the contract!

## 📄 License

MIT License - see LICENSE file for details
