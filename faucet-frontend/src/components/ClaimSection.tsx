import { FaucetStats } from '../types';
import { CLAIM_AMOUNT } from '../constants/config';
import '../styles/ClaimSection.css';

interface ClaimSectionProps {
    stats: FaucetStats;
    onClaim: () => void;
}

export const ClaimSection = ({ stats, onClaim }: ClaimSectionProps) => {
    return (
        <div className="claim-section">
            <h3>Claim Tokens</h3>
            <p>Claim {CLAIM_AMOUNT} SUI every 24 hours</p>
            <button
                className="btn btn-primary"
                onClick={onClaim}
                disabled={!stats.canClaim}
            >
                {stats.canClaim ? `Claim ${CLAIM_AMOUNT} SUI` : 'Cooldown Active'}
            </button>
        </div>
    );
};