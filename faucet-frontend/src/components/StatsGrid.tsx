import { FaucetStats } from '../types/index';
import { formatTime } from '../utils/formatTime';
import '../styles/StatsGrid.css';

interface StatsGridProps {
    stats: FaucetStats;
}

export const StatsGrid = ({ stats }: StatsGridProps) => {
    return (
        <div className="stats-grid">
            <div className="stat-card">
                <div className="stat-label">Faucet Balance</div>
                <div className="stat-value">{stats.balance} SUI</div>
            </div>

            <div className="stat-card">
                <div className="stat-label">Claim Amount</div>
                <div className="stat-value">{stats.claimAmount} SUI</div>
            </div>

            <div className="stat-card">
                <div className="stat-label">Cooldown Period</div>
                <div className="stat-value">{stats.cooldownPeriod} hours</div>
            </div>

            <div className="stat-card">
                <div className="stat-label">Status</div>
                <div className="stat-value">
                    {stats.canClaim ? (
                        <span className="status-ready">Ready to Claim</span>
                    ) : (
                        <span className="status-cooldown">
                            {formatTime(stats.timeUntilNextClaim)}
                        </span>
                    )}
                </div>
            </div>
        </div>
    );
};