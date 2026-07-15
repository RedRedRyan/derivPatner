'use client';

import React, { createContext, useContext } from 'react';
import { useDerivWS } from '@deriv/core';
import { useAuth, UseAuthReturn } from './use-auth';
import type { DerivWS } from '@deriv/core';

interface DerivWSContextValue {
  ws: DerivWS | null;
  isConnected: boolean;
  isExhausted: boolean;
  auth: UseAuthReturn;
}

const DerivWSContext = createContext<DerivWSContextValue | null>(null);

export function TemplateAuthProvider({ children }: { children: React.ReactNode }) {
  const auth = useAuth();
  const { ws, isConnected, isExhausted } = useDerivWS({
    url: auth.wsUrl,
    accountId: auth.activeAccountId ?? undefined,
  });

  return (
    <DerivWSContext.Provider value={{ ws, isConnected, isExhausted, auth }}>
      {children}
    </DerivWSContext.Provider>
  );
}

export function useTemplateAuth(): DerivWSContextValue {
  const ctx = useContext(DerivWSContext);
  if (!ctx) {
    throw new Error('useTemplateAuth must be used within a TemplateAuthProvider');
  }
  return ctx;
}
