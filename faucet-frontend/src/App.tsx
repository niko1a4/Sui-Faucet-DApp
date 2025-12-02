import { useState, useEffect } from 'react';
import {
  useCurrentAccount,
  useSignAndExecuteTransaction,
  useSuiClient,
} from '@mysten/dapp-kit';
import { Transaction } from '@mysten/sui/transactions';
import { Header } from './components/Header';
import { ConnectPrompt } from './components/ConnectPrompt';
import { Message } from './components/Message';
import { StatsGrid } from './components/StatsGrid';
import { ClaimSection } from './components/ClaimSection';
import { DepositSection } from './components/DepositSection';
import { FaucetStats } from './types';
import {
  PACKAGE_ID,
  FAUCET_OBJECT_ID,
  CLOCK_OBJECT_ID,
  CLAIM_AMOUNT,
  REFRESH_INTERVAL,
} from './constants/config';
import './App.css';

function App() {
  const account = useCurrentAccount();
  const suiClient = useSuiClient();
  const { mutate: signAndExecute } = useSignAndExecuteTransaction();

  const [stats, setStats] = useState<FaucetStats | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // Fetch faucet stats
  const fetchStats = async () => {
    if (!account) return;

    try {
      setLoading(true);
      setError(null);

      console.log('Fetching faucet object:', FAUCET_OBJECT_ID);

      const faucetObject = await suiClient.getObject({
        id: FAUCET_OBJECT_ID,
        options: {
          showContent: true,
          showType: true,
        },
      });

      console.log('Faucet object response:', faucetObject);

      if (!faucetObject.data) {
        throw new Error('Faucet object not found');
      }

      if (faucetObject.data.content?.dataType !== 'moveObject') {
        throw new Error('Invalid faucet object type');
      }

      const fields = faucetObject.data.content.fields as any;
      console.log('Faucet fields:', fields);

      // The balance is nested in the Balance object
      const balanceValue = fields.balance || '0';
      console.log('Balance value:', balanceValue);

      // Get current time from clock
      let currentTime = Date.now();
      try {
        const clockObject = await suiClient.getObject({
          id: CLOCK_OBJECT_ID,
          options: { showContent: true },
        });

        if (clockObject.data?.content?.dataType === 'moveObject') {
          const clockFields = clockObject.data.content.fields as any;
          currentTime = Number(clockFields.timestamp_ms);
        }
      } catch (clockError) {
        console.log('Clock fetch error (using Date.now):', clockError);
      }

      // Check if user has claimed before
      let lastClaimTime = 0;
      let canClaim = true;
      let timeUntilNextClaim = 0;

      // Try to get last claim time
      try {
        const tx = new Transaction();
        tx.moveCall({
          target: `${PACKAGE_ID}::faucet::get_last_claim_time`,
          arguments: [
            tx.object(FAUCET_OBJECT_ID),
            tx.pure.address(account.address),
          ],
        });

        const devInspect = await suiClient.devInspectTransactionBlock({
          sender: account.address,
          transactionBlock: tx,
        });

        console.log('DevInspect result:', devInspect);

        if (devInspect.results?.[0]?.returnValues?.[0]) {
          const bytes = devInspect.results[0].returnValues[0][0];
          lastClaimTime = Number(
            new DataView(new Uint8Array(bytes).buffer).getBigUint64(0, true)
          );

          console.log('Last claim time:', lastClaimTime);

          if (lastClaimTime > 0) {
            const cooldownMs = 86400000; // 24 hours
            const timeElapsed = currentTime - lastClaimTime;
            canClaim = timeElapsed >= cooldownMs;
            timeUntilNextClaim = canClaim ? 0 : cooldownMs - timeElapsed;
          }
        }
      } catch (e) {
        console.log('Error fetching last claim time (user may not have claimed yet):', e);
        // This is fine - it means the user hasn't claimed yet
      }

      const faucetBalance = (Number(balanceValue) / 1_000_000_000).toFixed(2);
      console.log('Setting stats with balance:', faucetBalance);

      setStats({
        balance: faucetBalance,
        claimAmount: CLAIM_AMOUNT.toString(),
        cooldownPeriod: '24',
        lastClaimTime,
        canClaim,
        timeUntilNextClaim,
      });
    } catch (err: any) {
      console.error('Error fetching stats:', err);
      setError(`Failed to fetch faucet stats: ${err.message || 'Unknown error'}`);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    if (account) {
      fetchStats();
      const interval = setInterval(fetchStats, REFRESH_INTERVAL);
      return () => clearInterval(interval);
    }
  }, [account?.address]);

  // Handle claim
  const handleClaim = () => {
    if (!account) return;

    setError(null);
    setSuccess(null);

    const tx = new Transaction();
    tx.moveCall({
      target: `${PACKAGE_ID}::faucet::claim`,
      arguments: [tx.object(FAUCET_OBJECT_ID), tx.object(CLOCK_OBJECT_ID)],
    });

    signAndExecute(
      {
        transaction: tx,
      },
      {
        onSuccess: (result) => {
          console.log('Claim successful:', result);
          setSuccess(`Successfully claimed ${CLAIM_AMOUNT} SUI! Digest: ${result.digest}`);
          setError(null);
          setTimeout(() => {
            fetchStats();
          }, 2000);
        },
        onError: (err: any) => {
          console.error('Claim failed:', err);
          setError(err.message || 'Failed to claim tokens');
          setSuccess(null);
        },
      }
    );
  };

  // Handle deposit
  const handleDeposit = (amount: string) => {
    if (!account || !amount) return;

    setError(null);
    setSuccess(null);

    const amountInMist = Math.floor(Number(amount) * 1_000_000_000);
    if (amountInMist <= 0) {
      setError('Please enter a valid amount');
      return;
    }

    const tx = new Transaction();
    const [coin] = tx.splitCoins(tx.gas, [amountInMist]);
    tx.moveCall({
      target: `${PACKAGE_ID}::faucet::deposit`,
      arguments: [tx.object(FAUCET_OBJECT_ID), coin],
    });

    signAndExecute(
      {
        transaction: tx,
      },
      {
        onSuccess: (result) => {
          console.log('Deposit successful:', result);
          setSuccess(`Successfully deposited ${amount} SUI!`);
          setError(null);
          setTimeout(() => {
            fetchStats();
          }, 2000);
        },
        onError: (err: any) => {
          console.error('Deposit failed:', err);
          setError(err.message || 'Failed to deposit tokens');
          setSuccess(null);
        },
      }
    );
  };

  return (
    <div className="app">
      <Header />

      <main className="main">
        {!account ? (
          <ConnectPrompt />
        ) : (
          <>
            {error && <Message type="error" message={error} />}
            {success && <Message type="success" message={success} />}

            {loading ? (
              <div className="loading">Loading faucet data...</div>
            ) : stats ? (
              <>
                <StatsGrid stats={stats} />

                <div className="actions">
                  <ClaimSection stats={stats} onClaim={handleClaim} />
                  <DepositSection onDeposit={handleDeposit} />
                </div>
              </>
            ) : (
              <div className="no-data">
                <p>Unable to load faucet data</p>
                <p style={{ fontSize: '0.875rem', marginTop: '0.5rem', color: 'var(--text-muted)' }}>
                  Please check the browser console for more details
                </p>
              </div>
            )}
          </>
        )}
      </main>

      <footer className="footer">
        <p>Built on Sui Blockchain</p>
        <p className="contract-info">
          Package: {PACKAGE_ID.slice(0, 8)}...{PACKAGE_ID.slice(-6)}
        </p>
        <p className="contract-info">
          Faucet: {FAUCET_OBJECT_ID.slice(0, 8)}...{FAUCET_OBJECT_ID.slice(-6)}
        </p>
      </footer>
    </div>
  );
}

export default App;