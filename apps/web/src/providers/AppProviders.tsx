'use client';
import {createContext,useContext,useMemo,useState,type ReactNode} from 'react';
type AppContextValue={sidebarOpen:boolean;setSidebarOpen:(open:boolean)=>void;permissions:Set<string>;hasPermission:(permission?:string)=>boolean};
const AppContext=createContext<AppContextValue|null>(null);
export function AppProviders({children}:{children:ReactNode}){const[sidebarOpen,setSidebarOpen]=useState(false);const permissions=useMemo(()=>new Set(['asset.view','notification.view','report.view_book','spread.view']),[]);const value=useMemo(()=>({sidebarOpen,setSidebarOpen,permissions,hasPermission:(p?:string)=>!p||permissions.has(p)}),[sidebarOpen,permissions]);return <AppContext.Provider value={value}>{children}</AppContext.Provider>}
export function useApp(){const value=useContext(AppContext);if(!value)throw new Error('useApp must be used inside AppProviders');return value}
