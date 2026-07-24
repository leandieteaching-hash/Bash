import type {Metadata} from 'next';import './globals.css';import {AppProviders} from '@/providers/AppProviders';import {AppShell} from '@/components/layout/AppShell';
export const metadata:Metadata={title:'Studio OS',description:'Collaborative publishing production platform'};
export default function RootLayout({children}:{children:React.ReactNode}){return <html lang="en"><body><AppProviders><AppShell>{children}</AppShell></AppProviders></body></html>}
