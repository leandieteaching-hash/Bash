import Link from 'next/link';
export function Breadcrumbs({items}:{items:{label:string;href?:string}[]}){return <div className="breadcrumbs">{items.map((item,i)=><span key={item.label}>{i>0?' / ':''}{item.href?<Link href={item.href}>{item.label}</Link>:item.label}</span>)}</div>}
export function PageHeader({title,description,action}:{title:string;description?:string;action?:React.ReactNode}){return <div className="pageHeader"><div><h1>{title}</h1>{description&&<p>{description}</p>}</div>{action}</div>}
export function EmptyState({title,description}:{title:string;description:string}){return <div className="empty"><h3>{title}</h3><p className="muted">{description}</p></div>}
