import { FormEvent } from 'react';
import '../styles/DepositSection.css';

interface DepositSectionProps {
    onDeposit: (amount: string) => void;
}

export const DepositSection = ({ onDeposit }: DepositSectionProps) => {
    const handleSubmit = (e: FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        const formData = new FormData(e.currentTarget);
        const amount = formData.get('amount') as string;
        onDeposit(amount);
        e.currentTarget.reset();
    };

    return (
        <div className="deposit-section">
            <h3>Fund the Faucet</h3>
            <p>Help others by depositing SUI</p>
            <form onSubmit={handleSubmit}>
                <input
                    type="number"
                    name="amount"
                    placeholder="Amount in SUI"
                    step="0.1"
                    min="0.1"
                    required
                />
                <button type="submit" className="btn btn-secondary">
                    Deposit
                </button>
            </form>
        </div>
    );
};