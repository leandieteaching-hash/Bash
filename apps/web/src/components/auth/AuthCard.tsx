import Link from 'next/link';
import type {ReactNode} from 'react';

export function AuthCard({title, description, children, footer}:{title:string;description:string;children:ReactNode;footer?:ReactNode}) {
  return <main className="authPage"><section className="authCard" aria-labelledby="auth-title"><Link href="/" className="authBrand">Studio OS</Link><h1 id="auth-title">{title}</h1><p className="muted">{description}</p>{children}{footer&&<div className="authFooter">{footer}</div>}</section></main>;
}
