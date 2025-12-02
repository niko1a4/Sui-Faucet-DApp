import { MessageProps } from '../types';
import '../styles/Message.css';

export const Message = ({ type, message }: MessageProps) => {
    return (
        <div className={`message ${type}`}>
            <span>{type === 'error' ? '' : ''}</span> {message}
        </div>
    );
};