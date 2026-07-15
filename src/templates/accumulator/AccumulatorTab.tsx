import React from 'react';
import { TemplateAuthProvider } from '../shared/auth/TemplateAuthProvider';
import AccumulatorView from './components/accumulator-view';
import '../shared/styles/globals.css';

const AccumulatorTabContent = () => {
  return (
    <div className="flex flex-col h-full overflow-hidden bg-background text-foreground font-sans antialiased">
      <AccumulatorView />
    </div>
  );
};

export const AccumulatorTab = () => {
  return (
    <AccumulatorTabContent />
  );
};

export default AccumulatorTab;
