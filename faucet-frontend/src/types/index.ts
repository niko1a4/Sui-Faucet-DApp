export interface FaucetStats {
    balance: string;
    claimAmount: string;
    cooldownPeriod: string;
    lastClaimTime: number;
    canClaim: boolean;
    timeUntilNextClaim: number;
}

export interface MessageProps {
    type: 'error' | 'success';
    message: string;
}