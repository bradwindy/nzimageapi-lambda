'use client';

import { useState } from 'react';

interface Props {
  currentIndex: number;
  total: number;
  onPrev: () => void;
  onNext: () => void;
  onJumpTo: (index: number) => void;
  onSync: () => void;
  syncMessage: string | null;
  syncing: boolean;
}

export default function ProgressNav({
  currentIndex,
  total,
  onPrev,
  onNext,
  onJumpTo,
  onSync,
  syncMessage,
  syncing,
}: Props) {
  const [jumpInput, setJumpInput] = useState('');

  function handleJump(e: React.FormEvent) {
    e.preventDefault();
    const n = parseInt(jumpInput, 10);
    if (!isNaN(n) && n >= 1 && n <= total) {
      onJumpTo(n - 1); // 1-based → 0-based
      setJumpInput('');
    }
  }

  return (
    <div className="progress-nav">
      <span className="counter">
        {currentIndex + 1} / {total}
      </span>

      <div className="nav-btns">
        <button className="btn-nav" onClick={onPrev} disabled={currentIndex === 0}>
          ← Prev
        </button>
        <button className="btn-nav" onClick={onNext} disabled={currentIndex >= total - 1}>
          Next →
        </button>
      </div>

      <form className="jump-form" onSubmit={handleJump}>
        <input
          type="number"
          min={1}
          max={total}
          placeholder="Go to #"
          value={jumpInput}
          onChange={e => setJumpInput(e.target.value)}
        />
        <button type="submit" className="btn-nav">Go</button>
      </form>

      <div className="sync-area">
        {syncMessage && <span className="sync-msg">{syncMessage}</span>}
        <button className="btn-sync" onClick={onSync} disabled={syncing}>
          {syncing ? 'Syncing…' : 'Sync collections'}
        </button>
      </div>
    </div>
  );
}
