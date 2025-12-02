import { ConnectButton } from '@mysten/dapp-kit';
import '../styles/Header.css';

export const Header = () => {
    return (
        <header className="header">
            <h1>💧 SUI Faucet</h1>
            <ConnectButton />
        </header>
    );
};