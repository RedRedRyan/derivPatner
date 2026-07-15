import React from 'react';
import RiseFallView from './components/rise-fall-view';
import '../shared/styles/globals.css';

export const RiseFallTab = () => {
  return (
    <div className="flex flex-col h-full overflow-hidden bg-background text-foreground font-sans antialiased">
      <RiseFallView />
    </div>
  );
};

export default RiseFallTab;
