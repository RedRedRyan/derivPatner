import React from 'react';
import DigitsView from './components/digits-view';
import '../shared/styles/globals.css';

export const DigitsTab = () => {
  return (
    <div className="flex flex-col h-full overflow-hidden bg-background text-foreground font-sans antialiased">
      <DigitsView />
    </div>
  );
};

export default DigitsTab;
